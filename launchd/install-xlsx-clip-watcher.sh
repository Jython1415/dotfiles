#!/usr/bin/env bash
# install-xlsx-clip-watcher.sh — idempotent install/reload of the Folder Action watcher.
# Run after pulling dotfiles: bash ~/.dotfiles/launchd/install-xlsx-clip-watcher.sh
#
# DESIGN: macOS Folder Action on ~/Downloads.
# FolderActionsAgent has Downloads TCC access natively — no bash TCC workarounds needed.

# Go up one level: this script lives in .dotfiles/launchd/; dotfiles root is one above
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
LABEL="com.joshuashew.xlsx-clip-watcher"
STATE_DIR="$HOME/.local/state/xlsx-clip-watcher"
SCRIPTS_DIR="$HOME/Library/Scripts/Folder Action Scripts"
SCPT_DEST="$SCRIPTS_DIR/xlsx-clip-watcher.scpt"
APPLESCRIPT_SRC="$DOTFILES_DIR/launchd/scripts/xlsx-clip-watcher.applescript"
OLD_PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

echo "=== install-xlsx-clip-watcher $(date '+%H:%M:%S') ==="
echo "  dotfiles:  $DOTFILES_DIR"

# 1. Create state dir
mkdir -p "$STATE_DIR"
echo "  state dir: $STATE_DIR"

# 2. Pre-warm xlcat uv cache
echo "  warming xlcat uv cache..."
if command -v uv &>/dev/null && [[ -x "$DOTFILES_DIR/bin/xlcat" ]]; then
    timeout 60 uv run "$DOTFILES_DIR/bin/xlcat" /dev/null 2>/dev/null || true
    echo "  xlcat: cache warm (exit ignored — /dev/null not a valid xlsx)"
else
    echo "  xlcat: skipped (uv or xlcat not found at $DOTFILES_DIR/bin/xlcat)"
fi

# 3. Retire old launchd agent if present
if launchctl list "$LABEL" &>/dev/null 2>&1; then
    launchctl unload "$OLD_PLIST" 2>/dev/null && echo "  launchd agent: unloaded" || true
fi
if [[ -f "$OLD_PLIST" ]]; then
    rm -f "$OLD_PLIST" && echo "  launchd plist: removed"
fi

# Remove legacy crontab entries
if crontab -l 2>/dev/null | grep -q "xlsx-clip-watcher"; then
    (crontab -l 2>/dev/null | grep -v "xlsx-clip-watcher") | crontab - && \
        echo "  crontab: removed legacy entries" || true
fi

# 4. Compile AppleScript to .scpt in Folder Action Scripts directory
mkdir -p "$SCRIPTS_DIR"
if osacompile -o "$SCPT_DEST" "$APPLESCRIPT_SRC" 2>/dev/null; then
    echo "  folder action script: compiled → $SCPT_DEST"
else
    echo "  ERROR: osacompile failed — check $APPLESCRIPT_SRC"
    exit 1
fi

# 5. Register Folder Action on ~/Downloads (idempotent: delete + recreate)
REGISTER_OUT=$(osascript 2>&1 << 'OSASCRIPT'
tell application "System Events"
    set folder actions enabled to true
    set dlHFS to (path to downloads folder) as text

    -- Idempotent: iterate all folder actions and delete any matching Downloads.
    -- The "if exists" pattern is unreliable (path lookup quirk returns false even
    -- when the action exists), so we iterate and match instead.
    try
        set allFAs to every folder action
        repeat with fa in allFAs
            if path of fa is dlHFS then
                delete fa
            end if
        end repeat
    end try

    -- Create fresh and attach script
    make new folder action with properties {path:dlHFS, enabled:true}
    tell folder action dlHFS
        make new script with properties {name:"xlsx-clip-watcher.scpt"}
    end tell
end tell
return "ok"
OSASCRIPT
)
REGISTER_RC=$?
echo "  folder action registration: $REGISTER_OUT (rc=$REGISTER_RC)"
if [[ $REGISTER_RC -ne 0 ]]; then
    echo "  WARNING: Folder Action registration may have failed."
    echo "  Run manually: osascript ~/.dotfiles/launchd/register-folder-action.sh"
fi

echo ""
echo "Watching ~/Downloads for ScheduleAtAGlance*.xlsx files (Folder Action)."
echo "Log: tail -f $STATE_DIR/watcher.log"
echo "Done."
