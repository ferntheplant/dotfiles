#!/bin/bash

usage() {
    echo "Usage: $0 filename [--light|--dark] [--underscore]"
    exit 1
}

if [ $# -lt 1 ]; then
    usage
fi

FILE="$1"
if [ ! -e "$FILE" ]; then
    echo "File $FILE not found!"
    exit 1
fi

TARGET_FILE=$(readlink -f "$FILE" || echo "$FILE")

# Default to dash separator
SEPARATOR="-"
REPLACEMENT_ACTION=""

# Process flags
for arg in "$@"; do
    case $arg in
        --light)
            REPLACEMENT_ACTION="light"
            ;;
        --dark)
            REPLACEMENT_ACTION="dark"
            ;;
        --underscore)
            SEPARATOR="_"
            ;;
    esac
done

# Create a unique temporary file to avoid race conditions when multiple instances run concurrently
TMPFILE=$(mktemp) || exit 1
trap 'rm -f "$TMPFILE"' EXIT

# Perform replacement on lines containing '=' (key=value) or '"' (KDL key "value" syntax)
if [ "$REPLACEMENT_ACTION" == "light" ]; then
    sed -E '/(=|")/s/catppuccin[_-]macchiato/catppuccin'${SEPARATOR}'latte/g' "$TARGET_FILE" > "$TMPFILE" && mv "$TMPFILE" "$TARGET_FILE"
elif [ "$REPLACEMENT_ACTION" == "dark" ]; then
    sed -E '/(=|")/s/catppuccin[_-]latte/catppuccin'${SEPARATOR}'macchiato/g' "$TARGET_FILE" > "$TMPFILE" && mv "$TMPFILE" "$TARGET_FILE"
else
    usage
fi
