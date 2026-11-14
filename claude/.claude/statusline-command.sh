#!/bin/bash
# Claude Code status line, in two lines:
#   1. the model and its effort level, the working directory, and the git branch
#   2. the context window usage (tokens and %), and the subscription usage left with the time until
#      it resets, for the 5-hour and 7-day windows. When the model has its own weekly limit (for
#      example Fable), the usage left of that limit too.
#
# Claude Code sends the 5-hour and 7-day windows on stdin, but not the per-model weekly limits.
# Those come from the usage API that Claude Code's /usage screen reads. The script keeps the reply
# in a cache file for 60 seconds and refreshes it in the background, so the status line does not
# wait for the network. The API is not documented: if it fails or changes, the model stat goes away.

input=$(cat)

RESET='\033[0m'
BLUE='\033[34m'
GREEN='\033[32m'
CYAN='\033[36m'
YELLOW='\033[33m'
MAGENTA='\033[35m'
RED='\033[31m'

field() { jq -r "$1 // empty" <<<"$input"; }

# --- Model, effort level, working directory, and git branch ---
model=$(field '.model.display_name')
effort=$(field '.effort.level')
cwd=$(field '.workspace.current_dir')
[ -n "$cwd" ] || cwd=$(field '.cwd')
cwd_fmt="${cwd/#$HOME/~}"
branch=""
if [ -n "$cwd" ]; then
  branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null)
  # A detached HEAD has no branch name: show the short commit
  [ -n "$branch" ] || branch=$(git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null)
fi

where_str="${BLUE}${model:-?}${RESET}"
[ -n "$effort" ] && where_str="${where_str} ${CYAN}(${effort})${RESET}"
where_str="${where_str} ${GREEN}${cwd_fmt}${RESET}"
[ -n "$branch" ] && where_str="${where_str} ${MAGENTA} ${branch}${RESET}"

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

if [ -n "$used_tokens" ] && [ -n "$window_size" ] && [ -n "$used_pct" ]; then
  ctx_str=$(printf "${CYAN}Ctx %s/%stok (%.0f%%)${RESET}" "$(fmt_tokens "$used_tokens")" "$(fmt_tokens "$window_size")" "$used_pct")
else
  ctx_str="${CYAN}Ctx N/A${RESET}"
fi

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

# "<label> left <100 - used>% (<countdown>)" in a color
fmt_limit() {
  local color="$1" label="$2" used="$3" resets_at="$4" str
  str="${label} left $(awk -v u="$used" 'BEGIN { printf "%.0f", 100 - u }')%"
  [ -n "$resets_at" ] && str="${str} ($(fmt_countdown "$resets_at"))"
  printf '%s%s%s' "$color" "$str" "$RESET"
}

limits=()
five_used=$(field '.rate_limits.five_hour.used_percentage')
week_used=$(field '.rate_limits.seven_day.used_percentage')
[ -n "$five_used" ] && limits+=("$(fmt_limit "$YELLOW" 5h "$five_used" "$(field '.rate_limits.five_hour.resets_at')")")
[ -n "$week_used" ] && limits+=("$(fmt_limit "$MAGENTA" 7d "$week_used" "$(field '.rate_limits.seven_day.resets_at')")")

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
  # A weekly limit with a model scope, whose name is a word of the current model's name
  scoped=$(jq -r --arg model "$model" '
    [.limits[]? | select(.kind == "weekly_scoped" and .scope.model.display_name != null)
      | select(.scope.model.display_name as $m | $model | split(" ") | index($m))][0]
    | select(.) | [.scope.model.display_name, .percent, (.resets_at | sub("\\.[0-9]+"; "") | sub("\\+00:00$"; "Z") | fromdateiso8601)]
    | @tsv' "$usage_cache" 2>/dev/null)
  if [ -n "$scoped" ]; then
    IFS=$'\t' read -r scoped_name scoped_used scoped_resets_at <<<"$scoped"
    limits+=("$(fmt_limit "$RED" "$scoped_name 7d" "$scoped_used" "$scoped_resets_at")")
  fi
fi

if [ ${#limits[@]} -eq 0 ]; then
  rl_str="${YELLOW}Rate limits N/A${RESET}"
else
  rl_str=$(printf '%s  ' "${limits[@]}")
  rl_str="${rl_str%  }"
fi

printf "%b\n%b  |  %b\n" "$where_str" "$ctx_str" "$rl_str"
