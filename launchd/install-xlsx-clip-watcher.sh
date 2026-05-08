#!/usr/bin/env bash
# install-xlsx-clip-watcher.sh — starts watcher + auto-updater, sets up persistence

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
SCRIPT="$DOTFILES_DIR/launchd/scripts/xlsx-clip-watcher.sh"
AUTO_UPDATER="$DOTFILES_DIR/launchd/scripts/dotfiles-auto-updater.sh"
STATE_DIR="$HOME/.local/state/xlsx-clip-watcher"
LOG="$STATE_DIR/watcher.log"
AUTO_LOG="$STATE_DIR/auto-updater.log"

mkdir -p "$STATE_DIR"

echo "=== install-xlsx-clip-watcher $(date +%H:%M:%S) ==="
echo "  dotfiles: $DOTFILES_DIR"

if ! command -v fswatch &>/dev/null; then
    echo "  installing fswatch via brew..."
    brew install fswatch || { echo "  ERROR: brew install fswatch failed"; exit 1; }
fi
echo "  fswatch: $(command -v fswatch)"

chmod +x "$SCRIPT" "$AUTO_UPDATER"

# Stop watcher: kill the named script AND fswatch (child process that holds
# the flock fd via the pipeline; pkill on script name alone leaves fswatch
# as an orphan keeping the lock).
pkill -f "xlsx-clip-watcher.sh" 2>/dev/null && echo "  watcher: stopped"
pkill -f "fswatch.*Downloads" 2>/dev/null && echo "  fswatch: stopped"
sleep 1

nohup /bin/bash "$SCRIPT" >> "$LOG" 2>&1 &
echo "  watcher: started PID $!"

pkill -f "dotfiles-auto-updater.sh" 2>/dev/null && echo "  auto-updater: stopped"
sleep 1

nohup /bin/bash "$AUTO_UPDATER" >> "$AUTO_LOG" 2>&1 &
echo "  auto-updater: started PID $!"

REBOOT_W="@reboot /bin/bash $SCRIPT >> $LOG 2>&1 &  # xlsx-clip-watcher"
WATCHDOG_W="* * * * * pgrep -qf xlsx-clip-watcher.sh || /bin/bash $SCRIPT >> $LOG 2>&1 &  # xlsx-clip-watcher"
REBOOT_A="@reboot /bin/bash $AUTO_UPDATER >> $AUTO_LOG 2>&1 &  # xlsx-clip-watcher-updater"
WATCHDOG_A="* * * * * pgrep -qf dotfiles-auto-updater.sh || /bin/bash $AUTO_UPDATER >> $AUTO_LOG 2>&1 &  # xlsx-clip-watcher-updater"

(crontab -l 2>/dev/null | grep -v "xlsx-clip-watcher" || true
 echo "$REBOOT_W"
 echo "$WATCHDOG_W"
 echo "$REBOOT_A"
 echo "$WATCHDOG_A") | crontab -
echo "  crontab: @reboot + 1-min watchdog (watcher + auto-updater)"

echo ""
echo "Logs:"
echo "  watcher:      tail -f $LOG"
echo "  auto-updater: tail -f $AUTO_LOG"
echo "State: $STATE_DIR/seen.txt"
echo "Done."
