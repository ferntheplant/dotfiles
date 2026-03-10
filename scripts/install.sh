#!/bin/bash

# WRITTEN BY CHATGPT
# Define the fixed location
fixed_location="$HOME/dotfiles"
# List of directories to ignore
IGNORE_LIST=("floorp" "node_modules" "raycast" "stats" "stylus" "custom-cursor-extensions")

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


# Symlink agent skills into Claude and Codex skills directories
skills_source="$fixed_location/agents/.agents/skills"
claude_skills_dir="$HOME/.claude/skills"
codex_skills_dir="$HOME/.codex/skills"

if [ -d "$skills_source" ]; then
	mkdir -p "$claude_skills_dir" "$codex_skills_dir"

	for skill_dir in "$skills_source"/*; do
		if [ -d "$skill_dir" ]; then
			skill_name=$(basename "$skill_dir")
			ln -sfn "$skill_dir" "$claude_skills_dir/$skill_name"
			ln -sfn "$skill_dir" "$codex_skills_dir/$skill_name"
		fi
	done
fi

