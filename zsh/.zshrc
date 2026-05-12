autoload -U compinit
compinit

export EDITOR="/opt/homebrew/bin/hx"
export HELIX_RUNTIME="/var/lib/helix/runtime"
export STARSHIP_CONFIG="$HOME/.config/starship/starship.toml"
export CMUX_SOCKET_MODE=allowAll
export CMUX_SOCKET_ENABLE=true

[[ ":$PATH:" != *":/opt/nanobrew/prefix/bin:"* ]] && path+=("/opt/nanobrew/prefix/bin")
[[ ":$PATH:" != *":/opt/homebrew/bin:"* ]] && path+=("/opt/homebrew/bin")
[[ ":$PATH:" != *":$HOME/.local/bin:"* ]] && path+=("$HOME/.local/bin")
[[ ":$PATH:" != *":$HOME/.bun/bin:"* ]] && path+=("$HOME/.bun/bin")
export PATH

alias l="eza -a --long --header --tree --level=2 --icons --no-user --git --ignore-glob='.git|*node_modules*' --time-style='relative' --no-permissions --modified"
alias l1="l --level=1 --time-style='+%y-%m-%d %H:%M'"
alias g="git"
alias bathelp="bat --plain --language=help"
alias -g -- --help='--help 2>&1 | bathelp'
alias zm="zmx"

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

zms() {
  local display
  display=$(zmx list 2>/dev/null | awk '
    {
      name=pid=clients=dir=""
      for (i = 1; i <= NF; i++) {
        split($i, kv, "=")
        if (kv[1] == "name") name=kv[2]
        if (kv[1] == "pid") pid=kv[2]
        if (kv[1] == "clients") clients=kv[2]
        if (kv[1] == "start_dir") dir=kv[2]
      }
      printf "%-20s  pid:%-8s  clients:%-2s  %s\n", name, pid, clients, dir
    }
  ')

  local output query key selected session_name rc

  output=$(
    { [[ -n "$display" ]] && echo "$display"; } | fzf \
      --print-query \
      --expect=ctrl-n \
      --height=80% \
      --reverse \
      --prompt="zmx> " \
      --header="Enter: select | Ctrl-N: create new" \
      --preview='zmx history {1} --vt' \
      --preview-window=right:60%:follow \
      --bind='ctrl-j:down,ctrl-k:up'
  )

  rc=$?

  query=$(echo "$output" | sed -n '1p')
  key=$(echo "$output" | sed -n '2p')
  selected=$(echo "$output" | sed -n '3p')

  if [[ "$key" == "ctrl-n" && -n "$query" ]]; then
    session_name="$query"
  elif [[ $rc -eq 0 && -n "$selected" ]]; then
    session_name=${selected%% *}
  elif [[ -n "$query" ]]; then
    session_name="$query"
  else
    return 130
  fi

  zmx attach "$session_name"
}
