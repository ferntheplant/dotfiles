# Dotfiles Setup

## Profiles

The gitignored `.work/profile` file selects what a machine gets. A machine without the file is
`desktop`.

| Profile | Packages | Stow packages |
| --- | --- | --- |
| `desktop` | `.Nanobrewfile`, `.Nanobrewfile.desktop`, and Kiri | all of them |
| `server` (a Mac server) | `.Nanobrewfile` only | all except kanata, librewolf, paneru, and zed |
| `infra` (a Linux server) | `.Nanobrewfile` without the casks and the macOS-only formulas | as `server`, and also not ghostty, claude, fx, kvm-pilot, or opencode |
| `work` (the Pillar laptop) | as `desktop` | all of them |

`infra` is for a Linux server that runs services.
It gets no agent config: no Claude Code, opencode, or fx settings, no skills, and no MCP servers.
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

Install Nanobrew and mise first. Run `scripts/install.sh` to install Nanobrew packages, link the
dotfiles, install mise tools, and apply settings. You can run it again after a pull.

Use `scripts/install.sh --config-only` to apply the dotfiles and settings without a package install.
Use `scripts/install-packages.sh` to install packages without the dotfiles and settings.
Neither script installs Mac App Store apps. See [Set up a new desktop Mac](#set-up-a-new-desktop-mac)
for that step.

`leave-brew` puts a new formula in `.Nanobrewfile` and a new cask in `.Nanobrewfile.desktop`.
It skips `fresh-editor`. The repo keeps the Fresh config but does not install the editor.
Move a line by hand if it belongs in the other file. `leave-brew` does not run on the server or
infra profile. Add a formula with no Linux build to `MACOS_ONLY` in `scripts/install-packages.sh`.

A Mac can also have Homebrew in `/opt/homebrew`, which links to nanobrew's prefix, so the two
tools share one Cellar. Nanobrew's kegs have no Homebrew install receipt, so Homebrew's autoremove
takes them for unused dependencies: one `brew uninstall` removed most of them. The `homebrew`
package links `~/.homebrew/brew.env`, which sets `HOMEBREW_NO_AUTOREMOVE=1` for every `brew` call,
from any shell.

### Mac server

The server keeps its own apps and services (Tailscale and others) in a separate
private repo. Rex is not in Nanobrew: install it from `Rex.dmg`. After `scripts/install.sh`,
run `agent-browser install` once so that agents have a browser.

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
- `mddog` and `zmx`: mise
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

2. Install mise. Clone the repo. Run the installer.

   ```bash
   curl https://mise.run | sh
   git clone https://github.com/ferntheplant/dotfiles ~/dotfiles
   mkdir -p ~/dotfiles/.work && echo infra > ~/dotfiles/.work/profile
   cd ~/dotfiles
   scripts/install.sh
   ```

To sync after a push, use the same command as the Mac server. The mise config has no profiles.
It installs agent-browser on the Linux server, but the installer does not configure it there.

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

3. Install [mise](https://mise.jdx.dev/installing-mise.html) with its installer.

   ```bash
   curl https://mise.run | sh
   ```

4. Install [Nanobrew](https://github.com/justrach/nanobrew).

   ```bash
   curl -fsSL https://nanobrew.trilok.ai/install | bash
   ```

5. Install the apps and fonts that no package file installs:
   - [MesloLGS NF](https://github.com/romkatv/powerlevel10k/blob/master/font.md) (Ghostty and Rex use it)
   - Rex from `Rex.dmg`
   - the other `download` apps in the [Apps](#apps) table
6. Run the installer. Import the Rex settings. Sign in to the App Store before the `mas` command.

   ```bash
   cd ~/dotfiles
   scripts/install.sh
   scripts/rex-settings.sh import
   sed -n 's/^mas .*id: //p' .Nanobrewfile.desktop | xargs /opt/nanobrew/prefix/bin/mas install
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

Claude Code, opencode, and fx have shared settings in this repo.

- **Instructions:** two files in `.agents/instructions/`. `constitution.md` is the
  [Clanker Constitution](https://github.com/kenn-io/constitution), and `writing.md` is the
  [ASD-STE100 writing rules](https://gist.github.com/toppa/bf7ff49d6fc44fd4fc3337248f8f2a7e). Both
  are copies with local edits, recorded in `.agents/vendored-files.jsonc`. Another repo maintains
  them, merges upstream's changes, and publishes them here, so an edit here is lost at the next
  publish. `claude/.claude/CLAUDE.md` imports both through `~/.claude/agent-instructions`, a link
  that `scripts/link-agents.sh` makes. opencode loads the same folder (see
  [Shared instruction and skill discovery](#shared-instruction-and-skill-discovery)).
- **Skills:** `.agents/skills/`. `scripts/link-agents.sh` links each skill into `~/.claude/skills/`
  for Claude Code and opencode. The skills are copies, published here the same way as the
  instructions and recorded in `.agents/vendored-skills.jsonc`. Claude Code also syncs the claude.ai
  account skills (xlsx, pptx, and others) into `~/.claude/skills/synced/`. Neither agent shows
  them to the model (see [opencode plugins](#opencode-plugins)).
- **Local sources:** the gitignored `.work/agent-sources` file changes the material on one machine.
  It adds skill folders before `.agents/skills/`, and it can replace the instructions folder. Use
  it to try a change before it is published here, or to add the skills that another checkout owns.
  The comment at the top of `scripts/link-agents.sh` gives the format. To go back to the published
  copies, remove the file and run the script again.
- **Settings:** each agent writes its own keys to its settings file, so the file is not a link.
  `scripts/claude-settings.sh`, `scripts/opencode-settings.sh`, and `scripts/fx-settings.sh` merge
  the base files into it.
- **MCP servers:** `scripts/claude-mcp.sh` registers them with `claude mcp` at user scope, because
  Claude Code owns `~/.claude.json`. The only registered server is kvm-pilot (see [KVM](#kvm)).

### opencode and fx settings

The base files capture the shared harness preferences:

| Base file | Live file | What it holds |
| --- | --- | --- |
| `opencode/.config/opencode/opencode.base.json` | `~/.config/opencode/opencode.json` | The opencode server: the shared instructions |
| `opencode/.config/opencode/cli.base.json` | `~/.config/opencode/cli.json` | The opencode terminal client: theme, tabs, diffs, auto-accept |
| `fx/.fx/settings.base.json` | `~/.fx/settings.json` | fx: Codex `gpt-6.1-terra` with high effort |

opencode keeps its selected model in its own state, not in a settings file.
The installer applies these settings on desktop, server, and work profiles, but not infra.

Edit the base files. Run `scripts/install.sh --config-only`, or apply only these settings:

```bash
scripts/opencode-settings.sh
scripts/fx-settings.sh
```

Both scripts merge nested objects with the base keys winning, retain unlisted machine-local
keys, and back up changed files. Repeating the merge without changes does not rewrite the file.
The live files remain writable regular files. Settings changed in the harness are not
automatically captured in the base files. Credentials, sessions, history, databases, and caches
stay outside the repo. Sign in on each machine with `opencode auth` and `fx login codex`. These
scripts configure installed harnesses; they do not install the binaries.

opencode v2 runs a background service (`opencode service`) that every terminal client shares.
After a change to the settings or a plugin, run `opencode reload`.
A new plugin folder needs `opencode service restart`, which ends the sessions that run.

#### opencode plugins

`opencode/.config/opencode/plugins/` holds the plugins. opencode loads each folder in
`~/.config/opencode/plugins/`, but it skips a server plugin file that is a link. Thus stow skips the
plugins (`opencode/.stow-local-ignore`), and `scripts/opencode-settings.sh` links each plugin
folder. `scripts/install.sh` removes a link whose folder is gone.

The `agent-context` plugin has two parts:

- `server.ts` runs in the shared server. It gives the agent its identity
  (see [Agent identity](#agent-identity)). It also holds the first prompt of each new root session
  for at most 250 ms, until the entries from `tui.ts` exist. It also removes the synced claude.ai
  skills: Claude Code reads only the folders directly in `~/.claude/skills`, but opencode searches
  six folders deep and finds `synced/<account>/<skill>`. A policy cannot remove them, because it
  matches skill IDs, and the account skills change.
- `tui.ts` runs in each terminal client, so it knows the pane. It adds the Rex context (see
  [Rex support in opencode](#rex-support-in-opencode)) and records the session for
  [Rex resume](#rex-resume). It also adds the text of the file in `$AGENT_INSTRUCTIONS_FILE`,
  because opencode has no option for extra system text. A launcher sets that variable.

Each part of the context from `tui.ts` is an instruction entry on the session. An entry that
changes reaches the model at its next step. A subagent's session gets no entries from `tui.ts`.

The `status-footer` plugin replaces the omp status line and stop time. It adds two things:

- **The footer row**, after opencode's own `cwd:branch`: the context that remains, and the five-hour
  and weekly quota that remains for the provider of the selected model, with the time to each
  reset. Example: `· 62% ctx left · 5h 71% (2h10m)  7d 38% (3d4h)`. opencode already shows the
  model, the thinking level, and the branch.
- **The row above the input**: `stopped at HH:MM`, the time that the last turn ended, with the date
  when it is not today. Use it to tell whether the provider prompt cache has likely expired.
  opencode has no place under each reply, so earlier turns show no time.

`?` means unknown, `~` marks a value older than 10 minutes, and a passed reset shows `? (now)`. The
quota takes the theme's warning color at 20% or less, and its info color at 50% or less. The quota sources:

| Provider | Source | Credentials |
| --- | --- | --- |
| `openai` (a ChatGPT sign-in) | The Codex rate-limit WebSocket frames and `x-codex-*` headers on each model response | None |
| `claude-agent` | The Claude Agent SDK rate-limit event that opencode keeps on each step (`native.rateLimit.unifiedWindows`) | None |
| `opencode-go` | opencode's usage-limits call, once a minute while a Go model is selected | opencode's own. It needs an OpenCode Console sign-in (`/connect`) in the workspace of the Go subscription. A Go API key alone gives `?`. |

The server part (`server.ts`) keeps the newest value of each window in the plugin storage, so the
values survive a server restart. The TUI part (`tui.ts`) reads them through the RPC in `rpc.ts`.
openai and claude-agent quota update only on model responses. After a long pause, the values show
`~` until the next reply.

### Shared instruction and skill discovery

`opencode.base.json` sets `instructions` to `~/.claude/agent-instructions/*.md`, the folder that
`scripts/link-agents.sh` links. opencode also reads `~/.claude/CLAUDE.md` when there is no
`~/.config/opencode/AGENTS.md`, but it does not follow the `@` imports in that file. Without
the `instructions` setting, opencode gets only the two import lines.

opencode reads skills from `~/.claude/skills` and `~/.agents/skills`, so the links that
`scripts/link-agents.sh` makes need no second copy. Project-root `AGENTS.md` and `CLAUDE.md` work
too. In each folder, `AGENTS.md` wins when both names exist.

### Rex support in opencode

`rex skill setup` installs the Rex skill for opencode in `~/.agents/skills/rex`. Rex has no startup
hook for opencode, because opencode has no command hooks. `rex skill status` reports the hook as
`unsupported`.

The `agent-context` plugin does the work of that hook. In a Rex pane, `tui.ts` runs
`rex __internal session-start --agent opencode` and adds its text to each root session that the
pane shows. The text holds the pane's own `REX_SESSION` and `REX_BLOCK`, and the rule to name the
Rex session. Subagents do not get it, so they do not rename the parent's Rex session.

The background server's environment holds the IDs of the pane that started the service. Thus the
server part never reads Rex IDs from its environment. Each client sends its own environment to
the shell tool, so `$REX_SESSION` and `$REX_BLOCK` in the agent's commands belong to its pane.

opencode v2 reports its state to Rex itself with
[OSC 7501 program status](https://www.superlogical.com/rex/docs/build/program-status.md)
(`app=opencode`). Rex's activity indicators need no adapter.

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

To set up a machine, add the password. Run `install.sh --config-only` to register the server:

```bash
security add-generic-password -s kvm-pilot -a comet -w   # prompts for the Comet admin password
scripts/install.sh --config-only
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

Each agent uses one identity, `<model>+<harness>@<host>`, for example
`opus-5-5+claude@personal-macbook` or `gpt-6.1-sol+opencode@personal-macbook`.
The model is the model ID in lowercase, without a provider prefix, a `claude-` prefix, or a `[1m]` suffix.
The host is the Tailscale machine name, such as `personal-macbook`, from `scripts/tailnet-name.sh`.
The `+` separator is valid in an email address, and no model ID uses it.

You are the commit author.
The agent ends each commit message with `Co-Authored-By: <identity> <<identity>>`.
Claude Code's own trailer is off (`attribution.commit` is empty in `settings.base.json`).
The `work` profile keeps each harness's own commit trailer without this identity or its hook.

The SessionStart hook `claude/.claude/hooks/agent-identity.sh` reads the session model.
It writes `AGENT_IDENTITY` to `$CLAUDE_ENV_FILE`, so every Bash command gets it, also in subagents.
It also gives Claude the trailer rule as session context.
A `/model` switch keeps the identity of the session start.
`claude -p` has no session model, so the hook takes the `--model` value (an alias such as `haiku`).
Without a model, the hook keeps the fallback in `AGENT_IDENTITY` from `scripts/claude-settings.sh`.
The fallback is `<model setting>+claude@<host>`.

In opencode, the `server.ts` part of the `agent-context` plugin adds the identity and the trailer
rule to each model request. It takes the model from the request, so a model switch changes the
identity at once. opencode does not set `AGENT_IDENTITY` in the shell.

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
The form retains the origin session and directory. It removes its float before it selects the destination on the origin client.
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
`claude --resume <ID>` or `opencode --session <ID>` in each restored pane that ran Claude Code or
opencode when the server stopped. The turn that the stop cut off does not continue. Other programs,
and processes that the agent started, such as background shells, do not come back.

It has two parts, and needs no daemon:

1. **Record:** the agent writes `~/.local/state/rex-resume/<REX_BLOCK>`. The file holds the
   conversation ID, the directory, the transcript path, and the agent, separated by tabs. A file
   without an agent is from Claude Code.
   - Claude Code: the SessionStart hook `claude/.claude/hooks/rex-resume.sh`. The hook records
     nothing for a `claude -p` run or a subagent. Each start, `/clear`, `/compact`, and resume
     writes the file again.
   - opencode: `tui.ts` in the `agent-context` plugin. It records the root session that the pane
     shows, each time the pane shows another session. It leaves the transcript field empty.
     `opencode run` does not record.
2. **Resume:** `zsh/.zsh/rex-resume.zsh`, which `.zshrc` loads, does two things in a Rex pane:
   - At each prompt, it removes the pane's file. A prompt means that the agent no longer runs in
     the pane. A server stop ends the shell before its next prompt, so the file stays.
   - In a new login shell, it reads the pane's file and removes it. At the first prompt, it runs
     the agent's resume command, after a `cd` to the recorded directory if the shell is in another
     directory. Rex restores each pane under its old ID, so the file names the restored pane.

The shell does not resume a Claude conversation that has no transcript, because Claude writes the
transcript at the first prompt only. Such a pane keeps its shell. The Claude hook deletes files
older than 30 days, which panes closed while an agent ran leave behind.

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

## Kiri

[Kiri](https://github.com/libracoder/kiri) runs local development containers.
The desktop and work profiles use the Kiri installer. Nanobrew cannot expand the architecture
in the Kiri cask URL. On a Mac server that needs Kiri, run the installer:

```bash
curl -fsSL https://runkiri.com/install.sh | KIRI_SKIP_SETUP=1 /bin/bash
```

Run this once to start Kiri at login and select the `kiri` Docker context:

```bash
kiri_app=/Applications/Kiri.app
[[ -d "$kiri_app" ]] || kiri_app="$HOME/Applications/Kiri.app"
ZDOTDIR="$HOME/dotfiles/.work" "$kiri_app/Contents/MacOS/kiri" setup --use --no-domains
```

`ZDOTDIR` keeps Kiri's shell setup out of the linked `.zshrc`. The dotfiles add Kiri to `PATH`.
Open a new shell. Run `docker context show` to confirm the default context.

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
| mddog (`mdd`) | nanobrew (`qu8n/tap` tap) on macOS, mise on Linux | `.config/mddog`, Rosé Pine Moon |
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
| opencode-v2 (`anomalyco/tap`) | nanobrew core, macOS only | `.config/opencode`; see [Agents](#agents) |
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
| pnpm | mise | `.config/mise/config.toml` |
| px0 | mise (github) | `.px0/settings.base.json`, merged by `scripts/px0-settings.sh` |
| python | mise | `.config/mise/config.toml` |
| rust | mise | `.config/mise/config.toml` |
| shellcheck | mise | null |
| typescript | mise (npm) | null |
| typescript-language-server | mise (npm) | null |
| uv | mise | `.config/mise/config.toml` |
| yq | mise | null |
| zig | mise | `.config/mise/config.toml` |
| mise | manual | `.config/mise/config.toml` |

px0 reads and reviews code and agent diffs in a browser. `px0 .` serves the current directory at
`http://127.0.0.1:7777`, and `px0` with no target opens the workbench. Its settings file is
`~/.px0/settings.json`. On each install, `scripts/px0-settings.sh` merges the shared settings from
this repo into that file. px0 also writes to the file when its Settings panel saves a change, and
that change can be a forge token. A token therefore stays in `~/.px0/settings.json` and out of
this repo. px0 replaces its own binary when it finds a newer release; `mise upgrade` installs
that release into mise's own version directory.

`typescript-language-server`, which px0 and Helix start, needs the `tsserver` module that
TypeScript 7 does not ship. Its mise entry adds TypeScript 6 to the server's own `node_modules`.
A project that uses TypeScript 7 keeps its TypeScript and its `tsc --lsp`.

### Apps

This list shows the apps on the desktop Mac. The source column tells you how to install each app:

- `nanobrew`: a cask in `.Nanobrewfile.desktop`
- `mas`: a Mac App Store entry in `.Nanobrewfile.desktop`
- `Kiri installer`: `scripts/install-packages.sh` runs the installer from Kiri
- `download`: a manual download from the vendor; no package file installs it

| App | Source | Config | macOS only |
| --- | --- | --- | --- |
| 1password | nanobrew | null | |
| agentsview | nanobrew | null | |
| beeper | nanobrew | null | |
| ghostty | nanobrew | `.config/ghostty` | |
| handy | nanobrew | `dotfiles/handy/settings.json` via `scripts/handy-settings.sh` | |
| hiddenbar | nanobrew | `scripts/macos-defaults.sh` | yes |
| Kiri | Kiri installer | See [Kiri](#kiri) | yes |
| librewolf | nanobrew | `.librewolf/librewolf.overrides.cfg`, `dotfiles/librewolf` | |
| sill | nanobrew (`saffsanity/sill` tap) | `scripts/macos-defaults.sh` | yes |
| spotify | nanobrew | null | |
| syncthing-app | nanobrew | null | |
| tinycast | nanobrew | `dotfiles/tinycast` | yes |
| vorssaint | nanobrew | `dotfiles/vorssaint/settings.plist` | yes |
| Zed | nanobrew | `.config/zed` | |
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
