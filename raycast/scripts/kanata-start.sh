#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Kanata Start
# @raycast.mode inline

# Optional parameters:
# @raycast.icon 🌸

# Documentation:
# @raycast.author plasmadice
# @raycast.authorURL https://github.com/plasmadice

# Source shared helper functions
source "$HOME/.local/bin/kanata-common.sh"

# Retrieve password from keychain
if ! get_keychain_password; then
  exit 1
fi

# Get plists for available devices
plists_to_start=()
while IFS= read -r plist; do
  plists_to_start+=("$plist")
done < <(get_plists_for_available_devices)

if [ ${#plists_to_start[@]} -eq 0 ]; then
  exit 1
fi

success_count=0
failed_count=0

for plist in "${plists_to_start[@]}"; do
  label=$(basename "$plist" .plist)
  if echo "$CLI_PASSWORD" | sudo -S -k launchctl bootstrap system "$plist" >/dev/null 2>&1; then
    ((success_count++))
  else
    ((failed_count++))
    echo "⚠️  Failed to start $label"
  fi
done

if [ $failed_count -eq 0 ]; then
  echo "✅ All $success_count kanata daemon(s) started successfully!"
else
  echo "⚠️  $success_count/$((success_count + failed_count)) daemon(s) started successfully"
  exit 1
fi
