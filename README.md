# Dotfiles Setup

## Install packages

Prerequisites: Make sure the machine has a terminal and bash installed then:

1. Install [MesloLGS NF](https://github.com/romkatv/powerlevel10k/blob/master/font.md)

```bash
# Leaving machine
cd ~/dotfiles
leave-machine -c

# -------------------------------------

# Fresh machine
curl -fsSL https://raw.githubusercontent.com/ferntheplant/dotfiles/main/scripts/setup-new-machine | bash

# load Stylus config dump into browser
# load Raycast config dump into Raycast
```

TODO: find way to automate generating `.Brewfile`

TODO: automate generating Stylus config dump

TODO: automate generating Raycast config dump

## Colima vs Docker Desktop (vs Orbstack)

See this [thread](https://github.com/abiosoft/colima/discussions/273) for installing buildx

## Config TODOs

- Neat.run install and configs
- spicetify install and configs
- bctl install and configs
- Beeper install
- meetingbar configs
- hiddenbar config
- stats config
- floorp config

Refactor all configs to not be nested in redundant `.config`
