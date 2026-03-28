#!/usr/bin/env bash
# Usage: bash switch-theme.sh lcars
THEME="${1:-minimal}"
THEME_DIR="$(dirname "$0")"

if [ ! -f "$THEME_DIR/$THEME.json" ]; then
    echo "Error: theme '$THEME' not found in $THEME_DIR"
    echo "Available themes:"
    ls "$THEME_DIR"/*.json 2>/dev/null | xargs -I{} basename {} .json
    exit 1
fi

mkdir -p ~/.atlas
cp "$THEME_DIR/$THEME.json" ~/.atlas/hud-theme.json
echo "Theme switched to: $THEME"
