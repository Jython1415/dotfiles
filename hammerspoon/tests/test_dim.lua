-- Off-host tests for hammerspoon/dim.lua with a fake `hs`. Run: hammerspoon/tests/run.sh
-- (needs lua5.4 or lua on PATH, or LUA=<binary>). The runner sets HOME to a temp dir and TZ.

local failures, passed = 0, 0
local function check(cond, what)
  if cond then passed = passed + 1 else failures = failures + 1; io.stderr:write("FAIL: " .. what .. "\n") end
end
local function approx(a, b) return a ~= nil and b ~= nil and math.abs(a - b) < 1e-6 end

local HOME = os.getenv("HOME")
assert(HOME and HOME:match("dimtest"), "run through tests/run.sh (HOME must be a temp dir)")

-- ---- fake hs -------------------------------------------------------------------------------
local function jenc(v)
  local t = type(v)
  if t == "nil" then return "null" end
  if t == "boolean" then return tostring(v) end
  if t == "number" then return string.format("%.14g", v) end
  if t == "string" then
    return '"' .. v:gsub('[%c"\\]', function(c) return string.format("\\u%04x", c:byte()) end) .. '"'
  end
  if t == "table" then
    if #v > 0 or next(v) == nil then
      local parts = {}
      for i = 1, #v do parts[i] = jenc(v[i]) end
      return "[" .. table.concat(parts, ",") .. "]"
    end
    local parts = {}
    for k, x in pairs(v) do parts[#parts + 1] = jenc(tostring(k)) .. ":" .. jenc(x) end
    table.sort(parts)
    return "{" .. table.concat(parts, ",") .. "}"
  end
  error("cannot encode " .. t)
end

local calls = { set = 0, restore = 0 }
local function fakeScreen(name, id)
  local s = { _name = name, _id = id, _white = 1.0 }
  function s:name() return self._name end
  function s:id() return self._id end
  function s:getUUID() return "UUID-" .. self._id end
  function s:getGamma()
    return { whitepoint = { red = self._white, green = self._white, blue = self._white },
             blackpoint = { red = 0, green = 0, blue = 0 } }
  end
  function s:setGamma(w, b)
    calls.set = calls.set + 1
    self._white = w.red
    return true
  end
  function s:fullFrame() return { x = 0, y = 0, w = 1920, h = 1080 } end
  function s:currentMode() return { w = 1920, h = 1080, scale = 1, freq = 100 } end
  function s:getInfo() return nil end
  return s
end

local builtin = fakeScreen("Built-in Retina Display", 1)
local ext = fakeScreen("DELL P2419H", 3)
local screens = { builtin, ext }
local store = {}
local timers = {}
local urlHandlers = {}
local screenWatcherFn, powerFn

local function fsattr(p, key)
  local f = io.open(p, "r")
  if not f then return nil end
  local size = f:seek("end"); f:close()
  if key == "size" then return size end
  return { size = size }
end

hs = {
  settings = { get = function(k) return store[k] end, set = function(k, v) store[k] = v end },
  json = { encode = jenc },
  fs = { attributes = fsattr, mkdir = function(d) os.execute("mkdir -p '" .. d .. "'") return true end },
  screen = {
    allScreens = function() return screens end,
    restoreGamma = function()
      calls.restore = calls.restore + 1
      for _, s in ipairs(screens) do s._white = 1.0 end
    end,
    watcher = { new = function(fn) screenWatcherFn = fn; return { start = function() end } end },
  },
  caffeinate = { watcher = { screensDidWake = 10, systemDidWake = 11, screensDidUnlock = 12, sessionDidBecomeActive = 13,
                             screensDidSleep = 14,
                             new = function(fn) powerFn = fn; return { start = function() end } end } },
  timer = {
    doAfter = function(d, fn) local t = { d = d, fn = fn, kind = "after" }; function t:stop() self.stopped = true end
      timers[#timers + 1] = t; return t end,
    doEvery = function(d, fn) local t = { d = d, fn = fn, kind = "every" }; function t:stop() self.stopped = true end
      timers[#timers + 1] = t; return t end,
  },
  urlevent = { bind = function(name, fn) urlHandlers[name] = fn end },
}

local function runAfterTimers()
  local pending = {}
  for i, t in ipairs(timers) do if t.kind == "after" and not t.stopped and not t.fired then pending[#pending + 1] = t end end
  for _, t in ipairs(pending) do t.fired = true; t.fn() end
end

local function readState()
  local f = io.open(HOME .. "/Library/Caches/com.joshuashew.claude.dim/state")
  if not f then return {} end
  local t = {}
  for line in f:lines() do local k, v = line:match("^([^=]+)=(.*)$"); if k then t[k] = v end end
  f:close()
  return t
end

local function logLines()
  local f = io.open(HOME .. "/Library/Logs/claude-dim/dim.jsonl")
  if not f then return {} end
  local out = {}
  for line in f:lines() do out[#out + 1] = line end
  f:close()
  return out
end

local here = arg[0]:match("^(.*)/tests/") or "hammerspoon"
package.path = here .. "/?.lua;" .. package.path

-- 2026-10-19 14:00:00 EDT (runner sets TZ=America/New_York)
local NOW = 1792432800
local function loadModule()
  package.loaded.dim = nil
  local M = require("dim")
  M.now = function() return NOW end
  return M
end

-- ---- pure helpers -------------------------------------------------------------------------
local M = loadModule()
check(M.isBuiltIn("Built-in Retina Display") == true, "built-in retina")
check(M.isBuiltIn("Built-in Liquid Retina Display") == true, "built-in liquid")
check(M.isBuiltIn("Color LCD") == true, "color lcd")
check(M.isBuiltIn(nil) == true and M.isBuiltIn("") == true, "unnamed fails closed")
check(M.isBuiltIn("DELL P2419H") == false, "external")
check(M.isBuiltIn("LG HDR 4K (1)") == false, "external 2")
check(M.clampLevel("15") == 15 and M.clampLevel(1) == 1 and M.clampLevel(100) == 100, "clamp ok")
check(M.clampLevel(0) == nil and M.clampLevel(101) == nil and M.clampLevel("x") == nil, "clamp bad")
check(M.parseClock("7:00") == "07:00" and M.parseClock("07:30") == "07:30" and M.parseClock("7") == "07:00", "clock")
check(M.parseClock("off") == "off" and M.parseClock("25:00") == nil and M.parseClock("7:61") == nil, "clock bad")
check(os.date("%H:%M", NOW) == "14:00", "test clock is 2 PM local")
check(M.nextAt("07:00", NOW) == NOW + 17 * 3600, "2 PM -> 7 AM tomorrow")
check(M.nextAt("07:00", NOW - 11 * 3600) == NOW - 11 * 3600 + 4 * 3600, "3 AM -> 7 AM today")
check(M.nextAt("off", NOW) == 0, "off -> 0")

-- ---- start with nothing saved: no gamma change --------------------------------------------
M.start()
check(urlHandlers.dim ~= nil, "url handler bound")
check(calls.set == 0 and calls.restore == 0, "load when not dimmed touches nothing")
check(readState().dimmed == "0" and readState().externals == "1", "state written at load")
check(#timers == 1 and timers[1].kind == "every" and timers[1].d == M.BACKSTOP_S, "backstop armed")

-- ---- on ------------------------------------------------------------------------------------
urlHandlers.dim("dim", { action = "on", via = "test", req = "r1" })
check(approx(ext._white, 0.15), "external dimmed to default 15")
check(builtin._white == 1.0, "built-in untouched")
local st = readState()
check(st.dimmed == "1" and st.level == "15" and st.last_req == "r1" and st.last_ok == "1", "state after on")
check(st.until_text == "07:00" and tonumber(st["until"]) == NOW + 17 * 3600, "until tomorrow 7")
check(st.dimmed_screens == "1", "dimmed_screens counted")
check(store["claude_dim.state"].dimmed == true and store["claude_dim.state"].level == 15, "settings persisted")

urlHandlers.dim("dim", { action = "on", level = "5", req = "r2" })
check(approx(ext._white, 0.05), "level 5")
urlHandlers.dim("dim", { action = "on", level = "0", req = "r3" })
check(approx(ext._white, 0.05) and readState().last_ok == "0" and readState().last_req == "r3", "level 0 refused")
urlHandlers.dim("dim", { action = "on", level = "30", ["until"] = "off", req = "r4" })
check(approx(ext._white, 0.30) and readState()["until"] == "0", "until=off")

-- ---- status / probe are read-only ---------------------------------------------------------
local before = { set = calls.set, restore = calls.restore, white = ext._white, st = store["claude_dim.state"] }
urlHandlers.dim("dim", { action = "status", req = "s1" })
urlHandlers.dim("dim", { action = "probe", req = "p1" })
check(calls.set == before.set and calls.restore == before.restore and ext._white == before.white, "status/probe change no screen")
check(store["claude_dim.state"] == before.st, "status/probe leave saved state alone")
check(readState().last_req == "p1" and readState().last_action == "probe", "probe answered")
local lines = logLines()
local probeLine = lines[#lines]
check(probeLine:find('"action":"probe"') and probeLine:find('"builtInReason":"name:Built%-in"')
      and probeLine:find('"uuid":"UUID%-3"'), "probe logs screens")

-- ---- reconcile: gamma reset by macOS -> re-applied ----------------------------------------
ext._white = 1.0
powerFn(hs.caffeinate.watcher.screensDidWake)
runAfterTimers()
check(approx(ext._white, 0.30), "re-applied after wake")
powerFn(hs.caffeinate.watcher.screensDidSleep)
check(true, "sleep event ignored without error")
local setsBefore = calls.set
timers[1].fn()  -- backstop with gamma intact: no set
check(calls.set == setsBefore, "backstop idempotent")

-- ---- reload: state survives, re-applied on load --------------------------------------------
urlHandlers.dim("dim", { action = "on", level = "20", req = "r5" })
hs.screen.restoreGamma()  -- what Hammerspoon's screens_gc does on a config reload
timers, urlHandlers = {}, {}
M = loadModule()
M.start()
check(approx(ext._white, 0.20), "re-dimmed after reload")
check(builtin._white == 1.0, "built-in untouched after reload")

-- ---- auto restore when until has passed ----------------------------------------------------
local untilTs = store["claude_dim.state"]["until"]
NOW = untilTs + 5
M.now = function() return NOW end
timers[1].fn()
check(ext._white == 1.0 and store["claude_dim.state"].dimmed == false, "auto restore at morning time")
check(readState().last_action == "auto_restore" and readState().dimmed == "0", "auto restore state")

-- ---- off -----------------------------------------------------------------------------------
NOW = 1792432800
urlHandlers.dim("dim", { action = "on", req = "r6" })
local r0 = calls.restore
urlHandlers.dim("dim", { action = "off", req = "r7" })
check(calls.restore == r0 + 1 and ext._white == 1.0 and readState().dimmed == "0", "off restores")
urlHandlers.dim("dim", { action = "toggle", req = "r8" })
check(approx(ext._white, 0.20), "toggle on uses last level")
urlHandlers.dim("dim", { action = "toggle", req = "r9" })
check(ext._white == 1.0, "toggle off")

-- ---- no external connected, then one connects ---------------------------------------------
screens = { builtin }
urlHandlers.dim("dim", { action = "on", level = "10", req = "r10" })
check(readState().externals == "0" and readState().last_msg:find("No external monitor"), "no external msg")
check(builtin._white == 1.0, "built-in still untouched")
ext._white = 1.0
screens = { builtin, ext }
screenWatcherFn()
runAfterTimers()
check(approx(ext._white, 0.10), "dims a newly connected external")

-- ---- config / unknown ----------------------------------------------------------------------
urlHandlers.dim("dim", { action = "config", restore_at = "6:30", req = "c1" })
check(store.dim_restore_at == "06:30" and readState().restore_at == "06:30", "config restore_at")
urlHandlers.dim("dim", { action = "bogus", req = "u1" })
check(readState().last_ok == "0", "unknown action refused")
urlHandlers.dim("dim", nil)
check(readState().last_action == "status", "no params = status")

-- every log line is one JSON object
for _, l in ipairs(logLines()) do check(l:match("^{.*}$") ~= nil, "log line is an object: " .. l) end

-- no globals leaked except the fake hs
for k in pairs(_G) do
  if not ({ hs = 1 })[k] and type(_G[k]) ~= "function" and type(_G[k]) ~= "table" and k ~= "_VERSION" then
    check(false, "global leaked: " .. k)
  end
end
check(rawget(_G, "dim") == nil and rawget(_G, "M") == nil, "module defines no global")

print(string.format("%d passed, %d failed", passed, failures))
os.exit(failures == 0 and 0 or 1)
