local _, FLT = ...
local L = FLT.L or setmetatable({}, { __index = function(_, k) return k end }) -- (tests without Locales)

-- Quest icons on the world map (6.0.2, user 01.11.; wish from Discord, "like Questie"): a yellow "!" at quest givers
-- with a quest you can take now - only quests for your level (not grey, not too high), your side, race and class,
-- pre-quests done, not done or in the log yet - and a yellow "?" where a finished quest from your log is turned in.
-- Tooltip only (giver, quests with their level and the levels in which they can be taken and give experience), no click; a walking giver's route is drawn with it. Data: Data/QuestPins.lua (QuestieDB, GPL-3).
-- Switch qol.mapQuests (on by default, user 01.11.); hidden while Questie is loaded (it draws its own, user 01.11.).
-- qol.mapQuestsContinent (6.1.1, user 04.11.): also on the continent map, all zones at once (rect of each zone from
-- C_Map.GetMapRectOnMap), a bit smaller, without the walking routes.
-- Lean: a map's data string is read only when that map is shown (cached per map); the quest log is read once per
-- refresh; quest events are only registered while the map is open and the switch on, debounced.

local MQ = {}
FLT.MapQuests = MQ

local AVAIL_TEX, TURNIN_TEX = "Interface\\GossipFrame\\AvailableQuestIcon", "Interface\\GossipFrame\\ActiveQuestIcon"
-- the client's sharper map atlases when it has them (the 16 px gossip icons looked pixelated, user 01.11.)
local AVAIL_ATLAS, TURNIN_ATLAS = "QuestNormal", "QuestTurnin"
local function setIcon(tex, turnin)
  local atlas = turnin and TURNIN_ATLAS or AVAIL_ATLAS
  if tex.SetAtlas and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) then tex:SetAtlas(atlas); return end
  tex:SetTexture(turnin and TURNIN_TEX or AVAIL_TEX, nil, nil, "TRILINEAR")
end
local SIZE = 18
-- dungeon / raid quests (6.2.3, user 10.11.: "[D35] Rig Wars" and a mark on the map icon): [questID] = dungeon entry,
-- from the quest lists of Dungeons & Raids, built on first use
local dungeonQ
local function dungeonOf(id)
  if not dungeonQ then
    if not FLT.DUNGEONS then return nil end
    dungeonQ = {}
    for _, d in ipairs(FLT.DUNGEONS) do for _, q in ipairs(d.quests or {}) do if q.id then dungeonQ[q.id] = d end end end
  end
  return dungeonQ[id]
end
local function dLetter(d) -- "D" / "R", in the client's language (keys with a hint, the English text is the letter)
  local v = d.raid and L["R (raid quest)"] or L["D (dungeon quest)"]
  return v:find("quest", 1, true) and (d.raid and "R" or "D") or v
end
local function dName(d) -- short like the Gear Planner ("SM: Graveyard"), the client's name when it has its own
  local n = FLT.DungeonName and FLT.DungeonName(d.name)
  return n and n ~= d.name and n or d.short or d.name
end

local function Q(key) return FLT.QoL and FLT.QoL.Get(key) end

local questie
local function questieLoaded()
  if questie == nil then
    local loaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    questie = loaded and loaded("Questie") and true or false
  end
  return questie
end

