#!/bin/bash
# SessionStart hook: record the conversation that this Claude Code runs in its Rex pane, so that the
# pane's shell can resume it after the Rex server restarts (see "Rex resume" in ~/dotfiles/README.md).
#
# It writes one file for each pane, ~/.local/state/rex-resume/<REX_BLOCK>, which holds the
# conversation ID, the directory, and the transcript path, separated by tabs. ~/.zsh/rex-resume.zsh reads the file when
# Rex restores the pane, and removes it when the shell prompt comes back after Claude exits.
#
# The hook runs as a child of the Claude process. It records nothing for a `claude -p` run (for
# example one that an agent starts in the pane) or a subagent, because those do not hold the pane.
set -uo pipefail

[[ -n "${REX_BLOCK:-}" ]] || exit 0
# A `claude -p` run does not hold the pane
[[ " $(ps -o args= -p "$PPID" 2>/dev/null) " =~ \ (-p|--print)\  ]] && exit 0

input=$(cat)
# Subagents and in-process teammates report an agent_id
[[ -n "$(jq -r '.agent_id // empty' <<<"$input" 2>/dev/null)" ]] && exit 0
record=$(jq -r 'select(.session_id and .cwd) | [.session_id, .cwd, .transcript_path // ""] | @tsv' \
  <<<"$input" 2>/dev/null)
[[ -n "$record" ]] || exit 0

dir="${XDG_STATE_HOME:-$HOME/.local/state}/rex-resume"
mkdir -p "$dir" || exit 0
tmp=$(mktemp "$dir/.tmp.XXXXXX") || exit 0
printf '%s\n' "$record" >"$tmp" && mv -f "$tmp" "$dir/$REX_BLOCK"
# Panes closed while Claude ran leave a file behind. Each SessionStart writes the file again.
find "$dir" -type f -mtime +30 -delete 2>/dev/null
exit 0
