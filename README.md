# Dotfiles Setup

## Install packages

```bash
# Leaving machine
$ sudo apt-mark showmanual > apt-packages.txt
$ cargo install --list | awk 'NF==1 {printf "%s ", $1}' > cargo-packages.txt

# -------------------------------------

# Fresh machine
$ sudo add-apt-repository ppa:maveonair/helix-editor
$ sudo apt update
$ xargs sudo apt-get install < apt-packages.txt

# login with github to access dotfiles and notebook repos
$ gh auth login

# install dotfiles (must come after installing stow)
$ git clone https://github.com/ferntheplant/dotfiles.git ~/dotfiles
$ cd ~/dotfiles
$ ./install

# make zsh default shell
$ chsh -s $(which zsh)

# install mise
$ curl https://mise.run | sh
$ ~/.local/bin/mise activate
$ mise install

# install cargo
$ curl https://sh.rustup.rs -sSf | sh
$ xargs cargo install < cargo-packages.txt

# TODO: find way to automate custom bin installs
# setup location for custom installed libraries
$ mkdir ~/bin

# install zk
$ git clone https://github.com/zk-org/zk.git ~/bin/zk
$ cd ~/bin/zk
$ make
$ sudo ln -s /home/fjorn/bin/zk/zk /usr/local/bin/zk

# install marksman
$ curl -o ~/bin/marksman https://github.com/artempyanykh/marksman/releases/download/2023-12-09/marksman-linux-x64
$ chmod +x ~/bin/marksman
$ sudo ln -s /home/fjorn/bin/marksman /usr/local/bin/marksman

# setup notebook
$ git clone https://github.com/ferntheplant/notebook.git ~/notebook
```

## Windows shennanigans

After setting up WSL and installing alacritty need ot symlink the alacritty config to the windows filesystem. Run the following in an administrator power shell instance

```powershell
> New-Item -ItemType SymbolicLink -Path C:\Users\fjorn\AppData\Roaming\alacritty\alacritty.toml -Target "\\wsl.localhost\Ubuntu\home\fjorn\dotfiles\alacritty\.config\alacritty\alacritty.toml"
```

Note that the symlink target points to the dotfiles repo and not `~/.config`. Thisi s because windows symlinks CANNOT follow linux symlinks so we need ot point to the original file.

## MacOS and Homebrew

Most things from `apt`, `mise`, `cargo`, and the manual install list can be acquired via homebrew on MacOS.

TODO: finalize list of homebrew packages to install
Notes on this:

- probably keep everything managed by cargo and mise in those tools
- only use homebrew on custom bin installs
