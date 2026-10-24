#!/bin/bash
# Swap one theme name for another on the theme-selecting lines of a config file:
#
#   update-theme.sh <file> <from> <to>
#   update-theme.sh ~/.config/bat/config vitesse-dark-soft vitesse-light-soft
#
# Names are the dashed build stems (<theme>-<variant>). The underscored form Helix uses
# (vitesse_dark_soft) is swapped too, so no --underscore flag is needed. Only lines that set
# theme / palette / color_theme / features are touched, like scripts/update-rose-pine.sh.

if [ $# -ne 3 ]; then
    echo "Usage: $0 <file> <from> <to>"
    exit 1
fi

FILE="$1"
FROM="$2"
TO="$3"
if [ ! -e "$FILE" ]; then
    echo "File $FILE not found!"
    exit 1
fi

TARGET_FILE=$(readlink -f "$FILE" || echo "$FILE")
FROM_US="${FROM//-/_}"
TO_US="${TO//-/_}"

TMPFILE=$(mktemp) || exit 1
trap 'rm -f "$TMPFILE"' EXIT

# \b-style guard: the name must not be followed by more name characters, so swapping
# vitesse-dark does not also rewrite vitesse-dark-soft.
LINE='^[[:space:]]*((-{1,2})?(color_theme|features|theme|palette))[[:space:]]*(=|")'
sed -E "/$LINE/{
s/$FROM([^a-zA-Z0-9_-]|\$)/$TO\\1/g
s/$FROM_US([^a-zA-Z0-9_-]|\$)/$TO_US\\1/g
}" "$TARGET_FILE" > "$TMPFILE" && mv "$TMPFILE" "$TARGET_FILE"
