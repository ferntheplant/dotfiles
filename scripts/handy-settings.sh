#!/bin/bash
set -euo pipefail

# Save or load Handy's settings, which Handy keeps in a JSON store in Application Support.
#   handy-settings.sh export   write the settings to ~/dotfiles/handy/settings.json
#   handy-settings.sh import   merge ~/dotfiles/handy/settings.json into the Handy store
# The machine-only keys below (devices, the downloaded model, API keys, onboarding state)
# stay out of the shared file, and import keeps their current values. Handy fills in a
# default for every key that the store does not name, so import also works before the
# first launch. Import quits Handy while it writes, because Handy saves its own copy on exit.

STORE="${HANDY_STORE:-$HOME/Library/Application Support/com.pais.handy/settings_store.json}"
FILE="${HANDY_SETTINGS_FILE:-$HOME/dotfiles/handy/settings.json}"

case "${1:-}" in
  export | import) ;;
  *)
    echo "usage: $(basename "$0") export|import" >&2
    exit 1
    ;;
esac

if [[ "$1" == import && ! -f "$FILE" ]]; then
  echo "❌ $FILE does not exist; run export on a configured machine first" >&2
  exit 1
fi

sync() {
  python3 -I - "$1" "$STORE" "$FILE" <<'EOF'
import json, os, sys

mode, store_path, file_path = sys.argv[1:]
MACHINE = {
    "clamshell_microphone",
    "onboarding_completed",
    "post_process_api_keys",
    "selected_channel",
    "selected_microphone",
    "selected_model",
    "selected_output_device",
    "transcribe_gpu_device",
    "whats_new_last_seen_version",
}

def read(path):
    if not os.path.exists(path):
        return {}
    with open(path) as f:
        return json.load(f)

def write(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write("\n")

store = read(store_path)
current = store.get("settings", {})

if mode == "export":
    if not current:
        sys.exit(f"❌ {store_path} has no settings; launch Handy once first")
    settings = {k: v for k, v in sorted(current.items()) if k not in MACHINE}
    write(file_path, settings)
    print(f"✅ Exported {len(settings)} settings to {file_path}")
else:
    shared = {k: v for k, v in read(file_path).items() if k not in MACHINE}
    changed = [k for k, v in shared.items() if current.get(k) != v]
    print(f"{len(changed)} of {len(shared)} Handy settings differ: {', '.join(changed) or 'none'}")
    if mode == "check":
        sys.exit(3 if changed else 0)
    if changed:
        store["settings"] = {**current, **shared}
        write(store_path, store)
EOF
}

if [[ "$1" == export ]]; then
  sync export
  exit
fi

# Quit Handy only when a setting differs: it saves its own copy of the store on exit.
status=0
sync check || status=$?
[[ $status -eq 3 ]] || exit "$status"
running=false
if pgrep -xq handy; then
  running=true
  osascript -e 'quit app "Handy"'
  while pgrep -xq handy; do sleep 0.2; done
fi
sync import >/dev/null
echo "✅ Imported into the Handy store."
if $running; then
  open -a Handy
fi
