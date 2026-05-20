#!/usr/bin/env bash
# install-xlsx-clip-watcher.sh — idempotent install/reload of the Folder Action watcher.
# Run after pulling dotfiles updates: bash ~/.dotfiles/launchd/install-xlsx-clip-watcher.sh
#
# Replaces the old launchd StartInterval:5 design (which required osascript for
# file enumeration due to TCC restrictions). Folder Actions run under
# com.apple.FolderActionsAgent, which has Downloads TCC access natively.

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
LABEL="com.joshuashew.xlsx-clip-watcher"
STATE_DIR="$HOME/.local/state/xlsx-clip-watcher"
SCRIPTS_DIR="$HOME/Library/Scripts/Folder Action Scripts"
SCPT_DEST="$SCRIPTS_DIR/xlsx-clip-watcher.scpt"
APPLESCRIPT_SRC="$DOTFILES_DIR/scripts/xlsx-clip-watcher.applescript"
OLD_PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

echo "=== install-xlsx-clip-watcher $(date '+%H:%M:%S') ==="
echo "  dotfiles:  $DOTFILES_DIR"

# 1. Create state dir
mkdir -p "$STATE_DIR"
echo "  state dir: $STATE_DIR"

# 2. Pre-warm xlcat uv cache so first real trigger doesn't stall
echo "  warming xlcat uv cache..."
if command -v uv &>/dev/null && [[ -x "$DOTFILES_DIR/bin/xlcat" ]]; then
    timeout 60 uv run "$DOTFILES_DIR/bin/xlcat" /dev/null 2>/dev/null || true
    echo "  xlcat: cache warm"
else
    echo "  xlcat: skipped (uv or xlcat not found)"
fi

# 3. Retire old launchd agent if present
if launchctl list "$LABEL" &>/dev/null 2>&1; then
    launchctl unload "$OLD_PLIST" 2>/dev/null && echo "  launchd agent: unloaded" || true
fi
if [[ -f "$OLD_PLIST" ]]; then
    rm -f "$OLD_PLIST"
    echo "  launchd plist: removed"
fi

# Remove legacy crontab entries
if crontab -l 2>/dev/null | grep -q "xlsx-clip-watcher"; then
    (crontab -l 2>/dev/null | grep -v "xlsx-clip-watcher") | crontab - && \
        echo "  crontab: removed legacy entries" || true
fi

# 4. Compile AppleScript to .scpt in Folder Action Scripts directory
mkdir -p "$SCRIPTS_DIR"
osacompile -o "$SCPT_DEST" "$APPLESCRIPT_SRC"
echo "  folder action script: $SCPT_DEST"

# 5. Register Folder Action on ~/Downloads (idempotent via delete+recreate)
REGISTER_RESULT=$(osascript 2>&1 << 'OSASCRIPT'
tell application "System Events"
    set folder actions enabled to true
    set dlHFS to (path to downloads folder) as text

    -- Remove any existing Folder Action for Downloads to ensure a clean state
    try
        if exists folder action dlHFS then
            delete folder action dlHFS
        end if
    end try

    -- Attach new Folder Action
    make new folder action with properties {path:dlHFS, enabled:true}
    tell folder action dlHFS
        make new script with properties {name:"xlsx-clip-watcher.scpt"}
    end tell
end tell
return "ok"
OSASCRIPT
)
echo "  folder action registration: $REGISTER_RESULT"

echo ""
echo "Watching ~/Downloads for ScheduleAtAGlance*.xlsx files (Folder Action)."
echo "Log: tail -f $STATE_DIR/watcher.log"
echo "Done."
