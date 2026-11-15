#!/bin/bash
set -euo pipefail
umask 077

# Merge the shared omp settings into its writable config; base keys win, local keys survive.
# Keep credentials, sessions, databases, and caches out of the stow package.
BASE="$HOME/dotfiles/omp/.omp/agent/config.base.yml"
TARGET="$HOME/.omp/agent/config.yml"

mkdir -p "$(dirname "$TARGET")"
new_file=false
[[ -f "$TARGET" ]] || { echo '{}' > "$TARGET"; new_file=true; }

merged=$(yq eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' "$TARGET" "$BASE")
if [[ ! -L "$TARGET" && "$merged" == "$(yq . "$TARGET")" ]]; then
  echo "$TARGET already has the base settings"
  exit 0
fi

if [[ "$new_file" == false ]]; then
  backup="$TARGET.$(date +%Y%m%d%H%M%S).bak"
  cp "$TARGET" "$backup"
  echo "Backed up $TARGET to $backup"
fi
# The harness owns the live file, not a link into the repo.
[[ -L "$TARGET" ]] && rm "$TARGET"
printf '%s\n' "$merged" > "$TARGET"
echo "Wrote $TARGET"
