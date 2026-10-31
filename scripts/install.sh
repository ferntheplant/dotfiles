#!/bin/bash
set -euo pipefail

# Link the dotfiles into $HOME with stow, and on the desktop profile write the macOS defaults
# and the Handy settings. Run it again after a pull: it is safe to repeat.
#
# The profile in the gitignored ~/dotfiles/.work/profile selects the packages:
#   desktop (default)  every package
#   server             no packages for desktop-only apps (lil-homie)

fixed_location="$HOME/dotfiles"
profile="$(cat "$fixed_location/.work/profile" 2>/dev/null || echo desktop)"

# Directories that are not stow packages
IGNORE_LIST=("handy" "node_modules" "themes" "tinycast" "vorssaint")
# Packages for apps that the server profile does not install
DESKTOP_ONLY=("aerospace" "kanata" "librewolf" "linearmouse" "zed")

cd "$fixed_location"

for subdir in "$fixed_location"/*; do
	if [ -d "$subdir" ]; then
		subdir_name=$(basename "$subdir")
		if [ "$subdir_name" = "scripts" ]; then
			mkdir -p "$HOME/.local/bin"
			stow -t "$HOME/.local/bin" --ignore="install" scripts
		elif [[ " ${IGNORE_LIST[*]} " == *" ${subdir_name} "* ]]; then
			continue
		elif [[ "$profile" = "server" && " ${DESKTOP_ONLY[*]} " == *" ${subdir_name} "* ]]; then
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

# Skills live in the hidden .agents/, which the loop above skips
"$fixed_location/scripts/link-skills.sh"
"$fixed_location/scripts/claude-settings.sh"

# Desktop apps: macOS and Hidden Bar defaults, Handy settings
if [[ "$profile" != "server" ]]; then
	"$fixed_location/scripts/macos-defaults.sh"
	"$fixed_location/scripts/handy-settings.sh" import
fi
