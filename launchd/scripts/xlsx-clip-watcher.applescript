-- xlsx-clip-watcher Folder Action
-- Attached to ~/Downloads. Fires when any file is added to the folder.
--
-- Filters for ScheduleAtAGlance*.xlsx files and hands each one to
-- xlsx-clip-watcher-process.sh, which handles:
--   • inode-based dedup (skips files already processed, including those
--     restored from Trash — inode is preserved across same-volume moves)
--   • xlcat clipboard import
--   • Finder trash
--   • logging to ~/.local/state/xlsx-clip-watcher/watcher.log
--
-- "Restored from Trash" behaviour: the user can move a file back from
-- Trash to Downloads freely. The Folder Action will fire, but the process
-- script's inode check will recognise it as previously processed and skip it.

on adding folder items to thisFolder after receiving theFiles
    set processorScript to (POSIX path of (path to home folder)) & ".dotfiles/launchd/scripts/xlsx-clip-watcher-process.sh"

    repeat with theFile in theFiles
        try
            set filePosix to POSIX path of theFile

            -- Extract filename from path
            set AppleScript's text item delimiters to "/"
            set fileName to last text item of filePosix
            set AppleScript's text item delimiters to ""

            -- Filter: only ScheduleAtAGlance*.xlsx
            if fileName starts with "ScheduleAtAGlance" and fileName ends with ".xlsx" then
                -- Explicit PATH so xlcat, uv, pbcopy are all found
                set shellPath to "/Users/" & (do shell script "whoami") & "/.dotfiles/bin:/Users/" & (do shell script "whoami") & "/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
                do shell script "PATH=" & quoted form of shellPath & " " & quoted form of processorScript & " " & quoted form of filePosix
            end if
        on error errMsg
            -- Log errors but don't surface dialogs
            try
                set stateDir to (POSIX path of (path to home folder)) & ".local/state/xlsx-clip-watcher"
                do shell script "mkdir -p " & quoted form of stateDir & " && printf '[xlsx-clip-watcher] %s ERROR in Folder Action: %s\\n' \"$(date '+%Y-%m-%d %H:%M:%S')\" " & quoted form of errMsg & " >> " & quoted form of (stateDir & "/watcher.log")
            end try
        end try
    end repeat
end adding folder items to
