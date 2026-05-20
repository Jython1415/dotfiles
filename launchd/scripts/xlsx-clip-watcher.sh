#!/usr/bin/env bash
# xlsx-clip-watcher — one-shot polled by launchd StartInterval:5.
# Runs every 5 seconds. Idempotent: tracks seen files by device:inode
# so re-scans of the same file are ignored.
# WatchPaths was dropped: macOS 12+ fires on the .crdownload temp file,
# not on the final xlsx rename, so every scan ran before the file existed.
# Downloads access: bash in launchd GUI domain lacks TCC permission for
# ~/Downloads. osascript (Finder Automation) is used for file listing
# instead — it goes through Finder's TCC context.

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

# Heartbeat
printf 'ts=%s\nosascript_test=%s\n' \
  "$(date '+%Y-%m-%d %H:%M:%S')" \
  "$(osascript -e 'tell application "Finder" to return name of desktop' 2>&1)" \
  > "$STATE_DIR/last_scan"

# List ScheduleAtAGlance xlsx files via osascript (Finder Automation) because
# bash in a launchd GUI domain agent lacks TCC permission to read ~/Downloads.
# If osascript fails (permission not granted), output is empty and we skip silently.
xlsx_paths=$(osascript 2>/dev/null << 'OSASCRIPT_EOF'
tell application "Finder"
    set dlFolder to (path to downloads folder) as alias
    set xlFiles to every file in dlFolder whose name starts with "ScheduleAtAGlance" and name ends with ".xlsx"
    set pathList to ""
    repeat with f in xlFiles
        set pathList to pathList & POSIX path of (f as alias) & linefeed
    end repeat
    return pathList
end tell
OSASCRIPT_EOF
)

processed=0
while IFS= read -r file; do
  [[ -n "$file" ]] || continue
  [[ -f "$file" ]] || continue

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
done <<< "$xlsx_paths"

[[ $processed -gt 0 ]] && log "done ($processed processed)"
