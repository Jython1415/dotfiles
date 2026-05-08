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
    if git -C "$DOTFILES" fetch origin main --quiet 2>/dev/null; then
        # Count commits in origin/main not yet in HEAD. Using rev-list rather
        # than comparing SHAs directly handles merge-pull (where HEAD is a merge
        # commit with a different SHA than origin/main but already contains it).
        BEHIND=$(git -C "$DOTFILES" rev-list HEAD..origin/main --count 2>/dev/null || echo 0)
        if [ "${BEHIND:-0}" -gt 0 ]; then
            log "$BEHIND new commit(s) on origin/main, updating"
            # Reset working tree before pull — installer's chmod +x sets the execute
            # bit on this script (100644 → 100755). With core.filemode=true (macOS
            # default), git treats the mode change as a local modification and blocks
            # fast-forward pulls. Reset clears this before every pull.
            git -C "$DOTFILES" reset --hard HEAD 2>/dev/null || true
            if git -C "$DOTFILES" pull origin main 2>&1; then
                # XLSX_UPDATER_RUN=1 tells the installer to skip auto-updater
                # management (avoids killing itself mid-install via the trap).
                XLSX_UPDATER_RUN=1 bash "$DOTFILES/launchd/install-xlsx-clip-watcher.sh" 2>&1
                log "update complete — exiting so cron restarts with new code"
                exit 0
            else
                log "pull failed — will retry next cycle"
            fi
        fi
    else
        log "git fetch failed (network or auth), skipping"
    fi
    sleep "$INTERVAL"
done
