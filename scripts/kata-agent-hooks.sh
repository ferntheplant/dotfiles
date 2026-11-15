#!/bin/bash
set -euo pipefail

# Install Kata's agent hooks for the agents on this machine. install.sh runs it; it is safe to run
# again, because Kata writes nothing when the installed hooks are current.
#
# The hooks give an agent Kata's working contract when a session starts in a Kata workspace (a repo
# with a .kata.toml), and mark the session's issue as needing attention. Kata generates them, so
# they are not in this repo. The client config (daemon, transcripts) is the kata stow package.

if ! command -v kata >/dev/null 2>&1; then
	echo "⚠️  kata not found; skipped the Kata agent hooks (it is in .Nanobrewfile)"
	exit 0
fi

# Claude Code: Kata adds its hooks to ~/.claude/settings.json. claude-settings.sh keeps hook groups
# that are not in the base file, so a later merge leaves them in place.
if command -v claude >/dev/null 2>&1; then
	kata agent-hook install claude --executable kata
else
	echo "⚠️  claude not found; run this script again after you install Claude Code"
fi
