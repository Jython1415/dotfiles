#!/usr/bin/env bash
# install-xlsx-clip-watcher.sh — installs and loads com.joshuashew.xlsx-clip-watcher

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
TEMPLATE="$DOTFILES_DIR/launchd/agents/com.joshuashew.xlsx-clip-watcher.plist.template"
PLIST_DIR="$HOME/Library/LaunchAgents"
PLIST_DEST="$PLIST_DIR/com.joshuashew.xlsx-clip-watcher.plist"
LABEL="com.joshuashew.xlsx-clip-watcher"
DOMAIN="gui/$(id -u)"

echo "=== install-xlsx-clip-watcher $(date +%H:%M:%S) ==="
echo "  dotfiles: $DOTFILES_DIR"

mkdir -p "$PLIST_DIR"
sed "s|\$HOME|$HOME|g" "$TEMPLATE" > "$PLIST_DEST"
echo "  plist written: $PLIST_DEST"

chmod +x "$DOTFILES_DIR/launchd/scripts/xlsx-clip-watcher.sh"
echo "  script marked executable"

if launchctl list | grep -q "$LABEL"; then
    launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || launchctl unload "$PLIST_DEST" 2>/dev/null || true
    echo "  unloaded previous version"
    sleep 1
fi

if launchctl bootstrap "$DOMAIN" "$PLIST_DEST"; then
    echo "  loaded: $LABEL (bootstrap)"
else
    launchctl load "$PLIST_DEST" 2>/dev/null || true
    echo "  loaded: $LABEL (legacy load)"
fi

echo ""
echo "Log:   tail -f /tmp/xlsx-clip-watcher.log"
echo "State: $HOME/.local/state/xlsx-clip-watcher/seen.txt"
echo ""
echo "Done. Agent polls every 5s — clipboard updates within 5s of a new download."
