local _, FLT = ...
local L = FLT.L or setmetatable({}, { __index = function(_, k) return k end }) -- (tests without Locales)
local UI = FLT.UI
local GetItemIcon = (C_Item and C_Item.GetItemIconByID) or GetItemIcon
local GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local unpack = unpack or table.unpack

-- Professions > the gathering professions, Fishing and Lockpicking (6.2.18-beta13, user 27.11.2026: "alle professions ...
-- auch skinning, herbalism, fishing ... lockpicking"):
--   UI.CreateGatherPage  - the Skill-Up Helper of these: where to level which skill range (Data/GatheringGuide.lua)
--   UI.CreateTrainerPage - "Trainers" of every profession: the ranks and which trainer teaches which rank
-- Lean: each profession's cards are built once on first view; a refresh only paints your skill into them.

local function N(t) return t end -- marks English texts translated where shown (tools/locale/extract.py)
local _RANKS = { N"Apprentice", N"Journeyman", N"Expert", N"Artisan" }
local GOLD, DIM, TEXT = UI.GOLD or { 1, 0.82, 0.20 }, { 0.62, 0.60, 0.56 }, { 0.88, 0.86, 0.80 }
local CAPS = { 75, 150, 225, 300 }
local BITS = { 1, 2, 4, 8 }
local function ZN(z) return FLT.ZoneName and FLT.ZoneName(z) or z end
local function NM(s) return FLT.Name and FLT.Name(s) or s end
local function icon(id) return (id and GetItemIcon and GetItemIcon(id)) or "Interface\\Icons\\INV_Misc_QuestionMark" end
local function money(c) if FLT.QoL and FLT.QoL.Money then return FLT.QoL.Money(c or 0) end return tostring(c) end
local function newText(parent, font, w, color)
  local fs = FLT.NewFS(parent, nil, "OVERLAY", font or "GameFontHighlight")
  if w then fs:SetWidth(w) end
  fs:SetJustifyH("LEFT")
  if color then fs:SetTextColor(FLT.TextC(unpack(color))) end
  return fs
end
local function myFaction()
  local f = UnitFactionGroup and UnitFactionGroup("player")
  return (f == "Alliance" and "A") or (f == "Horde" and "H") or nil
end

-- Lockpicking has no profession spell: its skill line in the client's language
local LOCK_NAMES = { Lockpicking = true, Schlossknacken = true, Crochetage = true, ["Forzar cerraduras"] = true,
  ["Abrir cerraduras"] = true, Arrombamento = true, ["Взлом замков"] = true }
FLT.LOCKPICK_ICON = "Interface\\Icons\\Spell_Nature_MoonKey"
-- our key for a skill line name ("Bergbau" -> "Mining", "Schlossknacken" -> "Lockpicking")
function FLT.SkillKey(name)
  if type(name) ~= "string" then return nil end
  if LOCK_NAMES[name] then return "Lockpicking" end
  return FLT.ProfKey and FLT.ProfKey(name) or name
end
-- your skill and its current cap in a profession (from the skill list, read when asked); nil = not learned
function FLT.ProfSkill(prof)
  -- the Forever client lists professions with GetProfessions (beta15: Herbalism showed "Not learned yet" with the skill lines alone)
  if GetProfessions and GetProfessionInfo then
    local list = { GetProfessions() }
    for k = 1, 6 do
      if list[k] then
        local ok, name, _, rank, maxRank = pcall(GetProfessionInfo, list[k])
        if ok and FLT.SkillKey(name) == prof then return tonumber(rank), tonumber(maxRank) end
      end
    end
  end
  if GetNumSkillLines and GetSkillLineInfo then
    for i = 1, GetNumSkillLines() or 0 do
      local name, isHeader, _, rank, _, _, maxRank = GetSkillLineInfo(i)
      if not isHeader and FLT.SkillKey(name) == prof then return tonumber(rank), tonumber(maxRank) end
    end
  end
  local p = type(OneForAllCharDB) == "table" and type(OneForAllCharDB.professions) == "table" and OneForAllCharDB.professions[prof]
  if type(p) == "table" and tonumber(p.skill) then return tonumber(p.skill), tonumber(p.maxSkill) end
  return nil
end

-- the classic gathering colours: orange until 25 over the need, yellow until 50, green until 100, then grey (red: not yet)
local function nodeColor(need, skill)
  if not skill or skill < need then return 0.85, 0.25, 0.20 end
  local d = skill - need
  if d < 25 then return 1, 0.50, 0.15 elseif d < 50 then return 1, 0.86, 0.15 elseif d < 100 then return 0.30, 0.85, 0.30 end
  return 0.55, 0.55, 0.55
end
-- Skinning: the highest beast level your skill can skin
local function skinLevel(skill)
  if skill >= 100 then return math.floor(skill / 5) end
  if skill >= 10 then return math.floor(skill / 10) + 10 end
  return 10
end

local function itemTip(self)
  if not self.item then return end
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  if GameTooltip.SetItemByID then GameTooltip:SetItemByID(self.item) else GameTooltip:SetHyperlink("item:" .. self.item) end
  if self.need then GameTooltip:AddLine(string.format(L["Needs skill %d"], self.need), 1, 0.82, 0) end
  if self.keep then GameTooltip:AddLine(string.format(L["Keep about %d for Cooking"], self.keep), 0.4, 0.9, 0.4) end
  GameTooltip:Show()
end
local function iconButton(parent, size)
  local b = CreateFrame("Button", nil, parent); b:SetSize(size, size)
  b.tex = b:CreateTexture(nil, "ARTWORK"); b.tex:SetAllPoints(); b.tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  local ring = b:CreateTexture(nil, "OVERLAY"); ring:SetPoint("TOPLEFT", -1, 1); ring:SetPoint("BOTTOMRIGHT", 1, -1)
  FLT.SetTex(ring, UI.ASSET_ROOT .. "talent_frame"); b.ring = ring
  b:SetScript("OnEnter", itemTip); b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return b
end
-- a row of zone buttons (your faction's zones and those for both); returns the height used
local function zoneButtons(parent, step, x, y, maxW)
  local fac, list = myFaction(), {}
  for _, z in ipairs((fac == "A" and step.A) or (fac == "H" and step.H) or {}) do list[#list + 1] = z end
  if not fac then for _, k in ipairs({ "A", "H" }) do for _, z in ipairs(step[k] or {}) do list[#list + 1] = z end end end
  for _, z in ipairs(step.B or {}) do list[#list + 1] = z end
  local cx, cy = x, y
  for _, z in ipairs(list) do
    local b = UI.GoldButton(parent, ZN(z), 40, 20, UI.ASSET_ROOT .. "icon_map", 11, true)
    local w = b:GetWidth() or 60
    if cx > x and cx + w > x + maxW then cx, cy = x, cy - 24 end
    b:SetPoint("TOPLEFT", cx, cy); cx = cx + w + 6
    b:SetScript("OnClick", function() FLT:ShowZoneMap(z) end)
    b:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:AddLine(ZN(z), 1, 0.82, 0)
      GameTooltip:AddLine(L["Click: open the world map there"], 0.85, 0.85, 0.85); GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end
  return #list > 0 and (y - cy + 24) or 0
end
local recipeIdx
local function cookRecipe(spell)
  if not recipeIdx then
    recipeIdx = {}
    for _, r in ipairs(FLT.PROFESSION_RECIPES and FLT.PROFESSION_RECIPES.Cooking or {}) do recipeIdx[r.s] = r end
  end
  return recipeIdx[spell]
end

-- SKILL-UP HELPER of the gathering professions ---------------------------------------------------------------
function UI.CreateGatherPage(parent)
  local f = CreateFrame("Frame", nil, parent); f:SetAllPoints(); f:Hide()
  local sf = FLT.SkinBlizz(CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate"))
  sf:SetPoint("TOPLEFT", 0, 0); sf:SetPoint("BOTTOMRIGHT", -26, 0)
  UI.AutoHideScrollBar(sf)
  local W = 780
  local pages, cur = {}, nil

  local function build(prof)
    local g = FLT.GATHER_GUIDE and FLT.GATHER_GUIDE[prof]
    local c = CreateFrame("Frame", nil, sf); c:SetSize(W, 1); c:Hide()
    local page = { frame = c, cards = {}, nodes = {} }
    UI.SectionTitle(c, L["Skill-Up Helper"], 8, -4, -20)
    -- header box: your skill, the next rank, the tool, the rule
    local box = CreateFrame("Frame", nil, c); box:SetPoint("TOPLEFT", 10, -30); box:SetSize(W - 20, 84)
    UI.MarkBG(UI.RoundRect(box, box, "BACKGROUND", 0, 7, 1, 0.07, 0.06, 0.05, 0.95))
    UI.RoundRect(box, box, "BORDER", 0, 8, 0, 0.45, 0.35, 0.20, 0.9, UI.ASSET_ROOT .. "window_ring")
    page.skill = newText(box, "GameFontHighlight", 420); page.skill:SetPoint("TOPLEFT", 14, -10)
    page.hint = newText(box, "GameFontHighlightSmall", W - 50, TEXT); page.hint:SetPoint("TOPLEFT", 14, -32); page.hint:SetWordWrap(false)
    page.rule = newText(box, "GameFontDisableSmall", W - 50); page.rule:SetPoint("TOPLEFT", 14, -52); page.rule:SetWordWrap(true)
    page.rule:SetText(g and g.rule and L[g.rule] or "")
    if g and g.tool then
      local tb = iconButton(box, 22); tb:SetPoint("TOPRIGHT", -14, -9); tb.item = g.tool; FLT.SetTex(tb.tex, icon(g.tool))
      local tl = newText(box, "GameFontHighlightSmall", nil, DIM); tl:SetPoint("RIGHT", tb, "LEFT", -6, 0); tl:SetJustifyH("RIGHT")
      tl:SetText(L["Needed in your bags:"])
    end
    local y = -124
    -- what you can gather and from which skill (herbs, ores), coloured for your skill
    if g and g.nodes then
      local t = UI.SectionTitle(c, L["What you can gather"], 8, y, -20); y = y - 26
      local per = math.floor((W - 20) / 52)
      for i, n in ipairs(g.nodes) do
        local b = iconButton(c, 26); b.item, b.need = n[1], n[2]; FLT.SetTex(b.tex, icon(n[1]))
        b:SetPoint("TOPLEFT", 14 + ((i - 1) % per) * 52, y - math.floor((i - 1) / per) * 46)
        b.num = newText(c, "GameFontNormalSmall"); b.num:SetPoint("TOP", b, "BOTTOM", 0, -2); b.num:SetJustifyH("CENTER")
        b.num:SetText(tostring(n[2]))
        page.nodes[i] = b
      end
      y = y - math.ceil(#g.nodes / per) * 46 - 6
      local legend = newText(c, "GameFontDisableSmall", W - 30); legend:SetPoint("TOPLEFT", 14, y)
      legend:SetText(L["The number is the skill a node needs; the colour shows how likely it raises yours (orange, yellow, green, grey)."])
      y = y - 22
      local _ = t
    end
    -- the steps
    UI.SectionTitle(c, L["Where to level"], 8, y, -20); y = y - 28
    for i, st in ipairs(g and g.steps or {}) do
      local card = CreateFrame("Frame", nil, c); card:SetPoint("TOPLEFT", 8, y); card:SetWidth(W - 16)
      card.card = UI.CardRow(card)
      local range = newText(card, "GameFontNormalLarge", 90, GOLD); range:SetPoint("TOPLEFT", 12, -10)
      range:SetText(st[1] .. " - " .. st[2])
      card.now = newText(card, "GameFontNormalSmall", 90); card.now:SetPoint("TOPLEFT", 12, -32)
      local x0, cy, inner = 110, -10, W - 16 - 122
      -- items (herbs, ores, leather, fish) with the lure
      local ix = x0
      for _, id in ipairs(st.items or {}) do
        local b = iconButton(card, 24); b.item = id; FLT.SetTex(b.tex, icon(id)); b:SetPoint("TOPLEFT", ix, cy); ix = ix + 28
        -- Fishing: about how many to keep for Cooking, like a stack count
        local n = st.keep and st.keep[id]
        if n then
          b.keep = n
          local c = FLT.NewFS(b, nil, "OVERLAY", "NumberFontNormal"); c:SetPoint("BOTTOMRIGHT", 2, -2); c:SetText(n)
        end
      end
      if st.lure then
        local lt = newText(card, "GameFontHighlightSmall", nil, DIM); lt:SetPoint("TOPLEFT", ix + 10, cy - 5); lt:SetText(L["Lure:"])
        local b = iconButton(card, 24); b.item = st.lure; FLT.SetTex(b.tex, icon(st.lure))
        b:SetPoint("LEFT", lt, "RIGHT", 6, 0)
      end
      if st.items or st.lure then cy = cy - 30 end
      -- the beasts (Skinning) or lockboxes (Lockpicking)
      if st.mobs or st.objs then
        local names = {}
        for _, n in ipairs(st.mobs or st.objs) do names[#names + 1] = NM(n) end
        local t = newText(card, "GameFontHighlightSmall", inner, TEXT); t:SetPoint("TOPLEFT", x0, cy)
        t:SetText(table.concat(names, ", ") .. (st.lv and ("  |cff9d9d9d(" .. string.format(L["level %s"], st.lv) .. ")|r") or ""))
        cy = cy - (t:GetStringHeight() or 12) - 6
      elseif st.lv then
        local t = newText(card, "GameFontHighlightSmall", inner, TEXT); t:SetPoint("TOPLEFT", x0, cy)
        t:SetText(string.format(L["Beasts of level %s"], st.lv)); cy = cy - 18
      end
      cy = cy - zoneButtons(card, st, x0, cy, inner)
      -- cooking along (Fishing)
      for _, ck in ipairs(st.cook or {}) do
        local r = cookRecipe(ck[1])
        local b = CreateFrame("Button", nil, card); b:SetSize(inner, 18); b:SetPoint("TOPLEFT", x0, cy)
        local ic = b:CreateTexture(nil, "ARTWORK"); ic:SetSize(16, 16); ic:SetPoint("LEFT", 0, 0)
        FLT.SetTex(ic, r and icon(r.i) or FLT.PROFESSION_ICONS and FLT.PROFESSION_ICONS.Cooking)
        local t = newText(b, "GameFontHighlightSmall", inner - 24, TEXT); t:SetPoint("LEFT", 22, 0)
        local rn = r and (FLT.RecipeName and FLT.RecipeName(r) or r.n) or tostring(ck[1])
        local extra = (ck[4] and string.format(L["about %d"], ck[4])) or (ck[5] and L[ck[5]])
        t:SetText(string.format(L["Cooking %d-%d: %s"], ck[2], ck[3], "|cffffd200" .. rn .. "|r") .. (extra and ("  |cff9d9d9d(" .. extra .. ")|r") or ""))
        local hl = b:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(FLT.SkinC(0.90, 0.66, 0.22, 0.08))
        b:SetScript("OnClick", function() if FLT.ShowRecipeInProfessions then FLT.ShowRecipeInProfessions("Cooking", ck[1]) end end)
        b:SetScript("OnEnter", function(self)
          GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:AddLine(rn, 1, 0.82, 0)
          GameTooltip:AddLine(L["Click: show the recipe under Cooking"], 0.85, 0.85, 0.85); GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        cy = cy - 20
      end
      if st.note then
        local t = newText(card, "GameFontDisableSmall", inner); t:SetPoint("TOPLEFT", x0, cy - 2); t:SetText(L[st.note])
        cy = cy - (t:GetStringHeight() or 12) - 6
      end
      -- the NPCs the note names (book, quest, recipe), with a map button each (your faction's)
      if st.npcs then
        local fac, nx, any = myFaction(), x0, false
        for _, id in ipairs(st.npcs) do
          local t = FLT.PROFESSION_RANK_NPCS and FLT.PROFESSION_RANK_NPCS[id]
          if t and (not fac or t[4] == "AH" or t[4] == fac) then
            local b = UI.GoldButton(card, NM(t[2]), 40, 20, UI.ASSET_ROOT .. "icon_map", 11, true)
            local w = b:GetWidth() or 80
            if nx > x0 and nx + w > x0 + inner then nx, cy = x0, cy - 24 end
            b:SetPoint("TOPLEFT", nx, cy); nx = nx + w + 6; any = true
            b:SetScript("OnClick", function() FLT:ShowOnMap({ mapID = t[5], x = t[6], y = t[7], name = NM(t[2]) }) end)
            b:SetScript("OnEnter", function(self)
              GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:AddLine(NM(t[2]), 1, 0.82, 0)
              if t[3] and t[3] ~= "" then GameTooltip:AddLine("<" .. t[3] .. ">", 0.8, 0.8, 0.8) end
              GameTooltip:AddLine(string.format("%s (%.1f, %.1f)", ZN(t[8]), t[6], t[7]), 0.85, 0.82, 0.74)
              GameTooltip:AddLine(L["Click: show on the world map"], 0.85, 0.85, 0.85); GameTooltip:Show()
            end)
            b:SetScript("OnLeave", function() GameTooltip:Hide() end)
          end
        end
        if any then cy = cy - 26 end
      end
      card:SetHeight(math.max(58, -cy + 8))
      card.from, card.to = st[1], st[2]
      page.cards[i] = card
      y = y - card:GetHeight() - 6
    end
    -- Mining: smelting along
    if g and g.smelt then
      y = y - 6
      UI.SectionTitle(c, L["Smelting along"], 8, y, -20); y = y - 28
      for _, sm in ipairs(g.smelt) do
        local b = iconButton(c, 20); b.item = sm[3]; FLT.SetTex(b.tex, icon(sm[3])); b:SetPoint("TOPLEFT", 110, y)
        local r = newText(c, "GameFontNormal", 86, GOLD); r:SetPoint("TOPLEFT", 16, y - 3); r:SetText(sm[1] .. " - " .. sm[2])
        local t = newText(c, "GameFontHighlightSmall", 400, TEXT); t:SetPoint("LEFT", b, "RIGHT", 8, 0)
        local nm = FLT.ItemName and FLT.ItemName(sm[3]) or ((GetItemInfo and GetItemInfo(sm[3])) or (L["Item"] .. " " .. sm[3]))
        t:SetText(string.format(L["%s - about %d smelts"], nm, sm[4]))
        y = y - 24
      end
      if g.smeltNote then local t = newText(c, "GameFontDisableSmall", W - 40); t:SetPoint("TOPLEFT", 16, y - 2); t:SetText(L[g.smeltNote]); y = y - 22 end
    end
    c:SetHeight(-y + 10)
    return page
  end

  local function paint(prof, page)
    local skill, max = FLT.ProfSkill(prof)
    if prof == "Lockpicking" then
      local lvl = UnitLevel and UnitLevel("player") or 0
      page.skill:SetText(skill and string.format(L["Your skill: %d / %d"], skill, max or skill) or L["Not learned yet"])
      page.hint:SetText(string.format(L["At your level it can go up to %d."], math.min(300, (lvl or 0) * 5)))
    else
      page.skill:SetText(skill and string.format(L["Your skill: %d / %d"], skill, max or skill) or L["Not learned yet"])
      -- the next rank to learn (Data/ProfessionFees.lua ranks): a reminder once your cap is near
      local hint
      local ranks = FLT.PROFESSION_FEES and FLT.PROFESSION_FEES[prof] and FLT.PROFESSION_FEES[prof].ranks or {}
      for _, rk in ipairs(ranks) do
        if (max or 0) < rk[3] then
          if skill and skill >= rk[5] then
            hint = string.format(L["Learn %s now (needs skill %d) - see Trainers."], L[rk[1]], rk[5])
          else
            hint = string.format(L["Next: %s from skill %d raises the cap to %d."], L[rk[1]], rk[5], rk[3])
          end
          break
        end
      end
      if prof == "Skinning" and skill then
        hint = (hint and (hint .. "  ") or "") .. string.format(L["You can skin beasts up to level %d."], skinLevel(skill))
      end
      page.hint:SetText(hint or "")
    end
    for _, b in ipairs(page.nodes) do b.num:SetTextColor(nodeColor(b.need, skill)) end
    local nowCard
    for _, card in ipairs(page.cards) do
      local s = skill or 0
      local isNow = s >= card.from and s < card.to
      card.card:SetSelected(isNow)
      if isNow then card.now:SetText(L["you are here"]); card.now:SetTextColor(FLT.TextC(1, 0.82, 0.2)); nowCard = card
      elseif s >= card.to then card.now:SetText(L["done"]); card.now:SetTextColor(0.45, 0.75, 0.45)
      else card.now:SetText("") end
    end
    return nowCard
  end

  function f:ShowProfession(prof)
    if cur and pages[cur] then pages[cur].frame:Hide() end
    cur = prof
    local page = pages[prof]
    if not page then page = build(prof); pages[prof] = page end
    sf:SetScrollChild(page.frame); page.frame:Show()
    local nowCard = paint(prof, page)
    f:Show()
    -- scroll to your step
    local top = nowCard and nowCard.GetTop and nowCard:GetTop()
    local ctop = page.frame.GetTop and page.frame:GetTop()
    sf:SetVerticalScroll(0)
    if top and ctop and type(top) == "number" and type(ctop) == "number" and ctop - top > 200 then
      sf:SetVerticalScroll(math.max(0, math.min(ctop - top - 120, sf:GetVerticalScrollRange() or 0)))
    end
  end
  f:SetScript("OnShow", function() if cur and pages[cur] then paint(cur, pages[cur]) end end)
  return f
end

-- TRAINERS of a profession ---------------------------------------------------------------------------------
function UI.CreateTrainerPage(parent)
  local f = CreateFrame("Frame", nil, parent); f:SetAllPoints(); f:Hide()
  local W = 780
  UI.SectionTitle(f, L["Ranks"], 8, -4, -20)
  -- the four rank cards
  local rankCards = {}
  local CW = math.floor((W - 16 - 18) / 4)
  for i = 1, 4 do
    local rc = CreateFrame("Frame", nil, f); rc:SetSize(CW, 92); rc:SetPoint("TOPLEFT", 8 + (i - 1) * (CW + 6), -30)
    rc.card = UI.CardRow(rc)
    rc.name = newText(rc, "GameFontNormal", CW - 20, GOLD); rc.name:SetPoint("TOPLEFT", 10, -8)
    rc.cap = newText(rc, "GameFontHighlightSmall", CW - 20, TEXT); rc.cap:SetPoint("TOPLEFT", 10, -26)
    rc.req = newText(rc, "GameFontHighlightSmall", CW - 20, DIM); rc.req:SetPoint("TOPLEFT", 10, -42)
    rc.how = newText(rc, "GameFontHighlightSmall", CW - 20, TEXT); rc.how:SetPoint("TOPLEFT", 10, -58); rc.how:SetWordWrap(true)
    rc.map = UI.GoldButton(rc, "Map", 20, 20, UI.ASSET_ROOT .. "icon_map"); rc.map:SetPoint("TOPRIGHT", -6, -6)
    rankCards[i] = rc
  end
  -- the list below the cards; it moves down when a card needs more lines (beta15: Expert Fishing ran over the frame)
  local below = CreateFrame("Frame", nil, f); below:SetPoint("TOPLEFT", 0, -132); below:SetPoint("BOTTOMRIGHT", 0, 0)
  UI.SectionTitle(below, L["Trainers of your faction"], 8, 0, -20)
  local legend = newText(below, "GameFontDisableSmall", W - 30); legend:SetPoint("TOPLEFT", 12, -22)
  legend:SetText(L["The four marks show up to which skill a trainer teaches: 75, 150, 225, 300."])
  local sf = FLT.SkinBlizz(CreateFrame("ScrollFrame", nil, below, "UIPanelScrollFrameTemplate"))
  sf:SetPoint("TOPLEFT", 0, -40); sf:SetPoint("BOTTOMRIGHT", -26, 0)
  local child = CreateFrame("Frame", nil, sf); child:SetSize(W, 1); sf:SetScrollChild(child)
  UI.AutoHideScrollBar(sf)
  local rows, heads = {}, {}
  local function row(i)
    local r = rows[i]; if r then return r end
    r = CreateFrame("Frame", nil, child); r:SetSize(W - 16, 30); r:EnableMouse(true)
    local hi = r:CreateTexture(nil, "HIGHLIGHT"); hi:SetAllPoints(); hi:SetColorTexture(FLT.SkinC(0.90, 0.66, 0.22, 0.07))
    local ln = r:CreateTexture(nil, "BORDER"); ln:SetColorTexture(0.40, 0.32, 0.20, 0.35); ln:SetHeight(1)
    ln:SetPoint("BOTTOMLEFT", 4, 0); ln:SetPoint("BOTTOMRIGHT", -4, 0)
    r.name = newText(r, "GameFontHighlight", 250); r.name:SetPoint("LEFT", 10, 0); r.name:SetWordWrap(false)
    r.zone = newText(r, "GameFontHighlightSmall", 230, DIM); r.zone:SetPoint("LEFT", 266, 0); r.zone:SetWordWrap(false)
    r.marks = {}
    for k = 1, 4 do
      local m = CreateFrame("Frame", nil, r); m:SetSize(34, 18); m:SetPoint("LEFT", 504 + (k - 1) * 38, 0)
      m.bg = UI.RoundRect(m, m, "BACKGROUND", 0, 5, 0, 1, 1, 1, 1)
      m.t = newText(m, "GameFontNormalSmall"); m.t:SetPoint("CENTER", 0, 0); m.t:SetJustifyH("CENTER"); m.t:SetText(CAPS[k])
      r.marks[k] = m
    end
    r.map = UI.GoldButton(r, "Map", 22, 22, UI.ASSET_ROOT .. "icon_map"); r.map:SetPoint("RIGHT", -8, 0)
    r:SetScript("OnEnter", function(self)
      local t = self.t; if not t then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:AddLine(t[2], 1, 0.82, 0)
      if t[3] and t[3] ~= "" then GameTooltip:AddLine("<" .. t[3] .. ">", 0.8, 0.8, 0.8) end
      GameTooltip:AddLine(string.format("%s (%.1f, %.1f)", ZN(t[8]), t[6], t[7]), 0.85, 0.82, 0.74)
      if self.guess then
        GameTooltip:AddLine(L["Which ranks this trainer teaches is not known yet - talk to them once and OneForAll remembers it."], 0.9, 0.7, 0.3, true)
      else
        for k = 1, 4 do
          if math.floor(self.mask / BITS[k]) % 2 == 1 then GameTooltip:AddLine(string.format(L["%s (up to %d)"], L[_RANKS[k]], CAPS[k]), 1, 1, 1) end
        end
      end
      GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    rows[i] = r
    return r
  end
  local function head(i)
    local h = heads[i]; if h then return h end
    h = CreateFrame("Frame", nil, child); h:SetSize(W - 16, 24)
    h.text = newText(h, "GameFontNormalSmall", W - 30, UI.HEAD_GOLD or GOLD); h.text:SetPoint("LEFT", 6, -2)
    local line = UI.makeTexture(h, "ARTWORK", 0.72, 0.50, 0.12, 0.45); line:SetPoint("BOTTOMLEFT", 2, 0); line:SetPoint("BOTTOMRIGHT", -2, 0); line:SetHeight(1)
    heads[i] = h
    return h
  end
  local function mapTo(btn, t, prof)
    if t then
      btn:Enable(); if btn.SetLook then btn:SetLook(true) end
      btn:SetScript("OnClick", function() FLT:ShowOnMap({ mapID = t[5], x = t[6], y = t[7], name = t[2] .. " (" .. L[prof] .. ")" }) end)
    else
      btn:Disable(); if btn.SetLook then btn:SetLook(false) end; btn:SetScript("OnClick", nil)
    end
  end
  local GROUPS = { { 8, N"Teach up to Artisan (300)" }, { 4, N"Teach up to Expert (225)" }, { 2, N"Teach up to Journeyman (150)" },
    { 1, N"Apprentice only (75)" } }

  function f:ShowProfession(prof)
    local SU = FLT.SkillUp
    local fees = FLT.PROFESSION_FEES and FLT.PROFESSION_FEES[prof]
    local _, max = FLT.ProfSkill(prof)
    local fac = myFaction()
    -- rank cards
    for i, rc in ipairs(rankCards) do
      local rk
      for _, x in ipairs(fees and fees.ranks or {}) do if x[1] == _RANKS[i] then rk = x end end
      rc.name:SetText(L[_RANKS[i]])
      rc.cap:SetText(string.format(L["Skill up to %d"], CAPS[i]))
      local mine = max and max >= CAPS[i]
      rc.card:SetSelected(max and max == CAPS[i] or false)
      if rk then
        local req = rk[5] > 0 and string.format(L["needs skill %d"], rk[5]) or L["no skill needed"]
        if rk[6] and rk[6] > 0 then req = req .. "  ·  " .. string.format(L["level %d"], rk[6]) end
        rc.req:SetText(req)
        local npc
        if rk.npcs then
          for _, id in ipairs(rk.npcs) do
            local t = FLT.PROFESSION_RANK_NPCS and FLT.PROFESSION_RANK_NPCS[id]
            if t and (not fac or t[4] == "AH" or t[4] == fac) then npc = t; break end
          end
        end
        if rk.item then
          local nm = FLT.ItemName and FLT.ItemName(rk.item) or (GetItemInfo and GetItemInfo(rk.item)) or (L["Item"] .. " " .. rk.item)
          rc.how:SetText(string.format(L["Book: %s"], nm) .. (npc and ("\n" .. NM(npc[2]) .. ", " .. ZN(npc[8])) or ""))
        elseif rk.quest then
          rc.how:SetText(L["From a quest"] .. (npc and ("\n" .. NM(npc[2]) .. ", " .. ZN(npc[8])) or ""))
        else
          rc.how:SetText(rk[4] > 0 and string.format(L["At a trainer: %s"], money(rk[4])) or L["At a trainer"])
        end
        rc.map:SetShown(npc ~= nil); mapTo(rc.map, npc, prof)
      else
        rc.req:SetText(""); rc.how:SetText(""); rc.map:Hide()
      end
      rc.name:SetTextColor(FLT.TextC(unpack(mine and GOLD or TEXT)))
    end
    -- every card as high as the longest text needs
    local hmax = 92
    for _, rc in ipairs(rankCards) do
      local h = rc.how:GetStringHeight()
      if type(h) == "number" then hmax = math.max(hmax, math.ceil(58 + h + 10)) end
    end
    for _, rc in ipairs(rankCards) do rc:SetHeight(hmax) end
    below:ClearAllPoints(); below:SetPoint("TOPLEFT", 0, -30 - hmax - 10); below:SetPoint("BOTTOMRIGHT", 0, 0)
    -- the trainers of my faction, grouped by the highest rank they teach
    local buckets = { [8] = {}, [4] = {}, [2] = {}, [1] = {}, guess = {} }
    for _, t in ipairs(FLT.PROFESSION_TRAINERS and FLT.PROFESSION_TRAINERS[prof] or {}) do
      if not fac or t[4] == "AH" or t[4]:find(fac, 1, true) then
        local m, guess = 1, true
        if SU and SU.TrainerMask then m, guess = SU.TrainerMask(prof, t) end
        local top = (m >= 8 and 8) or (m >= 4 and 4) or (m >= 2 and 2) or 1
        local b = guess and buckets.guess or buckets[top]
        b[#b + 1] = { t = t, m = m, guess = guess }
      end
    end
    local y, nr, nh = -2, 0, 0
    for _, h in ipairs(heads) do h:Hide() end
    for _, r in ipairs(rows) do r:Hide() end
    local function group(list, label)
      if #list == 0 then return end
      table.sort(list, function(a, b) if a.t[8] ~= b.t[8] then return ZN(a.t[8]) < ZN(b.t[8]) end return a.t[2] < b.t[2] end)
      nh = nh + 1; local h = head(nh); h:ClearAllPoints(); h:SetPoint("TOPLEFT", 8, y); h:Show(); h.text:SetText(label); y = y - 26
      for _, e in ipairs(list) do
        nr = nr + 1; local r = row(nr); r:ClearAllPoints(); r:SetPoint("TOPLEFT", 8, y); r:Show(); y = y - 31
        r.t, r.mask, r.guess = e.t, e.m, e.guess
        r.name:SetText(NM(e.t[2]))
        r.zone:SetText(ZN(e.t[8]))
        for k = 1, 4 do
          local on = not e.guess and math.floor(e.m / BITS[k]) % 2 == 1
          local m = r.marks[k]
          for _, p in ipairs(m.bg.pieces or {}) do
            if on then p:SetVertexColor(FLT.SkinC(0.55, 0.40, 0.12, 0.95)) else p:SetVertexColor(0.12, 0.11, 0.10, 0.9) end
          end
          m.t:SetTextColor(FLT.TextC(unpack(on and { 1, 0.90, 0.55 } or { 0.40, 0.38, 0.35 })))
        end
        mapTo(r.map, e.t, prof)
      end
      y = y - 6
    end
    for _, gr in ipairs(GROUPS) do group(buckets[gr[1]], L[gr[2]]) end
    group(buckets.guess, L["Not known yet - talk to them once"])
    if nr == 0 then
      nh = nh + 1; local h = head(nh); h:ClearAllPoints(); h:SetPoint("TOPLEFT", 8, y); h:Show(); h.text:SetText(L["No trainer known."]); y = y - 26
    end
    child:SetHeight(math.max(1, -y)); sf:SetVerticalScroll(0)
    f:Show()
  end
  return f
end
