#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title bbctl Restart
# @raycast.mode inline

# Optional parameters:
# @raycast.icon ♻️

# Documentation:
# @raycast.author fjorn
# @raycast.authorURL https://github.com/fjorn

# CONFIGURATION - Edit these values for your service
SERVICE_NAME="bbctl-imessage"  # Change this to your service name
KEYCHAIN_SERVICE="kanata"  # piggyback on kanata's keychain service

# Retrieve password from keychain
# Add password with: security add-generic-password -s "$KEYCHAIN_SERVICE" -a "$(id -un)" -w 'yourpassword'
# Delete password with: security delete-generic-password -s "$KEYCHAIN_SERVICE" -a "$(id -un)"

pw_account=$(id -un)
service_label="dev.fjorn.${SERVICE_NAME}"

if ! cli_password=$(security find-generic-password -w -s "$KEYCHAIN_SERVICE" -a "$pw_account" 2>/dev/null); then
  echo "❌ Could not get password from keychain"
  echo "Add password with: security add-generic-password -s '$KEYCHAIN_SERVICE' -a '$pw_account' -w 'yourpassword'"
  exit 1
fi

# Stop and start the service (launchctl stop will automatically restart if KeepAlive is true)
if echo "$cli_password" | sudo -S -k launchctl stop "$service_label" >/dev/null 2>&1; then
  echo "✅ ${SERVICE_NAME} restarted successfully!"
else
  echo "❌ Failed to restart ${SERVICE_NAME}."
  echo "Check if service exists: sudo launchctl print system/${service_label}"
  exit 1
fi
