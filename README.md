# Dotfiles Setup

## Profiles

The gitignored `.work/profile` file selects what a machine gets. A machine without the file is
`desktop`.

| Profile | Packages | Stow packages |
| --- | --- | --- |
| `desktop` | `.Nanobrewfile` and `.Nanobrewfile.desktop` | all of them |
| `server` (lil-homie) | `.Nanobrewfile` only | all except aerospace, kanata, librewolf, linearmouse, and zed |

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
   - disable the Spotlight shortcut (Raycast uses it)
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
8. Launch the apps that add themselves to the login items: Hidden Bar, Pandan, macshot, Handy, and
   Syncthing. Add AeroSpace to the login items by hand.
9. Load the newest Raycast export from `raycast/` and the Stats config from `stats/Stats.plist`.
   Both apps then add themselves to the login items.
10. Log out and back in, so that the menu bar spacing from `scripts/macos-defaults.sh` applies.

## Leave a machine

Export the settings that no script saves, then commit. `leave-machine` rewrites the package
lists and exports the Handy settings.

```bash
cd ~/dotfiles
# LibreWolf: export Vimium and Dark Reader settings
bun librewolf/get-addons-list.js ~/Library/Application\ Support/librewolf/Profiles/<profile>
# Sidebery: Settings > Help > Export addon data, without snapshots; then drop the favicon data
jq 'del(.favicons, .favDomains, .favHashes)' ~/Downloads/sidebery-data-*.json > librewolf/sidebery-data.json
# Stats: export settings to stats/Stats.plist
# Raycast: "Export Settings and Data" to ~/dotfiles/raycast
scripts/rex-settings.sh export
leave-machine -c
```

TODO: [Raycast plaintext config](https://gist.github.com/jeremy-code/50117d5b4f29e04fcbbb1f55e301b893)

TODO: find way to keep `.Nanobrewfile` and `.Nanobrewfile.desktop` clean (nb leaves drops packages that are also dependencies, such as jq)

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

This list shows the command-line tools on the desktop Mac. The source column tells you how to install each tool:

- `nanobrew core`: a line in `.Nanobrewfile`; every machine gets it
- `nanobrew desktop`: a line in `.Nanobrewfile.desktop`; only the desktop profile gets it
- `mise`: a tool in `.config/mise/config.toml`; every machine gets it, the server too
- `manual`: the installer script from the vendor (see the setup steps)

`borders` is in `.Nanobrewfile.desktop`, but Homebrew installed it, not nanobrew.

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
| borders | Homebrew (see note) | null |
| colima | nanobrew desktop | null |
| docker | nanobrew desktop | null |
| docker-buildx | nanobrew desktop | null |
| docker-completion | nanobrew desktop | null |
| docker-compose | nanobrew desktop | null |
| docker-credential-helper | nanobrew desktop | null |
| kanata | nanobrew desktop | `.config/kanata` |
| mas | nanobrew desktop | null |
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
| aerospace | nanobrew | `.config/aerospace/aerospace.toml` | yes |
| agentsview | nanobrew | null | |
| beeper | nanobrew | null | |
| ghostty | nanobrew | `.config/ghostty` | |
| handy | nanobrew | `dotfiles/handy/settings.json` via `scripts/handy-settings.sh` | |
| hiddenbar | nanobrew | `scripts/macos-defaults.sh` | yes |
| latest | nanobrew | null | yes |
| librewolf | nanobrew | `.librewolf/librewolf.overrides.cfg`, `dotfiles/librewolf` | |
| linearmouse | nanobrew | `.config/linearmouse` | yes |
| macshot | nanobrew | null | yes |
| monitorcontrol | nanobrew | null | yes |
| raycast | nanobrew | `dotfiles/raycast` | yes |
| spotify | nanobrew | null | |
| stats | nanobrew | `dotfiles/stats/Stats.plist` | yes |
| syncthing-app | nanobrew | null | |
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
