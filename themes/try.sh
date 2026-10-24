#!/bin/bash
# Try a theme without touching any real config.
#
#   themes/try.sh <theme> [pair]    open a separate Ghostty instance where everything uses <theme>
#   themes/try.sh <theme> build [pair]  only build the sandbox; enter it with ZDOTDIR=... zsh
#   themes/try.sh <theme> clean     remove everything this script created for <theme>
#
# <theme> is a folder here with a built dist/ (node themes/build.mjs <theme>). [pair] is one of
# the theme.json "pairs" (defaults to "defaultPair"); the sandbox follows macOS light/dark
# with that pair's variants.
#
# Real configs are only read, never written. The sandbox shell gets copies with the theme lines
# swapped, selected via env vars and flags (STARSHIP_CONFIG, BAT_THEME, GIT_PAGER, hx/leaf
# XDG_CONFIG_HOME, btop -c). Quit that Ghostty instance and you're back to normal.
#
# One exception: delta only reads syntax themes from bat's default cache, so the theme's
# .tmTheme files are symlinked into ~/.config/bat/themes and the cache is rebuilt. That only
# adds themes; nothing outside the sandbox selects them. `clean` undoes it.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"

usage() {
	echo "Usage: $0 <theme> [pair|build|clean]" >&2
	echo "Themes: $(cd "$ROOT" && ls -d */dist 2>/dev/null | sed 's|/dist||' | tr '\n' ' ')" >&2
	exit 1
}

