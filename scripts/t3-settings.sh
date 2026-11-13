#!/bin/bash
set -euo pipefail

# Save or load the T3 Code settings, which T3 Code keeps in ~/.t3/userdata.
#   t3-settings.sh export   write the settings to ~/dotfiles/t3/
#   t3-settings.sh import   merge ~/dotfiles/t3/ into the T3 Code settings
#
# T3 Code has two settings files, and the dotfiles keep one copy of each:
#   settings.json          server settings (theme, models, git, worktrees); the server reloads it
#                          while it runs. Each machine's server has its own copy, so the app's
#                          settings for git and worktrees apply only to the machine that you
#                          edit them on. Import on each machine to give every environment the same.
#   client-settings.json   desktop app settings (fonts, sounds, animations); read at launch only.
#                          They apply in this app to the threads of every environment.
# GitHub authentication is not in these files. T3 Code uses each machine's own `gh` login, and
# this script does not touch the secrets in ~/.t3/userdata/secrets.
# The machine-only keys below (projects, devices, credentials, onboarding state) stay out of the
# shared files, and import keeps their current values. Import also keeps each key that the shared
# files do not name. The client file holds the legacy model favorites, which the server settings
# now keep, so those stay out too.
#
# T3 Code saves both files with a rename, which would replace a stow link, so import writes copies.
# The theme files in t3/themes are copies for the same reason: T3 Code ignores a linked theme file.
# The desktop app writes its whole client file when a setting changes in the UI. After an import
# that changes the client file, restart T3 Code before you change a setting in the app.

USERDATA="${T3CODE_HOME:-$HOME/.t3}/userdata"
DIR="${T3_SETTINGS_DIR:-$HOME/dotfiles/t3}"

case "${1:-}" in
  export | import) ;;
  *)
    echo "usage: $(basename "$0") export|import" >&2
    exit 1
    ;;
esac

if [[ ! -d "$USERDATA" ]]; then
  echo "⏭️  $USERDATA does not exist; open T3 Code once, then run this again"
  exit 0
fi

if [[ "$1" == import ]]; then
  # The background service (`t3 service install`) does not read the login shell, so .zshrc does
  # not reach it. It reads extra variables from service.env, so turn its telemetry off there too.
  # A running service applies the change after `t3 service restart`.
  service_env="$(dirname "$USERDATA")/service.env"
  telemetry="T3CODE_TELEMETRY_ENABLED=false"
  if ! grep -qx "$telemetry" "$service_env" 2>/dev/null; then
    { grep -v -E '^[[:space:]]*(export[[:space:]]+)?T3CODE_TELEMETRY_ENABLED=' "$service_env" 2>/dev/null || true
      echo "$telemetry"; } > "$service_env.tmp"
    mv "$service_env.tmp" "$service_env"
    echo "✅ Set $telemetry in $service_env; run \`t3 service restart\` if the service runs"
  fi

  mkdir -p "$USERDATA/themes"
  for theme in "$DIR"/themes/*.json; do
    [[ -e "$theme" ]] || continue
    target="$USERDATA/themes/$(basename "$theme")"
    if [[ -L "$target" ]] || ! cmp -s "$theme" "$target"; then
      rm -f "$target"
      cp "$theme" "$target"
      echo "✅ Copied theme $(basename "$theme")"
    fi
  done
fi

python3 -I - "$1" "$USERDATA" "$DIR" <<'EOF'
import json, os, sys, tempfile

mode, userdata, shared_dir = sys.argv[1:]
MACHINE = {
    "settings.json": {
        "addProjectBaseDirectory",
        "cloudSpeechCredentials",
        "defaultThemeSetAt",
        "deviceHosts",
        "deviceOnboardingCompleted",
        "easDeviceHosts",
        "environmentIcon",
        "observability",
        "previousWorktreesDirectories",
        "projectAgentBrowserAccessOverrides",
        "projectAutoPullOverrides",
        "projectScriptOverrides",
        "projectSettingsFolded",
        "projectSettingsOverrides",
        "secretProviders",
        "simlockDeviceHosts",
        "sourceControlHosts",
        "speechProjectCustomWords",
        "usageLimitSources",
        "worktreesDirectory",
    },
    "client-settings.json": {
        "browserDefaultProfileId",
        "browserProfiles",
        "favorites",
        "onboardingCompletedAt",
        "providerModelPreferences",
        "sidebarProjectGroupingOverrides",
        "voiceMicrophone",
    },
}

# Fields that hold a secret at any depth, such as a provider's server password. Export drops them,
# because this repo is public, and import keeps the current value.
SECRET = {"serverPassword"}

def strip(value):
    if isinstance(value, dict):
        return {k: strip(v) for k, v in value.items() if k not in SECRET}
    if isinstance(value, list):
        return [strip(v) for v in value]
    return value

def keep_secrets(new, old):
    if not isinstance(new, dict) or not isinstance(old, dict):
        return new
    merged = {k: keep_secrets(v, old.get(k)) for k, v in new.items()}
    merged.update({k: old[k] for k in SECRET if k in old})
    return merged

def read(path):
    if not os.path.exists(path):
        return {}
    with open(path) as f:
        return json.load(f)

def write(path, settings):
    # Write and rename, as T3 Code does, so a reader never sees half a file
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path), suffix=".tmp")
    with os.fdopen(fd, "w") as f:
        json.dump(settings, f, indent=2, ensure_ascii=False)
        f.write("\n")
    os.replace(tmp, path)

for name, machine in MACHINE.items():
    current_path = os.path.join(userdata, name)
    shared_path = os.path.join(shared_dir, name)
    current, shared = read(current_path), read(shared_path)
    if mode == "export":
        settings = {k: strip(v) for k, v in sorted(current.items()) if k not in machine}
        write(shared_path, settings)
        print(f"✅ Exported {len(settings)} settings to {shared_path}")
        continue
    wanted = {k: keep_secrets(v, current.get(k)) for k, v in shared.items()}
    changed = [k for k, v in wanted.items() if current.get(k) != v]
    if changed:
        write(current_path, {**current, **{k: wanted[k] for k in changed}})
    print(f"{name}: {len(changed)} of {len(shared)} settings differ: {', '.join(changed) or 'none'}")
    if changed and name == "client-settings.json":
        print("✅ Restart T3 Code to apply the client settings.")
EOF
