autoload -U compinit
compinit

export EDITOR="/usr/bin/hx"
export HELIX_RUNTIME="/var/lib/helix/runtime"
export STARSHIP_CONFIG="$HOME/.config/starship/starship.toml"

path+=("/opt/homebrew/bin")
path+=("$HOME/.local/bin")
path+=("$HOME/.spicetify")
export PATH

alias l="eza -a --long --header --tree --level=2 --icons --no-user --git --ignore-glob='.git|*node_modules*' --time-style='relative' --no-permissions --modified"
alias l1="l --level=1 --time-style='+%y-%m-%d %H:%M'"
alias g="git"
alias dab="databricks"
alias dbx="databricks"
alias -g -- --help='--help 2>&1 | bat --language=help --style=plain'

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

source "$HOME/dotfiles/scripts/zsh-functions/loader"

if grep -q 'palette = "catppuccin-latte"' "$HOME/.config/starship/starship.toml"; then
  theme 'light'
else
  theme 'dark'
fi

export CARAPACE_BRIDGES='zsh,bash,inshellisense' # optional
# zstyle ':completion:*' format $'\e[3m\e[38;2;220;138;120m[ Completing %d ]\e[0m'
source <(carapace _carapace)

eval "$(mise activate zsh)"
eval "$(mise hook-env)"
eval "$(fzf --zsh)"
eval "$(zoxide init zsh)"
eval "$(starship init zsh)"
eval "$(atuin init zsh --disable-up-arrow)"

# Only load these if not in SSH session
if [[ -z "$SSH_CONNECTION" ]]; then
  source "$HOME/.zsh/fzf-tab/fzf-tab.plugin.zsh"
  source "$(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi
source "$(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

[[ "$TERM_PROGRAM" == "kiro" ]] && . "$(kiro --locate-shell-integration-path zsh)"
