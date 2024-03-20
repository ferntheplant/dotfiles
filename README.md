# Dotfiles symlinking

## Install packages
```bash
# Leaving machine
$ sudo apt-mark showmanual > leaves.txt

# -------------------------------------

# Fresh machine
$ sudo add-apt-repository ppa:maveonair/helix-editor
$ sudo apt update
$ xargs sudo apt-get install < leaves.txt

# install cargo
$ curl https://sh.rustup.rs -sSf | sh
# TODO: find way to do a 'leaves.txt' thing with cargo
$ cargo install exa sd zellij

# install bun
$ curl -fsSL https://bun.sh/install | bash

# install dprint
# TODO: find way to do a leaves.txt thing with bun
$ bun add --global dprint

# TODO: find way to automate custom bin installs
# setup location for custom installed libraries
$ mkdir ~/bin

# install zk
$ git clone https://github.com/zk-org/zk.git ~/bin/zk
$ cd ~/bin/zk
$ make
$ sudo ln -s /home/fjorn/bin/zk/zk /usr/local/bin/zk

# setup notebook
$ git clone https://github.com/ferntheplant/notebook.git

# install marksman
$ curl -o ~/bin/marksman https://github.com/artempyanykh/marksman/releases/download/2023-12-09/marksman-linux-x64
$ chmod +x ~/bin/marksman
$ sudo ln -s /home/fjorn/bin/marksman /usr/local/bin/marksman
```

## Install dotfiles with stow

Clone this repo to `~/dotfiles` and run

```bash
# TODO: find way to automatically install all the subdirectories with stow
stow --no-folding alacritty gh git helix starship zellij zk zshrc
```

