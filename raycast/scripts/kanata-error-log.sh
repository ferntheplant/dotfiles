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

# Find all kanata error logs
error_logs=$(ls /var/log/kanata-*.err 2>/dev/null || true)

if [ -z "$error_logs" ]; then
  echo "No kanata error logs found"
  exit 0
fi

for log in $error_logs; do
  config_name=$(basename "$log" .err | sed 's/kanata-//')
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "📋 Error log for: $config_name"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  tail -n 100 "$log"
  echo
done
