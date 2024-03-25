export EDITOR="/usr/bin/hx"
export HELIX_RUNTIME="/var/lib/helix/runtime"
export ZK_NOTEBOOK_DIR="/home/fjorn/notebook"
export RUSTC_WRAPPER="/home/fjorn/.cargo/bin/sccache"

path+=('/home/fjorn/.bun/bin')
path+=('/home/fjorn/.local/bin')
export PATH

# shellcheck disable=SC1094
source /home/fjorn/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
# shellcheck disable=SC1094
source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

alias l="exa -a --long --header --tree --level=2 --icons --no-user --git --ignore-glob='.git|*node_modules*'"
alias g="git"

alias leave-apt="apt-mark showmanual > apt-packages.txt"

# shellcheck disable=SC2142
alias leave-cargo="cargo install --list | awk 'NF==1 {printf \"%s\", \$1}' > cargo-packages.txt"
alias leave-bun="cat ~/.bun/install/global/package.json | jq -r '.dependencies | keys[]' | tr -s '\n' ' ' > bun-packages.txt"
# shellcheck disable=SC2142
alias leave-pip="pip list | awk 'NR>2 && NF' | grep -v \"\\[notice\\]\" | awk '{print \$1}' | paste -sd \" \" > pip-packages.txt"

eval "$(mise activate zsh)"
eval "$(mise hook-env)"
eval "$(fzf --zsh)"
eval "$(zoxide init zsh)"
eval "$(starship init zsh)"
eval "$(atuin init zsh --disable-up-arrow)"

if [[ -x "$(command -v zellij)" ]]; then
	eval "$(zellij setup --generate-completion zsh | grep "^function")"
fi
