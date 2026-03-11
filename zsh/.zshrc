autoload -U compinit
compinit

export EDITOR="/usr/bin/hx"
export HELIX_RUNTIME="/var/lib/helix/runtime"
export STARSHIP_CONFIG="$HOME/.config/starship/starship.toml"

path+=("/opt/homebrew/bin")
path+=("$HOME/.local/bin")
path+=("$HOME/.bun/bin")
export PATH

alias l="eza -a --long --header --tree --level=2 --icons --no-user --git --ignore-glob='.git|*node_modules*' --time-style='relative' --no-permissions --modified"
alias l1="l --level=1 --time-style='+%y-%m-%d %H:%M'"
alias g="git"
alias bathelp="bat --plain --language=help"
alias -g -- --help='--help 2>&1 | bathelp'
alias zel="zellij"
alias zm="zmx"
alias pm="~/.local/bin/pm.ts"

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

function y() {
  local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
  command yazi "$@" --cwd-file="$tmp"
  IFS= read -r -d '' cwd < "$tmp"
  [ "$cwd" != "$PWD" ] && [ -d "$cwd" ] && builtin cd -- "$cwd"
  rm -f -- "$tmp"
}

source "$HOME/dotfiles/scripts/zsh-functions/loader"

# Only run theme update if not in VSCode/Cursor and starship config exists
if [[ -f "$HOME/.config/starship/starship.toml" ]]; then
  # Check multiple ways to detect VSCode/Cursor to be more robust
  if [[ "$TERM_PROGRAM" != "vscode" ]] && \
     [[ "$TERM_PROGRAM" != "cursor" ]] && \
     [[ -z "$VSCODE_INJECTION" ]] && \
     [[ -z "$CURSOR_SESSION" ]] && \
     [[ "$(ps -o comm= -p $PPID 2>/dev/null)" != *"cursor"* ]] && \
     [[ "$(ps -o comm= -p $PPID 2>/dev/null)" != *"code"* ]]; then
    if grep -q 'palette = "rose-pine-dawn"' "$HOME/.config/starship/starship.toml"; then
      theme 'light'
    else
      theme 'dark'
    fi
  fi
fi

eval "$(mise activate zsh)"
eval "$(mise hook-env)"
eval "$(fzf --zsh)"
eval "$(zoxide init zsh)"
eval "$(starship init zsh)"

# Only load async renderers if not in SSH session
if [[ -z "$SSH_CONNECTION" ]]; then
  export CARAPACE_BRIDGES='zsh,bash,inshellisense' # optional
  # zstyle ':completion:*' format $'\e[3m\e[38;2;220;138;120m[ Completing %d ]\e[0m'
  source <(carapace _carapace)
  eval "$(atuin init zsh --disable-up-arrow)"
  source "$HOME/.zsh/fzf-tab/fzf-tab.plugin.zsh"
  source "$(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi

source "$(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

if command -v zmx &> /dev/null; then
  eval "$(zmx completions zsh)"
fi

# pnpm
export PNPM_HOME="/Users/fjorn/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end
