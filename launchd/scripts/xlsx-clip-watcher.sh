#!/usr/bin/env bash
# xlsx-clip-watcher — continuous poller, runs via KeepAlive launchd agent
# Checks ~/Downloads every 5 seconds for new .xlsx < 500KB and runs
# clip import xlsx if any are new. Tracks by device:inode.

export PATH="$HOME/.local/bin:$HOME/bin:$HOME/.dotfiles/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"

DOWNLOADS="$HOME/Downloads"
STATE_DIR="$HOME/.local/state/xlsx-clip-watcher"
SEEN_FILE="$STATE_DIR/seen.txt"

mkdir -p "$STATE_DIR"

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
            echo "[xlsx-clip-watcher] $(date '+%Y-%m-%d %H:%M:%S') clip exited non-zero — inodes not marked seen"
        fi
    fi

    sleep 5
done
