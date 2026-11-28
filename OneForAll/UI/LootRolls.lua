local ADDON, FLT = ...
-- 6.2.17-beta10 (user 24.11.2026: "das waere noch richtig geil ... unten am rand des trackers auf der rahmenlinie ein symbol zum
-- aufklappen"; the idea of the addon "Better Loot Rolls" - only the idea, own code): the loot rolls of a run - every item the group
-- rolled on, who won it with which roll, and on a click every player's choice and roll. Kept with the run (History shows them too).
-- Source: the game's loot chat lines (LOOT_ROLL_* - the client's own texts, so every language works) and START_LOOT_ROLL; the
-- dungeon tracker passes them on while you are in a dungeon (no events of its own, nothing runs outside dungeons).
-- Settings (the tracker's cog; user 24.11.: no on / off switch): "Auto-hide rolls after" X seconds (0 = never) and "Always show
-- the current roll" (opens by itself when a roll starts; auto-hide waits until every item has its winner).
local UI = FLT.UI
local L = FLT.L or setmetatable({}, { __index = function(_, k) return k end })
local function N(s) return s end
local LR = {}
FLT.LootRolls = LR

local MAX_ITEMS, STALE = 60, 300 -- items kept per run; a roll without an end counts as over after 5 minutes
local W = 236
local function now() return time() end
local function plain(v) if FLT.IsSecret and FLT.IsSecret(v) then return nil end return v end
local function cfg() return FLT.RunTracker and FLT.RunTracker.Cfg and FLT.RunTracker.Cfg() or {} end

-- a pattern for one of the client's texts, with the order of its arguments ("%2$s" in some languages)
local function compile(fmt)
  if type(fmt) ~= "string" or fmt == "" then return nil end
  -- the client's own text can begin with the loot history link and its number: "|HlootHistory:%d|h[Loot]|h: %s won: %s"
  -- (6.2.17-beta50, user 25.11. 20:38: rolls still "Rolling..." - the extra number moved every argument by one); without it the
  -- arguments are the classic ones (the chat line loses the same tag in clean())
  local pre = fmt:match("^|HlootHistory:.-|h.-|h:?%s*")
  local shift = 0
  if pre then fmt = fmt:sub(#pre + 1); shift = select(2, pre:gsub("%%%d?%$?[sd]", "")) end
  local order, n = {}, 0
  local p = fmt:gsub("%%(%d)%$([sd])", function(i, k) return "\1" .. (tonumber(i) - shift) .. k end)
  p = p:gsub("%%([sd])", function(k) n = n + 1; return "\1" .. n .. k end)
  p = p:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
  p = p:gsub("\1(%d)([sd])", function(i, k) order[#order + 1] = tonumber(i); return k == "d" and "(%d+)" or "(.+)" end)
  return { pat = "^" .. p .. "$", order = order }
end
-- what a line says: kind ("roll" / "pick" / "won" / "pass"), the choice, and which argument is the player, the item, the roll
local RULES = {
  { "LOOT_ROLL_ROLLED_NEED", "roll", "need", name = 3, item = 2, roll = 1 },
  { "LOOT_ROLL_ROLLED_NEED_ROLE_BONUS", "roll", "need", name = 3, item = 2, roll = 1 },
  { "LOOT_ROLL_ROLLED_GREED", "roll", "greed", name = 3, item = 2, roll = 1 },
  { "LOOT_ROLL_ROLLED_DE", "roll", "de", name = 3, item = 2, roll = 1 },
  { "LOOT_ROLL_NEED_SELF", "pick", "need", item = 1, me = true },
  { "LOOT_ROLL_GREED_SELF", "pick", "greed", item = 1, me = true },
  { "LOOT_ROLL_DISENCHANT_SELF", "pick", "de", item = 1, me = true },
  { "LOOT_ROLL_PASSED_SELF_AUTO", "pick", "pass", item = 1, me = true },
  { "LOOT_ROLL_PASSED_SELF", "pick", "pass", item = 1, me = true },
  -- with "less loot spam" the winner line carries the choice and the roll (WoW Forever's own texts, wago GlobalStrings, beta50)
  { "LOOT_ROLL_YOU_WON_NO_SPAM_NEED", "won", "need", item = 2, roll = 1, me = true },
  { "LOOT_ROLL_YOU_WON_NO_SPAM_NEED_OFF_SPEC", "won", "need", item = 2, roll = 1, me = true },
  { "LOOT_ROLL_YOU_WON_NO_SPAM_GREED", "won", "greed", item = 2, roll = 1, me = true },
  { "LOOT_ROLL_YOU_WON_NO_SPAM_DE", "won", "de", item = 2, roll = 1, me = true },
  { "LOOT_ROLL_WON_NO_SPAM_NEED", "won", "need", name = 1, item = 3, roll = 2 },
  { "LOOT_ROLL_WON_NO_SPAM_NEED_OFF_SPEC", "won", "need", name = 1, item = 3, roll = 2 },
  { "LOOT_ROLL_WON_NO_SPAM_GREED", "won", "greed", name = 1, item = 3, roll = 2 },
  { "LOOT_ROLL_WON_NO_SPAM_DE", "won", "de", name = 1, item = 3, roll = 2 },
  { "LOOT_ROLL_LOST_ROLL", "roll", nil, item = 3, roll = 2, me = true }, -- "You have rolled Greed - 23 for: <item>"
  { "LOOT_ROLL_YOU_WON", "won", nil, item = 1, me = true },
  { "LOOT_ROLL_ALL_PASSED", "pass", nil, item = 1 },
  { "LOOT_ROLL_NEED", "pick", "need", name = 1, item = 2 },
  { "LOOT_ROLL_GREED", "pick", "greed", name = 1, item = 2 },
  { "LOOT_ROLL_DISENCHANT", "pick", "de", name = 1, item = 2 },
  { "LOOT_ROLL_PASSED_AUTO_FEMALE", "pick", "pass", name = 1, item = 2 },
  { "LOOT_ROLL_PASSED_AUTO", "pick", "pass", name = 1, item = 2 },
  { "LOOT_ROLL_PASSED", "pick", "pass", name = 1, item = 2 },
  { "LOOT_ROLL_WON", "won", nil, name = 1, item = 2 },
}
local compiled
-- the line without what the client may put round it (6.2.17-beta49, user 25.11. 20:30: rolls stayed "Rolling..." - WoW Forever puts a
-- "[Loot]: " tag (a lootHistory link) before the roll lines and can colour or link the names; Dungeon Journal 2.1.3 handles the same):
-- the tag gone, player links and coloured names as plain text, item links kept
local function clean(text)
  return (text:gsub("|HlootHistory:[^|]*|h.-|h:?%s*", ""):gsub("^%[[^%]|]*%]:%s*", "")
    :gsub("|Hplayer:[^|]*|h%[?([^%]|]*)%]?|h", "%1"):gsub("|c%x%x%x%x%x%x%x%x([^|]*)|r", "%1"))
end
local function parse(text)
  if not compiled then
    compiled = {}
    for _, r in ipairs(RULES) do local c = compile(_G[r[1]]); if c then compiled[#compiled + 1] = { r, c } end end
  end
  text = clean(text)
  for _, rc in ipairs(compiled) do
    local caps = { text:match(rc[2].pat) }
    if caps[1] then
      local a = {}
      for j, i in ipairs(rc[2].order) do a[i] = caps[j] end
      local r = rc[1]
      local name = r.me and true or (r.name and a[r.name])
      local link = r.item and a[r.item]
      local id = type(link) == "string" and tonumber(link:match("item:(%d+)"))
      if id then return r[2], r[3], name, link, id, r.roll and tonumber(a[r.roll]) end
    end
  end
end
LR._parse = parse -- tests

local function me() return plain(UnitName and (UnitName("player"))) or "?" end
local function realName(name)
  if name == true or name == YOU or name == "You" then return me() end
  return (type(name) == "string" and name:gsub("%-.*$", "")) or "?"
end
-- the class of a group member (for the colour), by name. Inside a WoW Forever dungeon the group's names can be hidden values, so the
-- classes are also noted whenever they can be read (joining the group, entering the world) and kept for later (6.2.17-beta60, user
-- 25.11. 21:49: "im loot roll fenster die spielernamen nach klasse einfaerben? und in der historie am besten auch")
local function classStore()
  if type(OneForAllCharDB) ~= "table" then return {} end
  local t = type(OneForAllCharDB.groupClasses) == "table" and OneForAllCharDB.groupClasses or {}
  OneForAllCharDB.groupClasses = t
  return t
end
local function scanGroup()
  local t, raid, n = classStore(), IsInRaid and IsInRaid(), 0
  for _ in pairs(t) do n = n + 1 end
  if n > 300 then wipe(t) end -- an old list does not grow forever
  for i = 1, (GetNumGroupMembers and GetNumGroupMembers()) or 0 do
    local u = raid and ("raid" .. i) or ("party" .. i)
    local okN, nm = pcall(UnitName, u); nm = okN and plain(nm)
    local okC, _, cls = pcall(UnitClass, u); cls = okC and plain(cls)
    if type(nm) == "string" and nm ~= "" and type(cls) == "string" then t[nm] = cls end
  end
end
local function classOf(name)
  if type(name) ~= "string" then return nil end
  if name == me() then return select(2, UnitClass("player")) end
  local raid = IsInRaid and IsInRaid()
  for i = 1, (GetNumGroupMembers and GetNumGroupMembers()) or 0 do
    local u = raid and ("raid" .. i) or ("party" .. i)
    local ok, n = pcall(UnitName, u); n = ok and plain(n)
    if n == name then local okC, _, cls = pcall(UnitClass, u); cls = okC and plain(cls); if cls then classStore()[name] = cls; return cls end end
  end
  return classStore()[name]
end
LR.ClassOf = classOf
do
  local ev = CreateFrame and CreateFrame("Frame")
  if ev then
    ev:RegisterEvent("GROUP_ROSTER_UPDATE"); ev:RegisterEvent("PLAYER_ENTERING_WORLD")
    ev:SetScript("OnEvent", function() pcall(scanGroup) end)
  end
end
-- a player's class, filled in later when it was not known at the roll
local function fillClass(p) if p and not p.c then p.c = classOf(p.n) end return p end
local function player(e, name) for _, p in ipairs(e.p) do if p.n == name then return p end end end
local function isOpen(e) return not e.done and now() - (e.t or 0) < STALE end
-- the item's entry: the newest still open one of that item that has no such line from this player yet, or a new one
local function entryFor(c, id, link, name, want)
  c.rolls = c.rolls or {}
  local any
  for _, e in ipairs(c.rolls) do
    if e.id == id and isOpen(e) then
      any = any or e
      local p = name and player(e, name)
      if want == "end" or (want == "pick" and not (p and p.k)) or (want == "roll" and not (p and p.r)) then return e end
    end
  end
  if any then return any end
  local e = { id = id, link = link, t = now(), p = {} }
  table.insert(c.rolls, 1, e)
  for i = #c.rolls, MAX_ITEMS + 1, -1 do c.rolls[i] = nil end
  return e, true
end

local panel, hideTimer
local refresh, armHide, openPanel
-- still rolling, for the auto-hide: a roll lasts 2 minutes at most, so an item whose winner line never came (out of range, a line we
-- could not read) no longer keeps the list open (6.2.17-beta26, a tester: "ging gar nicht mehr zu obwohl autoclose eingestellt war")
local ROLL_MAX = 130
-- green (and lower) items left out when "Hide green items" is on (6.2.17-beta51, user 25.11. 20:47: "einen schalter ... dass gruene items
-- nicht angezeigt werden, also nur die hoeherstufigen"): quality from the item info, else from the link's colour
local GREEN = { ["1eff00"] = 2, ["ffffff"] = 1, ["9d9d9d"] = 0 }
local function quality(e)
  local q = C_Item and C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(e.id)
  if not q and type(e.link) == "string" then q = GREEN[(e.link:match("|c%x%x(%x%x%x%x%x%x)") or ""):lower()] end
  return q
end
local function hidden(e) if not cfg().rollsNoGreen then return false end local q = quality(e); return q ~= nil and q <= 2 end
LR._hidden = hidden -- tests
local function anyOpen(c) for _, e in ipairs(c and c.rolls or {}) do if not e.done and now() - (e.t or 0) < ROLL_MAX and not hidden(e) then return true end end return false end
LR._anyOpen = anyOpen -- tests
local function changed(c, new, e)
  if new and e and hidden(e) then new = false end -- a hidden green item opens nothing
  if new and cfg().rollsAuto then openPanel(true) end
  if panel and panel:IsShown() then refresh() end
  if new and hideTimer then hideTimer:Cancel(); hideTimer = nil end
  armHide() -- with a roll still running it only looks again in a few seconds
end

-- a loot chat line in a dungeon (from UI/RunTracker.lua): true when it was a roll line
function LR.OnChat(c, text)
  text = plain(text)
  if not (c and type(text) == "string") then return false end
  local kind, choice, name, link, id, roll = parse(text)
  if not kind then return false end
  if kind == "pass" then
    local e, new = entryFor(c, id, link, nil, "end"); e.done = true; e.winner = nil
    changed(c, new, e); return true
  end
  name = realName(name)
  if kind == "won" then
    local e, new = entryFor(c, id, link, name, "end")
    e.done, e.winner = true, name
    local p = player(e, name); if not p then p = { n = name, c = classOf(name) }; e.p[#e.p + 1] = p end
    if roll then p.r = roll end
    if choice then p.k = choice end
    changed(c, new, e); return true
  end
  local e, new = entryFor(c, id, link, name, kind)
  local p = player(e, name)
  if not p then p = { n = name, c = classOf(name) }; e.p[#e.p + 1] = p end
  p.k = choice or p.k
  if kind == "roll" then p.r = roll end
  changed(c, new, e)
  return true
end
-- a roll starts (START_LOOT_ROLL): the item shows at once, before anyone chose
function LR.OnStart(c, rollID)
  if not (c and rollID and GetLootRollItemLink) then return end
  local ok, link = pcall(GetLootRollItemLink, rollID); link = ok and plain(link)
  local id = type(link) == "string" and tonumber(link:match("item:(%d+)"))
  if not id then return end
  for _, e in ipairs(c.rolls or {}) do if e.rollID == rollID and isOpen(e) then return end end
  c.rolls = c.rolls or {}
  local e = { id = id, link = link, t = now(), p = {}, rollID = rollID }
  table.insert(c.rolls, 1, e)
  for i = #c.rolls, MAX_ITEMS + 1, -1 do c.rolls[i] = nil end
  changed(c, true, e)
end

-- the choices: the game's own words and dice / coin / shard / cross
local CHOICE = {
  need = { tex = "Interface\\Buttons\\UI-GroupLoot-Dice-Up", col = { 0.30, 0.85, 0.35 } },
  greed = { tex = "Interface\\Buttons\\UI-GroupLoot-Coin-Up", col = { 1, 0.82, 0.25 } },
  de = { tex = "Interface\\Buttons\\UI-GroupLoot-DE-Up", col = { 0.70, 0.55, 1 } },
  pass = { tex = "Interface\\Buttons\\UI-GroupLoot-Pass-Up", col = { 0.62, 0.62, 0.62 } },
}
local function choiceText(k)
  return (k == "need" and (NEED or "Need")) or (k == "greed" and (GREED or "Greed")) or (k == "de" and (ROLL_DISENCHANT or "Disenchant"))
    or (k == "pass" and (PASS or "Pass")) or ""
end
LR.ChoiceText, LR.ChoiceTex = choiceText, function(k) return CHOICE[k] and CHOICE[k].tex end
local function classCol(cls)
  local cc = cls and RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls]
  if cc then return cc.r, cc.g, cc.b end
  return 0.85, 0.85, 0.85
end
local function itemName(e)
  local name = type(e.link) == "string" and e.link:match("%[(.-)%]")
  local GetInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
  local _, _, q = GetInfo and GetInfo(e.id)
  if not q and C_Item and C_Item.GetItemQualityByID then q = C_Item.GetItemQualityByID(e.id) end
  return name or ("item " .. e.id), q
end
LR.ItemName = itemName
-- the winner's line: name, roll and the choice he won with
function LR.WinnerText(e)
  if not e.done then return "|cffb0b0b0" .. L["Rolling..."] .. "|r" end
  if not e.winner then return "|cff9d9d9d" .. L["All passed"] .. "|r" end
  local p = fillClass(player(e, e.winner))
  local r, g, b = classCol(p and p.c)
  return string.format("|cff%02x%02x%02x%s|r%s", math.floor(r * 255), math.floor(g * 255), math.floor(b * 255), e.winner, (p and p.r) and (" " .. p.r) or "")
end
function LR.Winner(e) return e.done and e.winner and player(e, e.winner) or nil end

-- the panel ------------------------------------------------------------------------------------------------------------------------
local ROW_H, SUB_H = 26, 17
local rows, expanded = {}, setmetatable({}, { __mode = "k" })
local function current() local RT = FLT.RunTracker; return RT and RT.Current and RT.Current() end
local function row(i)
  local r = rows[i]
  if r then return r end
  r = CreateFrame("Button", nil, panel.child); r:SetHeight(ROW_H)
  r.bg = r:CreateTexture(nil, "BACKGROUND"); r.bg:SetAllPoints()
  r.plus = FLT.NewFS(r, nil, "OVERLAY", "GameFontHighlightSmall"); r.plus:SetPoint("LEFT", 4, 0); r.plus:SetWidth(10)
  r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(20, 20); r.icon:SetPoint("LEFT", 16, 0); r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  r.choice = r:CreateTexture(nil, "ARTWORK"); r.choice:SetSize(16, 16); r.choice:SetPoint("RIGHT", -4, 0)
  r.win = FLT.NewFS(r, nil, "OVERLAY", "GameFontHighlightSmall"); r.win:SetPoint("RIGHT", r.choice, "LEFT", -3, 0); r.win:SetJustifyH("RIGHT")
  r.name = FLT.NewFS(r, nil, "OVERLAY", "GameFontHighlightSmall"); r.name:SetPoint("LEFT", r.icon, "RIGHT", 5, 0)
  r.name:SetPoint("RIGHT", r.win, "LEFT", -4, 0); r.name:SetJustifyH("LEFT"); r.name:SetWordWrap(false)
  -- a player's line (the details)
  r.check = r:CreateTexture(nil, "ARTWORK"); r.check:SetSize(12, 12); r.check:SetPoint("LEFT", 6, 0)
  r.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
  r.pname = FLT.NewFS(r, nil, "OVERLAY", "GameFontHighlightSmall"); r.pname:SetPoint("LEFT", 22, 0)
  r.ptype = FLT.NewFS(r, nil, "OVERLAY", "GameFontHighlightSmall"); r.ptype:SetPoint("LEFT", 120, 0)
  r.proll = FLT.NewFS(r, nil, "OVERLAY", "GameFontHighlightSmall"); r.proll:SetPoint("RIGHT", -8, 0)
  local hl = r:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(1, 0.82, 0.3, 0.06)
  r:SetScript("OnClick", function(self) if self.e then expanded[self.e] = not expanded[self.e]; refresh() end end)
  r:SetScript("OnEnter", function(self)
    if not self.e then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    if self.e.link then pcall(GameTooltip.SetHyperlink, GameTooltip, self.e.link) else GameTooltip:SetHyperlink("item:" .. self.e.id) end
    GameTooltip:Show()
  end)
  r:SetScript("OnLeave", function() GameTooltip:Hide() end)
  rows[i] = r
  return r
end
refresh = function()
  if not panel then return end
  local c = current()
  local list = c and c.rolls or {}
  local y, i = 0, 0
  local w = (panel.scroll:GetWidth() or (W - 30))
  for n, e in ipairs(list) do if not hidden(e) then
    i = i + 1
    local r = row(i)
    r.e = e
    r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, -y); r:SetWidth(w); r:SetHeight(ROW_H); y = y + ROW_H + 2
    r.bg:SetColorTexture(1, 1, 1, 0.045)
    local open = expanded[e]; if open == nil then open = isOpen(e) end
    r.plus:SetText(#e.p > 0 and (open and "-" or "+") or "")
    r.icon:SetTexture((C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(e.id)) or "Interface\\Icons\\INV_Misc_QuestionMark")
    local name, q = itemName(e)
    r.name:SetText(name)
    local qc = q and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
    if qc then r.name:SetTextColor(qc.r, qc.g, qc.b) else r.name:SetTextColor(0.9, 0.9, 0.9) end
    r.win:SetText(LR.WinnerText(e))
    local wp = LR.Winner(e)
    r.choice:SetShown(((wp and wp.k) or (e.done and not e.winner)) and true or false)
    r.choice:SetTexture(CHOICE[(wp and wp.k) or "pass"].tex)
    for _, o in ipairs({ r.plus, r.icon, r.name, r.win }) do o:Show() end
    r.check:Hide(); r.pname:Hide(); r.ptype:Hide(); r.proll:Hide()
    r:Show()
    if open then
      -- every player: the winner first, then by roll, then those who passed
      local ps = {}
      for _, p in ipairs(e.p) do ps[#ps + 1] = p end
      table.sort(ps, function(a, b)
        if (a.n == e.winner) ~= (b.n == e.winner) then return a.n == e.winner end
        if (a.k == "pass") ~= (b.k == "pass") then return b.k == "pass" end
        return (a.r or -1) > (b.r or -1)
      end)
      for k, p in ipairs(ps) do
        i = i + 1
        local s = row(i)
        s.e = nil
        s:ClearAllPoints(); s:SetPoint("TOPLEFT", 0, -y); s:SetWidth(w); s:SetHeight(SUB_H); y = y + SUB_H
        s.bg:SetColorTexture(1, 1, 1, k % 2 == 0 and 0.03 or 0)
        for _, o in ipairs({ s.plus, s.icon, s.name, s.win, s.choice }) do o:Hide() end
        s.check:SetShown(p.n == e.winner)
        fillClass(p)
        s.pname:SetText(p.n); s.pname:SetTextColor(classCol(p.c)); s.pname:Show()
        local cc = CHOICE[p.k or ""]
        s.ptype:SetText(choiceText(p.k)); if cc then s.ptype:SetTextColor(cc.col[1], cc.col[2], cc.col[3]) end; s.ptype:Show()
        s.proll:SetText(p.r and tostring(p.r) or ""); s.proll:Show()
        s:Show()
      end
      y = y + 2
    end
  end end
  panel.empty:SetShown(i == 0)
  for k = i + 1, #rows do rows[k]:Hide() end
  panel.child:SetHeight(math.max(1, y))
end
LR._refresh = function() if refresh then refresh() end end -- tests

-- down below the tracker, or up above it when the screen ends below
local function place()
  local f = panel.owner
  panel:ClearAllPoints()
  local bottom = (f:GetBottom() or 0) * (f:GetEffectiveScale() or 1)
  local need = (panel:GetHeight() or 200) * (f:GetEffectiveScale() or 1)
  if bottom - need < 0 then panel:SetPoint("BOTTOM", f, "TOP", 0, 2); panel.up = true
  else panel:SetPoint("TOP", f, "BOTTOM", 0, -2); panel.up = false end
end
armHide = function()
  if hideTimer then hideTimer:Cancel(); hideTimer = nil end
  local s = tonumber(cfg().rollsHide) or 0
  if s <= 0 or not (panel and panel:IsShown()) or not (C_Timer and C_Timer.NewTimer) then return end
  -- a roll still running: look again in a few seconds (before, nothing was armed then and the list stayed open for good)
  if anyOpen(current()) then hideTimer = C_Timer.NewTimer(5, function() hideTimer = nil; armHide() end); return end
  hideTimer = C_Timer.NewTimer(s, function()
    hideTimer = nil
    if not (panel and panel:IsShown()) then return end
    if panel:IsMouseOver() or anyOpen(current()) then armHide() else panel:Hide(); place() end
  end)
end
LR.Rearm = function() armHide() end
openPanel = function(auto)
  if not panel then return end
  if not panel:IsShown() then panel:Show() end
  place(); refresh()
  armHide()
end
function LR.Toggle()
  if not panel then return end
  if panel:IsShown() then panel:Hide(); if hideTimer then hideTimer:Cancel(); hideTimer = nil end; place() else openPanel() end
end

-- on the tracker's bottom line: the arrow that opens the list (UI/RunTracker.lua calls this once it built its window)
function LR.Attach(f)
  if panel then return end
  panel = CreateFrame("Frame", nil, f); panel._ofaNoBG = true; panel.owner = f
  panel.bg = UI.UnmarkBG(UI.FramedPanel(panel))
  panel:SetSize(W, math.max(90, math.min(500, tonumber(cfg().rollsH) or 200)))
  panel:SetFrameStrata("DIALOG"); panel:EnableMouse(true); panel:SetResizable(true)
  if panel.SetResizeBounds then panel:SetResizeBounds(W, 90, W, 500) end
  local title = FLT.NewFS(panel, nil, "OVERLAY", "GameFontNormal"); title:SetPoint("TOPLEFT", 10, -8); title:SetText(L["Loot rolls"])
  local sf = FLT.SkinBlizz(CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate"))
  sf:SetPoint("TOPLEFT", 6, -28); sf:SetPoint("BOTTOMRIGHT", -24, 16)
  local child = CreateFrame("Frame", nil, sf); child:SetSize(W - 30, 1); sf:SetScrollChild(child)
  panel.scroll, panel.child = sf, child
  panel.empty = FLT.NewFS(panel, nil, "OVERLAY", "GameFontDisableSmall"); panel.empty:SetPoint("TOPLEFT", 12, -34)
  panel.empty:SetPoint("RIGHT", -12, 0); panel.empty:SetJustifyH("LEFT"); panel.empty:SetText(L["No loot rolls in this run yet."])
  -- the corner: drag for a taller or shorter list (kept)
  local grip = CreateFrame("Button", nil, panel); grip:SetSize(14, 14); grip:SetPoint("BOTTOMRIGHT", -2, 2)
  grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
  grip:SetScript("OnMouseDown", function() panel:StartSizing(panel.up and "TOP" or "BOTTOM") end)
  grip:SetScript("OnMouseUp", function()
    panel:StopMovingOrSizing()
    local RT = FLT.RunTracker; if RT and RT.Cfg then RT.Cfg().rollsH = math.floor(panel:GetHeight() + 0.5) end
    panel:SetWidth(W); place(); refresh()
  end)
  panel:SetScript("OnLeave", function() armHide() end)
  panel:Hide()
  -- the arrow, in the middle of the tracker's bottom line
  -- the handle of OneForAll's own window (its height grip, grip_height.tga, same size; user 24.11. 23:46: "die gleiche groesse und
  -- breite wie im addon selbst, das schaut dann schoen dezent aus"), here a click opens / closes the list instead of dragging
  -- smaller and dark bronze (user 25.11. 17:15: "etwas kleiner ... vielleicht in dunkel bronze, dann sticht der nicht so hervor")
  local t = CreateFrame("Button", nil, f); t:SetSize(70, 12); t:SetPoint("CENTER", f, "BOTTOM", 0, 1)
  t:SetFrameLevel((f:GetFrameLevel() or 0) + 20)
  local bar = t:CreateTexture(nil, "ARTWORK"); bar:SetSize(44, 11); bar:SetPoint("CENTER")
  FLT.SetTex(bar, UI.ASSET_ROOT .. "grip_height"); bar:SetDesaturated(true); bar:SetVertexColor(0.62, 0.44, 0.22); bar:SetAlpha(0.9)
  local hi = t:CreateTexture(nil, "HIGHLIGHT"); hi:SetSize(44, 11); hi:SetPoint("CENTER")
  FLT.SetTex(hi, UI.ASSET_ROOT .. "grip_height"); hi:SetBlendMode("ADD")
  t:SetScript("OnClick", function() LR.Toggle() end)
  t:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM"); GameTooltip:AddLine(L["Loot rolls"], 1, 0.82, 0.2)
    GameTooltip:AddLine(L["Click: who rolled what on the loot of this run"], 0.8, 0.8, 0.8, true); GameTooltip:Show()
  end)
  t:SetScript("OnLeave", function() GameTooltip:Hide() end)
  panel.toggle = t
  LR.ApplyButton()
  place()
end
-- the cog's "Hide loot-roll button" (6.2.17-beta26, user 25.11.: "standardmaessig aus ... wenn always show the current loot roll aktiv
-- ist, sollte das dann trotzdem erscheinen"): only the handle goes, the list still opens by itself for a new roll
function LR.ApplyButton() if panel and panel.toggle then panel.toggle:SetShown(not cfg().rollsBtnHide) end end
function LR.SetAlpha(a) if panel and panel.bg then panel.bg:SetColor(0.045, 0.045, 0.055, a) end end
LR._panel = function() return panel end -- tests
