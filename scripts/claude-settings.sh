#!/bin/bash
set -euo pipefail

# Merge the shared Claude Code settings into ~/.claude/settings.json.
# Keys in the base file win. Hooks are added per event, and a hook group that is
# already present is skipped. Every other key stays, so machine-only settings
# (theme, plugins) and keys that other tools write (the pillar sync's telemetry
# env and trace hooks) survive. A hook group that runs a command in RETIRED is
# removed, so a hook that left the base file also leaves each machine.

BASE="$HOME/dotfiles/claude/.claude/settings.base.json"
TARGET="$HOME/.claude/settings.json"
# Hook commands that the base file no longer has
RETIRED='["rtk hook claude"]'

[[ -f "$TARGET" ]] || echo '{}' > "$TARGET"

merged=$(jq -n --slurpfile base "$BASE" --slurpfile cur "$TARGET" --argjson retired "$RETIRED" '
  def add_groups($have; $add):
    reduce $add[] as $g ($have; if any(.[]; . == $g) then . else . + [$g] end);
  ($base[0]) as $b | ($cur[0]) as $c
  | ($c * ($b | del(.hooks)))
  | .hooks = (reduce (($b.hooks // {}) | to_entries[]) as $e
      (($c.hooks // {}); .[$e.key] = add_groups(.[$e.key] // []; $e.value)))
  | .hooks |= with_entries(.value |= map(select(any(.hooks[]?; .command as $cmd | $retired | index($cmd)) | not)))
  | .hooks |= with_entries(select(.value | length > 0))
')

if [[ "$merged" == "$(jq . "$TARGET")" ]]; then
  echo "✅ $TARGET already has the base settings"
  exit 0
fi

backup="$TARGET.$(date +%Y%m%d%H%M%S).bak"
cp "$TARGET" "$backup"
printf '%s\n' "$merged" > "$TARGET"
echo "✅ Updated $TARGET (backup: $backup)"
