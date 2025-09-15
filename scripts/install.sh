#!/bin/bash

# WRITTEN BY CHATGPT
# Define the fixed location
fixed_location="$HOME/dotfiles"
# List of directories to ignore
IGNORE_LIST=("raycast" "stylus" "custom-cursor-extensions")

# Loop through all subdirectories
for subdir in "$fixed_location"/*; do
	if [ -d "$subdir" ]; then
		subdir_name=$(basename "$subdir")
		if [ "$subdir_name" = "scripts" ]; then
			stow -t "$HOME/.local/bin" --ignore="install" scripts
		elif [[ " ${IGNORE_LIST[@]} " =~ " ${subdir_name} " ]]; then
			continue
		else
			stow --no-folding "$subdir_name"
		fi
	fi
done
