-- ~/.dotfiles/hammerspoon/init.lua  (symlinked to ~/.hammerspoon/init.lua by installer.sh)
--
-- Managed in github.com/Jython1415/dotfiles. Edit it THERE; `POST /dotfiles/deploy`
-- pulls the change onto Ganymede and the watcher at the bottom auto-reloads Hammerspoon.
-- Do not hand-edit ~/.hammerspoon/init.lua — it is a symlink into this repo.
--
-- Purpose: move ALL standard windows of the frontmost app to a screen region at once,
-- complementing Rectangle (which only ever moves the single focused window).
--
--   Halves / fill:
--     ctrl + shift + opt + Left    -> every window of the app -> left half
--     ctrl + shift + opt + Right   -> every window of the app -> right half
--     ctrl + shift + opt + Enter   -> every window of the app -> fill screen (not native fullscreen)
--   Thirds:
--     ctrl + shift + opt + D       -> every window of the app -> left third
--     ctrl + shift + opt + F       -> every window of the app -> center third
--     ctrl + shift + opt + G       -> every window of the app -> right third
--   Two-thirds:
--     ctrl + shift + opt + E       -> every window of the app -> left two-thirds
--     ctrl + shift + opt + T       -> every window of the app -> right two-thirds
--
-- Modifier rationale: your Rectangle single-window actions (alternate-default set) are
-- ctrl+opt+arrow for halves and ctrl+opt+D/F/G/E/T for the thirds/two-thirds. Adding
-- shift namespaces the "all windows" variants 1:1 over the matching Rectangle key,
-- without collision. ctrl+opt+cmd+arrow is avoided (Rectangle = previous/next display)
-- and ctrl+opt+shift+Up is avoided (Rectangle = maximizeHeight). The letters D/F/G/E/T
-- are free at the ctrl+opt+shift layer (your customized sixths/larger/smaller/almostMax
-- live on other keys).

local ax = require("hs.axuielement")

hs.window.animationDuration = 0  -- instant, matching Rectangle (no slide)

-- Compute the target rect (within the screen's usable frame) for a named region.
-- Mirrors Rectangle's own integer math so the all-windows result lands pixel-for-pixel
-- on Rectangle's single-window action: halves floor(w/2); thirds floor(w/3);
-- two-thirds floor(w*2/3); right-anchored regions pin to maxX exactly as Rectangle does
-- (origin.x = minX + w - width). center-third reproduces Rectangle's own quirk of a
-- floored origin with an unfloored width (visibleFrame.width / 3).
-- hs.screen:frame() is the top-left-origin usable frame (Dock + menu bar excluded) and
-- AX-aligned, so no Cocoa coordinate flip is needed (Rectangle flips; we don't have to).
local function regionFrame(screen, region)
  local f = screen:frame()
  local half     = math.floor(f.w / 2)
  local third    = math.floor(f.w / 3)
  local twoThird = math.floor(f.w * 2 / 3)

  if region == "left" then
    return { x = f.x, y = f.y, w = half, h = f.h }
  elseif region == "right" then
    return { x = f.x + (f.w - half), y = f.y, w = f.w - half, h = f.h }
  elseif region == "left-third" then
    return { x = f.x, y = f.y, w = third, h = f.h }
  elseif region == "center-third" then
    return { x = f.x + third, y = f.y, w = f.w / 3, h = f.h }
  elseif region == "right-third" then
    return { x = f.x + (f.w - third), y = f.y, w = third, h = f.h }
  elseif region == "left-two-thirds" then
    return { x = f.x, y = f.y, w = twoThird, h = f.h }
  elseif region == "right-two-thirds" then
    return { x = f.x + (f.w - twoThird), y = f.y, w = twoThird, h = f.h }
  else  -- "full": fill the usable frame (Rectangle "maximize", not native fullscreen)
    return { x = f.x, y = f.y, w = f.w, h = f.h }
  end
end

-- Apply the region to every standard, non-minimized window of the frontmost app.
-- Target screen = the focused window's screen, so windows scattered across displays
-- get gathered onto the one you're looking at.
local function moveAllAppWindows(region)
  local fw = hs.window.focusedWindow()
  if not fw then return end
  local app = fw:application()
  local frame = regionFrame(fw:screen(), region)

  -- Chrome / Electron apps silently reject AX geometry changes unless
  -- AXEnhancedUserInterface is off. Toggle it once around the batch, then restore
  -- (this is exactly what Rectangle does per move).
  local appAX = ax.applicationElement(app)
  local hadEnhanced = appAX and appAX:attributeValue("AXEnhancedUserInterface")
  if hadEnhanced then appAX:setAttributeValue("AXEnhancedUserInterface", false) end

  for _, w in ipairs(app:allWindows()) do
    if w:isStandard() and not w:isMinimized() then
      w:setFrame(frame)
    end
  end

  if hadEnhanced then appAX:setAttributeValue("AXEnhancedUserInterface", true) end
end

local mods = { "ctrl", "shift", "alt" }  -- alt == option
-- halves + fill
hs.hotkey.bind(mods, "left",   function() moveAllAppWindows("left")  end)
hs.hotkey.bind(mods, "right",  function() moveAllAppWindows("right") end)
hs.hotkey.bind(mods, "return", function() moveAllAppWindows("full")  end)  -- fill screen (not native fullscreen)
-- thirds (mirror Rectangle ctrl+opt+D/F/G)
hs.hotkey.bind(mods, "d", function() moveAllAppWindows("left-third")   end)
hs.hotkey.bind(mods, "f", function() moveAllAppWindows("center-third") end)
hs.hotkey.bind(mods, "g", function() moveAllAppWindows("right-third")  end)
-- two-thirds (mirror Rectangle ctrl+opt+E/T)
hs.hotkey.bind(mods, "e", function() moveAllAppWindows("left-two-thirds")  end)
hs.hotkey.bind(mods, "t", function() moveAllAppWindows("right-two-thirds") end)

-- Auto-reload when this file changes. `git pull` rewrites the real file in
-- ~/.dotfiles/hammerspoon, so watch that directory (the symlink in ~/.hammerspoon
-- itself does not change, only its target's contents). Refs kept on _G so they
-- survive the reload that they trigger.
local home = os.getenv("HOME")
_G.__hsConfigWatchers = _G.__hsConfigWatchers or {}
for _, w in ipairs(_G.__hsConfigWatchers) do pcall(function() w:stop() end) end
_G.__hsConfigWatchers = {}
for _, dir in ipairs({ home .. "/.dotfiles/hammerspoon", hs.configdir }) do
  local watcher = hs.pathwatcher.new(dir, function() hs.reload() end)
  if watcher then watcher:start(); table.insert(_G.__hsConfigWatchers, watcher) end
end

hs.alert.show("Hammerspoon: all-windows config loaded")
