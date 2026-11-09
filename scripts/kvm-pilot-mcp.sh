#!/bin/bash
# Start the kvm-pilot MCP server for one KVM profile. The profile is KVM_PILOT_PROFILE, from the
# Claude Code registration in scripts/claude-mcp.sh. The profile itself is in
# ~/.config/kvm-pilot/config.toml (the kvm-pilot stow package).
#
# The KVM password is in the macOS keychain, not in a file: service kvm-pilot, account <profile>.
# This script puts it in KVM_PILOT_PASSWD for the server process only. Add it once with:
#   security add-generic-password -s kvm-pilot -a <profile> -w
set -euo pipefail

profile="${KVM_PILOT_PROFILE:?KVM_PILOT_PROFILE is not set}"

if ! KVM_PILOT_PASSWD=$(security find-generic-password -s kvm-pilot -a "$profile" -w 2>/dev/null); then
  echo "kvm-pilot-mcp.sh: the keychain has no password for $profile." >&2
  echo "Add it with: security add-generic-password -s kvm-pilot -a $profile -w" >&2
  exit 1
fi
export KVM_PILOT_PASSWD

# mise installs kvm-pilot (pypi:kvm-pilot in the global mise config)
mise_bin="$(command -v mise || echo "$HOME/.local/bin/mise")"
exec "$mise_bin" exec -- kvm-pilot-mcp "$@"
