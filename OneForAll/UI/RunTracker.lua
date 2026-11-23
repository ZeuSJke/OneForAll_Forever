local ADDON, FLT = ...
-- 6.2.14 (user 23.11.2026: "so einen tracker machen wie dungeon journal hat" - the idea only, Dungeon Journal has no licence;
-- own code): every visit of a dungeon or raid is a run - time, bosses, mobs, XP, gold, deaths, loot - kept per character
-- (OneForAllCharDB.runs, newest first, History in Dungeons & Raids). The small tracker window shows the run (QoL "runTracker"):
-- time with the best time, mobs' XP (gold at level 60), the dungeon quests in your log, the instances of this hour, and a
-- portrait per boss - crossed off when dead, a green arrow when it drops an upgrade, a star for your wishlist, "!" when a quest
-- in your log needs it. Left-click: OneForAll on that boss, right-click: its loot.
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

local MAX_RUNS, CAP, CAP_TIME, RESUME = 100, 5, 3600, 3600
local W, H = 236, 104 -- the size of Dungeon Journal's tracker (user 23.11.: "wieder schmaler machen wie dungeon journal")

local function now() return time() end
local function runs()
  if type(OneForAllCharDB) ~= "table" then return nil end
  OneForAllCharDB.runs = type(OneForAllCharDB.runs) == "table" and OneForAllCharDB.runs or {}
  return OneForAllCharDB.runs
end
local function current()
  if RT.testRun then return RT.testRun end -- /ofa tracker test (6.2.14-beta24)
  local r = runs(); local c = r and r[1]; return c and c.open and c or nil
end
local function dungeonByKey(key) for _, d in ipairs(FLT.DUNGEONS or {}) do if d.key == key then return d end end end
RT.Runs, RT.Current, RT.DungeonByKey = runs, current, dungeonByKey

-- the run's length: to its end, or to now while you are in it
function RT.Duration(c)
  if not c then return 0 end
  local stop = c.t1 or (c.open and RT.active and now()) or c.last or c.t0
  return math.max(0, (stop or 0) - (c.t0 or 0))
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
      local d = c.t1 - c.t0
      if d > 0 then n = n + 1; sum = sum + d; if not best or d < best then best = d end end
    end
  end
  return best, n > 0 and sum / n or nil, n
end

