#!/bin/bash
# SessionStart hook: give Claude its agent identity, <model>+claude@<host>, for example
# opus-5-5+claude@lil-homie (see "Agent identity" in ~/dotfiles/README.md).
#
# The hook writes AGENT_IDENTITY to $CLAUDE_ENV_FILE for later Bash commands and subagents.
# It also tells Claude to use the identity in a Co-Authored-By commit trailer.
# The base settings turn off Claude Code's own trailer (attribution.commit).
#
# The host is the Tailscale machine name. claude-settings.sh puts it in AGENT_IDENTITY,
# so the hook does not run tailscale at each session start.
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
  host="${AGENT_IDENTITY:-}"
  host="${host##*@}"
  [[ -n "$host" && "$host" != "${AGENT_IDENTITY:-}" ]] || host=$("$HOME/dotfiles/scripts/tailnet-name.sh")
  identity="$model+claude@$host"
  [[ -n "${CLAUDE_ENV_FILE:-}" ]] && printf 'export AGENT_IDENTITY=%q\n' "$identity" >> "$CLAUDE_ENV_FILE"
else
  identity="${AGENT_IDENTITY:-}"
fi

[[ -n "$identity" ]] || exit 0
context="Your agent identity is $identity. End each git commit message with this trailer, in place of any other Co-Authored-By trailer for yourself:
Co-Authored-By: $identity <$identity>"
jq -n --arg context "$context" '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $context}}'
