# Dotfiles Setup

## Install packages

Prerequisites:

1. Install [Alacritty](https://github.com/alacritty/alacritty)
2. Install [MesloLGS NF](https://github.com/romkatv/powerlevel10k/blob/master/font.md)

```bash
# Leaving machine
$ cd ~/dotfiles

# Linux
$ leave-apt

# macOS
$ leave-brew

$ leave-cargo
$ leave-bun
$ leave-pip

$ g add *
$ g commit -m "Leaving machine"
$ g push origin main

# -------------------------------------

# Fresh machine
# Clear out existing configs
$ rm ~/.zshrc ~/.zshenv ~/.gitconfig
$ rm -rf ~/.config

# Linux
$ sudo apt update
$ sudo add-apt-repository ppa:maveonair/helix-editor
$ xargs sudo apt-get install < apt-packages.txt

# macOS
$ brew update
$ xargs brew install < brew-packages.txt

# login with github to access dotfiles and notebook repos
$ gh auth login

# install dotfiles (must come after installing stow with apt)
$ git clone https://github.com/ferntheplant/dotfiles.git ~/dotfiles
$ cd ~/dotfiles
$ ./scripts/install

# install mise
$ curl https://mise.run | sh
$ ~/.local/bin/mise install

# install cargo (mise reccomends not using mise to manage rust)
$ unset RUSTC_WRAPPER
$ curl https://sh.rustup.rs -sSf | sh
$ xargs cargo install < cargo-packages.txt
$ cargo-install-custom < cargo-custom.txt

# add sccache to rust
$ cargo install sccache

# install bun packages
$ xargs bun add --global < bun-packages.txt

# install pip packages
$ xargs pip install < pip-packages.txt

# TODO: find way to automate custom bin installs
# setup location for custom installed libraries
$ mkdir ~/bin

# install zsh auto-suggestions and theme
$ git clone https://github.com/zsh-users/zsh-autosuggestions ~/.zsh/zsh-autosuggestions
$ git clone https://github.com/catppuccin/zsh-syntax-highlighting.git ~/zsh-catppuccin-highlighting-theme
$ cd ~/zsh-catppuccin-highlighting-theme
$ cp -v themes/catppuccin_macchiato-zsh-syntax-highlighting.zsh ~/.zsh/

# install ltex-ls
$ curl -L -o "~/bin/ltex-ls.tar.gz" https://github.com/valentjn/ltex-ls/releases/download/16.0.0/ltex-ls-16.0.0-linux-x64.tar.gz
$ cd ~/bin
$ tar -xvzf ltex-ls.tar.gz
$ rm ltex-ls.tar.gz
$ sudo ln -s ~/bin/ltex-ls-16.0.0/bin/ltex-ls ~/.local/bin/ltex-ls

# macOS only
$ sudo mkdir /Library/Java/JavaVirtualMachines/17.0.2.jdk
$ sudo ln -s /Users/fjorn/.local/share/mise/installs/java/17.0.2/Contents /Library/Java/JavaVirtualMachines/17.0.2.jdk/Contents

# install zk
$ git clone https://github.com/zk-org/zk.git ~/bin/zk
$ cd ~/bin/zk
$ make
$ sudo ln -s ~/bin/zk/zk ~/.local/bin/zk

# make zsh default shell
$ chsh -s $(which zsh)
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

Most things from `apt`, `mise`, `cargo`, and the manual install list can be acquired via Homebrew on macOS. However, for maximal interoperability we instead manually ported over the list of `apt` packages to `brew` packages.

TODO: look into using nixOS/nix packages

## Config TODOs

- Setup [pretty ts errors](https://github.com/yoavbls/pretty-ts-errors)
  - Here is a [fork](https://github.com/hexh250786313/pretty-ts-errors-markdown) that exposes a standalone LSP
  - Here is a [sample plugin](https://github.com/hexh250786313/coc-pretty-ts-errors) for nvim using said LSP
- Setup [quick lint JS](https://quick-lint-js.com/)
- Setup [automatic class sorting](https://tailwindcss.com/blog/automatic-class-sorting-with-prettier) for tailwind with prettier
  - Pass the prettier config to dprint somehow
