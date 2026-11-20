#!/bin/bash
set -euo pipefail
umask 077

# Merge the shared opencode settings into its writable config files; base keys win, local keys survive.
#   opencode.base.json -> ~/.config/opencode/opencode.json  (the server: instructions, models, permissions)
#   cli.base.json      -> ~/.config/opencode/cli.json       (the terminal client: theme, tabs, diffs)
# Keep credentials, sessions, databases, and caches out of the stow package.
BASE_DIR="$HOME/dotfiles/opencode/.config/opencode"
TARGET_DIR="$HOME/.config/opencode"

merge() {
  local base="$BASE_DIR/$1" target="$TARGET_DIR/$2" new_file=false merged backup
  mkdir -p "$TARGET_DIR"
  [[ -f "$target" ]] || { echo '{}' > "$target"; new_file=true; }

  merged=$(jq -n --slurpfile base "$base" --slurpfile cur "$target" '$cur[0] * $base[0]')
  if [[ ! -L "$target" && "$merged" == "$(jq . "$target")" ]]; then
    echo "$target already has the base settings"
    return 0
  fi

  if [[ "$new_file" == false ]]; then
    backup="$target.$(date +%Y%m%d%H%M%S).bak"
    cp "$target" "$backup"
    echo "Backed up $target to $backup"
  fi
  # The harness owns the live file, not a link into the repo.
  [[ -L "$target" ]] && rm "$target"
  printf '%s\n' "$merged" > "$target"
  echo "Wrote $target"
}

merge opencode.base.json opencode.json
merge cli.base.json cli.json

# Link each plugin folder. opencode loads a folder at ~/.config/opencode/plugins/<name>, but it skips a
# server plugin file that is a link. Thus stow skips the plugins (see opencode/.stow-local-ignore),
# and this links the folders. install.sh removes a link whose folder is gone.
mkdir -p "$TARGET_DIR/plugins"
for plugin in "$BASE_DIR"/plugins/*/; do
  plugin="${plugin%/}"
  link="$TARGET_DIR/plugins/$(basename "$plugin")"
  if [[ -L "$link" && "$(readlink "$link")" == "$plugin" ]]; then
    continue
  elif [[ -e "$link" && ! -L "$link" ]]; then
    echo "⏭️  $link already exists and is not a link, skipped"
    continue
  fi
  ln -sfn "$plugin" "$link"
  echo "Linked $link"
done