-- the instances you entered in the last hour (the game allows CAP new ones per hour, account wide). One entry per instance
-- copy (its ID from the creatures' GUIDs), so going in and out of the same copy counts once (user 23.11.: "kann man das nicht
-- im hintergrund anhand der instance ID machen?")
local function capList()
  if type(OneForAllDB) ~= "table" then return {} end
  local t = type(OneForAllDB.instCap) == "table" and OneForAllDB.instCap or {}
  OneForAllDB.instCap = t
  local cut, n = now() - CAP_TIME, 0
  for i = 1, #t do local e = t[i]; if type(e) == "table" and (e.t or 0) > cut then n = n + 1; t[n] = e end end
  for i = #t, n + 1, -1 do t[i] = nil end
  return t
end
local function capAdd(uid, t)
  local list = capList()
  for _, e in ipairs(list) do if e.uid == uid then return end end
  list[#list + 1] = { uid = uid, t = t or now() }
  table.sort(list, function(a, b) return a.t < b.t end)
end
function RT.CapInfo()
  local t = capList()
  return #t, CAP, t[1] and (t[1].t + CAP_TIME - now()) or nil
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
local INNER = { "ENCOUNTER_END", "BOSS_KILL", "PARTY_KILL", "UNIT_DIED", "CHAT_MSG_COMBAT_HOSTILE_DEATH", "CHAT_MSG_COMBAT_XP_GAIN",
  "PLAYER_DEAD", "PLAYER_MONEY", "CHAT_MSG_LOOT", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "PLAYER_EQUIPMENT_CHANGED", "QUEST_LOG_UPDATE",
  "LOOT_OPENED" }
-- the units you see (copy ID, boss names, dead bosses, rares) - inside instances only, each a quick look at one GUID
local SEEK = { "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT", "NAME_PLATE_UNIT_ADDED" }
local lastMoney, visitT0, partyKills, lastPartyKill = nil, nil, false, 0

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
local function allDown(c, d)
  local any = false
  for _, b in ipairs(d and d.bosses or {}) do
    if not b.rare then any = true; if not RT.Killed(c, b) then return false end end
  end
  return any
end

local function start(d, t0)
  local r = runs(); if not r then return end
  local c = { key = d.key, t0 = t0 or now(), last = now(), open = true, xp = 0, gold = 0, deaths = 0, trash = 0, kills = {}, loot = {},
    party = (IsInGroup and IsInGroup()) and true or nil, lvl = UnitLevel and UnitLevel("player") or nil }
  table.insert(r, 1, c)
  for i = #r, MAX_RUNS + 1, -1 do r[i] = nil end
  return c
end

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
  capAdd(uid, visitT0)
  if RT.Show then RT.Show() end
  if RT.onChange then RT.onChange() end
end
local kill
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
    c.uid = uid
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
  if not (c and c.key == d.key and (now() - (c.last or 0) < RESUME or c.uid)) then
    if c then close(c) end
    c = start(d, visitT0)
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
    -- the copy never showed (no creature seen): the run still counts as one instance, once
    if not RT.uid and not c.uid then capAdd("run" .. (c.t0 or 0), c.t0) end
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
  if b and not c.kills[b.name] then
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
    if not (npc and (npcs[npc] or sibNpc[npc])) then c.trash = (c.trash or 0) + 1; lastPartyKill = now() end
    if npc then kill(nil, npc) end
    if RT.Paint then RT.Paint() end
  elseif event == "UNIT_DIED" then
    local npc, uid, map = parseGUID(a1)
    if uid then learnCopy(uid, map) end
    if npc then wingSign(npc, 2) end
    if npc and (npcs[npc] or sibNpc[npc]) then kill(nil, npc) end
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
    if who and not kill(who) and not partyKills then c.trash = (c.trash or 0) + 1; if RT.Paint then RT.Paint() end end
  elseif event == "CHAT_MSG_COMBAT_XP_GAIN" then
    local text = plain(a1)
    if type(text) ~= "string" then return end
    xpPat = xpPat or pattern(COMBATLOG_XPGAIN_FIRSTPERSON or "%s dies, you gain %d experience.")
    local who = xpPat and text:match(xpPat)
    if who then kill(who) end -- a boss by its name in the XP line
    local n = tonumber(text:match("(%d+)"))
    if n then c.xp = (c.xp or 0) + n; if RT.Paint then RT.Paint() end end
  elseif event == "PLAYER_DEAD" then
    c.deaths = (c.deaths or 0) + 1
  elseif event == "PLAYER_MONEY" then
    local m = GetMoney and GetMoney()
    if m and lastMoney and m > lastMoney then c.gold = (c.gold or 0) + m - lastMoney; if RT.Paint then RT.Paint() end end
    lastMoney = m
  elseif event == "CHAT_MSG_LOOT" then
    local text = plain(a1)
    lootPat = lootPat or pattern(LOOT_ITEM_SELF or "You receive loot: %s.")
    lootPat2 = lootPat2 or pattern(LOOT_ITEM_SELF_MULTIPLE or "You receive loot: %sx%d.")
    local link = type(text) == "string" and ((lootPat2 and text:match(lootPat2)) or (lootPat and text:match(lootPat)))
    local id = link and tonumber(link:match("item:(%d+)"))
    local q = id and C_Item and C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(id)
    if id and (q == nil or q >= 2) then c.loot[#c.loot + 1] = id end
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
function RT.BossMarks(d, b, log)
  local m = {}
  local GV = FLT.GearValue
  for _, it in ipairs(b.loot or {}) do
    local id = type(it) == "table" and (it.id or it[1]) -- DungeonData records {id, name, quality, slot}
    if id then
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
local frame, ticker, lootPop
local function cfg()
  if type(OneForAllDB) ~= "table" then return {} end
  OneForAllDB.runTracker = type(OneForAllDB.runTracker) == "table" and OneForAllDB.runTracker or {}
  return OneForAllDB.runTracker
end
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
-- the boss tooltip hangs at the portrait's top right corner (like Dungeon Journal; user 23.11.)
local function bossTip(self)
  local d, b, c = RT.active, self.boss, current()
  if not (d and b) then return end
  cornerTip(self)
  GameTooltip:AddLine(FLT.Name and FLT.Name(b.name) or b.name, 1, 0.82, 0.2)
  if b.rare then GameTooltip:AddLine(L["Rare - not there every time"], 0.78, 0.80, 0.86) end
  if b.rare and c and c.rareSeen and c.rareSeen[b.name] and not RT.Killed(c, b) then GameTooltip:AddLine(L["Seen in this run"], 0.85, 0.9, 1) end
  local k = RT.Killed(c, b)
  if k then GameTooltip:AddLine(string.format(L["Killed after %s"], RT.Clock(k)), 0.45, 1, 0.5) end
  -- the green arrow tells about an upgrade; which item shows in the loot window (user 23.11.: "der pfeil reicht")
  local m = self.marks or {}
  if m.wish then GameTooltip:AddLine(string.format(L["On your wishlist: %s"], GetItemInfo and GetItemInfo(m.wish) or ("item " .. m.wish)), 1, 0.82, 0.2) end
  if m.quest then GameTooltip:AddLine(string.format(L["Quest: %s"], m.quest), 1, 0.82, 0.2) end
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine(L["Left-click: open in OneForAll"], 0.8, 0.8, 0.8)
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
local PIC_H = 118
-- first-time settings (user 23.11. 15:02): 5 bosses per row, 75 % opacity, the dungeon picture on, everything else off
local function applyPicture()
  if not (frame and frame.pic) then return end
  local d = RT.active and (RT.active._real or RT.active)
  local on = cfg().picture ~= false and d and UI.SetDungeonPicture and UI.SetDungeonPicture(frame.pic, d.key, W - 8, PIC_H)
  frame.pic:SetShown(on and true or false)
  if on and UI.AlphaFade then UI.AlphaFade(frame.pic, "VERTICAL", 0, 0.9 * (cfg().bgAlpha or 0.75)) end
end
local function applyBG()
  local a = 0.96 * (cfg().bgAlpha or 0.75)
  if frame and frame.bg then frame.bg:SetColor(0.045, 0.045, 0.055, a) end
  if lootPop and lootPop.bg then lootPop.bg:SetColor(0.045, 0.045, 0.055, a) end
  applyPicture()
end

local function showLoot(btn)
  local b = btn.boss
  if lootPop and lootPop:IsShown() and lootPop.boss == b then lootPop:Hide(); return end
  if not lootPop then
    lootPop = CreateFrame("Frame", nil, frame)
    lootPop._ofaNoBG = true
    lootPop.bg = UI.UnmarkBG(UI.FramedPanel(lootPop))
    applyBG()
    lootPop.items = {}
    lootPop:SetFrameStrata("DIALOG")
    lootPop:SetToplevel(true)
    lootPop.face = UI.CreateBossFrame(lootPop, 28, false, true); lootPop.face:SetSize(28, 28); lootPop.face:SetPoint("TOPLEFT", 6, -5)
    -- hover: only the boss's name (user 23.11.: "unten im boss icon tooltip mit namen, also nur der name")
    lootPop.face:EnableMouse(true)
    lootPop.face:SetScript("OnEnter", function(self)
      local fb = lootPop.boss; if not fb then return end
      cornerTip(self); GameTooltip:AddLine(FLT.Name and FLT.Name(fb.name) or fb.name, 1, 0.82, 0.2); GameTooltip:Show()
    end)
    lootPop.face:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- right-click the portrait (or anywhere on the window): close it (user 23.11.)
    local function closeOnRight(_, button) if button == "RightButton" then GameTooltip:Hide(); lootPop:Hide() end end
    lootPop.face:SetScript("OnMouseUp", closeOnRight)
    lootPop:EnableMouse(true); lootPop:SetScript("OnMouseUp", closeOnRight)
  end
  lootPop:SetFrameLevel((frame:GetFrameLevel() or 0) + 30)
  lootPop.boss = b
  if UI.setBossPortrait then UI.setBossPortrait(lootPop.face.portrait, RT.active and RT.active._real or RT.active, b) end
  if b.rare then lootPop.face.ring:SetVertexColor(0.78, 0.80, 0.86, 1) else lootPop.face.ring:SetVertexColor(FLT.SkinC(0.86, 0.66, 0.28, 1)) end
  local GV = FLT.GearValue
  local n = 0
  for _, it in ipairs(b.loot or {}) do
    local id = type(it) == "table" and (it.id or it[1]) -- DungeonData records {id, name, quality, slot}
    if id then
      n = n + 1
      local ib = lootPop.items[n]
      if not ib then
        ib = CreateFrame("Button", nil, lootPop); ib:SetSize(26, 26)
        ib.icon = ib:CreateTexture(nil, "ARTWORK"); ib.icon:SetPoint("TOPLEFT", 1, -1); ib.icon:SetPoint("BOTTOMRIGHT", -1, 1)
        ib.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        ib.edge = ib:CreateTexture(nil, "BACKGROUND"); ib.edge:SetAllPoints()
        ib.up = ib:CreateTexture(nil, "OVERLAY"); ib.up:SetSize(12, 12); ib.up:SetPoint("TOPLEFT", -2, 2)
        FLT.SetTex(ib.up, UI.ASSET_ROOT .. "icon_arrow_up")
        ib:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        ib:SetScript("OnEnter", function(self)
          GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
          if GameTooltip.SetItemByID then GameTooltip:SetItemByID(self.id) else GameTooltip:SetHyperlink("item:" .. self.id) end
          GameTooltip:Show()
        end)
        ib:SetScript("OnLeave", function() GameTooltip:Hide() end)
        ib:SetScript("OnClick", function(self) if IsModifiedClick and IsModifiedClick() and HandleModifiedItemClick then
          local link = GetItemInfo and select(2, GetItemInfo(self.id)); if link then HandleModifiedItemClick(link) end end end)
        lootPop.items[n] = ib
      end
      ib.id = id
      ib:ClearAllPoints(); ib:SetPoint("TOPLEFT", 40 + (n - 1) * 29, -6)
      ib.icon:SetTexture((C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)) or "Interface\\Icons\\INV_Misc_QuestionMark")
      local q = it.quality or it[4]
      q = type(q) == "number" and q or 1
      local r, g, bl = qualityColor(q)
      ib.edge:SetColorTexture(r, g, bl, 0.9)
      local up = false
      if GV and GV.Change then local ok, kind = pcall(GV.Change, id); up = ok and (kind == "up" or kind == "new") end
      ib.up:SetShown(up)
      ib:Show()
    end
  end
  for i = n + 1, #lootPop.items do lootPop.items[i]:Hide() end
  if n == 0 then lootPop:Hide(); return end
  lootPop:SetSize(46 + n * 29 - 3, 38)
  lootPop:ClearAllPoints()
  if (frame:GetBottom() or 100) * (frame:GetEffectiveScale() or 1) < 60 then
    lootPop:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 2) -- no room below the tracker: over it
  else
    lootPop:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -2)
  end
  lootPop:Show()
  return n