[[ $# -ge 1 ]] || usage
SLUG="$1"
ACTION="${2:-}"
DIST="$ROOT/$SLUG/dist"
[[ -f "$DIST/pairs.sh" ]] || { echo "No $SLUG/dist/pairs.sh; run: node themes/build.mjs $SLUG" >&2; exit 1; }
# shellcheck source=/dev/null
source "$DIST/pairs.sh"

SANDBOX="$HOME/.cache/theme-try/$SLUG"
BAT_THEMES="$HOME/.config/bat/themes"

clean() {
	for f in "$DIST"/bat/.config/bat/themes/*.tmTheme; do
		rm -f "$BAT_THEMES/$(basename "$f")"
	done
	bat cache --build >/dev/null
	rm -rf "$SANDBOX"
	echo "Removed $SANDBOX and the $SLUG bat themes."
}

# Replace the value of a `key = ...` line (first match) in a copy of a config file.
swap_line() { # <file> <sed ERE for the line start> <replacement line>
	sed -E "s|^$2.*|$3|" "$1"
}

build() {
	local pair="$1"
	local dark_var="THEME_PAIR_${pair}_dark" light_var="THEME_PAIR_${pair}_light"
	[[ -n "${!dark_var:-}" ]] || { echo "$SLUG has no pair \"$pair\" (pairs: $THEME_PAIRS)" >&2; exit 1; }

	rm -rf "$SANDBOX"
	mkdir -p "$SANDBOX/zdot" "$BAT_THEMES"

	ln -sf "$DIST"/bat/.config/bat/themes/*.tmTheme "$BAT_THEMES/"
	bat cache --build >/dev/null

	local mode stem stem_us xdg
	for mode in dark light; do
		local var="THEME_PAIR_${pair}_${mode}"
		stem="${!var}"
		stem_us="${stem//-/_}"
		xdg="$SANDBOX/xdg-$mode"

		{
			swap_line "$HOME/.config/starship/starship.toml" 'palette = ' "palette = \"$stem\""
			echo
			cat "$DIST/snippets/starship-palettes.toml"
		} >"$SANDBOX/starship-$mode.toml"

		# helix: own config dir so the themes don't need installing
		mkdir -p "$xdg/helix"
		swap_line "$HOME/.config/helix/config.toml" 'theme = ' "theme = \"$stem_us\"" >"$xdg/helix/config.toml"
		ln -s "$HOME/.config/helix/languages.toml" "$xdg/helix/languages.toml"
		ln -s "$DIST/helix/.config/helix/themes" "$xdg/helix/themes"

		mkdir -p "$xdg/leaf"
		{
			swap_line "$HOME/.config/leaf/config.toml" 'theme = ' "theme = \"$stem\""
			echo
			cat "$DIST/snippets/leaf-themes.toml"
		} >"$xdg/leaf/config.toml"

		# btop writes its config back on exit, which is fine: it's the copy
		swap_line "$HOME/.config/btop/btop.conf" 'color_theme = ' \
			"color_theme = \"$DIST/btop/.config/btop/themes/$stem.theme\"" >"$SANDBOX/btop-$mode.conf"

		# delta: real gitconfig first, then the theme's feature on top
		cat >"$SANDBOX/delta-$mode.gitconfig" <<-EOF2
			[include]
			    path = ~/.gitconfig
			[include]
			    path = $DIST/snippets/delta.gitconfig
			[delta]
			    features = $stem
		EOF2

		printf '%s\n' "$stem" >"$SANDBOX/stem-$mode"
	done

	cat >"$SANDBOX/env.zsh" <<-EOF2
		# Loaded after ~/.zshrc in the sandbox shell. \`theme-try-mode light|dark\` re-applies.
		theme-try-mode() {
		  local mode="\$1"
		  if [[ -z "\$mode" ]]; then
		    [[ "\$(defaults read -g AppleInterfaceStyle 2>/dev/null)" == Dark ]] && mode=dark || mode=light
		  fi
		  local stem="\$(<"$SANDBOX/stem-\$mode")"
		  local stem_us="\${stem//-/_}"

		  export THEME_TRY="$SLUG" THEME_TRY_MODE="\$mode"
		  export STARSHIP_CONFIG="$SANDBOX/starship-\$mode.toml"
		  export BAT_THEME="\$stem"
		  export GIT_PAGER="delta --config $SANDBOX/delta-\$mode.gitconfig"
		  export LS_COLORS="\$(vivid generate "$DIST/vivid/.config/vivid/themes/\$stem.yml")"
		  alias hx="XDG_CONFIG_HOME=$SANDBOX/xdg-\$mode hx"
		  alias leaf="XDG_CONFIG_HOME=$SANDBOX/xdg-\$mode leaf"
		  alias btop="btop -c $SANDBOX/btop-\$mode.conf"
		  source "$DIST/zsh/.zsh/\${stem_us}-fzf.zsh"
		  source "$DIST/zsh/.zsh/\${stem_us}-zsh-syntax-highlighting.zsh"
		}
		theme-try-mode
		echo "$THEME_NAME sandbox (\$THEME_TRY_MODE, pair $pair). Quit this Ghostty instance to go back."
	EOF2

	# ZDOTDIR swap: run the normal startup files, then layer the sandbox on top.
	echo '[[ -f ~/.zshenv ]] && source ~/.zshenv' >"$SANDBOX/zdot/.zshenv"
	printf 'source ~/.zshrc\nsource %q\n' "$SANDBOX/env.zsh" >"$SANDBOX/zdot/.zshrc"
}

launch() {
	local pair="$1"
	build "$pair"
	local themes="$DIST/ghostty/.config/ghostty/themes"
	local dark_var="THEME_PAIR_${pair}_dark" light_var="THEME_PAIR_${pair}_light"
	local dark_name_var="THEME_NAME_${!dark_var//-/_}" light_name_var="THEME_NAME_${!light_var//-/_}"
	open -na Ghostty --args \
		"--theme=dark:$themes/${!dark_name_var},light:$themes/${!light_name_var}" \
		"--env=ZDOTDIR=$SANDBOX/zdot" \
		"--window-save-state=never"
}

case "$ACTION" in
	clean) clean ;;
	build) build "${3:-$THEME_DEFAULT_PAIR}" && echo "Built $SANDBOX. Enter it with: ZDOTDIR=$SANDBOX/zdot zsh" ;;
	"") launch "$THEME_DEFAULT_PAIR" ;;
	*) launch "$ACTION" ;;
esac
