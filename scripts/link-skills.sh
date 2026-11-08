#!/bin/bash
set -euo pipefail

# Link each skill in the source folders into ~/.claude/skills, where Claude Code finds it. Pi reads
# the same folder (the skills key in pi/.pi/agent/settings.base.json), so both agents get the same
# skills. A name that something else already provides is skipped, such as the pillar repo's sync
# links on the work laptop, or a skill of the same name from an earlier source. A link to a skill
# that was deleted is removed.
#
# The skills in ~/dotfiles are copies (see .agents/vendored-skills.jsonc). The homielab skills are
# links to that repo's checkout, so homielab owns them and a `git pull` there updates them. A machine
# without the checkout skips that source.

SOURCES=(
  "$HOME/dotfiles/.agents/skills"
  "$HOME/homielab/.agents/skills"
)
TARGET="$HOME/.claude/skills"

mkdir -p "$TARGET"

for source in "${SOURCES[@]}"; do
  [[ -d "$source" ]] || continue
  for skill in "$source"/*/; do
    skill="${skill%/}"
    name="$(basename "$skill")"
    link="$TARGET/$name"
    if [[ -L "$link" && "$(readlink "$link")" == "$skill" ]]; then
      continue
    elif [[ -e "$link" || -L "$link" ]]; then
      echo "⏭️  $name: $link already exists, skipped"
    else
      ln -s "$skill" "$link"
      echo "✅ $name linked"
    fi
  done
done

for link in "$TARGET"/*; do
  [[ -L "$link" && ! -e "$link" ]] || continue
  for source in "${SOURCES[@]}"; do
    if [[ "$(readlink "$link")" == "$source"/* ]]; then
      rm "$link"
      echo "🗑️  $(basename "$link") removed (skill deleted)"
      break
    fi
  done
done
