#!/bin/bash

# Shared helper functions for kanata Raycast scripts

# Map device name to config file
# Returns config name (without .kbd extension) for a given device name
get_config_for_device() {
  local device="$1"
  case "$device" in
    "Apple Internal Keyboard"|"Magic Keyboard")
      echo "macbook"
      ;;
    "Advantage2 Keyboard")
      echo "advantage"
      ;;
    "AVA")
      echo "ava"
      ;;
    "Corne-ish Zen")
      echo "zen"
      ;;
    "Agar Mini BLE (USB)")
      echo "agar"
      ;;
    *)
      echo ""
      ;;
  esac
}

# Get list of available devices from kanata --list
# Outputs device names to stdout, one per line
get_available_devices() {
  local kanata_output
  if ! kanata_output=$(kanata --list 2>/dev/null); then
    echo "❌ Could not run 'kanata --list'" >&2
    return 1
  fi

  local available_devices=()
  local device

  # Check each device in our mapping - if it appears in the output, it's available
  # Explicitly list devices to avoid potential issues with associative array key expansion
  local devices=(
    "Apple Internal Keyboard"
    "Magic Keyboard"
    "Advantage2 Keyboard"
    "AVA"
    "Corne-ish Zen"
    "Agar Mini BLE (USB)"
  )

  for device in "${devices[@]}"; do
    # Check if device name appears in kanata output (use -q for quiet, -F for fixed string)
    if echo "$kanata_output" | grep -qF "$device"; then
      available_devices+=("$device")
    fi
  done

  if [ ${#available_devices[@]} -eq 0 ]; then
    echo "❌ No keyboard devices detected" >&2
    return 1
  fi

  printf '%s\n' "${available_devices[@]}"
  return 0
}

# Get config names for currently available devices
# Outputs config names to stdout, one per line
get_configs_for_available_devices() {
  local device
  local configs=()

  # Read devices line by line to preserve device names with spaces
  while IFS= read -r device; do
    # Trim any whitespace
    device=$(echo "$device" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    [[ -z "$device" ]] && continue

    # Look up config using mapping function
    local config_name
    config_name=$(get_config_for_device "$device")

    # Add config if found and not already in list
    if [[ -n "$config_name" ]] && [[ ! " ${configs[*]} " =~ " ${config_name} " ]]; then
      configs+=("$config_name")
    fi
  done < <(get_available_devices)

  if [ ${#configs[@]} -eq 0 ]; then
    echo "⚠️  No matching kanata configs found for detected devices" >&2
    return 1
  fi

  printf '%s\n' "${configs[@]}"
  return 0
}

# Get all kanata plist paths (regardless of device connection)
# Outputs plist paths to stdout, one per line
get_all_kanata_plists() {
  local plists=()
  local plist
  for plist in /Library/LaunchDaemons/com.kanata.*.plist; do
    [[ -f "$plist" ]] && plists+=("$plist")
  done
  printf '%s\n' "${plists[@]}"
}

# Get service labels for kanata daemons that are currently loaded/running
# Requires CLI_PASSWORD to be set (e.g. via get_keychain_password)
# Outputs service labels to stdout, one per line (e.g. com.kanata.macbook)
get_running_kanata_services() {
  echo "$CLI_PASSWORD" | sudo -S -k launchctl list 2>/dev/null | grep kanata | awk '{print $3}'
}

# Get plist paths for currently available devices
# Outputs plist paths to stdout, one per line
get_plists_for_available_devices() {
  local configs
  if ! configs=($(get_configs_for_available_devices)); then
    return 1
  fi

  local plists=()
  local config
  for config in "${configs[@]}"; do
    local plist="/Library/LaunchDaemons/com.kanata.${config}.plist"
    if [ -f "$plist" ]; then
      plists+=("$plist")
    fi
  done

  if [ ${#plists[@]} -eq 0 ]; then
    echo "❌ No kanata daemons found for detected devices" >&2
    return 1
  fi

  printf '%s\n' "${plists[@]}"
  return 0
}

# Get password from keychain
# Sets CLI_PASSWORD variable on success, returns non-zero on failure
get_keychain_password() {
  local pw_name="${1:-kanata}"
  local pw_account
  pw_account=$(id -un)

  if ! CLI_PASSWORD=$(security find-generic-password -w -s "$pw_name" -a "$pw_account" 2>/dev/null); then
    echo "❌ Could not get password (error $?)" >&2
    return 1
  fi

  return 0
}
