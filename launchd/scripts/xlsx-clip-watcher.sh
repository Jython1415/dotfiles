#!/usr/bin/env bash
# xlsx-clip-watcher — FSEvents-based via fswatch (no polling)
# Runs clip import xlsx on any new .xlsx < 500KB in ~/Downloads.
# Tracks files by device:inode so a re-downloaded file counts as new.

export PATH="$HOME/.local/bin:$HOME/bin:$HOME/.dotfiles/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"

DOWNLOADS="$HOME/Downloads"
STATE_DIR="$HOME/.local/state/xlsx-clip-watcher"
SEEN_FILE="$STATE_DIR/seen.txt"
LOCK_FILE="$STATE_DIR/watcher.lock"

mkdir -p "$STATE_DIR"

log() { echo "[xlsx-clip-watcher] $(date '+%Y-%m-%d %H:%M:%S') $*"; }

# Kill entire process group on SIGTERM so fswatch and the while-loop subshell
# (which inherit the flock fd) are cleaned up — otherwise pkill leaves orphans
# that hold the lock and cause every restart to immediately exit.
trap 'kill 0 2>/dev/null; exit 0' SIGTERM SIGINT

exec 9>"$LOCK_FILE"
if ! flock -n 9; then
    log "another instance already running, exiting"
    exit 0
fi

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
check_and_import
log "startup scan complete, entering fswatch loop"

fswatch -0 -e ".*" -i ".*\\.xlsx$" "$DOWNLOADS" | \
while IFS= read -r -d '' _event; do
    check_and_import
done

log "fswatch exited unexpectedly (will be restarted by watchdog)"
