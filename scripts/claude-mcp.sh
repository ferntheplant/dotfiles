#!/bin/bash
# Register the MCP servers for Claude Code at user scope, in ~/.claude.json. Claude Code owns that
# file, so this script uses `claude mcp` and does not write the file. A server whose registration
# already matches is skipped. A server whose registration differs is removed and added again.
#
# kvm-pilot: one server per KVM profile in ~/.config/kvm-pilot/config.toml. It is registered only
# when the keychain has the profile's password (see scripts/kvm-pilot-mcp.sh), so a machine without
# the password does not get a server that fails at every session start. The server starts read-only:
# the agent can read the screen and the state, but it cannot press keys, move the mouse, or change
# the power. To allow an action, add a KVM_PILOT_MCP_ALLOW_* variable below (see "KVM" in README.md).
set -euo pipefail

if ! command -v claude >/dev/null 2>&1; then
  echo "⏭️  claude not found, MCP servers skipped"
  exit 0
fi

CONFIG="$HOME/.claude.json"

register() {
  local name="$1" json="$2" current
  current=$(jq -c --arg n "$name" '.mcpServers[$n] // empty' "$CONFIG" 2>/dev/null || true)
  if [[ "$current" == "$(jq -c . <<<"$json")" ]]; then
    echo "✅ MCP server $name already registered"
    return
  fi
  if [[ -n "$current" ]]; then
    claude mcp remove "$name" -s user >/dev/null
  fi
  claude mcp add-json "$name" "$json" -s user >/dev/null
  echo "✅ MCP server $name registered"
}

kvm_profile=comet
if security find-generic-password -s kvm-pilot -a "$kvm_profile" >/dev/null 2>&1; then
  register kvm-pilot "$(jq -n --arg cmd "$HOME/.local/bin/kvm-pilot-mcp.sh" --arg profile "$kvm_profile" '{
    type: "stdio",
    command: $cmd,
    args: [],
    env: {KVM_PILOT_PROFILE: $profile, KVM_PILOT_MCP_READ_ONLY: "1"}
  }')"
else
  echo "⏭️  MCP server kvm-pilot skipped: the keychain has no password for $kvm_profile"
  echo "   Add it with: security add-generic-password -s kvm-pilot -a $kvm_profile -w"
fi
