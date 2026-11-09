#!/bin/bash
set -euo pipefail

# Merge the shared Pi settings into ~/.pi/agent/settings.json, and give Pi the OpenCode Go key.
# install.sh runs it; it is safe to run again.
#
# Keys in the base file win. The packages and skills lists are combined, so a package added with
# `pi install` stays. Every other key stays too, because Pi writes its own keys to this file (such as
# lastChangelogVersion). That is also why the file is not a link into this repo.

BASE="$HOME/dotfiles/pi/.pi/agent/settings.base.json"
TARGET="$HOME/.pi/agent/settings.json"

mkdir -p "$(dirname "$TARGET")"
# A link would make Pi write into the linked file; start from a real file instead
[[ -L "$TARGET" ]] && rm "$TARGET"
new_file=false
[[ -f "$TARGET" ]] || { echo '{}' > "$TARGET"; new_file=true; }

merged=$(jq -n --slurpfile base "$BASE" --slurpfile cur "$TARGET" '
  def union($have; $add): reduce $add[] as $x ($have; if any(.[]; . == $x) then . else . + [$x] end);
  ($base[0]) as $b | ($cur[0]) as $c
  | ($c * ($b | del(.packages, .skills)))
  | .packages = union($c.packages // []; $b.packages // [])
  | .skills = union($c.skills // []; $b.skills // [])
')

if [[ "$merged" == "$(jq . "$TARGET")" ]]; then
  echo "✅ $TARGET already has the base settings"
elif [[ "$new_file" == true ]]; then
  printf '%s\n' "$merged" > "$TARGET"
  echo "✅ Wrote $TARGET"
else
  backup="$TARGET.$(date +%Y%m%d%H%M%S).bak"
  cp "$TARGET" "$backup"
  printf '%s\n' "$merged" > "$TARGET"
  echo "✅ Updated $TARGET (backup: $backup)"
fi

# Pi's opencode-go provider uses the same API key as OpenCode Go. Copy the key that OpenCode saved,
# if there is one. Without it, run /login in Pi and pick OpenCode Go.
AUTH="$HOME/.pi/agent/auth.json"
OPENCODE_AUTH="$HOME/.local/share/opencode/auth.json"
if [[ -f "$AUTH" ]] && jq -e '."opencode-go"' "$AUTH" >/dev/null; then
  exit 0
fi
key=$(jq -r '."opencode-go".key // empty' "$OPENCODE_AUTH" 2>/dev/null || true)
if [[ -z "$key" ]]; then
  echo "⚠️  no OpenCode Go key found; run /login in Pi and pick OpenCode Go"
  exit 0
fi
[[ -f "$AUTH" ]] || (umask 077 && echo '{}' > "$AUTH")
updated=$(jq --arg key "$key" '."opencode-go" = {type: "api_key", key: $key}' "$AUTH")
(umask 077 && printf '%s\n' "$updated" > "$AUTH")
chmod 600 "$AUTH"
echo "✅ Copied the OpenCode Go key to $AUTH"
