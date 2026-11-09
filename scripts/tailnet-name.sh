#!/bin/bash
# Print this machine's Tailscale machine name, for example personal-macbook. It is the host part of
# the agent identity (see "Agent identity" in README.md). On a Mac, the CLI is inside the Tailscale
# app when `tailscale` is not on PATH. Without Tailscale, it prints `hostname -s` in lowercase.
set -uo pipefail

for cli in tailscale /Applications/Tailscale.app/Contents/MacOS/Tailscale; do
  command -v "$cli" >/dev/null 2>&1 || continue
  name=$("$cli" status --json 2>/dev/null | jq -r '.Self.DNSName // empty | split(".")[0]' 2>/dev/null)
  if [[ -n "$name" ]]; then
    echo "$name"
    exit 0
  fi
done
hostname -s | tr '[:upper:]' '[:lower:]'
