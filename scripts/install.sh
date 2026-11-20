#!/bin/bash
set -euo pipefail

# Link the dotfiles into $HOME with stow, and on the desktop and work profiles write the macOS
# defaults and the Handy settings. Run it again after a pull: it is safe to repeat.
#
# The profile in the gitignored ~/dotfiles/.work/profile selects the packages:
#   desktop (default)  every package
#   server             no packages for desktop-only apps (a Mac server)
#   infra              as server, and no agent config: no Claude Code, opencode, fx, or skills
#                      (a Linux server that runs services; agents reach it through Rex)
#   work               as desktop (the Pillar laptop)
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
AGENT_ONLY=("claude" "fx" "kvm-pilot" "opencode")
# Packages for apps that have no Linux build (the server profile is for a Mac, so it keeps them)
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
			[[ "$profile" = "infra" && " ${AGENT_ONLY[*]} " == *" ${subdir_name} "* ]]; then
			stow -D --no-folding "$subdir_name"
		elif [[ " ${FOLDED[*]} " == *" ${subdir_name} "* ]]; then
			stow_folded "$subdir_name"
		else
			stow --no-folding "$subdir_name"
		fi
	fi
done

# Remove links into ~/dotfiles whose file was deleted or moved
# Include legacy ~/.pi and ~/.omp only to clean up dangling dotfiles links; leave their runtime data alone.
{
	find "$HOME" -maxdepth 1 -type l 2>/dev/null
	find "$HOME/.config" "$HOME/.local/bin" "$HOME/.claude" "$HOME/.pi" "$HOME/.omp" "$HOME/.fx" "$HOME/.zsh" -name node_modules -prune -o -type l -print 2>/dev/null
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

# Agent config: skills and instructions (in the hidden .agents/, which the loop above skips), harness
# settings, and Claude's MCP servers.
if [[ "$profile" != "infra" ]]; then
	"$fixed_location/scripts/link-agents.sh"
	"$fixed_location/scripts/claude-settings.sh"
	"$fixed_location/scripts/opencode-settings.sh"
	"$fixed_location/scripts/fx-settings.sh"
	"$fixed_location/scripts/claude-mcp.sh"
fi

# px0 is on every profile, so its settings merge outside the agent block
"$fixed_location/scripts/px0-settings.sh"

# Remove only the exact legacy Pi override generated here, on every profile. Preserve user edits
# and symlinks: mise no longer needs a work-profile override for a tool we do not install.
mise_work="$HOME/.config/mise/conf.d/work.toml"
if [[ -f "$mise_work" && ! -L "$mise_work" ]] &&
	cmp -s "$mise_work" <(printf '# Written by ~/dotfiles/scripts/install.sh for the work profile\n[settings]\ndisable_tools = ["pi"]\n'); then
	rm "$mise_work"
fi

# Desktop apps: macOS, Hidden Bar, and Sill defaults, Handy settings
if [[ "$desktop" = true ]]; then
	"$fixed_location/scripts/macos-defaults.sh"
	"$fixed_location/scripts/handy-settings.sh" import
fi
