#!/bin/bash

# WRITTEN BY CHATGPT
# Set the directory containing dotfiles
dotfiles_dir="$HOME/dotfiles"

# Navigate to the dotfiles directory
cd "$dotfiles_dir" || exit

# Iterate over subdirectories in dotfiles directory
for subdir in */; do
	# Remove trailing slash from the directory name
	subdir="${subdir%/}"
	# Run stow on the subdirectory
	stow "$subdir"
done
