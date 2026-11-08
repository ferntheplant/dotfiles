# Dotfiles Setup

## Profiles

The gitignored `.work/profile` file selects what a machine gets. A machine without the file is
`desktop`.

| Profile | Packages | Stow packages |
| --- | --- | --- |
| `desktop` | `.Nanobrewfile` and `.Nanobrewfile.desktop` | all of them |
| `server` (lil-homie) | `.Nanobrewfile` only | all except kanata, librewolf, paneru, and zed |
| `infra` (micro-homie) | `.Nanobrewfile` without the casks, the macOS-only formulas, and kata | as `server`, and also not ghostty, claude, kata, or pi |

`infra` is for micro-homie, which runs the homielab services. It gets no agent config: no Claude
Code or Pi settings, no skills, and no Kata client or hooks. Agents run on lil-homie or a
laptop and reach micro-homie through Rex (see the Rex section of the homielab README). Linux
supports only `infra`. `MACOS_ONLY` and `AGENT_ONLY` in `scripts/install-packages.sh` and in
`scripts/install.sh` list what it skips.

```bash
scripts/install-packages.sh # nanobrew packages for the profile and the OS; safe to run again
scripts/install.sh          # stow, skills, Claude and Pi settings, Kata hooks; safe to run again
                            # desktop only: macOS defaults, Handy settings
```

`leave-brew` puts a new formula in `.Nanobrewfile` and a new cask in `.Nanobrewfile.desktop`.
Move a line by hand when that guess is wrong. It does not run on the server or infra profile. A new
formula that has no Linux build must also go in `MACOS_ONLY` in `scripts/install-packages.sh`.

### Server (lil-homie)

The server keeps its own apps and services (OrbStack, Tailscale, and others) in the
lil-homie repo. Rex is not in nanobrew: install it from `Rex.dmg`. Run `mise install`, and then
run `agent-browser install` once, so that agents have a browser.

```bash
echo server > ~/dotfiles/.work/profile
cd ~/dotfiles && git pull --ff-only && scripts/install.sh # sync after a push
```

### Linux server (micro-homie)

micro-homie runs Debian 13 with no desktop. Its host setup (Docker, the 1Password CLI) is
`setup-micro-homie.sh` in the lil-homie repo. Nanobrew installs the Linux builds of most
`.Nanobrewfile` formulas. The other tools come from other sources:

- `1password-cli` (a cask): 1Password's apt repo, from `setup-micro-homie.sh`
- `claude-code` (a cask): none, because agents do not run on micro-homie
- `stow`: apt
- `zmx`: mise
- `mole`: none, because it is a macOS app

1. Install zsh, stow, and a C compiler, make zsh the login shell, and install nanobrew. mise
   builds `fj` with cargo, which needs the compiler (`build-essential`). `nb init` must run with
   sudo: it makes the `/opt/nb` and `/opt/homebrew` links to `/opt/nanobrew/prefix`. Without
   `/opt/nb`, each package fails with `incomplete relocation`.

   ```bash
   sudo apt install -y zsh stow build-essential
   chsh -s /usr/bin/zsh
   curl -fsSL https://nanobrew.trilok.ai/install | bash
   sudo /opt/nanobrew/prefix/bin/nb init
   ```

2. Install the other tools, clone the repo, and link the dotfiles.

   ```bash
   curl https://mise.run | sh
   git clone https://github.com/ferntheplant/dotfiles ~/dotfiles
   mkdir -p ~/dotfiles/.work && echo infra > ~/dotfiles/.work/profile
   cd ~/dotfiles
   PATH="/opt/nanobrew/prefix/bin:$PATH" scripts/install-packages.sh
   PATH="/opt/nanobrew/prefix/bin:$PATH" scripts/install.sh
   ~/.local/bin/mise install
   ```

To sync after a push, use the same command as lil-homie. Run `scripts/install-packages.sh` too
when `.Nanobrewfile` changes. `mise install` still installs pi and agent-browser, because the
mise config has no profiles; nothing configures them on micro-homie.

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
   scripts/install.sh            # stow, skills, Claude and Pi settings, Kata hooks, macOS defaults, Handy settings
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
   it applies after step 12.
9. Set up Tinycast: Settings > Backup > Import, and pick `tinycast/settings.tinycast`. It restores
   the settings, hotkeys (Cmd+Space), quicklinks, and the custom commands that run
   `tinycast/commands`, with Show confirmation on. `tinycast/quicklinks.json` is a readable copy of
   the quicklinks; do not import it too, or the quicklinks appear twice.
10. Set up Vorssaint: Settings > Backup > Import settings…, and pick `vorssaint/settings.plist`.
    Vorssaint restarts with the CPU temperature readout, Fan Control, and Keep Awake. Tinycast and
    Paneru do the launcher, clipboard, and window jobs.
11. Set up Sill. `scripts/macos-defaults.sh` already turned on Remote Access.
    - open Sill, and allow Screen Recording, Accessibility, and Local Network when macOS asks
    - in Sill's Settings > General, turn on Launch at login
    - pair the iPhone and the iPad again: Pair iPhone or iPad… in the Sill menu. The pairing keys
      are in the keychain, so they do not move to a new Mac.
    - away from home, the devices connect through Tailscale on TCP port 7455. Tailscale must be on
      at both ends, with Shields Up off on the Mac. Sill cannot wake a Mac that sleeps.
12. Log out and back in, so that the menu bar spacing and the Spaces setting from
    `scripts/macos-defaults.sh` apply.

## Set up the Forgejo CLI

