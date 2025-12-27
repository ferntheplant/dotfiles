#!/usr/bin/env bash
set -euo pipefail

LABEL="com.kanata"
PLIST_PATH="/Library/LaunchDaemons/${LABEL}.plist"

LOG_OUT="/var/log/kanata.log"
LOG_ERR="/var/log/kanata.err"

# Your config (already managed by your dotfiles scripts)
USER_CONFIG="${HOME}/.config/kanata/config.kbd"

# Root-readable config location (good for daemons)
ROOT_CONFIG_DIR="/etc/kanata"
ROOT_CONFIG="${ROOT_CONFIG_DIR}/config.kbd"

say() { printf "\n\033[1m==> %s\033[0m\n" "$*"; }
need_cmd() { command -v "$1" >/dev/null 2>&1; }

die() {
  echo "ERROR: $*" >&2
  exit 1
}

# --- Preconditions ---
if [[ "$(uname -s)" != "Darwin" ]]; then
  die "This script is for macOS only."
fi

if [[ ! -f "${USER_CONFIG}" ]]; then
  die "Kanata config not found at: ${USER_CONFIG}
Make sure your dotfiles install ran first."
fi

# --- Install Homebrew if missing ---
if ! need_cmd brew; then
  say "Homebrew not found"
  exit 1
fi

# --- Install Kanata ---
say "Installing kanata via Homebrew..."
brew install kanata >/dev/null 2>&1 || brew upgrade kanata

KANATA_BIN="$(command -v kanata)"
say "Using kanata at: ${KANATA_BIN}"

# --- Copy config to a root-readable location ---
say "Copying config to ${ROOT_CONFIG}..."
sudo mkdir -p "${ROOT_CONFIG_DIR}"
sudo cp "${USER_CONFIG}" "${ROOT_CONFIG}"
sudo chown root:wheel "${ROOT_CONFIG}"
sudo chmod 644 "${ROOT_CONFIG}"

# --- Write LaunchDaemon plist ---
say "Writing LaunchDaemon plist to ${PLIST_PATH}..."
sudo tee "${PLIST_PATH}" >/dev/null <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>${LABEL}</string>

    <key>ProgramArguments</key>
    <array>
      <string>${KANATA_BIN}</string>
      <string>-c</string>
      <string>${ROOT_CONFIG}</string>
    </array>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <true/>

    <key>StandardOutPath</key>
    <string>${LOG_OUT}</string>

    <key>StandardErrorPath</key>
    <string>${LOG_ERR}</string>
  </dict>
</plist>
EOF

# LaunchDaemons must be owned by root and not group/world-writable
say "Fixing plist permissions..."
sudo chown root:wheel "${PLIST_PATH}"
sudo chmod 644 "${PLIST_PATH}"

# --- Ensure logs exist (optional but nice) ---
say "Ensuring log files exist..."
sudo touch "${LOG_OUT}" "${LOG_ERR}"
sudo chmod 644 "${LOG_OUT}" "${LOG_ERR}"

# --- Reload daemon ---
say "Reloading LaunchDaemon..."
sudo launchctl unload -w "${PLIST_PATH}" >/dev/null 2>&1 || true
sudo launchctl load -w "${PLIST_PATH}"

# --- Health check ---
say "Health check..."

# Give launchd a moment to spawn
sleep 0.7

# 1) Check launchd knows about it
if ! sudo launchctl list | grep -q "${LABEL}"; then
  echo "❌ launchctl does not list ${LABEL}"
  echo "Last errors:"
  sudo tail -n 40 "${LOG_ERR}" || true
  exit 1
fi

# 2) Check process is running
if ! pgrep -f "kanata.*-c.*${ROOT_CONFIG}" >/dev/null 2>&1; then
  echo "❌ kanata process not running (or not matched)"
  echo
  echo "Recent stdout:"
  sudo tail -n 40 "${LOG_OUT}" || true
  echo
  echo "Recent stderr:"
  sudo tail -n 80 "${LOG_ERR}" || true
  echo
  echo "launchctl entry:"
  sudo launchctl list | grep "${LABEL}" || true
  exit 1
fi

echo "✅ Kanata is installed + running as a LaunchDaemon."
echo
echo "Status:   sudo launchctl list | grep kanata"
echo "Logs:     tail -f ${LOG_OUT}"
echo "Errors:   tail -f ${LOG_ERR}"

cat <<'NOTE'

NOTE:
- You may still need to grant macOS permissions:
  System Settings → Privacy & Security → Accessibility + Input Monitoring
  (Depending on your setup, macOS may require approval for the driver/tools.)
- If it doesn't work after a reboot, check these logs:
  /var/log/kanata.log and /var/log/kanata.err

NOTE
