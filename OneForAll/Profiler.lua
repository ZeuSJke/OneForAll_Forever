-- 6.2.17-beta54 (user 25.11.2026 21:09: with the game's script profiling OneForAll used the most CPU of all addons, 3129 ms): /ofa cpu
-- lists which of our files and functions use the time. It works only while the game's profiling is on (/console scriptProfile 1, then
-- /reload); otherwise this file returns at once and costs nothing. It notes every function OneForAll hands to the game (frame scripts,
-- timers, tooltip calls) with its file and line, and asks the game's profiler how much time each one took.
local _, FLT = ...
local on = GetCVar and GetCVar("scriptProfile") == "1" and GetFunctionCPUUsage and debugstack and hooksecurefunc
FLT.Profiler = { on = on and true or false }
if not on then return end

local fns, n = {}, 0 -- function -> "UI/File.lua:123"
local function where()
  -- 6.2.18 (Discord clyd3032 / henoo / gold.k 26.11.): the SetScript hook also runs for the game's own frames (unit frames in
  -- combat); there the stack text is a "secret" string and reading it was an error - such calls are not ours, skip them
  local st = debugstack(3, 8, 0)
  if type(st) ~= "string" or (issecretvalue and issecretvalue(st)) then return end
  for path, line in st:gmatch("OneForAll[/\\]([%w_/\\%-]+%.lua)[^:\n]*:(%d+)") do
    if not path:find("Profiler.lua", 1, true) then return path:gsub("\\", "/") .. ":" .. line end
  end
end
local function add(fn)
  if type(fn) ~= "function" or fns[fn] or n >= 20000 then return end
  local w = where()
  if w then fns[fn] = w; n = n + 1 end
end
-- frame scripts of every widget type (one method table per type)
local done = {}
local function hookType(obj)
  local mt = obj and getmetatable(obj); local idx = mt and mt.__index
  if type(idx) ~= "table" or done[idx] then return end
  done[idx] = true
  if idx.SetScript then pcall(hooksecurefunc, idx, "SetScript", function(_, _, fn) add(fn) end) end
  if idx.HookScript then pcall(hooksecurefunc, idx, "HookScript", function(_, _, fn) add(fn) end) end
end
-- (no EditBox: a new edit box takes the keyboard focus at once - beta55 left the game without keyboard input, user 25.11. 21:19;
-- every helper frame hidden right away)
for _, t in ipairs({ "Frame", "Button", "CheckButton", "ScrollFrame", "Slider", "StatusBar", "Cooldown", "GameTooltip", "Model", "PlayerModel", "MessageFrame", "SimpleHTML" }) do
  pcall(function() local f = CreateFrame(t); f:Hide(); hookType(f) end)
end
pcall(hookType, GameTooltip)
-- timers and tooltip calls
if C_Timer then
  for _, k in ipairs({ "After", "NewTicker", "NewTimer" }) do if C_Timer[k] then pcall(hooksecurefunc, C_Timer, k, function(_, fn) add(fn) end) end end
end
-- (every hook in pcall: the game forbids some; hooksecurefunc itself cannot be hooked: "hooksecurefunc is forbidden for hooking", beta55 - hooks on the game's functions are not noted)
if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall then
  pcall(hooksecurefunc, TooltipDataProcessor, "AddTooltipPostCall", function(_, fn) add(fn) end)
end

-- /ofa cpu: the files and functions with the most time since the last /reload (or /ofa cpu reset)
function FLT.Profiler.Report()
  if UpdateAddOnCPUUsage then UpdateAddOnCPUUsage() end
  local byFile, byFn = {}, {}
  for fn, w in pairs(fns) do
    local ms, calls = GetFunctionCPUUsage(fn, true)
    if ms and ms > 0 then
      local file = w:match("^(.-):%d+$") or w
      byFile[file] = (byFile[file] or 0) + ms
      local e = byFn[w] or { w = w, ms = 0, calls = 0 }; byFn[w] = e
      e.ms, e.calls = e.ms + ms, e.calls + (tonumber(calls) or 0)
    end
  end
  local files, list = {}, {}
  for f, ms in pairs(byFile) do files[#files + 1] = { f = f, ms = ms } end
  for _, e in pairs(byFn) do list[#list + 1] = e end
  table.sort(files, function(a, b) return a.ms > b.ms end)
  table.sort(list, function(a, b) return a.ms > b.ms end)
  local total = GetAddOnCPUUsage and GetAddOnCPUUsage("OneForAll")
  print(string.format("|cffffd100OneForAll CPU|r %s ms (%d functions noted)", total and string.format("%.0f", total) or "?", n))
  for i = 1, math.min(12, #files) do print(string.format("  %6.0f ms  %s", files[i].ms, files[i].f)) end
  print("|cffffd100Functions|r")
  for i = 1, math.min(10, #list) do print(string.format("  %6.0f ms  %5d x  %s", list[i].ms, list[i].calls, list[i].w)) end
end
function FLT.Profiler.Reset() if ResetCPUUsage then ResetCPUUsage() end print("|cffffd100OneForAll CPU|r reset") end
