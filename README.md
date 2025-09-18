# Dotfiles Setup

## Install packages

Prerequisites: Make sure the machine has a terminal and bash installed then:

1. Install [MesloLGS NF](https://github.com/romkatv/powerlevel10k/blob/master/font.md)

```bash
# Leaving machine
cd ~/dotfiles
# Floorp export settings: stylus, violentmonkey, vimium, dark reader, get-addons-list.js
# Stats export settings
# Stylus export settings
# Raycast: "Export Settings and Data" to ~/dotfiles/raycast
leave-machine -c

# -------------------------------------

# Fresh machine
curl -fsSL https://raw.githubusercontent.com/ferntheplant/dotfiles/main/scripts/setup-new-machine | bash

# set global macos settings (see below)
# load Stylus config dump into browser
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

TODO: find way to automate generating `.Brewfile` and `cursor-extensions.txt`

TODO: automate generating Stats config dump

TODO: automate generating Raycast config dump

TODO: [Raycast plaintext config](https://gist.github.com/jeremy-code/50117d5b4f29e04fcbbb1f55e301b893)

TODO: somehow put other macOS level settings in here

- key repeat timing
- finder settings (show hidden files, no tags, list view, etc)
- disable all notifications
- auto-hide dock, always show menu bar
- 24h clock + menu bar clock
- disable spotlight shortcut (for raycast)

TODO: automate all the Floorp settings (a lot of the settings are so fucked inside of user.js)

## Colima vs Docker Desktop (vs Orbstack)

See this [thread](https://github.com/abiosoft/colima/discussions/273) for installing buildx

## Config TODOs

- Neat.run install and config
- spicetify install and config
- bctl install and config
- Beeper config
- meetingbar configs
- hiddenbar config
- setup global prettier/biome with mise

Refactor all configs to not be nested in redundant `.config`
