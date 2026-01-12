#!/usr/bin/env bash
set -euo pipefail

# Define config files to install as daemons
# Add more config files here as needed
CONFIG_FILES=(
  "macbook.kbd"
  "advantage.kbd"
  "ava.kbd"
  "zen.kbd"
)

# Base paths
USER_CONFIG_DIR="${HOME}/.config/kanata"
ROOT_CONFIG_DIR="/etc/kanata"
PLIST_DIR="/Library/LaunchDaemons"

say() { printf "\n\033[1m==> %s\033[0m\n" "$*"; }
need_cmd() { command -v "$1" >/dev/null 2>&1; }

die() {
  echo "ERROR: $*" >&2
  exit 1
}

# Function to install a single kanata daemon
install_kanata_daemon() {
  local config_file="$1"
  local config_name="${config_file%.kbd}"  # Remove .kbd extension

  local user_config="${USER_CONFIG_DIR}/${config_file}"
  local root_config="${ROOT_CONFIG_DIR}/${config_file}"
  local label="com.kanata.${config_name}"
  local plist_path="${PLIST_DIR}/${label}.plist"
  local log_out="/var/log/kanata-${config_name}.log"
  local log_err="/var/log/kanata-${config_name}.err"

  say "Installing daemon for ${config_file}..."

  # Check if user config exists
  if [[ ! -f "${user_config}" ]]; then
    echo "⚠️  Config not found: ${user_config}, skipping..."
    return 1
  fi

  # Copy config to root-readable location
  say "  Copying config to ${root_config}..."
  sudo mkdir -p "${ROOT_CONFIG_DIR}"
  sudo cp "${user_config}" "${root_config}"
  sudo chown root:wheel "${root_config}"
  sudo chmod 644 "${root_config}"

  # Write LaunchDaemon plist
  say "  Writing LaunchDaemon plist to ${plist_path}..."
  sudo tee "${plist_path}" >/dev/null <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>${label}</string>

    <key>ProgramArguments</key>
    <array>
      <string>${KANATA_BIN}</string>
      <string>-c</string>
      <string>${root_config}</string>
    </array>

    <key>RunAtLoad</key>
    <false/>

    <key>KeepAlive</key>
    <true/>

    <key>StandardOutPath</key>
    <string>${log_out}</string>

    <key>StandardErrorPath</key>
    <string>${log_err}</string>
  </dict>
</plist>
EOF

  # Fix plist permissions
  say "  Fixing plist permissions..."
  sudo chown root:wheel "${plist_path}"
  sudo chmod 644 "${plist_path}"

  # Ensure logs exist
  say "  Ensuring log files exist..."
  sudo touch "${log_out}" "${log_err}"
  sudo chmod 644 "${log_out}" "${log_err}"

  # Load daemon (but don't start it - RunAtLoad is false)
  say "  Loading LaunchDaemon..."
  sudo launchctl unload -w "${plist_path}" >/dev/null 2>&1 || true
  sudo launchctl load -w "${plist_path}"

  # Immediately stop the daemon if it started
  say "  Stopping daemon..."
  sudo launchctl bootout system "${plist_path}" >/dev/null 2>&1 || true

  echo "✅ ${config_name} daemon installed (stopped - use kanata-start to start for connected devices)"
  return 0
}

# --- Preconditions ---
if [[ "$(uname -s)" != "Darwin" ]]; then
  die "This script is for macOS only."
fi

if [[ ! -d "${USER_CONFIG_DIR}" ]]; then
  die "Kanata config directory not found at: ${USER_CONFIG_DIR}
Make sure your dotfiles install ran first."
fi

# --- Install Kanata ---
say "Installing kanata via Homebrew..."
brew install kanata >/dev/null 2>&1 || brew upgrade kanata

KANATA_BIN="$(command -v kanata)"
say "Using kanata at: ${KANATA_BIN}"

# --- Install daemons for each config file ---
SUCCESS_COUNT=0
FAILED_CONFIGS=()

for config_file in "${CONFIG_FILES[@]}"; do
  if install_kanata_daemon "${config_file}"; then
    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
  else
    FAILED_CONFIGS+=("${config_file}")
  fi
done

# --- Summary ---
echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [[ ${SUCCESS_COUNT} -eq ${#CONFIG_FILES[@]} ]]; then
  echo "✅ All ${SUCCESS_COUNT} kanata daemon(s) installed (stopped)."
else
  echo "⚠️  ${SUCCESS_COUNT}/${#CONFIG_FILES[@]} daemon(s) installed successfully."
  if [[ ${#FAILED_CONFIGS[@]} -gt 0 ]]; then
    echo "Failed configs: ${FAILED_CONFIGS[*]}"
  fi
fi
echo
echo "💡 Use 'kanata-start' (Raycast script) to start daemons for currently connected devices."
echo
echo "Status:   sudo launchctl list | grep kanata"
echo "Logs:     tail -f /var/log/kanata-*.log"
echo "Errors:   tail -f /var/log/kanata-*.err"
echo
cat <<'NOTE'
NOTE:
- You may still need to grant macOS permissions:
  System Settings → Privacy & Security → Accessibility + Input Monitoring
  (Depending on your setup, macOS may require approval for the driver/tools.)
- If it doesn't work after a reboot, check the logs:
  /var/log/kanata-*.log and /var/log/kanata-*.err
- To add more config files, edit the CONFIG_FILES array at the top of this script.

NOTE
