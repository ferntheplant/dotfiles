# Rex resume: run Claude Code or opencode again in a Rex pane that Rex restored after its server
# stopped (see "Rex resume" in ~/dotfiles/README.md).
#
# The agent writes ~/.local/state/rex-resume/<REX_BLOCK> while it runs in the pane: Claude Code
# with the SessionStart hook ~/.claude/hooks/rex-resume.sh, and opencode with its agent-context
# plugin. The file holds the conversation ID, the directory, the transcript path, and the agent,
# separated by tabs. A file without an agent is from Claude Code.
#
# - When the shell prompt comes back, the agent no longer runs in the pane, so the shell removes
#   the file. A server stop ends the shell too, so the file stays.
# - Rex restores each pane under its old ID, with a new login shell. If that shell finds the file,
#   it types `claude --resume <ID>` or `opencode --session <ID>` at its first prompt and runs it.
#   The turn that the stop cut off does not continue.

[[ -n "$REX_BLOCK" ]] || return 0

typeset -g _rex_resume_file="${XDG_STATE_HOME:-$HOME/.local/state}/rex-resume/$REX_BLOCK"
typeset -g _rex_resume_command=""

_rex_resume_forget() {
  [[ -e "$_rex_resume_file" ]] && rm -f -- "$_rex_resume_file"
}

_rex_resume_run() {
  autoload -Uz add-zle-hook-widget
  add-zle-hook-widget -d line-init _rex_resume_run
  [[ -n "$_rex_resume_command" ]] || return 0
  BUFFER="$_rex_resume_command"
  _rex_resume_command=""
  zle .accept-line
}

# Only the login shell that Rex starts in a restored pane resumes. A nested shell does not.
if [[ -o login && -o interactive && -f "$_rex_resume_file" ]]; then
  IFS=$'\t\t' read -r _rex_resume_id _rex_resume_dir _rex_resume_transcript _rex_resume_agent <"$_rex_resume_file"
  rm -f -- "$_rex_resume_file"
  case "${_rex_resume_agent:-claude}" in
    claude) _rex_resume_command="claude --resume $_rex_resume_id" ;;
    opencode) _rex_resume_command="opencode --session $_rex_resume_id" ;;
    *) _rex_resume_command="" ;;
  esac
  # Claude writes the transcript at the first prompt, and cannot resume a conversation without one
  if [[ -n "$_rex_resume_command" && "$_rex_resume_id" =~ '^[[:alnum:]_-]+$' ]] &&
    [[ -z "$_rex_resume_transcript" || -f "$_rex_resume_transcript" ]]; then
    if [[ -n "$_rex_resume_dir" && "$_rex_resume_dir" != "$PWD" ]]; then
      _rex_resume_command="cd ${(q)_rex_resume_dir} && $_rex_resume_command"
    fi
    autoload -Uz add-zle-hook-widget
    zle -N _rex_resume_run
    add-zle-hook-widget line-init _rex_resume_run
  else
    _rex_resume_command=""
  fi
  unset _rex_resume_id _rex_resume_dir _rex_resume_transcript _rex_resume_agent
fi

autoload -Uz add-zsh-hook
add-zsh-hook precmd _rex_resume_forget
