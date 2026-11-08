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

# OpenCode: Kata writes the plugin package to ~/.config/opencode/plugins/kata-user/, which OpenCode
# loads by itself because it is in plugins/. Kata also adds the plugin's absolute path to a config
# file. --config points that at a file that OpenCode does not read, so the stowed opencode.jsonc
# does not get a path for one machine, and OpenCode does not load the plugin twice.
if command -v opencode >/dev/null 2>&1; then
	opencode_dir="$HOME/.config/opencode"
	kata agent-hook install opencode --executable kata --config "$opencode_dir/kata-registration.json"
	# The plugin imports @opencode/plugin. OpenCode does not install a local plugin's dependencies.
	if command -v bun >/dev/null 2>&1; then
		bun install --silent --cwd "$opencode_dir/plugins/kata-user"
	else
		echo "⚠️  bun not found; run 'bun install' in $opencode_dir/plugins/kata-user after 'mise install'"
	fi
fi
