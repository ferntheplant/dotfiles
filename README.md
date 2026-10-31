# Dotfiles Setup

## Profiles

The gitignored `.work/profile` file selects what a machine gets. A machine without the file is
`desktop`.

| Profile | Packages | Stow packages |
| --- | --- | --- |
| `desktop` | `.Nanobrewfile` and `.Nanobrewfile.desktop` | all of them |
| `server` (lil-homie) | `.Nanobrewfile` only | all except kanata, librewolf, linearmouse, paneru, and zed |

```bash
nb bundle install .Nanobrewfile
nb bundle install .Nanobrewfile.desktop # desktop only
scripts/install.sh                      # stow, skills, Claude settings; safe to run again
                                        # desktop only: macOS defaults, Handy settings
```

`leave-brew` puts a new formula in `.Nanobrewfile` and a new cask in `.Nanobrewfile.desktop`.
Move a line by hand when that guess is wrong. It does not run on the server profile.

### Server (lil-homie)

The server keeps its own apps and services (OrbStack, Tailscale, and others) in the
lil-homie repo. Rex is not in nanobrew: install it from `Rex.dmg`. Run `mise install`, and then
run `agent-browser install` once, so that agents have a browser.

```bash
echo server > ~/dotfiles/.work/profile
cd ~/dotfiles && git pull --ff-only && scripts/install.sh # sync after a push
```

## Set up a new desktop Mac

1. Set the macOS settings that `scripts/macos-defaults.sh` does not set:
   - key repeat timing
   - Finder: show hidden files, no tags, list view
   - disable all notifications
   - auto-hide the Dock, always show the menu bar
   - 24-hour clock in the menu bar
   - disable the Spotlight shortcut (Tinycast uses it)
2. Clone the repo. `git` comes with the Xcode command line tools.

   ```bash
   xcode-select --install
   git clone https://github.com/ferntheplant/dotfiles ~/dotfiles
   ```

