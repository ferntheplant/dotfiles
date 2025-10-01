#!/usr/bin/env bash
# Generic installer for running CLI programs as LaunchAgents on macOS
# LaunchAgents run as the user (not root) so they can access user files
# Usage: ./install-agent.sh <service-name> <binary-path> [args...]

set -euo pipefail

# Color variables
MAGENTA='\033[35m'
GREEN='\033[32m'
RED='\033[31m'
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

# Configuration - LaunchAgents go in user directory
PLIST_DIR="${HOME}/Library/LaunchAgents"
PLIST_FILE="${PLIST_DIR}/dev.fjorn.${SERVICE_NAME}.plist"
LABEL="dev.fjorn.${SERVICE_NAME}"
LOG_DIR="${HOME}/Library/Logs/${SERVICE_NAME}"
STDOUT_LOG="${LOG_DIR}/stdout.log"
STDERR_LOG="${LOG_DIR}/stderr.log"

echo -e "${ARROW} Installing ${SERVICE_NAME} as a LaunchAgent..."

# Create directories
echo "Creating directories..."
mkdir -p "${PLIST_DIR}"
mkdir -p "${LOG_DIR}"

# Create the plist file (no wrapper needed since we run as user)
echo "Creating plist file at ${PLIST_FILE}..."
cat > "${PLIST_FILE}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>${LABEL}</string>
  <key>ProgramArguments</key><array>
    <string>${BINARY_PATH}</string>
EOF

# Add arguments to the plist only if there are args
if [ ${#ARGS[@]} -gt 0 ]; then
    for arg in "${ARGS[@]}"; do
        cat >> "${PLIST_FILE}" <<EOF
    <string>${arg}</string>
EOF
    done
fi

# Complete the plist
cat >> "${PLIST_FILE}" <<EOF
  </array>
  <key>StandardOutPath</key><string>${STDOUT_LOG}</string>
  <key>StandardErrorPath</key><string>${STDERR_LOG}</string>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
</dict></plist>
EOF

# Validate the plist file
echo "Validating plist file..."
if ! plutil -lint "${PLIST_FILE}" >/dev/null 2>&1; then
    echo -e "${RED}❌${RESET} Plist file is invalid!"
    plutil -lint "${PLIST_FILE}"
    exit 1
fi
echo -e "${GREEN}✅${RESET} Plist file is valid"

# Show the generated plist
echo ""
echo "Generated plist content:"
echo "========================"
cat "${PLIST_FILE}"
echo "========================"
echo ""

# Test the command
echo "Testing command..."
if [ ${#ARGS[@]} -gt 0 ]; then
    echo "Command: ${BINARY_PATH} ${ARGS[*]}"
    timeout 3s "$BINARY_PATH" "${ARGS[@]}" &
    TEST_PID=$!
else
    echo "Command: ${BINARY_PATH}"
    timeout 3s "$BINARY_PATH" &
    TEST_PID=$!
fi
sleep 1
if kill -0 $TEST_PID 2>/dev/null; then
    echo -e "${GREEN}✅${RESET} Command started successfully"
    kill $TEST_PID 2>/dev/null || true
    wait $TEST_PID 2>/dev/null || true
else
    echo -e "${RED}❌${RESET} Command failed to start or exited immediately"
    exit 1
fi

# Load the agent
echo "Loading LaunchAgent..."
# Bootout if already loaded
launchctl bootout "gui/$(id -u)/${LABEL}" 2>/dev/null || true

# Bootstrap the agent
if launchctl bootstrap "gui/$(id -u)" "${PLIST_FILE}"; then
    echo -e "${GREEN}✅${RESET} LaunchAgent loaded successfully"
else
    echo -e "${RED}❌${RESET} Failed to load LaunchAgent"
    exit 1
fi

echo -e "${ARROW} ${SERVICE_NAME} LaunchAgent installed successfully!"
echo "Service label: ${LABEL}"
echo "Plist file: ${PLIST_FILE}"
echo "Logs directory: ${LOG_DIR}"
echo ""
echo "Useful commands:"
echo "  Check status: launchctl list | grep ${SERVICE_NAME}"
echo "  Stop service: launchctl bootout gui/$(id -u)/${LABEL}"
echo "  Start service: launchctl bootstrap gui/$(id -u) ${PLIST_FILE}"
echo "  View logs: tail -f ${LOG_DIR}/*.log"
echo "  Uninstall: ./uninstall-agent.sh ${SERVICE_NAME}"
