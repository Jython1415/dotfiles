#!/usr/bin/env bash
# xlsx-clip-watcher-process.sh — called by the Folder Action with a single
# xlsx file path as $1. Handles inode-based dedup, xlcat import, clipboard,
# and trash.
#
# Inode dedup: stat(1) returns device:inode for the file. If that pair is
# already in seen.txt, the file was previously processed — skip it. This
# naturally handles files restored from Trash: the inode is unchanged across
# Trash ↔ Downloads moves on the same APFS volume, so restored files are
# silently skipped without extra bookkeeping.

export PATH="$HOME/.dotfiles/bin:$HOME/.local/bin:$HOME/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"

FILE="$1"
STATE_DIR="$HOME/.local/state/xlsx-clip-watcher"
SEEN_FILE="$STATE_DIR/seen.txt"

mkdir -p "$STATE_DIR"

log() {
    local msg="[xlsx-clip-watcher] $(date '+%Y-%m-%d %H:%M:%S') $*"
    echo "$msg"
    printf '%s\n' "$msg" >> "$STATE_DIR/watcher.log"
}

[[ -n "$FILE" ]] || exit 0
[[ -f "$FILE" ]] || exit 0

# Inode-based dedup — skips previously-processed files (including restored-from-Trash)
DEV_INODE=$(stat -f "%d:%i" "$FILE" 2>/dev/null) || {
    log "ERROR: stat failed for $(basename "$FILE")"
    exit 1
}
grep -qxF "$DEV_INODE" "$SEEN_FILE" 2>/dev/null && exit 0

log "new: $(basename "$FILE") (inode=$DEV_INODE)"

if xlcat "$FILE" | pbcopy; then
    printf '%s\n' "$DEV_INODE" >> "$SEEN_FILE"
    log "imported to clipboard: $(basename "$FILE")"

    # Trash via Finder (preserves recovery; supports both forms)
    if osascript -e "tell application \"Finder\" to delete POSIX file \"$FILE\"" 2>/dev/null; then
        log "trashed: $(basename "$FILE")"
    elif mv "$FILE" "$HOME/.Trash/" 2>/dev/null; then
        log "trashed (fallback): $(basename "$FILE")"
    else
        log "WARNING: could not trash $(basename "$FILE") — left in place"
    fi
else
    log "ERROR: xlcat failed for $(basename "$FILE") — not marking seen"
fi