`fj` ([forgejo-cli](https://codeberg.org/forgejo-contrib/forgejo-cli)) works with the Forgejo
instance at `https://forgejo.tail8cc0d3.ts.net`, through Tailscale. Its releases have no
macOS build, so `mise install` builds it from source with cargo on every machine. The build finds
OpenSSL through `pkg-config`, so `openssl@4` and `pkgconf` are in `.Nanobrewfile`. Install them
before `mise install`. On Linux, cargo also needs a C compiler: see step 1 of
[Linux server (micro-homie)](#linux-server-micro-homie).

`fj auth login` works only on instances it has an OAuth client for, so sign in with a token:

1. On the instance, open Settings > Applications > Generate new token. Give it **repository** read
   and write access, and **user** read access.
2. Add the token to `fj`. The command reads the token from stdin, so it does not go in the shell
   history.

   ```bash
   fj -H https://forgejo.tail8cc0d3.ts.net auth add-token
   fj -H https://forgejo.tail8cc0d3.ts.net whoami
   ```

`fj` stores the token in `keys.json`: in `~/Library/Application Support/forgejo-cli.forgejo-cli/`
on macOS, and in `~/.local/share/forgejo-cli/` on Linux. Each machine needs its own token. Inside a
clone, `fj` finds the instance from the git remote, so `-H` is not necessary there.

```bash
fj pr create          # open a pull request from the current branch
fj pr status 1        # the mergeability and CI status of pull request 1
fj actions tasks      # recent Actions runs
fj repo units prs --help   # merge styles and other pull request settings
```

## Agents

Claude Code and Pi share one set of instructions and one set of skills:

- **Instructions:** two files in `.agents/instructions/`. `constitution.md` is the
  [Clanker Constitution](https://github.com/kenn-io/constitution), and `writing.md` is the
  [ASD-STE100 writing rules](https://gist.github.com/toppa/bf7ff49d6fc44fd4fc3337248f8f2a7e). Both
  are copies with local edits, recorded in `.agents/vendored-files.jsonc`; `/rebaseline files`
  takes upstream's changes. `claude/.claude/CLAUDE.md` imports both. Pi has no imports, so
  `pi/.pi/agent/AGENTS.md` links to the constitution and `APPEND_SYSTEM.md` links to the writing rules.
- **Skills:** `.agents/skills/`, and the homielab repo's own skills in
  `~/homielab/.agents/skills/` when that checkout exists. `scripts/link-skills.sh` links each skill
  into `~/.claude/skills/`, and Pi reads that folder through the `skills` key in its settings. The
  dotfiles skills are copies; the homielab skills are links, so a `git pull` in `~/homielab`
  updates them.
- **Settings:** each agent writes its own keys to its settings file, so the file is not a link.
  `scripts/claude-settings.sh` and `scripts/pi-settings.sh` merge `settings.base.json` into it.

Pi uses the `opencode-go` provider. `scripts/pi-settings.sh` copies the OpenCode Go key from
`~/.local/share/opencode/auth.json` when that file has one. On a machine without it, run `/login` in
Pi and pick OpenCode Go. The base settings turn on the `codemode` tool and install these packages:
`pi-web-access`, `pi-subagents`, `@juicesharp/rpiv-ask-user-question`, and `pi-usage`.

## Kata

[Kata](https://www.katatracker.com/docs/) is the issue tracker for agents. Its daemon runs on
micro-homie (see the Kata section of the homielab README). This repo sets up the clients.

- **Daemon target:** `kata/.kata/config.toml` sends every `kata` command to
  `https://kata-api.tail8cc0d3.ts.net`. Without it, `kata` starts a local daemon with its own
  database. It also turns on close transcripts: `kata close` records the agent and session.
- **Actor:** each agent sets `KATA_AUTHOR`. Pi gets `pi@<host>` from
  `pi/.pi/agent/extensions/kata-env.ts`.
- **Agent hooks:** `scripts/kata-agent-hooks.sh` (run by `install.sh`) runs
  `kata agent-hook install pi`, which writes `~/.pi/agent/extensions/kata.js`. The hooks give the
  agent Kata's contract when a session starts in a repo that has a `.kata.toml`. Kata generates
  them, so they are not in this repo. Only Pi has hooks now.

To use Kata in a repo, run `kata init --project <name>` there. It writes `.kata.toml` (commit it)
and adds `.kata.local.toml` to `.gitignore`.

```bash
kata whoami                       # the actor and where it came from
kata daemon locate                # the daemon this machine uses
kata agent-hook status pi         # the installed hooks (offline)
```

micro-homie (the `infra` profile) has no Kata client: agents do not run there.

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
| kata | nanobrew core | `.kata/config.toml`; agent hooks from `scripts/kata-agent-hooks.sh`, see [Kata](#kata) |
| leaf-markdown-viewer | nanobrew core | `.config/leaf/config.toml` |
| less | nanobrew core | null |
| libpq | nanobrew core | null |
| mole | nanobrew core | null |
| openssl@4 | nanobrew core | null |
| pkgconf | nanobrew core | null |
| ripgrep | nanobrew core | null |
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
| fj (forgejo-cli) | mise (cargo) | `keys.json`; see [Set up the Forgejo CLI](#set-up-the-forgejo-cli) |
| gitleaks | mise | null |
| go | mise | `.config/mise/config.toml` |
| helix | mise | `.config/helix` |
| just | mise | null |
| node | mise | `.config/mise/config.toml` |
| pi | mise | `.pi/agent`; see [Agents](#agents) |
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
| librewolf | nanobrew | `.librewolf/librewolf.overrides.cfg`, `dotfiles/librewolf` | |
| sill | nanobrew (`saffsanity/sill` tap) | `scripts/macos-defaults.sh` | yes |
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
