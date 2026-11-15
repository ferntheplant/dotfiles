#!/bin/bash
set -euo pipefail
umask 077

# Merge the shared fx settings into its writable config; base keys win, local keys survive.
# Keep credentials, sessions, history, and caches out of the stow package.
BASE="$HOME/dotfiles/fx/.fx/settings.base.json"
TARGET="$HOME/.fx/settings.json"

mkdir -p "$(dirname "$TARGET")"
new_file=false
[[ -f "$TARGET" ]] || { echo '{}' > "$TARGET"; new_file=true; }

merged=$(jq -n --slurpfile base "$BASE" --slurpfile cur "$TARGET" '$cur[0] * $base[0]')
if [[ ! -L "$TARGET" && "$merged" == "$(jq . "$TARGET")" ]]; then
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
