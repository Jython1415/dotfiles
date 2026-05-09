#!/usr/bin/env bash
# install-xlsx-clip-watcher.sh — starts watcher, sets up cron persistence.
# Deploy via: POST /proxy/dashboard/admin/deploy/dotfiles

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
SCRIPT="$DOTFILES_DIR/launchd/scripts/xlsx-clip-watcher.sh"
STATE_DIR="$HOME/.local/state/xlsx-clip-watcher"
LOG="$STATE_DIR/watcher.log"

mkdir -p "$STATE_DIR"

echo "=== install-xlsx-clip-watcher $(date +%H:%M:%S) ==="
echo "  dotfiles: $DOTFILES_DIR"

if ! command -v fswatch &>/dev/null; then
    echo "  installing fswatch via brew..."
    brew install fswatch || { echo "  ERROR: brew install fswatch failed"; exit 1; }
fi
echo "  fswatch: $(command -v fswatch)"

chmod +x "$SCRIPT"

# Stop any running instance (and its fswatch child) before restarting.
pkill -f "xlsx-clip-watcher.sh" 2>/dev/null && echo "  watcher: stopped"
pkill -f "fswatch.*Downloads" 2>/dev/null && echo "  fswatch: stopped"
sleep 3

nohup /bin/bash "$SCRIPT" >> "$LOG" 2>&1 &
echo "  watcher: started PID $!"

REBOOT_W="@reboot /bin/bash $SCRIPT >> $LOG 2>&1 &  # xlsx-clip-watcher"
WATCHDOG_W="* * * * * flock -n $STATE_DIR/watcher.lock true && /bin/bash $SCRIPT >> $LOG 2>&1 &  # xlsx-clip-watcher"

# crontab write may fail in non-interactive contexts (macOS permission model).
# Non-fatal: crontab from the initial interactive install persists.
(crontab -l 2>/dev/null | grep -v "xlsx-clip-watcher" || true
 echo "$REBOOT_W"
 echo "$WATCHDOG_W") | crontab - 2>/dev/null && echo "  crontab: updated" || echo "  crontab: skipped (non-interactive; prior entries still active)"

echo ""
echo "Log: tail -f $LOG"
echo "State: $STATE_DIR/seen.txt"
echo "Done."
