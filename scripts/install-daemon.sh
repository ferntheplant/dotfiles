#!/usr/bin/env bash
# Generic installer for running CLI programs as LaunchDaemons on macOS
# Usage: ./install-daemon.sh <service-name> <binary-path> [args...]
# Example: ./install-daemon.sh myservice /usr/local/bin/myprogram --config /path/to/config

set -euo pipefail

# Color variables
MAGENTA='\033[35m'
RESET='\033[0m'
ARROW="${MAGENTA}==>${RESET}"

# Validate arguments
if [ $# -lt 2 ]; then
    echo "Usage: $0 <service-name> <binary-path> [args...]"
    echo "Example: $0 myservice /usr/local/bin/myprogram --config /path/to/config"
    exit 1
fi

SERVICE_NAME="$1"
BINARY_PATH="$2"
shift 2
ARGS=("$@")

# Validate binary exists
if [ ! -f "$BINARY_PATH" ]; then
    echo "Error: Binary not found at $BINARY_PATH"
    exit 1
fi

# Configuration
PLIST_DIR="/Library/LaunchDaemons"
PLIST_FILE="${PLIST_DIR}/dev.fjorn.${SERVICE_NAME}.plist"
LABEL="dev.fjorn.${SERVICE_NAME}"
LOG_DIR="/var/log/${SERVICE_NAME}"
STDOUT_LOG="${LOG_DIR}/stdout.log"
STDERR_LOG="${LOG_DIR}/stderr.log"

echo -e "${ARROW} Installing ${SERVICE_NAME} as a LaunchDaemon..."

# Create log directory
echo "Creating log directory at ${LOG_DIR}..."
sudo mkdir -p "${LOG_DIR}"
sudo chown root:wheel "${LOG_DIR}"
sudo chmod 755 "${LOG_DIR}"

# Create the plist file
echo "Creating plist file at ${PLIST_FILE}..."
sudo tee "${PLIST_FILE}" >/dev/null <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>${LABEL}</string>
  <key>ProgramArguments</key><array>
    <string>${BINARY_PATH}</string>
EOF

# Add arguments to the plist
for arg in "${ARGS[@]}"; do
    sudo tee -a "${PLIST_FILE}" >/dev/null <<EOF
    <string>${arg}</string>
EOF
done

# Complete the plist
sudo tee -a "${PLIST_FILE}" >/dev/null <<EOF
  </array>
  <key>StandardOutPath</key><string>${STDOUT_LOG}</string>
  <key>StandardErrorPath</key><string>${STDERR_LOG}</string>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
</dict></plist>
EOF

# Set proper ownership and permissions
sudo chown root:wheel "${PLIST_FILE}"
sudo chmod 644 "${PLIST_FILE}"

# Bootstrap and enable the service
echo "Bootstrapping and enabling ${SERVICE_NAME} service..."
sudo launchctl bootout system "${PLIST_FILE}" 2>/dev/null || true
sudo launchctl bootstrap system "${PLIST_FILE}"
sudo launchctl enable "system/${LABEL}"

echo -e "${ARROW} ${SERVICE_NAME} service installed and enabled successfully!"
echo "Service label: ${LABEL}"
echo "Plist file: ${PLIST_FILE}"
echo "Logs directory: ${LOG_DIR}"
echo ""
echo "Useful commands:"
echo "  Check status: sudo launchctl print system/${LABEL}"
echo "  Stop service: sudo launchctl stop ${LABEL}"
echo "  Start service: sudo launchctl start ${LABEL}"
echo "  View stdout: sudo tail -f ${STDOUT_LOG}"
echo "  View stderr: sudo tail -f ${STDERR_LOG}"
echo "  View all logs: sudo tail -f ${LOG_DIR}/*.log"
echo "  Uninstall: ./uninstall-daemon.sh ${SERVICE_NAME}"
echo "  Manual uninstall: sudo launchctl bootout system ${PLIST_FILE} && sudo rm ${PLIST_FILE}"