end
RT._showLoot = showLoot -- tests

-- gold in the tracker: the two largest coins only (it is a small column)
local COIN_G, COIN_S, COIN_C = "|TInterface\\MoneyFrame\\UI-GoldIcon:0|t", "|TInterface\\MoneyFrame\\UI-SilverIcon:0|t", "|TInterface\\MoneyFrame\\UI-CopperIcon:0|t"
local function shortMoney(c)
  c = math.floor(tonumber(c) or 0)
  local g, si, cu = math.floor(c / 10000), math.floor(c / 100) % 100, c % 100
  if g > 0 then return g .. COIN_G .. (si > 0 and (" " .. si .. COIN_S) or "") end
  if si > 0 then return si .. COIN_S .. (cu > 0 and (" " .. cu .. COIN_C) or "") end
  return cu .. COIN_C
end
RT._shortMoney = shortMoney -- tests

local function capTip(self)
  local n, max, left = RT.CapInfo()
  cornerTip(self)
  GameTooltip:AddLine(string.format(L["Instances this hour: %d / %d"], n, max), 1, 0.82, 0.2)
  GameTooltip:AddLine(string.format(L["The game lets you enter %d new instances per hour."], max), 0.9, 0.9, 0.9, true)
  if left and n >= 1 then GameTooltip:AddLine(string.format(L["Next free instance in %s."], RT.Clock(left)), 0.8, 0.8, 0.8) end
  GameTooltip:Show()
