#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title bbctl Restart
# @raycast.mode inline

# Optional parameters:
# @raycast.icon ♻️

# Documentation:
# @raycast.author fjorn
# @raycast.authorURL https://github.com/ferntheplant

# CONFIGURATION - Edit these values for your service
SERVICE_NAME="bbctl-imessage"  # Change this to your service name

service_label="dev.fjorn.${SERVICE_NAME}"
plist_file="${HOME}/Library/LaunchAgents/dev.fjorn.${SERVICE_NAME}.plist"

# Stop and start the agent (no sudo needed for LaunchAgents)
if launchctl unload "$plist_file" 2>/dev/null && launchctl load "$plist_file" 2>/dev/null; then
  echo "✅ ${SERVICE_NAME} restarted successfully!"
else
  echo "❌ Failed to restart ${SERVICE_NAME}."
  echo "Check if agent exists: launchctl list | grep $SERVICE_NAME"
  exit 1
fi
