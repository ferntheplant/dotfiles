# Dotfiles Setup

## Install packages

Prerequisites: Make sure the machine has a terminal and bash installed then:

1. Install [MesloLGS NF](https://github.com/romkatv/powerlevel10k/blob/master/font.md)

```bash
# Leaving machine
cd ~/dotfiles
# Floorp export settings: stylus, violentmonkey, vimium, dark reader, get-addons-list.js
# Stats export settings
# Raycast: "Export Settings and Data" to ~/dotfiles/raycast
leave-machine -c

# -------------------------------------

# Fresh machine
curl -fsSL https://raw.githubusercontent.com/ferntheplant/dotfiles/main/scripts/setup-new-machine | bash

# set global macos settings (see below)
# load Raycast config dump into Raycast (will add itself to login items)
# load Stats config (will add itself to login items)
# login to cursor
# cmd+shift+p Install from VSIX for cursor custom extensions
# launch hiddenbar, pandan, shottr, and shortcat (will add themselves to login items)
# Add aerospace to login items
# Floorp install userChrome.css
# Floorp install add-ons from list
# Floorp import: stylus, violentmonkey, vimium, dark reader
```

TODO: find way to automate dumping and loading all the settings in the comments above

TODO: [Raycast plaintext config](https://gist.github.com/jeremy-code/50117d5b4f29e04fcbbb1f55e301b893)

TODO: somehow put other macOS level settings in here

- key repeat timing
- finder settings (show hidden files, no tags, list view, etc.)
- disable all notifications
- auto-hide dock, always show menu bar
- 24h clock + menu bar clock
- disable spotlight shortcut (for raycast)

TODO: find way to keep `.Brewfile` clean

## Colima vs Docker Desktop (vs Orbstack)

See this [thread](https://github.com/abiosoft/colima/discussions/273) for installing buildx

## Config TODOs

- Beeper config
- hiddenbar config
- setup global prettier/biome with mise

Refactor all configs to not be nested in redundant `.config`

## Kanata Raycast Script Template

```bash
#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title myservice Restart
# @raycast.mode inline

# Optional parameters:
# @raycast.icon ♻️

# Documentation:
# @raycast.author fjorn
# @raycast.authorURL https://github.com/fjorn

# CONFIGURATION - Edit these values for your service
SERVICE_NAME="myservice"  # Change this to your service name
KEYCHAIN_SERVICE="myservice"  # Change this to your keychain service name

# Retrieve password from keychain
# Add password with: security add-generic-password -s "$KEYCHAIN_SERVICE" -a "$(id -un)" -w 'yourpassword'
# Delete password with: security delete-generic-password -s "$KEYCHAIN_SERVICE" -a "$(id -un)"

pw_account=$(id -un)
service_label="com.example.${SERVICE_NAME}"

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
```

## Manual list of packages

TODO:

```
cat > ~/.local/bin/osc52 <<'EOF'
#!/usr/bin/env bash
printf "\033]52;c;%s\a" "$(base64 | tr -d '\n')"
EOF
```

### CLI

atuin|`.config/atuin/config.toml`
bat|`.config/bat`
cloudflared|null
carapace|`.zshrc`
diff-so-fancy|`.gitconfig`
docker|null
docker-buildx|null
docker-completion|null
docker-compose|null
docker-credential-helper|null
duckdb|`.duckdbrc`
eza|`.zshrc`
fd|null
fzf|`.zshrc`
gh|`.gitconfig`
git-delta|`.gitconfig`
gitleaks|null
grep|null
helix|`.config/helix/config.tml`
httpie|null
jq|null
just|null
kanata|`.config/kanata`
less|null
mas|null (MAC)
ripgrep|null
opencode|null
shellcheck|null
starship|`.config/starship`
stow|`dotfiles/scripts/instal.sh`
unzip|null
vivid|`theme`
zelliij|`.config/zellij`
zoxide|null
zsh-autosuggestions|`.zshrc`
zsh-syntax-highlighting|`theme`
zx|null
borders|null (MAC)
1password-cli|null
aerospace|`.config/aerospace/aerospace.toml` (MAC)
claude-code|null
codex|null
font-monaspace|null

### Apps

cursor|`/Library/Application Support/Cursor/User`
beeper|null
ghostty|`.config/ghostty`
hiddenbar|null (MAC)
latest|null (MAC)
linear-linear|null
linearmouse|null (MAC)
monitorcontrol|null (MAC)
notion|null (MAC)
raycast|`.config/raycast` (MAC)
shottr|null (MAC)
spotify|null
stats|`dotfiles/stats/Stats.plist` (MAC)
syncthing-app|null
Equinox|null (MAC)
Pandan|null (MAC)
QuickShade|null (MAC)
floorp|`dotfiles/floorp`