end
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

local function build()
  frame = CreateFrame("Frame", "OneForAllRunTracker", UIParent)
  frame:SetSize(W, H); frame:SetFrameStrata("MEDIUM"); frame:SetClampedToScreen(true)
  frame:SetMovable(true); frame:EnableMouse(true); frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function(self) if not cfg().locked then self:StartMoving() end end)
  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    RT._pinTop()
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
  close:SetSize(18, 16); close:SetPoint("TOPRIGHT", -5, -6)
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
  frame.qBtn = iconButton("Interface\\GossipFrame\\AvailableQuestIcon", 12, close,
    function() if RT.active then openBoss(RT.active, nil, "quests") end end, questTip)
  frame.mapBtn = iconButton(UI.ASSET_ROOT .. "icon_map", 12, frame.qBtn,
    function() if RT.active then openBoss(RT.active, nil, "map") end end, function(self)
      cornerTip(self); GameTooltip:AddLine(L["Map"], 1, 0.82, 0.2)
      GameTooltip:AddLine(L["Click: show the dungeon map in OneForAll"], 0.8, 0.8, 0.8); GameTooltip:Show()
    end)
  frame.cap = CreateFrame("Button", nil, frame); frame.cap:SetSize(26, 16); frame.cap:SetPoint("RIGHT", frame.mapBtn, "LEFT", -3, 0)
  frame.cap.text = FLT.NewFS(frame.cap, nil, "OVERLAY", "GameFontHighlightSmall"); frame.cap.text:SetPoint("RIGHT")
  frame.cap:SetScript("OnEnter", capTip); frame.cap:SetScript("OnLeave", function() GameTooltip:Hide() end)
  frame.title:SetPoint("RIGHT", frame.cap, "LEFT", -4, 0)

  local function column(x, label)
    -- the labels in a light warm tone with a shadow: the grey hardly showed on the dungeon pictures (user 23.11.)
    local l = FLT.NewFS(frame, nil, "OVERLAY", "GameFontHighlightSmall"); l:SetPoint("TOPLEFT", x, -30); l:SetText(label)
    l:SetTextColor(FLT.TextC(0.90, 0.82, 0.62))
    local v = FLT.NewFS(frame, nil, "OVERLAY", "GameFontHighlightLarge"); v:SetPoint("TOPLEFT", l, "BOTTOMLEFT", 0, -2)
    return l, v
  end
  frame.timeL, frame.time = column(10, L["Time"])
  -- the best time / the difference sits next to the label, so the values fit in one row
  frame.best = FLT.NewFS(frame, nil, "OVERLAY", "GameFontHighlightSmall"); frame.best:SetTextColor(FLT.TextC(0.85, 0.85, 0.85)); frame.best:SetPoint("LEFT", frame.timeL, "RIGHT", 4, 0)
  frame.xpL, frame.xp = column(96, L["Mobs XP"])
  frame.goldL, frame.gold = column(164, L["Gold"])
  -- the cog: the tracker's settings (user 23.11.: "das zahnrad hernehmen um ... mehrere optionen einstellen zu koennen": hide time /
  -- XP / gold / bosses, bosses per row 4-6, lock, opacity); its window opens on a click only, over the tracker
  applyBG()
  local ob = CreateFrame("Button", nil, frame); ob:SetSize(14, 14); frame.cog = ob
  ob:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton"); ob:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
  ob:SetScript("OnEnter", function(self) cornerTip(self); GameTooltip:AddLine(L["Settings"], 1, 0.82, 0.2); GameTooltip:Show() end)
  ob:SetScript("OnLeave", function() GameTooltip:Hide() end)
  ob:SetScript("OnClick", function()
    local pop = frame.opPop
    if not pop then
      pop = CreateFrame("Frame", nil, frame); pop._ofaNoBG = true; UI.FramedPanel(pop)
      pop:SetFrameStrata("DIALOG"); pop:SetToplevel(true); pop:EnableMouse(true)
      local y = -8
      local checks = {}
      local function check(key, label)
        local cb = FLT.SkinBlizz(CreateFrame("CheckButton", nil, pop, "UICheckButtonTemplate")); cb:SetSize(20, 20)
        cb:SetPoint("TOPLEFT", 8, y)
        local t = FLT.NewFS(pop, nil, "OVERLAY", "GameFontHighlightSmall"); t:SetPoint("LEFT", cb, "RIGHT", 4, 0); t:SetText(label)
        cb:SetScript("OnClick", function(self)
          if key == "picture" then cfg().picture = self:GetChecked() and true or false; applyPicture(); return end
          cfg()[key] = self:GetChecked() and true or nil
          RT.Layout()
        end)
        checks[key] = cb
        y = y - 22
      end
      check("hideTime", L["Hide time"]); check("hideXP", L["Hide XP"]); check("hideGold", L["Hide gold"])
      check("hideBosses", L["Hide bosses"]); check("locked", L["Lock tracker"])
      check("picture", L["Show dungeon picture"])
      local function slider(label, minV, maxV, step, get, set)
        local t = FLT.NewFS(pop, nil, "OVERLAY", "GameFontHighlightSmall"); t:SetPoint("TOPLEFT", 12, y - 4); t:SetText(label)
        local v = FLT.NewFS(pop, nil, "OVERLAY", "GameFontHighlightSmall"); v:SetPoint("TOPRIGHT", -10, y - 4)
        local sl = UI.Slider(pop, 176, minV, maxV, step, function(val) set(val); v:SetText(get(true)) end)
        sl:SetPoint("TOPLEFT", 10, y - 18)
        y = y - 42
        return sl, v
      end
      pop.perRow = slider(L["Bosses per row"], 4, 6, 1, function(txt) return tostring(cfg().perRow or 5) end,
        function(val) cfg().perRow = val; RT.Paint() end)
      pop.alpha = slider(L["Opacity"], 0, 100, 5, function() return math.floor((cfg().bgAlpha or 0.75) * 100 + 0.5) .. "%" end,
        function(val) cfg().bgAlpha = val / 100; applyBG() end)
      pop:SetSize(196, -y + 6)
      pop:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", 0, 2)
      pop.checks = checks
      -- a click anywhere else closes it (user 23.11.: "auch geschlossen werden wenn man irgendwo anders hinklickt"); the cog's own
      -- click still toggles it
      pop:SetScript("OnEvent", function(self)
        if not self:IsMouseOver() and not frame.cog:IsMouseOver() then self:Hide() end
      end)
      pop:SetScript("OnShow", function(self) pcall(self.RegisterEvent, self, "GLOBAL_MOUSE_DOWN") end)
      pop:SetScript("OnHide", function(self) self:UnregisterAllEvents() end)
      frame.opPop = pop
      pop:Hide()
    end
    if pop:IsShown() then pop:Hide(); return end
    pop:SetFrameLevel((frame:GetFrameLevel() or 0) + 30)
    for key, cb in pairs(pop.checks) do
      if key == "picture" then cb:SetChecked(cfg().picture ~= false) else cb:SetChecked(cfg()[key] and true or false) end
    end
    pop.perRow:SetValue(cfg().perRow or 5)
    pop.alpha:SetValue(math.floor((cfg().bgAlpha or 0.75) * 100 + 0.5))
    pop:Show()
  end)
  frame.line = frame:CreateTexture(nil, "ARTWORK"); frame.line:SetColorTexture(0.50, 0.38, 0.19, 0.55); frame.line:SetHeight(1)
  frame.line:SetPoint("TOPLEFT", 9, -64); frame.line:SetPoint("TOPRIGHT", -9, -64)

  frame.bosses = {}
  frame.rareL = FLT.NewFS(frame, nil, "OVERLAY", "GameFontHighlightSmall"); frame.rareL:SetText(L["Rare"])
  frame.rareL:SetTextColor(FLT.TextC(0.90, 0.82, 0.62))
  -- the corner: drag to resize (the scale, 60 - 200 %); the top left corner stays where it is and the bottom right corner
  -- follows the mouse (user 23.11.: it ran away from the cursor while the frame was anchored at its top right)
  local grip = CreateFrame("Button", nil, frame); grip:SetSize(14, 14); grip:SetPoint("BOTTOMRIGHT", -2, 2); frame.grip = grip
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
      frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left / (s * pe), top / (s * pe))
    end)
  end)
  grip:SetScript("OnMouseUp", function(self)
    self:SetScript("OnUpdate", nil)
    cfg().scale = frame:GetScale()
    local p, _, rp, x, y = frame:GetPoint(); cfg().pos = { p, rp, x, y }
  end)
  frame:SetScript("OnHide", function()
    if ticker then ticker:Cancel(); ticker = nil end
    if lootPop then lootPop:Hide() end
    if frame.opPop then frame.opPop:Hide() end
  end)
