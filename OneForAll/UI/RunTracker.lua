local ADDON, FLT = ...
-- 6.2.14 (user 23.11.2026: "so einen tracker machen wie dungeon journal hat" - the idea only, Dungeon Journal has no licence;
-- own code): every visit of a dungeon or raid is a run - time, bosses, mobs, XP, gold, deaths, loot - kept per character
-- (OneForAllCharDB.runs, newest first, History in Dungeons & Raids). The small tracker window shows the run (QoL "runTracker"):
-- 6.2.17 (user 25.11.2026, mockups "ofa_tracker_package"): a compact list - head with the bosses killed, one row per boss (next boss
-- gold bar, killed ones greyed with their kill time and folded into "N defeated", the rest past RT.MaxVisible in "N more", rares
-- and optional bosses round at the end), foot with time / mob XP / gold. Left-click: target + raid mark dropdown, right-click:
-- loot dropdown, Shift-click: OneForAll on that boss.
-- Lean: outside dungeons only PLAYER_ENTERING_WORLD / ZONE_CHANGED_NEW_AREA; inside a handful of chat / boss events (no combat
-- log): a boss counts on ENCOUNTER_END or its "<name> dies." line, every other "dies." line is a mob. The clock ticks once a
-- second only while the tracker shows an unfinished run.
local UI = FLT.UI
-- the item API of this client lives in C_Item (the global GetItemInfo is gone; user 23.11.: error in History)
local GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local function qualityColor(q)
  local c = q and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
  if c then return c.r, c.g, c.b end
  return 0.6, 0.6, 0.6
end
local L = FLT.L or setmetatable({}, { __index = function(_, k) return k end })
local function N(s) return s end
local RT = {}
FLT.RunTracker = RT

local MAX_RUNS, RESUME = 100, 3600
local W, H = 236, 104
local SUM_H = 20 -- the "N / M defeated" and "N more" lines -- the size of Dungeon Journal's tracker (user 23.11.: "wieder schmaler machen wie dungeon journal")

local function now() return time() end
local repaired
local function runs()
  if type(OneForAllCharDB) ~= "table" then return nil end
  OneForAllCharDB.runs = type(OneForAllCharDB.runs) == "table" and OneForAllCharDB.runs or {}
  -- beta48 also started a clock on runs from before it (their time began again at the next kill, user 25.11. 20:38: 2:16 with
  -- bosses killed at 8:05 and 14:03): those keep their time from t0
  if not repaired then repaired = true; for _, c in ipairs(OneForAllCharDB.runs) do if c.ts and not c.clk then c.ts = nil end end end
  return OneForAllCharDB.runs
end
local function current()
  if RT.testRun then return RT.testRun end -- /ofa tracker test (6.2.14-beta24)
  local r = runs(); local c = r and r[1]; return c and c.open and c or nil
end
local function dungeonByKey(key) for _, d in ipairs(FLT.DUNGEONS or {}) do if d.key == key then return d end end end
RT.Runs, RT.Current, RT.DungeonByKey = runs, current, dungeonByKey

-- the run's length: to its end, or to now while you are in it
-- the clock runs from the first kill, like Dungeon Journal ("From the first trash kill to the last boss kill"; user 25.11.2026 20:25:
-- "gut waere es wenn der timer erst startet nachdem der erste mob tot ist"): c.ts; runs from before 6.2.17-beta48 (no c.clk) from t0
function RT.Duration(c)
  if not c then return 0 end
  local s = c.ts or (not c.clk and c.t0)
  if not s then return 0 end
  local stop = c.t1 or (c.open and RT.active and now()) or c.last or s
  return math.max(0, (stop or 0) - s)
end
function RT.Clock(sec)
  sec = math.floor((sec or 0) + 0.5)
  local h, m, s = math.floor(sec / 3600), math.floor(sec % 3600 / 60), sec % 60
  if h > 0 then return string.format("%d:%02d:%02d", h, m, s) end
  return string.format("%d:%02d", m, s)
end
-- best and average time of the finished runs of a dungeon (all bosses down), without the run `skip`
function RT.Stats(key, skip)
  local best, sum, n = nil, 0, 0
  for _, c in ipairs(runs() or {}) do
    if c ~= skip and c.key == key and c.done and c.t1 then
      local d = c.t1 - (c.ts or c.t0)
      if d > 0 then n = n + 1; sum = sum + d; if not best or d < best then best = d end end
    end
  end
  return best, n > 0 and sum / n or nil, n
end

