#!/bin/bash
set -euo pipefail

# px0 reads ~/.px0/settings.json, and it writes to that file when its Settings panel saves a change.
# The file also holds the tokens for GitHub, GitLab, Gitea, and Bitbucket. This repo holds only the
# settings that every machine shares, in the px0 stow package. This script merges the two, so a
# token stays out of the repo and a shared setting takes the value from the repo on each install.

base="$HOME/.px0/settings.base.json" # a link into the px0 stow package
settings="$HOME/.px0/settings.json"

if [[ ! -f "$base" ]]; then
	echo "px0 settings: $base is missing, so ~/.px0/settings.json stays as it is" >&2
	exit 0
fi

mkdir -p "$HOME/.px0"

# An earlier layout linked this file into the repo. Remove the link, so that this script and px0
# write a plain file and no token can reach the repo.
if [[ -L "$settings" ]]; then
	rm "$settings"
fi

# Without a local file, the base is the whole file. With one, the base wins each key it defines,
# and a key that only the local file has (a token, the last theme) stays.
if [[ -f "$settings" ]]; then
	tmp="$(mktemp "$HOME/.px0/settings.json.XXXXXX")"
	trap 'rm -f "$tmp"' EXIT
	jq -s '.[0] * .[1]' "$settings" "$base" >"$tmp"
	mv "$tmp" "$settings"
else
	cp "$base" "$settings"
fi
