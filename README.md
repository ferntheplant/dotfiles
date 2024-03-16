# Dotfiles symlinking

## Install packages
```bash
# Leaving machine
sudo apt-mark showmanual > leaves.txt

# Fresh machine
xargs sudo apt-get install < leaves.txt
```

## Install dotfiles with stow

Clone this repo to `~/dotfiles` and run

```bash
stow --no-folding alacritty gh git nvim starship zellij zshrc
```

