export EDITOR="/usr/bin/hx"
export HELIX_RUNTIME="/var/lib/helix/runtime"
export ZK_NOTEBOOK_DIR="/home/fjorn/notebook"
export RUSTC_WRAPPER="/home/fjorn/.cargo/bin/sccache"

path+=('/home/fjorn/.local/bin')
export PATH

source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

alias l="exa -a --long --header --tree --level=2 --icons --no-user --git --ignore-glob='.git' --git-ignore"
alias g="git"

eval "$(mise activate zsh)"
eval "$(mise hook-env)"
eval "$(fzf --zsh)"
eval "$(zoxide init zsh)"
eval "$(starship init zsh)"

if [[ -x "$(command -v zellij)" ]]; then
	eval "$(zellij setup --generate-completion zsh | grep "^function")"
fi
