# Dotfiles Setup

## Install packages

Prerequisites: Make sure the machine has a terminal and bash installed then:

1. Install [MesloLGS NF](https://github.com/romkatv/powerlevel10k/blob/master/font.md)

```bash
# Leaving machine
cd ~/dotfilesi
# Raycast: "Export Settings and Data" to ~/dotfiles/raycast
leave-machine -c

# -------------------------------------

# Fresh machine
curl -fsSL https://raw.githubusercontent.com/ferntheplant/dotfiles/main/scripts/setup-new-machine | bash

# load Stylus config dump into browser
# load Raycast config dump into Raycast
# cmd+shift+p Install from VSIX for cursor custom extensions
```

TODO: find way to automate generating `.Brewfile` and `cursor-extensions.txt`

TODO: automate generating Stylus config dump

TODO: automate generating Raycast config dump

TODO: [Raycast plaintext config](https://gist.github.com/jeremy-code/50117d5b4f29e04fcbbb1f55e301b893)

TODO: somehow put other macOS level settings in here

## Colima vs Docker Desktop (vs Orbstack)

See this [thread](https://github.com/abiosoft/colima/discussions/273) for installing buildx

## Config TODOs

- Neat.run install and configs
- spicetify install and configs
- bctl install and configs
- Beeper configs
- meetingbar configs
- hiddenbar config
- stats config
- floorp config

Refactor all configs to not be nested in redundant `.config`
