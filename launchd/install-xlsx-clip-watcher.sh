#!/usr/bin/env bash
# install-xlsx-clip-watcher.sh — installs and loads com.joshuashew.xlsx-clip-watcher

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
TEMPLATE="$DOTFILES_DIR/launchd/agents/com.joshuashew.xlsx-clip-watcher.plist.template"
PLIST_DIR="$HOME/Library/LaunchAgents"
PLIST_DEST="$PLIST_DIR/com.joshuashew.xlsx-clip-watcher.plist"
LABEL="com.joshuashew.xlsx-clip-watcher"

echo "=== install-xlsx-clip-watcher $(date +%H:%M:%S) ==="
echo "  dotfiles: $DOTFILES_DIR"

mkdir -p "$PLIST_DIR"
sed "s|\$HOME|$HOME|g" "$TEMPLATE" > "$PLIST_DEST"
echo "  plist written: $PLIST_DEST"

chmod +x "$DOTFILES_DIR/launchd/scripts/xlsx-clip-watcher.sh"
echo "  script marked executable"

if launchctl list | grep -q "$LABEL"; then
    launchctl unload "$PLIST_DEST" 2>/dev/null || true
    echo "  unloaded previous version"
fi

launchctl load "$PLIST_DEST"
echo "  loaded: $LABEL"
echo ""
echo "Log:   tail -f /tmp/xlsx-clip-watcher.log"
echo "State: $HOME/.local/state/xlsx-clip-watcher/seen.txt"
echo ""
echo "Done. Drop an .xlsx file < 500KB into ~/Downloads to test."
