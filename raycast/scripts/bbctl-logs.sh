#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Service Logs
# @raycast.mode fullOutput

# Optional parameters:
# @raycast.icon 📋

# Documentation:
# @raycast.description View logs for a LaunchDaemon service
# @raycast.author fjorn
# @raycast.authorURL https://github.com/ferntheplant

# CONFIGURATION - Edit these values for your service
SERVICE_NAME="bbctl-imessage"  # Change this to your service name
LOG_LINES=100             # Number of lines to show

LOG_DIR="/var/log/${SERVICE_NAME}"
STDOUT_LOG="${LOG_DIR}/stdout.log"
STDERR_LOG="${LOG_DIR}/stderr.log"
LABEL="dev.fjorn.${SERVICE_NAME}"

echo "=== ${SERVICE_NAME} Service Status ==="
if sudo launchctl print "system/${LABEL}" >/dev/null 2>&1; then
    STATE=$(sudo launchctl print "system/${LABEL}" | grep -E "state = " | awk '{print $3}' || echo "unknown")
    echo "Status: Loaded (state: $STATE)"
else
    echo "Status: Not loaded"
fi

echo ""
echo "=== Recent STDERR (last ${LOG_LINES} lines) ==="
if [ -f "$STDERR_LOG" ]; then
    sudo tail -n "$LOG_LINES" "$STDERR_LOG" 2>/dev/null || echo "No stderr content"
else
    echo "No stderr log file found at: $STDERR_LOG"
fi

echo ""
echo "=== Recent STDOUT (last ${LOG_LINES} lines) ==="
if [ -f "$STDOUT_LOG" ]; then
    sudo tail -n "$LOG_LINES" "$STDOUT_LOG" 2>/dev/null || echo "No stdout content"
else
    echo "No stdout log file found at: $STDOUT_LOG"
fi

echo ""
echo "=== Log Files ==="
echo "STDOUT: $STDOUT_LOG"
echo "STDERR: $STDERR_LOG"
