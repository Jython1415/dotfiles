#!/usr/bin/env bash
# xlsx-clip-watcher — one-shot polled by launchd StartInterval:5.
# Runs every 5 seconds. Idempotent: tracks seen files by device:inode
# so re-scans of the same file are ignored.
# WatchPaths was dropped: macOS 12+ fires on the .crdownload temp file,
# not on the final xlsx rename, so every scan ran before the file existed.

export PATH="$HOME/.dotfiles/bin:$HOME/.local/bin:$HOME/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"

DOWNLOADS="$HOME/Downloads"
STATE_DIR="$HOME/.local/state/xlsx-clip-watcher"
SEEN_FILE="$STATE_DIR/seen.txt"

mkdir -p "$STATE_DIR"

log() {
  local msg="[xlsx-clip-watcher] $(date '+%Y-%m-%d %H:%M:%S') $*"
  echo "$msg"
  echo "$msg" >> "$STATE_DIR/watcher.log"
}

# Heartbeat + environment snapshot — written every scan for liveness checks
{
  printf 'ts=%s HOME=%s DOWNLOADS=%s\n' \
    "$(date '+%Y-%m-%d %H:%M:%S')" "$HOME" "$DOWNLOADS"
  echo "ls -la Downloads:"
  ls -la "$DOWNLOADS" 2>&1 | head -20
  echo "---"
  echo "xlsx_in_downloads: $(find "$DOWNLOADS" -maxdepth 1 -name '*.xlsx' 2>/dev/null | wc -l | tr -d ' ') file(s) (find)"
  echo "xlsx_in_downloads_ls: $(ls "$DOWNLOADS"/*.xlsx 2>&1)"
  find "$DOWNLOADS" -maxdepth 1 -name '*.xlsx' 2>/dev/null | while read -r f; do echo "  $f"; done
} > "$STATE_DIR/last_scan"

processed=0
while IFS= read -r -d '' file; do
  [[ -f "$file" ]] || continue
  [[ "$(basename "$file")" == ScheduleAtAGlance* ]] || continue

  dev_inode=$(stat -f "%d:%i" "$file" 2>/dev/null) || continue
  grep -qxF "$dev_inode" "$SEEN_FILE" 2>/dev/null && continue

  log "new: $(basename "$file") (inode=$dev_inode)"

  # Pass the specific file — don't let xlcat guess from -d
  if xlcat "$file" | pbcopy; then
    printf '%s\n' "$dev_inode" >> "$SEEN_FILE"
    log "imported to clipboard: $(basename "$file")"

    if osascript -e "tell application \"Finder\" to delete POSIX file \"$file\"" 2>/dev/null; then
      log "trashed: $(basename "$file")"
    elif mv "$file" "$HOME/.Trash/" 2>/dev/null; then
      log "trashed (fallback): $(basename "$file")"
    else
      log "WARNING: could not trash $(basename "$file")"
    fi
    processed=$((processed + 1))
  else
    log "ERROR: xlcat failed for $(basename "$file") — not marking seen"
  fi
done < <(find "$DOWNLOADS" -maxdepth 1 -name "*.xlsx" -print0 2>/dev/null)

[[ $processed -gt 0 ]] && log "done ($processed processed)"
