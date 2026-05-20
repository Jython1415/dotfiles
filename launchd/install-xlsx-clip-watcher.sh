#!/usr/bin/env bash
# install-xlsx-clip-watcher.sh — idempotent install of the Folder Action watcher.
# Called by the deploy endpoint; also safe to run manually from Terminal.
#
# DESIGN: macOS Folder Action on ~/Downloads.
# FolderActionsAgent runs in the user GUI session and has Downloads TCC access.
#
# KEY GOTCHAS (learned in production, 2026-05-20):
#   1. `folder action pathString` does a NAME lookup, not a path lookup. Always
#      use `first folder action whose path is X` (filter reference) to find an
#      existing action by path.
#   2. FolderActionsAgent must be started/restarted after script attachment for
#      the new configuration to take effect. The agent may not be running at all
#      (confirmed on macOS 14 — it only starts on demand, not at login).

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

# 4. Compile AppleScript → .scpt in Folder Action Scripts directory
mkdir -p "$SCRIPTS_DIR"
if osacompile -o "$SCPT_DEST" "$APPLESCRIPT_SRC" 2>/dev/null; then
    echo "  folder action script: compiled → $SCPT_DEST"
else
    echo "  ERROR: osacompile failed — check $APPLESCRIPT_SRC"
    exit 1
fi

# 5. Register Folder Action on ~/Downloads and attach the script.
#    Uses filter reference (`first folder action whose path is X`) to look up
#    any existing action — direct path-string lookup (`folder action X`) does
#    a NAME lookup and fails with -1728 on modern macOS. Written to a temp
#    file to avoid heredoc-in-subshell parsing issues.
TMPOSA=$(mktemp /tmp/xlsx-register-fa.XXXXXX.osa)
cat > "$TMPOSA" << 'OSASCRIPT_CONTENT'
tell application "System Events"
    set folder actions enabled to true
    set dlPath to "/Users/" & (do shell script "whoami") & "/Downloads"

    -- Create folder action for Downloads if it doesn't already exist.
    -- -48 means already exists — fine.
    try
        make new folder action with properties {path:dlPath}
    on error errMsg number errCode
        if errCode is not -48 then
            error errMsg number errCode
        end if
    end try

    -- Get the existing action via FILTER REFERENCE (not name lookup).
    -- `folder action pathString` does a name lookup and returns -1728.
    -- `first folder action whose path is X` works correctly.
    set fa to first folder action whose path is dlPath
    set enabled of fa to true

    -- Remove any stale script entries then attach fresh.
    try
        set stale to every script of fa whose name is "xlsx-clip-watcher.scpt"
        repeat with s in stale
            delete s
        end repeat
    end try
    make new script of fa with properties {name:"xlsx-clip-watcher.scpt"}
    return "ok scripts=" & (name of every script of fa)
end tell
OSASCRIPT_CONTENT

REGISTER_OUT=$(osascript "$TMPOSA" 2>&1)
REGISTER_RC=$?
rm -f "$TMPOSA"
echo "  folder action registration: $REGISTER_OUT (rc=$REGISTER_RC)"
if [[ $REGISTER_RC -ne 0 ]]; then
    echo "  WARNING: Folder Action registration failed (rc=$REGISTER_RC)"
fi

# 6. Start/restart FolderActionsAgent.
#    The agent may not be running (it doesn't auto-start at login on macOS 14).
#    Without it running, Folder Actions never fire even if correctly configured.
launchctl stop com.apple.FolderActionsAgent 2>/dev/null || true
sleep 1
launchctl start com.apple.FolderActionsAgent 2>/dev/null || true
sleep 1
if pgrep -q FolderActionsAgent; then
    echo "  FolderActionsAgent: running (pid=$(pgrep FolderActionsAgent))"
else
    echo "  FolderActionsAgent: started (or will start on next file event)"
fi

echo ""
echo "Watching ~/Downloads for ScheduleAtAGlance*.xlsx files (Folder Action)."
echo "Log: tail -f $STATE_DIR/watcher.log"
echo "Done."
