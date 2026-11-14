#!/bin/bash
# Claude Code status line: one line, with its items spread evenly across the terminal width. Claude
# Code shows its permission mode on a row of its own below this one, so the footer has two rows.
# The items:
#   the model and its effort level
#   the working directory and the git branch, as "<path> (<branch>)"
#   the context window usage (% and tokens)
#   the subscription usage left, with the time until each limit resets:
#   "Left: S <%> (<time>) W <%> (<time>)". S is the 5-hour session limit and W the weekly one.
#
# A model can have its own weekly limit inside the overall one. Fable may use a part of the weekly
# limit (for example 50%), and its usage also counts toward the overall limit. With such a model,
# W shows the model's own limit, or the overall limit when that one would run out first.
# When the items do not fit, they get shorter in steps (see "Layout").
#
# Claude Code sends the 5-hour and 7-day windows on stdin, but not the per-model weekly limits.
# Those come from the usage API that Claude Code's /usage screen reads. The script keeps the reply
# in a cache file for 60 seconds and refreshes it in the background, so the status line does not
# wait for the network. The API is not documented: if it fails or changes, the model stat goes away.

input=$(cat)
# ${#var} counts characters, not bytes, only in a UTF-8 locale
export LC_ALL=en_US.UTF-8

RESET=$'\033[0m'
BLUE=$'\033[34m'
GREEN=$'\033[32m'
CYAN=$'\033[36m'
YELLOW=$'\033[33m'
MAGENTA=$'\033[35m'
RED=$'\033[31m'

field() { jq -r "$1 // empty" <<<"$input"; }

# --- Model, effort level, working directory, and git branch ---
model=$(field '.model.display_name')
effort=$(field '.effort.level')
cwd=$(field '.workspace.current_dir')
[ -n "$cwd" ] || cwd=$(field '.cwd')
branch=""
if [ -n "$cwd" ]; then
  branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null)
  # A detached HEAD has no branch name: show the short commit
  [ -n "$branch" ] || branch=$(git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null)
fi

# --- Context window usage ---
used_tokens=$(field '.context_window.total_input_tokens')
window_size=$(field '.context_window.context_window_size')
used_pct=$(field '.context_window.used_percentage')

fmt_tokens() {
  awk -v n="$1" 'BEGIN {
    if (n >= 1000000) printf "%.1fM", n/1000000
    else if (n >= 1000) printf "%.0fk", n/1000
    else printf "%d", n
  }'
}

# --- Subscription usage left ---
fmt_countdown() {
  local secs=$(($1 - $(date +%s)))
  if [ "$secs" -le 0 ]; then
    printf "now"
  elif [ "$secs" -ge 86400 ]; then
    printf "%dd%dh" "$((secs / 86400))" "$(((secs % 86400) / 3600))"
  elif [ "$secs" -ge 3600 ]; then
    printf "%dh%dm" "$((secs / 3600))" "$(((secs % 3600) / 60))"
  else
    printf "%dm" "$((secs / 60))"
  fi
}

# S and W: the % left and the countdown to the reset
five_used=$(field '.rate_limits.five_hour.used_percentage')
week_used=$(field '.rate_limits.seven_day.used_percentage')
pct_left() { awk -v u="$1" 'BEGIN { printf "%.0f", 100 - u }'; }
s_left="" s_reset="" w_left="" w_reset="" w_color="$MAGENTA"
if [ -n "$five_used" ]; then
  s_left=$(pct_left "$five_used")
  resets_at=$(field '.rate_limits.five_hour.resets_at')
  [ -n "$resets_at" ] && s_reset=$(fmt_countdown "$resets_at")
fi
if [ -n "$week_used" ]; then
  w_left=$(pct_left "$week_used")
  resets_at=$(field '.rate_limits.seven_day.resets_at')
  [ -n "$resets_at" ] && w_reset=$(fmt_countdown "$resets_at")
fi

# --- The current model's own weekly limit, from the usage API ---
usage_cache="$HOME/.cache/claude-statusline/usage.json"

oauth_token() {
  if [ "$(uname -s)" = "Darwin" ]; then
    security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null
  else
    cat "$HOME/.claude/.credentials.json" 2>/dev/null
  fi | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null
}

refresh_usage() {
  local token tmp
  token=$(oauth_token)
  [ -n "$token" ] || return
  tmp="$usage_cache.$$"
  if curl -sf --max-time 5 https://api.anthropic.com/api/oauth/usage \
    -H "Authorization: Bearer $token" -H "anthropic-beta: oauth-2025-04-20" -o "$tmp" &&
    jq -e '.limits' "$tmp" >/dev/null 2>&1; then
    mv "$tmp" "$usage_cache"
  else
    rm -f "$tmp"
    # Try again after the next 60 seconds, not on each refresh of the status line
    touch "$usage_cache"
  fi
}

