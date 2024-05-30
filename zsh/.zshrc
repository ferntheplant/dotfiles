export EDITOR="/usr/bin/hx"
export HELIX_RUNTIME="/var/lib/helix/runtime"
export ZK_NOTEBOOK_DIR="$HOME/notebook"
export RUSTC_WRAPPER="$HOME/.cargo/bin/sccache"

path+=("/opt/homebrew/bin")
path+=("$HOME/.bun/bin")
path+=("$HOME/.local/bin")
export PATH

# shellcheck disable=SC1091
source "$HOME/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh"
if [[ -x "$(command -v brew)" ]]; then
	# shellcheck disable=SC1091
	source "$(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
else
	# shellcheck disable=SC1091
	source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

alias l="exa -a --long --header --tree --level=2 --icons --no-user --git --ignore-glob='.git|*node_modules*'"
alias g="git"

alias leave-apt="apt-mark showmanual > apt-packages.txt"
alias leave-brew="brew leaves > brew-packages.txt"
alias leave-cargo="cargo install --list | parse-cargo"
alias leave-bun="cat ~/.bun/install/global/package.json | jq -r '.dependencies | keys[]' | tr -s '\n' ' ' > bun-packages.txt"
# shellcheck disable=SC2142
alias leave-pip="pip list | awk 'NR>2 && NF' | grep -v \"\\[notice\\]\" | awk '{print \$1}' | paste -sd \" \" > pip-packages.txt"

alias zell="zellij"
alias blog-toc="markdown-toc --append=$'\n<br></br>' -i"

eval "$(mise activate zsh)"
eval "$(mise hook-env)"
eval "$(fzf --zsh)"
eval "$(zoxide init zsh)"
eval "$(starship init zsh)"
eval "$(atuin init zsh --disable-up-arrow)"
