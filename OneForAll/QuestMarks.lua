local _, FLT = ...
local function N(s) return s end -- marks an English text translated where it is shown (tools/locale/extract.py)

-- Quest marks on nameplates (6.0.2, user 31.10.; idea from ForeverQuestMark by Ugge Zen, MIT - own code, nothing
-- copied). A sword when you must kill the unit for a quest, a bag when it drops a quest item, with the progress
-- ("3/10"). The game itself lists the quest objectives in a unit's tooltip data (C_TooltipInfo.GetUnit, lines of type
-- QuestObjective); "slain" / "killed" = kill, anything else = loot. Done objectives (10/10) show nothing.
-- Inside instances the game keeps that data secret: no marks there for now (no guessing, user 31.10.);
-- /ofa questmarks test shows what the game gives away there.
-- Switch qol.questMarks (off by default), position qol.questMarkAt (QM.At below).
-- Lean: the events are only registered while the switch is on; a plate is looked at when it appears and again
-- (all shown plates) after the quest log changed, debounced.

local QM = {}
FLT.QuestMarks = QM
-- Position (6.2.11, user 17.11.: dragged in a sample nameplate in the settings, all around the plate - no drop-down):
-- qol.questMarkAt = { z = "L" / "C" / "R", x, y }: the mark's centre, in mark sizes (the mark grows with the bar), from
-- the bar's left edge (L), across the bar + level box as a fraction 0..1 (C) or from the level box's / bar's right edge
-- (R); y from the bar's middle (up = +). The old qol.questMarkPos ("left" ... "right") gives the start.
QM.PRESETS = { left = { z = "L", x = -0.65, y = 0 }, topleft = { z = "C", x = 0.06, y = 1.5 }, top = { z = "C", x = 0.5, y = 1.5 },
  topright = { z = "C", x = 0.88, y = 1.5 }, right = { z = "R", x = 0.8, y = 0 } }
QM.LIMIT_X, QM.LIMIT_Y = 3, 2.5 -- how far it may go from the plate (mark sizes)
function QM.At()
  local a = FLT.QoL and FLT.QoL.Get("questMarkAt")
  if type(a) == "table" and (a.z == "L" or a.z == "C" or a.z == "R") and type(a.x) == "number" and type(a.y) == "number" then return a end
  return QM.PRESETS[FLT.QoL and FLT.QoL.Get("questMarkPos") or "right"] or QM.PRESETS.right
end

local KILL_ATLAS, LOOT_ATLAS = "Crosshair_Attack_32", "Crosshair_pickup_32"
local KILL_TEX, LOOT_TEX = "Interface\\Cursor\\Attack", "Interface\\Cursor\\Pickup" -- when the client has no atlas

local function Q() return FLT.QoL end
local function on() return Q() and Q().Get("questMarks") end

local function setIcon(tex, kill)
  local atlas = kill and KILL_ATLAS or LOOT_ATLAS
  if tex.SetAtlas and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) then
    tex:SetAtlas(atlas)
  else
    tex:SetTexture(kill and KILL_TEX or LOOT_TEX)
  end
end

-- Kill or loot, in every language (user 01.11.: another addon had trouble with non-English clients): the quest log
-- knows each objective's type ("monster" = kill, "item" = loot). Its texts, without numbers and signs, are matched
-- with the tooltip line; only when nothing matches, the English words "slain" / "killed" decide.
local kinds = {} -- normalised objective text -> true (kill) / false (loot)
local function norm(t) return (t:lower():gsub("[%d%p%s]", "")) end
local function readLog()
  wipe(kinds)
  local function add(text, kind)
    if type(text) == "string" and not FLT.IsSecret(text) and kind then kinds[norm(text)] = (kind == "monster") end
  end
  if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo and C_QuestLog.GetQuestObjectives then
    for i = 1, C_QuestLog.GetNumQuestLogEntries() or 0 do
      local info = C_QuestLog.GetInfo(i)
      if info and not info.isHeader and info.questID then
        for _, o in ipairs(C_QuestLog.GetQuestObjectives(info.questID) or {}) do add(o.text, o.type) end
      end
    end
  elseif GetNumQuestLogEntries and GetNumQuestLeaderBoards and GetQuestLogLeaderBoard then
    for i = 1, GetNumQuestLogEntries() or 0 do
      for j = 1, GetNumQuestLeaderBoards(i) or 0 do add(GetQuestLogLeaderBoard(j, i)) end
    end
  end
