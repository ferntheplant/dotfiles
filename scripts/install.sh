#!/bin/bash
set -euo pipefail

# Link the dotfiles into $HOME with stow, and on the desktop and work profiles write the macOS
# defaults and the Handy settings. Run it again after a pull: it is safe to repeat.
#
# The profile in the gitignored ~/dotfiles/.work/profile selects the packages:
#   desktop (default)  every package
#   server             no packages for desktop-only apps (lil-homie)
#   infra              as server, and no agent config: no Claude Code, Pi, Kata, or skills
#                      (micro-homie, which runs the homielab services; agents reach it through Rex)
#   work               as desktop, and no Pi or Kata, which are for the homelab (the Pillar laptop)
# On Linux, the packages in MACOS_ONLY are skipped too. A package that the profile skips is
# unstowed, so a machine that changes its profile loses the links of that package.

fixed_location="$HOME/dotfiles"
profile="$(cat "$fixed_location/.work/profile" 2>/dev/null || echo desktop)"
# The work profile gets the desktop apps
desktop=false
[[ "$profile" = "desktop" || "$profile" = "work" ]] && desktop=true

# Directories that are not stow packages
IGNORE_LIST=("handy" "node_modules" "themes" "tinycast" "vorssaint")
# Packages for apps that the server and infra profiles do not install
DESKTOP_ONLY=("kanata" "librewolf" "paneru" "zed")
# Packages for agents, which the infra profile does not install
AGENT_ONLY=("claude" "kata" "kvm-pilot" "pi")
# Packages for the homelab's agent tools, which the work profile does not install
HOMELAB_ONLY=("kata" "pi")
# Packages for apps that have no Linux build (lil-homie is a Mac server, so it keeps them)
MACOS_ONLY=("ghostty")
if [[ "$(uname -s)" == "Linux" ]]; then
	DESKTOP_ONLY+=("${MACOS_ONLY[@]}")
fi
# Packages that get one link for each folder in .config, not one link for each file. Fresh saves
# its config with a temporary file and a rename, and a rename replaces a link to a file with a
# plain file. With a link to the folder, Fresh's saves land in the package.
FOLDED=("fresh")

cd "$fixed_location"

# Stow a FOLDED package. Stow links a folder only when the target does not exist, so a plain folder
# that the app made before the first install moves to <folder>.pre-dotfiles first.
stow_folded() {
	local pkg="$1" dir target
	for dir in "$fixed_location/$pkg"/.config/*/; do
		target="$HOME/.config/$(basename "$dir")"
		if [[ -d "$target" && ! -L "$target" ]]; then
			if [[ -e "$target.pre-dotfiles" ]]; then
				echo "⚠️  skipped $pkg: move $target or $target.pre-dotfiles away, then run again"
				return 0
			fi
			mv "$target" "$target.pre-dotfiles"
			echo "📦 moved $target to $target.pre-dotfiles"
		fi
	done
	stow "$pkg"
}

for subdir in "$fixed_location"/*; do
	if [ -d "$subdir" ]; then
		subdir_name=$(basename "$subdir")
		if [ "$subdir_name" = "scripts" ]; then
			mkdir -p "$HOME/.local/bin"
			stow -t "$HOME/.local/bin" --ignore="install" scripts
		elif [[ " ${IGNORE_LIST[*]} " == *" ${subdir_name} "* ]]; then
			continue
		elif [[ "$desktop" = false && " ${DESKTOP_ONLY[*]} " == *" ${subdir_name} "* ]] ||
			[[ "$profile" = "infra" && " ${AGENT_ONLY[*]} " == *" ${subdir_name} "* ]] ||
			[[ "$profile" = "work" && " ${HOMELAB_ONLY[*]} " == *" ${subdir_name} "* ]]; then
			stow -D --no-folding "$subdir_name"
		elif [[ " ${FOLDED[*]} " == *" ${subdir_name} "* ]]; then
			stow_folded "$subdir_name"
		else
			stow --no-folding "$subdir_name"
		fi
	fi
done

# Remove links into ~/dotfiles whose file was deleted or moved
{
	find "$HOME" -maxdepth 1 -type l 2>/dev/null
	find "$HOME/.config" "$HOME/.local/bin" "$HOME/.claude" "$HOME/.pi" "$HOME/.zsh" -name node_modules -prune -o -type l -print 2>/dev/null
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

# Agent config: skills (in the hidden .agents/, which the loop above skips), Claude and Pi
# settings, Claude's MCP servers, and Kata hooks. The work profile gets no Pi and no Kata.
if [[ "$profile" != "infra" ]]; then
	"$fixed_location/scripts/link-skills.sh"
	"$fixed_location/scripts/claude-settings.sh"
	"$fixed_location/scripts/claude-mcp.sh"
	if [[ "$profile" != "work" ]]; then
		"$fixed_location/scripts/pi-settings.sh"
		"$fixed_location/scripts/kata-agent-hooks.sh"
	fi
fi

# mise has no profiles, so the work profile turns Pi off in a config file of its own
mise_work="$HOME/.config/mise/conf.d/work.toml"
if [[ "$profile" = "work" ]]; then
	mkdir -p "$(dirname "$mise_work")"
	printf '# Written by ~/dotfiles/scripts/install.sh for the work profile\n[settings]\ndisable_tools = ["pi"]\n' > "$mise_work"
else
	rm -f "$mise_work"
fi

# Desktop apps: macOS, Hidden Bar, and Sill defaults, Handy settings
if [[ "$desktop" = true ]]; then
	"$fixed_location/scripts/macos-defaults.sh"
	"$fixed_location/scripts/handy-settings.sh" import
fi
