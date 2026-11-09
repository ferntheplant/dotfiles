#!/bin/bash
# SessionStart hook: give Claude its agent identity, <model>+claude@<host>, for example
# opus-5-5+claude@lil-homie (see "Agent identity" in ~/dotfiles/README.md).
#
# - Kata: it writes KATA_AUTHOR to $CLAUDE_ENV_FILE, which reaches every later Bash command, also in
#   subagents. Hooks do not get it: they keep the fallback that claude-settings.sh puts in the env
#   key, <model setting>+claude@<host>.
# - Commits: it tells Claude to end each commit message with a Co-Authored-By trailer for the
#   identity. The base settings turn off Claude Code's own trailer (attribution.commit).
#
# SessionStart has no model after /clear and in `claude -p`. Then the hook takes the --model value
# from Claude's command line (an alias such as haiku), or else keeps the fallback. A /model switch
# keeps the identity of the session start.
set -euo pipefail

model=$(jq -r '.model // empty' 2>/dev/null || true)
if [[ -z "$model" ]]; then
  # `claude -p --model haiku`: take the --model value from Claude's command line
  model=$(ps -o args= -p "$PPID" 2>/dev/null | sed -nE 's/.*--model[= ]([^ ]+).*/\1/p' || true)
fi
if [[ -n "$model" ]]; then
  # claude-opus-5-5[1m] -> opus-5-5
  model=$(printf '%s' "$model" | tr '[:upper:]' '[:lower:]' | sed -E 's|.*/||; s/\[.*\]$//; s/^claude-//')
  identity="$model+claude@$(hostname -s)"
  [[ -n "${CLAUDE_ENV_FILE:-}" ]] && printf 'export KATA_AUTHOR=%q\n' "$identity" >> "$CLAUDE_ENV_FILE"
else
  identity="${KATA_AUTHOR:-}"
fi

[[ -n "$identity" ]] || exit 0
jq -n --arg id "$identity" '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext:
  "Your agent identity is \($id). It is your Kata actor (KATA_AUTHOR). End each git commit message with this trailer, in place of any other Co-Authored-By trailer for yourself:\nCo-Authored-By: \($id) <\($id)>"}}'
