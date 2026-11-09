#!/bin/bash
set -euo pipefail

# Install the nanobrew packages that this machine's profile selects. Safe to run again.
#   desktop  .Nanobrewfile and .Nanobrewfile.desktop (macOS only)
#   server   .Nanobrewfile only (lil-homie, macOS)
#   infra    .Nanobrewfile without the agent formulas (micro-homie, Linux)
#   work     as desktop, without the homelab's agent formulas (the Pillar laptop, macOS)
#
# On Linux, the casks and the formulas in MACOS_ONLY are left out. The README tells how a Linux
# server gets the casks' tools.

fixed_location="$HOME/dotfiles"
profile="$(cat "$fixed_location/.work/profile" 2>/dev/null || echo desktop)"

# Formulas that nanobrew does not install correctly on Linux:
#   mole  has no Linux build
#   stow  the bottle does not find its Perl modules after relocation; apt installs stow
#   zmx   nanobrew ignores the tap's on_linux block and installs the macOS binary; mise installs
#         zmx (os = ["linux"] in the mise config)
MACOS_ONLY=("mole" "stow" "zmx")
# Linux-only dependencies of .Nanobrewfile formulas. Nanobrew installs the dependencies that
# Homebrew lists for macOS only, so it skips these:
#   alsa-lib, libxcb  ffmpeg
LINUX_DEPS=("alsa-lib" "libxcb")
# Formulas for agents, which the infra profile does not install
AGENT_ONLY=("kata")
# Formulas for the homelab's agent tools, which the work profile does not install
HOMELAB_ONLY=("kata")

bundle="$(mktemp)"
trap 'rm -f "$bundle"' EXIT

if [[ "$(uname -s)" != "Linux" ]]; then
	if [[ "$profile" = "work" ]]; then
		# Drop each formula in HOMELAB_ONLY (with or without a tap prefix), and keep every other line
		awk -F'"' -v skip="${HOMELAB_ONLY[*]}" '
			BEGIN { n = split(skip, s, " "); for (i = 1; i <= n; i++) drop[s[i]] = 1 }
			{ short = $2; sub(/.*\//, "", short) }
			!(/^brew "/ && short in drop)
		' "$fixed_location/.Nanobrewfile" > "$bundle"
		nb bundle install "$bundle"
	else
		nb bundle install "$fixed_location/.Nanobrewfile"
	fi
	if [[ "$profile" = "desktop" || "$profile" = "work" ]]; then
		nb bundle install "$fixed_location/.Nanobrewfile.desktop"
	fi
	exit 0
fi

if [[ "$profile" != "infra" ]]; then
	echo "❌ Linux supports the infra profile only: echo infra > $fixed_location/.work/profile" >&2
	exit 1
fi

# Keep the brew lines only, and drop each formula in MACOS_ONLY and AGENT_ONLY (with or without a
# tap prefix)
awk -F'"' -v skip="${MACOS_ONLY[*]} ${AGENT_ONLY[*]}" '
	BEGIN { n = split(skip, s, " "); for (i = 1; i <= n; i++) macos[s[i]] = 1 }
	/^brew "/ { short = $2; sub(/.*\//, "", short); if (!(short in macos)) print }
' "$fixed_location/.Nanobrewfile" > "$bundle"

for dep in "${LINUX_DEPS[@]}"; do
	echo "brew \"$dep\"" >> "$bundle"
done

nb bundle install "$bundle"
