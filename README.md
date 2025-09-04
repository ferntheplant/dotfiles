# Dotfiles Setup

## Install packages

Prerequisites: Make sure the machine has a terminal and bash installed then:

1. Install [MesloLGS NF](https://github.com/romkatv/powerlevel10k/blob/master/font.md)
2. Install [Docker](https://docs.docker.com/desktop/install/mac-install/)

```bash
# Leaving machine
$ cd ~/dotfiles
$ leave-machine

# -------------------------------------

# Fresh machine
$ curl -fsSL https://raw.githubusercontent.com/ferntheplant/dotfiles/main/scripts/setup-new-machine | bash
```

TODO: find way to automate generating `leaves.txt` files on reasonable schedule to always keep them up to date.

## Windows shenanigans

After setting up WSL and installing Alacritty you need to symlink the Alacritty config to the Windows file system. Run the following in an administrator PowerShell instance

```powershell
> New-Item -ItemType SymbolicLink -Path C:\Users\fjorn\AppData\Roaming\alacritty\alacritty.toml -Target "\\wsl.localhost\Ubuntu\home\fjorn\dotfiles\alacritty\.config\alacritty\alacritty.toml"
```

Furthermore, you'll likely need to modify the default shell for Alacritty to be the Ubuntu shell for WSL. Set the top level `shell=ubuntu` key in `alacritty.toml`.

Note that the symlink target points to the dotfiles repo and not `~/.config`. This is because windows symlinks CANNOT follow Linux symlinks, so we need to point to the original file.

## macOS and Homebrew

Most things from `apt`, `mise`, `cargo`, and the manual install list can be acquired via Homebrew on macOS. ~~However, for maximal interoperability we instead manually ported over the list of `apt` packages to `brew` packages.~~

TODO: look into using nixOS/nix packages

## Colima vs Docker Desktop

See this [thread](https://github.com/abiosoft/colima/discussions/273) for installing buildx

## Config TODOs

- Setup [pretty ts errors](https://github.com/yoavbls/pretty-ts-errors)
  - Here is a [fork](https://github.com/hexh250786313/pretty-ts-errors-markdown) that exposes a standalone LSP
  - Here is a [sample plugin](https://github.com/hexh250786313/coc-pretty-ts-errors) for nvim using said LSP
- Setup [quick lint JS](https://quick-lint-js.com/)
- Setup [automatic class sorting](https://tailwindcss.com/blog/automatic-class-sorting-with-prettier) for tailwind with prettier
  - Pass the prettier config to dprint somehow

---------

- Neat.run
- Beeper install
- meetingbar
