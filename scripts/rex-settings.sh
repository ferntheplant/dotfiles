#!/bin/bash
set -euo pipefail

# Save or load Rex's app settings, which Rex keeps in macOS preferences (not in init.lua).
#   rex-settings.sh export   write the settings to ~/dotfiles/rex/settings.json
#   rex-settings.sh import   merge ~/dotfiles/rex/settings.json into the Rex preferences
# Every Workspace.* and rex.* key is a setting, except the session and cache state below.
# Values that Rex stores as JSON data (such as the custom themes) are saved decoded, so
# their diffs stay readable. Import keeps every key the file does not name.

DOMAIN="${REX_DEFAULTS_DOMAIN:-com.superlogical.rex}"
FILE="${REX_SETTINGS_FILE:-$HOME/dotfiles/rex/settings.json}"

case "${1:-}" in
  export | import) ;;
  *)
    echo "usage: $(basename "$0") export|import" >&2
    exit 1
    ;;
esac

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
defaults export "$DOMAIN" "$tmp/current.plist" 2>/dev/null || echo '{}' | plutil -convert xml1 -o "$tmp/current.plist" -

python3 -I - "$1" "$tmp/current.plist" "$FILE" "$tmp/merged.plist" <<'EOF'
import base64, json, plistlib, sys

mode, current_path, file_path, merged_path = sys.argv[1:]
PREFIXES = ("Workspace.", "rex.")
STATE = {
    "Workspace.lastFocusedSession",
    "Workspace.programActivitySeen",
    "rex.local-server.cached-route.v1",
    "rex.sync.hosts-migrated.v1",
}

with open(current_path, "rb") as f:
    current = plistlib.load(f)

def encode(value):
    if isinstance(value, bytes):
        try:
            return {"$json": json.loads(value)}
        except ValueError:
            return {"$data": base64.b64encode(value).decode()}
    return value

def decode(value):
    if isinstance(value, dict) and value.keys() == {"$json"}:
        return json.dumps(value["$json"], separators=(",", ":")).encode()
    if isinstance(value, dict) and value.keys() == {"$data"}:
        return base64.b64decode(value["$data"])
    return value

def same(a, b):
    if isinstance(a, bytes) and isinstance(b, bytes):
        try:
            return json.loads(a) == json.loads(b)
        except ValueError:
            pass
    return a == b

if mode == "export":
    settings = {k: encode(v) for k, v in sorted(current.items())
                if k.startswith(PREFIXES) and k not in STATE}
    with open(file_path, "w") as f:
        json.dump(settings, f, indent=2, ensure_ascii=False)
        f.write("\n")
    print(f"✅ Exported {len(settings)} settings to {file_path}")
else:
    with open(file_path) as f:
        settings = json.load(f)
    changed = [k for k, v in settings.items() if not same(current.get(k), decode(v))]
    current.update({k: decode(settings[k]) for k in changed})
    if changed:
        with open(merged_path, "wb") as f:
            plistlib.dump(current, f)
    print(f"{len(changed)} of {len(settings)} settings differ: {', '.join(changed) or 'none'}")
EOF

if [[ -f "$tmp/merged.plist" ]]; then
  defaults import "$DOMAIN" "$tmp/merged.plist"
  echo "✅ Imported into $DOMAIN. Restart Rex to apply."
fi
