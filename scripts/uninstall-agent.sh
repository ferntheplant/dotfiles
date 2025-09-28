#!/usr/bin/env bash
# Uninstaller for LaunchAgent services
# Usage: ./uninstall-agent.sh <service-name>

set -euo pipefail

# Color variables
MAGENTA='\033[35m'
RED='\033[31m'
GREEN='\033[32m'
RESET='\033[0m'
ARROW="${MAGENTA}==>${RESET}"

# Validate arguments
if [ $# -ne 1 ]; then
    echo "Usage: $0 <service-name>"
    echo "Example: $0 myservice"
    exit 1
fi

SERVICE_NAME="$1"
PLIST_DIR="${HOME}/Library/LaunchAgents"
PLIST_FILE="${PLIST_DIR}/dev.fjorn.${SERVICE_NAME}.plist"
LABEL="dev.fjorn.${SERVICE_NAME}"
LOG_DIR="${HOME}/Library/Logs/${SERVICE_NAME}"

echo -e "${ARROW} Uninstalling ${SERVICE_NAME} LaunchAgent..."

# Check if plist file exists
if [ ! -f "$PLIST_FILE" ]; then
    echo -e "${RED}❌${RESET} Plist file not found: $PLIST_FILE"
    echo "Service may not be installed or may have a different name."
    exit 1
fi

# Check if service is loaded and unload it
if launchctl list "$LABEL" >/dev/null 2>&1; then
    echo "Unloading service..."
    if launchctl unload "$PLIST_FILE"; then
        echo -e "${GREEN}✅${RESET} Service unloaded successfully"
    else
        echo -e "${RED}❌${RESET} Warning: Failed to unload service"
    fi
else
    echo "Service is not currently loaded"
fi

# Remove the plist file
if rm -f "$PLIST_FILE"; then
    echo -e "${GREEN}✅${RESET} Plist file removed: $PLIST_FILE"
else
    echo -e "${RED}❌${RESET} Failed to remove plist file"
    exit 1
fi

# Ask about removing logs
if [ -d "$LOG_DIR" ]; then
    echo ""
    read -p "Remove log directory $LOG_DIR? [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if rm -rf "$LOG_DIR"; then
            echo -e "${GREEN}✅${RESET} Log directory removed: $LOG_DIR"
        else
            echo -e "${RED}❌${RESET} Failed to remove log directory"
        fi
    else
        echo "Log directory preserved: $LOG_DIR"
    fi
fi

echo -e "${ARROW} ${SERVICE_NAME} LaunchAgent uninstalled successfully!"
