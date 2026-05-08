#!/usr/bin/env bash
# xlsx-clip-watcher — FSEvents-based via fswatch (no polling)
# Runs clip import xlsx on any new .xlsx < 500KB in ~/Downloads.
# Tracks files by device:inode so a re-downloaded file counts as new.

export PATH="$HOME/.local/bin:$HOME/bin:$HOME/.dotfiles/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"

DOWNLOADS="$HOME/Downloads"
STATE_DIR="$HOME/.local/state/xlsx-clip-watcher"
SEEN_FILE="$STATE_DIR/seen.txt"

mkdir -p "$STATE_DIR"

log() { echo "[xlsx-clip-watcher] $(date '+%Y-%m-%d %H:%M:%S') $*"; }

check_and_import() {
    local new_inodes=()
    while IFS= read -r -d '' file; do
        [[ -f "$file" ]] || continue
        local size dev_inode
        size=$(stat -f "%z" "$file" 2>/dev/null) || continue
        [ "$size" -ge 512000 ] && continue
        dev_inode=$(stat -f "%d:%i" "$file" 2>/dev/null) || continue
        grep -qxF "$dev_inode" "$SEEN_FILE" 2>/dev/null && continue
        log "new: $(basename "$file") (${size}B inode=$dev_inode)"
        new_inodes+=("$dev_inode")
    done < <(find "$DOWNLOADS" -maxdepth 1 -name "*.xlsx" -print0 2>/dev/null)

    if [ "${#new_inodes[@]}" -gt 0 ]; then
        log "running: clip import xlsx -d $DOWNLOADS"
        if clip import xlsx -d "$DOWNLOADS"; then
            printf '%s\n' "${new_inodes[@]}" >> "$SEEN_FILE"
        else
            log "ERROR: clip exited non-zero — inodes not marked seen"
        fi
    fi
}

log "starting up (PID $$)"

# Startup scan: catch files downloaded while watcher was down
check_and_import
log "startup scan complete, entering fswatch loop"

# FSEvents watch — kernel notifies on .xlsx events, zero polling
fswatch -0 -e ".*" -i ".*\\.xlsx$" "$DOWNLOADS" | \
while IFS= read -r -d '' _event; do
    check_and_import
done

log "fswatch exited unexpectedly (will be restarted by watchdog)"