end

local function bossButton(i)
  local bb = frame.bosses[i]
  if bb then return bb end
  bb = CreateFrame("Button", nil, frame)
  bb:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  bb.f = UI.CreateBossFrame(bb, 32, false, true); bb.f:SetAllPoints()
  bb.f:EnableMouse(false)
  -- the marks lie on their own layer above the portrait frame (on the button itself they were behind it; user 23.11.)
  local ov = CreateFrame("Frame", nil, bb); ov:SetAllPoints(); ov:SetFrameLevel((bb.f:GetFrameLevel() or 0) + 2); bb.ov = ov
  -- a rare boss seen alive in this run: a soft glow around its portrait
  bb.glow = ov:CreateTexture(nil, "OVERLAY", nil, 1); bb.glow:SetPoint("CENTER"); bb.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
  bb.glow:SetBlendMode("ADD"); bb.glow:SetVertexColor(0.85, 0.9, 1, 0.9); bb.glow:Hide()
  bb.x = ov:CreateTexture(nil, "OVERLAY", nil, 3); bb.x:SetPoint("CENTER"); bb.x:SetTexture("Interface\\RaidFrame\\ReadyCheck-NotReady")
  bb.up = ov:CreateTexture(nil, "OVERLAY", nil, 4); bb.up:SetPoint("BOTTOMRIGHT", 3, -3); FLT.SetTex(bb.up, UI.ASSET_ROOT .. "icon_arrow_up")
  bb.star = ov:CreateTexture(nil, "OVERLAY", nil, 4); bb.star:SetPoint("TOPRIGHT", 3, 3); FLT.SetTex(bb.star, UI.ASSET_ROOT .. "icon_star")
  bb.quest = ov:CreateTexture(nil, "OVERLAY", nil, 4); bb.quest:SetPoint("TOPLEFT", -4, 4); bb.quest:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")
  bb:SetScript("OnEnter", bossTip); bb:SetScript("OnLeave", function() GameTooltip:Hide() end)
  bb:SetScript("OnClick", function(self, button)
    if button == "RightButton" then showLoot(self) else openBoss(RT.active, self.boss) end
  end)
  frame.bosses[i] = bb
  return bb
