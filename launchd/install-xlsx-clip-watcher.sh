#!/usr/bin/env bash
# install-xlsx-clip-watcher.sh — installs and loads com.joshuashew.xlsx-clip-watcher

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

# Stop any running instance
launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || launchctl unload "$PLIST_DEST" 2>/dev/null || true
sleep 1

# Register with launchd (bootstrap preferred, legacy fallback)
if launchctl bootstrap "$DOMAIN" "$PLIST_DEST" 2>/dev/null; then
    echo "  registered: $LABEL (bootstrap)"
else
    launchctl load "$PLIST_DEST" 2>/dev/null || true
    echo "  registered: $LABEL (legacy load)"
fi

# Force-start the while-loop script regardless of load method
if launchctl kickstart -k "$DOMAIN/$LABEL" 2>/dev/null; then
    echo "  kickstarted: $LABEL"
else
    echo "  WARN: kickstart failed — trying direct launch"
    nohup bash "$DOTFILES_DIR/launchd/scripts/xlsx-clip-watcher.sh" \
        >> /tmp/xlsx-clip-watcher.log 2>&1 &
    echo "  launched directly (PID $!)"
fi

# Survive logout: crontab @reboot re-kickstarts the registered agent
CRON_ENTRY="@reboot launchctl kickstart -k $DOMAIN/$LABEL  # xlsx-clip-watcher"
(crontab -l 2>/dev/null | grep -v "xlsx-clip-watcher" || true; echo "$CRON_ENTRY") | crontab -
echo "  crontab @reboot entry set"

echo ""
echo "Log:   tail -f /tmp/xlsx-clip-watcher.log"
echo "State: $HOME/.local/state/xlsx-clip-watcher/seen.txt"
echo ""
echo "Done. Watcher polling every 5s."
