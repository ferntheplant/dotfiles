# Dotfiles symlinking

## Install packages
```bash
# Leaving machine
$ sudo apt-mark showmanual > apt-packages.txt
$ cargo install --list | awk 'NF==1 {printf "%s ", $1}' > cargo-packages.txt
$ cat ~/.bun/install/global/package.json | jq -r '.dependencies | keys[]' | tr -s '\n' ' ' > bun-packages.txt 

# -------------------------------------

# Fresh machine
$ sudo add-apt-repository ppa:maveonair/helix-editor
$ sudo apt update
$ xargs sudo apt-get install < apt-packages.txt

# make zsh default shell
$ chsh -s $(which zsh)

# install cargo
$ curl https://sh.rustup.rs -sSf | sh
$ xargs cargo install < cargo-packages.txt

# install go
$ wget https://go.dev/dl/go1.22.1.linux-amd64.tar.gz
$ sudo tar -xvf go1.22.1.linux-amd64.tar.gz
$ sudo mv go /usr/local
$ rm go1.22.1.linux-amd64.tar.gz

# install bun
$ curl -fsSL https://bun.sh/install | bash
$ xargs bun add --global < bun-packages.txt

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

# install lazygit
$ git clone https://github.com/jesseduffield/lazygit.git ~/bin/lazygit
$ cd ~/bin/lazygit
$ go install

# setup notebook
$ git clone https://github.com/ferntheplant/notebook.git ~/notebook
```

## Install dotfiles with stow

Clone this repo to `~/dotfiles` and run

```bash
# TODO: find way to automatically install all the subdirectories with stow
stow --no-folding alacritty gh git helix starship zellij zk zshrc
```

## Windows shennanigans

After setting up WSL and installing alacritty need ot symlink the alacritty config to the windows filesystem. Run the following in an administrator power shell instance
```powershell
> New-Item -ItemType SymbolicLink -Path C:\Users\fjorn\AppData\Roaming\alacritty\alacritty.toml -Target "\\wsl.localhost\Ubuntu\home\fjorn\dotfiles\alacritty\.config\alacritty\alacritty.toml" 
```

Note that the symlink target points to the dotfiles repo and not `~/.config`. Thisi s because windows symlinks CANNOT follow linux symlinks so we need ot point to the original file.

