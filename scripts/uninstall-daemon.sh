#!/bin/bash
# Generic uninstaller for LaunchDaemon services
# Usage: ./uninstall-daemon.sh <service-name>
# Example: ./uninstall-daemon.sh myservice

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
PLIST_DIR="/Library/LaunchDaemons"
PLIST_FILE="${PLIST_DIR}/dev.fjorn.${SERVICE_NAME}.plist"
LABEL="dev.fjorn.${SERVICE_NAME}"
LOG_DIR="/var/log/${SERVICE_NAME}"
WRAPPER_SCRIPT="/usr/local/bin/${SERVICE_NAME}-daemon-wrapper"

echo -e "${ARROW} Uninstalling ${SERVICE_NAME} LaunchDaemon..."

# Check if plist file exists
if [ ! -f "$PLIST_FILE" ]; then
    echo -e "${RED}❌${RESET} Plist file not found: $PLIST_FILE"
    echo "Service may not be installed or may have a different name."
    exit 1
fi

# Check if service is loaded
if sudo launchctl print "system/${LABEL}" >/dev/null 2>&1; then
    echo "Stopping and unloading service..."

    # Disable the service first
    sudo launchctl disable "system/${LABEL}" 2>/dev/null || true

    # Stop the service if it's running
    sudo launchctl stop "$LABEL" 2>/dev/null || true

    # Bootout (unload) the service
    if sudo launchctl bootout system "$PLIST_FILE" 2>/dev/null; then
        echo -e "${GREEN}✅${RESET} Service unloaded successfully"
    else
        echo -e "${RED}❌${RESET} Warning: Failed to unload service (it may not have been running)"
    fi
else
    echo "Service is not currently loaded"
fi

# Remove the plist file
if sudo rm -f "$PLIST_FILE"; then
    echo -e "${GREEN}✅${RESET} Plist file removed: $PLIST_FILE"
else
    echo -e "${RED}❌${RESET} Failed to remove plist file"
    exit 1
fi

# Remove wrapper script
if [ -f "$WRAPPER_SCRIPT" ]; then
    if sudo rm -f "$WRAPPER_SCRIPT"; then
        echo -e "${GREEN}✅${RESET} Wrapper script removed: $WRAPPER_SCRIPT"
    else
        echo -e "${RED}❌${RESET} Failed to remove wrapper script"
    fi
fi

# Ask about removing logs
if [ -d "$LOG_DIR" ]; then
    echo ""
    read -p "Remove log directory $LOG_DIR? [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if sudo rm -rf "$LOG_DIR"; then
            echo -e "${GREEN}✅${RESET} Log directory removed: $LOG_DIR"
        else
            echo -e "${RED}❌${RESET} Failed to remove log directory"
        fi
    else
        echo "Log directory preserved: $LOG_DIR"
    fi
fi

echo -e "${ARROW} ${SERVICE_NAME} LaunchDaemon uninstalled successfully!"
echo ""
echo "Note: The original binary and any config files are left untouched."
echo "If you want to remove those as well, you'll need to do that manually."