-- map data, read on first use: { starts = { {x, y, name, quests = { {id, lvl, req, max, side, race, class, pre1, preAll, excl, bc, name} } } },
-- ends = { {x, y, name, ids = {id ...}} } }
local parsed = {}
local function split(s) local t = {}; for v in s:gmatch("[^/]+") do t[#t + 1] = tonumber(v) end; return t end
local function mapData(mapID)
  local d = parsed[mapID]
  if d ~= nil then return d end
  local raw = FLT.QUEST_PINS and FLT.QUEST_PINS[mapID]
  if not raw then parsed[mapID] = false; return false end
  d = { starts = {}, ends = {} }
  local cur, last
  for line in raw:gmatch("[^\n]+") do
    local c = line:sub(1, 1)
    if c == "~" then
      if last then last.route = line:sub(2) end -- walking NPC: its route, drawn on mouseover
    elseif c == "!" then
      local x, y, name = line:match("^!([%d.]+),([%d.]+),(.*)$")
      cur = { x = tonumber(x), y = tonumber(y), name = name, quests = {} }
      d.starts[#d.starts + 1] = cur; last = cur
    elseif c == "?" then
      local x, y, ids, name = line:match("^%?([%d.]+),([%d.]+),([%d/]+),(.*)$")
      last = { x = tonumber(x), y = tonumber(y), name = name, ids = split(ids) }
      d.ends[#d.ends + 1] = last
    elseif cur then
      local f = {}
      for v in (line .. "|"):gmatch("([^|]*)|") do f[#f + 1] = v end
      cur.quests[#cur.quests + 1] = { id = tonumber(f[1]), lvl = tonumber(f[2]) or 0, req = tonumber(f[3]) or 0,
        max = tonumber(f[4]) or 0, side = f[5], race = tonumber(f[6]), class = tonumber(f[7]) or 0,
        pre1 = f[8] ~= "" and split(f[8]) or nil, preAll = f[9] ~= "" and split(f[9]) or nil,
        excl = f[10] ~= "" and split(f[10]) or nil, bc = tonumber(f[11]), name = f[12] }
    end
  end
  parsed[mapID] = d
  return d
end

-- the quest log: in the log / finished (reused tables)
local inLog, complete, titles = {}, {}, {}
local bagHas = {} -- [itemID] = in the bags (Library Book quests below), per refresh - wiped with the quest log
local function readLog()
  wipe(inLog); wipe(complete); wipe(titles); wipe(bagHas)
  if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo then
    for i = 1, C_QuestLog.GetNumQuestLogEntries() or 0 do
      local info = C_QuestLog.GetInfo(i)
      if info and not info.isHeader and info.questID then
        inLog[info.questID] = true; titles[info.questID] = info.title
        local done = C_QuestLog.IsComplete and C_QuestLog.IsComplete(info.questID)
        if done == nil then done = info.isComplete end
        if done and done ~= 0 and done ~= -1 then complete[info.questID] = true end
      end
    end
  elseif GetNumQuestLogEntries and GetQuestLogTitle then
    for i = 1, GetNumQuestLogEntries() or 0 do
      local qtitle, _, _, isHeader, _, isComplete, _, questID = GetQuestLogTitle(i)
      if not isHeader and questID then
        inLog[questID] = true; titles[questID] = qtitle
        if isComplete and isComplete > 0 then complete[questID] = true end
      end
    end
  end
end

local function done(id) return FLT.IsQuestDone and FLT:IsQuestDone(id) end
-- Library Book quests (6.1.6, user 06.11.: "dutzende" ! at Owen Thadd, who had none): QuestieDB names the librarians as
-- givers, but they offer a book quest only while you carry that book (the Friend of the Library quests: any book)
local bookOf -- [questID] = itemID of its book (FLT.BOOKS), built on first use
local FRIEND = { [78150] = true, [79536] = true, [82208] = true }
local function inBags(item)
  local v = bagHas[item]
  if v == nil then
    local n = (C_Item and C_Item.GetItemCount and C_Item.GetItemCount(item)) or (GetItemCount and GetItemCount(item)) or 0
    v = n > 0; bagHas[item] = v
  end
  return v
end
local function bookOK(id)
  if not bookOf then
    bookOf = {}
    for _, b in ipairs(FLT.BOOKS or {}) do if b.questId and b.itemId then bookOf[b.questId] = b.itemId end end
  end
  local item = bookOf[id]
  if item then return inBags(item) end
  if FRIEND[id] then for _, it in pairs(bookOf) do if inBags(it) then return true end end return false end
  return true
end
local function bit(mask, n) return math.floor(mask / 2 ^ (n - 1)) % 2 == 1 end -- masks go past 32 bits (Skyborne)

local me = {}
local function readMe()
  me.level = UnitLevel and UnitLevel("player") or 1
  local f = UnitFactionGroup and UnitFactionGroup("player")
  me.side = f == "Horde" and "H" or f == "Alliance" and "A" or nil
  me.race = UnitRace and select(3, UnitRace("player"))
  me.class = UnitClass and select(3, UnitClass("player"))
  -- grey below this level (the game's own range when it has one)
  local range = GetQuestGreenRange and GetQuestGreenRange("player")
  if type(range) ~= "number" then range = me.level <= 5 and 5 or me.level <= 39 and (math.floor(me.level / 10) + 5) or 8 end
  me.grey = me.level - range
end

-- grey: also the quests that are grey for you (6.2.12-beta15, user 18.11.: "low level quests (grau) wieder in der map
-- anzuzeigen. optional als schalter (standard: Aus)" - qol.mapQuestsGrey, only for the map pins)
local function available(q, grey)
  if q.req > me.level or (q.lvl < me.grey and not grey) or (q.max > 0 and me.level > q.max) then return false end
  -- far above your level (6.1.1, user 04.11.: level 60 book, Legacy and event quests that anyone may take showed for
  -- a level 9 character): only up to 10 levels above
  if q.lvl > me.level + 10 then return false end
  if q.side ~= "" and me.side and q.side ~= me.side then return false end
  if q.race and me.race and not bit(q.race, me.race) then return false end
  if q.class > 0 and me.class and not bit(q.class, me.class) then return false end
  if inLog[q.id] or done(q.id) then return false end
  if not bookOK(q.id) then return false end
  if q.excl then for _, e in ipairs(q.excl) do if inLog[e] or done(e) then return false end end end
  if q.bc and (inLog[q.bc] or done(q.bc)) then return false end -- breadcrumb: its target is already on the way
  if q.preAll then for _, p in ipairs(q.preAll) do if not done(p) then return false end end end
  if q.pre1 then
    local ok = false
    for _, p in ipairs(q.pre1) do if done(p) then ok = true; break end end
    if not ok then return false end
  end
  return true
end

-- the level range in which a quest can be taken and still gives experience (user 01.11.: "[8] Practical Prey (5-13)"):
-- from its required level up to the last level at which it is not grey yet (the classic grey levels: up to level 5
-- nothing, then level - level/10 - 5, from 40 on level - level/5 - 1, at 60: 48)
local function greyAt(pl)
  if pl <= 5 then return 0 elseif pl <= 39 then return pl - math.floor(pl / 10) - 5
  elseif pl <= 59 then return pl - math.floor(pl / 5) - 1 end
  return 48
end
-- grey for you (no experience any more): used by "Accept quests automatically" (6.1.5, user 05.11.)
local questLevel -- [questID] = level, read from the pin data on first use
function FLT.IsQuestGrey(id, level)
  local pl = UnitLevel and UnitLevel("player") or 1
  if not level and id then
    if not questLevel then
      questLevel = {}
      for _, raw in pairs(FLT.QUEST_PINS or {}) do
        for qid, lvl in raw:gmatch("\n(%d+)|(%d+)|") do questLevel[tonumber(qid)] = tonumber(lvl) end
      end
    end
    level = questLevel[id]
  end
  return level ~= nil and level > 0 and level <= greyAt(pl)
end
-- where a quest starts / is turned in according to the pin data (6.2.7, user 13.11.: every NPC under "Starts at" / "Turn in"
-- of a dungeon quest gets a Map button): { mapID, x, y, label }, looked up on first use per quest (a Map button is rare)
local pinLoc = { [false] = {}, [true] = {} }
function FLT.QuestPinLoc(id, isEnd)
  if not (id and FLT.QUEST_PINS) then return nil end
  local c = pinLoc[isEnd and true or false]
  if c[id] ~= nil then return c[id] or nil end
  local found = false
  local key = "/" .. id .. "/"
  for mapID, raw in pairs(FLT.QUEST_PINS) do
    if isEnd then
      for x, y, ids, name in raw:gmatch("%?([%d.]+),([%d.]+),([%d/]+),([^\n]*)") do
        if ("/" .. ids .. "/"):find(key, 1, true) then found = { mapID = mapID, x = tonumber(x), y = tonumber(y), name = name }; break end
      end
    else
      local p = raw:find("\n" .. id .. "|", 1, true)
      if p then
        for at, x, y, name in raw:gmatch("()!([%d.]+),([%d.]+),([^\n]*)") do
          if at > p then break end
          found = { mapID = mapID, x = tonumber(x), y = tonumber(y), name = name }
        end
      end
    end
    if found then break end
  end
  if found then
    local m = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(found.mapID)
    found.label = (FLT.Name and FLT.Name(found.name) or found.name) .. (m and m.name and (", " .. m.name) or "")
  end
  c[id] = found
  return found or nil
end
local function xpRange(q)
  local from = math.max(1, q.req)
  local to = from
  while to < 60 and q.lvl > greyAt(to + 1) do to = to + 1 end
  return from, to
end

local function title(q)
  local t = C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(q.id or q)
  if type(t) == "string" and t ~= "" and not (FLT.IsSecret and FLT.IsSecret(t)) then return t end
  return q.name and FLT.Name and FLT.Name(q.name) or q.name or "?"
end

-- Pins -----------------------------------------------------------------------------------------------------------------
local pool, used = {}, 0
-- no mouse on the pins at all, so every click goes to the map below (GitHub #38: our "?" took the click on Blizzard's
-- turn-in icon; user 10.11.: many "!" on the continent blocked the click into a zone - SetMouseClickEnabled(false) did
-- not let it through in the Forever client). The tooltip comes from a hover watcher instead (below).
local function hoverOnly(f) f:EnableMouse(false) end
local spots = {} -- reused per refresh: key "x,y" -> { x, y, name, avail = {}, turnin = {} }
local spotList = {}

-- the route of a walking quest giver, shown with its icon (user 01.11., like Questie); qol.mapQuestNoRoutes hides them
-- (6.2.12-beta5, Discord #general Baezil 18.11.: "all 3 alliance cities are covered in squiggles")
local routeFrame, lines, nLines = nil, {}, 0
-- invisible hover spots along the routes (6.1.1, user 04.11.: like Questie, the route shows its giver's tooltip and
-- lights up on mouseover); pooled like the lines
local hits, nHits = {}, 0
local onEnter, onLeave, openDungeonQuest -- forward (the tooltip of the pins, Shift-click)
local function paintRoute(r, on)
  for i = r.first, r.last do
    local l = lines[i]
    -- only a touch more (user 04.11.: the strong glow looked cheap): slightly thicker, fully opaque
    if on then l:SetColorTexture(1, 0.85, 0.15, 1); l:SetThickness(3.2 * r.scale)
    else l:SetColorTexture(1, 0.82, 0.1, 0.85); l:SetThickness(2.5 * r.scale) end
  end
end
local function hitEnter(self) paintRoute(self.route, true); onEnter(self) end
local function hitLeave(self) paintRoute(self.route, false); onLeave() end
local function hideRoute()
  for i = 1, nLines do lines[i]:Hide() end
  for i = 1, nHits do hits[i]:Hide(); hits[i].spot, hits[i].route = nil, nil end
  nLines, nHits = 0, 0
end
local HIT_STEP = 10 -- a hover spot every 10 units along the route
local function showRoute(route, child, w, h, scale, level, s)
  if not child.CreateLine then return end
  if not routeFrame then routeFrame = CreateFrame("Frame", nil, child); routeFrame:SetAllPoints() end
  routeFrame:SetFrameLevel(math.max(1, level - 1)); routeFrame:Show()
  local r = { first = nLines + 1, scale = scale }
  for path in route:gmatch("[^|]+") do
    local px, py
    for x, y in path:gmatch("([%d.]+),([%d.]+)") do
      x, y = tonumber(x) / 100 * w, -tonumber(y) / 100 * h
      if px then
        nLines = nLines + 1
        local l = lines[nLines]
        if not l then l = routeFrame:CreateLine(nil, "OVERLAY"); lines[nLines] = l end
        l:SetColorTexture(1, 0.82, 0.1, 0.85); l:SetThickness(2.5 * scale)
        l:SetStartPoint("TOPLEFT", routeFrame, px, py); l:SetEndPoint("TOPLEFT", routeFrame, x, y)
        l:Show()
        -- hover spots along this piece
        local dx, dy = x - px, y - py
        local steps = math.max(1, math.floor(math.sqrt(dx * dx + dy * dy) / (HIT_STEP * scale)))
        if nHits + steps > 600 then steps = math.max(0, 600 - nHits) end -- a few routes per map; never hundreds more
        for k = 0, steps - 1 do
          nHits = nHits + 1
          local hf = hits[nHits]
          if not hf then
            hf = CreateFrame("Frame", nil, routeFrame); hoverOnly(hf)
            hits[nHits] = hf
          end
          hf.spot, hf.route = s, r
          hf:SetSize(HIT_STEP * scale * 1.4, HIT_STEP * scale * 1.4)
          hf:ClearAllPoints(); hf:SetPoint("CENTER", routeFrame, "TOPLEFT", px + dx * k / steps, py + dy * k / steps)
          hf:SetFrameLevel(math.max(1, level - 1)); hf:Show()
        end
      end
      px, py = x, y
    end
  end
  r.last = nLines
end

onEnter = function(pin)
  local s = pin.spot
  if not s or not GameTooltip then return end
  GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
  GameTooltip:AddLine(FLT.Name and FLT.Name(s.name) or s.name, 1, 0.82, 0.2)
  for _, id in ipairs(s.turnin) do
    local d = dungeonOf(id)
    GameTooltip:AddLine(string.format(L["Turn in: %s"], (d and ("[" .. dLetter(d) .. "] ") or "") .. (titles[id] or title({ id = id })))
      .. (d and ("  |cff9d9d9d" .. dName(d) .. "|r") or ""), 0.4, 0.9, 0.4, true)
  end
  for _, q in ipairs(s.avail) do
    local c = GetQuestDifficultyColor and GetQuestDifficultyColor(q.lvl) or { r = 1, g = 1, b = 1 }
    local lo, hi = xpRange(q)
    local d = dungeonOf(q.id)
    GameTooltip:AddLine("[" .. (d and dLetter(d) or "") .. q.lvl .. "] " .. title(q) .. "  |cff9d9d9d(" .. lo .. (hi > lo and ("-" .. hi) or "") .. ")"
      .. (d and ("  " .. dName(d)) or "") .. "|r", c.r, c.g, c.b, true)
  end
  if pin.dq then GameTooltip:AddLine(L["Shift-click: open in OFA"], 0.6, 0.6, 0.6, true) end
  GameTooltip:Show()
end
onLeave = function() if GameTooltip then GameTooltip:Hide() end end

-- Shift-click on a "!" / "?" with a dungeon quest opens that quest in Dungeons & Raids (user 10.11.). The pins take
-- no mouse (clicks go to the map); only while Shift is held the ones with a dungeon quest take it (MODIFIER_STATE_CHANGED,
-- registered while the map is open).
openDungeonQuest = function(pin, button)
  if button ~= "LeftButton" or not pin.dq or not (IsShiftKeyDown and IsShiftKeyDown()) then return end
  local d, qid = pin.dq, pin.dqid -- read first: closing the map clears the pins
  if WorldMapFrame and WorldMapFrame:IsShown() and HideUIPanel then pcall(HideUIPanel, WorldMapFrame) end
  FLT:OpenPanel("dungeons")
  if FLT.UI and FLT.UI.OpenDungeon then FLT.UI.OpenDungeon(d, nil, "quests", qid) end
end
local function shiftPins()
  local sh = IsShiftKeyDown and IsShiftKeyDown() and true or false
  for i = 1, used do local p = pool[i]; p:EnableMouse(sh and p.dq ~= nil) end
end
local function acquire(parent)
  used = used + 1
  local pin = pool[used]
  if not pin then
    pin = CreateFrame("Frame", nil, parent)
    pin.tex = pin:CreateTexture(nil, "OVERLAY"); pin.tex:SetAllPoints()
    -- dungeon / raid swirl at the corner when a quest there is a dungeon or raid quest (user 10.11.)
    pin.badge = pin:CreateTexture(nil, "OVERLAY", nil, 2); pin.badge:SetSize(13, 13); pin.badge:SetPoint("CENTER", pin, "BOTTOMRIGHT", -1, 3)
    hoverOnly(pin)
    pin:SetScript("OnMouseUp", openDungeonQuest)
    pool[used] = pin
  end
  return pin
end
-- hover watcher: while pins are shown, a small frame on the open map looks every 0.1 s which pin (or route spot) is under
-- the cursor and shows its tooltip. It is a child of the map, so it never runs while the map is closed.
local watch, hovered, hoveredHit, wt = nil, nil, false, 0
local function unhover()
  if hovered then if hoveredHit then hitLeave(hovered) else onLeave() end end
  hovered = nil
end
local function watchTick(_, el)
  wt = wt + el
  if wt < 0.1 then return end
  wt = 0
  local p, hit
  for i = 1, used do if pool[i]:IsMouseOver() then p = pool[i]; break end end
  if not p then for i = 1, nHits do if hits[i]:IsMouseOver() then p, hit = hits[i], true; break end end end
  if p == hovered then return end
  unhover()
  if p then hovered, hoveredHit = p, hit and true or false; if hit then hitEnter(p) else onEnter(p) end end
end
local function setWatch(on)
  if on and not watch and WorldMapFrame then watch = CreateFrame("Frame", nil, WorldMapFrame) end
  if not watch then return end
  wt = 0
  watch:SetScript("OnUpdate", on and watchTick or nil)
end
local function hideAll()
  unhover(); setWatch(false)
  for i = 1, used do local p = pool[i]; p:Hide(); p:EnableMouse(false); p.spot, p.dq, p.dqid = nil, nil, nil end
  used = 0
end

local function spot(x, y, name, route)
  local key = x .. "," .. y
  local s = spots[key]
  if not s then
    s = { avail = {}, turnin = {} }
    spots[key] = s
  end
  if not s.used then s.used = true; s.x, s.y, s.name, s.route = x, y, name, nil; spotList[#spotList + 1] = s end
  if route then s.route = route end
  return s
end

-- the zones of a continent with quest data and where they lie on it: { {mapID, x0, y0, sx, sy} } (0-1 of the
-- continent map), cached per continent (6.1.1, user 04.11.: the icons also when zoomed out of the zone)
local continents = {}
local function continentZones(mapID)
  local c = continents[mapID]
  if c ~= nil then return c end
  c = false
  local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
  local CONT = Enum and Enum.UIMapType and Enum.UIMapType.Continent or 2
  if info and info.mapType == CONT and C_Map.GetMapChildrenInfo and FLT.QUEST_PINS then
    c = {}
    local ok, kids = pcall(C_Map.GetMapChildrenInfo, mapID, nil, true)
    for _, k in ipairs(ok and kids or {}) do
      if k.mapID and FLT.QUEST_PINS[k.mapID] and C_Map.GetMapRectOnMap then
        local ok2, x0, x1, y0, y1 = pcall(C_Map.GetMapRectOnMap, k.mapID, mapID)
        if ok2 and x0 and x1 and y0 and y1 and x1 > x0 and y1 > y0 then c[#c + 1] = { k.mapID, x0, y0, x1 - x0, y1 - y0 } end
      end
    end
    if #c == 0 then c = false end
  end
  continents[mapID] = c
  return c
end

local ONE = { { nil, 0, 0, 1, 1 } } -- a zone map: its own data at full size
function MQ.Refresh()
  if not WorldMapFrame then return end
  hideAll(); hideRoute()
  if not Q("mapQuests") or questieLoaded() or not WorldMapFrame:IsShown() then return end
  local mapID = WorldMapFrame.GetMapID and WorldMapFrame:GetMapID()
  if not mapID then return end
  local zones
  if mapData(mapID) then ONE[1][1] = mapID; zones = ONE
  elseif Q("mapQuestsContinent") then zones = continentZones(mapID) end
  if not zones then return end
  local LM = FLT.MapLandmarks
  local child, w, h, scale, level
  if LM and LM.Canvas then child, w, h, scale, level = LM.Canvas() end
  if not child then return end
  readLog(); readMe()
  for _, s in ipairs(spotList) do s.used = nil; wipe(s.avail); wipe(s.turnin) end
  wipe(spotList)
  local whole = zones == ONE
  for _, z in ipairs(zones) do
    local d = mapData(z[1])
    if d then
      -- zone coordinates (0-100) -> this map's; walking routes only on the zone map itself
      local function at(x, y) return z[2] * 100 + x * z[4], z[3] * 100 + y * z[5] end
      local givers, turnins = Q("mapQuestGivers") ~= false, Q("mapQuestTurnins") ~= false -- 6.1.9: each on its own
      local grey = Q("mapQuestsGrey") and true or false
      for _, g in ipairs(givers and d.starts or {}) do
        for _, q in ipairs(g.quests) do
          if available(q, grey) then local x, y = at(g.x, g.y); local s = spot(x, y, g.name, whole and g.route or nil); s.avail[#s.avail + 1] = q end
        end
      end
      for _, e in ipairs(turnins and d.ends or {}) do
        for _, id in ipairs(e.ids) do
          if complete[id] then local x, y = at(e.x, e.y); local s = spot(x, y, e.name, whole and e.route or nil); s.turnin[#s.turnin + 1] = id end
        end
      end
    end
  end
  local size = whole and SIZE or SIZE * 0.8 -- a bit smaller on the continent
  for _, s in ipairs(spotList) do
    local pin = acquire(child)
    pin.spot = s
    setIcon(pin.tex, #s.turnin > 0)
    -- only grey quests there: a grey "!" (like the game's own low level quest marks)
    local allGrey = #s.turnin == 0 and #s.avail > 0
    for _, q in ipairs(s.avail) do if q.lvl >= me.grey then allGrey = false; break end end
    if pin.tex.SetDesaturated then pin.tex:SetDesaturated(allGrey) end
    pin.tex:SetVertexColor(allGrey and 0.75 or 1, allGrey and 0.75 or 1, allGrey and 0.75 or 1)
    local dq, dqid
    for _, q in ipairs(s.avail) do if not dq then dq = dungeonOf(q.id); dqid = dq and q.id end end
    for _, id in ipairs(s.turnin) do if not dq then dq = dungeonOf(id); dqid = dq and id end end
    pin.dq, pin.dqid = dq, dqid
    local atlas = dq and (dq.raid and "raid" or "dungeon")
    if atlas and pin.badge.SetAtlas and pin.badge.atlas ~= atlas then pin.badge.atlas = atlas; pcall(pin.badge.SetAtlas, pin.badge, atlas) end
    pin.badge:SetShown(atlas and pin.badge.atlas == atlas or false)
    pin:SetSize(size, size); pin:SetScale(scale); pin:SetFrameLevel(level + 10) -- above books and entrances (user 10.11.)
    pin:ClearAllPoints()
    pin:SetPoint("CENTER", child, "TOPLEFT", (s.x / 100) * w / scale, -(s.y / 100) * h / scale)
    pin:Show()
    if s.route and not Q("mapQuestNoRoutes") then showRoute(s.route, child, w, h, scale, level, s) end -- 6.2.12-beta5: can be hidden
  end
  setWatch(used > 0)
  shiftPins()
end

-- quest log changes while the map is open (accept, finish, turn in, level up): debounced
local ev = CreateFrame("Frame")
local EVENTS = { "QUEST_LOG_UPDATE", "QUEST_TURNED_IN", "PLAYER_LEVEL_UP" }
local pending = false
ev:SetScript("OnEvent", function()
  if pending then return end
  pending = true
  C_Timer.After(0.5, function() pending = false; MQ.Refresh() end)
end)
local mod = CreateFrame("Frame")
mod:SetScript("OnEvent", function() shiftPins() end)
local function listen(on)
  for _, e in ipairs(EVENTS) do if on then ev:RegisterEvent(e) else ev:UnregisterEvent(e) end end
  if on then mod:RegisterEvent("MODIFIER_STATE_CHANGED") else mod:UnregisterEvent("MODIFIER_STATE_CHANGED") end
end

local hooked
local function onShow() if Q("mapQuests") then listen(true) end; MQ.Refresh() end
local function onHide() listen(false); hideAll() end
function MQ.Apply()
  if Q("mapQuests") and not hooked and WorldMapFrame then
    hooked = true
    WorldMapFrame:HookScript("OnShow", onShow)
    WorldMapFrame:HookScript("OnHide", onHide)
    if WorldMapFrame.OnMapChanged then hooksecurefunc(WorldMapFrame, "OnMapChanged", MQ.Refresh) end
    if WorldMapFrame.OnCanvasScaleChanged then hooksecurefunc(WorldMapFrame, "OnCanvasScaleChanged", MQ.Refresh) end
  end
  local open = WorldMapFrame and WorldMapFrame:IsShown()
  listen(Q("mapQuests") and open and true or false)
  MQ.Refresh()
end
-- Quests on NPC tooltips (6.2.2, user 08.11.: "wenn ich einen npc ... drueber hover ... sollte dort die quest stehen die
-- ich annehmen oder abgeben kann"; on, off while Questie is loaded - user 08.11.): the same data and rules as the map's
-- ! and ?. The NPC is found by its name (in the client's language) on the map you are on, the nearest one when a name
-- is there twice. Lean: nothing is read unless the name is a giver / turn-in NPC of this map (index per map, built once).
local tipIndex = {} -- [mapID] = { [name in the client's language] = { starts = {...}, ends = {...} } }
local function npcsOf(mapID)
  local idx = tipIndex[mapID]
  if idx ~= nil then return idx end
  local d = mapData(mapID)
  if not d then tipIndex[mapID] = false; return false end
  idx = {}
  local function put(kind, e)
    local n = FLT.Name and FLT.Name(e.name) or e.name
    local t = idx[n]; if not t then t = { starts = {}, ends = {} }; idx[n] = t end
    t[kind][#t[kind] + 1] = e
  end
  for _, g in ipairs(d.starts) do put("starts", g) end
  for _, e in ipairs(d.ends) do put("ends", e) end
  tipIndex[mapID] = idx
  return idx
end
local function nearest(list, px, py)
  if #list < 2 or not px then return list[1] end
  local best, bd
  for _, e in ipairs(list) do
    local dd = (e.x - px) ^ 2 + (e.y - py) ^ 2
    if not bd or dd < bd then best, bd = e, dd end
  end
  return best
end
local AVAIL_ICON, TURNIN_ICON = "|TInterface\\GossipFrame\\AvailableQuestIcon:0|t ", "|TInterface\\GossipFrame\\ActiveQuestIcon:0|t "
function MQ.AddUnitLines(tt, unit)
  if not Q("npcQuestTip") or questieLoaded() or not unit then return end
  if not (UnitExists and UnitExists(unit)) or (UnitIsPlayer and UnitIsPlayer(unit)) then return end
  -- fading out after the mouse left the NPC (6.2.10, Discord darkgameover 15.11.): no Show() that would stop the fade
  if not UnitExists("mouseover") then return end
  local name = UnitName and UnitName(unit)
  if type(name) ~= "string" or (FLT.IsSecret and FLT.IsSecret(name)) then return end
  local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  local idx = mapID and npcsOf(mapID)
  local npc = idx and idx[name]
  if not npc then return end
  local px, py
  local pos = C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(mapID, "player")
  if pos and pos.GetXY then
    local x, y = pos:GetXY()
    if x and y and not (FLT.IsSecret and FLT.IsSecret(x, y)) then px, py = x * 100, y * 100 end
  end
  readLog(); readMe()
  local added = false
  local e = nearest(npc.ends, px, py)
  for _, id in ipairs(e and e.ids or {}) do
    if complete[id] then
      local d = dungeonOf(id) -- 6.2.7-beta14 (user 13.11.: "im tooltip steht kein D fuer Dungeon quest"), like the map pins
      tt:AddLine(TURNIN_ICON .. (d and ("[" .. dLetter(d) .. "] ") or "") .. (titles[id] or title({ id = id }))
        .. (d and ("  |cff9d9d9d" .. dName(d) .. "|r") or ""), 0.4, 0.9, 0.4, true); added = true
    end
  end
  local g = nearest(npc.starts, px, py)
  for _, q in ipairs(g and g.quests or {}) do
    if available(q) then
      local c = GetQuestDifficultyColor and GetQuestDifficultyColor(q.lvl) or { r = 1, g = 1, b = 1 }
      local d = dungeonOf(q.id)
      tt:AddLine(AVAIL_ICON .. "[" .. (d and dLetter(d) or "") .. q.lvl .. "] " .. title(q) .. (d and ("  |cff9d9d9d" .. dName(d) .. "|r") or ""),
        c.r, c.g, c.b, true); added = true
    end
  end
  if added then tt:Show() end
end

MQ.QuestieLoaded = questieLoaded
MQ._mapData, MQ._available, MQ._pool, MQ._xpRange, MQ._dungeonOf, MQ._openDQ = mapData, available, pool, xpRange, dungeonOf, openDungeonQuest
MQ._routeLines = function() return nLines end -- 6.2.12-beta5 test: route lines drawn -- for tools/tests/t_mapquests.lua
function MQ._me(t) for k, v in pairs(t) do me[k] = v end wipe(bagHas) end

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self)
  self:UnregisterAllEvents()
  if FLT.QoL and FLT.QoL.On then FLT.QoL.On("mapQuests", MQ.Apply); FLT.QoL.On("mapQuestsContinent", MQ.Refresh)
    FLT.QoL.On("mapQuestGivers", MQ.Refresh); FLT.QoL.On("mapQuestTurnins", MQ.Refresh)
    FLT.QoL.On("mapQuestNoRoutes", MQ.Refresh)
    FLT.QoL.On("mapQuestsGrey", MQ.Refresh) end
  if Q("mapQuests") then MQ.Apply() end
end)
