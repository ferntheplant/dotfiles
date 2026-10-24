#!/bin/bash
# Claude Code status line
# Shows: context window usage (tokens + %) and subscription rate-limit
# usage remaining, plus time until reset, for the 5-hour and 7-day windows.

input=$(cat)

RESET='\033[0m'
CYAN='\033[36m'
YELLOW='\033[33m'
MAGENTA='\033[35m'

# --- Context window usage ---
used_tokens=$(echo "$input" | jq -r '.context_window.total_input_tokens // empty')
window_size=$(echo "$input" | jq -r '.context_window.context_window_size // empty')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

fmt_tokens() {
  awk -v n="$1" 'BEGIN {
    if (n >= 1000000) printf "%.1fM", n/1000000
    else if (n >= 1000) printf "%.0fk", n/1000
    else printf "%d", n
  }'
}

if [ -n "$used_tokens" ] && [ -n "$window_size" ] && [ -n "$used_pct" ]; then
  used_tokens_fmt=$(fmt_tokens "$used_tokens")
  window_size_fmt=$(fmt_tokens "$window_size")
  ctx_str=$(printf "${CYAN}Ctx %s/%stok (%.0f%%)${RESET}" "$used_tokens_fmt" "$window_size_fmt" "$used_pct")
else
  ctx_str="${CYAN}Ctx N/A${RESET}"
fi

# --- Subscription rate limit usage remaining ---
five_used=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
week_used=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
five_resets_at=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
week_resets_at=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

fmt_countdown() {
  local resets_at="$1"
  local now secs
  now=$(date +%s)
  secs=$((resets_at - now))
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

rl_str=""
if [ -n "$five_used" ]; then
  five_remaining=$(printf "%.0f" "$(echo "100 - $five_used" | bc)")
  five_reset_str=""
  if [ -n "$five_resets_at" ]; then
    five_reset_str=" (resets $(fmt_countdown "$five_resets_at"))"
  fi
  rl_str="${YELLOW}5h left ${five_remaining}%${five_reset_str}${RESET}"
fi
if [ -n "$week_used" ]; then
  week_remaining=$(printf "%.0f" "$(echo "100 - $week_used" | bc)")
  week_reset_str=""
  if [ -n "$week_resets_at" ]; then
    week_reset_str=" (resets $(fmt_countdown "$week_resets_at"))"
  fi
  if [ -n "$rl_str" ]; then
    rl_str="${rl_str}  ${MAGENTA}7d left ${week_remaining}%${week_reset_str}${RESET}"
  else
    rl_str="${MAGENTA}7d left ${week_remaining}%${week_reset_str}${RESET}"
  fi
fi

if [ -z "$rl_str" ]; then
  rl_str="${YELLOW}Rate limits N/A${RESET}"
fi

printf "%b  |  %b\n" "$ctx_str" "$rl_str"
