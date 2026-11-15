#!/bin/bash
set -euo pipefail

# Link the agent material into ~/.claude, where Claude Code and omp find it:
#   - each skill folder into ~/.claude/skills/<name>
#   - the instructions folder to ~/.claude/agent-instructions, which claude/.claude/CLAUDE.md imports
#
# By default, the material comes from this repo's own copies in .agents/. The gitignored
# .work/agent-sources file adds folders on one machine, to try a change before it is published
# here, or to add skills that another checkout owns. Each line is `skills <folder>` or
# `instructions <folder>`; a line that starts with # is a comment, and ~ expands to $HOME:
#
#   skills ~/src/agent-material/skills
#   instructions ~/src/agent-material/instructions
#
# The skill folders in the file come before .agents/skills, and the first folder with a skill name
# wins. The first `instructions` line replaces .agents/instructions. Remove the file, or a line,
# and run this script again to go back to the published copies.
#
# A name that something else already provides is skipped, such as the pillar repo's sync links on
# the work laptop. The script records the links it makes in $STATE, so it can change or remove
# them later without touching a link that it did not make.

DOTFILES="$HOME/dotfiles"
SOURCES_FILE="$DOTFILES/.work/agent-sources"
SKILLS_TARGET="$HOME/.claude/skills"
INSTRUCTIONS_LINK="$HOME/.claude/agent-instructions"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/skill-links"

skill_sources=()
instructions=""
if [[ -f "$SOURCES_FILE" ]]; then
  while read -r kind folder; do
    [[ -z "$kind" || "$kind" == \#* ]] && continue
    folder="${folder/#\~/$HOME}"
    folder="${folder%/}"
    [[ -d "$folder" ]] || { echo "⚠️  $SOURCES_FILE: $folder does not exist, skipped"; continue; }
    case "$kind" in
      skills) skill_sources+=("$folder") ;;
      instructions) [[ -n "$instructions" ]] || instructions="$folder" ;;
      *) echo "⚠️  $SOURCES_FILE: unknown kind '$kind', skipped" ;;
    esac
  done < "$SOURCES_FILE"
fi
skill_sources+=("$DOTFILES/.agents/skills")
[[ -n "$instructions" ]] || instructions="$DOTFILES/.agents/instructions"

# --- Instructions ---

if [[ -L "$INSTRUCTIONS_LINK" ]]; then
  if [[ "$(readlink "$INSTRUCTIONS_LINK")" != "$instructions" ]]; then
    ln -sfn "$instructions" "$INSTRUCTIONS_LINK"
    echo "✅ instructions linked from $instructions"
  fi
elif [[ -e "$INSTRUCTIONS_LINK" ]]; then
  echo "⏭️  instructions: $INSTRUCTIONS_LINK is not a link, skipped"
else
  ln -s "$instructions" "$INSTRUCTIONS_LINK"
  echo "✅ instructions linked from $instructions"
fi

# --- Skills ---

mkdir -p "$SKILLS_TARGET" "$(dirname "$STATE")"

# The links this script made on its last run, as "name<TAB>target" lines. A link is ours only while
# it still has the target that we gave it. Before the first run with a state file, a link into
# one of the current sources counts as ours.
owned_names=()
owned_targets=()
if [[ -f "$STATE" ]]; then
  while IFS=$'\t' read -r name target; do
    owned_names+=("$name")
    owned_targets+=("$target")
  done < "$STATE"
fi

is_ours() {
  local link="$SKILLS_TARGET/$1" target i source
  [[ -L "$link" ]] || return 1
  target="$(readlink "$link")"
  for i in "${!owned_names[@]}"; do
    [[ "${owned_names[$i]}" == "$1" && "${owned_targets[$i]}" == "$target" ]] && return 0
  done
  [[ -f "$STATE" ]] && return 1
  for source in "${skill_sources[@]}"; do
    [[ "$target" == "$source"/* ]] && return 0
  done
  return 1
}

linked=()
linked_targets=()
for source in "${skill_sources[@]}"; do
  for skill in "$source"/*/; do
    [[ -d "$skill" ]] || continue
    skill="${skill%/}"
    name="$(basename "$skill")"
    for done_name in "${linked[@]+"${linked[@]}"}"; do
      [[ "$done_name" == "$name" ]] && continue 2
    done
    link="$SKILLS_TARGET/$name"
    if [[ -L "$link" && "$(readlink "$link")" == "$skill" ]]; then
      :
    elif is_ours "$name"; then
      ln -sfn "$skill" "$link"
      echo "✅ $name linked from $source"
    elif [[ -e "$link" || -L "$link" ]]; then
      echo "⏭️  $name: $link already exists, skipped"
      continue
    else
      ln -s "$skill" "$link"
      echo "✅ $name linked"
    fi
    linked+=("$name")
    linked_targets+=("$skill")
  done
done

# Remove each link that this script made for a skill that no source has now.
for name in "${owned_names[@]+"${owned_names[@]}"}"; do
  for done_name in "${linked[@]+"${linked[@]}"}"; do
    [[ "$done_name" == "$name" ]] && continue 2
  done
  if is_ours "$name"; then
    rm "$SKILLS_TARGET/$name"
    echo "🗑️  $name removed (no source has it)"
  fi
done
# Before the first run with a state file: remove a dangling link into a current source.
if [[ ! -f "$STATE" ]]; then
  for link in "$SKILLS_TARGET"/*; do
    [[ -L "$link" && ! -e "$link" ]] || continue
    for source in "${skill_sources[@]}"; do
      if [[ "$(readlink "$link")" == "$source"/* ]]; then
        rm "$link"
        echo "🗑️  $(basename "$link") removed (skill deleted)"
        break
      fi
    done
  done
fi

: > "$STATE"
for i in "${!linked[@]}"; do
  printf '%s\t%s\n' "${linked[$i]}" "${linked_targets[$i]}" >> "$STATE"
done
