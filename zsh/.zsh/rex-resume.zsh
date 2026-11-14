# Rex resume: run Claude Code again in a Rex pane that Rex restored after its server stopped (see
# "Rex resume" in ~/dotfiles/README.md).
#
# The SessionStart hook ~/.claude/hooks/rex-resume.sh writes ~/.local/state/rex-resume/<REX_BLOCK>
# while Claude runs in the pane. The file holds the conversation ID, the directory, and the
# transcript path.
#
# - When the shell prompt comes back, Claude no longer runs in the pane, so the shell removes the
#   file. A server stop ends the shell too, so the file stays.
# - Rex restores each pane under its old ID, with a new login shell. If that shell finds the file,
#   it types `claude --resume <ID>` at its first prompt and runs it. The turn that the stop cut
#   off does not continue.

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
  IFS=$'\t' read -r _rex_resume_id _rex_resume_dir _rex_resume_transcript <"$_rex_resume_file"
  rm -f -- "$_rex_resume_file"
  # Claude writes the transcript at the first prompt, and cannot resume a conversation without one
  if [[ "$_rex_resume_id" =~ '^[[:alnum:]-]+$' ]] &&
    [[ -z "$_rex_resume_transcript" || -f "$_rex_resume_transcript" ]]; then
    _rex_resume_command="claude --resume $_rex_resume_id"
    if [[ -n "$_rex_resume_dir" && "$_rex_resume_dir" != "$PWD" ]]; then
      _rex_resume_command="cd ${(q)_rex_resume_dir} && $_rex_resume_command"
    fi
    autoload -Uz add-zle-hook-widget
    zle -N _rex_resume_run
    add-zle-hook-widget line-init _rex_resume_run
  fi
  unset _rex_resume_id _rex_resume_dir _rex_resume_transcript
fi

autoload -Uz add-zsh-hook
add-zsh-hook precmd _rex_resume_forget
