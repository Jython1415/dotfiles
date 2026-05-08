#!/usr/bin/env bash
# install-xlsx-clip-watcher.sh — starts the watcher and makes it persistent

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
SCRIPT="$DOTFILES_DIR/launchd/scripts/xlsx-clip-watcher.sh"
LOG="/tmp/xlsx-clip-watcher.log"

echo "=== install-xlsx-clip-watcher $(date +%H:%M:%S) ==="
echo "  dotfiles: $DOTFILES_DIR"

chmod +x "$SCRIPT"
echo "  script marked executable"

# Stop any previous instance
if pkill -f "xlsx-clip-watcher.sh" 2>/dev/null; then
    echo "  stopped previous instance"
    sleep 1
fi

# Start directly — no launchd scheduling required
nohup /bin/bash "$SCRIPT" >> "$LOG" 2>&1 &
WATCHER_PID=$!
echo "  started: PID $WATCHER_PID"

# Persist across login: @reboot starts it, watchdog restarts if it crashes
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
echo "Done. Watcher polling every 5s."
