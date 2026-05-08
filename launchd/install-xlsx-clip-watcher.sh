#!/usr/bin/env bash
# install-xlsx-clip-watcher.sh — installs fswatch, starts watcher, sets up persistence

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
SCRIPT="$DOTFILES_DIR/launchd/scripts/xlsx-clip-watcher.sh"
LOG="/tmp/xlsx-clip-watcher.log"

echo "=== install-xlsx-clip-watcher $(date +%H:%M:%S) ==="
echo "  dotfiles: $DOTFILES_DIR"

# Ensure fswatch is available (uses macOS FSEvents, no polling)
if ! command -v fswatch &>/dev/null; then
    echo "  installing fswatch via brew..."
    if ! brew install fswatch; then
        echo "  ERROR: brew install fswatch failed — aborting"
        exit 1
    fi
fi
echo "  fswatch: $(command -v fswatch)"

chmod +x "$SCRIPT"

# Stop any previous instance
if pkill -f "xlsx-clip-watcher.sh" 2>/dev/null; then
    echo "  stopped previous instance"
    sleep 1
fi

# Start directly — no launchd scheduling required
nohup /bin/bash "$SCRIPT" >> "$LOG" 2>&1 &
WATCHER_PID=$!
echo "  started: PID $WATCHER_PID"

# Persist across login/restart: @reboot starts it, watchdog restarts on crash
REBOOT_ENTRY="@reboot /bin/bash $SCRIPT >> $LOG 2>&1 &  # xlsx-clip-watcher"
WATCHDOG_ENTRY="* * * * * pgrep -qf xlsx-clip-watcher.sh || /bin/bash $SCRIPT >> $LOG 2>&1 &  # xlsx-clip-watcher"
(crontab -l 2>/dev/null | grep -v "xlsx-clip-watcher" || true
 echo "$REBOOT_ENTRY"
 echo "$WATCHDOG_ENTRY") | crontab -
echo "  crontab: @reboot + 1-min watchdog"

echo ""
echo "Log:   tail -f $LOG"
echo "State: $HOME/.local/state/xlsx-clip-watcher/seen.txt"
echo ""
echo "Done. Watcher active (FSEvents, no polling)."
