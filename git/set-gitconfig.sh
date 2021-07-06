#!/usr/bin/env zsh

echo $(git config --global --get user.name)

git config --global user.name "Fern Sanchez"

git config --global core.editor vim
git config --global credential.helper store

git config --global alias.co checkout
git config --global alias.st status

echo 'memes'

if [[ -z $(git config --global --get user.email) ]]; then
  echo -e "!!!\n\nGit Email not set, please configure!\n\ngit config --global user.email 'test@email.com'\n\n!!!"
fi
