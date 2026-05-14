#!/usr/bin/env bash
# install-xlsx-clip-watcher.sh — idempotent install/reload of the watcher.
# Run after pulling dotfiles updates: bash ~/.dotfiles/launchd/install-xlsx-clip-watcher.sh

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
TEMPLATE="$DOTFILES_DIR/launchd/agents/com.joshuashew.xlsx-clip-watcher.plist.template"
PLIST_DEST="$HOME/Library/LaunchAgents/com.joshuashew.xlsx-clip-watcher.plist"
LABEL="com.joshuashew.xlsx-clip-watcher"
STATE_DIR="$HOME/.local/state/xlsx-clip-watcher"

echo "=== install-xlsx-clip-watcher $(date '+%H:%M:%S') ==="
echo "  dotfiles:  $DOTFILES_DIR"

# 1. Create state dir so launchd can open the log file before the script runs
mkdir -p "$STATE_DIR"
echo "  state dir: $STATE_DIR"

# 2. Pre-warm uv cache for xlcat so the first real trigger doesn't stall
echo "  warming xlcat uv cache..."
if command -v uv &>/dev/null && [[ -x "$DOTFILES_DIR/bin/xlcat" ]]; then
  echo '# dummy xlsx to warm cache' | \
    timeout 60 uv run "$DOTFILES_DIR/bin/xlcat" /dev/null 2>/dev/null || true
  echo "  xlcat: cache warm (exit ignored — /dev/null not a valid xlsx)"
else
  echo "  xlcat: skipped (uv or xlcat not found)"
fi

# 3. Remove legacy crontab entries (old design used @reboot + watchdog)
if crontab -l 2>/dev/null | grep -q "xlsx-clip-watcher"; then
  (crontab -l 2>/dev/null | grep -v "xlsx-clip-watcher") | crontab - && \
    echo "  crontab: removed legacy entries" || \
    echo "  crontab: could not remove (non-interactive — OK)"
else
  echo "  crontab: no legacy entries"
fi

# 4. Unload old agent (ignore errors if not loaded)
launchctl unload "$PLIST_DEST" 2>/dev/null && echo "  agent: unloaded" || echo "  agent: was not loaded"

# Kill any leftover daemon-mode processes from the old design
pkill -f "xlsx-clip-watcher.sh" 2>/dev/null && echo "  old process: stopped" || true
pkill -f "fswatch.*Downloads"   2>/dev/null && echo "  fswatch: stopped"    || true
rm -f "$STATE_DIR/watcher.lock"

# 5. Build plist from template (substitute DOTFILES_DIR and HOME_DIR)
sed \
  -e "s|DOTFILES_DIR|$DOTFILES_DIR|g" \
  -e "s|HOME_DIR|$HOME|g" \
  "$TEMPLATE" > "$PLIST_DEST"
echo "  plist: installed → $PLIST_DEST"

# 6. Load the new agent
launchctl load "$PLIST_DEST"
echo "  agent: loaded"

echo ""
echo "Watching ~/Downloads for ScheduleAtAGlance*.xlsx files."
echo "Log: tail -f $STATE_DIR/watcher.log"
echo "Done."
