# Dotfiles Setup

## Profiles

The gitignored `.work/profile` file selects what a machine gets. A machine without the file is
`desktop`.

| Profile | Packages | Stow packages |
| --- | --- | --- |
| `desktop` | `.Nanobrewfile` and `.Nanobrewfile.desktop` | all of them |
| `server` (a Mac server) | `.Nanobrewfile` only | all except kanata, librewolf, paneru, and zed |
| `infra` (a Linux server) | `.Nanobrewfile` without the casks and the macOS-only formulas | as `server`, and also not ghostty, claude, fx, kvm-pilot, or omp |
| `work` (the Pillar laptop) | as `desktop` | all of them |

`infra` is for a Linux server that runs services.
It gets no agent config: no Claude Code, omp, or fx settings, no skills, and no MCP servers.
Agents run on the Mac server or a laptop and reach the Linux server through Rex.
Linux supports only `infra`.
`MACOS_ONLY` in `scripts/install-packages.sh` lists the formulas that Linux skips.
`DESKTOP_ONLY`, `AGENT_ONLY`, and `MACOS_ONLY` in `scripts/install.sh` select the stow packages.

`work` is for the Pillar work laptop.
Claude Code keeps its own commit trailer there, without the shared agent identity.
The Pillar repo's own agent sync (`.scratch/agents/sync --laptop`) adds its skills, MCP server, and traces on top.
The Pillar link wins when a skill name is in both repos, and `scripts/link-agents.sh` skips it.
`install.sh` unstows each package that the profile skips, so a machine that changes its profile loses those links.
It does not uninstall a tool.

```bash
scripts/install-packages.sh # nanobrew packages for the profile and the OS; safe to run again
scripts/install.sh          # stow, skills, harness settings; safe to run again
                            # desktop only: macOS defaults, Handy settings
```

`leave-brew` puts a new formula in `.Nanobrewfile` and a new cask in `.Nanobrewfile.desktop`.
Move a line by hand when that guess is wrong. It does not run on the server or infra profile. A new
formula that has no Linux build must also go in `MACOS_ONLY` in `scripts/install-packages.sh`.

A Mac can also have Homebrew in `/opt/homebrew`, which links to nanobrew's prefix, so the two
tools share one Cellar. Nanobrew's kegs have no Homebrew install receipt, so Homebrew's autoremove
takes them for unused dependencies: one `brew uninstall` removed most of them. The `homebrew`
package links `~/.homebrew/brew.env`, which sets `HOMEBREW_NO_AUTOREMOVE=1` for every `brew` call,
from any shell.

### Mac server

The server keeps its own apps and services (OrbStack, Tailscale, and others) in a separate
private repo. Rex is not in nanobrew: install it from `Rex.dmg`. Run `mise install`, and then
run `agent-browser install` once, so that agents have a browser.

```bash
echo server > ~/dotfiles/.work/profile
cd ~/dotfiles && git pull --ff-only && scripts/install.sh # sync after a push
```

### Linux server

The Linux server runs Debian 13 with no desktop. Its host setup (Docker, the 1Password CLI) is
in the same private repo as the Mac server's. Nanobrew installs the Linux builds of most
`.Nanobrewfile` formulas. The other tools come from other sources:

- `1password-cli` (a cask): 1Password's apt repo, from the host setup
- `claude-code` (a cask): none, because agents do not run on the Linux server
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

