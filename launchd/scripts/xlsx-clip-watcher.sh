#!/usr/bin/env bash
# xlsx-clip-watcher — polled every 5s via nohup background process
# Runs clip import xlsx if any new .xlsx < 500KB has appeared since last run.
# Tracks files by device:inode so a re-downloaded file with the same name
# counts as new.

export PATH="$HOME/.local/bin:$HOME/bin:$HOME/.dotfiles/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"

DOWNLOADS="$HOME/Downloads"
STATE_DIR="$HOME/.local/state/xlsx-clip-watcher"
SEEN_FILE="$STATE_DIR/seen.txt"

mkdir -p "$STATE_DIR"
echo "[xlsx-clip-watcher] $(date '+%Y-%m-%d %H:%M:%S') starting up (PID $$)"

while true; do
    new_inodes=()
    while IFS= read -r -d '' file; do
        size=$(stat -f "%z" "$file" 2>/dev/null) || continue
        [ "$size" -ge 512000 ] && continue
        dev_inode=$(stat -f "%d:%i" "$file" 2>/dev/null) || continue
        if ! grep -qxF "$dev_inode" "$SEEN_FILE" 2>/dev/null; then
            echo "[xlsx-clip-watcher] $(date '+%Y-%m-%d %H:%M:%S') new: $(basename "$file") (${size}B inode=$dev_inode)"
            new_inodes+=("$dev_inode")
        fi
    done < <(find "$DOWNLOADS" -maxdepth 1 -name "*.xlsx" -print0 2>/dev/null)

    if [ "${#new_inodes[@]}" -gt 0 ]; then
        echo "[xlsx-clip-watcher] $(date '+%Y-%m-%d %H:%M:%S') running: clip import xlsx -d $DOWNLOADS"
        if clip import xlsx -d "$DOWNLOADS"; then
            printf '%s\n' "${new_inodes[@]}" >> "$SEEN_FILE"
        else
            echo "[xlsx-clip-watcher] $(date '+%Y-%m-%d %H:%M:%S') ERROR: clip exited non-zero — inodes not marked seen"
        fi
    fi

    sleep 5
done
