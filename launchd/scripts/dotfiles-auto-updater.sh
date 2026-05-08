#!/usr/bin/env bash
# dotfiles-auto-updater — polls for new dotfiles commits and reinstalls on change.

export PATH="$HOME/.local/bin:$HOME/bin:$HOME/.dotfiles/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"

DOTFILES="$HOME/.dotfiles"
STATE_DIR="$HOME/.local/state/xlsx-clip-watcher"
LOCK_FILE="$STATE_DIR/auto-updater.lock"
INTERVAL=300

mkdir -p "$STATE_DIR"
log() { echo "[dotfiles-auto-updater] $(date '+%Y-%m-%d %H:%M:%S') $*"; }

trap 'kill 0 2>/dev/null; exit 0' SIGTERM SIGINT

exec 9>"$LOCK_FILE"
if ! flock -n 9; then
    log "another instance already running, exiting"
    exit 0
fi

log "starting (PID $$)"

while true; do
    BEFORE=$(git -C "$DOTFILES" rev-parse HEAD 2>/dev/null)
    if git -C "$DOTFILES" fetch origin main --quiet 2>/dev/null; then
        AFTER=$(git -C "$DOTFILES" rev-parse origin/main 2>/dev/null)
        if [ "$BEFORE" != "$AFTER" ]; then
            log "new commits: ${BEFORE:0:8} -> ${AFTER:0:8}, updating"
            git -C "$DOTFILES" pull origin main 2>&1
            bash "$DOTFILES/launchd/install-xlsx-clip-watcher.sh" 2>&1
            log "update complete"
        fi
    else
        log "git fetch failed (network or auth), skipping"
    fi
    sleep "$INTERVAL"
done
