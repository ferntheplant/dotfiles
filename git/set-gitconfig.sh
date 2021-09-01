#!/usr/bin/env zsh

git config --global user.name "Fern Sanchez"

git config --global core.editor vim
git config --global credential.helper store

git config --global alias.co checkout
git config --global alias.st status
git config --global alias.cm commit

if [[ -z $(git config --global --get user.email) ]]; then
  echo -e "!!!\n\nGit Email not set, please configure!\n\ngit config --global user.email 'test@email.com'\n\n!!!"
fi
