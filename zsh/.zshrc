autoload -U compinit
compinit

export EDITOR="/usr/bin/hx"
export HELIX_RUNTIME="/var/lib/helix/runtime"
export RUSTC_WRAPPER="$HOME/.cargo/bin/sccache"
export STARSHIP_CONFIG="$HOME/.config/starship/starship.toml"

path+=("/opt/homebrew/bin")
path+=("$HOME/.bun/bin")
path+=("$HOME/.local/bin")
path+=("$HOME/.spicetify")
export PATH

alias l="eza -a --long --header --tree --level=2 --icons --no-user --git --ignore-glob='.git|*node_modules*' --time-style='relative' --no-permissions --modified"
alias l1="l --level=1 --time-style='+%y-%m-%d %H:%M'"
alias g="git"
alias zell="zellij"
alias zspot="zellij action new-tab --layout ~/.config/zellij/layouts/spotify.kdl --name spotify"
alias ztab="zellij action new-tab --layout ~/.config/zellij/layouts/base.kdl --name "
alias dab="databricks"
alias dbx="databricks"
alias blog-toc="markdown-toc --append=$'\n<br></br>' -i"
alias spot="spotify_player"

beep() {
	(
		trap "kill 0" EXIT
		~/Downloads/bbctl-macos-arm64 run sh-meta &
		~/Downloads/bbctl-macos-arm64 run --param 'imessage_platform=mac' sh-imessage &
		~/Downloads/bbctl-macos-arm64 run sh-signal &
		wait
	)
}

jab() {
	just dab/"$1" "${@:2}"
}

# Function to capture command start time
preexec() {
	date "+%m/%d %H:%M:%S" >~/.cache/starship_command_time
	STARSHIP_COMMAND_START_SECONDS=$(date +%s)
	export STARSHIP_COMMAND_START_SECONDS
}

# Function to check if command was long-running
precmd() {
	if [[ -n $STARSHIP_COMMAND_START_SECONDS ]]; then
		local end_seconds
		end_seconds=$(date +%s)
		local duration
		duration=$((end_seconds - STARSHIP_COMMAND_START_SECONDS))

		# Only keep the timestamp for commands running longer than 3 seconds
		if [[ duration -lt 3 ]]; then
			rm -f ~/.cache/starship_command_time
		fi

		unset STARSHIP_COMMAND_START_SECONDS
	fi
}

# shellcheck disable=SC1091
source "$HOME/dotfiles/scripts/zsh-functions/loader"
# shellcheck disable=SC1091
source "$HOME/dotfiles/scripts/zsh-functions/machine-setup"

if [ "$ALACRITTY" = "true" ] && [ "$ZELLIJ" != 0 ]; then
	ALACRITTY_THEME=$(defaults read -g AppleInterfaceStyle 2>/dev/null || echo "Light")
	if [ "$ALACRITTY_THEME" = "Dark" ]; then
		theme "dark"
	else
		theme "light"
	fi
fi

export CARAPACE_BRIDGES='zsh,fish,bash,inshellisense' # optional
zstyle ':completion:*' format $'\e[3m\e[38;2;220;138;120m[ Completing %d ]\e[0m'
source <(carapace _carapace)

eval "$(mise activate zsh)"
eval "$(mise hook-env)"
eval "$(fzf --zsh)"
eval "$(zoxide init zsh)"
eval "$(starship init zsh)"
eval "$(atuin init zsh --disable-up-arrow)"

if [[ -x "$(command -v brew)" ]]; then
	# shellcheck disable=SC1091
	source "$(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
else
	# shellcheck disable=SC1091
	source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

[[ "$TERM_PROGRAM" == "kiro" ]] && . "$(kiro --locate-shell-integration-path zsh)"
