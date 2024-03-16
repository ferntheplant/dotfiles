path+=('/opt/nvim-linux64/bin')
path+=('/home/fjorn/.local/bin')

export PATH

export EDITOR="/opt/nvim-linux64/bin/nvim"

source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

alias l="exa -a --long --header --tree --level=2 --icons --no-user --git"
alias g="git"

eval "$(zoxide init zsh)"
eval "$(starship init zsh)"

if [[ -x "$(command -v zellij)" ]];
then
  eval "$(zellij setup --generate-completion zsh | grep "^function")"
fi;
