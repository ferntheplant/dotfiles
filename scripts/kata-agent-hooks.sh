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

# Pi: Kata writes one extension file, ~/.pi/agent/extensions/kata.js, which Pi loads by itself. It
# imports only Node built-ins, so it needs no install step. It needs Pi 0.99.1 or newer.
if command -v pi >/dev/null 2>&1; then
	kata agent-hook install pi --executable kata
else
	echo "⚠️  pi not found; run 'mise install', then run this script again for the Pi hooks"
fi
