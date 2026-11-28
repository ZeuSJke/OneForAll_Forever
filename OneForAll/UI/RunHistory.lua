local ADDON, FLT = ...
-- 6.2.14 (user 23.11.2026: "die character logs ... bei uns im ofa unter dungeons, raids, links in der liste. Name History"):
-- Dungeons & Raids > History - the runs of this character (UI/RunTracker.lua): the list left (newest first, search by name),
-- the run right: time with your best and average for that dungeon, deaths, mobs, XP, gold, every boss with the time it died,
-- the loot you got (with its Gear Value). Built when first opened; redrawn when shown and when a run changes.
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
local function NM(s) return FLT.Name and FLT.Name(s) or s end

function UI.CreateRunHistory(parent)
  local RT = FLT.RunTracker
  local pane = CreateFrame("Frame", nil, parent)
  local head = UI.PageHeader(pane, { x = 0, y = 0, right = 46, placeholder = L["Search name..."],
    onSearch = function(t) pane.search = t; if pane.Refresh then pane:Refresh() end end })
  head:Set("Interface\\Icons\\INV_Misc_Book_09", L["History"], L["Your dungeon and raid runs on this character."])

  local LIST_W = 236
  local lsf = FLT.SkinBlizz(CreateFrame("ScrollFrame", nil, pane, "UIPanelScrollFrameTemplate"))
  lsf:SetPoint("TOPLEFT", 8, -60); lsf:SetPoint("BOTTOMLEFT", 8, 6); lsf:SetWidth(LIST_W); UI.PlaceScrollBar(lsf)
  local lchild = CreateFrame("Frame", nil, lsf); lchild:SetSize(LIST_W, 1); lsf:SetScrollChild(lchild)
  local empty = FLT.NewFS(pane, nil, "OVERLAY", "GameFontDisable"); empty:SetPoint("TOPLEFT", 20, -80); empty:SetWidth(LIST_W - 20)
  empty:SetJustifyH("LEFT"); empty:SetText(L["No runs yet - enter a dungeon."])
  local vl = pane:CreateTexture(nil, "ARTWORK"); vl:SetColorTexture(0.50, 0.38, 0.19, 0.55); vl:SetWidth(1)
  vl:SetPoint("TOPLEFT", LIST_W + 26, -60); vl:SetPoint("BOTTOMLEFT", LIST_W + 26, 6)

  local dsf = FLT.SkinBlizz(CreateFrame("ScrollFrame", nil, pane, "UIPanelScrollFrameTemplate"))
  dsf:SetPoint("TOPLEFT", LIST_W + 36, -60); dsf:SetPoint("BOTTOMRIGHT", -24, 6); UI.PlaceScrollBar(dsf)
  local dchild = CreateFrame("Frame", nil, dsf); dchild:SetSize(400, 1); dsf:SetScrollChild(dchild)
  dsf:SetScript("OnSizeChanged", function(self, w) dchild:SetWidth(math.max(300, w or 400)) end)

  local rows, selected = {}, nil
  local function status(c)
    if c.open and not c.done then return L["In progress"], { 1, 0.82, 0.2 } end
    if c.done then return L["Completed"], { 0.35, 1, 0.45 } end
    return L["Not finished"], { 0.62, 0.60, 0.56 }
  end
  local function dname(c)
    local d = RT.DungeonByKey(c.key)
    return d and (FLT.DungeonName and FLT.DungeonName(d.name) or d.name) or tostring(c.key), d
  end

  -- the run on the right ----------------------------------------------------------------------------------------------
  local det = {}
  local function text(parent, tmpl) return FLT.NewFS(parent, nil, "OVERLAY", tmpl or "GameFontHighlight") end
  det.title = text(dchild, "GameFontNormalLarge"); det.title:SetPoint("TOPLEFT", 4, -4); det.title:SetTextColor(FLT.TextC(1, 0.82, 0.2))
  det.chip = CreateFrame("Frame", nil, dchild); det.chip:SetHeight(20)
  UI.Card(det.chip, det.chip, 4, { 0.50, 0.40, 0.24, 0.90 }, { 0.30, 0.05, 0.04, 0.96 }, "BACKGROUND", 0)
  det.chipText = text(det.chip, "GameFontHighlightSmall"); det.chipText:SetPoint("CENTER")
  det.chip:SetPoint("LEFT", det.title, "RIGHT", 10, 0)
  det.when = text(dchild, "GameFontHighlightSmall"); det.when:SetPoint("TOPLEFT", 4, -28); det.when:SetTextColor(FLT.TextC(0.80, 0.77, 0.70))
  det.state = text(dchild, "GameFontHighlightSmall"); det.state:SetPoint("LEFT", det.when, "RIGHT", 10, 0)
  det.cards = {}
  local CARD_W, CARD_H = 0, 50
  local function card(i)
    local c = det.cards[i]
    if c then return c end
    c = CreateFrame("Frame", nil, dchild); c:SetHeight(CARD_H)
    UI.Card(c, c, 4, { 0.28, 0.25, 0.20, 0.90 }, { 0.060, 0.062, 0.074, 0.97 }, "BACKGROUND", 0)
    c.label = text(c, "GameFontDisableSmall"); c.label:SetPoint("TOPLEFT", 10, -7)
    c.value = text(c, "GameFontHighlightLarge"); c.value:SetPoint("TOPLEFT", 10, -22)
    c.note = text(c, "GameFontDisableSmall"); c.note:SetPoint("BOTTOMRIGHT", -10, 8)
    det.cards[i] = c
    return c
  end
  det.bossHead = UI.SectionTitle(dchild, L["Bosses"], 4, 0, -4)
  det.lootHead = UI.SectionTitle(dchild, L["Loot"], 4, 0, -4)
  det.noLoot = text(dchild, "GameFontDisableSmall")
  det.bossRows, det.lootRows = {}, {}
  -- the loot rolls of the run (6.2.17-beta10, UI/LootRolls.lua): item, winner with roll and choice; hover = every player's roll
  det.rollHead = UI.SectionTitle(dchild, L["Loot rolls"], 4, 0, -4)
  det.rollRows = {}

  local function bossRow(i)
    local r = det.bossRows[i]
    if r then return r end
    r = CreateFrame("Button", nil, dchild); r:SetHeight(34)
    UI.CardRow(r)
    r.f = UI.CreateBossFrame(r, 28, false, true); r.f:SetPoint("LEFT", 4, 0)
    r.name = text(r, "GameFontHighlight"); r.name:SetPoint("LEFT", r.f, "RIGHT", 8, 0)
    r.when = text(r, "GameFontHighlightSmall"); r.when:SetPoint("RIGHT", -10, 0)
    r:SetScript("OnClick", function(self)
      if self.d and UI.OpenDungeon then UI.OpenDungeon(self.d, self.boss and self.boss.name) end
    end)
    det.bossRows[i] = r
    return r
  end
  local function lootRow(i)
    local r = det.lootRows[i]
    if r then return r end
    r = CreateFrame("Button", nil, dchild); r:SetHeight(26)
    r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(22, 22); r.icon:SetPoint("LEFT", 4, 0); r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    r.name = text(r, "GameFontHighlight"); r.name:SetPoint("LEFT", r.icon, "RIGHT", 8, 0)
    r.gv = text(r, "GameFontHighlightSmall"); r.gv:SetPoint("RIGHT", -10, 0)
    local hl = r:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(1, 0.82, 0.3, 0.07) -- a soft hover (the list
    -- highlight texture was a bright white bar, user 23.11.)
    r:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      if GameTooltip.SetItemByID then GameTooltip:SetItemByID(self.id) else GameTooltip:SetHyperlink("item:" .. self.id) end
      GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    det.lootRows[i] = r
    return r
  end

  local function rollRow(i)
    local r = det.rollRows[i]
    if r then return r end
    r = CreateFrame("Button", nil, dchild); r:SetHeight(24)
    r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(20, 20); r.icon:SetPoint("LEFT", 4, 0); r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    r.choice = r:CreateTexture(nil, "ARTWORK"); r.choice:SetSize(16, 16); r.choice:SetPoint("RIGHT", -10, 0)
    r.win = text(r, "GameFontHighlightSmall"); r.win:SetPoint("RIGHT", r.choice, "LEFT", -4, 0)
    r.name = text(r, "GameFontHighlight"); r.name:SetPoint("LEFT", r.icon, "RIGHT", 8, 0); r.name:SetPoint("RIGHT", r.win, "LEFT", -8, 0)
    r.name:SetJustifyH("LEFT"); r.name:SetWordWrap(false)
    local hl = r:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(1, 0.82, 0.3, 0.07)
    r:SetScript("OnEnter", function(self)
      local e, LR = self.e, FLT.LootRolls
      if not (e and LR) then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      if e.link then pcall(GameTooltip.SetHyperlink, GameTooltip, e.link) else GameTooltip:SetHyperlink("item:" .. e.id) end
      GameTooltip:AddLine(" ")
      for _, p in ipairs(e.p or {}) do
        if not p.c and LR.ClassOf then p.c = LR.ClassOf(p.n) end -- the class colour, also for rolls noted before it was known
        local cc = p.c and RAID_CLASS_COLORS and RAID_CLASS_COLORS[p.c]
        GameTooltip:AddDoubleLine((p.n == e.winner and "> " or "") .. p.n, LR.ChoiceText(p.k) .. (p.r and ("  " .. p.r) or ""),
          cc and cc.r or 0.85, cc and cc.g or 0.85, cc and cc.b or 0.85, 0.9, 0.9, 0.9)
      end
      GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    det.rollRows[i] = r
    return r
  end

  local function showRun(c)
    selected = c
    for _, r in ipairs(rows) do if r.card then r.card:SetSelected(r.run == c) end end
    local visible = c ~= nil
    for _, o in ipairs({ det.title, det.chip, det.when, det.state, det.bossHead, det.lootHead, det.noLoot }) do o:SetShown(visible) end
    if not c then det.rollHead:Hide(); for _, r in ipairs(det.rollRows) do r:Hide() end end
    for _, o in ipairs(det.cards) do o:SetShown(visible) end
    if not c then for _, r in ipairs(det.bossRows) do r:Hide() end; for _, r in ipairs(det.lootRows) do r:Hide() end; return end
    local name, d = dname(c)
    det.title:SetText(name)
    det.chipText:SetText(c.party and L["Party"] or L["Solo"]); det.chip:SetWidth((det.chipText:GetStringWidth() or 30) + 18)
    det.when:SetText(date("%d.%m.%Y  %H:%M", c.t0 or 0))
    local st, col = status(c); det.state:SetText(st); det.state:SetTextColor(FLT.TextC(col[1], col[2], col[3]))
    local w = dchild:GetWidth() or 400
    CARD_W = math.floor((w - 16) / 2)
    local best, avg, n = RT.Stats(c.key)
    local dur = RT.Duration(c)
    local items = {
      { L["Time"], RT.Clock(dur), best and string.format(L["Best %s"], RT.Clock(best)) or "" },
      { L["Deaths"], tostring(c.deaths or 0), "" },
      { L["Mobs killed"], tostring(c.trash or 0), "" },
      { L["XP from mobs"], tostring(c.xp or 0), "" },
      { L["Gold earned"], FLT.QoL and FLT.QoL.Money and FLT.QoL.Money(c.gold or 0) or tostring(c.gold or 0),
        -- the loot's value when the tracker adds it (6.2.17-beta4)
        (RT.LootValue and RT.LootValue(c) or 0) > 0 and string.format(L["Loot value %s"], FLT.QoL and FLT.QoL.Money and FLT.QoL.Money(RT.LootValue(c)) or tostring(RT.LootValue(c))) or "" },
      { L["Runs of this dungeon"], tostring(n), avg and string.format(L["Average %s"], RT.Clock(avg)) or "" },
    }
    local y = -56
    for i, it in ipairs(items) do
      local cd = card(i)
      cd:SetWidth(CARD_W); cd:ClearAllPoints(); cd:SetPoint("TOPLEFT", 4 + ((i - 1) % 2) * (CARD_W + 8), y - math.floor((i - 1) / 2) * (CARD_H + 8))
      cd.label:SetText(it[1]); cd.value:SetText(it[2]); cd.note:SetText(it[3]); cd:Show()
    end
    y = y - math.ceil(#items / 2) * (CARD_H + 8) - 6
    det.bossHead:ClearAllPoints(); det.bossHead:SetPoint("TOPLEFT", 4, y); y = y - 24
    -- the fixed bosses first, then the rare / optional ones (marked "Rare" / "Optional"; user 23.11.)
    local bosses = {}
    -- bosses only the other faction can fight are left out unless killed (6.2.17)
    local function mine(b) return not FLT.BossForMe or FLT.BossForMe(b) or (c.kills and c.kills[b.name]) end
    for _, b in ipairs(d and d.bosses or {}) do if not b.rare and mine(b) then bosses[#bosses + 1] = b end end
    for _, b in ipairs(d and d.bosses or {}) do if b.rare and mine(b) then bosses[#bosses + 1] = b end end
    for i, b in ipairs(bosses) do
      local r = bossRow(i)
      r.d, r.boss = d, b
      r:ClearAllPoints(); r:SetPoint("TOPLEFT", 4, y); r:SetPoint("RIGHT", dchild, "RIGHT", -4, 0); y = y - 37
      if r.forBoss ~= b and UI.setBossPortrait then UI.setBossPortrait(r.f.portrait, d, b); r.forBoss = b end
      r.name:SetText(NM(b.name) .. (b.rare and ("  |cffc7ccd8" .. (b.optional and L["Optional"] or L["Rare"]) .. "|r") or ""))
      local k = c.kills and c.kills[b.name]
      r.when:SetText(k and RT.Clock(k) or L["not killed"])
      r.when:SetTextColor(FLT.TextC(k and 0.35 or 0.62, k and 1 or 0.60, k and 0.45 or 0.56))
      r.f.portrait:SetDesaturated(not k); r.name:SetTextColor(FLT.TextC(k and 0.92 or 0.62, k and 0.90 or 0.60, k and 0.84 or 0.56))
      r:Show()
    end
    for i = #bosses + 1, #det.bossRows do det.bossRows[i]:Hide() end
    y = y - 6
    det.lootHead:ClearAllPoints(); det.lootHead:SetPoint("TOPLEFT", 4, y); y = y - 24
    local GV = FLT.GearValue
    local loot = c.loot or {}
    det.noLoot:SetShown(#loot == 0); det.noLoot:ClearAllPoints(); det.noLoot:SetPoint("TOPLEFT", 8, y); det.noLoot:SetText(L["No loot recorded."])
    if #loot == 0 then y = y - 20 end
    local missingNames = false
    for i, id in ipairs(loot) do
      local r = lootRow(i)
      r.id = id
      r:ClearAllPoints(); r:SetPoint("TOPLEFT", 4, y); r:SetPoint("RIGHT", dchild, "RIGHT", -4, 0); y = y - 28
      r.icon:SetTexture((C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)) or "Interface\\Icons\\INV_Misc_QuestionMark")
      local nm, _, q = nil, nil, nil
      if GetItemInfo then nm, _, q = GetItemInfo(id) end
      if not q and C_Item and C_Item.GetItemQualityByID then q = C_Item.GetItemQualityByID(id) end
      r.name:SetText(nm or ("item " .. id))
      if not nm then missingNames = true; if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end end
      r.name:SetTextColor(qualityColor(q))
      local s = ""
      if GV and GV.Change then
        local ok, kind, pct = pcall(GV.Change, id)
        if ok and (kind == "up" or kind == "new") and pct then s = string.format("|cff4dff60+%.1f%%|r", pct)
        elseif ok and kind == "worn" then s = "|cff9d9d9d" .. L["Worn"] .. "|r" end
      end
      r.gv:SetText(s)
      r:Show()
    end
    for i = #loot + 1, #det.lootRows do det.lootRows[i]:Hide() end
    local rolls, LR = c.rolls or {}, FLT.LootRolls
    det.rollHead:SetShown(#rolls > 0 and LR and true or false)
    if #rolls > 0 and LR then
      y = y - 6
      det.rollHead:ClearAllPoints(); det.rollHead:SetPoint("TOPLEFT", 4, y); y = y - 24
      for i, e in ipairs(rolls) do
        local r = rollRow(i)
        r.e = e
        r:ClearAllPoints(); r:SetPoint("TOPLEFT", 4, y); r:SetPoint("RIGHT", dchild, "RIGHT", -4, 0); y = y - 26
        r.icon:SetTexture((C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(e.id)) or "Interface\\Icons\\INV_Misc_QuestionMark")
        local nm, q = LR.ItemName(e)
        r.name:SetText(nm); r.name:SetTextColor(qualityColor(q))
        r.win:SetText(LR.WinnerText(e))
        local wp = LR.Winner(e)
        local tex = LR.ChoiceTex((wp and wp.k) or (e.done and not e.winner and "pass") or "")
        r.choice:SetShown(tex and true or false); if tex then r.choice:SetTexture(tex) end
        r:Show()
      end
    end
    for i = (LR and #rolls or 0) + 1, #det.rollRows do det.rollRows[i]:Hide() end
    dchild:SetHeight(math.max(1, -y + 8))
    -- item names the client does not know yet: draw again when they came (at most 3 times a second apart)
    if det.nameFor ~= c then det.nameFor, det.nameTries = c, 0 end
    if missingNames and det.nameTries < 3 and C_Timer and C_Timer.After then
      det.nameTries = det.nameTries + 1
      C_Timer.After(1, function() if selected == c and dchild:IsVisible() then showRun(c) end end)
    end
  end

  -- the list on the left ------------------------------------------------------------------------------------------------
  local function row(i)
    local r = rows[i]
    if r then return r end
    r = CreateFrame("Button", nil, lchild); r:SetSize(LIST_W - 4, 46)
    r.card = UI.CardRow(r)
    r.name = text(r, "GameFontNormal"); r.name:SetPoint("TOPLEFT", 10, -7); r.name:SetPoint("RIGHT", -34, 0)
    r.name:SetJustifyH("LEFT"); r.name:SetWordWrap(false); r.name:SetTextColor(FLT.TextC(1, 0.82, 0.2))
    r.sub = text(r, "GameFontHighlightSmall"); r.sub:SetPoint("TOPLEFT", 10, -26)
    r.del = UI.CloseButton(r, function(self)
      local run = self:GetParent().run
      if run and UI.Confirm then UI.Confirm(L["Delete this run?"], function() RT.Delete(run) end) end
    end)
    r.del:SetSize(20, 18); r.del:SetPoint("RIGHT", -6, 0)
    r.del:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:SetText(L["Delete this run?"]); GameTooltip:Show() end)
    r:SetScript("OnClick", function(self) showRun(self.run) end)
    rows[i] = r
    return r
  end

  function pane:Refresh()
    local list = RT.Runs() or {}
    local q = self.search or ""
    local n, keep = 0, false
    for _, c in ipairs(list) do
      local name = dname(c)
      if q == "" or name:lower():find(q, 1, true) then
        n = n + 1
        local r = row(n)
        r.run = c
        r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, -(n - 1) * 50)
        r.name:SetText(name)
        local st, col = status(c)
        r.sub:SetText(string.format("%s  |cffffffff%s|r  |cff%02x%02x%02x%s|r", date("%d.%m. %H:%M", c.t0 or 0), RT.Clock(RT.Duration(c)),
          math.floor(col[1] * 255), math.floor(col[2] * 255), math.floor(col[3] * 255), st))
        r:Show()
        if c == selected then keep = true end
      end
    end
    for i = n + 1, #rows do rows[i]:Hide(); rows[i].run = nil end
    lchild:SetHeight(math.max(1, n * 50))
    empty:SetShown(n == 0)
    showRun(keep and selected or (n > 0 and rows[1].run) or nil)
  end
  pane:SetScript("OnShow", function(self) self:Refresh() end)
  RT.onChange = function() if pane:IsVisible() then pane:Refresh() end end
  return pane
end