if [ -n "$model" ]; then
  mkdir -p "${usage_cache%/*}"
  if [ -z "$(find "$usage_cache" -mmin -1 2>/dev/null)" ]; then
    touch "$usage_cache" # one refresh at a time
    (refresh_usage &) >/dev/null 2>&1
  fi
  # A weekly limit with a model scope, whose name is a word of the current model's name. Its share
  # tells how much of the overall weekly limit the model may use and has used.
  scoped=$(jq -r --arg model "$model" '
    . as $u
    | [.limits // [] | to_entries[]
        | select(.value.kind == "weekly_scoped" and .value.scope.model.display_name != null)
        | select(.value.scope.model.display_name as $m | $model | split(" ") | index($m))][0]
    | select(.)
    | .key as $index
    | ([$u.weekly_scoped_shares[]? | select(.limit_index == $index)][0]) as $share
    | [.value.percent,
       (.value.resets_at | sub("\\.[0-9]+"; "") | sub("\\+00:00$"; "Z") | fromdateiso8601),
       (if $share then $share.allowance_percent_of_weekly - $share.used_percent_of_weekly else "" end)]
    | @tsv' "$usage_cache" 2>/dev/null)
  if [ -n "$scoped" ]; then
    IFS=$'\t' read -r scoped_used scoped_resets_at scoped_left_of_week <<<"$scoped"
    # Keep the overall limit only when less of it is left than of the model's part
    if [ -z "$w_left" ] || [ -z "$scoped_left_of_week" ] ||
      awk -v all="$w_left" -v part="$scoped_left_of_week" 'BEGIN { exit !(all >= part) }'; then
      w_left=$(pct_left "$scoped_used")
      w_reset=$(fmt_countdown "$scoped_resets_at")
      w_color="$RED"
    fi
  fi
fi

# --- Layout ---
# Level 0 is the full text. Level 1 shows only the context %, without the tokens. Level 2 also drops
# the countdowns. Level 3 also drops the effort level. Level 4 also shortens each folder of the path
# to its first letter, except the last two (~/d/.c/worktrees/fix-login). The first level that fits
# wins; when no level fits, level 4 goes out with one space between items and Claude Code cuts the end.
items_at_level() {
  local level="$1" str path
  items=()
  str="${BLUE}${model:-?}${RESET}"
  [ -n "$effort" ] && [ "$level" -lt 3 ] && str="${str} ${CYAN}(${effort})${RESET}"
  items+=("$str")
  if [ -n "$cwd" ]; then
    path="${cwd/#$HOME/~}"
    # The whole path tells which worktree this is. Only level 4 shortens it.
    [ "$level" -ge 4 ] && path=$(awk -F/ -v OFS=/ '{ for (i = 1; i < NF - 1; i++) if ($i != "~") $i = substr($i, 1, 1 + ($i ~ /^\./)); print }' <<<"$path")
    str="${GREEN}${path}${RESET}"
    [ -n "$branch" ] && str="${str} ${MAGENTA}(${branch})${RESET}"
    items+=("$str")
  fi
  if [ -n "$used_pct" ]; then
    str="${CYAN}Ctx $(printf '%.0f' "$used_pct")%"
    [ "$level" -lt 1 ] && [ -n "$used_tokens" ] && [ -n "$window_size" ] &&
      str="${str} $(fmt_tokens "$used_tokens")/$(fmt_tokens "$window_size")"
    items+=("${str}${RESET}")
  fi
  if [ -n "$s_left" ] || [ -n "$w_left" ]; then
    str="Left:"
    if [ -n "$s_left" ]; then
      str="${str} ${YELLOW}S ${s_left}%"
      [ "$level" -lt 2 ] && [ -n "$s_reset" ] && str="${str} (${s_reset})"
      str="${str}${RESET}"
    fi
    if [ -n "$w_left" ]; then
      str="${str} ${w_color}W ${w_left}%"
      [ "$level" -lt 2 ] && [ -n "$w_reset" ] && str="${str} (${w_reset})"
      str="${str}${RESET}"
    fi
    items+=("$str")
  fi
}

# The visible width of a string: its length without the color codes
visible_width() {
  local plain="$1"
  while [[ "$plain" =~ $'\033'\[[0-9\;]*m ]]; do plain="${plain/"${BASH_REMATCH[0]}"/}"; done
  echo "${#plain}"
}

# Claude Code indents the status line by 2 columns. Keep 2 more free at the end, so a line that
# fills the width never wraps.
width=$(( ${COLUMNS:-80} - 4 ))
for level in 0 1 2 3 4; do
  items_at_level "$level"
  total=0
  for item in "${items[@]}"; do total=$((total + $(visible_width "$item"))); done
  gaps=$((${#items[@]} - 1))
  # Each gap is at least 2 spaces, so the items stay apart
  [ $((total + 2 * gaps)) -le "$width" ] && break
done

line="${items[0]}"
if [ "$gaps" -gt 0 ]; then
  free=$((width - total))
  [ "$free" -lt "$gaps" ] && free=$gaps
  for ((i = 1; i <= gaps; i++)); do
    # Spread the free columns evenly: the first (free % gaps) gaps get one more
    pad=$((free / gaps + (i <= free % gaps ? 1 : 0)))
    line="${line}$(printf '%*s' "$pad" '')${items[i]}"
  done
fi
printf '%s\n' "$line"
