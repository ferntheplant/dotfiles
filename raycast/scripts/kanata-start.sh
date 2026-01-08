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

# Retrieve password from keychain https://scriptingosx.com/2021/04/get-password-from-keychain-in-shell-scripts/
# Added with security add-generic-password -s 'kanata'  -a 'myUser' -w 'myPassword'
# Retrieve password with security find-generic-password -w -s 'kanata' -a 'myUser'
# Deleted with security delete-generic-password -s 'kanata' -a 'myUser'

# Name of the password in the keychain
pw_name="kanata" # name of the password in the keychain
# current username e.g. "viper"
pw_account=$(id -un)

if ! cli_password=$(security find-generic-password -w -s "$pw_name" -a "$pw_account"); then
  echo "❌ Could not get password (error $?)"
  exit 1
fi

# Find all kanata plists
plists=$(ls /Library/LaunchDaemons/com.kanata.*.plist 2>/dev/null || true)

if [ -z "$plists" ]; then
  echo "❌ No kanata daemons found"
  exit 1
fi

success_count=0
failed_count=0

for plist in $plists; do
  if echo "$cli_password" | sudo -S -k launchctl bootstrap system "$plist" >/dev/null 2>&1; then
    ((success_count++))
  else
    ((failed_count++))
    label=$(basename "$plist" .plist)
    echo "⚠️  Failed to start $label"
  fi
done

if [ $failed_count -eq 0 ]; then
  echo "✅ All $success_count kanata daemon(s) started successfully!"
else
  echo "⚠️  $success_count/$((success_count + failed_count)) daemon(s) started successfully"
  exit 1
fi
