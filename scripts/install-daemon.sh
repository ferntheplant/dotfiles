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

# Validate the plist file
echo "Validating plist file..."
if ! plutil -lint "${PLIST_FILE}" >/dev/null 2>&1; then
    echo -e "${RED}❌${RESET} Plist file is invalid!"
    echo "Running plutil to show errors:"
    plutil -lint "${PLIST_FILE}"
    exit 1
fi
echo -e "${GREEN}✅${RESET} Plist file is valid"

# Show the generated plist for debugging
echo ""
echo "Generated plist content:"
echo "========================"
cat "${PLIST_FILE}"
echo "========================"
echo ""

# Test the binary and arguments manually
echo "Testing binary and arguments..."
echo "Command that will be run: ${BINARY_PATH} ${ARGS[*]}"
echo ""

# Check if binary exists and is executable
if [ ! -x "$BINARY_PATH" ]; then
    echo -e "${RED}❌${RESET} Binary is not executable or doesn't exist!"
    echo "File info:"
    ls -la "$BINARY_PATH" 2>/dev/null || echo "File not found"
    exit 1
fi

# Test running the command briefly
echo "Testing if command runs (will kill after 3 seconds)..."
timeout 3s "$BINARY_PATH" "${ARGS[@]}" &
TEST_PID=$!
sleep 1
if kill -0 $TEST_PID 2>/dev/null; then
    echo -e "${GREEN}✅${RESET} Command started successfully"
    kill $TEST_PID 2>/dev/null || true
    wait $TEST_PID 2>/dev/null || true
else
    echo -e "${RED}❌${RESET} Command failed to start or exited immediately"
    echo "Try running manually to see the error:"
    echo "  $BINARY_PATH ${ARGS[*]}"
    exit 1
fi

# Bootstrap and enable the service
echo "Bootstrapping and enabling ${SERVICE_NAME} service..."

# First, make sure it's not already loaded
sudo launchctl bootout system "${PLIST_FILE}" 2>/dev/null || true

# Bootstrap the service
if sudo launchctl bootstrap system "${PLIST_FILE}"; then
    echo -e "${GREEN}✅${RESET} Service bootstrapped successfully"
else
    echo -e "${RED}❌${RESET} Bootstrap failed!"
    echo ""
    echo "Troubleshooting steps:"
    echo "1. Check if binary exists and is executable:"
    echo "   ls -la ${BINARY_PATH}"
    echo "2. Try running the command manually:"
    echo "   ${BINARY_PATH} ${ARGS[*]}"
    echo "3. Check system logs:"
    echo "   sudo dmesg | tail -20"
    echo "4. Validate plist again:"
    echo "   plutil -lint ${PLIST_FILE}"
    exit 1
fi

# Enable the service
if sudo launchctl enable "system/${LABEL}"; then
    echo -e "${GREEN}✅${RESET} Service enabled successfully"
else
    echo -e "${RED}❌${RESET} Failed to enable service"
    exit 1
fi

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
