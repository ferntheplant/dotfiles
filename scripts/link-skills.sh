#!/bin/bash
set -euo pipefail

# Link each skill in ~/dotfiles/.agents/skills into ~/.claude/skills, where Claude Code and
# OpenCode both find it. A name that something else already provides is skipped, such as the
# pillar repo's sync links on the work laptop. A link to a skill that was deleted is removed.

SOURCE="$HOME/dotfiles/.agents/skills"
TARGET="$HOME/.claude/skills"

mkdir -p "$TARGET"

for skill in "$SOURCE"/*/; do
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

for link in "$TARGET"/*; do
  if [[ -L "$link" && "$(readlink "$link")" == "$SOURCE"/* && ! -e "$link" ]]; then
    rm "$link"
    echo "🗑️  $(basename "$link") removed (skill deleted)"
  fi
done
