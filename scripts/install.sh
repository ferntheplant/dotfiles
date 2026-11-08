#!/bin/bash
set -euo pipefail

# Link the dotfiles into $HOME with stow, and on the desktop profile write the macOS defaults
# and the Handy settings. Run it again after a pull: it is safe to repeat.
#
# The profile in the gitignored ~/dotfiles/.work/profile selects the packages:
#   desktop (default)  every package
#   server             no packages for desktop-only apps (lil-homie)
#   infra              as server, and no agent config: no Claude Code, OpenCode, Kata, or skills
#                      (micro-homie, which runs the homielab services; agents reach it through Rex)
# On Linux, the packages in MACOS_ONLY are skipped too.

fixed_location="$HOME/dotfiles"
profile="$(cat "$fixed_location/.work/profile" 2>/dev/null || echo desktop)"

# Directories that are not stow packages
IGNORE_LIST=("handy" "node_modules" "themes" "tinycast" "vorssaint")
# Packages for apps that the server and infra profiles do not install
DESKTOP_ONLY=("kanata" "librewolf" "paneru" "zed")
# Packages for agents, which the infra profile does not install
AGENT_ONLY=("claude" "kata" "opencode")
# Packages for apps that have no Linux build (lil-homie is a Mac server, so it keeps them)
MACOS_ONLY=("ghostty")
if [[ "$(uname -s)" == "Linux" ]]; then
	DESKTOP_ONLY+=("${MACOS_ONLY[@]}")
fi

cd "$fixed_location"

for subdir in "$fixed_location"/*; do
	if [ -d "$subdir" ]; then
		subdir_name=$(basename "$subdir")
		if [ "$subdir_name" = "scripts" ]; then
			mkdir -p "$HOME/.local/bin"
			stow -t "$HOME/.local/bin" --ignore="install" scripts
		elif [[ " ${IGNORE_LIST[*]} " == *" ${subdir_name} "* ]]; then
			continue
		elif [[ "$profile" != "desktop" && " ${DESKTOP_ONLY[*]} " == *" ${subdir_name} "* ]]; then
			continue
		elif [[ "$profile" = "infra" && " ${AGENT_ONLY[*]} " == *" ${subdir_name} "* ]]; then
			continue
		else
			stow --no-folding "$subdir_name"
		fi
	fi
done

# Remove links into ~/dotfiles whose file was deleted or moved
{
	find "$HOME" -maxdepth 1 -type l 2>/dev/null
	find "$HOME/.config" "$HOME/.local/bin" "$HOME/.claude" "$HOME/.zsh" -name node_modules -prune -o -type l -print 2>/dev/null
} | while read -r link; do
	if [[ "$(readlink "$link")" == *dotfiles/* && ! -e "$link" ]]; then
		rm "$link"
		echo "🗑️  removed dangling link $link"
	fi
done

# fzf-tab is not packaged; .zshrc sources it from ~/.zsh
if [[ ! -d "$HOME/.zsh/fzf-tab" ]]; then
	git clone --depth 1 https://github.com/Aloxaf/fzf-tab "$HOME/.zsh/fzf-tab"
fi

# Agent config: skills (in the hidden .agents/, which the loop above skips), Claude settings,
# and Kata hooks
if [[ "$profile" != "infra" ]]; then
	"$fixed_location/scripts/link-skills.sh"
	"$fixed_location/scripts/claude-settings.sh"
	"$fixed_location/scripts/kata-agent-hooks.sh"
fi

# Desktop apps: macOS, Hidden Bar, and Sill defaults, Handy settings
if [[ "$profile" = "desktop" ]]; then
	"$fixed_location/scripts/macos-defaults.sh"
	"$fixed_location/scripts/handy-settings.sh" import
fi
