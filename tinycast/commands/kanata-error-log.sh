#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Kanata Error Log
# @raycast.mode fullOutput

# Optional parameters:
# @raycast.icon 🔥

# Documentation:
# @raycast.description Output /Library/Logs/Kanata/kanata.err.log
# @raycast.author plasmadice
# @raycast.authorURL https://github.com/plasmadice

# Source shared helper functions
source "$HOME/.local/bin/kanata-common.sh"

# Get configs for available devices
configs=()
while IFS= read -r config; do
  configs+=("$config")
done < <(get_configs_for_available_devices)

if [ ${#configs[@]} -eq 0 ]; then
  echo "No kanata error logs found for detected devices"
  exit 0
fi

# Find error logs for the available configs
for config in "${configs[@]}"; do
  log="/var/log/kanata-${config}.err"
  if [ -f "$log" ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📋 Error log for: $config"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    tail -n 100 "$log"
    echo
  fi
done