To sync after a push, use the same command as the Mac server. Run `scripts/install-packages.sh` too
when `.Nanobrewfile` changes. `mise install` still installs omp and agent-browser, because the
mise config has no profiles; nothing configures them on the Linux server.

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
   scripts/install.sh            # stow, skills, harness settings, macOS defaults, Handy settings
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
instance on the tailnet. The examples below call its URL `https://forgejo.example`. Its releases
have no macOS build, so `mise install` builds it from source with cargo on every machine. The build finds
OpenSSL through `pkg-config`, so `openssl@4` and `pkgconf` are in `.Nanobrewfile`. Install them
before `mise install`. On Linux, cargo also needs a C compiler: see step 1 of
[Linux server](#linux-server).

`fj auth login` works only on instances it has an OAuth client for, so sign in with a token:

1. On the instance, open Settings > Applications > Generate new token. Give it **repository** read
   and write access, and **user** read access.
2. Add the token to `fj`. The command reads the token from stdin, so it does not go in the shell
   history.

   ```bash
   fj -H https://forgejo.example auth add-token
   fj -H https://forgejo.example whoami
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

Claude Code, omp, and fx have shared settings in this repo.

- **Instructions:** two files in `.agents/instructions/`. `constitution.md` is the
  [Clanker Constitution](https://github.com/kenn-io/constitution), and `writing.md` is the
  [ASD-STE100 writing rules](https://gist.github.com/toppa/bf7ff49d6fc44fd4fc3337248f8f2a7e). Both
  are copies with local edits, recorded in `.agents/vendored-files.jsonc`. Another repo maintains
  them, merges upstream's changes, and publishes them here, so an edit here is lost at the next
  publish. `claude/.claude/CLAUDE.md` imports both through `~/.claude/agent-instructions`, a link
  that `scripts/link-agents.sh` makes. omp loads this same entry point.
- **Skills:** `.agents/skills/`. `scripts/link-agents.sh` links each skill into `~/.claude/skills/`
  for Claude Code and omp. The skills are copies, published here the same way as the instructions
  and recorded in `.agents/vendored-skills.jsonc`. Claude Code also syncs the claude.ai account
  skills (xlsx, pptx, and others) into `~/.claude/skills/synced/`. Claude Code does not show them
  to the model.
- **Local sources:** the gitignored `.work/agent-sources` file changes the material on one machine.
  It adds skill folders before `.agents/skills/`, and it can replace the instructions folder. Use
  it to try a change before it is published here, or to add the skills that another checkout owns.
  The comment at the top of `scripts/link-agents.sh` gives the format. To go back to the published
  copies, remove the file and run the script again.
- **Settings:** each agent writes its own keys to its settings file, so the file is not a link.
  `scripts/claude-settings.sh` and `scripts/fx-settings.sh` merge `settings.base.json` into it;
  `scripts/omp-settings.sh` merges `config.base.yml` with `yq`.
- **MCP servers:** `scripts/claude-mcp.sh` registers them with `claude mcp` at user scope, because
  Claude Code owns `~/.claude.json`. The only registered server is kvm-pilot (see [KVM](#kvm)).

### omp and fx settings

`omp/.omp/agent/config.base.yml` and `fx/.fx/settings.base.json` capture the shared harness
preferences. omp uses `openai-codex/gpt-6.1-sol`; fx uses Codex `gpt-6.1-terra` with high effort.
The installer applies both on desktop, server, and work profiles, but not infra.

Edit the base files and run `scripts/install.sh`, or apply only these settings:

```bash
scripts/omp-settings.sh
scripts/fx-settings.sh
```

Both scripts merge nested objects with the base keys winning, retain unlisted machine-local
keys, and back up changed files. Repeating the merge without changes does not rewrite the file.
The live files remain writable regular files at `~/.omp/agent/config.yml` and
`~/.fx/settings.json`; settings changed in the harness are not automatically captured in the
base files. Credentials, sessions, history, databases, and caches stay outside the repo. Sign in
on each machine with `omp login` and `fx login codex`. These scripts configure installed
harnesses; they do not install the binaries.

#### omp quota status

The native extension at `omp/.omp/agent/extensions/quota-status.ts` adds separate Codex and OpenCode Go rows below the status line.
Run `stow -R omp` after an update to link the extension.
Restart omp to load it.
Keep `statusLine.showHookStatus: true` to show these rows.

Each row shows the percentage used, the reset countdown (`↻`), and the age of the report.
Codex shows its primary and secondary quota windows, plus a credit cap if the provider reports one.
OpenCode Go shows its five-hour, weekly, and monthly limits.
The rows stay visible when another provider is active.
Multiple accounts get numbered rows without account identifiers.
`unavailable` means no report exists; `?` means an amount is unknown.
Reports older than ten minutes show `stale`.
`↻due` means the reported reset time passed; it does not mean the quota is empty or full.

The extension uses omp 18.22.0's built-in providers through `ctx.modelRegistry.authStorage.usage.reports()`.
It reads reports once per minute outside the render path.
The host shares its cache, five-minute cache lifetime, failure cooldown, and credential handling with `omp usage`.
No extension code reads credentials or makes direct provider requests.
Use `omp usage --redact` for detailed limits.
See the [extension API](https://github.com/can1357/oh-my-pi/blob/v18.22.0/packages/coding-agent/src/extensibility/extensions/types.ts),
[usage API](https://github.com/can1357/oh-my-pi/blob/v18.22.0/packages/ai/src/auth/types.ts),
and built-in [Codex](https://github.com/can1357/oh-my-pi/blob/v18.22.0/packages/ai/src/usage/openai-codex.ts)
and [OpenCode Go](https://github.com/can1357/oh-my-pi/blob/v18.22.0/packages/ai/src/usage/opencode-go.ts) providers.

#### omp input mouse limits

omp 18.22.0 has no supported setting for cursor placement through mouse clicks in the input text.
`tui.mouse` controls clicks on subagent cards and extension links, not the editor cursor.
It also captures wheel events, so this configuration leaves it off.
Use the arrow keys, Home/End, or Ctrl+A/Ctrl+E to move the cursor.

The upstream fix belongs in `InputController.#handleInlineMouse` and the editor layout code.
The controller consumes every recognized mouse report before the editor receives it.
It only dispatches link activation and subagent focus.
The editor needs a supported conversion from screen coordinates to a text position, including wrapped lines and wide characters.
The public extension API does not supply that conversion.
This configuration does not replace the editor or patch the installed binary.
See the [input controller](https://github.com/can1357/oh-my-pi/blob/v18.22.0/packages/coding-agent/src/modes/controllers/input-controller.ts#L858-L877),
[TUI dispatch](https://github.com/can1357/oh-my-pi/blob/v18.22.0/packages/tui/src/tui.ts#L3101-L3149),
and [editor](https://github.com/can1357/oh-my-pi/blob/v18.22.0/packages/tui/src/components/editor.ts).

### Shared instruction and skill discovery

omp opts into Claude user discovery with `enabledProviders: [claude]`.
`skills.enableClaudeUser: true` also records the shared skill choice explicitly.
It loads `~/.claude/CLAUDE.md`, including its imports of the constitution and writing
instructions, and skills from `~/.claude/skills`. The links that `scripts/link-agents.sh` makes are
the source of both; no second copy or instruction shim is needed.

Project-root `CLAUDE.md` and `AGENTS.md` already work without this opt-in. omp keeps one context
file per directory depth; standalone `AGENTS.md` wins when both names exist at that depth.
Use an explicit `@` import when both files must contribute. omp task children retain the shared
`CLAUDE.md` imports, but omit standalone `AGENTS.md` context.

Claude provider discovery is broader than instructions and skills: supported pre/post JS/TS
hook factories and Claude plugins can also load. It does not execute Claude Code's
`settings.json` lifecycle commands such as SessionStart. The current Claude hook folder has only
standalone shell scripts, not those factory directories. Restart omp after a settings change.

### Rex support in omp

Rex `0.1.0-preview.18` has no `omp` setup target.
The shared Rex skill works in omp. It does not install automatic startup context.
`rex __internal session-start --agent omp` already returns usable plain-text context.

omp 18.20.2 already implements [OSC 7501 program status](https://www.superlogical.com/rex/docs/build/program-status.md)
for idle, working, blocked, done, and error states on interactive terminals.
No second status adapter is needed. This is source-level support; the discovery smoke proof
does not verify Rex's visual indicators.

Startup parity needs a small omp extension: obtain Rex context at session start or switch,
then append it through `before_agent_start`. Gate session naming on `ctx.agent.kind === "main"`
and the owning Rex pane/session. Children must not rename the parent's Rex session.
Reuse the installed CLI's context and skill text instead of copying its instructions.

Native Rex management also needs an `omp` harness entry and a versioned, Rex-owned extension
stub. Setup, status, and removal must handle native user/project/profile roots, preserve foreign
files, and retain shared skill ownership. Rex's installed setup command does not do this yet.
See the [Rex agent setup documentation](https://www.superlogical.com/rex/docs/automate/agent-skill.md)
and [omp extension API](https://github.com/can1357/oh-my-pi/blob/v18.20.2/docs/extensions.md).

The custom Claude resume hooks in this repo are separate from Rex's built-in setup.
No omp Rex adapter or resume hook is installed by this change.

## KVM

[kvm-pilot](https://github.com/DustinTrap/kvm-pilot) is an MCP server that lets an agent use an
IP-KVM: it reads the screen, and it can type, click, and control the power. This repo installs it
on each agent machine. The KVM is a GL.iNet Comet on the home network. It controls a gaming PC.

- **Package:** `pypi:kvm-pilot` in the mise config. `mise install` installs the `kvm-pilot` CLI and
  the `kvm-pilot-mcp` server.
- **Profile:** the `kvm-pilot` stow package links `~/.config/kvm-pilot/config.toml`. The `comet`
  profile has the Comet's address and login name, and the SSH login name for the PC.
- **SSH host:** machine-only. `~/dotfiles/.work/kvm-pilot.zsh` exports `KVM_PILOT_SSH_HOST`, the PC's
  SSH address. `.zshrc` sources it for the CLI, and `scripts/kvm-pilot-mcp.sh` sources it for the
  server. Without it, kvm-pilot has no SSH channel to the PC.
- **Password:** the macOS keychain, as service `kvm-pilot` and account `comet`. The password is not
  in this repo. `scripts/kvm-pilot-mcp.sh` reads it and starts the server.
- **Registration:** `scripts/claude-mcp.sh` (run by `install.sh`) registers the server only on a
  machine whose keychain has the password. Without it, the script prints the command to add it.

To set up a machine, add the password, then run `install.sh` again:

```bash
security add-generic-password -s kvm-pilot -a comet -w   # prompts for the Comet admin password
scripts/install.sh
claude mcp get kvm-pilot                                 # expect: Status: ✔ Connected
```

The server starts read-only (`KVM_PILOT_MCP_READ_ONLY=1`). The agent can take screenshots and read
the state, but it cannot press keys, move the mouse, or change the power. To allow one type of
action, add its `KVM_PILOT_MCP_ALLOW_*` variable (such as `KVM_PILOT_MCP_ALLOW_HID` for the keyboard
and mouse) to the registration in `scripts/claude-mcp.sh`, and remove `KVM_PILOT_MCP_READ_ONLY`.
Each action still asks for approval. The
[MCP server README](https://github.com/DustinTrap/kvm-pilot/blob/main/src/kvm_pilot/mcp/README.md)
lists the variables.

## Agent identity

Claude Code uses one identity, `<model>+claude@<host>`, for example `opus-5-5+claude@personal-macbook`.
The model is the model ID in lowercase, without a provider prefix, a `claude-` prefix, or a `[1m]` suffix.
The host is the Tailscale machine name, such as `personal-macbook`, from `scripts/tailnet-name.sh`.
The `+` separator is valid in an email address, and no model ID uses it.

You are the commit author.
The agent ends each commit message with `Co-Authored-By: <identity> <<identity>>`.
Claude Code's own trailer is off (`attribution.commit` is empty in `settings.base.json`).
The `work` profile keeps Claude Code's own commit trailer without this identity or its hook.

The SessionStart hook `claude/.claude/hooks/agent-identity.sh` reads the session model.
It writes `AGENT_IDENTITY` to `$CLAUDE_ENV_FILE`, so every Bash command gets it, also in subagents.
It also gives Claude the trailer rule as session context.
A `/model` switch keeps the identity of the session start.
`claude -p` has no session model, so the hook takes the `--model` value (an alias such as `haiku`).
Without a model, the hook keeps the fallback in `AGENT_IDENTITY` from `scripts/claude-settings.sh`.
The fallback is `<model setting>+claude@<host>`.

## Rex selector

`Cmd+Shift+O` opens **New Tab or Session** from `rex/.config/rex/init.lua`.
The form uses Python curses in a Rex floating pane. It needs no extra UI package.
It shows the destination, the active field, match counts, and keyboard help.
Directory rows show the folder name above its path. Colors use the terminal palette.
Long field values scroll to keep the cursor visible. Small panes show a size notice.

- **Host:** choose the local server or a configured Rex host.
- **Session:** choose an existing session for a new tab, or `+ new session`.
- **Directory:** search zoxide history, or type a path that starts with `/`, `~`, or `.`.
- **Name:** keep the folder name or type a new name.

`Enter` advances through the fields. It opens the destination from the name field.
`Tab` advances except in Directory, where it completes the chosen path.
`Shift+Tab` goes back. Arrows or `Ctrl+N`/`Ctrl+P` choose a match.
`Cmd+Enter` or `Ctrl+S` opens from any field. `Esc` or `Ctrl+C` cancels.
The form retains the origin session and directory. It routes selection to the origin client.
Outside the form, `Cmd+Enter` still splits the pane.

[Raptor](https://github.com/alienxp03/raptor) uses a separate native macOS panel, not a Rex popup.
Its [host](https://github.com/alienxp03/raptor/blob/master/Sources/raptor/Host/RaptorApp.swift)
places SwiftUI content in an AppKit `NSPanel`, with glass or a visual-effect surface.
Its [Rex plugin](https://github.com/alienxp03/raptor/blob/master/init.lua) permits that panel only for a local macOS app client.
That approach does not display the panel on a remote Rex client.

The installed Rex preview exposes fixed native pickers, but no custom form or embedded HTML interface.
The selector borrows Raptor's clear sections, row details, and destination preview within the supported terminal surface.
It does not install Raptor, change terminals, or change client settings.
Use `rex actions`, `rex -C CLIENT actions`, and `rex block types --json` to check later versions.

## Rex resume

When the Rex server stops, for example after a crash, an update, or a reboot, it restores its
sessions and panes at the next start. Each pane gets a new login shell. Rex resume runs
`claude --resume <ID>` in each restored pane that ran Claude Code when the server stopped. The turn
that the stop cut off does not continue. Other programs, and processes that Claude started, such as
background shells, do not come back.

It has two parts, and needs no daemon:

1. **Record:** the SessionStart hook `claude/.claude/hooks/rex-resume.sh` writes
   `~/.local/state/rex-resume/<REX_BLOCK>`. The file holds the conversation ID, the directory, and
   the transcript path. The hook records nothing for a `claude -p` run or a subagent. Each start,
   `/clear`, `/compact`, and resume writes the file again.
2. **Resume:** `zsh/.zsh/rex-resume.zsh`, which `.zshrc` loads, does two things in a Rex pane:
   - At each prompt, it removes the pane's file. A prompt means that Claude no longer runs in the
     pane. A server stop ends the shell before its next prompt, so the file stays.
   - In a new login shell, it reads the pane's file and removes it. At the first prompt, it runs
     `claude --resume <ID>`, after a `cd` to the recorded directory if the shell is in another
     directory. Rex restores each pane under its old ID, so the file names the restored pane.

The shell does not resume a conversation that has no transcript, because Claude writes the
transcript at the first prompt only. Such a pane keeps its shell. The hook deletes files older than
30 days, which panes closed while Claude ran leave behind.

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
scripts/t3-settings.sh export
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
| openssl@4 | nanobrew core | null |
| pkgconf | nanobrew core | null |
| ripgrep | nanobrew core | null |
| starship | nanobrew core | `.config/starship` |
| stow | nanobrew core | `dotfiles/scripts/install.sh` |
| tree | nanobrew core | null |
| unzip | nanobrew core | null |
| vivid | nanobrew core | null |
| zmx | nanobrew (`neurosnap/tap` tap) | `.zshrc` |
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
| kvm-pilot | mise (pypi) | `.config/kvm-pilot/config.toml`; see [KVM](#kvm) |
| node | mise | `.config/mise/config.toml` |
| oxfmt, oxlint | mise (npm) | null |
| omp | mise (GitHub) | `.omp/agent/config.yml`; see [Agents](#agents) |
| pnpm | mise | `.config/mise/config.toml` |
| python | mise | `.config/mise/config.toml` |
| rust | mise | `.config/mise/config.toml` |
| shellcheck | mise | null |
| typescript | mise (npm) | null |
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
| tinycast | nanobrew | `dotfiles/tinycast` | yes |
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
| VIA | download | null | |
| VLC | download | null | |