3. Install [mise](https://mise.jdx.dev/installing-mise.html) with its installer. The runtimes come
   from `.config/mise/config.toml` after step 6.

   ```bash
   curl https://mise.run | sh
   ```

4. Install [nanobrew](https://github.com/justrach/nanobrew) and the packages. Nanobrew does not
   install App Store apps, so `mas` installs the `mas` lines. Sign in to the App Store first.

   ```bash
   curl -fsSL https://nanobrew.trilok.ai/install | bash
   cd ~/dotfiles
   nb bundle install .Nanobrewfile
   nb bundle install .Nanobrewfile.desktop
   sed -n 's/^mas .*id: //p' .Nanobrewfile.desktop | xargs mas install
   ```

5. Install the apps and fonts that no package file installs:
   - [MesloLGS NF](https://github.com/romkatv/powerlevel10k/blob/master/font.md) (Ghostty and Rex use it)
   - Rex from `Rex.dmg`
   - the other `download` apps in the [Apps](#apps) table
6. Run the installer scripts. `install.sh` is safe to run again.

   ```bash
   scripts/install.sh            # stow, skills, Claude settings, macOS defaults, Handy settings
   scripts/rex-settings.sh import
   mise install
   ```

7. Set up LibreWolf. `install.sh` already linked `~/.librewolf/librewolf.overrides.cfg`, which keeps
   cookies and site data when LibreWolf closes and loads `userChrome.css`.
   - link `librewolf/userChrome.css` to `chrome/userChrome.css` in the profile (`about:profiles`)
   - install the add-ons in `librewolf/addons.json`
   - import the Vimium and Dark Reader settings from `librewolf/`
   - import `librewolf/sidebery-data.json` in Sidebery: Settings > Help > Import addon data
   - in `about:addons` > Manage Extension Shortcuts, set Sidebery's sidebar shortcut to Ctrl+B
   - link the 1Password native messaging files from
     `~/Library/Application Support/Mozilla/NativeMessagingHosts` into
     `~/Library/Application Support/librewolf/NativeMessagingHosts`
8. Launch the apps that add themselves to the login items: Hidden Bar, Pandan, Handy,
   Syncthing, Tinycast, and Vorssaint. Run `paneru install` to add the Paneru launch agent, then
   `paneru start`, and give Paneru Accessibility access when macOS asks. Paneru stops with an
   error until "Displays have separate Spaces" is on; `scripts/macos-defaults.sh` turns it on, and
   it applies after step 11.
9. Set up Tinycast: Settings > Backup > Import, and pick `tinycast/settings.tinycast`. It restores
   the settings, hotkeys (Cmd+Space), quicklinks, and the custom commands that run
   `tinycast/commands`, with Show confirmation on. `tinycast/quicklinks.json` is a readable copy of
   the quicklinks; do not import it too, or the quicklinks appear twice.
10. Set up Vorssaint: Settings > Backup > Import settings…, and pick `vorssaint/settings.plist`.
    Vorssaint restarts with the CPU temperature readout, Fan Control, and Keep Awake. Tinycast and
    Paneru do the launcher, clipboard, and window jobs.
11. Log out and back in, so that the menu bar spacing and the Spaces setting from
    `scripts/macos-defaults.sh` apply.

## Leave a machine

Export the settings that no script saves, then commit. `leave-machine` rewrites the package
lists and exports the Handy settings.

```bash
cd ~/dotfiles
# LibreWolf: export Vimium and Dark Reader settings
bun librewolf/get-addons-list.js ~/Library/Application\ Support/librewolf/Profiles/<profile>
# Sidebery: Settings > Help > Export addon data, without snapshots; then drop the favicon data
jq 'del(.favicons, .favDomains, .favHashes)' ~/Downloads/sidebery-data-*.json > librewolf/sidebery-data.json
# Tinycast: Settings > Backup > Export, with only Settings & Shortcuts ticked (no clipboard
#   history, snippets, notes, or launcher learning: this repo is public) -> tinycast/settings.tinycast
# Tinycast: export the quicklinks as JSON -> tinycast/quicklinks.json
# Vorssaint: Settings > Backup > Export settings… -> vorssaint/settings.plist
scripts/rex-settings.sh export
leave-machine -c
```

TODO: find way to keep `.Nanobrewfile` and `.Nanobrewfile.desktop` clean (nb leaves drops packages that are also dependencies, such as jq)

## Colima vs Docker Desktop (vs Orbstack)

See this [thread](https://github.com/abiosoft/colima/discussions/273) for installing buildx

## Config TODOs

- Beeper config
- hiddenbar config
- setup global prettier/biome with mise

Refactor all configs to not be nested in redundant `.config`

## Kanata Launcher Command Template

Tinycast imports script files in the Raycast script command format (Settings > Commands > Import
Raycast Scripts), so the commands in `tinycast/commands` keep the `@raycast` metadata.

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

This list shows the command-line tools on the desktop Mac. The source column tells you how to install each tool:

- `nanobrew core`: a line in `.Nanobrewfile`; every machine gets it
- `nanobrew desktop`: a line in `.Nanobrewfile.desktop`; only the desktop profile gets it
- `mise`: a tool in `.config/mise/config.toml`; every machine gets it, the server too
- `manual`: the installer script from the vendor (see the setup steps)

| Tool | Source | Config |
| --- | --- | --- |
| atuin | nanobrew core | `.config/atuin/config.toml` |
| bash | nanobrew core | null |
| bat | nanobrew core | `.config/bat` |
| btop | nanobrew core | `.config/btop` |
| carapace | nanobrew core | `.zshrc` |
| eza | nanobrew core | `.zshrc` |
| fd | nanobrew core | null |
| ffmpeg | nanobrew core | null |
| fzf | nanobrew core | `.zshrc` |
| gh | nanobrew core | `.config/gh/config.yml` |
| git-delta | nanobrew core | `.gitconfig` |
| grep | nanobrew core | null |
| gzip | nanobrew core | null |
| httpie | nanobrew core | null |
| jq | nanobrew core | null |
| leaf-markdown-viewer | nanobrew core | `.config/leaf/config.toml` |
| less | nanobrew core | null |
| libpq | nanobrew core | null |
| mole | nanobrew core | null |
| ripgrep | nanobrew core | null |
| rtk | nanobrew core | null |
| starship | nanobrew core | `.config/starship` |
| stow | nanobrew core | `dotfiles/scripts/install.sh` |
| tree | nanobrew core | null |
| unzip | nanobrew core | null |
| vivid | nanobrew core | null |
| zmx | nanobrew core | `.zshrc` |
| zoxide | nanobrew core | `.zshrc` |
| zsh-autosuggestions | nanobrew core | `.zshrc` |
| zsh-syntax-highlighting | nanobrew core | `.zsh` (theme files) |
| zx | nanobrew core | null |
| 1password-cli | nanobrew core | null |
| claude-code | nanobrew core | `.claude` |
| colima | nanobrew desktop | null |
| docker | nanobrew desktop | null |
| docker-buildx | nanobrew desktop | null |
| docker-completion | nanobrew desktop | null |
| docker-compose | nanobrew desktop | null |
| docker-credential-helper | nanobrew desktop | null |
| kanata | nanobrew desktop | `.config/kanata` |
| mas | nanobrew desktop | null |
| paneru | nanobrew desktop | `.config/paneru/paneru.toml` |
| chromedriver | nanobrew desktop | null |
| font-monaspace | nanobrew desktop | null |
| agent-browser | mise | null |
| bun | mise | `.config/mise/config.toml` |
| duckdb | mise | `.duckdbrc` |
| gitleaks | mise | null |
| go | mise | `.config/mise/config.toml` |
| helix | mise | `.config/helix` |
| just | mise | null |
| node | mise | `.config/mise/config.toml` |
| opencode | mise | `.config/opencode` |
| pnpm | mise | `.config/mise/config.toml` |
| python | mise | `.config/mise/config.toml` |
| rust | mise | `.config/mise/config.toml` |
| shellcheck | mise | null |
| uv | mise | `.config/mise/config.toml` |
| yq | mise | null |
| zig | mise | `.config/mise/config.toml` |
| mise | manual | `.config/mise/config.toml` |

### Apps

This list shows the apps on the desktop Mac. The source column tells you how to install each app:

- `nanobrew`: a cask in `.Nanobrewfile.desktop`
- `mas`: a Mac App Store entry in `.Nanobrewfile.desktop`
- `download`: a manual download from the vendor; no package file installs it

| App | Source | Config | macOS only |
| --- | --- | --- | --- |
| 1password | nanobrew | null | |
| agentsview | nanobrew | null | |
| beeper | nanobrew | null | |
| ghostty | nanobrew | `.config/ghostty` | |
| handy | nanobrew | `dotfiles/handy/settings.json` via `scripts/handy-settings.sh` | |
| hiddenbar | nanobrew | `scripts/macos-defaults.sh` | yes |
| latest | nanobrew | null | yes |
| librewolf | nanobrew | `.librewolf/librewolf.overrides.cfg`, `dotfiles/librewolf` | |
| linearmouse | nanobrew | `.config/linearmouse` | yes |
| monitorcontrol | nanobrew | null | yes |
| spotify | nanobrew | null | |
| syncthing-app | nanobrew | null | |
| tinycast | nanobrew (`abue-ammar/tinycast` tap) | `dotfiles/tinycast` | yes |
| vorssaint | nanobrew | `dotfiles/vorssaint/settings.plist` | yes |
| zoom | nanobrew | null | |
| Equinox | mas | null | yes |
| Pandan | mas | null | yes |
| Tailscale | mas | null | |
| Xcode | mas | null | yes |
| Rex | download (`Rex.dmg`) | `.config/rex`, `dotfiles/rex/settings.json` via `scripts/rex-settings.sh` | |
| balenaEtcher | download | null | |
| freewrite | download | null | |
| Google Chrome | download | null | |
| Mullvad VPN | download | null | |
| Signal | download | null | |
| Steam | download | null | |
| Suzuri | download | null | |
| VIA | download | null | |
| VLC | download | null | |
