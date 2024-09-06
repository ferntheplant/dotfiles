export EDITOR="/usr/bin/hx"
export HELIX_RUNTIME="/var/lib/helix/runtime"
export ZK_NOTEBOOK_DIR="$HOME/notebook"
export RUSTC_WRAPPER="$HOME/.cargo/bin/sccache"

path+=("/opt/homebrew/bin")
path+=("$HOME/.bun/bin")
path+=("$HOME/.local/bin")
export PATH

alias l="eza -a --long --header --tree --level=2 --icons --no-user --git --ignore-glob='.git|*node_modules*' --time-style='relative' --no-permissions --modified"
alias l1="l --level=1 --time-style='+%y-%m-%d %H:%M'"
alias g="git"
alias zell="zellij"
alias zspot="zellij action new-tab --layout ~/.config/zellij/layouts/spotify.kdl --name spotify"
alias ztab="zellij action new-tab --layout ~/.config/zellij/layouts/base.kdl --name "

alias blog-toc="markdown-toc --append=$'\n<br></br>' -i"
alias spot="spotify_player"

alias leave-apt="apt-mark showmanual > apt-packages.txt"
alias leave-brew="brew leaves > brew-packages.txt"
alias leave-cargo="cargo install --list | parse-cargo"
alias leave-bun="cat ~/.bun/install/global/package.json | jq -r '.dependencies | keys[]' | tr -s '\n' ' ' > bun-packages.txt"
# shellcheck disable=SC2142
alias leave-pip="pip list | awk 'NR>2 && NF' | grep -v \"\\[notice\\]\" | awk '{print \$1}' | paste -sd \" \" > pip-packages.txt"

theme() {
	update-catppuccin "$HOME/.config/alacritty/alacritty.toml" --"$1"
	update-catppuccin "$HOME/.config/starship.toml" --"$1" --quotes
	update-catppuccin "$HOME/.config/zellij/config.kdl" --"$1" --quotes
	update-catppuccin "$HOME/.config/bat/config.conf" --"$1" --quotes
	update-catppuccin "$HOME/.config/helix/config.toml" --"$1" --quotes --underscore
	update-catppuccin "$HOME/.config/spotify-player/app.toml" --"$1" --quotes
	update-catppuccin "$HOME/.gitconfig" --"$1"

	# TODO: Yazi
	if [[ "$1" == "light" ]]; then
		source "$HOME/.zsh/catppuccin-latte-zsh-syntax-highlighting.zsh"
		export FZF_DEFAULT_OPTS=" \
--color=bg+:#ccd0da,bg:#eff1f5,spinner:#dc8a78,hl:#d20f39 \
--color=fg:#4c4f69,header:#d20f39,info:#8839ef,pointer:#dc8a78 \
--color=marker:#7287fd,fg+:#4c4f69,prompt:#8839ef,hl+:#d20f39 \
--color=selected-bg:#bcc0cc \
--multi"
	else
		source "$HOME/.zsh/catppuccin-macchiato-zsh-syntax-highlighting.zsh"
		export FZF_DEFAULT_OPTS=" \
--color=bg+:#363a4f,bg:#24273a,spinner:#f4dbd6,hl:#ed8796 \
--color=fg:#cad3f5,header:#ed8796,info:#c6a0f6,pointer:#f4dbd6 \
--color=marker:#f4dbd6,fg+:#cad3f5,prompt:#c6a0f6,hl+:#ed8796"
	fi
}

if [ "$ALACRITTY" = "true" ] && [ "$ZELLIJ" != 0 ]; then
	ALACRITTY_THEME=$(defaults read -g AppleInterfaceStyle 2>/dev/null || echo "Light")
	if [ "$ALACRITTY_THEME" = "Dark" ]; then
		theme "dark"
	else
		theme "light"
	fi
fi

if [[ -x "$(command -v brew)" ]]; then
	# shellcheck disable=SC1091
	source "$(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
else
	# shellcheck disable=SC1091
	source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

# shellcheck disable=SC1091
source "$HOME/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh"

eval "$(mise activate zsh)"
eval "$(mise hook-env)"
eval "$(fzf --zsh)"
eval "$(zoxide init zsh)"
eval "$(starship init zsh)"
eval "$(atuin init zsh --disable-up-arrow)"

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/opt/miniconda3/bin/conda' 'shell.zsh' 'hook' 2>/dev/null)"
if [ $? -eq 0 ]; then
	eval "$__conda_setup"
else
	if [ -f "/opt/miniconda3/etc/profile.d/conda.sh" ]; then
		. "/opt/miniconda3/etc/profile.d/conda.sh"
	else
		export PATH="/opt/miniconda3/bin:$PATH"
	fi
fi
unset __conda_setup
# <<< conda initialize <<<
