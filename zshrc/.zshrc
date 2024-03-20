path+=('/opt/nvim-linux64/bin')
path+=('/home/fjorn/.local/bin')
path+=('/home/fjorn/go/bin')

export PATH

export EDITOR="/usr/bin/hx"
export HELIX_RUNTIME="/var/lib/helix/runtime"
export ZK_NOTEBOOK_DIR="/home/fjorn/notebook"

source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

alias l="exa -a --long --header --tree --level=2 --icons --no-user --git --ignore-glob='.git'"
alias g="git"

eval "$(zoxide init zsh)"
eval "$(starship init zsh)"

if [[ -x "$(command -v zellij)" ]];
then
  eval "$(zellij setup --generate-completion zsh | grep "^function")"
fi;

# bun completions
[ -s "/home/fjorn/.bun/_bun" ] && source "/home/fjorn/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