-- boss names (data, aliases, the client's language, names learnt in game) and NPC IDs -> boss; items only one boss drops -> boss
local names, npcs, onlyDrop = {}, {}, {}
local function lower(s) return type(s) == "string" and s:lower() or "" end
-- the names the game showed for a boss (target / mouseover / nameplate), account wide: a kill then counts under the client's own
-- name too (German, French ... - user 23.11.: Zul'Farrak on a German client)
local function learnedNames()
  if type(OneForAllDB) ~= "table" then return {} end
  OneForAllDB.bossNames = type(OneForAllDB.bossNames) == "table" and OneForAllDB.bossNames or {}
  return OneForAllDB.bossNames
end
local function buildNames(d)
  wipe(names); wipe(npcs); wipe(onlyDrop)
  local known, drops = learnedNames(), {}
  for _, b in ipairs(d and d.bosses or {}) do
    names[lower(b.name)] = b
    for _, a in ipairs(b.aliases or {}) do names[lower(a)] = b end
    if FLT.Name then names[lower(FLT.Name(b.name))] = b end
    if b.npcID then
      npcs[b.npcID] = b
      if type(known[b.npcID]) == "string" then names[lower(known[b.npcID])] = b end
    end
    for _, it in ipairs(b.loot or {}) do
      local id = type(it) == "table" and (it.id or it[1])
      if id then drops[id] = (drops[id] == nil or drops[id] == b) and b or false end
    end
  end
  for id, b in pairs(drops) do if b then onlyDrop[id] = b end end
end
local function byName(d, n) for _, b in ipairs(d and d.bosses or {}) do if b.name == n then return b end end end
function RT.Killed(c, b) return c and c.kills and b and c.kills[b.name] end

-- Forever hides some values inside dungeons ("secret" values): they must not be compared or parsed
local function plain(v) if issecretvalue and issecretvalue(v) then return nil end return v end
-- Creature-0-server-map-zoneUID-npcID-spawnUID: server + zoneUID name the instance copy
local function parseGUID(guid)
  guid = plain(guid)
  if type(guid) ~= "string" then return nil end
  local kind, server, map, zone, npc = guid:match("^(%a+)%-%d+%-(%d+)%-(%d+)%-(%d+)%-(%d+)%-")
  if kind ~= "Creature" and kind ~= "Vehicle" then return nil end
  return tonumber(npc), server .. ":" .. zone, tonumber(map)
end
RT._parseGUID = parseGUID -- tests

-- Run life -------------------------------------------------------------------------------------------------------------
-- A run is one copy of a dungeon. Out and back in (a corpse run, a hearth) is the same run; the copy's ID, learnt from the first
-- creature you target, mouse over or see on a nameplate (or that dies), tells a reset copy apart: then a new run starts.
-- Kills: Forever has no "dies" lines inside dungeons and hides most GUIDs there, but PARTY_KILL still says your group killed
-- something (a mob), and ENCOUNTER_END / BOSS_KILL / UNIT_DIED (when its GUID shows) name a boss.
local inner = CreateFrame("Frame")
local INNER = { "START_LOOT_ROLL", "ENCOUNTER_START", "ENCOUNTER_END", "BOSS_KILL", "PARTY_KILL", "UNIT_DIED", "CHAT_MSG_COMBAT_HOSTILE_DEATH", "CHAT_MSG_COMBAT_XP_GAIN",
  "PLAYER_DEAD", "PLAYER_MONEY", "CHAT_MSG_LOOT", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "PLAYER_EQUIPMENT_CHANGED", "QUEST_LOG_UPDATE",
  "LOOT_OPENED" }
-- the units you see (copy ID, boss names, dead bosses, rares) - inside instances only, each a quick look at one GUID
local SEEK = { "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT", "NAME_PLATE_UNIT_ADDED" }
local lastMoney, visitT0, partyKills, lastPartyKill = nil, nil, false, 0
-- this visit of a run that went on (6.2.17-beta4): what the run had when you came in, and the bosses killed since
local visit, visitKills = nil, {}

local function isEmpty(c)
  return not next(c.kills or {}) and (c.trash or 0) == 0 and (c.xp or 0) == 0 and #(c.loot or {}) == 0
end
local function close(c)
  if not c then return end
  c.open = nil
  c.t1 = c.t1 or c.last or now()
  local r = runs()
  if r and r[1] == c and isEmpty(c) then table.remove(r, 1) end -- walked in and out: no run
end
-- the run is finished when every boss is dead - the rare ones do not count (they are not there every time; user 23.11.)
local paintBosses = {} -- RT.Paint's boss list (reused)
local function allDown(c, d)
  local any = false
  for _, b in ipairs(d and d.bosses or {}) do
    if not b.rare and (not FLT.BossForMe or FLT.BossForMe(b)) then any = true; if not RT.Killed(c, b) then return false end end
  end
  return any
end

-- the other players in the group (names), to tell a new group's copy from the old one (6.2.17)
local function mates()
  local t, raid = {}, IsInRaid and IsInRaid()
  local n = (GetNumGroupMembers and GetNumGroupMembers()) or 0
  local me = UnitName and plain((UnitName("player")))
  for i = 1, raid and n or n - 1 do -- party1..party(n-1) (n counts you), raid1..raid(n) (you among them)
    local u = raid and ("raid" .. i) or ("party" .. i)
    local ok, name = pcall(UnitName, u); name = ok and plain(name)
    if type(name) == "string" and name ~= "" and name ~= me then t[#t + 1] = name end
  end
  return table.concat(t, ",")
end
local function sameGroup(a, b)
  if (a or "") == "" or (b or "") == "" then return (a or "") == (b or "") end
  for name in a:gmatch("[^,]+") do if ("," .. b .. ","):find("," .. name .. ",", 1, true) then return true end end
  return false
end
local function start(d, t0)
  local r = runs(); if not r then return end
  local c = { key = d.key, t0 = t0 or now(), last = now(), open = true, clk = true, xp = 0, gold = 0, deaths = 0, trash = 0, kills = {}, loot = {},
    party = (IsInGroup and IsInGroup()) and true or nil, lvl = UnitLevel and UnitLevel("player") or nil, mates = mates() }
  table.insert(r, 1, c)
  for i = #r, MAX_RUNS + 1, -1 do r[i] = nil end
  return c
end

-- the first kill starts the clock (also remembered for this visit: a run split off later starts at it)
local function clockOn(c)
  if visit and not visit.ts then visit.ts = now() end
  if c and c.clk and not c.ts then c.ts = now() end -- only runs that wait for their first kill
end
RT._clockOn = clockOn -- tests

local function seek(on)
  for _, e in ipairs(SEEK) do if on then pcall(inner.RegisterEvent, inner, e) else pcall(inner.UnregisterEvent, inner, e) end end
end
-- the copy we are in: the same as the run's, or a new copy (a reset) - then a new run
local function learnCopy(uid, map)
  local d, c = RT.active, current()
  if RT.uid or not (d and c and uid) then return end
  if map and d.instanceID and map ~= d.instanceID then return end
  RT.uid = uid
  if c.uid and c.uid ~= uid then
    close(c)
    c = start(d, visitT0)
  end
  c.uid = uid
  if RT.Show then RT.Show() end
  if RT.onChange then RT.onChange() end
end
local kill
-- A boss that is already dead in this run fights or dies again: a new copy, reset without the tracker hearing of it (6.2.17-beta4,
-- user 24.11.: "unser timer setzt beim zweiten run nicht automatisch zurueck" - the same group back within 10 minutes, and the
-- copy's ID is a secret value in Forever dungeons). The new run starts when you came in and takes what this visit brought.
local function splitRun(c, d)
  local v = visit; visit = nil
  local n = start(d, visitT0); if not n then return c end
  n.xp, c.xp = (c.xp or 0) - v.xp, v.xp
  n.gold, c.gold = (c.gold or 0) - v.gold, v.gold
  n.trash, c.trash = (c.trash or 0) - v.trash, v.trash
  n.deaths, c.deaths = (c.deaths or 0) - v.deaths, v.deaths
  for i = v.loot + 1, #(c.loot or {}) do n.loot[#n.loot + 1] = c.loot[i] end
  for i = #(c.loot or {}), v.loot + 1, -1 do c.loot[i] = nil end
  if c.items then
    for id, k in pairs(c.items) do
      local was = v.items and v.items[id] or 0
      if k > was then n.items = n.items or {}; n.items[id] = k - was; n.itemsN = (n.itemsN or 0) + 1 end
    end
    c.items = v.items
  end
  n.manual = c.manual
  n.ts = v.ts -- its clock from this visit's first kill
  c.t1 = v.t1 or v.last
  close(c)
  if RT.onChange then RT.onChange() end
  if RT.Show then RT.Show() end
  return n
end
RT._splitRun = splitRun -- tests
-- Wings of one instance (6.2.15-beta3, Discord: a UBRS run shown as LBRS; user 23.11.: "genauso bauen wie bei dungeon journal,
-- also auch mit mobs"): Blackrock Spire, Dire Maul and Scarlet Monastery share one instance ID per dungeon, so the game cannot
-- tell the wing. The creatures you see (1) or kill (2) can: those that live in one wing only (Data/DungeonWings.lua). The run
-- moves to a wing once it has 2 points and more than the shown wing - only while no boss is dead and the wing was not chosen
-- by hand. The points belong to the run (out and back in keeps them).
-- A boss of another wing killed (LBRS done, then UBRS in the same copy; user 23.11.: "auf boss kill auf jedenfall") ends the run
-- and starts one for that wing in the same copy, from the first mob killed there (wingFirst). The tracker's title chooses the wing
-- by hand (only dungeons that share their instance ID; user 23.11.: "A neuen lauf starten ... die automatik soll aber trotzdem
-- beibehalten werden"): with bosses dead also a new run; the creatures then no longer move it, a boss kill still does.
local wingT, wingScore, wingSeen, wingFirst, wingRun = nil, {}, {}, {}, nil
local sibNpc, sibName = {}, {} -- the bosses of the other wings -> their dungeon
-- the dungeons that share d's instance ID (d too), when there is more than one
function RT.Wings(d)
  if not (d and d.instanceID) then return nil end
  local t
  for _, o in ipairs(FLT.DUNGEONS or {}) do
    if o.instanceID == d.instanceID then t = t or {}; t[#t + 1] = o end
  end
  return t and #t > 1 and t or nil
end
local function buildSiblings(d)
  wipe(sibNpc); wipe(sibName)
  for _, o in ipairs(RT.Wings(d) or {}) do
    if o.key ~= d.key then
      for _, b in ipairs(o.bosses or {}) do
        if b.npcID then sibNpc[b.npcID] = o end
        sibName[lower(b.name)] = o
        if FLT.Name then sibName[lower(FLT.Name(b.name))] = o end
      end
    end
  end
end
local function wingReset(c)
  if wingRun ~= c then wipe(wingScore); wipe(wingSeen); wipe(wingFirst); wingRun = c; RT.wing = nil end
end
-- the run goes over to wing nd: renamed while no boss is dead, else a new run in the same copy from t0
local function toWing(nd, t0, manual)
  local c, d = current(), RT.active
  if not (c and d and nd) or nd.key == d.key or RT.testRun then return end
  wingReset(c)
  if next(c.kills) then
    local uid = c.uid
    t0 = math.max(math.min(t0 or now(), now()), c.t0 or 0)
    c.last = t0; close(c)
    c = start(nd, t0)
    if not c then return end
    c.uid = uid; c.ts = t0 -- bosses died: its clock runs from the wing's start
    wingRun = c -- the points stay
  else
    c.key = nd.key
  end
  if manual then c.manual = true end
  wipe(wingFirst) -- the next change of wing counts from then on
  RT.active, RT.wing = nd, nd
  buildNames(nd); buildSiblings(nd)
  if RT.Show then RT.Show() end
  if RT.onChange then RT.onChange() end
  return c
end
RT._toWing = toWing -- tests
-- a new run by hand (the cog; 6.2.17, Discord sleaker 24.11.: "no way to manually reset"): ends this one, starts a fresh one
function RT.NewRun()
  local d, c = RT.active, current()
  if not d or RT.testRun then return end
  if c then close(c) end
  visitT0 = now()
  c = start(d, visitT0)
  RT.uid, RT.wing = nil, nil
  wingReset(c)
  buildNames(d)
  if RT.Show then RT.Show() end
  if RT.onChange then RT.onChange() end
end
local function wingSign(npc, weight)
  local k = wingT and npc and wingT[npc]
  local d, c = RT.active, current()
  if not (k and d and c) or RT.testRun then return end
  wingReset(c)
  if (wingSeen[npc] or 0) >= weight then return end
  wingScore[k] = (wingScore[k] or 0) + weight - (wingSeen[npc] or 0)
  wingSeen[npc] = weight
  if weight >= 2 and k ~= d.key and not wingFirst[k] then wingFirst[k] = now() end
  local mine = (wingScore[d.key] or 0)
  if k == d.key then
    if mine >= 2 then RT.wing = d end
    return
  end
  if wingScore[k] < 2 or wingScore[k] <= mine or next(c.kills) or c.manual then return end
  toWing(dungeonByKey(k))
end
RT._wingSign = wingSign -- tests
-- a boss of another wing killed: the run goes over to that wing (see above)
local function bossOfWing(o)
  if o and RT.active and o.key ~= RT.active.key and not RT.testRun then toWing(o, wingFirst[o.key]) end
end
-- the wing chosen by hand (the tracker's title)
function RT.PickWing(o)
  local c = current()
  if not (o and c and RT.active) or RT.testRun then return end
  if o.key == RT.active.key then c.manual = true; RT.wing = o; return end
  toWing(o, now(), true)
end
-- the dungeon of this instance ID the tracker shows (sure = found by the creatures or chosen), else the one of its open run
-- (sure when it was chosen by hand)
function RT.WingDungeon(inst)
  local d, c = RT.active, not RT.testRun and current()
  if d and d.instanceID == inst then return d, RT.wing == d or (c and c.manual and c.key == d.key) or false end
  local cd = c and dungeonByKey(c.key)
  if cd and cd.instanceID == inst and now() - (c.last or 0) < RESUME then return cd, c.manual and true or false end
end
-- a unit you target, mouse over or see on a nameplate: the copy's ID; a boss's name in the client's language; a boss lying dead
-- counts as killed (killed out of range, no event came); a rare boss seen alive lights up (user 23.11.: as Dungeon Journal does)
local function seeUnit(unit)
  local ok, guid = pcall(UnitGUID, unit)
  local npc, uid, map = parseGUID(ok and guid or nil)
  if uid then learnCopy(uid, map) end
  if npc then wingSign(npc, 1) end
  local b = npc and npcs[npc]
  if not b then return end
  local okN, name = pcall(UnitName, unit); name = okN and plain(name)
  if type(name) == "string" and name ~= "" and lower(name) ~= lower(b.name) and not names[lower(name)] then
    learnedNames()[npc] = name; names[lower(name)] = b
  end
  local c = current()
  if not c or (uid and RT.uid and uid ~= RT.uid) then return end
  local okD, dead = pcall(UnitIsDead, unit)
  if okD and plain(dead) == true then kill(nil, npc, true)
  elseif b.rare and not RT.Killed(c, b) then
    c.rareSeen = c.rareSeen or {}
    if not c.rareSeen[b.name] then c.rareSeen[b.name] = true; if RT.Paint then RT.Paint() end end
  end
end

local function enter(d)
  local c = current()
  visitT0 = now()
  -- a finished run only goes on within 10 minutes and with the same group (6.2.17, Discord sleaker 24.11.: Stratholme done,
  -- new group, fresh copy - the copy's ID is a secret value in Forever dungeons, so the old finished run went on)
  local finishedOld = c and c.done and (now() - (c.t1 or 0) > 600 or not sameGroup(c.mates, mates()))
  visit = nil; wipe(visitKills)
  if finishedOld or not (c and c.key == d.key and (now() - (c.last or 0) < RESUME or c.uid)) then
    if c then close(c) end
    c = start(d, visitT0)
  elseif c then
    local it; if c.items then it = {}; for id, k in pairs(c.items) do it[id] = k end end
    visit = { last = c.last, t1 = c.t1, xp = c.xp or 0, gold = c.gold or 0, trash = c.trash or 0, deaths = c.deaths or 0,
      loot = #(c.loot or {}), items = it }
  end
  if not c then return end
  if not c.done then c.t1 = nil end -- back in (a finished run keeps its time)
  c.last = now()
  wingT = FLT.DUNGEON_WINGS and d.instanceID and FLT.DUNGEON_WINGS[d.instanceID]
  RT.wing = ((c.manual and c.key == d.key) or (wingRun == c and (wingScore[d.key] or 0) >= 2)) and d or nil
  buildSiblings(d)
  RT.active, RT.uid, RT.closed = d, nil, nil -- X hides it only while you are inside (user 23.11.: "geht man raus und wieder rein, sollte er wieder kommen")
  buildNames(d)
  lastMoney = GetMoney and GetMoney() or nil
  for _, e in ipairs(INNER) do
    local ok = pcall(inner.RegisterEvent, inner, e)
    if e == "PARTY_KILL" then partyKills = ok end
  end
  seek(true)
  seeUnit("target")
  if RT.Show then RT.Show() end
end
local function leave()
  local c = current()
  if c then
    c.last = now()
  end
  RT.active, RT.uid, RT.closed, RT.wing, wingT = nil, nil, nil, nil, nil
  inner:UnregisterAllEvents()
  if RT.Hide then RT.Hide() end
end

local function check()
  -- a zone change (above all into a dungeon) ends the test tracker, so it never stands in for the real run (user 23.11.)
  local ended = RT.testRun and RT.EndTest and (RT.EndTest() or true)
  local inInst, kind
  if IsInInstance then inInst, kind = IsInInstance() end
  local d, sure
  if inInst and (kind == "party" or kind == "raid") and FLT.FindCurrentDungeon then d, sure = FLT.FindCurrentDungeon() end
  if d then
    -- a wing known only now (a room's name came later): the run moves to it while nothing is dead. A guess (no room name)
    -- never moves it (6.2.15-beta3)
    local c = current()
    if sure and RT.active and RT.active ~= d and c and c.key == RT.active.key and not next(c.kills) and not c.manual and RT.active.instanceID == d.instanceID then
      c.key = d.key; RT.active = d; buildNames(d)
      if RT.Show then RT.Show() end
      return
    end
    if RT.active ~= d then enter(d) elseif ended and RT.Show then RT.Show() end
  elseif RT.active then leave()
  elseif ended and RT.Hide then RT.Hide() end
end
RT._check = check -- tests

-- late: found afterwards (its corpse, its loot) - its killing blow was not just now
kill = function(name, npc, late, boss)
  local c, d = current(), RT.active
  if not (c and d) then return end
  local b = boss or (npc and npcs[npc]) or (name and names[lower(name)])
  if not b and not late then
    local o = (npc and sibNpc[npc]) or (name and sibName[lower(name)])
    if o then
      bossOfWing(o)
      c, d = current(), RT.active
      if not (c and d and d.key == o.key) then return end
      b = (npc and npcs[npc]) or (name and names[lower(name)])
    end
  end
  if b and c.kills[b.name] and not late and visit and not visitKills[b.name] then c = splitRun(c, d) end
  if b and not c.kills[b.name] then
    visitKills[b.name] = true
    clockOn(c)
    c.kills[b.name] = RT.Duration(c)
    -- the group's killing blow on it (PARTY_KILL) came just before and counted as a mob
    if not late and now() - lastPartyKill <= 3 and (c.trash or 0) > 0 then c.trash = c.trash - 1; lastPartyKill = 0 end
    if allDown(c, d) then c.done = true; c.t1 = now() end
    if RT.Paint then RT.Paint() end
    for m in pairs(RT.mapViews or {}) do if m:IsVisible() then m.MarkKills() end end -- the X on the dungeon map
  end
  return b
end
RT._kill = kill -- tests

local deathPat, xpPat, lootPat, lootPat2
local function pattern(fmt)
  if type(fmt) ~= "string" then return nil end
  local p = fmt:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
  p = p:gsub("%%%%s", "(.+)"):gsub("%%%%d", "(%%d+)")
  return "^" .. p .. "$"
end
local questDue
inner:SetScript("OnEvent", function(_, event, a1, a2, a3, a4, a5)
  if event == "PLAYER_TARGET_CHANGED" then seeUnit("target"); return
  elseif event == "UPDATE_MOUSEOVER_UNIT" then seeUnit("mouseover"); return
  elseif event == "NAME_PLATE_UNIT_ADDED" then if plain(a1) then seeUnit(a1) end return end
  local c = current()
  if event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" then check(); return end
  if not c then return end
  c.last = now()
  if event == "PARTY_KILL" then
    -- your group killed something: a mob, unless its GUID shows a boss
    local npc, uid, map = parseGUID(a2)
    if uid then learnCopy(uid, map) end
    if npc then wingSign(npc, 2) end
    if not (npc and (npcs[npc] or sibNpc[npc])) then clockOn(c); c.trash = (c.trash or 0) + 1; lastPartyKill = now() end
    if npc then kill(nil, npc) end
    if RT.Paint then RT.Paint() end
  elseif event == "UNIT_DIED" then
    local npc, uid, map = parseGUID(a1)
    if uid then learnCopy(uid, map) end
    if npc then wingSign(npc, 2) end
    if npc and (npcs[npc] or sibNpc[npc]) then kill(nil, npc) end
  elseif event == "START_LOOT_ROLL" then
    if FLT.LootRolls then FLT.LootRolls.OnStart(c, plain(a1)) end -- the loot rolls list (UI/LootRolls.lua, 6.2.17-beta10)
  elseif event == "ENCOUNTER_START" then
    -- a boss already dead in this run is pulled again: a new copy (6.2.17-beta4) - the new run from the pull on, not the kill
    local e = FLT.DUNGEON_ENCOUNTERS and FLT.DUNGEON_ENCOUNTERS[plain(a1) or 0]
    local d = RT.active
    local b = e and d and e[1] == d.key and byName(d, e[2])
    if b and c.kills[b.name] and visit and not visitKills[b.name] then splitRun(c, d) end
  elseif event == "ENCOUNTER_END" or event == "BOSS_KILL" then
    -- the fight's ID first (the same in every client language, Data/DungeonEncounters.lua), with the other bosses of the fight
    -- (Ukorz with Ruuzlu, the Seven ...); then its name
    if event == "ENCOUNTER_END" and plain(a5) ~= 1 then return end
    local e = FLT.DUNGEON_ENCOUNTERS and FLT.DUNGEON_ENCOUNTERS[plain(a1) or 0]
    local d = RT.active
    if e and d and e[1] ~= d.key then
      local o = dungeonByKey(e[1])
      if o and o.instanceID and o.instanceID == d.instanceID then bossOfWing(o); d = RT.active end
    end
    local b = e and byName(d, e[2])
    if b then
      kill(nil, nil, nil, b)
      for _, n in ipairs(e.also or {}) do local o = byName(d, n); if o then kill(nil, nil, true, o) end end
    else kill(plain(a2)) end
  elseif event == "LOOT_OPENED" or event == "LOOT_READY" then
    -- what you loot: from a boss (its GUID), or an item only one boss of this dungeon drops - that boss is dead
    local okN, n = pcall(GetNumLootItems); n = okN and plain(n)
    if type(n) ~= "number" then return end
    for slot = 1, n do
      local okS, guid = pcall(GetLootSourceInfo, slot)
      local npc = parseGUID(okS and guid or nil)
      if npc and npcs[npc] then kill(nil, npc, true)
      else
        local okL, link = pcall(GetLootSlotLink, slot); link = okL and plain(link)
        local id = type(link) == "string" and tonumber(link:match("item:(%d+)"))
        if id and onlyDrop[id] then kill(nil, nil, true, onlyDrop[id]) end
      end
    end
  elseif event == "CHAT_MSG_COMBAT_HOSTILE_DEATH" then
    local text = plain(a1)
    deathPat = deathPat or pattern(UNITDIESOTHER or "%s dies.")
    local who = deathPat and type(text) == "string" and text:match(deathPat)
    if who and not kill(who) and not partyKills then clockOn(c); c.trash = (c.trash or 0) + 1; if RT.Paint then RT.Paint() end end
  elseif event == "CHAT_MSG_COMBAT_XP_GAIN" then
    local text = plain(a1)
    if type(text) ~= "string" then return end
    -- not anchored at the end: in a group the line goes on "(+N group bonus)" (COMBATLOG_XPGAIN_FIRSTPERSON_GROUP), in a raid "(-N raid
    -- penalty)" - bosses known only by this line (no encounter, hidden GUIDs: Arugal's Voidwalker) were never counted as killed in a group
    -- and the run never finished (6.2.17-beta60, user 25.11. 21:49: "warum wurde der dungeon nicht als fertig markiert")
    xpPat = xpPat or (pattern(COMBATLOG_XPGAIN_FIRSTPERSON or "%s dies, you gain %d experience."):gsub("%$$", ""))
    local who = xpPat and text:match(xpPat)
    if who then kill(who) end -- a boss by its name in the XP line
    local n = tonumber(text:match("(%d+)"))
    if n then clockOn(c); c.xp = (c.xp or 0) + n; if RT.Paint then RT.Paint() end end
  elseif event == "PLAYER_DEAD" then
    c.deaths = (c.deaths or 0) + 1
  elseif event == "PLAYER_MONEY" then
    local m = GetMoney and GetMoney()
    if m and lastMoney and m > lastMoney then c.gold = (c.gold or 0) + m - lastMoney; if RT.Paint then RT.Paint() end end
    lastMoney = m
  elseif event == "CHAT_MSG_LOOT" then
    local text = plain(a1)
    if FLT.LootRolls and FLT.LootRolls.OnChat(c, text) then return end -- a roll line (6.2.17-beta10)
    lootPat = lootPat or pattern(LOOT_ITEM_SELF or "You receive loot: %s.")
    lootPat2 = lootPat2 or pattern(LOOT_ITEM_SELF_MULTIPLE or "You receive loot: %sx%d.")
    local link = type(text) == "string" and ((lootPat2 and text:match(lootPat2)) or (lootPat and text:match(lootPat)))
    local id = link and tonumber(link:match("item:(%d+)"))
    local q = id and C_Item and C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(id)
    if id and (q == nil or q >= 2) then c.loot[#c.loot + 1] = id end
    -- every item with its count, for the loot value (6.2.17-beta4, the cog's "Add loot value to gold")
    if id then
      local _, k = nil, nil
      if lootPat2 then _, k = text:match(lootPat2) end
      k = tonumber(k) or 1
      c.items = c.items or {}; c.items[id] = (c.items[id] or 0) + k; c.itemsN = (c.itemsN or 0) + 1
      if RT.Paint then RT.Paint() end
    end
  elseif event == "PLAYER_EQUIPMENT_CHANGED" or event == "QUEST_LOG_UPDATE" then
    if not questDue and C_Timer and C_Timer.After then
      questDue = true
      C_Timer.After(1, function() questDue = nil; if RT.Paint then RT.Paint(true) end end)
    end
  end
end)

local outer = CreateFrame("Frame")
outer:RegisterEvent("PLAYER_ENTERING_WORLD")
outer:RegisterEvent("ZONE_CHANGED_NEW_AREA")
-- "<dungeon> has been reset." (you reset it outside): its open run is over, the next visit starts a new one with its own time,
-- XP and gold (user 23.11.: "der timer laeuft einfach weiter ... auch die mob XP werden nicht zurueck gesetzt" - the run did not
-- know its copy yet, so the new copy's ID was taken as its own)
outer:RegisterEvent("CHAT_MSG_SYSTEM")
local resetPat
outer:SetScript("OnEvent", function(_, event, msg)
  local c = current()
  if event == "CHAT_MSG_SYSTEM" then
    if not c or RT.active then return end
    msg = plain(msg)
    resetPat = resetPat or pattern(INSTANCE_RESET_SUCCESS or "%s has been reset.")
    local inst = type(msg) == "string" and resetPat and msg:match(resetPat)
    local d = inst and dungeonByKey(c.key)
    if d then
      inst = lower(inst)
      local n1, n2 = lower(d.name), lower(FLT.DungeonName and FLT.DungeonName(d.name) or "")
      if n1:find(inst, 1, true) or inst:find(n1, 1, true) or (n2 ~= "" and (n2:find(inst, 1, true) or inst:find(n2, 1, true))) then
        close(c); if RT.onChange then RT.onChange() end
      end
    end
    return
  end
  -- an open run you did not come back to within the hour (logged out, hearthed home): over
  if c and not RT.active and now() - (c.last or 0) >= RESUME then close(c) end
  FLT.SafeCall("RunTracker", check)
end)

function RT.Delete(c)
  local r = runs(); if not r then return end
  for i, x in ipairs(r) do if x == c then table.remove(r, i); break end end
  if c.open and RT.active then RT.active = nil; inner:UnregisterAllEvents(); check() end
  if RT.onChange then RT.onChange() end
end

-- Marks per boss ----------------------------------------------------------------------------------------------------------
-- best upgrade among its loot (Gear Value), a wishlist item, quests in your log that need it (a drop - QuestDrops - or its name
-- in the quest's objective)
local function questLog()
  local t = {}
  if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo then
    for i = 1, C_QuestLog.GetNumQuestLogEntries() or 0 do
      local info = C_QuestLog.GetInfo(i)
      if info and not info.isHeader and info.questID then t[info.questID] = info.title or true end
    end
  elseif GetNumQuestLogEntries and GetQuestLogTitle then
    for i = 1, GetNumQuestLogEntries() or 0 do
      local title, _, _, isHeader, _, _, _, id = GetQuestLogTitle(i)
      if not isHeader and id then t[id] = title or true end
    end
  end
  return t
end
function RT.BossMarks(d, b, log, noLoad)
  local m = {}
  local GV = FLT.GearValue
  for _, it in ipairs(b.loot or {}) do
    local id = type(it) == "table" and (it.id or it[1]) -- DungeonData records {id, name, quality, slot}
    if id then
      -- an item the client has not loaded yet cannot be judged: ask for it, the tracker tries again on its next paint (user 25.11.
      -- 17:46: a boss with 3 upgrades in its loot had no triangle)
      if C_Item and C_Item.IsItemDataCachedByID and not C_Item.IsItemDataCachedByID(id) then
        m.pending = true
        if C_Item.RequestLoadItemDataByID and not noLoad then C_Item.RequestLoadItemDataByID(id) end
      end
      if GV and GV.Change then
        local ok, kind, pct = pcall(GV.Change, id)
        if ok and (kind == "up" or kind == "new") and (not m.pct or (pct or 0) > m.pct) then m.up, m.pct = id, pct or 0 end
      end
      if FLT.IsOnWishlist and FLT.IsOnWishlist(id) then m.wish = m.wish or id end
    end
  end
  log = log or questLog()
  local drops = b.npcID and FLT.QUEST_DROPS and FLT.QUEST_DROPS[b.npcID]
  if drops then
    for qid in drops:gmatch("(%d+):") do
      qid = tonumber(qid)
      if log[qid] then m.quest = type(log[qid]) == "string" and log[qid] or (FLT.Name and FLT.Name(tostring(qid))); break end
    end
  end
  if not m.quest then
    local bn = lower(b.name)
    for _, q in ipairs(d.quests or {}) do
      if q.id and log[q.id] and lower(q.objective):find(bn, 1, true) then m.quest = FLT.Name and FLT.Name(q.name) or q.name; break end
    end
  end
  return m
end
-- the dungeon's quests: in your log, and the ones you could take but have not (dungeon quest status of Dungeons & Raids)
function RT.Quests(d)
  local H = UI and UI.DungeonHelpers
  local have, open, missing = 0, 0, {}
  if not (H and H.getDungeonQuestStatus) then return 0, 0, missing end
  for _, q in ipairs(d and d.quests or {}) do
    local s = H.getDungeonQuestStatus(d, q)
    if s == "inlog" or s == "ready" then have = have + 1; open = open + 1
    elseif s == "available" or s == "chain" then open = open + 1; missing[#missing + 1] = FLT.Name and FLT.Name(q.name) or q.name end
  end
  return have, open, missing
end

-- Tracker window ----------------------------------------------------------------------------------------------------------
local frame, ticker, lootPop, markPop
local function cfg()
  if type(OneForAllDB) ~= "table" then return {} end
  OneForAllDB.runTracker = type(OneForAllDB.runTracker) == "table" and OneForAllDB.runTracker or {}
  OneForAllDB.instCap = nil -- the instances per hour are no longer shown (6.2.17, user 25.11.2026: "streichen")
  local t = OneForAllDB.runTracker
  -- the shipped settings (user 25.11.2026 with a screenshot of the cog: "das sind die standardeinstellungen die dann ausgeliefert
  -- werden sollen"): loot value on, with auction prices, the current loot roll always shown, loot rolls hide after 10 s; picture
  -- on, 5 bosses per row, 75 % opacity (those three were defaults already). Set once, so a choice made later stays.
  if not t.defaults1 then
    t.defaults1 = true
    if t.lootValue == nil then t.lootValue = true end
    if t.lootAH == nil then t.lootAH = true end
    if t.rollsAuto == nil then t.rollsAuto = true end
    if t.rollsHide == nil then t.rollsHide = 10 end
  end
  -- 6.2.17-beta60 (user 25.11. 21:49 with a screenshot of the settings: "das sollen die standardeinstellungen sein ab jetzt"): 5 visible
  -- bosses and 85 % opacity (the defaults when nothing is saved) and green items hidden in the loot rolls - set once, a choice made later stays
  if not t.defaults2 then
    t.defaults2 = true
    if t.rollsNoGreen == nil then t.rollsNoGreen = true end
  end
  return t
end
-- the value of what you looted (6.2.17-beta4, user 24.11.: "einen eigenen schalter in den einstellungen des trackers ... optional
-- auch mit AH preisen von auctionator"): on by default since 6.2.17-beta26 (see cfg); vendor prices, or Auctionator's (the vendor price where it has none, e.g.
-- soulbound items). nil when switched off. Worked out again only when the loot or the setting changed (the clock paints every second).
local lvRun, lvN, lvMode, lvVal
function RT.LootValue(c)
  local cf = cfg()
  if not (cf.lootValue and c) then return nil end
  local ah = cf.lootAH and FLT.SkillUp and FLT.SkillUp.HasAuctionator and FLT.SkillUp.HasAuctionator() or false
  if lvRun == c and lvN == (c.itemsN or 0) and lvMode == ah then return lvVal end
  local v, missing = 0, false
  local info = (C_Item and C_Item.GetItemInfo) or GetItemInfo
  for id, k in pairs(c.items or {}) do
    local p = ah and FLT.SkillUp.AHPrice(id) or nil
    if not p then
      local sell = select(11, info(id))
      if sell == nil then missing = true; if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end end
      p = sell or 0
    end
    v = v + p * k
  end
  if not missing then lvRun, lvN, lvMode = c, c.itemsN or 0, ah end -- an item not loaded yet: again next time
  lvVal = v
  return v
end
RT.Cfg = cfg
local function wanted()
  local c = current()
  return RT.active and c and not RT.closed and (RT.testRun or (FLT.QoL and FLT.QoL.Get and FLT.QoL.Get("runTracker")))
end

-- every tooltip of the tracker hangs at its owner's top right corner (like Dungeon Journal's boss tooltip; user 23.11.:
-- "tooltip wie bei den bossen oben rechts ... damit das einheitlich ist"), so it never covers the loot window below
local function cornerTip(owner)
  GameTooltip:SetOwner(owner, "ANCHOR_NONE"); GameTooltip:ClearAllPoints()
  GameTooltip:SetPoint("BOTTOMLEFT", owner, "TOPRIGHT", 0, 0)
end
-- an item of a killed boss's tooltip: its icon and its name in its quality colour
local function dropText(id, link)
  local icon = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)
  local l = (GetItemInfo and select(2, GetItemInfo(id))) or link or ("item " .. id)
  return (icon and ("|T" .. icon .. ":14:14|t ") or "") .. l
end
-- the boss tooltip hangs at the portrait's top right corner (like Dungeon Journal; user 23.11.)
local function bossTip(self)
  local d, b, c = RT.active, self.boss, current()
  if not (d and b) then return end
  cornerTip(self)
  GameTooltip:AddLine(FLT.Name and FLT.Name(b.name) or b.name, 1, 0.82, 0.2)
  if b.optional then GameTooltip:AddLine(L["Optional - not needed to finish the run"], 0.78, 0.80, 0.86)
  elseif b.rare then GameTooltip:AddLine(L["Rare - not there every time"], 0.78, 0.80, 0.86) end
  if b.rare and c and c.rareSeen and c.rareSeen[b.name] and not RT.Killed(c, b) then GameTooltip:AddLine(L["Seen in this run"], 0.85, 0.9, 1) end
  local k = RT.Killed(c, b)
  if k then
    GameTooltip:AddLine(string.format(L["Killed after %s"], RT.Clock(k)), 0.45, 1, 0.5)
    -- what it dropped in this run and who got it (6.2.17-beta23, user 25.11.: "die anzeige von loot nach toten bossen ist auch toll";
    -- idea from Dungeon Journal): its loot table against this run's rolls (UI/LootRolls.lua) and what you looted yourself
    local LR = FLT.LootRolls
    for _, it in ipairs(b.loot or {}) do
      local id = type(it) == "table" and (it.id or it[1])
      if id then
        local got = false
        for _, e in ipairs(c.rolls or {}) do
          if e.id == id then
            got = true
            GameTooltip:AddDoubleLine(dropText(id, e.link), LR and LR.WinnerText(e) or "", 1, 1, 1, 1, 1, 1)
          end
        end
        if not got and c.items and c.items[id] then
          GameTooltip:AddDoubleLine(dropText(id), UnitName and UnitName("player") or "", 1, 1, 1, 1, 1, 1)
        end
      end
    end
  end
  -- the green arrow tells about an upgrade; which item shows in the loot window (user 23.11.: "der pfeil reicht")
  local m = self.marks or {}
  if m.wish then GameTooltip:AddLine(string.format(L["On your wishlist: %s"], GetItemInfo and GetItemInfo(m.wish) or ("item " .. m.wish)), 1, 0.82, 0.2) end
  if m.quest then GameTooltip:AddLine(string.format(L["Quest: %s"], m.quest), 1, 0.82, 0.2) end
  GameTooltip:AddLine(" ")
  -- left-click targets it, killed or not (6.2.17-beta23/24), OneForAll moves to Shift-click
  GameTooltip:AddLine((b.rare and not k) and L["Left-click: target and mark with a skull"] or L["Left-click: target"], 0.8, 0.8, 0.8)
  GameTooltip:AddLine(L["Shift-click: open in OneForAll"], 0.8, 0.8, 0.8)
  GameTooltip:AddLine(L["Right-click: show loot"], 0.8, 0.8, 0.8)
  GameTooltip:Show()
end

-- the same click again closes OneForAll (user 23.11.: "sollten aber die OFA fenster auch wieder schliessen koennen")
local opened
local function openBoss(d, b, mode)
  if not (UI and UI.PrepareWindow) then return end
  d = d and d._real or d -- the test tracker shows a part of a real dungeon
  local what = d and (d.key .. ":" .. tostring(mode or (b and b.name)))
  local win = _G.OneForAllFrame
  if win and win:IsShown() and opened == what and (not UI.ActiveTab or UI.ActiveTab() == "dungeons") then
    win:Hide(); opened = nil; return
  end
  opened = what
  UI.PrepareWindow("dungeons", function()
    if FLT.OpenPanel then FLT:OpenPanel("dungeons") end
    if UI.OpenDungeon then UI.OpenDungeon(d, b and b.name, mode) end
  end)
end

-- the loot window: under the whole tracker, left aligned, with the boss's portrait first (over the tracker when there is no room
-- below); on a higher level - under the boss it covered the next row of portraits and lay behind them (user 23.11.: "unten
-- tatsaechlich besser ... ganz linksbuendig unten und vor den items nochmal das boss portrait")
-- the backgrounds of the tracker and its loot window: the opacity of the cog's slider (user 23.11.: "das loot fenster sollte die
-- gleichen einstellungen der opacity uebernehmen")
-- the dungeon's picture (its loading screen, like in the dungeon list) behind the top of the tracker, darkened and fading out
-- downward so the text and the portraits stay readable (user 23.11.: "dungeon bilder ... als halbtransparenten hintergrund",
-- option "Show dungeon picture" in the cog)
local PIC_H = 48 -- only behind the head since the list layout (6.2.17-beta37)
-- first-time settings (user 23.11. 15:02 / 25.11., see cfg): 5 bosses per row, 75 % opacity, the dungeon picture on
local function applyPicture()
  if not (frame and frame.pic) then return end
  local d = RT.active and (RT.active._real or RT.active)
  local on = cfg().picture ~= false and d and UI.SetDungeonPicture and UI.SetDungeonPicture(frame.pic, d.key, W - 8, PIC_H)
  -- the tracker's piece is almost as high as the picture, so the loading screen's painted top border (the bar with the lamp)
  -- came along - the dungeon list uses a flat strip from the middle (user 25.11.: "bei unseren dungeonbildern ist diese leiste
  -- aber nicht drin"): start 10 % lower and narrow it by as much, so the shape stays (6.2.17-beta15)
  if on and frame.pic.GetTexCoord then
    local l, t, _, b, r = frame.pic:GetTexCoord()
    if l and t and b and r and b > t and r > l then
      local cut = 0.10
      local nt = t + (b - t) * cut
      local dw = (r - l) * cut / 2
      frame.pic:SetTexCoord(l + dw, r - dw, nt, b)
    end
  end
  frame.pic:SetShown(on and true or false)
  if on and UI.AlphaFade then UI.AlphaFade(frame.pic, "VERTICAL", 0.30 * (cfg().bgAlpha or 0.85), 0.9 * (cfg().bgAlpha or 0.85)) end
end
local function applyBG()
  local a = 0.96 * (cfg().bgAlpha or 0.85)
  if frame and frame.bg then frame.bg:SetColor(0.045, 0.045, 0.055, a) end
  if lootPop and lootPop.bg then lootPop.bg:SetColor(0.045, 0.045, 0.055, a) end
  if markPop and markPop.bg then markPop.bg:SetColor(0.045, 0.045, 0.055, a) end
  if FLT.LootRolls then FLT.LootRolls.SetAlpha(a) end
  applyPicture()
end

-- the dropdowns under a boss row (6.2.17-beta37, user 25.11.: "der loot per rechtsklick, die marker per linksklick, aber nicht unten
-- als extra box sondern wie eine art dropdown das sich oeffnet"): they float over the rows below (the mark buttons are protected
-- and may not move in combat), as wide as a row. Close by themselves after 5 s with the mouse off them (user 25.11., beta32); the
-- OnUpdate runs only while one is open, checked twice a second. Right-click closes it.
-- The mark dropdown is a secure frame (marking is protected: SetRaidTarget gave ADDON_ACTION_FORBIDDEN, beta24): its buttons run /tm,
-- it is opened under the row by the target button's secure click and closed by a mark's click; in combat only those two can show /
-- hide it.
local function inCombat() return InCombatLockdown and InCombatLockdown() end
local ROW_W = W - 8
local SLOT, STEP = 24, 27
local PERROW = math.max(1, math.floor((ROW_W - 12 + 3) / STEP))
local function popHeight(n) local rows = math.max(1, math.ceil(n / PERROW)); return 10 + rows * SLOT + (rows - 1) * (STEP - SLOT) end
local function slotPoint(ib, i)
  ib:ClearAllPoints(); ib:SetPoint("TOPLEFT", 6 + ((i - 1) % PERROW) * STEP, -5 - math.floor((i - 1) / PERROW) * STEP)
end
local function makePop(secure)
  local p
  if secure then p = CreateFrame("Frame", "OneForAllTrackerMarks", UIParent, "SecureHandlerBaseTemplate"); p:Hide()
  else p = CreateFrame("Frame", nil, frame) end
  p.secure = secure
  p._ofaNoBG = true
  p.bg = UI.UnmarkBG(UI.FramedPanel(p))
  p.items = {}
  p:SetFrameStrata("DIALOG")
  p:SetToplevel(true)
  local function close() if not (secure and inCombat()) then GameTooltip:Hide(); p:Hide() end end
  p:EnableMouse(true); p:SetScript("OnMouseUp", function(_, button) if button == "RightButton" then close() end end)
  local idle, acc = 0, 0
  function p.Poke() idle, acc = 0, 0 end
  p:SetScript("OnShow", p.Poke)
  p:SetScript("OnUpdate", function(self, el)
    acc = acc + (el or 0); if acc < 0.5 then return end
    -- the frame's own IsMouseOver (the FrameXML helper MouseIsOver does not exist in this client, beta34)
    if self:IsMouseOver() then idle = 0 else idle = idle + acc end
    acc = 0
    if idle >= 5 then close() end -- the mark dropdown in combat: as soon as the fight is over
  end)
  return p
end
-- a slot with slightly rounded corners, like the game's buttons (6.2.17-beta24, user 25.11.: "die items an den ecken noch etwas
-- abrunden")
local function popSlot(p, secure, size)
  size = size or SLOT
  local ib = CreateFrame("Button", nil, p, secure and "SecureActionButtonTemplate" or nil); ib:SetSize(size, size)
  ib.edge = UI.RoundRect(ib, ib, "BACKGROUND", 0, 5, 0, 0.3, 0.3, 0.3, 0.9)
  ib.icon = ib:CreateTexture(nil, "ARTWORK"); ib.icon:SetPoint("TOPLEFT", 1, -1); ib.icon:SetPoint("BOTTOMRIGHT", -1, 1)
  ib:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  if ib.icon.AddMaskTexture and ib.CreateMaskTexture then
    local m = ib:CreateMaskTexture(); FLT.SetTex(m, UI.ASSET_ROOT .. "talent_icon_mask2", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    m:SetAllPoints(ib.icon); ib.icon:AddMaskTexture(m)
    local hl = ib.GetHighlightTexture and ib:GetHighlightTexture()
    if hl and hl.AddMaskTexture then hl:ClearAllPoints(); hl:SetAllPoints(ib.icon); hl:AddMaskTexture(m) end
  end
  ib:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return ib
end

-- the loot of a boss (right-click on its row): its items, an upgrade with a green frame, "1 upgrade for you" after them
local function showLoot(btn)
  local b = btn.boss
  if lootPop and lootPop:IsShown() and lootPop.boss == b then lootPop:Hide(); return end
  if not lootPop then
    lootPop = makePop()
    lootPop.note = FLT.NewFS(lootPop, nil, "OVERLAY", "GameFontHighlightSmall"); lootPop.note:SetJustifyH("LEFT")
    lootPop.note:SetTextColor(FLT.TextC(0.75, 0.75, 0.72))
  end
  local GV = FLT.GearValue
  local n, ups = 0, 0
  for _, it in ipairs(b.loot or {}) do
    local id = type(it) == "table" and (it.id or it[1]) -- DungeonData records {id, name, quality, slot}
    if id then
      n = n + 1
      local ib = lootPop.items[n]
      if not ib then
        ib = popSlot(lootPop)
        ib.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        -- 6.2.18-beta9 (user 27.11.2026: "im loot anzeigen ... per rechtsklick ... der wishlist direkt hinzufuegen"): a gold star
        -- on wishlist items, right-click on gear adds / removes it (right-click elsewhere still closes the window)
        ib.star = ib:CreateTexture(nil, "OVERLAY", nil, 7); ib.star:SetSize(12, 12); ib.star:SetPoint("TOPRIGHT", 3, 3)
        FLT.SetTex(ib.star, UI.ASSET_ROOT .. "icon_star"); ib.star:SetVertexColor(FLT.SkinC(1, 0.82, 0.25))
        ib:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        ib:SetScript("OnEnter", function(self)
          GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
          if GameTooltip.SetItemByID then GameTooltip:SetItemByID(self.id) else GameTooltip:SetHyperlink("item:" .. self.id) end
          if FLT.IsGearItem and FLT.IsGearItem(self.id) and FLT.ToggleWishlist then
            GameTooltip:AddLine(L[FLT.IsOnWishlist(self.id) and N"Right-click: remove from wishlist" or N"Right-click: add to wishlist"], 0.6, 0.8, 1)
          end
          GameTooltip:Show()
        end)
        ib:SetScript("OnClick", function(self, button)
          if button == "RightButton" then
            if FLT.IsGearItem and FLT.IsGearItem(self.id) and FLT.ToggleWishlist then
              FLT.ToggleWishlist(self.id); self.star:SetShown(FLT.IsOnWishlist(self.id))
              if GameTooltip:IsOwned(self) then self:GetScript("OnEnter")(self) end
            else GameTooltip:Hide(); lootPop:Hide() end
            return
          end
          if IsModifiedClick and IsModifiedClick() and HandleModifiedItemClick then
          local link = GetItemInfo and select(2, GetItemInfo(self.id)); if link then HandleModifiedItemClick(link) end end end)
        lootPop.items[n] = ib
      end
      ib.id = id
      ib.star:SetShown(FLT.IsOnWishlist and FLT.IsOnWishlist(id) or false)
      slotPoint(ib, n)
      ib.icon:SetTexture((C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)) or "Interface\\Icons\\INV_Misc_QuestionMark")
      local up = false
      if GV and GV.Change then local ok, kind = pcall(GV.Change, id); up = ok and (kind == "up" or kind == "new") end
      if up then
        ups = ups + 1; ib.edge:SetColor(0.25, 1, 0.25, 1) -- an upgrade for you: a green frame
      else
        local q = it.quality or it[4]
        q = type(q) == "number" and q or 1
        local r, g, bl = qualityColor(q)
        ib.edge:SetColor(r, g, bl, 0.9)
      end
      -- and the green arrow of our other item lists (user 25.11. 17:15: "bei den upgrades der bosse sind keine pfeile")
      if FLT.GearMarks and FLT.GearMarks.IconArrow then FLT.GearMarks.IconArrow(ib.icon, id) end
      ib:Show()
    end
  end
  for i = n + 1, #lootPop.items do lootPop.items[i]:Hide() end
  if n == 0 then lootPop:Hide(); return end
  if markPop and markPop:IsShown() and not inCombat() then markPop:Hide() end
  applyBG()
  lootPop.boss = b
  lootPop:SetFrameLevel((frame:GetFrameLevel() or 0) + 30)
  local h = popHeight(n)
  -- "1 upgrade for you": after the last item when there is room, else in a line of its own
  local note = lootPop.note
  note:SetText(ups > 0 and string.format(ups == 1 and L["%d upgrade for you"] or L["%d upgrades for you"], ups) or "")
  note:ClearAllPoints()
  if ups > 0 then
    local last = ((n - 1) % PERROW) + 1
    local x = 6 + last * STEP + 4
    if x + (note:GetStringWidth() or 80) <= ROW_W - 6 then
      note:SetPoint("LEFT", lootPop, "TOPLEFT", x, -5 - math.floor((n - 1) / PERROW) * STEP - SLOT / 2)
    else
      note:SetPoint("TOPLEFT", 8, -h + 2); h = h + 14
    end
  end
  lootPop:SetSize(ROW_W, h)
  lootPop:ClearAllPoints(); lootPop:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, 0)
  lootPop:Show()
  return n
end
RT._showLoot = showLoot -- tests
-- the wishlist changed (FLT.ToggleWishlist): the boss rows show their stars anew
function RT.WishChanged()
  if frame and frame:IsShown() then RT.Paint(true) end
end
function RT._pops() return lootPop, markPop end -- tests

-- the raid marks (6.2.17-beta24, user 25.11.: "eine leiste ... mit markern, die man dann gleich setzen kann ... beim setzen oder
-- spaetestens nach 10 sekunden geschlossen"; not for rares: "da soll einfach nur skull gesetzt werden"): the eight marks and "none"
-- in one row
local MARKS = { 8, 7, 6, 5, 4, 3, 2, 1, 0 }
local MSLOT, MSTEP = 22, 25
local function ensureMarks()
  if markPop or inCombat() then return markPop end
  markPop = makePop(true)
  for i, m in ipairs(MARKS) do
    local ib = popSlot(markPop, true, MSLOT)
    ib:RegisterForClicks("AnyUp", "AnyDown")
    ib.mark = m
    ib:SetAttribute("type1", "macro"); ib:SetAttribute("macrotext1", "/tm " .. m)
    ib.icon:SetTexture(m > 0 and ("Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. m) or "Interface\\Buttons\\UI-GroupLoot-Pass-Up")
    ib.icon:ClearAllPoints(); ib.icon:SetPoint("TOPLEFT", 3, -3); ib.icon:SetPoint("BOTTOMRIGHT", -3, 3)
    ib.edge:SetColor(0.30, 0.27, 0.22, 0.9)
    ib:SetPoint("TOPLEFT", 4 + (i - 1) * MSTEP + (m == 0 and 2 or 0), -5)
    ib:SetScript("OnEnter", function(self)
      cornerTip(self)
      GameTooltip:AddLine(self.mark > 0 and (_G["RAID_TARGET_" .. self.mark] or ("#" .. self.mark)) or (_G.RAID_TARGET_NONE or NONE or "-"), 1, 0.82, 0.2)
      GameTooltip:Show()
    end)
    -- after the mark is set the dropdown closes (secure, works in combat too)
    -- (on the mouse-up half only: the buttons take AnyUp + AnyDown, and with "cast on key up" a dropdown hidden on the down half
    -- would never see the up click that sets the mark)
    if SecureHandlerWrapScript then SecureHandlerWrapScript(ib, "OnClick", markPop, [[ if not down then return nil, "close" end ]], [[ owner:Hide() ]]) end
    markPop.items[i] = ib
  end
  markPop:SetSize(ROW_W, MSLOT + 10)
  markPop:HookScript("OnShow", function() GameTooltip:Hide(); if lootPop then lootPop:Hide() end; applyBG() end)
  return markPop
end
-- out of combat: the tracker's scale (its place under the row is set by the secure click)
local function placeMarks()
  if not markPop or inCombat() then return end
  markPop:SetScale((frame:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1))
end
RT._ensureMarks = ensureMarks -- tests

-- gold in the tracker: the two largest coins only (it is a small column)
local COIN_G, COIN_S, COIN_C = "|TInterface\\MoneyFrame\\UI-GoldIcon:10:10:1:0|t", "|TInterface\\MoneyFrame\\UI-SilverIcon:10:10:1:0|t",
  "|TInterface\\MoneyFrame\\UI-CopperIcon:10:10:1:0|t"
local function shortMoney(c, one)
  c = math.floor(tonumber(c) or 0)
  local g, si, cu = math.floor(c / 10000), math.floor(c / 100) % 100, c % 100
  if g > 0 then return g .. COIN_G .. (si > 0 and not one and (" " .. si .. COIN_S) or "") end
  if si > 0 then return si .. COIN_S .. (cu > 0 and not one and (" " .. cu .. COIN_C) or "") end
  return cu .. COIN_C
end
RT._shortMoney = shortMoney -- tests

local function questTip(self)
  local d = RT.active; if not d then return end
  local have, open, missing = RT.Quests(d)
  cornerTip(self)
  GameTooltip:AddLine(string.format(L["Quests in your log: %d of %d"], have, open), 1, 0.82, 0.2)
  if #missing > 0 then
    GameTooltip:AddLine(L["Not taken yet:"], 0.9, 0.9, 0.9)
    for _, n in ipairs(missing) do GameTooltip:AddLine("  " .. n, 0.8, 0.8, 0.8) end
  end
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine(L["Click: show the quests in OneForAll"], 0.8, 0.8, 0.8)
  GameTooltip:Show()
end

-- the tracker hangs at its top left corner: when it grows or shrinks (bosses per row, hidden parts) it does so downward, its top and
-- the settings window above it stay where they are (user 23.11.: "das settingsfenster fix bleiben"); saves the place
function RT._pinTop()
  if not frame then return end
  local l, t = frame:GetLeft(), frame:GetTop()
  if not (l and t) then return end
  frame:ClearAllPoints(); frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l, t)
  cfg().pos = { "TOPLEFT", "BOTTOMLEFT", l, t }
end

-- Left-click on a living boss targets it, a rare also gets the skull (6.2.17-beta23, user 25.11.: "per linksklick den boss ins
-- target nehmen, bei rare auch mit totenkopf"). Targeting is protected, so a secure button runs /targetexact. These buttons lie
-- on UIParent where the portraits are (not anchored to them): a protected child would stop the tracker from moving in combat.
-- They are put back over their portraits by RT.Paint (every second while the tracker is shown) out of combat only.
local targets = {}
local regen
local function targetButton(i)
  local t = targets[i]
  if t then return t end
  t = CreateFrame("Button", "OneForAllTrackerTarget" .. i, UIParent, "SecureActionButtonTemplate")
  t:RegisterForClicks("AnyUp", "AnyDown") -- the game's "cast on key down" setting needs both
  t:SetAttribute("type1", "macro")
  t:SetAttribute("shift-type1", "ofanone") -- Shift-click: no game action, opens OneForAll (PostClick)
  t:SetAttribute("type2", "ofanone") -- right-click: no game action, the loot window (PostClick)
  t:SetScript("PostClick", function(self, button, down)
    if down or not self.bb then return end
    if button == "RightButton" then showLoot(self.bb)
    elseif IsShiftKeyDown and IsShiftKeyDown() then openBoss(RT.active, self.bb.boss)
    elseif markPop and not self.bb.boss.rare and markPop:IsShown() then markPop.boss = self.bb.boss; markPop.Poke() end -- the mark dropdown (opened securely)
  end)
  -- left-click on a boss that is no rare: the secure mark bar opens (in combat too); ofamarks is set by syncTargets
  local mp = ensureMarks()
  if mp and SecureHandlerWrapScript then
    -- a second click on the same boss closes it again (user 25.11. 17:15: "soll auch geschlossen werden koennen wenn man erneut klickt")
    SecureHandlerWrapScript(t, "OnClick", mp, [[ if not down and button == "LeftButton" and self:GetAttribute("ofamarks") and not IsModifierKeyDown() then
      if owner:IsShown() and owner:GetAttribute("ofafrom") == self:GetName() then owner:Hide()
      else owner:ClearAllPoints(); owner:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, 0); owner:SetAttribute("ofafrom", self:GetName()); owner:Show() end
    end ]])
  end
  t:SetScript("OnEnter", function(self) if self.bb then bossTip(self.bb) end end)
  t:SetScript("OnLeave", function() GameTooltip:Hide() end)
  targets[i] = t
  return t
end
local function hideTargets(from)
  if inCombat() then return end
  if not from and markPop then markPop:Hide() end
  for i = from or 1, #targets do local t = targets[i]; if t:IsShown() then t:Hide() end; t.bb = nil end
end
-- after a fight: put them in place (or away when the tracker closed meanwhile)
local function needRegen()
  if regen then return end
  regen = CreateFrame("Frame")
  regen:SetScript("OnEvent", function()
    if frame and frame:IsShown() then if RT.Paint then RT.Paint() end else hideTargets() end
  end)
  pcall(regen.RegisterEvent, regen, "PLAYER_REGEN_ENABLED")
end
local function syncTargets(d, c)
  if inCombat() then return end
  needRegen()
  local us = UIParent:GetEffectiveScale() or 1
  local n = 0
  for _, bb in ipairs(frame.bosses) do
    local b = bb:IsShown() and bb.boss
    local cx, cy = bb:GetCenter()
    if b and cx then -- killed ones too (user 25.11.: "manchmal sucht man einen toten boss")
      n = n + 1
      local t = targetButton(n)
      t.bb = bb
      local fs = (bb:GetEffectiveScale() or 1) / us
      t:ClearAllPoints(); t:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx * fs, cy * fs)
      t:SetSize((bb:GetWidth() or 0) * fs, (bb:GetHeight() or 0) * fs)
      t:SetFrameStrata(frame:GetFrameStrata() or "MEDIUM"); t:SetFrameLevel((frame:GetFrameLevel() or 1) + 20)
      local name = FLT.Name and FLT.Name(b.name) or b.name
      local macro = "/cleartarget\n/targetexact " .. tostring(name) .. ((b.rare and not RT.Killed(c, b)) and "\n/tm 8" or "")
      if t.macro ~= macro then t.macro = macro; t:SetAttribute("macrotext1", macro) end
      local marks = not b.rare -- a rare only gets the skull (user 25.11.)
      if t.marks ~= marks then t.marks = marks; t:SetAttribute("ofamarks", marks or nil) end
      if not t:IsShown() then t:Show() end
    end
  end
  hideTargets(n + 1)
  placeMarks()
end
RT._targets = targets -- tests

local function build()
  frame = CreateFrame("Frame", "OneForAllRunTracker", UIParent)
  frame:SetSize(W, H); frame:SetFrameStrata("MEDIUM"); frame:SetClampedToScreen(true)
  frame:SetMovable(true); frame:EnableMouse(true); frame:RegisterForDrag("LeftButton")
  -- while it is dragged (out of combat) the target buttons and the mark bar move along every frame, like the loot bar that hangs on
  -- the tracker (user 25.11.: "wieso rueckt diese leiste mit markern verzoegert nach"); in combat they follow after the fight
  local function follow() syncTargets(RT.active, current()) end
  frame:SetScript("OnDragStart", function(self)
    if cfg().locked then return end
    self:StartMoving()
    if not inCombat() then self:SetScript("OnUpdate", follow) end
  end)
  frame:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
    self:StopMovingOrSizing()
    RT._pinTop()
    follow()
  end)
  local pos = cfg().pos
  if type(pos) == "table" then frame:SetPoint(pos[1], UIParent, pos[2] or pos[1], pos[3] or 0, pos[4] or 0)
  else frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -260, -220) end
  local sc = tonumber(cfg().scale); if sc and sc >= 0.6 and sc <= 2 then frame:SetScale(sc) end
  frame._ofaNoBG = true
  -- its background has its own opacity (the small button at the top right, user 23.11.), not the main window's
  frame.bg = UI.UnmarkBG(UI.FramedPanel(frame))
  frame.pic = frame:CreateTexture(nil, "BACKGROUND", nil, 2); frame.pic:SetPoint("TOPLEFT", 4, -4); frame.pic:SetSize(W - 8, PIC_H)
  frame.pic:SetVertexColor(0.55, 0.55, 0.55); frame.pic:Hide()
  -- the frame line of OneForAll's windows (user 23.11.: "schoener waere der rahmen aus OFA"), in a quiet dark bronze (grey was still
  -- "zu deutlich zu sehen ... oder in einem dunklen bronze")
  local deco = CreateFrame("Frame", nil, frame); deco:SetAllPoints(frame); deco:SetFrameLevel((frame:GetFrameLevel() or 0) + 15)
  UI.WindowFrame(deco, frame, { ring = { 0.26, 0.20, 0.12 }, acc = { 0.40, 0.30, 0.16 } })

  -- no dungeon icon before the name any more: the dungeon's picture shows which dungeon it is (user 23.11.: "version ohne dieses icon")
  frame.title = FLT.NewFS(frame, nil, "OVERLAY", "GameFontNormal"); frame.title:SetPoint("LEFT", frame, "TOPLEFT", 10, -16)
  frame.title:SetJustifyH("LEFT"); frame.title:SetWordWrap(false); frame.title:SetTextColor(FLT.TextC(1, 0.82, 0.2))
  -- dungeons that share their instance ID (LBRS / UBRS, Dire Maul, Scarlet Monastery): a click on the name chooses the wing
  -- (6.2.15-beta4); dragging there still moves the tracker
  local wb = CreateFrame("Button", nil, frame); frame.wingBtn = wb
  wb:SetHeight(18); wb:SetPoint("LEFT", frame.title, "LEFT", -2, 0); wb:RegisterForDrag("LeftButton")
  wb:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
  wb.arrow = wb:CreateTexture(nil, "OVERLAY"); wb.arrow:SetSize(12, 12); wb.arrow:SetPoint("RIGHT", 0, -1)
  wb.arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow"); wb.arrow:SetRotation(-math.pi / 2)
  wb:SetScript("OnDragStart", function() local f = frame:GetScript("OnDragStart"); if f then f(frame) end end)
  wb:SetScript("OnDragStop", function() local f = frame:GetScript("OnDragStop"); if f then f(frame) end end)
  wb:SetScript("OnEnter", function(self)
    cornerTip(self); GameTooltip:AddLine(L["Wing"], 1, 0.82, 0.2)
    GameTooltip:AddLine(L["Click: choose the wing - the tracker finds it by itself, choose it here when it is wrong."], 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
  end)
  wb:SetScript("OnLeave", function() GameTooltip:Hide() end)
  wb:SetScript("OnClick", function(self)
    local pop = frame.wingPop
    if pop and pop:IsShown() then pop:Hide(); return end
    local wings = RT.Wings(RT.active)
    if not wings then return end
    if not pop then
      pop = CreateFrame("Frame", nil, frame); pop._ofaNoBG = true; UI.FramedPanel(pop)
      pop:SetFrameStrata("DIALOG"); pop:SetToplevel(true); pop:EnableMouse(true); pop.rows = {}
      pop:SetScript("OnEvent", function(p) if not p:IsMouseOver() and not frame.wingBtn:IsMouseOver() then p:Hide() end end)
      pop:SetScript("OnShow", function(p) pcall(p.RegisterEvent, p, "GLOBAL_MOUSE_DOWN") end)
      pop:SetScript("OnHide", function(p) p:UnregisterAllEvents() end)
      frame.wingPop = pop
    end
    for i, o in ipairs(wings) do
      local r = pop.rows[i]
      if not r then
        r = CreateFrame("Button", nil, pop); r:SetSize(196, 18); r:SetPoint("TOPLEFT", 6, -6 - (i - 1) * 18)
        r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        r.text = FLT.NewFS(r, nil, "OVERLAY", "GameFontHighlightSmall"); r.text:SetPoint("LEFT", 6, 0); r.text:SetJustifyH("LEFT")
        r:SetScript("OnClick", function(b) pop:Hide(); RT.PickWing(b.d) end)
        pop.rows[i] = r
      end
      r.d = o; r:Show()
      r.text:SetText(FLT.DungeonName and FLT.DungeonName(o.name) or o.name)
      local on = RT.active and o.key == RT.active.key
      r.text:SetTextColor(FLT.TextC(on and 1 or 0.9, on and 0.82 or 0.9, on and 0.2 or 0.9))
    end
    for i = #wings + 1, #pop.rows do pop.rows[i]:Hide() end
    pop:SetSize(208, #wings * 18 + 12)
    pop:ClearAllPoints(); pop:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
    pop:SetFrameLevel((frame:GetFrameLevel() or 0) + 30)
    pop:Show()
  end)

  -- X: hides the tracker until you leave the dungeon; on the test tracker it ends the test (user 23.11.: a hidden test tracker kept
  -- the real one hidden in the next dungeon)
  local close = UI.CloseButton(frame, function()
    if RT.testRun and RT.EndTest then RT.EndTest(); if RT.active then RT.Show() else RT.Hide() end return end
    RT.closed = true; RT.Hide()
  end)
  close:SetSize(18, 16); close:SetPoint("TOPRIGHT", -5, -6); frame.close = close
  close:SetScript("OnEnter", function(self)
    cornerTip(self); GameTooltip:AddLine(L["Hide (/ofa tracker)"], 0.9, 0.9, 0.9); GameTooltip:Show()
  end)
  close:SetScript("OnLeave", function() GameTooltip:Hide() end)
  -- no reset button: a new copy of the dungeon (after a reset) starts a new run by itself (user 23.11.: "nicht manuell steuern")
  -- small buttons next to X: the dungeon's quests and its map in OneForAll (user 23.11.: instead of the Quests column)
  local function iconButton(icon, size, anchor, onClick, onEnter)
    local b = UI.GoldButton(frame, "", 18, 16, icon, 10); b.iconGap = 0
    if b.icon then b.icon:SetSize(size, size); b.icon:ClearAllPoints(); b.icon:SetPoint("CENTER") end
    b:SetPoint("RIGHT", anchor, "LEFT", -2, 0)
    b:SetScript("OnClick", onClick); b:SetScript("OnEnter", onEnter); b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
  end
  -- the cog sits in the head now (6.2.17-beta37, user 25.11.: "settings button ... oben in den kopfbereich")
  local ob = iconButton("Interface\\Buttons\\UI-OptionsButton", 12, close, function() RT._openSettings() end,
    function(self) cornerTip(self); GameTooltip:AddLine(L["Settings"], 1, 0.82, 0.2); GameTooltip:Show() end)
  frame.cog = ob
  frame.qBtn = iconButton("Interface\\GossipFrame\\AvailableQuestIcon", 12, ob,
    function() if RT.active then openBoss(RT.active, nil, "quests") end end, questTip)
  frame.mapBtn = iconButton(UI.ASSET_ROOT .. "icon_map", 12, frame.qBtn,
    function() if RT.active then openBoss(RT.active, nil, "map") end end, function(self)
      cornerTip(self); GameTooltip:AddLine(L["Map"], 1, 0.82, 0.2)
      GameTooltip:AddLine(L["Click: show the dungeon map in OneForAll"], 0.8, 0.8, 0.8); GameTooltip:Show()
    end)
  frame.title:SetPoint("RIGHT", frame.mapBtn, "LEFT", -4, 0)

  -- the footer: Time, Mob XP, Gold in cells (6.2.17-beta37, user 25.11.: "time, xp, gold wie auf dem bild"); placed by RT.Paint
  frame.foot = CreateFrame("Frame", nil, frame)
  frame.footLine = frame.foot:CreateTexture(nil, "ARTWORK"); frame.footLine:SetColorTexture(0.50, 0.38, 0.19, 0.55); frame.footLine:SetHeight(1)
  frame.footLine:SetPoint("TOPLEFT", 5, 0); frame.footLine:SetPoint("TOPRIGHT", -5, 0)
  frame.sep = {}
  for i = 1, 2 do
    local t = frame.foot:CreateTexture(nil, "ARTWORK"); t:SetColorTexture(0.50, 0.38, 0.19, 0.40); t:SetWidth(1); frame.sep[i] = t
  end
  local function column(label)
    local l = FLT.NewFS(frame.foot, nil, "OVERLAY", "GameFontNormalSmall"); l:SetText(label); l:SetTextColor(FLT.TextC(1, 0.82, 0.2))
    local v = FLT.NewFS(frame.foot, nil, "OVERLAY", "GameFontHighlightLarge"); v:SetPoint("TOPLEFT", l, "BOTTOMLEFT", 0, -2)
    return l, v
  end
  frame.timeL, frame.time = column(L["Time"])
  -- the best time / the difference sits next to the label, so the values fit in one row
  frame.best = FLT.NewFS(frame.foot, nil, "OVERLAY", "GameFontHighlightSmall"); frame.best:SetTextColor(FLT.TextC(0.85, 0.85, 0.85)); frame.best:SetPoint("LEFT", frame.timeL, "RIGHT", 4, 0)
  frame.xpL, frame.xp = column(L["Mobs XP"])
  frame.goldL, frame.gold = column(L["Gold"])
  -- the width of the gold's digits (texture escapes count oddly in GetStringWidth: the copper was dropped although it fit)
  frame.goldM = FLT.NewFS(frame.foot, nil, "OVERLAY", "GameFontHighlightLarge"); frame.goldM:Hide()
  applyBG()
  -- the cog's settings window (user 23.11.: "das zahnrad hernehmen um ... mehrere optionen einstellen zu koennen"); it opens on a
  -- click only, over the tracker
  function RT._openSettings()
    local pop = frame.opPop
    if not pop then
      -- its own window (6.2.17-beta58, user 25.11. 21:37: "ein kleines unabhaengiges popup ... braucht dann einfach ein X zum schliessen";
      -- beta59, 21:42: "ein fenster das nicht auch schon angeheftet startet und wie ein fenster aussieht, also breiter als hoch ... beim
      -- ersten mal oeffnen in der mitte"): two columns - the tracker on the left, loot on the right; it does not close on a click elsewhere,
      -- can be dragged and stays where it was put (the first time in the middle of the screen)
      local COLW, PAD, GAP = 250, 14, 22
      local popW = PAD + COLW + GAP + COLW + PAD
      pop = CreateFrame("Frame", "OneForAllTrackerSettings", UIParent); pop._ofaNoBG = true; UI.FramedPanel(pop)
      for _, t in ipairs(UI.OrnateFrame(pop, pop, 16, 3, "OVERLAY", 4) or {}) do t:SetVertexColor(FLT.SkinC(1, 1, 1, 1)) end
      pop:SetFrameStrata("DIALOG"); pop:SetToplevel(true); pop:EnableMouse(true); pop:SetClampedToScreen(true)
      pop:SetMovable(true); pop:RegisterForDrag("LeftButton")
      pop:SetScript("OnDragStart", function(self) self:StartMoving() end)
      pop:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local x, yy = self:GetLeft(), self:GetTop()
        if x and yy then cfg().setPos2 = { x, yy } end
      end)
      if UISpecialFrames then table.insert(UISpecialFrames, "OneForAllTrackerSettings") end -- Escape closes it
      local head = FLT.NewFS(pop, nil, "OVERLAY", "GameFontNormalLarge"); head:SetPoint("TOPLEFT", PAD, -12)
      head:SetText(L["Dungeon tracker"] .. " - " .. L["Settings"])
      local x = UI.CloseButton(pop, function() pop:Hide() end); x:SetPoint("TOPRIGHT", -8, -8)
      local hl = pop:CreateTexture(nil, "ARTWORK"); hl:SetColorTexture(0.50, 0.38, 0.19, 0.55); hl:SetHeight(1)
      hl:SetPoint("TOPLEFT", PAD, -38); hl:SetPoint("TOPRIGHT", -PAD, -38)
      local checks, ys = {}, {}
      local function col(c) return PAD + (c - 1) * (COLW + GAP) end
      local function section(c, label)
        local t = FLT.NewFS(pop, nil, "OVERLAY", "GameFontNormal"); t:SetPoint("TOPLEFT", col(c), ys[c]); t:SetText(label)
        ys[c] = ys[c] - 20
      end
      local function check(c, key, label)
        local cb = FLT.SkinBlizz(CreateFrame("CheckButton", nil, pop, "UICheckButtonTemplate")); cb:SetSize(20, 20)
        cb:SetPoint("TOPLEFT", col(c) - 4, ys[c])
        local t = FLT.NewFS(pop, nil, "OVERLAY", "GameFontHighlightSmall"); t:SetPoint("LEFT", cb, "RIGHT", 4, 0); t:SetText(label)
        t:SetWidth(COLW - 28); t:SetJustifyH("LEFT"); t:SetWordWrap(false)
        cb:SetScript("OnClick", function(self)
          if key == "picture" then cfg().picture = self:GetChecked() and true or false; applyPicture(); RT.Layout(); return end
          cfg()[key] = self:GetChecked() and true or nil
          if key == "rollsBtnHide" and FLT.LootRolls then FLT.LootRolls.ApplyButton() end
          if key == "rollsNoGreen" and FLT.LootRolls then FLT.LootRolls._refresh(); FLT.LootRolls.Rearm() end
          if key == "lootValue" and checks.lootAH then
            checks.lootAH:SetEnabled(self:GetChecked() and FLT.SkillUp and FLT.SkillUp.HasAuctionator and FLT.SkillUp.HasAuctionator() or false)
          end
          RT.Layout()
        end)
        checks[key] = cb
        ys[c] = ys[c] - 22
      end
      local function slider(c, label, minV, maxV, step, get, set)
        local t = FLT.NewFS(pop, nil, "OVERLAY", "GameFontHighlightSmall"); t:SetPoint("TOPLEFT", col(c), ys[c] - 4); t:SetText(label)
        local v = FLT.NewFS(pop, nil, "OVERLAY", "GameFontHighlightSmall"); v:SetPoint("TOPRIGHT", pop, "TOPLEFT", col(c) + COLW, ys[c] - 4)
        local sl = UI.Slider(pop, COLW, minV, maxV, step, function(val) set(val); v:SetText(get(true)) end)
        sl:SetPoint("TOPLEFT", col(c), ys[c] - 18)
        ys[c] = ys[c] - 44
        return sl, v
      end
      ys[1], ys[2] = -48, -48
      -- left: the tracker itself
      section(1, L["Dungeon tracker"])
      check(1, "hideTime", L["Hide time"]); check(1, "hideXP", L["Hide XP"]); check(1, "hideGold", L["Hide gold"])
      check(1, "hideBosses", L["Hide bosses"]); check(1, "picture", L["Show dungeon picture"]); check(1, "locked", L["Lock tracker"])
      ys[1] = ys[1] - 4
      -- how many bosses show before "N more" (6.2.17-beta37, user 25.11.: "wir machen erstmal 4, ich wuerde von 3-20 gehen")
      pop.maxVis = slider(1, L["Visible bosses"], 3, 20, 1, function() return tostring(RT.MaxVisible()) end,
        function(val) cfg().maxVisible = val; RT.Paint() end)
      pop.alpha = slider(1, L["Opacity"], 0, 100, 5, function() return math.floor((cfg().bgAlpha or 0.85) * 100 + 0.5) .. "%" end,
        function(val) cfg().bgAlpha = val / 100; applyBG() end)
      -- right: gold and the loot rolls list (6.2.17-beta10, user 24.11.: "autohide after X seconds, und always show aktuellen roll")
      section(2, L["Gold"])
      check(2, "lootValue", L["Add loot value to gold"]); check(2, "lootAH", L["Use auction prices (Auctionator)"])
      ys[2] = ys[2] - 6
      section(2, L["Loot rolls"])
      check(2, "rollsAuto", L["Always show the current loot roll"])
      check(2, "rollsBtnHide", L["Hide loot-roll button"])
      check(2, "rollsNoGreen", L["Hide green items in loot rolls"]) -- 6.2.17-beta51 (user 25.11. 20:47), off until the user decides
      ys[2] = ys[2] - 4
      pop.rollsHide = slider(2, L["Auto-hide loot rolls after"], 0, 30, 5,
        function() local v = tonumber(cfg().rollsHide) or 0; return v > 0 and string.format(L["%d sec"], v) or L["Never"] end,
        function(val) cfg().rollsHide = val > 0 and val or nil; if FLT.LootRolls then FLT.LootRolls.Rearm() end end)
      -- "New run" at the bottom right
      local bottom = math.min(ys[1], ys[2]) - 4
      local nr = UI.GoldButton(pop, L["New run"], 140, 22, nil, 11); nr:SetPoint("TOPRIGHT", pop, "TOPLEFT", col(2) + COLW, bottom)
      nr:SetScript("OnClick", function() pop:Hide(); RT.NewRun() end)
      nr:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:AddLine(L["New run"], 1, 0.82, 0.2)
        GameTooltip:AddLine(L["Ends this run and starts a new one - e.g. after a reset the tracker did not notice."], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
      end)
      nr:HookScript("OnLeave", function() GameTooltip:Hide() end)
      pop.newRun = nr
      pop:SetSize(popW, -(bottom - 22) + PAD)
      -- where it was put last; the first time in the middle of the screen
      local sp = cfg().setPos2
      if type(sp) == "table" and sp[1] and sp[2] then pop:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", sp[1], sp[2])
      else pop:SetPoint("CENTER", UIParent, "CENTER", 0, 60) end
      cfg().setPos = nil -- (beta58's place: that window was smaller and sat on the tracker)
      pop.checks = checks
      frame.opPop = pop
      pop:Hide()
    end
    if pop:IsShown() then pop:Hide(); return end
    for key, cb in pairs(pop.checks) do
      if key == "picture" then cb:SetChecked(cfg().picture ~= false) else cb:SetChecked(cfg()[key] and true or false) end
    end
    pop.maxVis:SetValue(RT.MaxVisible())
    pop.alpha:SetValue(math.floor((cfg().bgAlpha or 0.85) * 100 + 0.5))
    pop.rollsHide:SetValue(tonumber(cfg().rollsHide) or 0)
    pop.newRun:SetEnabled(RT.active and not RT.testRun and true or false)
    local atr = FLT.SkillUp and FLT.SkillUp.HasAuctionator and FLT.SkillUp.HasAuctionator() or false
    pop.checks.lootAH:SetEnabled(atr and cfg().lootValue and true or false)
    pop:Show()
  end
  -- the line under the head (placed by RT.Paint)
  frame.line = frame:CreateTexture(nil, "ARTWORK"); frame.line:SetColorTexture(0.50, 0.38, 0.19, 0.55); frame.line:SetHeight(1)

  frame.bosses = {}
  -- the folded parts of the list: "N defeated" (with the last kill time) and "N more"; a click unfolds / folds them
  local function summaryRow(key)
    local r = CreateFrame("Button", nil, frame); r:SetSize(ROW_W, SUM_H); r:RegisterForClicks("LeftButtonUp")
    r.arrow = r:CreateTexture(nil, "OVERLAY"); r.arrow:SetSize(10, 10); r.arrow:SetPoint("LEFT", 12, 0)
    r.arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
    r.text = FLT.NewFS(r, nil, "OVERLAY", "GameFontHighlightSmall"); r.text:SetPoint("LEFT", 30, 0); r.text:SetTextColor(FLT.TextC(0.62, 0.62, 0.60))
    r.time = FLT.NewFS(r, nil, "OVERLAY", "GameFontHighlightSmall"); r.time:SetPoint("RIGHT", -8, 0); r.time:SetTextColor(FLT.TextC(0.35, 0.85, 0.40))
    r.hl = r:CreateTexture(nil, "HIGHLIGHT"); r.hl:SetAllPoints(); r.hl:SetColorTexture(1, 0.85, 0.4, 0.06)
    r.line = r:CreateTexture(nil, "ARTWORK"); r.line:SetColorTexture(0.40, 0.31, 0.16, 0.30); r.line:SetHeight(1); r.line:SetPoint("BOTTOMLEFT"); r.line:SetPoint("BOTTOMRIGHT")
    r:SetScript("OnClick", function() local u = RT._unfold(); u[key] = not u[key]; RT.Paint() end)
    r:SetScript("OnDragStart", function() local f = frame:GetScript("OnDragStart"); if f then f(frame) end end)
    r:SetScript("OnDragStop", function() local f = frame:GetScript("OnDragStop"); if f then f(frame) end end)
    r:RegisterForDrag("LeftButton")
    return r
  end
  frame.sumDead, frame.sumMore = summaryRow("dead"), summaryRow("more")
  -- the corner: drag to resize (the scale, 60 - 200 %); the top left corner stays where it is and the bottom right corner
  -- follows the mouse (user 23.11.: it ran away from the cursor while the frame was anchored at its top right)
  local grip = CreateFrame("Button", nil, frame); grip:SetSize(11, 11); grip:SetPoint("BOTTOMRIGHT", -1, 1); frame.grip = grip
  grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
  grip:SetScript("OnMouseDown", function(self)
    local eff, pe = frame:GetEffectiveScale(), UIParent:GetEffectiveScale() or 1
    local left, top = (frame:GetLeft() or 0) * eff, (frame:GetTop() or 0) * eff -- screen pixels
    local s0, x0, y0 = frame:GetScale(), GetCursorPosition()
    local dx, dy = math.max(1, x0 - left), math.max(1, top - y0) -- the cursor's distance from the fixed corner at the start
    self:SetScript("OnUpdate", function()
      local x, y = GetCursorPosition()
      local s = s0 * math.max((x - left) / dx, (top - y) / dy)
      s = math.max(0.6, math.min(2, s))
      frame:SetScale(s); frame:ClearAllPoints()
      -- the size in % at the cursor (user 25.11. 17:25)
      local pct = math.floor(s * 100 + 0.5)
      if pct ~= self.pct then self.pct = pct; GameTooltip:SetOwner(self, "ANCHOR_CURSOR"); GameTooltip:SetText(pct .. " %", 1, 0.82, 0.2); GameTooltip:Show() end
      frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left / (s * pe), top / (s * pe))
      syncTargets(RT.active, current()) -- (does nothing in combat)
    end)
  end)
  grip:SetScript("OnMouseUp", function(self)
    self:SetScript("OnUpdate", nil); self.pct = nil; GameTooltip:Hide()
    cfg().scale = frame:GetScale()
    local p, _, rp, x, y = frame:GetPoint(); cfg().pos = { p, rp, x, y }
  end)
  frame:SetScript("OnHide", function()
    hideTargets() -- in combat they stay until the fight ends (PLAYER_REGEN_ENABLED)
    if ticker then ticker:Cancel(); ticker = nil end
    if lootPop then lootPop:Hide() end
    if markPop then markPop:Hide() end
    if frame.opPop then frame.opPop:Hide() end
  end)
end


-- a boss row (6.2.17-beta37, user 25.11.: the compact list): portrait (a rounded square, round for rares and optional bosses),
-- name, on the right the kill time (a dead boss) or a green triangle (it drops an upgrade for you), a star (wishlist), "!" (a
-- quest in your log needs it). The next boss has a gold bar in front. Clicks: its target button lies over it (left: target +
-- marks, Shift: OneForAll, right: loot); this button takes them in combat when the target buttons could not follow.
local ROW_H = 28 -- user 25.11. 17:15: "die Zeilenhoehe der bosse koennte etwas groesser sein"
local function bossButton(i)
  local bb = frame.bosses[i]
  if bb then return bb end
  bb = CreateFrame("Button", nil, frame)
  bb:RegisterForClicks("LeftButtonUp", "RightButtonUp"); bb:SetSize(ROW_W, ROW_H)
  bb:RegisterForDrag("LeftButton")
  bb:SetScript("OnDragStart", function() local f = frame:GetScript("OnDragStart"); if f then f(frame) end end)
  bb:SetScript("OnDragStop", function() local f = frame:GetScript("OnDragStop"); if f then f(frame) end end)
  bb.tint = bb:CreateTexture(nil, "BACKGROUND", nil, 3); bb.tint:SetAllPoints(); bb.tint:SetColorTexture(1, 0.78, 0.25, 0.10)
  bb.bar = bb:CreateTexture(nil, "ARTWORK"); bb.bar:SetPoint("TOPLEFT"); bb.bar:SetPoint("BOTTOMLEFT"); bb.bar:SetWidth(3)
  bb.bar:SetColorTexture(1, 0.80, 0.15, 1)
  bb.line = bb:CreateTexture(nil, "ARTWORK"); bb.line:SetColorTexture(0.40, 0.31, 0.16, 0.30); bb.line:SetHeight(1)
  bb.line:SetPoint("BOTTOMLEFT"); bb.line:SetPoint("BOTTOMRIGHT")
  bb.hl = bb:CreateTexture(nil, "HIGHLIGHT"); bb.hl:SetAllPoints(); bb.hl:SetColorTexture(1, 0.85, 0.4, 0.06)
  -- the portrait: a bronze edge behind, the picture masked to a rounded square or a circle
  bb.edge = bb:CreateTexture(nil, "ARTWORK", nil, 1); bb.edge:SetSize(23, 23); bb.edge:SetPoint("LEFT", 8, 0)
  bb.icon = bb:CreateTexture(nil, "ARTWORK", nil, 2); bb.icon:SetSize(21, 21); bb.icon:SetPoint("CENTER", bb.edge)
  if bb.icon.AddMaskTexture and bb.CreateMaskTexture then
    bb.maskSq = bb:CreateMaskTexture(); FLT.SetTex(bb.maskSq, UI.ASSET_ROOT .. "talent_icon_mask2", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    bb.maskSq:SetAllPoints(bb.icon)
    bb.maskRd = bb:CreateMaskTexture(); bb.maskRd:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    bb.maskRd:SetAllPoints(bb.icon)
    bb.maskSqE = bb:CreateMaskTexture(); FLT.SetTex(bb.maskSqE, UI.ASSET_ROOT .. "talent_icon_mask2", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    bb.maskSqE:SetAllPoints(bb.edge)
    bb.maskRdE = bb:CreateMaskTexture(); bb.maskRdE:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    bb.maskRdE:SetAllPoints(bb.edge)
  end
  bb.name = FLT.NewFS(bb, nil, "OVERLAY", "GameFontHighlight"); bb.name:SetPoint("LEFT", 37, 0); bb.name:SetJustifyH("LEFT")
  bb.name:SetWordWrap(false)
  bb.time = FLT.NewFS(bb, nil, "OVERLAY", "GameFontHighlightSmall"); bb.time:SetPoint("RIGHT", -8, 0); bb.time:SetTextColor(FLT.TextC(0.35, 0.85, 0.40))
  bb.up = bb:CreateTexture(nil, "OVERLAY"); bb.up:SetSize(11, 11); bb.up:SetPoint("RIGHT", -9, 0); FLT.SetTex(bb.up, UI.ASSET_ROOT .. "tri_up")
  bb.star = bb:CreateTexture(nil, "OVERLAY"); bb.star:SetSize(13, 13); FLT.SetTex(bb.star, UI.ASSET_ROOT .. "icon_star")
  bb.star:SetVertexColor(FLT.SkinC(1, 0.82, 0.25)) -- gold like the wishlist star everywhere else (6.2.18-beta9; it was white)
  bb.quest = bb:CreateTexture(nil, "OVERLAY"); bb.quest:SetSize(14, 14); bb.quest:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")
  bb:SetScript("OnEnter", bossTip); bb:SetScript("OnLeave", function() GameTooltip:Hide() end)
  bb:SetScript("OnClick", function(self, button)
    if button == "RightButton" then showLoot(self) else openBoss(RT.active, self.boss) end
  end)
  frame.bosses[i] = bb
  return bb
end
local function setShape(bb, round)
  if not bb.maskSq or bb.round == round then return end
  bb.round = round
  bb.icon:RemoveMaskTexture(round and bb.maskSq or bb.maskRd); bb.icon:AddMaskTexture(round and bb.maskRd or bb.maskSq)
  bb.edge:RemoveMaskTexture(round and bb.maskSqE or bb.maskRdE); bb.edge:AddMaskTexture(round and bb.maskRdE or bb.maskSqE)
end

-- the list (6.2.17-beta37, user 25.11. with Ofa's mock-ups "list layout"): the main bosses in dungeon order, then the optional ones,
-- then the rares. Dead bosses fold into "N defeated" (a boss just killed stays in place for a moment), the next living boss is the
-- first full row, up to maxVisible rows, the rest folds into "N more"; a rare seen alive in this run moves up into the shown rows
-- (user: "wenn einer gefunden wird ... dann soll er mit rein rutschen"). A row clicked open stays open until it is folded again or
-- a new run starts.
local JUST = 2 -- seconds a boss just killed stays in place before it folds
function RT.MaxVisible() local v = tonumber(cfg().maxVisible) or 5; return math.max(3, math.min(20, math.floor(v))) end
local unfold = { run = nil }
function RT._unfold()
  local c = current()
  if unfold.run ~= c then unfold.run, unfold.dead, unfold.more = c, nil, nil end
  return unfold
end
local orderBuf, deadBuf, liveBuf, skipBuf, rowsBuf, posBuf = {}, {}, {}, {}, {}, setmetatable({}, { __mode = "k" })
local function row(kind, b, n, t, m) local r = rowsBuf[#rowsBuf + 1] or {}; rowsBuf[#rowsBuf + 1] = r; r.kind, r.boss, r.n, r.t, r.m = kind, b, n, t, m; return r end
local function isMain(b) return not b.rare and not b.optional end
local function listRows(bosses, c, maxV, dur)
  wipe(orderBuf); wipe(deadBuf); wipe(liveBuf); wipe(skipBuf)
  for i = #rowsBuf, 1, -1 do rowsBuf[i] = nil end
  for pass = 1, 3 do
    for _, b in ipairs(bosses) do
      local kind = b.rare and 3 or (b.optional and 2 or 1)
      if kind == pass then orderBuf[#orderBuf + 1] = b end
    end
  end
  local u = RT._unfold()
  -- a skipped boss (user 25.11. 17:53: "wenn ... der erste uebersprungen wird und dann der zweite getoetet wird, sollte der erste boss
  -- in die "X more" liste rutschen und der naechste Boss waere dann der dritte"): a living main boss before the last main boss killed
  -- in dungeon order - as long as a living main boss comes after that one; when none does, the skipped ones are next again
  local far, after = 0, false
  for i, b in ipairs(orderBuf) do if isMain(b) and RT.Killed(c, b) then far = i end end
  for i, b in ipairs(orderBuf) do if i > far and isMain(b) and not RT.Killed(c, b) then after = true; break end end
  local lastKill, next, killed, total = nil, nil, 0, 0
  for i, b in ipairs(orderBuf) do
    local k = RT.Killed(c, b)
    if isMain(b) then total = total + 1; if k then killed = killed + 1 end end
    if k and not (dur >= k and dur - k < JUST) then deadBuf[#deadBuf + 1] = b; lastKill = math.max(lastKill or 0, k) -- (a kill time past the clock: folded too)
    elseif not k and after and i < far and isMain(b) then skipBuf[#skipBuf + 1] = b
    else liveBuf[#liveBuf + 1] = b; if not k and not next and isMain(b) then next = b end end
  end
  -- "3 / 8 defeated" (main bosses; the count left the head, user 25.11. 17:15: "das 1/8 ... oben komplett entfernen, stattdessen da wo
  -- jetzt 1 defeated steht 1/8 defeated"), always on top, the killed bosses unfold below it
  if total > 0 or #deadBuf > 0 then
    row("dead", nil, killed, lastKill, total).has = #deadBuf > 0
    if u.dead then
      -- in the order they died (user 25.11. 21:27: "die toten bosse bitte der zeit nach sortieren"); same time: dungeon order
      for i, b in ipairs(orderBuf) do posBuf[b] = i end
      table.sort(deadBuf, function(a, b)
        local ka, kb = RT.Killed(c, a) or 0, RT.Killed(c, b) or 0
        if ka ~= kb then return ka < kb end
        return (posBuf[a] or 0) < (posBuf[b] or 0)
      end)
      for _, b in ipairs(deadBuf) do row("boss", b) end
    end
  end
  local shown, rest = 0, 0
  local seen = c.rareSeen
  for _, b in ipairs(liveBuf) do
    if u.more or shown < maxV then row("boss", b); shown = shown + 1
    elseif b.rare and seen and seen[b.name] and not RT.Killed(c, b) then row("boss", b)
    else rest = rest + 1 end
  end
  -- the skipped ones always wait in "N more" (unfolded: at its end)
  for _, b in ipairs(skipBuf) do if u.more then row("boss", b) else rest = rest + 1 end end
  if rest > 0 then row("more", nil, rest) end
  if u.more and (#liveBuf > maxV or #skipBuf > 0) then row("more", nil, 0) end -- the line to fold the rest again
  return rowsBuf, next
end
RT._listRows = listRows -- tests

local marksFor, marksGen, markCache, markTries = nil, nil, {}, {}
local HEAD, HEAD_PIC, FOOT = 26, 52, 44
local COIN_W = 11 -- a coin icon (10) and its gap (user 25.11. 17:43: "die symbole etwas kleiner")
function RT.Paint(marksToo)
  if not (frame and frame:IsShown()) then return end
  local d, c = RT.active, current()
  if not (d and c) then hideTargets(); return end
  local cf = cfg()
  frame.title:SetText(FLT.DungeonName and FLT.DungeonName(d.name) or d.name)
  local wings = not RT.testRun and RT.Wings(d)
  frame.wingBtn:SetShown(wings and true or false)
  if not wings and frame.wingPop then frame.wingPop:Hide() end
  local dur = RT.Duration(c)
  -- the head: higher with the dungeon picture behind it (user 25.11.: "wenn hintergrund aktiviert dann soll die kopfzeile etwas
  -- erweitert werden")
  local head = (frame.pic and frame.pic:IsShown()) and HEAD_PIC or HEAD
  local ty = -(head - 13)
  frame.title:ClearAllPoints(); frame.title:SetPoint("LEFT", frame, "TOPLEFT", 10, ty)
  frame.close:ClearAllPoints(); frame.close:SetPoint("RIGHT", frame, "TOPRIGHT", -5, ty)
  local tgap = wings and -18 or -4 -- room for the wing arrow
  frame.title:SetPoint("RIGHT", frame.mapBtn, "LEFT", tgap, 0)
  if wings then frame.wingBtn:SetWidth(math.min(frame.title:GetStringWidth() or 0, frame.title:GetWidth() or 0) + 18) end
  frame.line:ClearAllPoints(); frame.line:SetPoint("TOPLEFT", 5, -head); frame.line:SetPoint("TOPRIGHT", -5, -head)
  -- the "!" button: the quest statuses only when the quest log changed (Paint(true)) or the dungeon did, not every second (beta53, lean)
  if marksToo or frame.qFor ~= d then
    frame.qFor = d
    local _, open = RT.Quests(d)
    frame.qBtn:SetEnabled(open > 0); frame.qBtn:SetAlpha(open > 0 and 1 or 0.45)
  end
  -- the bosses this character can fight (factionOnly ones of the other faction are left out, 6.2.17); one reused table
  local bosses = wipe(paintBosses)
  for _, b in ipairs(d.bosses or {}) do if not FLT.BossForMe or FLT.BossForMe(b) then bosses[#bosses + 1] = b end end

  -- the rows; in combat the order stays as it is (the target buttons over the rows cannot move then), only their state changes
  local rows, nextB
  if inCombat() and frame.rowsFor == c and frame.lastRows then rows, nextB = frame.lastRows, frame.lastNext
  elseif cf.hideBosses then rows = wipe(rowsBuf)
  else rows, nextB = listRows(bosses, c, RT.MaxVisible(), dur); frame.lastRows, frame.lastNext, frame.rowsFor = rows, nextB, c end
  local log = (marksToo or marksFor ~= d or marksGen ~= (FLT.GearValue and FLT.GearValue.gen)) and questLog() or nil
  if log then wipe(markCache); if marksFor ~= d then wipe(markTries) end end
  local y, nb = -head - 1, 0
  local u = RT._unfold()
  frame.sumDead:Hide(); frame.sumMore:Hide()
  for _, r in ipairs(rows) do
    if r.kind == "boss" then
      nb = nb + 1
      local b = r.boss
      local bb = bossButton(nb)
      bb.boss = b
      bb:ClearAllPoints(); bb:SetPoint("TOPLEFT", 4, y); y = y - ROW_H
      local round = (b.rare or b.optional) and true or false
      if (bb.forBoss ~= b or bb.forRound ~= round) and UI.setBossPortrait then
        bb.forBoss, bb.forRound = b, round
        -- the game's portraits are round: in the square frame the picture is zoomed in so it fills it (user 25.11. 17:25: "haben die
        -- bosse nur runde portraits? das sieht mit dem eckigen etwas seltsam aus"); icons stay as they are
        if UI.setBossPortrait(bb.icon, d, b) and not round and not b.customIcon then bb.icon:SetTexCoord(0.15, 0.85, 0.15, 0.85) end
      end
      setShape(bb, round)
      if round then bb.edge:SetColorTexture(0.70, 0.72, 0.78, 1) else bb.edge:SetColorTexture(0.62, 0.47, 0.20, 1) end
      local k = RT.Killed(c, b)
      local dead = k and true or false
      local isNext = (b == nextB) and not dead
      bb.icon:SetDesaturated(dead); bb.icon:SetAlpha(dead and 0.5 or 1); bb.edge:SetAlpha(dead and 0.5 or 1)
      bb.name:SetText(FLT.Name and FLT.Name(b.name) or b.name)
      if dead then bb.name:SetTextColor(FLT.TextC(0.50, 0.50, 0.50))
      elseif isNext then bb.name:SetTextColor(FLT.TextC(1, 0.82, 0.20))
      elseif b.rare then bb.name:SetTextColor(FLT.TextC(0.40, 0.66, 1))
      else bb.name:SetTextColor(FLT.TextC(0.95, 0.95, 0.93)) end
      bb.bar:SetShown(isNext); bb.tint:SetShown(isNext or (dead and (dur - k) < JUST))
      if dead then bb.tint:SetColorTexture(0.3, 0.9, 0.35, 0.10) else bb.tint:SetColorTexture(1, 0.78, 0.25, 0.10) end
      bb.time:SetText(dead and RT.Clock(k) or ""); bb.time:SetShown(dead)
      -- the marks belong to the boss, not to the row (user 25.11. 17:25: unfolded rows showed no green triangle)
      local mk = markCache[b]
      -- items still loading: again next second, 10 times at most per boss and dungeon (the count outlives the refresh that every
      -- quest log update brings, 6.2.17-beta52: items the server never sends were asked for every second)
      if not mk or (mk.pending and (markTries[b] or 0) < 10) then
        log = log or questLog()
        if mk and mk.pending then markTries[b] = (markTries[b] or 0) + 1 end
        mk = RT.BossMarks(d, b, log, (markTries[b] or 0) >= 10); markCache[b] = mk
        if mk.pending and (markTries[b] or 0) >= 10 then mk.pending = nil end
      end
      local m = markCache[b]
      local right = -8
      bb.up:SetShown(m.up ~= nil and not dead); if m.up and not dead then right = -24 end
      bb.star:ClearAllPoints(); bb.star:SetPoint("RIGHT", right, 0); bb.star:SetShown(m.wish ~= nil and not dead)
      if m.wish and not dead then right = right - 14 end
      bb.quest:ClearAllPoints(); bb.quest:SetPoint("RIGHT", right, 0); bb.quest:SetShown(m.quest ~= nil and not dead)
      if m.quest and not dead then right = right - 14 end
      if dead then right = -8 - (bb.time:GetStringWidth() or 30) - 6 end
      bb.name:SetPoint("RIGHT", right - 2, 0)
      bb:Show()
    else
      local sr = r.kind == "dead" and frame.sumDead or frame.sumMore
      sr:ClearAllPoints(); sr:SetPoint("TOPLEFT", 4, y); y = y - SUM_H
      local openNow = (r.kind == "dead" and u.dead) or (r.kind == "more" and u.more)
      sr.arrow:SetRotation(openNow and 0 or -math.pi / 2)
      sr.arrow:SetShown(r.kind ~= "dead" or r.has); sr:EnableMouse(r.kind ~= "dead" or r.has)
      if r.kind == "dead" then
        sr.text:SetText(string.format(L["%d / %d defeated"], r.n, r.m or r.n)); sr.time:SetText(r.t and RT.Clock(r.t) or "")
        local all = (r.m or 0) > 0 and r.n >= r.m
        sr.text:SetTextColor(FLT.TextC(all and 0.45 or 0.62, all and 1 or 0.62, all and 0.5 or 0.60))
      else sr.text:SetText(r.n > 0 and string.format(L["%d more"], r.n) or L["Fold"]); sr.time:SetText("") end
      sr:Show()
    end
  end
  for i = nb + 1, #frame.bosses do frame.bosses[i]:Hide() end
  if log then marksFor, marksGen = d, FLT.GearValue and FLT.GearValue.gen end

  -- the footer cells you did not hide, side by side
  frame.time:SetText(RT.Clock(dur))
  local best = RT.Stats(d.key, c)
  frame.best:SetText("")
  if c.done and best then
    local diff = dur - best
    frame.best:SetText((diff <= 0 and "|cff4dff60-" or "|cffff5050+") .. RT.Clock(math.abs(diff)) .. "|r")
  end
  frame.time:SetTextColor(FLT.TextC(c.done and 0.45 or 1, 1, c.done and 0.5 or 1))
  frame.xp:SetText(tostring(c.xp or 0))
  local lv = RT.LootValue(c)
  local money = (c.gold or 0) + (lv or 0)
  frame.gold:SetText(shortMoney(money))
  local cols = { { frame.timeL, frame.time, not cf.hideTime }, { frame.xpL, frame.xp, not cf.hideXP }, { frame.goldL, frame.gold, not cf.hideGold } }
  local k = 0
  for _, col in ipairs(cols) do if col[3] then k = k + 1 end end
  local footH = k > 0 and FOOT or 4
  frame.foot:ClearAllPoints(); frame.foot:SetPoint("TOPLEFT", 0, y - 2); frame.foot:SetSize(W, footH)
  frame.foot:SetShown(k > 0)
  -- three cells of the same width (user 25.11. 17:37: "die drei ... gleich gross ... das sieht viel besser aus")
  local cw, i = (W - 8) / math.max(1, k), 0
  for _, col in ipairs(cols) do
    col[1]:SetShown(col[3]); col[2]:SetShown(col[3])
    if col[3] then
      col[1]:ClearAllPoints(); col[1]:SetPoint("TOPLEFT", frame.foot, "TOPLEFT", 4 + i * cw + 6, -6)
      i = i + 1
    end
  end
  for j = 1, 2 do
    local sep = frame.sep[j]
    sep:SetShown(j < k); sep:ClearAllPoints()
    sep:SetPoint("TOPLEFT", frame.foot, "TOPLEFT", 4 + j * cw, -4); sep:SetPoint("BOTTOMLEFT", frame.foot, "BOTTOMLEFT", 4 + j * cw, 4)
  end
  -- the gold stays inside its cell: two coins, or only the largest when they do not fit (digits measured, coins counted)
  if not cf.hideGold then
    local txt = frame.gold:GetText() or ""
    local coins = select(2, txt:gsub("|T", ""))
    frame.goldM:SetText((txt:gsub("|T.-|t", "")))
    if (frame.goldM:GetStringWidth() or 0) + coins * COIN_W > cw - 4 then frame.gold:SetText(shortMoney(money, true)) end
  end
  frame.best:SetShown(not cf.hideTime)
  if (frame.best:GetStringWidth() or 0) > cw - 16 - (frame.timeL:GetStringWidth() or 30) then frame.best:SetText("") end
  frame.grip:SetShown(not cf.locked)
  frame:SetHeight(-(y - 2) + footH)
  syncTargets(d, c)
end

-- after a setting changed (cog)
function RT.Layout() if frame and frame:IsShown() then RT.Paint() end end

function RT.Show()
  if not wanted() then if frame then frame:Hide() end return end
  if not frame then build(); RT._frame = frame; if FLT.LootRolls then FLT.LootRolls.Attach(frame); applyBG() end end
  marksFor = nil
  frame:Show()
  RT._pinTop()
  applyPicture()
  RT.Paint(true)
  if C_Timer and C_Timer.After then C_Timer.After(3, function() RT.Paint(true) end) end -- item data for the marks
  if not ticker and C_Timer and C_Timer.NewTicker then
    ticker = C_Timer.NewTicker(1, function()
      local c = current()
      if not (frame and frame:IsShown() and c) then return end
      if c.done then if ticker then ticker:Cancel(); ticker = nil end end
      RT.Paint()
    end)
  end
  -- the dungeon's quests you have not taken yet: once per run, in the chat
  local c, d = current(), RT.active
  if c and d and not c.toldQuests then
    c.toldQuests = true
    local _, _, missing = RT.Quests(d)
    if #missing > 0 and FLT.Msg then
      FLT.Msg(string.format(L["%d quests for %s are not taken yet (see the tracker)."], #missing, FLT.DungeonName and FLT.DungeonName(d.name) or d.name))
    end
  end
end
function RT.Hide() if frame then frame:Hide() end end

-- /ofa tracker test (6.2.14-beta24, user 23.11.: "testversion ... ein tracker mit 10 bossen"; beta32: "5 verschiedene dungeons zu
-- testen"): each call shows the next of five dungeons (up to 10 bosses and 1 rare each) with a made-up run (nothing saved); after
-- the fifth it closes
local TEST_KEYS = { "rfc", "deadmines", "sfk", "zf", "brd" }
local testPrev, testIdx
-- ends the test: back to the real dungeon you are in (or none)
function RT.EndTest()
  if not RT.testRun then return end
  RT.testRun, RT.active, testIdx, RT.closed = nil, testPrev, nil, nil
  if lootPop then lootPop:Hide() end
  if markPop then markPop:Hide() end
  if RT.active then buildNames(RT.active) end
  marksFor = nil
end
function RT.Test()
  testIdx = (RT.testRun and testIdx or 0) + 1
  local real = testIdx <= #TEST_KEYS and dungeonByKey(TEST_KEYS[testIdx])
  if not real then
    if RT.testRun then
      RT.EndTest()
      if RT.active then RT.Show() else RT.Hide() end
    end
    testIdx = nil
    return
  end
  local bosses, rare = {}, nil
  for _, b in ipairs(real.bosses or {}) do
    if b.rare then rare = rare or b elseif #bosses < 10 then bosses[#bosses + 1] = b end
  end
  if rare then bosses[#bosses + 1] = rare end
  if not RT.testRun then testPrev = RT.active end
  RT.closed = nil
  RT.active = setmetatable({ bosses = bosses, _real = real }, { __index = real })
  RT.testRun = { key = real.key, t0 = now() - 229, last = now(), open = true, xp = 1466, gold = 3535, deaths = 0, trash = 12,
    kills = { [bosses[1] and bosses[1].name or ""] = 61 }, loot = {} }
  if lootPop then lootPop:Hide() end
  if markPop then markPop:Hide() end
  buildNames(RT.active)
  marksFor = nil
  RT.Show()
end
-- /ofa tracker: hide or show the tracker in the current run (user 23.11.: "/ofa tracker waere gut um den tracker ein- und
-- auszublenden"); it also brings it back after its X
function RT.Toggle()
  local c = current()
  if not (RT.active and c) then if FLT.Msg then FLT.Msg(L["The dungeon tracker shows in dungeons and raids only."]) end return end
  if not (FLT.QoL and FLT.QoL.Get and FLT.QoL.Get("runTracker")) then
    if FLT.Msg then FLT.Msg(L["The dungeon tracker is off: Quality of Life > Interface > Dungeon tracker."]) end
    return
  end
  RT.closed = (frame and frame:IsShown()) and true or nil
  if RT.closed then RT.Hide() else RT.Show() end
end
if FLT.QoL and FLT.QoL.On then FLT.QoL.On("runTracker", function() if RT.active then RT.Show() end end) end
