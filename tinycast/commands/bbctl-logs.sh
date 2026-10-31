#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title bbctl Logs
# @raycast.mode fullOutput

# Optional parameters:
# @raycast.icon 📋

# Documentation:
# @raycast.author fjorn
# @raycast.authorURL https://github.com/ferntheplant

# CONFIGURATION - Edit these values for your service
SERVICE_NAME="bbctl-imessage"  # Change this to your service name
LOG_LINES=100             # Number of lines to show

LOG_DIR="${HOME}/Library/Logs/${SERVICE_NAME}"
STDOUT_LOG="${LOG_DIR}/stdout.log"
STDERR_LOG="${LOG_DIR}/stderr.log"
LABEL="dev.fjorn.${SERVICE_NAME}"

echo "=== ${SERVICE_NAME} Agent Status ==="
if launchctl list "$LABEL" >/dev/null 2>&1; then
    echo "Status: Loaded and running"
else
    echo "Status: Not loaded"
fi

echo ""
echo "=== Recent STDERR (last ${LOG_LINES} lines) ==="
if [ -f "$STDERR_LOG" ]; then
    tail -n "$LOG_LINES" "$STDERR_LOG" 2>/dev/null || echo "No stderr content"
else
    echo "No stderr log file found at: $STDERR_LOG"
fi

echo ""
echo "=== Recent STDOUT (last ${LOG_LINES} lines) ==="
if [ -f "$STDOUT_LOG" ]; then
    tail -n "$LOG_LINES" "$STDOUT_LOG" 2>/dev/null || echo "No stdout content"
else
    echo "No stdout log file found at: $STDOUT_LOG"
fi

echo ""
echo "=== Log Files ==="
echo "STDOUT: $STDOUT_LOG"
echo "STDERR: $STDERR_LOG"
