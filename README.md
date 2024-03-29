# Dotfiles Setup

## Install packages

Prerequisites:

1. Install [Alacritty](https://github.com/alacritty/alacritty)
2. Install [MesloLGS NF](https://github.com/romkatv/powerlevel10k/blob/master/font.md)

```bash
# Leaving machine
$ apt-mark showmanual > apt-packages.txt
$ cargo install --list | awk 'NF==1 {printf "%s ", $1}' > cargo-packages.txt
$ cat ~/.bun/install/global/package.json | jq -r '.dependencies | keys[]' | tr -s '\n' ' ' > bun-packages.txt
$ pip list | awk 'NR>2 && NF' | grep -v "\[notice\]" | awk '{print $1}' | paste -sd " " > pip-packages.txt

# -------------------------------------

# Fresh machine
$ sudo add-apt-repository ppa:maveonair/helix-editor
$ sudo apt update
$ xargs sudo apt-get install < apt-packages.txt

# login with github to access dotfiles and notebook repos
$ gh auth login

# install dotfiles (must come after installing stow with apt)
$ git clone https://github.com/ferntheplant/dotfiles.git ~/dotfiles
$ cd ~/dotfiles
$ ./scripts/install

# install mise
$ curl https://mise.run | sh
$ ~/.local/bin/mise activate
$ mise install

# install cargo (mise reccomends not using mise to manage rust)
$ curl https://sh.rustup.rs -sSf | sh
$ xargs cargo install < cargo-packages.txt

# install bun packages
$ xargs bun add --global < bun-packages.txt

# install pip packages
$ xargs pip install < pip-packages.txt

# TODO: find way to automate custom bin installs
# setup location for custom installed libraries
$ mkdir ~/bin

# install ltex-ls
$ curl -L -o "/home/fjorn/bin/ltex-ls.tar.gz" https://github.com/valentjn/ltex-ls/releases/download/16.0.0/ltex-ls-16.0.0-linux-x64.tar.gz
$ cd ~/bin
$ tar -xvzf ltex-ls.tar.gz
$ rm ltex-ls.tar.gz
$ sudo ln -s /home/fjorn/bin/ltex-ls-16.0.0/bin/ltex-ls ~/.local/bin/ltex-ls

# install zk
$ git clone https://github.com/zk-org/zk.git ~/bin/zk
$ cd ~/bin/zk
$ make
$ sudo ln -s /home/fjorn/bin/zk/zk ~/.local/bin/zk

# make zsh default shell
$ chsh -s $(which zsh)
```

TODO: find way to automate generating `leaves.txt` files on reasonable schedule to always keep them up to date.

## Windows shenanigans

After setting up WSL and installing Alacritty you need to symlink the Alacritty config to the Windows file system. Run the following in an administrator PowerShell instance

```powershell
> New-Item -ItemType SymbolicLink -Path C:\Users\fjorn\AppData\Roaming\alacritty\alacritty.toml -Target "\\wsl.localhost\Ubuntu\home\fjorn\dotfiles\alacritty\.config\alacritty\alacritty.toml"
```

Note that the symlink target points to the dotfiles repo and not `~/.config`. This is because windows symlinks CANNOT follow Linux symlinks, so we need to point to the original file.

## macOS and Homebrew

Most things from `apt`, `mise`, `cargo`, and the manual install list can be acquired via Homebrew on macOS.

TODO: finalize list of Homebrew packages to install
Notes on this:

- probably keep everything managed by external package managers in those tools since we have the `leaves.txt` pattern
- only use Homebrew on custom bin installs and to replace `apt` on macOS

## Config TODOs

- Setup [pretty ts errors](https://github.com/yoavbls/pretty-ts-errors)
  - Here is a [fork](https://github.com/hexh250786313/pretty-ts-errors-markdown) that exposes a standalone LSP
  - Here is a [sample plugin](https://github.com/hexh250786313/coc-pretty-ts-errors) for nvim using said LSP
- Setup [quick lint js](https://quick-lint-js.com/)
- Setup [automatic class sorting](https://tailwindcss.com/blog/automatic-class-sorting-with-prettier) for tailwind with prettier
  - Pass the prettier config to dprint somehow
