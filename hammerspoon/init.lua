-- ~/.dotfiles/hammerspoon/init.lua  (symlinked to ~/.hammerspoon/init.lua by installer.sh)
--
-- Managed in github.com/Jython1415/dotfiles. Edit it THERE; `POST /dotfiles/deploy`
-- pulls the change onto Ganymede and the watcher at the bottom auto-reloads Hammerspoon.
-- Do not hand-edit ~/.hammerspoon/init.lua — it is a symlink into this repo.
--
-- Purpose: move ALL standard windows of the frontmost app to a screen half at once,
-- complementing Rectangle (which only ever moves the single focused window).
--
--   ctrl + shift + opt + Left   -> every window of the app -> left half
--   ctrl + shift + opt + Right  -> every window of the app -> right half
--   ctrl + shift + opt + Enter  -> every window of the app -> fill screen (not native fullscreen)
--
-- Modifier rationale: your Rectangle single-window halves are ctrl+opt+arrow, so adding
-- shift namespaces the "all windows" variants without collision. ctrl+opt+cmd+arrow is
-- avoided because Rectangle uses it for previous/next display.

local ax = require("hs.axuielement")

hs.window.animationDuration = 0  -- instant, matching Rectangle (no slide)

-- 50% split of the screen's usable frame (Dock + menu bar excluded).
-- hs.screen:frame() is top-left-origin and AX-aligned, so no coordinate flip is needed
-- (Rectangle has to flip because it computes in Cocoa's bottom-left space).
-- floor(w/2) mirrors Rectangle's `floor(visibleFrameOfScreen.width * 0.5)`.
local function halfFrame(screen, side)
  local f = screen:frame()
  local w = math.floor(f.w / 2)
  if side == "left" then
    return { x = f.x, y = f.y, w = w, h = f.h }
  elseif side == "right" then
    return { x = f.x + (f.w - w), y = f.y, w = f.w - w, h = f.h }
  else  -- "full": fill the usable frame (Rectangle "maximize", not native fullscreen)
    return { x = f.x, y = f.y, w = f.w, h = f.h }
  end
end

-- Apply the half to every standard, non-minimized window of the frontmost app.
-- Target screen = the focused window's screen, so windows scattered across displays
-- get gathered onto the one you're looking at.
local function moveAllAppWindows(side)
  local fw = hs.window.focusedWindow()
  if not fw then return end
  local app = fw:application()
  local frame = halfFrame(fw:screen(), side)

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
hs.hotkey.bind(mods, "left",   function() moveAllAppWindows("left")  end)
hs.hotkey.bind(mods, "right",  function() moveAllAppWindows("right") end)
hs.hotkey.bind(mods, "return", function() moveAllAppWindows("full")  end)  -- fill screen (not native fullscreen)

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