end

-- Loot quests (6.0.3, user 02.11.): the Forever mob tooltip lists kill objectives but not quest items (no mark on
-- Plainstriders for "The Hunt Begins", Platynator neither). Data/QuestDrops.lua (QuestieDB) says which mob drops a
-- quest item of which quest; the quest log gives the progress. Mob ID from the unit's GUID (readable outside instances).
local function npcID(unit)
  local g = UnitGUID and UnitGUID(unit)
  if type(g) ~= "string" or FLT.IsSecret(g) then return end
  local kind, id = g:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)")
  if kind == "Creature" then return tonumber(id) end
end
local function inLog(qid)
  if C_QuestLog and C_QuestLog.GetLogIndexForQuestID then return (C_QuestLog.GetLogIndexForQuestID(qid) or 0) > 0 end
  return GetQuestLogIndexByID and (GetQuestLogIndexByID(qid) or 0) > 0
end
local function lootObjective(unit)
  local list = FLT.QUEST_DROPS and FLT.QUEST_DROPS[npcID(unit) or 0]
  if not list or not (C_QuestLog and C_QuestLog.GetQuestObjectives) then return end
  for qid, item in list:gmatch("(%d+):(%d+)") do
    qid = tonumber(qid)
    if inLog(qid) then
      local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(tonumber(item))
      for _, o in ipairs(C_QuestLog.GetQuestObjectives(qid) or {}) do
        local text = o.text
        if o.type == "item" and not o.finished and type(text) == "string" and not FLT.IsSecret(text)
          and (not name or text:find(name, 1, true)) then
          return false, (o.numFulfilled or 0) .. "/" .. (o.numRequired or 0)
        end
      end
    end
  end
end

-- the first objective of this unit that is not done yet: kill (true/false), "3/10"
local function objective(unit)
  if not (C_TooltipInfo and C_TooltipInfo.GetUnit and Enum and Enum.TooltipDataLineType) then return lootObjective(unit) end
  local ok, data = pcall(C_TooltipInfo.GetUnit, unit)
  if not ok or type(data) ~= "table" or type(data.lines) ~= "table" then return lootObjective(unit) end
  local want = Enum.TooltipDataLineType.QuestObjective
  for _, line in ipairs(data.lines) do
    if TooltipUtil and TooltipUtil.SurfaceArgs and line.leftText == nil then pcall(TooltipUtil.SurfaceArgs, line) end
    local text = line.leftText
    if line.type == want and type(text) == "string" and not FLT.IsSecret(text) then
      local have, need = text:match("(%d+)%s*/%s*(%d+)")
      have, need = tonumber(have), tonumber(need)
      if have and need and have < need then
        local kill = kinds[norm(text)]
        if kill == nil then
          local lower = text:lower()
          kill = (lower:find("slain", 1, true) or lower:find("killed", 1, true)) and true or false
        end
        return kill, have .. "/" .. need
      end
    end
  end
  return lootObjective(unit)
end

local function markFor(plate)
  local m = plate.ofaQuestMark
  if m then return m end
  m = CreateFrame("Frame", nil, plate); m:SetSize(20, 20); m:SetFrameLevel((plate:GetFrameLevel() or 1) + 10)
  m.icon = m:CreateTexture(nil, "OVERLAY"); m.icon:SetAllPoints()
  m.text = FLT.NewFS(m, nil, "OVERLAY", "GameFontHighlightSmall")
  do local font, _, flags = m.text:GetFont(); if font then m.text:SetFont(font, 10, "OUTLINE") end end
  m:Hide()
  plate.ofaQuestMark = m
  return m
end

-- the health bar the player SEES: Blizzard's, or - when a nameplate addon (Platynator, Plater ...) hides Blizzard's frame -
-- that addon's biggest shown status bar on the plate (user 17.11., Platynator: the mark sat off the bar because Blizzard's
-- hidden bar is somewhere else). Found once per plate and kept while it is shown; sizes only, no positions.
-- a size we may calculate with: Platynator's bars give "secret" sizes - arithmetic on them is an error (user 17.11. 21:10)
local function num(v)
  if type(v) ~= "number" or FLT.IsSecret(v) then return nil end
  return v
