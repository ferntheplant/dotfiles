# Dotfiles Setup

## Install packages

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

# make zsh default shell
$ chsh -s $(which zsh)

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

# setup notebook
$ git clone https://github.com/ferntheplant/notebook.git ~/notebook
```

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

- probably keep everything managed by cargo and Mise in those tools
- only use Homebrew on custom bin installs