end

-- the boss portraits: perRow (4-6, the cog's slider, 5 by default - user 23.11. 14:33 "standard bosse per row 5"; user 23.11.: "portraits sollen dynamisch angepasst werden") in the window's
-- width, more rows when there are more; the rare bosses below under "Rare", 3/4 the size with a silver ring (user 23.11.: "eine extra
-- spalte fuer rare bosse"). top: where the portraits start. Returns the layout and the window's height.
local function bossGrid(nMain, nRare, perRow, top)
  perRow = math.max(4, math.min(6, tonumber(perRow) or 5)); top = top or -70
  local g = { gap = 4, perRow = perRow }
  g.size = math.floor((W - 16 - (perRow - 1) * g.gap) / perRow)
  g.rsize = math.floor(g.size * 0.75)
  g.rPerRow = math.max(1, math.floor((W - 16 + g.gap) / (g.rsize + g.gap)))
  g.top = top
  local rows = math.ceil(nMain / g.perRow)
  local y = top - rows * (g.size + g.gap) -- below the main rows
  if nMain == 0 then y = top end
  if nRare > 0 then
    g.rareLabelY = y - 2
    g.rareTop = y - 16
    local rr = math.ceil(nRare / g.rPerRow)
    g.height = -g.rareTop + rr * g.rsize + (rr - 1) * g.gap + 8
  else
    g.height = (nMain > 0) and (-y - g.gap + 8) or (-top + 4)
  end
  return g
end
RT._bossGrid = bossGrid -- tests

local marksFor, marksGen = nil, nil
function RT.Paint(marksToo)
  if not (frame and frame:IsShown()) then return end
  local d, c = RT.active, current()
  if not (d and c) then return end
  frame.title:SetText(FLT.DungeonName and FLT.DungeonName(d.name) or d.name)
  local wings = not RT.testRun and RT.Wings(d)
  frame.wingBtn:SetShown(wings and true or false)
  if not wings and frame.wingPop then frame.wingPop:Hide() end
  local dur = RT.Duration(c)
  frame.time:SetText(RT.Clock(dur))
  local best = RT.Stats(d.key, c)
  if c.done and best then
    local diff = dur - best
    frame.best:SetText((diff <= 0 and "|cff4dff60-" or "|cffff5050+") .. RT.Clock(math.abs(diff)) .. "|r")
  elseif best then frame.best:SetText(string.format(L["Best %s"], RT.Clock(best)))
  else frame.best:SetText("") end
  frame.time:SetTextColor(FLT.TextC(c.done and 0.45 or 1, 1, c.done and 0.5 or 1))
  frame.xp:SetText(tostring(c.xp or 0))
  frame.gold:SetText(shortMoney(c.gold))
  local _, open = RT.Quests(d)
  frame.qBtn:SetEnabled(open > 0); frame.qBtn:SetAlpha(open > 0 and 1 or 0.45)
  local n, max = RT.CapInfo()
  frame.cap.text:SetText(n .. "/" .. max)
  frame.cap.text:SetTextColor(FLT.TextC(n >= max and 1 or 0.88, n >= max and 0.35 or 0.88, n >= max and 0.3 or 0.88))
  -- portraits: always 32 px, as many per row as fit (6), more rows when there are more bosses - the window grows downward
  -- (user 23.11.: "so anpassen dass das fenster waechst"; Blackrock Depths would have tiny portraits in one row); rare bosses
  -- in their own row below
  -- the columns you did not hide, from the left (the cog's settings)
  local cf = cfg()
  local cols = { { frame.timeL, frame.time, not cf.hideTime }, { frame.xpL, frame.xp, not cf.hideXP }, { frame.goldL, frame.gold, not cf.hideGold } }
  local X, k = { 10, 96, 164 }, 0
  for _, col in ipairs(cols) do
    col[1]:SetShown(col[3]); col[2]:SetShown(col[3])
    if col[3] then k = k + 1; col[1]:ClearAllPoints(); col[1]:SetPoint("TOPLEFT", X[k], -30) end
  end
  frame.best:SetShown(not cf.hideTime)
  local stats = k > 0
  frame.cog:ClearAllPoints()
  local tgap = wings and -18 or -4 -- room for the wing arrow
  if stats then frame.cog:SetPoint("TOPRIGHT", -8, -29); frame.title:SetPoint("RIGHT", frame.cap, "LEFT", tgap, 0)
  else frame.cog:SetPoint("RIGHT", frame.cap, "LEFT", -2, 0); frame.title:SetPoint("RIGHT", frame.cog, "LEFT", tgap, 0) end
  if wings then frame.wingBtn:SetWidth(math.min(frame.title:GetStringWidth() or 0, frame.title:GetWidth() or 0) + 18) end
  frame.grip:SetShown(not cf.locked)
  local bosses = cf.hideBosses and {} or (d.bosses or {})
  frame.line:SetShown(stats and #bosses > 0)
  local nb, nRare = #bosses, 0
  for _, b in ipairs(bosses) do if b.rare then nRare = nRare + 1 end end
  local g = bossGrid(nb - nRare, nRare, cf.perRow, stats and -70 or -32)
  if #bosses == 0 then g.height = stats and 66 or 32 end
  local gap = g.gap
  local log = (marksToo or marksFor ~= d or marksGen ~= (FLT.GearValue and FLT.GearValue.gen)) and questLog() or nil
  frame.rareL:SetShown(nRare > 0)
  if nRare > 0 then frame.rareL:ClearAllPoints(); frame.rareL:SetPoint("TOPLEFT", 10, g.rareLabelY) end
  local mi, ri = 0, 0
  for i, b in ipairs(bosses) do
    local bb = bossButton(i)
    bb.boss = b
    local size
    bb:ClearAllPoints()
    if b.rare then
      size = g.rsize
      bb:SetPoint("TOPLEFT", 8 + (ri % g.rPerRow) * (size + gap), g.rareTop - math.floor(ri / g.rPerRow) * (size + gap)); ri = ri + 1
      bb.f.ring:SetVertexColor(0.78, 0.80, 0.86, 1)
    else
      size = g.size
      bb:SetPoint("TOPLEFT", 8 + (mi % g.perRow) * (size + gap), g.top - math.floor(mi / g.perRow) * (size + gap)); mi = mi + 1
      bb.f.ring:SetVertexColor(FLT.SkinC(0.86, 0.66, 0.28, 1))
    end
    bb:SetSize(size, size)
    if bb.forBoss ~= b and UI.setBossPortrait then UI.setBossPortrait(bb.f.portrait, d, b); bb.forBoss = b end
    local dead = RT.Killed(c, b) and true or false
    bb.f.portrait:SetDesaturated(dead); bb.f:SetAlpha(dead and 0.55 or 1)
    bb.x:SetSize(size * 0.7, size * 0.7); bb.x:SetShown(dead)
    bb.glow:SetSize(size * 1.75, size * 1.75); bb.glow:SetShown(b.rare and not dead and c.rareSeen and c.rareSeen[b.name] and true or false)
    if log then bb.marks = RT.BossMarks(d, b, log) end
    local m = bb.marks or {}
    local ms = math.max(10, math.floor(size * 0.42))
    bb.up:SetSize(ms, ms); bb.star:SetSize(ms, ms); bb.quest:SetSize(ms + 2, ms + 2)
    bb.up:SetShown(m.up ~= nil and not dead); bb.star:SetShown(m.wish ~= nil and not dead); bb.quest:SetShown(m.quest ~= nil and not dead)
    bb:Show()
  end
  for i = nb + 1, #frame.bosses do frame.bosses[i]:Hide() end
  if log then marksFor, marksGen = d, FLT.GearValue and FLT.GearValue.gen end
  frame:SetHeight(g.height)
end

-- after a setting changed (cog)
function RT.Layout() if frame and frame:IsShown() then RT.Paint() end end

function RT.Show()
  if not wanted() then if frame then frame:Hide() end return end
  if not frame then build(); RT._frame = frame end
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
  RT.testRun = { key = real.key, t0 = now() - 229, last = now(), open = true, xp = 1466, gold = 197, deaths = 0, trash = 12,
    kills = { [bosses[1] and bosses[1].name or ""] = 61 }, loot = {} }
  if lootPop then lootPop:Hide() end
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
