-- ~/.dotfiles/hammerspoon/dim.lua -- software dimming for external monitors (overnight).
--
-- Required from init.lua. Managed in github.com/Jython1415/dotfiles; deployed by
-- `POST /dotfiles/deploy`, which the init.lua path watcher turns into a config reload.
--
-- What it does: scales the gamma (transfer) table of every NON-built-in screen so its white
-- becomes `level`% of full output: screen:setGamma({r=k,g=k,b=k}, {r=0,g=0,b=0}), k = level/100.
-- The monitor's own backlight is unchanged, so blacks still glow; this only makes what macOS
-- sends the monitor darker. The table is applied to gamma-encoded pixel values, so perceived
-- brightness falls faster than the number: 15 is far darker than "15% of the brightness slider".
-- The built-in display is never touched.
--
-- Control (all from the Alfred workflow com.joshuashew.claude.dim, keyword `dim`):
--   open -g "hammerspoon://dim?action=on&level=15"     dim every external screen (level 1-100)
--   open -g "hammerspoon://dim?action=off"             restore (hs.screen.restoreGamma)
--   action=toggle | status | probe                     status/probe change nothing on screen
--   action=config&restore_at=07:00|off                 morning auto-restore time (hs.settings)
--   optional on every call: until=HH:MM|off (this dim only), via=<who>, req=<id echoed back>
--
-- State: hs.settings key "claude_dim.state" = {dimmed, level, until} survives config reloads and
-- restarts. It is re-applied on: config load, hs.screen.watcher, wake/unlock (hs.caffeinate
-- .watcher), and a backstop timer every BACKSTOP_S seconds; `until` (epoch, 0 = none) is checked
-- against the wall clock on each of those, so a missed timer during sleep still restores.
-- Why re-apply at all: macOS resets gamma tables on display sleep/wake and reconnection, and
-- Hammerspoon itself restores every gamma table when its Lua state is torn down (screens_gc in
-- extensions/screen/libscreen.m), so every config reload un-dims for a moment.
--
-- Files: one JSON line per action/event in ~/Library/Logs/claude-dim/dim.jsonl; the current state
-- for the Alfred filter in ~/Library/Caches/com.joshuashew.claude.dim/state (key=value lines) and
-- state.json.
--
-- Built-in detection: Hammerspoon exposes no built-in flag (hs.screen:getInfo() reads
-- IODisplayCreateInfoDictionary via the deprecated CGDisplayIOServicePort, which has no such key
-- and is often nil on Apple silicon). So a screen is built-in when its name (NSScreen
-- localizedName) starts with "Built-in" (macOS 10.15+: "Built-in Retina Display", "Built-in
-- Liquid Retina Display") or is "Color LCD" (older macOS), the same pattern hs.screen's own docs
-- use ('Built%-in'). An unnamed screen is treated as built-in, so it is never dimmed (fail closed).
-- `action=probe` logs every screen's name, id, uuid and classification so this can be checked.
--
-- No globals: everything lives in this module's table (package.loaded.dim), per the hs.ipc
-- shared-state rule in claude-workspace `hammerspoon-ops`.

local M = {}
M.VERSION = "1.0.0"

local HOME = os.getenv("HOME") or ""
M.LOGDIR = HOME .. "/Library/Logs/claude-dim"
M.LOGFILE = M.LOGDIR .. "/dim.jsonl"
M.STATEDIR = HOME .. "/Library/Caches/com.joshuashew.claude.dim"
M.SETTINGS_KEY = "claude_dim.state"
M.RESTORE_KEY = "dim_restore_at"
M.SEQ_KEY = "claude_dim.seq"
M.DEFAULT_LEVEL = 15
M.DEFAULT_RESTORE = "07:00"
M.BACKSTOP_S = 180
M.LOG_MAX_BYTES = 2 * 1024 * 1024

M.now = os.time  -- test seam

-- ---------------------------------------------------------------------------------------------
-- pure helpers

function M.clampLevel(v)
  local n = tonumber(v)
  if not n or n ~= n then return nil end
  n = math.floor(n + 0.5)
  if n < 1 or n > 100 then return nil end
  return n
end

-- "7:00", "07:00", "7", "off" -> "07:00" / "off"; nil when not understood
function M.parseClock(s)
  if s == nil then return nil end
  s = tostring(s):lower():gsub("^%s+", ""):gsub("%s+$", "")
  if s == "off" or s == "none" or s == "never" then return "off" end
  local h, m = s:match("^(%d%d?):(%d%d)$")
  if not h then h = s:match("^(%d%d?)$"); m = "0" end
  h, m = tonumber(h), tonumber(m)
  if not h or h > 23 or m > 59 then return nil end
  return string.format("%02d:%02d", h, m)
end

-- next local time HH:MM strictly later than now (+60 s), as epoch; 0 for "off"
function M.nextAt(hhmm, now)
  if hhmm == "off" or hhmm == nil then return 0 end
  local h, m = hhmm:match("^(%d%d):(%d%d)$")
  local t = os.date("*t", now)
  t.hour, t.min, t.sec = tonumber(h), tonumber(m), 0
  t.isdst = nil
  local e = os.time(t)
  if e <= now + 60 then
    t.day = t.day + 1
    e = os.time(t)
  end
  return e
end

function M.isBuiltIn(name)
  if name == nil or name == "" then return true, "unnamed" end
  if name:match("^Built%-in") then return true, "name:Built-in" end
  if name == "Color LCD" then return true, "name:Color LCD" end
  return false, "name"
end

-- ---------------------------------------------------------------------------------------------
-- settings / state

function M.restoreAt()
  local v = M.parseClock(hs.settings.get(M.RESTORE_KEY))
  return v or M.DEFAULT_RESTORE
end

function M.loadState()
  local s = hs.settings.get(M.SETTINGS_KEY)
  if type(s) ~= "table" then s = {} end
  return { dimmed = s.dimmed == true, level = M.clampLevel(s.level) or M.DEFAULT_LEVEL,
           ["until"] = tonumber(s["until"]) or 0 }
end

function M.saveState(st)
  hs.settings.set(M.SETTINGS_KEY, { dimmed = st.dimmed == true, level = st.level, ["until"] = st["until"] or 0 })
end

local function nextSeq()
  local n = (tonumber(hs.settings.get(M.SEQ_KEY)) or 0) + 1
  hs.settings.set(M.SEQ_KEY, n)
  return n
end

-- ---------------------------------------------------------------------------------------------
-- screens

local function white(scr)
  local ok, g = pcall(function() return scr:getGamma() end)
  if not ok or type(g) ~= "table" or type(g.whitepoint) ~= "table" then return nil end
  return g.whitepoint.red
end

local function round3(x) if x == nil then return nil end return math.floor(x * 1000 + 0.5) / 1000 end

function M.screens()
  local out = {}
  for _, scr in ipairs(hs.screen.allScreens() or {}) do
    local name = scr:name()
    local b, why = M.isBuiltIn(name)
    out[#out + 1] = { scr = scr, name = name or "", id = scr:id(), builtIn = b, builtInReason = why }
  end
  return out
end

local function externals()
  local out = {}
  for _, s in ipairs(M.screens()) do if not s.builtIn then out[#out + 1] = s end end
  return out
end

-- true when the screen's current white differs from the target enough to (re)apply
local function needsApply(w, k)
  if w == nil then return true end
  return math.abs(w - k) > math.max(0.02, 0.1 * k)
end

-- apply level to every external screen; returns per-screen results and how many changed
function M.apply(level)
  local k = level / 100
  local res, changed = {}, 0
  for _, s in ipairs(externals()) do
    local before = white(s.scr)
    local applied, ok = false, true
    if needsApply(before, k) then
      applied = true
      local pok, r = pcall(function()
        return s.scr:setGamma({ red = k, green = k, blue = k }, { red = 0, green = 0, blue = 0 })
      end)
      ok = pok and r ~= false
      if applied and ok then changed = changed + 1 end
    end
    local after = white(s.scr)
    local entry = { name = s.name, id = s.id, applied = applied, ok = ok,
                    white_before = round3(before), white_after = round3(after) }
    -- the table is built from the gamma Hammerspoon captured at load; if that capture happened
    -- while the screen was still dark, white ends up near k*k. Say so rather than hide it.
    if after ~= nil and after < k * 0.8 - 0.01 then entry.warn = "below_expected" end
    res[#res + 1] = entry
  end
  return res, changed
end

function M.restore()
  pcall(hs.screen.restoreGamma)
end

-- ---------------------------------------------------------------------------------------------
-- output: log line + state files

local function ensureDir(d) if not hs.fs.attributes(d) then hs.fs.mkdir(d) end end

local function encode(t)
  local ok, s = pcall(hs.json.encode, t)
  if ok and s then return s end
  return '{"encode_error":true}'
end

function M.log(t)
  t.ts = os.date("%Y-%m-%dT%H:%M:%S%z", M.now())
  t.v = M.VERSION
  pcall(function()
    ensureDir(M.LOGDIR)
    local size = hs.fs.attributes(M.LOGFILE, "size")
    if size and size > M.LOG_MAX_BYTES then os.rename(M.LOGFILE, M.LOGFILE .. ".1") end
    local f = io.open(M.LOGFILE, "a")
    if f then f:write(encode(t), "\n"); f:close() end
  end)
end

local function writeAtomic(path, text)
  local tmp = path .. ".tmp"
  local f = io.open(tmp, "w")
  if not f then return false end
  f:write(text); f:close()
  return os.rename(tmp, path)
end

local function oneLine(s) return (tostring(s or ""):gsub("[\r\n]", " ")) end

-- last: {action, ok, msg, req}
function M.writeState(last)
  local st = M.loadState()
  local ext, dimmedCount = externals(), 0
  local k = st.level / 100
  local list = {}
  for _, s in ipairs(ext) do
    local w = white(s.scr)
    local isDim = w ~= nil and not needsApply(w, k)
    if isDim then dimmedCount = dimmedCount + 1 end
    list[#list + 1] = { name = s.name, id = s.id, white = round3(w), dimmed = isDim }
  end
  local untilText = ""
  if st.dimmed and st["until"] > 0 then untilText = os.date("%H:%M", st["until"]) end
  local seq = nextSeq()
  last = last or {}
  local kv = {
    "seq=" .. seq, "ts=" .. M.now(), "version=" .. M.VERSION,
    "dimmed=" .. (st.dimmed and 1 or 0), "level=" .. st.level,
    "until=" .. st["until"], "until_text=" .. untilText, "restore_at=" .. M.restoreAt(),
    "externals=" .. #ext, "dimmed_screens=" .. dimmedCount,
    "last_action=" .. oneLine(last.action), "last_ok=" .. ((last.ok == false) and 0 or 1),
    "last_msg=" .. oneLine(last.msg), "last_req=" .. oneLine(last.req),
  }
  pcall(function()
    ensureDir(M.STATEDIR)
    writeAtomic(M.STATEDIR .. "/state", table.concat(kv, "\n") .. "\n")
    writeAtomic(M.STATEDIR .. "/state.json", encode({
      seq = seq, ts = M.now(), version = M.VERSION, dimmed = st.dimmed, level = st.level,
      ["until"] = st["until"], restore_at = M.restoreAt(), externals = list,
      last = { action = last.action, ok = last.ok ~= false, msg = last.msg, req = last.req },
    }) .. "\n")
  end)
  return seq, #ext, dimmedCount
end

-- ---------------------------------------------------------------------------------------------
-- actions

local restoreTimer = nil
local function armRestoreTimer(st)
  if restoreTimer then restoreTimer:stop(); restoreTimer = nil end
  if not (st.dimmed and st["until"] > 0) then return end
  local wait = st["until"] - M.now()
  if wait < 1 then wait = 1 end
  restoreTimer = hs.timer.doAfter(wait, function() M.reconcile("restore_timer") end)
end

local function screenSummary()
  local out = {}
  for _, s in ipairs(M.screens()) do
    out[#out + 1] = { name = s.name, id = s.id, builtIn = s.builtIn, white = round3(white(s.scr)) }
  end
  return out
end

function M.doOn(level, untilSpec, via, req, action)
  local now = M.now()
  local st = M.loadState()
  level = level or st.level or M.DEFAULT_LEVEL
  local at = untilSpec or M.restoreAt()
  st.dimmed, st.level, st["until"] = true, level, M.nextAt(at, now)
  M.saveState(st)
  local res, changed = M.apply(level)
  armRestoreTimer(st)
  local msg
  if #res == 0 then
    msg = "No external monitor connected; it will be dimmed when one connects"
  else
    msg = string.format("Dimmed %d external screen%s to %d%%", #res, #res == 1 and "" or "s", level)
  end
  if st["until"] > 0 then msg = msg .. ", restores at " .. os.date("%H:%M", st["until"]) end
  local ok = true
  for _, r in ipairs(res) do if not r.ok then ok = false end end
  if not ok then msg = "Could not set gamma on every external screen (see dim.jsonl)" end
  M.log({ event = "action", action = action or "on", via = via, req = req, level = level,
          ["until"] = st["until"], ok = ok, msg = msg, changed = changed, screens = res })
  M.writeState({ action = action or "on", ok = ok, msg = msg, req = req })
  return ok, msg
end

function M.doOff(via, req, event, action)
  local st = M.loadState()
  local was = st.dimmed
  st.dimmed, st["until"] = false, 0
  M.saveState(st)
  M.restore()
  armRestoreTimer(st)
  local msg = was and "Restored normal brightness" or "Restored normal brightness (was not dimmed)"
  M.log({ event = event or "action", action = action or "off", via = via, req = req, ok = true,
          was_dimmed = was, msg = msg, screens = screenSummary() })
  M.writeState({ action = action or "off", ok = true, msg = msg, req = req })
  return true, msg
end

function M.probeScreens()
  local out = {}
  for _, s in ipairs(M.screens()) do
    local scr = s.scr
    local e = { name = s.name, id = s.id, builtIn = s.builtIn, builtInReason = s.builtInReason }
    pcall(function() e.uuid = scr:getUUID() end)
    pcall(function()
      local g = scr:getGamma()
      if g then
        e.whitepoint = { round3(g.whitepoint.red), round3(g.whitepoint.green), round3(g.whitepoint.blue) }
        e.blackpoint = { round3(g.blackpoint.red), round3(g.blackpoint.green), round3(g.blackpoint.blue) }
      end
    end)
    pcall(function() local f = scr:fullFrame(); e.fullFrame = { f.x, f.y, f.w, f.h } end)
    pcall(function()
      local m = scr:currentMode()
      if m then e.mode = { w = m.w, h = m.h, scale = m.scale, freq = m.freq } end
    end)
    pcall(function()
      local info = scr:getInfo()
      if type(info) == "table" then
        local keys = {}
        for k2, v in pairs(info) do
          if type(v) == "string" or type(v) == "number" or type(v) == "boolean" then keys[#keys + 1] = tostring(k2) end
        end
        table.sort(keys)
        e.info_keys = keys
        e.info_product = info.DisplayProductName
      else
        e.info_keys = "nil"
      end
    end)
    out[#out + 1] = e
  end
  return out
end

function M.handle(params)
  params = params or {}
  local action = (params.action or "status"):lower()
  local via, req = params.via, params.req
  if action == "toggle" then action = M.loadState().dimmed and "off" or "on" end
  if action == "on" then
    local level = M.loadState().level
    if params.level ~= nil then
      level = M.clampLevel(params.level)
      if not level then
        local msg = "Level must be a number from 1 to 100"
        M.log({ event = "action", action = "on", via = via, req = req, ok = false, msg = msg, level_arg = params.level })
        M.writeState({ action = "on", ok = false, msg = msg, req = req })
        return false, msg
      end
    end
    local untilSpec = nil
    if params["until"] ~= nil then
      untilSpec = M.parseClock(params["until"])
      if not untilSpec then
        local msg = "until must be HH:MM or off"
        M.log({ event = "action", action = "on", via = via, req = req, ok = false, msg = msg })
        M.writeState({ action = "on", ok = false, msg = msg, req = req })
        return false, msg
      end
    end
    return M.doOn(level, untilSpec, via, req, "on")
  elseif action == "off" then
    return M.doOff(via, req)
  elseif action == "config" then
    local v = M.parseClock(params.restore_at)
    local ok, msg = v ~= nil, nil
    if ok then hs.settings.set(M.RESTORE_KEY, v); msg = "Morning restore set to " .. v
    else msg = "restore_at must be HH:MM or off" end
    M.log({ event = "action", action = "config", via = via, req = req, ok = ok, msg = msg })
    M.writeState({ action = "config", ok = ok, msg = msg, req = req })
    return ok, msg
  elseif action == "status" or action == "probe" then
    -- read-only: nothing here changes any screen or the saved state
    local st = M.loadState()
    local entry = { event = "action", action = action, via = via, req = req, ok = true,
                    dimmed = st.dimmed, level = st.level, ["until"] = st["until"], restore_at = M.restoreAt() }
    if action == "probe" then entry.screens = M.probeScreens() else entry.screens = screenSummary() end
    local nExt = 0
    for _, s in ipairs(entry.screens) do if not s.builtIn then nExt = nExt + 1 end end
    entry.msg = string.format("%s; %d external screen%s", st.dimmed and ("dimmed to " .. st.level .. "%") or "not dimmed",
                              nExt, nExt == 1 and "" or "s")
    M.log(entry)
    M.writeState({ action = action, ok = true, msg = entry.msg, req = req })
    return true, entry.msg
  end
  local msg = "Unknown action " .. tostring(params.action)
  M.log({ event = "action", action = tostring(params.action), via = via, req = req, ok = false, msg = msg })
  M.writeState({ action = tostring(params.action), ok = false, msg = msg, req = req })
  return false, msg
end

-- re-apply (or expire) the saved state; logs only when something changed
function M.reconcile(why)
  local st = M.loadState()
  if not st.dimmed then return end
  if st["until"] > 0 and M.now() >= st["until"] then
    M.doOff("auto", nil, "auto_restore", "auto_restore")
    return
  end
  local res, changed = M.apply(st.level)
  if changed > 0 or why == "load" then
    M.log({ event = "reapply", why = why, level = st.level, ["until"] = st["until"], changed = changed, screens = res })
  end
  if changed > 0 or why == "screens_changed" or why == "load" then M.writeState({ action = "reapply:" .. why, ok = true, msg = "" }) end
  armRestoreTimer(st)
end

-- ---------------------------------------------------------------------------------------------
-- wiring

local watchers = {}

function M.start()
  local W = hs.caffeinate.watcher
  local wakeEvents = { [W.screensDidWake] = "screensDidWake", [W.systemDidWake] = "systemDidWake",
                       [W.screensDidUnlock] = "screensDidUnlock", [W.sessionDidBecomeActive] = "sessionDidBecomeActive" }
  local function later(why, ...)
    for _, d in ipairs({ ... }) do hs.timer.doAfter(d, function() M.reconcile(why) end) end
  end
  watchers.screen = hs.screen.watcher.new(function() later("screens_changed", 2, 6) end)
  watchers.screen:start()
  watchers.power = W.new(function(ev) if wakeEvents[ev] then later(wakeEvents[ev], 1.5, 5) end end)
  watchers.power:start()
  watchers.backstop = hs.timer.doEvery(M.BACKSTOP_S, function() M.reconcile("backstop") end)
  hs.urlevent.bind("dim", function(_, params)
    local ok, err = pcall(M.handle, params)
    if not ok then M.log({ event = "error", where = "handle", msg = tostring(err) }) end
  end)
  M.watchers = watchers
  local st = M.loadState()
  M.log({ event = "load", dimmed = st.dimmed, level = st.level, ["until"] = st["until"],
          restore_at = M.restoreAt(), screens = screenSummary() })
  M.reconcile("load")
  if not st.dimmed then M.writeState({ action = "load", ok = true, msg = "" }) end
  return M
end

return M
