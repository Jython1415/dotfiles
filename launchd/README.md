# xlsx-clip-watcher

Watches `~/Downloads` for `ScheduleAtAGlance*.xlsx` files, imports them to the
clipboard via `xlcat`, then moves them to Trash. Used for the Mathnasium
pre-shift briefing workflow.

## Design (current, as of 2026-05-20)

**macOS Folder Action** on `~/Downloads`. Event-driven — fires exactly when a
file lands in the folder. Runs under `com.apple.FolderActionsAgent`, which has
Downloads TCC access natively.

```
file lands in ~/Downloads
    → FolderActionsAgent fires Folder Action
    → xlsx-clip-watcher.scpt (compiled AppleScript handler)
    → xlsx-clip-watcher-process.sh (bash: inode dedup, xlcat, pbcopy, trash)
    → ~/.local/state/xlsx-clip-watcher/watcher.log
```

## Files

| File | Purpose |
|------|---------|
| `launchd/scripts/xlsx-clip-watcher.applescript` | Folder Action handler source (compiled to `.scpt` by install script) |
| `launchd/scripts/xlsx-clip-watcher-process.sh` | Processing logic: inode dedup, xlcat → clipboard, Finder trash, logging |
| `launchd/install-xlsx-clip-watcher.sh` | Idempotent install script — called by `/dotfiles/deploy` on the credential proxy |

Compiled script location: `~/Library/Scripts/Folder Action Scripts/xlsx-clip-watcher.scpt`

State directory: `~/.local/state/xlsx-clip-watcher/`
- `watcher.log` — processing log
- `seen.txt` — processed file inodes (`dev:inode` pairs, one per line)

## Deploy

The credential proxy has a `/dotfiles/deploy` endpoint (admin-scoped session)
that runs `git pull && bash ~/.dotfiles/launchd/install-xlsx-clip-watcher.sh`.
This is fully autonomous — no Mac commands needed.

```python
requests.post('https://proxy.joshuashew.com/dotfiles/deploy',
    headers={'X-Session-Id': admin_session_id})
```

## Restored-from-Trash behaviour

When a file is processed, its `dev:inode` is written to `seen.txt`. APFS
preserves inodes across moves within the same volume, so if the user moves a
file from Trash back to Downloads, the Folder Action fires but the inode check
skips it. The file stays in Downloads undisturbed.

## Critical implementation notes (learned the hard way)

### AppleScript Folder Action lookup — filter reference required

`folder action "/path"` does a **NAME** lookup and returns error -1728 on
modern macOS. The path is not the name. Always use a filter reference:

```applescript
-- WRONG (name lookup, returns -1728)
set fa to folder action "/Users/Joshua/Downloads"

-- CORRECT (filter reference, works)
set fa to first folder action whose path is "/Users/Joshua/Downloads"
```

### FolderActionsAgent is ephemeral on macOS 14

The agent does not auto-start at login. It launches on-demand when a file lands
in a watched folder. After install/reconfiguration, run:

```bash
launchctl stop com.apple.FolderActionsAgent 2>/dev/null; sleep 1
launchctl start com.apple.FolderActionsAgent
```

The install script does this automatically.

### TCC and bash in launchd GUI agents

Bash launched as a launchd GUI-domain agent cannot read `~/Downloads` due to
TCC restrictions (`ls ~/Downloads` → "Operation not permitted"). Earlier designs
tried to work around this with `osascript` file enumeration and polling, both
of which are now unnecessary — the Folder Action runs in FolderActionsAgent's
context which has Downloads access.

### System Events Folder Action registration

- Use POSIX paths (no trailing slash) — macOS stores them as `/Users/Joshua/Downloads`
- The `(path to downloads folder) as text` HFS path (`Macintosh HD:Users:Joshua:Downloads:`) does NOT match the stored path for lookup
- Registration is idempotent: catch error -48 ("already exists") and use filter reference to get the existing action

## Design history

| Date | Design | Why changed |
|------|--------|-------------|
| 2026-05-09 | `fswatch` daemon + crontab `@reboot` watchdog | Worked; process started from Terminal so inherited Downloads TCC |
| 2026-05-14 | launchd `WatchPaths` one-shot | Cleaner than crontab; but WatchPaths fires on `.crdownload` temp files, not the final rename → "done (0 processed)" every time |
| 2026-05-20 (morning) | launchd `StartInterval:5` + osascript enumeration | Polling fixed the WatchPaths race; osascript Finder Automation bypassed TCC for enumeration; but janky |
| 2026-05-20 (afternoon) | **macOS Folder Action (current)** | Event-driven, correct TCC context natively, no polling |