end
-- shown? A secret answer (BlizzThreatPlates' own frames, Discord grumpymuppet 18.11.: "attempt to perform boolean test on a
-- secret boolean value") counts as not shown (6.2.12-beta22)
-- forbidden frames (Blizzard's own nameplate auras, Discord sylahm 24.11.: "calling 'IsVisible' on bad self (Attempt to access
-- forbidden object from code tainted by an AddOn)", Blizzard_AuraContainerFrameProviders) count as not shown (6.2.17-beta14)
local function shown(f)
  if not (f and f.IsVisible) then return false end
  if f.IsForbidden and f:IsForbidden() then return false end
  local ok, v = pcall(f.IsVisible, f)
  if not ok or FLT.IsSecret(v) then return false end
  return v and true or false
end
local function addonBar(f, skip, depth, best, bestA)
  for _, c in ipairs({ f:GetChildren() }) do
    if c ~= skip and shown(c) then
      if c.IsObjectType and c:IsObjectType("StatusBar") then
        local w, h = num(c:GetWidth()), num(c:GetHeight())
        -- secret sizes: the bar the addon calls its health / status bar wins, else the first one found
        local a = (w and h) and w * h or ((f.statusBar == c or f.healthBar == c) and 1e9 or 1)
        if a > bestA then best, bestA = c, a end
      end
      if depth < 3 then best, bestA = addonBar(c, skip, depth + 1, best, bestA) end
    end
  end
  return best, bestA
end
local function visibleBar(plate, uf)
  local bar = uf and (uf.healthBar or uf.HealthBar)
  if bar and (not uf.IsVisible or shown(uf)) and (not uf.GetEffectiveAlpha or (num(uf:GetEffectiveAlpha()) or 1) > 0.05)
    and (not bar.IsVisible or shown(bar)) then return bar, true end
  local c = plate.ofaBar
  if not shown(c) then c = plate.GetChildren and addonBar(plate, uf, 1, nil, 0); plate.ofaBar = c end
  if c then return c, false end
  return bar or plate, true
end
local badBar = setmetatable({}, { __mode = "k" }) -- other addons' bars we may not anchor to
local function place(plate, m)
  local uf = plate.UnitFrame
  local bar, blizz = visibleBar(plate, uf)
  local at = QM.At()
  m:ClearAllPoints(); m.text:ClearAllPoints()
  -- grows with the plate (Discord petrovafired 16.11.: Blizzard plates at size 3 - the mark sat on the level box's frame)
  -- nameplate addons: always 20 - their bars live in their own scale (Platynator: 2.5), so the height is not ours
  -- (6.2.11-beta19 user 17.11.: "viel zu gross")
  local h = blizz and bar.GetHeight and num(bar:GetHeight()) or 0
  local size = math.max(20, math.floor(h * 1.1 + 0.5))
  if m.size ~= size then
    m.size = size; m:SetSize(size, size)
    local font, _, flags = m.text:GetFont(); if font then m.text:SetFont(font, math.max(10, math.floor(size * 0.45)), flags or "OUTLINE") end
  end
  -- The level box beside Blizzard's bar is a FIXED allowance, no question to the plate at all (user 17.11.: "kannst du nicht
  -- einfach die positionen in ofa dafuer aendern ohne jedesmal an der nameplate selbst irgendwas abzufragen?" - the game
  -- forbids measuring and anchor queries there, and the style CVar did not tell the Forever client's classic style):
  -- measured on the user's screenshot (21:08), the box ends 21.5 % of the bar's width right of the bar. Nameplate addons: none.
  local extra = blizz and bar.GetWidth and (num(bar:GetWidth()) or 0) * 0.215 or 0
  local x, y = at.x * size, at.y * size
  local over = (plate:GetFrameLevel() or 1) + 30 -- above the plate's art (box, border); the plate's own level is safe to read
  if m:GetFrameLevel() < over then m:SetFrameLevel(over) end
  local w = bar.GetWidth and num(bar:GetWidth()) or 120 -- 120: secret width
  -- 6.2.17-beta3 (Discord Ar-Kane / Knova 24.11.): another addon's bar may forbid anchoring ("Anchoring disallowed as dependent
  -- object would inherit forbidden aspects: UntrustedLayoutScriptExecution", RogueAuras' bar on a friendly plate) - then the
  -- plate itself, same side (its centre; sizes from the bar); remembered per bar so it is tried once
  local to = bar
  if not blizz and badBar[bar] then to = nil end
  for _ = 1, 2 do
    local ok
    if to then
      if at.z == "L" then ok = pcall(m.SetPoint, m, "CENTER", to, "LEFT", x, y)
      elseif at.z == "R" then ok = pcall(m.SetPoint, m, "CENTER", to, "RIGHT", extra + x, y)
      else ok = pcall(m.SetPoint, m, "CENTER", to, "LEFT", at.x * (w + extra), y) end -- across the bar and the level box
    else
      local half = w / 2
      if at.z == "L" then ok = pcall(m.SetPoint, m, "CENTER", plate, "CENTER", x - half, y)
      elseif at.z == "R" then ok = pcall(m.SetPoint, m, "CENTER", plate, "CENTER", half + extra + x, y)
      else ok = pcall(m.SetPoint, m, "CENTER", plate, "CENTER", at.x * (w + extra) - half, y) end
    end
    if ok or not to then break end
    badBar[bar] = true; to = nil; m:ClearAllPoints()
  end
  -- the progress on the outer side: left of the mark when it sits left of the plate
  if at.z == "L" then m.text:SetPoint("RIGHT", m, "LEFT", -1, 0) else m.text:SetPoint("LEFT", m, "RIGHT", 2, 0) end
end

local function update(unit)
  local plate = C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit(unit)
  if not plate then return end
  local kill, progress
  if on() and not (IsInInstance and IsInInstance()) then kill, progress = objective(unit) end
  if kill == nil then
    if plate.ofaQuestMark then plate.ofaQuestMark:Hide() end
    return
  end
  local m = markFor(plate)
  place(plate, m); setIcon(m.icon, kill); m.text:SetText(progress); m:Show()
end

local function updateAll()
  if not (C_NamePlate and C_NamePlate.GetNamePlates) then return end
  if on() then readLog() end
  for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
    local unit = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
    if unit then update(unit) elseif plate.ofaQuestMark then plate.ofaQuestMark:Hide() end
  end
end

local ev = CreateFrame("Frame")
local pending = false
local function later() -- the quest log fires in bursts
  if pending then return end
  pending = true
  C_Timer.After(0.3, function() pending = false; updateAll() end)
end
local EVENTS = { "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "QUEST_LOG_UPDATE", "PLAYER_ENTERING_WORLD" }
ev:SetScript("OnEvent", function(_, event, unit)
  if event == "NAME_PLATE_UNIT_ADDED" then update(unit)
  elseif event == "NAME_PLATE_UNIT_REMOVED" then
    local plate = C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit(unit)
    if plate and plate.ofaQuestMark then plate.ofaQuestMark:Hide() end
  else later() end
end)
-- switch on / off: events only while it is on
function QM.Apply()
  for _, e in ipairs(EVENTS) do
    if on() then pcall(ev.RegisterEvent, ev, e) else pcall(ev.UnregisterEvent, ev, e) end
  end
  updateAll()
end
QM.UpdateAll = updateAll

-- /ofa questmarks test: what the game tells us about your target (in a dungeon: is anything readable at all?)
function QM.Test()
  local msg = FLT.Msg or print
  if not (UnitExists and UnitExists("target")) then msg("Quest marks test: target a mob first."); return end
  local guid = UnitGUID and UnitGUID("target")
  local inInst = IsInInstance and IsInInstance()
  msg(string.format("Quest marks test (%s): GUID %s", inInst and "inside an instance" or "open world",
    guid == nil and "missing" or (FLT.IsSecret(guid) and "secret" or ("readable (" .. tostring(guid) .. ")"))))
  local ok, data = false, nil
  if C_TooltipInfo and C_TooltipInfo.GetUnit then ok, data = pcall(C_TooltipInfo.GetUnit, "target") end
  if not ok or type(data) ~= "table" then msg("Tooltip data: none"); return end
  local n, secret, quest = 0, 0, 0
  local want = Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.QuestObjective
  for _, line in ipairs(data.lines or {}) do
    n = n + 1
    if FLT.IsSecret(line.leftText) then secret = secret + 1
    elseif line.type == want then quest = quest + 1; msg("  objective: " .. tostring(line.leftText)) end
  end
  msg(string.format("Tooltip data: %d lines, %d secret, %d quest objectives", n, secret, quest))
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function() if on() then QM.Apply() end end)
if FLT.QoL and FLT.QoL.On then
  FLT.QoL.On("questMarks", function() QM.Apply() end)
  FLT.QoL.On("questMarkAt", function() updateAll() end)
end
