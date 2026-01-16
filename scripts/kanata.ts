#!/usr/bin/env zx

import { $, fs } from 'zx'

// Define config files to install as daemons
// Add more config files here as needed
const CONFIG_FILES = [
  "macbook.kbd",
  "advantage.kbd",
  "ava.kbd",
  "zen.kbd"
]

// Base paths
const USER_CONFIG_DIR = `${process.env.HOME}/.config/kanata`
const ROOT_CONFIG_DIR = "/etc/kanata"
const PLIST_DIR = "/Library/LaunchDaemons"

const say = (msg: string) => console.log(`\n\x1b[1m==> ${msg}\x1b[0m`)
const die = (msg: string) => {
  console.error(`ERROR: ${msg}`)
  process.exit(1)
}

// Function to install a single kanata daemon
const install_kanata_daemon = async (config_file: string) => {
  const config_name = config_file.replace('.kbd', '') // Remove .kbd extension

  const user_config = `${USER_CONFIG_DIR}/${config_file}`
  const root_config = `${ROOT_CONFIG_DIR}/${config_file}`
  const label = `com.kanata.${config_name}`
  const plist_path = `${PLIST_DIR}/${label}.plist`
  const log_out = `/var/log/kanata-${config_name}.log`
  const log_err = `/var/log/kanata-${config_name}.err`

  say(`Installing daemon for ${config_file}...`)

  // Check if user config exists
  if (!await fs.pathExists(user_config)) {
    console.log(`⚠️  Config not found: ${user_config}, skipping...`)
    return false
  }

  // Copy config to root-readable location
  say(`  Copying config to ${root_config}...`)
  await $`sudo mkdir -p ${ROOT_CONFIG_DIR}`
  await $`sudo cp ${user_config} ${root_config}`
  await $`sudo chown root:wheel ${root_config}`
  await $`sudo chmod 644 ${root_config}`

  // Write LaunchDaemon plist
  say(`  Writing LaunchDaemon plist to ${plist_path}...`)
  const KANATA_BIN = await $`command -v kanata`.quiet()
  const plist_content = `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>${label}</string>

    <key>ProgramArguments</key>
    <array>
      <string>${KANATA_BIN.stdout.trim()}</string>
      <string>-c</string>
      <string>${root_config}</string>
    </array>

    <key>RunAtLoad</key>
    <false/>

    <key>KeepAlive</key>
    <true/>

    <key>StandardOutPath</key>
    <string>${log_out}</string>

    <key>StandardErrorPath</key>
    <string>${log_err}</string>
  </dict>
</plist>`

  await $`echo ${plist_content} | sudo tee ${plist_path} >/dev/null`

  // Fix plist permissions
  say(`  Fixing plist permissions...`)
  await $`sudo chown root:wheel ${plist_path}`
  await $`sudo chmod 644 ${plist_path}`

  // Ensure logs exist
  say(`  Ensuring log files exist...`)
  await $`sudo touch ${log_out} ${log_err}`
  await $`sudo chmod 644 ${log_out} ${log_err}`

  // Load daemon (but don't start it - RunAtLoad is false)
  say(`  Loading LaunchDaemon...`)
  await $`sudo launchctl unload -w ${plist_path}`.quiet().catch(() => {})
  await $`sudo launchctl load -w ${plist_path}`

  // Immediately stop the daemon if it started
  say(`  Stopping daemon...`)
  await $`sudo launchctl bootout system ${plist_path}`.quiet().catch(() => {})

  console.log(`✅ ${config_name} daemon installed (stopped - use kanata-start to start for connected devices)`)
  return true
}

// --- Preconditions ---
if (process.platform !== 'darwin') {
  die('This script is for macOS only.')
}

if (!await fs.pathExists(USER_CONFIG_DIR)) {
  die(`Kanata config directory not found at: ${USER_CONFIG_DIR}
Make sure your dotfiles install ran first.`)
}

// --- Install Kanata ---
say('Installing kanata via Homebrew...')
await $`brew install kanata`.quiet().catch(() => $`brew upgrade kanata`)

const KANATA_BIN = await $`command -v kanata`.quiet()
say(`Using kanata at: ${KANATA_BIN.stdout.trim()}`)

// --- Install daemons for each config file ---
let SUCCESS_COUNT = 0
const FAILED_CONFIGS = []

for (const config_file of CONFIG_FILES) {
  if (await install_kanata_daemon(config_file)) {
    SUCCESS_COUNT++
  } else {
    FAILED_CONFIGS.push(config_file)
  }
}

// --- Summary ---
console.log()
console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
if (SUCCESS_COUNT === CONFIG_FILES.length) {
  console.log(`✅ All ${SUCCESS_COUNT} kanata daemon(s) installed (stopped).`)
} else {
  console.log(`⚠️  ${SUCCESS_COUNT}/${CONFIG_FILES.length} daemon(s) installed successfully.`)
  if (FAILED_CONFIGS.length > 0) {
    console.log(`Failed configs: ${FAILED_CONFIGS.join(', ')}`)
  }
}
console.log()
console.log('💡 Use \'kanata-start\' (Raycast script) to start daemons for currently connected devices.')
console.log()
console.log('Status:   sudo launchctl list | grep kanata')
console.log('Logs:     tail -f /var/log/kanata-*.log')
console.log('Errors:   tail -f /var/log/kanata-*.err')
console.log()
console.log(`NOTE:
- You may still need to grant macOS permissions:
  System Settings → Privacy & Security → Accessibility + Input Monitoring
  (Depending on your setup, macOS may require approval for the driver/tools.)
- If it doesn't work after a reboot, check the logs:
  /var/log/kanata-*.log and /var/log/kanata-*.err
- To add more config files, edit the CONFIG_FILES array at the top of this script.

NOTE`)
