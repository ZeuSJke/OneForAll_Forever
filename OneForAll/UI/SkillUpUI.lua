local _, FLT = ...
local L = FLT.L or setmetatable({}, { __index = function(_, k) return k end }) -- (tests without Locales)
local UI = FLT.UI
local GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local GetItemIcon = (C_Item and C_Item.GetItemIconByID) or GetItemIcon
local GetItemCount = GetItemCount or (C_Item and C_Item.GetItemCount)
local unpack = unpack or table.unpack

-- Skill-Up Helper page (Professions > a profession > "Skill-Up Helper", 6.2.6) and the guide window that walks you
-- through a plan (buy at the auction house, vendors, materials, then step by step). Logic: SkillUp.lua.
-- Saved: OneForAllDB.skillUp = { target = { [prof] = n }, ah = bool, vendor = bool, guidePos = {...} }.
-- Lean: the plan is worked out on Calculate / when the page opens; the guide listens to bags and skill only while shown.

local SU = FLT.SkillUp
if not SU then return end
local function N(t) return t end -- marks English texts translated where shown (tools/locale/extract.py)
local _RANKS = { N"Apprentice", N"Journeyman", N"Expert", N"Artisan" } -- rank names of SkillUp.Ranks, shown as L[rank]
local GOLD = UI.GOLD or { 1, 0.82, 0.20 }

local function sdb()
  if type(OneForAllDB) ~= "table" then return { target = {} } end
  OneForAllDB.skillUp = OneForAllDB.skillUp or {}
  local d = OneForAllDB.skillUp
  d.target = d.target or {}
  return d
end
-- "Patterns from the auction house" / "... from vendors": on by default (user 12.11.2026), false = switched off
local function on(key) return sdb()[key] ~= false end
local function money(c) if FLT.QoL and FLT.QoL.Money then return FLT.QoL.Money(math.floor((c or 0) + 0.5)) end return tostring(c) end
-- 6.2.7-beta15 (user screenshot 13.11.: "Item 16072", "Item 2692" ...): a name the client has not loaded yet is requested,
-- and once GET_ITEM_INFO_RECEIVED came the page and the guide are drawn again (one redraw per burst, only while waiting)
local nameWait
local function waitForNames()
  if not nameWait then
    nameWait = CreateFrame("Frame")
    nameWait:SetScript("OnEvent", function(self)
      self:UnregisterAllEvents()
      C_Timer.After(0.3, function()
        local SU = FLT.SkillUp
        if SU and SU._onSkillPage then SU._onSkillPage() end
        if SU and SU.RefreshGuide then SU.RefreshGuide() end
      end)
    end)
  end
  nameWait:RegisterEvent("GET_ITEM_INFO_RECEIVED")
end
local function itemName(id)
  local n = GetItemInfo and GetItemInfo(id)
  if not n then
    if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
    if C_Timer then waitForNames() end
  end
  return n or (L["Item"] .. " " .. id)
end
local function recipeName(r) return FLT.RecipeName and FLT.RecipeName(r) or r.n end
local function NM(s) return FLT.Name and FLT.Name(s) or s end
local function ZN(z) return FLT.ZoneName and FLT.ZoneName(z) or z end
local function icon(id) return (id and GetItemIcon and GetItemIcon(id)) or "Interface\\Icons\\INV_Misc_QuestionMark" end
local function state(prof) return FLT.GetProfessionState and FLT.GetProfessionState(prof) or { known = {} } end
-- beta15: every crafting profession (enchants have no item: their spell icon)
local PROF_ICON = { Alchemy = "Trade_Alchemy", Blacksmithing = "Trade_BlackSmithing", Enchanting = "Trade_Engraving",
  Engineering = "Trade_Engineering", Leatherworking = "Trade_LeatherWorking", Tailoring = "Trade_Tailoring",
  Cooking = "INV_Misc_Food_15", ["First Aid"] = "Spell_Holy_SealOfSacrifice" }
local function profIcon(prof) return "Interface\\Icons\\" .. (PROF_ICON[prof] or "Trade_Tailoring") end
local function recipeIcon(r) return r.i and icon(r.i) or r.ic or icon(nil) end
-- a rank step: trainer, or (Cooking / First Aid Expert, Artisan) a book to buy and read, or a quest
local function trainText(st, prof)
  if st.book then return string.format(L["%s %s: buy and read %s"], L[st.rank], L[prof], itemName(st.book)) end
  if st.quest then return string.format(L["%s %s: from a quest"], L[st.rank], L[prof]) end
  return string.format(L["Train %s %s at skill %d"], L[st.rank], L[prof], st.at)
end

-- the nearest of a list of { ..., mapID, x, y } (rows of the trainer / vendor data; idx = index of the map ID)
local function nearest(list, idx)
  if #list <= 1 or not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition and C_Map.GetWorldPosFromMapPos and CreateVector2D) then return list[1] end
  local best, bd
  pcall(function()
    local m = C_Map.GetBestMapForUnit("player"); local pos = m and C_Map.GetPlayerMapPosition(m, "player")
    if not pos then return end
    local pc, pw = C_Map.GetWorldPosFromMapPos(m, pos)
    for _, e in ipairs(list) do
      local c, w = C_Map.GetWorldPosFromMapPos(e[idx], CreateVector2D(e[idx + 1] / 100, e[idx + 2] / 100))
      if c and w and pw then
        local d = (c == pc and 0 or 1e12) + (w.x - pw.x) ^ 2 + (w.y - pw.y) ^ 2
        if not bd or d < bd then best, bd = e, d end
      end
    end
  end)
  return best or list[1]
end
UI.NearestOf = nearest -- the Crafting List's vendor map button (6.2.10)
-- the rank a trainer needs to teach a recipe: the highest rank whose required skill is not above the recipe's learn level
-- (beta14: a Formal White Shirt (135) is taught by Expert trainers, so the map button no longer points at a village trainer)
local function rankFor(prof, req)
  local name = "Apprentice"
  for _, rk in ipairs(SU.Ranks(prof) or {}) do if (rk[5] or 0) <= (req or 0) then name = rk[1] end end
  return name
end
local trainerFor
-- the pattern's own name as a grey second line (beta38, user 12.11.: "da muesste angezeigt werden wie das pattern heisst.
-- ich wuerde es gerne kaufen, aber weiss nicht was"): client name, else ours (translated where we have it)
local function patternLine(r)
  local id = r.ri
  if not id then return "" end
  local n = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
  if not n and C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
  n = n or (r.rn and NM(r.rn))
  return n and ("\n|cffffd060" .. n .. "|r") or ""
end
local function learnText(step, prof)
  local r = step.r
  if step.learn == "trainer" then
    local txt = string.format(L["Learn %s at the trainer (%s)"], recipeName(r), money(step.learnCost))
    -- beta25: the trainers who really teach it (Runed Truesilver Rod: not Orgrimmar), else by rank
    local t = nearest(SU.RecipeTrainers(prof, r.s) or SU.TrainersFor(prof, rankFor(prof, r.req)), 5)
    local loc = t and { mapID = t[5], x = t[6], y = t[7], name = NM(t[2]) }
    if t then txt = txt .. "\n|cff9d9d9d" .. NM(t[2]) .. ", " .. ZN(t[8]) .. "|r" end
    return txt, loc
  end
  if step.learn == "vendor" then
    local v = nearest(SU.RecipeVendors(r), 4)
    if v then return string.format(L["Buy the pattern from %s (%s, %s)"], NM(v[2]), ZN(v[3]), money(step.learnCost)) .. patternLine(r), { mapID = v[4], x = v[5], y = v[6], name = NM(v[2]) } end
    return string.format(L["Buy the pattern from a vendor (%s)"], money(step.learnCost)) .. patternLine(r)
  end
  if step.learn == "ah" then return string.format(L["Buy the pattern at the auction house (%s)"], money(step.learnCost)) .. patternLine(r) end
  if step.learn == "bag" then return L["Learn the pattern from your bags"] end
end
function trainerFor(prof, rank)
  local t = nearest(SU.TrainersFor(prof, rank), 5)
  if t then return t, { mapID = t[5], x = t[6], y = t[7], name = NM(t[2]) } end
end

-- Guide window ------------------------------------------------------------------------------------------------------
local guide, gchild, gsf, gtitle, gsend
local gplan, gprof
local rows, used = {}, 0
local W = 440
local ghover -- secure Craft overlay of the guide (CraftList.CraftOverlay), made with the guide
local function newRow()
  local b = CreateFrame("Button", nil, gchild); b:SetHeight(22)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  -- beta19 (user 12.11.: "ein button zum craften ... craft und craft all"): look-only buttons in the current craft step,
  -- the secure overlay is laid over the one under the mouse
  b.c1 = UI.GoldButton(b, L["Craft"], 46, 20, nil, 11); b.c1.label0, b.c1.minW = L["Craft"], 46
  b.call = UI.GoldButton(b, L["Craft all"], 70, 20, nil, 11); b.call.label0, b.call.minW = L["Craft all"], 70
  b.call:SetPoint("LEFT", b.c1, "RIGHT", 6, 0)
  for _, c in ipairs({ b.c1, b.call }) do
    c:SetScript("OnEnter", function(self) if ghover then ghover(self) end end)
    c:Hide()
  end
  -- beta20 (user 12.11.: "eine kleine bar ... 152-160, die sich farbig fuellt und weiter springt bei jedem skillup"):
  -- progress of the current step, from where the step began to its end
  local pb = CreateFrame("Frame", nil, b); pb:SetHeight(16); b.pbar = pb
  UI.MarkBG(UI.RoundRect(pb, pb, "BACKGROUND", 0, 5, 1, 0.07, 0.06, 0.05, 0.95))
  UI.RoundRect(pb, pb, "BORDER", 0, 6, 0, 0.62, 0.47, 0.24, 0.95, UI.ASSET_ROOT .. "window_ring")
  pb.fill = pb:CreateTexture(nil, "ARTWORK"); FLT.SetTex(pb.fill, "Interface\\TargetingFrame\\UI-StatusBar")
  pb.fill:SetVertexColor(FLT.SkinC(0.86, 0.60, 0.16)); pb.fill:SetPoint("TOPLEFT", 2, -2); pb.fill:SetPoint("BOTTOMLEFT", 2, 2)
  pb.text = FLT.NewFS(pb, nil, "OVERLAY", "GameFontHighlightSmall"); pb.text:SetPoint("CENTER", 0, 0)
  -- (user 12.11.: "wieviel % skillup mir es momentan bringt, aber nur beim aktuellen"): chance of a point per craft now,
  -- in the recipe's colour (orange / yellow / green)
  b.chance = FLT.NewFS(b, nil, "OVERLAY", "GameFontHighlightSmall"); b.chance:SetJustifyH("RIGHT")
  -- on the row, not on the bar (the bar hangs on it: "Cannot anchor to a region dependent on it", user 12.11.)
  b.chance:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -24, 8)
  b.chance:Hide()
  pb.frac = 0
  pb.place = function()
    local w = (pb:GetWidth() or 0) - 4
    if w > 0 then pb.fill:SetWidth(math.max(0.01, w * pb.frac)) end
    pb.fill:SetShown(pb.frac > 0)
  end
  pb:SetScript("OnSizeChanged", pb.place)
  pb:Hide()
  b.hl = b:CreateTexture(nil, "HIGHLIGHT"); b.hl:SetAllPoints(); b.hl:SetColorTexture(FLT.SkinC(0.90, 0.66, 0.22, 0.06))
  b.cur = UI.makeTexture(b, "BACKGROUND", 0.45, 0.33, 0.12, 0.25); b.cur:SetAllPoints()
  b.mark = UI.Mark(b, 14, "check", 0.35, 0.85, 0.40)
  b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetSize(18, 18)
  b.text = FLT.NewFS(b, nil, "OVERLAY", "GameFontHighlightSmall"); b.text:SetJustifyH("LEFT"); b.text:SetWordWrap(true)
  b.right = FLT.NewFS(b, nil, "OVERLAY", "GameFontHighlightSmall"); b.right:SetJustifyH("RIGHT"); b.right:SetPoint("RIGHT", -24, 0)
  b.map = UI.GoldButton(b, "Map", 18, 18, UI.ASSET_ROOT .. "icon_map"); b.map:SetPoint("RIGHT", -2, 0)
  -- "Buy" at an open merchant who sells it (6.2.8, user 13.11.: "im popup skillup guide aehnlich bei der crafting list")
  b.buy = UI.GoldButton(b, L["Buy"], 46, 18, nil, 10); b.buy:SetPoint("RIGHT", b.right, "LEFT", -6, 0); b.buy:Hide()
  b.buy:SetScript("OnClick", function(self)
    local CL = FLT.CraftList
    if self.id and CL and CL.BuyFromMerchant then self:Disable(); CL.BuyFromMerchant(self.id, self.n) end
  end)
  b.buy:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:SetText(L["Buy"])
    if self.cost then GameTooltip:AddLine(string.format(L["Buys what is missing from this merchant: %s"], self.cost), 1, 1, 1, true) end
    GameTooltip:Show()
  end)
  b.buy:SetScript("OnLeave", function() GameTooltip:Hide() end)
  b.map:SetScript("OnClick", function(self) if self.loc and FLT.ShowOnMap then FLT:ShowOnMap(self.loc) end end)
  b:SetScript("OnEnter", function(self)
    if not (self.item or self.key) then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if self.key and self.key:sub(1, 2) == "s:" then -- section heading (beta25)
      GameTooltip:AddLine(self.text:GetText() or "", GOLD[1], GOLD[2], GOLD[3])
      GameTooltip:AddLine(self.isDone and L["Done - no longer checked. Right-click: check it again."] or L["Right-click: mark this section as done."], 0.62, 0.62, 0.62, true)
      GameTooltip:Show(); return
    end
    if not self.item then GameTooltip:AddLine(L["Steps"], GOLD[1], GOLD[2], GOLD[3])
    elseif GameTooltip.SetItemByID then GameTooltip:SetItemByID(self.item) else GameTooltip:AddLine(itemName(self.item)) end
    if self.key then GameTooltip:AddLine(L["Right-click: mark this step as done (or not done)."], 0.62, 0.62, 0.62, true) end
    if self.tip then GameTooltip:AddLine(" "); GameTooltip:AddLine(self.tip, 1, 0.82, 0, true) end
    local CL = FLT.CraftList
    if CL and CL.Stock then
      local _, places = CL.Stock(self.item)
      if places and #places > 0 then GameTooltip:AddLine(" "); for _, p in ipairs(places) do GameTooltip:AddLine(p, 1, 1, 1) end end
    end
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  b:SetScript("OnClick", function(self, button)
    -- beta19 (user 12.11.: "eine moeglichkeit per rechtsklick einen punkt manuell auf erledigt zu stellen")
    if button == "RightButton" then
      if self.key and gprof then SU.SetStepDone(gprof, self.key, not self.isDone); SU.RefreshGuide() end
      return
    end
    if self.toggle then self.toggle(); return end
    local H = UI.DungeonHelpers
    if self.item and H and H.handleDungeonItemClick then H.handleDungeonItemClick({ id = self.item }, button) end
  end)
  return b
end
-- one line: o = { head = text } or { text, right, item, iconPath, done, current, loc, indent, key, craft = { prof, r, all },
-- prog = { from, to, skill } }
local function line(y, o)
  used = used + 1
  local b = rows[used]; if not b then b = newRow(); rows[used] = b end
  b:ClearAllPoints(); b:SetPoint("TOPLEFT", 4, y); b:SetPoint("RIGHT", gchild, "RIGHT", -4, 0); b:Show()
  b.item, b.key, b.isDone, b.toggle, b.tip = o.item, o.key, o.done, o.toggle, o.tip
  b.c1:Hide(); b.call:Hide(); b.pbar:Hide(); b.chance:Hide(); b.buy:Hide()
  local x = 4 + (o.indent or 0) * 14
  b.cur:SetShown(o.current and true or false)
  if o.head then
    b.icon:Hide(); b.map:Hide(); b.right:SetText("")
    -- beta25: a finished section (auction house, materials ...) gets a green check in its heading
    b.mark:ClearAllPoints(); b.mark:SetPoint("LEFT", x, 0); b.mark:SetShown(o.done and true or false)
    if o.done then b.mark:SetKind("check"); b.mark:SetColor(0.35, 0.85, 0.40) end
    b.text:ClearAllPoints(); b.text:SetPoint("LEFT", x + (o.done and 18 or 0), 0); b.text:SetPoint("RIGHT", -4, 0)
    b.text:SetFontObject("GameFontNormal"); b.text:SetText(o.head); b.text:SetTextColor(FLT.SkinC(unpack(GOLD)))
    b:SetHeight(24)
    return y - 26
  end
  b.text:SetFontObject("GameFontHighlightSmall"); b.text:SetTextColor(o.grey and 0.62 or 0.92, o.grey and 0.62 or 0.90, o.grey and 0.62 or 0.84)
  b.mark:ClearAllPoints(); b.mark:SetPoint("LEFT", x, 0); b.mark:SetShown(o.done ~= nil)
  if o.done ~= nil then b.mark:SetKind(o.done and "check" or "ring"); if o.done then b.mark:SetColor(0.35, 0.85, 0.40) else b.mark:SetColor(0.55, 0.55, 0.55) end end
  local ix = x + (o.done ~= nil and 18 or 0)
  local ic = o.iconPath or (o.item and icon(o.item))
  b.icon:ClearAllPoints(); b.icon:SetPoint("LEFT", ix, 0); b.icon:SetShown(ic ~= nil); if ic then b.icon:SetTexture(ic) end
  b.text:ClearAllPoints(); b.text:SetPoint("LEFT", ic and (ix + 22) or ix, 0)
  b.map.loc = o.loc; b.map:SetShown(o.loc ~= nil)
  b.right:SetText(o.right or "")
  b.text:SetPoint("RIGHT", b.right, "LEFT", -6, 0)
  local CL, bn = FLT.CraftList, o.buy
  local m = bn and CL and CL.MerchantSells and CL.MerchantSells(o.item)
  if m then
    b.buy.id, b.buy.n, b.buy.cost = o.item, bn, CL.MerchantCost(m, bn)
    b.buy:Enable(); b.buy:Show(); b.text:SetPoint("RIGHT", b.buy, "LEFT", -6, 0)
  end
  b.text:SetText(o.text or "")
  local h = math.max(22, math.ceil((b.text:GetStringHeight() or 12) + 8))
  local cr, pg = o.craft, o.prog
  if cr or pg then -- the craft buttons and the step bar under the text
    local tx = ic and (ix + 22) or ix
    b.text:ClearAllPoints(); b.text:SetPoint("TOPLEFT", tx, -4); b.text:SetPoint("RIGHT", b.right, "LEFT", -6, 0)
    local last
    if cr then
      b.c1:ClearAllPoints(); b.c1:SetPoint("BOTTOMLEFT", tx, 4)
      b.c1.target = { prof = cr.prof, r = cr.r, n = 1 }; b.c1:SetLabel(L["Craft"]); b.c1:Show(); last = b.c1
      if cr.all then b.call.target = { prof = cr.prof, r = cr.r, n = cr.all }; b.call:SetLabel(L["Craft all"]); b.call:Show(); last = b.call end
    end
    if pg then
      local pb = b.pbar
      pb:ClearAllPoints()
      if last then pb:SetPoint("LEFT", last, "RIGHT", 10, 0) else pb:SetPoint("BOTTOMLEFT", tx, 6) end
      if pg.chance then
        local c, r, sk = pg.chance, pg.r, pg.cskill or pg.skill
        local col = (sk < (r.y or 0) and "ff8040") or (sk < (r.g or r.gr or 0) and "ffff00") or "40c040"
        b.chance:SetText(string.format("|cff%s" .. L["%d%% chance"] .. "|r", col, math.floor(c * 100 + 0.5))); b.chance:Show()
        pb:SetPoint("RIGHT", b.chance, "LEFT", -8, 0)
      else pb:SetPoint("RIGHT", b, "RIGHT", -24, 0) end
      local span = math.max(1, pg.to - pg.from)
      local cur = math.max(pg.from, math.min(pg.skill, pg.to))
      pb.frac = (cur - pg.from) / span
      pb.text:SetText(string.format("%d / %d", cur, pg.to))
      pb:Show(); pb.place()
    end
    h = h + 26
  end
  b:SetHeight(h)
  return y - h - 2
end

-- where else a material lies (bank, other characters), for the material lines (beta23, user 12.11.: Greater Astral
-- Essence "0 / 1 in bags" although it was on the bank - "ein direkter hinweis im fenster")
local function elsewhere(id) -- "12 in bank, 5 on Smörgi Banklshofer" (6.2.7-beta4, CL.Elsewhere)
  local CL = FLT.CraftList
  return CL and CL.Elsewhere and CL.Elsewhere(id) or nil
end

-- what counts as bought for the shopping lines: with "Don't use own materials" only the bags (bought things land there),
-- else bags, bank and other characters
local function haveBuy(id)
  if SU.NoOwn() then return FLT.CraftList and FLT.CraftList.InBags and FLT.CraftList.InBags(id) or 0 end
  return SU.Have(id)
end
local remain, prepS = {}, {} -- reused by refreshGuide (SU.RemainingMats, SU.PrepStatus)
local function refreshGuide()
  if not (guide and guide:IsShown() and gplan) then return end
  for i = 1, used do rows[i]:Hide() end
  used = 0
  local plan, prof = gplan, gprof
  local p = state(prof)
  local skill = p.skill or plan.from
  gtitle:SetText(string.format(L["Skill-Up guide: %s %d - %d"], L[prof], plan.from, plan.to))
  local y, n = -4, 0
  local function head(t) n = n + 1; y = line(y, { head = n .. ". " .. t }) end
  -- beta25 (user 12.11.: after a while 1. and 2. showed materials as missing again - crafting uses them up): once every
  -- line of a section is done the section is closed for this route, gets a green check and is no longer checked;
  -- right-click on its heading opens it again (keys "s:<name>" in skillUpDone, cleared with a new route)
  local function section(name, title, items)
    local key = "s:" .. name
    local closed = SU.StepDone(prof, key)
    if not closed then
      local any, all = false, true
      for _, o in ipairs(items) do if o.done ~= nil then any = true; if not o.done then all = false end end end
      if any and all then SU.SetStepDone(prof, key, true); closed = true end
    end
    n = n + 1; y = line(y, { head = n .. ". " .. title, done = closed, key = key })
    if not closed then for _, o in ipairs(items) do y = line(y, o) end end
    return closed
  end
  -- auction house
  -- 6.2.12-beta18 (user 18.11.: "die fertigen bolt of mageweave zu kaufen. mit der differenz wie viel es mehr kosten
  -- wuerde"): intermediates that can be bought or crafted; ticked = bought ready-made, right = what buying costs more (+)
  -- or less (-) than crafting; a click switches and works the plan out again (same route)
  local ch = {}
  for _, c in pairs(plan.choices or {}) do if c.n > 0 then ch[#ch + 1] = c end end
  if #ch > 0 then
    table.sort(ch, function(a, b) return a.id < b.id end)
    n = n + 1; y = line(y, { head = n .. ". " .. L["Buy ready-made or craft"], new = true })
    y = line(y, { text = L["Ticked: bought ready-made instead of crafted. Right: what that costs more (+) or less (-) than crafting. Click to switch."], grey = true })
    for _, c in ipairs(ch) do
      local diff = (c.buyU - c.craftU) * c.n
      local right = diff >= 0 and ("|cffff8040+ |r" .. money(diff)) or ("|cff59ff73- |r" .. money(-diff))
      local tip = string.format(L["Ready-made: %s each. Crafted: %s each (its materials)."], money(c.buyU), money(c.craftU))
      y = line(y, { item = c.id, text = string.format(L["Buy %dx %s ready-made"], c.n, itemName(c.id)), right = right, done = c.buying, indent = 1, tip = tip,
        toggle = function()
          SU.SetPrepChoice(prof, c.id, c.buying and "craft" or "buy")
          for _, k in ipairs({ "s:ah", "s:vendor", "s:other" }) do SU.SetStepDone(prof, k, false) end
          local st = state(prof)
          local np = SU.Plan(prof, { from = st.skill or plan.from, to = plan.to, ah = on("ah"), vendor = on("vendor") })
          if np then gplan = np end
          if SU._onDB then SU._onDB() end -- the Skill-Up page (costs) when it is open
          refreshGuide()
        end })
    end
  end
  local ahClosed = true
  if #plan.ah > 0 then
    local items = { { text = SU.HasAuctionator() and L["Open the auction house, send the shopping list to Auctionator and buy everything on it."] or L["Open the auction house and buy:"], grey = true } }
    for _, sh in ipairs(plan.ah) do
      local m = plan.mats[sh.id]
      local want = m and (m.need - m.craft) or sh.n
      items[#items + 1] = { item = sh.id, text = itemName(sh.id), right = sh.n .. "x  ~" .. money((sh.price or 0) * sh.n), done = haveBuy(sh.id) >= want, indent = 1 }
    end
    ahClosed = section("ah", L["Auction house"], items)
  end
  -- 6.2.12-beta17 (user 18.11.: "mein button send to auctionator weg ist im skill up guide"): it was only there with
  -- something to buy on the auction house; the materials without a known price go on the list too (put up after the last
  -- scan, Auctionator finds them), so it shows with either
  local farmOpen = false
  for _, sh in ipairs(plan.other or {}) do if haveBuy(sh.id) < sh.n then farmOpen = true; break end end
  gsend:SetShown(SU.HasAuctionator() and (not ahClosed or farmOpen))
  -- vendors
  if #plan.vendor > 0 then
    local items = { { text = L["Trade supplies vendors sell these (in every big city):"], grey = true } }
    for _, sh in ipairs(plan.vendor) do
      local m = plan.mats[sh.id]
      local want = m and (m.need - m.craft) or sh.n
      local have = haveBuy(sh.id)
      items[#items + 1] = { item = sh.id, text = itemName(sh.id), right = sh.n .. "x  " .. money((sh.price or 0) * sh.n), done = have >= want, indent = 1,
        buy = have < want and (want - have) or nil }
    end
    section("vendor", L["Vendors"], items)
  end
  if #plan.other > 0 then
    local items = { { text = L["No price known: not on the auction house (scan it with Auctionator) and no vendor sells it."], grey = true } }
    for _, sh in ipairs(plan.other) do items[#items + 1] = { item = sh.id, text = itemName(sh.id), right = sh.n .. "x", done = haveBuy(sh.id) >= sh.n, indent = 1 } end
    section("other", L["Farm or find"], items)
  end
  -- materials: what the rest of the route still needs (beta25, user 12.11.: "dynamisch waechst bzw. abnimmt" - it shrinks
  -- while you craft), done when in the bags (mail them over from your other characters); disappears when nothing is left
  local ps = SU.PrepStatus(plan, prof, skill, prepS)
  local rest = SU.RemainingMats(plan, prof, skill, remain, ps)
  local ids = {}
  for id in pairs(rest) do ids[#ids + 1] = id end
  if #ids > 0 then
    table.sort(ids)
    head(L["Materials"])
    y = line(y, { text = SU.NoOwn() and L["Have them in your bags before you start."] or L["Have them in your bags before you start: fetch them from the bank and mail them from your other characters."], grey = true })
    for _, id in ipairs(ids) do
      local want = rest[id]
      local inBags = FLT.CraftList and FLT.CraftList.InBags and FLT.CraftList.InBags(id) or 0
      local txt = itemName(id)
      local where = inBags < want and not SU.NoOwn() and elsewhere(id)
      if where then txt = txt .. "  |cffffd060(" .. where .. ")|r" end -- next to the name (user 13.11.)
      y = line(y, { item = id, text = txt, right = string.format(L["%d / %d in bags"], inBags, want), done = inBags >= want, indent = 1 })
    end
  end
  -- steps
  head(L["Steps"])
  local current
  for _, st in ipairs(plan.steps) do
    if st.kind == "train" then
      local key = "t:" .. tostring(st.rank)
      local done = (p.maxSkill or 0) >= st.cap or SU.StepDone(prof, key)
      local t, loc = trainerFor(prof, st.rank)
      local isCur = not done and not current
      if isCur then current = st end
      local txt = trainText(st, prof)
      if t then txt = txt .. "\n|cff9d9d9d" .. NM(t[2]) .. ", " .. ZN(t[8]) .. "|r" end
      if st.level and st.level > 0 and UnitLevel and (UnitLevel("player") or 0) < st.level then txt = txt .. "\n|cffff6060" .. string.format(L["Needs character level %d"], st.level) .. "|r" end
      y = line(y, { iconPath = st.book and icon(st.book) or profIcon(prof), item = st.book, text = txt, right = money(st.cost), done = done, current = isCur, loc = loc, key = key })
    else
      local r = st.r
      local key = "c:" .. r.s .. ":" .. st.to
      -- a rod step (beta22) is done when the rod is there
      local done = (st.toolStep and SU.Have(st.toolStep) > 0) or (not st.toolStep and skill >= st.to) or SU.StepDone(prof, key)
      local isCur = not done and not current
      if isCur then current = st end
      if st.learn then
        local lk = "l:" .. r.s
        -- learned at the trainer: the spell is known before the profession window updates p.known (beta27)
        if not p.known[r.s] and IsPlayerSpell and IsPlayerSpell(r.s) then p.known[r.s] = true end
        local known = p.known[r.s] or SU.StepDone(prof, lk) or done
        local t, loc = learnText(st, prof)
        y = line(y, { iconPath = "Interface\\Icons\\INV_Scroll_03", text = t, done = known and true or false, current = isCur and not known, loc = loc, indent = 0, key = lk })
      end
      -- beta31 (user 12.11.: "dann gilt das als ganzer Schritt", Craft buttons and a bar there): an intermediate to make
      -- first is a step of its own - done when the bags hold what it needs, its count shrinks with what you have (bolts
      -- made earlier count for the 33x further down); innermost first (bars before the tubes made of them)
      local prepCur
      for i = #st.prep, 1, -1 do
        local pr = st.prep[i]
        local s = ps[pr] or { want = 0, have = 0, left = 0 }
        local pdone = done or s.left <= 0
        local cur = isCur and not pdone and not prepCur
        if cur then prepCur = pr end
        local t = string.format(L["First craft %dx %s"], s.left > 0 and s.left or pr.n, recipeName(pr.r))
        if pr.learn then t = t .. "\n|cff9d9d9d" .. (learnText({ r = pr.r, learn = pr.learn, learnCost = pr.learnCost }, prof) or "") .. "|r" end
        local craft, prog
        if cur then
          if not p.known[pr.r.s] and IsPlayerSpell and IsPlayerSpell(pr.r.s) then p.known[pr.r.s] = true end
          if p.known[pr.r.s] then craft = { prof = prof, r = pr.r, all = prof ~= "Enchanting" and s.left or nil } end
          local ch = SU.Chance(pr.r, skill)
          prog = { from = 0, to = math.max(1, s.want), skill = s.have, cskill = skill, chance = ch > 0 and ch or nil, r = pr.r }
        end
        local right = (not done and not cur and s.want > 0) and string.format("%d / %d", s.have, s.want) or nil
        y = line(y, { item = pr.r.i, text = t, done = pdone, current = cur, indent = 1, key = not done and s.key or nil, craft = craft, prog = prog, right = right })
      end
      if prepCur then isCur = false end
      local txt
      if st.toolStep then
        txt = string.format(L["Craft %s once - the next step needs it"], recipeName(r))
        if st.to > st.from then txt = txt .. "\n|cff9d9d9d" .. string.format(L["Gives a skill point (%d)"], st.to) .. "|r" end
      else
        txt = string.format(L["Craft %s until skill %d"], recipeName(r), st.to)
        txt = txt .. "\n|cff9d9d9d" .. string.format(L["%d - %d: about %d crafts, buy for %d"], st.start or st.from, st.to, math.ceil(st.expected - 1e-9), st.safe) .. "|r"
      end
      if st.tool then txt = txt .. "\n|cffffd060" .. string.format(L["Needs %s in your bags"], itemName(st.tool)) .. "|r" end
      -- Craft (and Craft all: what is left of this step from the current skill; not for Enchanting, every enchant needs
      -- an item to click) while the step is the current one and the recipe is known
      local craft
      if isCur and p.known[r.s] then
        local left = 0
        for x = math.max(skill, st.from), st.to - 1 do local ch = SU.Chance(r, x); if ch > 0 then left = left + 1 / ch end end
        craft = { prof = prof, r = r, all = (prof ~= "Enchanting" and not st.toolStep) and math.max(1, math.ceil(left - 1e-9)) or nil }
      end
      local prog = isCur and not st.toolStep and { from = st.start or st.from, to = st.to, skill = skill, chance = SU.Chance(r, math.max(skill, st.from)), r = r } or nil
      y = line(y, { item = r.i, iconPath = not r.i and r.ic or nil, text = txt, right = st.safe .. "x", done = done, current = isCur, key = key, craft = craft, prog = prog })
    end
  end
  if not current then y = line(y, { text = "|cff59ff73" .. L["Done - target reached."] .. "|r" }) end
  gchild:SetHeight(-y + 8)
end
SU.RefreshGuide = refreshGuide

local pending
local function later()
  if pending or not (C_Timer and C_Timer.After) then refreshGuide(); return end
  pending = true
  C_Timer.After(1, function() pending = nil; refreshGuide() end)
end
function SU.OnSkill()
  if guide and guide:IsShown() then later() end
  if SU._onSkillPage then SU._onSkillPage() end
end

local function createGuide()
  guide = CreateFrame("Frame", "OneForAllSkillUpGuide", UIParent)
  guide:SetSize(W, 520); guide:SetFrameStrata("FULLSCREEN"); guide:SetClampedToScreen(true)
  guide:SetMovable(true); guide:EnableMouse(true); guide:RegisterForDrag("LeftButton")
  local pos = sdb().guidePos
  if type(pos) == "table" then guide:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) else guide:SetPoint("LEFT", 60, 0) end
  guide:SetScript("OnDragStart", guide.StartMoving)
  guide:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint(1)
    sdb().guidePos = { p, rp, x, y }
  end)
  UI.FramedPanel(guide)
  for _, t in ipairs(UI.OrnateFrame(guide, guide, 16, 3, "OVERLAY", 4)) do t:SetVertexColor(FLT.SkinC(1, 1, 1, 1)) end
  local close = UI.CloseButton(guide); close:SetPoint("TOPRIGHT", -12, -12)
  gtitle = FLT.NewFS(guide, nil, "OVERLAY", "GameFontNormal"); gtitle:SetPoint("TOPLEFT", 18, -15); gtitle:SetPoint("RIGHT", close, "LEFT", -6, 0)
  gtitle:SetJustifyH("LEFT"); gtitle:SetTextColor(FLT.SkinC(unpack(GOLD)))
  gsf = FLT.SkinBlizz(CreateFrame("ScrollFrame", nil, guide, "UIPanelScrollFrameTemplate"))
  gsf:SetPoint("TOPLEFT", 8, -36); gsf:SetPoint("BOTTOMRIGHT", -30, 40)
  gchild = CreateFrame("Frame", nil, gsf); gchild:SetSize(W - 38, 10); gsf:SetScrollChild(gchild)
  if UI.PlaceScrollBar then UI.PlaceScrollBar(gsf) end
  ghover = FLT.CraftList and FLT.CraftList.CraftOverlay and FLT.CraftList.CraftOverlay(guide, "OneForAllSkillUpCraft")
  gsend = UI.GoldButton(guide, L["Send to Auctionator"], 150, 22, nil, 11); gsend:SetPoint("BOTTOMRIGHT", -14, 12)
  -- beta28 (user 12.11.: a hint bottom left how to open this window)
  local ghint = FLT.NewFS(guide, nil, "OVERLAY", "GameFontDisableSmall"); ghint:SetPoint("BOTTOMLEFT", 16, 16)
  ghint:SetPoint("RIGHT", guide, "RIGHT", -172, 0); ghint:SetJustifyH("LEFT")
  ghint:SetText(L["You can open this window with Alt + right-click on the minimap button."])
  gsend:SetScript("OnClick", function()
    -- the auction house list and the materials without a price (beta17)
    local list = {}
    for _, sh in ipairs(gplan and gplan.ah or {}) do list[#list + 1] = sh end
    for _, sh in ipairs(gplan and gplan.other or {}) do local h = haveBuy(sh.id); if h < sh.n then list[#list + 1] = { id = sh.id, n = sh.n - h } end end
    SU.SendToAuctionator({ ah = list }, nil, function(ok, missing)
      if not FLT.Msg then return end
      FLT.Msg(ok and L["Shopping list \"OneForAll Skill-Up\" is in Auctionator (Shopping tab)."] or L["Auctionator did not take the list (open the auction house once, then try again)."])
      if ok and missing > 0 then FLT.Msg(string.format(L["%d materials could not be added yet (item data still loading) - send the list again."], missing)) end
    end)
  end)
  guide:SetScript("OnShow", function(self)
    self:RegisterEvent("BAG_UPDATE_DELAYED")
    -- beta27 (user 12.11.: learned Runed Truesilver Rod, no check until the profession window is opened)
    pcall(self.RegisterEvent, self, "LEARNED_SPELL_IN_TAB"); pcall(self.RegisterEvent, self, "NEW_RECIPE_LEARNED")
    local w = type(OneForAllDB) == "table" and OneForAllDB.window
    local sc = w and tonumber(w.scale)
    if sc and sc > 0 then self:SetScale(sc) end
    refreshGuide()
  end)
  guide:SetScript("OnHide", function(self) self:UnregisterAllEvents() end)
  guide:SetScript("OnEvent", later)
  guide:Hide()
end
function SU.ShowGuide(plan, prof)
  if not plan then return end
  if type(OneForAllCharDB) == "table" then OneForAllCharDB.skillUpLast = { prof = prof, to = plan.to } end
  if not guide then createGuide() end
  gplan, gprof = plan, prof
  if guide:IsShown() then refreshGuide() else guide:Show() end
end

-- Alt-right-click on the OneForAll button (beta21, user 12.11.: "schnellzugriff auf das skill-up guide fenster das zuletzt
-- geoeffnet war"): the last guide of this character, worked out with its stored route, or closed when it is open
function SU.ToggleLastGuide()
  if guide and guide:IsShown() then guide:Hide(); return end
  local last = type(OneForAllCharDB) == "table" and OneForAllCharDB.skillUpLast
  if type(last) ~= "table" or not last.prof then
    if FLT.Msg then FLT.Msg(L["No Skill-Up guide opened yet: open one in Professions > Skill-Up Helper."]) end
    return
  end
  local p = state(last.prof)
  local plan, why = SU.Plan(last.prof, { from = p.skill or 1, to = last.to or 300, ah = on("ah"), vendor = on("vendor") })
  if plan then SU.ShowGuide(plan, last.prof)
  elseif FLT.Msg then FLT.Msg(why == "done" and L["Done - target reached."] or L["No Skill-Up plan possible right now: open Professions > Skill-Up Helper."]) end
end

-- when Auctionator last scanned the auction house, coloured (green within the hour); "" without Auctionator
-- (also on the Profit page, 6.2.6-beta28)
function SU.ScanText()
  if not SU.HasAuctionator() then return "" end
  local last = SU.LastScan()
  if not last then return "|cffff5050" .. L["Last auction house scan: never"] .. "|r" end
  local m = math.max(0, math.floor((time() - last) / 60))
  local t = m < 60 and string.format(L["Last auction house scan: %d min ago"], m)
    or (m < 2880 and string.format(L["Last auction house scan: %d h ago"], math.floor(m / 60)) or string.format(L["Last auction house scan: %d days ago"], math.floor(m / 1440)))
  return (m < 60 and "|cff40ff60" or "|cffff5050") .. t .. "|r"
end

-- "Without other characters' materials" (6.2.7, Discord 13.11.: twinks may be levelling their own professions), on the
-- Skill-Up Helper and the Profit page, one setting for both (SU.NoAlts); off until the user decides
function UI.NoAltsSwitch(f, onChange)
  local cb = FLT.SkinBlizz(CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")); cb:SetSize(22, 22)
  local fs = FLT.NewFS(f, nil, "OVERLAY", "GameFontHighlightSmall"); fs:SetText(L["Without other characters' materials"])
  cb:SetScript("OnShow", function(self) self:SetChecked(SU.NoAlts()) end)
  cb:SetChecked(SU.NoAlts())
  cb:SetScript("OnClick", function(self) sdb().noAlts = self:GetChecked() and true or nil; if onChange then onChange() end end)
  cb:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM"); GameTooltip:AddLine(L["Without other characters' materials"], GOLD[1], GOLD[2], GOLD[3])
    GameTooltip:AddLine(L["Only your bags and bank count; what your other characters have is bought or farmed like everything else."], 1, 1, 1, true)
    GameTooltip:Show()
  end)
  cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return cb, fs
end

-- "Don't use own materials" (6.2.12-beta19, user 18.11.: "damit nichts aus der bank oder den eigenen taschen verwendet
-- wird", Standard aus): one setting for the Skill-Up Helper and the Profit page (SU.NoOwn)
function UI.NoOwnSwitch(f, onChange)
  local cb = FLT.SkinBlizz(CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")); cb:SetSize(22, 22)
  local fs = FLT.NewFS(f, nil, "OVERLAY", "GameFontHighlightSmall"); fs:SetText(L["Don't use own materials"])
  cb:SetScript("OnShow", function(self) self:SetChecked(SU.NoOwn()) end)
  cb:SetChecked(SU.NoOwn())
  cb:SetScript("OnClick", function(self) sdb().noOwn = self:GetChecked() and true or nil; if onChange then onChange() end end)
  cb:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM"); GameTooltip:AddLine(L["Don't use own materials"], GOLD[1], GOLD[2], GOLD[3])
    GameTooltip:AddLine(L["Nothing from your bags, bank or other characters is used - every material is bought or farmed."], 1, 1, 1, true)
    GameTooltip:Show()
  end)
  cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return cb, fs
end

-- Page --------------------------------------------------------------------------------------------------------------
function UI.CreateSkillUpPage(parent)
  local f = CreateFrame("Frame", nil, parent); f:SetAllPoints(); f:Hide()
  local prof, plan
  -- header (6.2.7-beta19, user 13.11.: "den kopfteil nicht sehr uebersichtlich"): the title with Recalculate / Open guide,
  -- under it one framed box - line 1 your skill, the target and the last auction house scan, line 2 the three switches
  -- spread evenly - and the price note under the box
  UI.SectionTitle(f, L["Skill-Up Helper"], 8, -4, -280)
  local box0 = CreateFrame("Frame", nil, f); box0:SetPoint("TOPLEFT", 10, -30); box0:SetPoint("RIGHT", f, "RIGHT", -10, 0); box0:SetHeight(88)
  UI.MarkBG(UI.RoundRect(box0, box0, "BACKGROUND", 0, 7, 1, 0.07, 0.06, 0.05, 0.95))
  UI.RoundRect(box0, box0, "BORDER", 0, 8, 0, 0.45, 0.35, 0.20, 0.9, UI.ASSET_ROOT .. "window_ring")
  local sep = UI.makeTexture(box0, "ARTWORK", 0.62, 0.47, 0.24, 0.35); sep:SetHeight(1)
  sep:SetPoint("LEFT", box0, "TOPLEFT", 10, -33); sep:SetPoint("RIGHT", box0, "TOPRIGHT", -10, -33)
  local skillFS = FLT.NewFS(box0, nil, "OVERLAY", "GameFontHighlight"); skillFS:SetPoint("LEFT", box0, "TOPLEFT", 14, -17)
  local tFS = FLT.NewFS(box0, nil, "OVERLAY", "GameFontHighlight"); tFS:SetPoint("LEFT", skillFS, "RIGHT", 28, 0); tFS:SetText(L["Target"])
  local box = FLT.SkinBlizz(CreateFrame("EditBox", nil, box0, "InputBoxTemplate"))
  box:SetSize(36, 20); box:SetPoint("LEFT", tFS, "RIGHT", 10, 0); box:SetAutoFocus(false); box:SetNumeric(true); box:SetMaxLetters(3); box:SetJustifyH("CENTER")
  local calc -- forward
  box:SetScript("OnEnterPressed", function(self) self:ClearFocus(); calc() end)
  box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  local quick = {}
  for i, cap in ipairs({ 75, 150, 225, 300 }) do
    local b = UI.GoldButton(box0, tostring(cap), 38, 20, nil, 11)
    b:SetPoint("LEFT", i == 1 and box or quick[i - 1], "RIGHT", i == 1 and 10 or 4, 0)
    b:SetScript("OnClick", function() box:SetText(tostring(cap)); calc() end)
    quick[i] = b
  end
  -- when Auctionator last scanned the auction house: green within the hour, red after (user 12.11.)
  local scanFS = FLT.NewFS(box0, nil, "OVERLAY", "GameFontHighlightSmall"); scanFS:SetPoint("RIGHT", box0, "TOPRIGHT", -14, -17); scanFS:SetJustifyH("RIGHT")
  -- the switches (patterns from the auction house / from vendors, without other characters' materials), a third of the
  -- box each
  local switches = {}
  local function switch(text, key)
    local cb = FLT.SkinBlizz(CreateFrame("CheckButton", nil, box0, "UICheckButtonTemplate")); cb:SetSize(22, 22)
    local fs = FLT.NewFS(box0, nil, "OVERLAY", "GameFontHighlightSmall"); fs:SetPoint("LEFT", cb, "RIGHT", 4, 0); fs:SetText(text)
    cb:SetChecked(on(key))
    cb:SetScript("OnClick", function(self) sdb()[key] = self:GetChecked() and true or false; calc() end)
    switches[#switches + 1] = cb
  end
  switch(L["Patterns from the auction house"], "ah")
  switch(L["Patterns from vendors"], "vendor")
  do
    local cb, fs = UI.NoAltsSwitch(box0, function() if calc then calc(true) end end) -- the costs change: a new route
    fs:SetPoint("LEFT", cb, "RIGHT", 4, 0); switches[3] = cb
  end
  do -- beta19: the fourth switch; two per row (box 24 higher, everything under it moved down by 24)
    local cb, fs = UI.NoOwnSwitch(box0, function() if calc then calc(true) end end)
    fs:SetPoint("LEFT", cb, "RIGHT", 4, 0); switches[4] = cb
  end
  local function placeSwitches()
    local w = box0:GetWidth() or 0
    for i, cb in ipairs(switches) do
      cb:ClearAllPoints(); cb:SetPoint("LEFT", box0, "TOPLEFT", 10 + ((i - 1) % 2) * math.floor((w - 20) / 2), i <= 2 and -48 or -72)
    end
  end
  box0:SetScript("OnSizeChanged", placeSwitches); placeSwitches()
  local status = FLT.NewFS(f, nil, "OVERLAY", "GameFontDisableSmall"); status:SetPoint("TOPLEFT", 12, -126); status:SetPoint("RIGHT", f, "RIGHT", -12, 0)
  status:SetJustifyH("LEFT"); status:SetWordWrap(false)
  -- the big progress bar: skill since the plan was started -> target (user 12.11.: "ein grosser, damit es optisch gut aussieht")
  local bar = CreateFrame("Frame", nil, f); bar:SetPoint("TOPLEFT", 10, -144); bar:SetPoint("RIGHT", f, "RIGHT", -10, 0); bar:SetHeight(28)
  UI.MarkBG(UI.RoundRect(bar, bar, "BACKGROUND", 0, 7, 1, 0.07, 0.06, 0.05, 0.95))
  UI.RoundRect(bar, bar, "BORDER", 0, 8, 0, 0.62, 0.47, 0.24, 0.95, UI.ASSET_ROOT .. "window_ring")
  local fill = bar:CreateTexture(nil, "ARTWORK"); FLT.SetTex(fill, "Interface\\TargetingFrame\\UI-StatusBar")
  fill:SetVertexColor(FLT.SkinC(0.86, 0.60, 0.16)); fill:SetPoint("TOPLEFT", 3, -3); fill:SetPoint("BOTTOMLEFT", 3, 3)
  local shine = bar:CreateTexture(nil, "ARTWORK", nil, 1); FLT.SetTex(shine, "Interface\\TargetingFrame\\UI-StatusBar")
  shine:SetVertexColor(1, 0.92, 0.6, 0.25); shine:SetPoint("TOPLEFT", fill, "TOPLEFT"); shine:SetPoint("TOPRIGHT", fill, "TOPRIGHT"); shine:SetHeight(8)
  local barText = FLT.NewFS(bar, nil, "OVERLAY", "GameFontHighlight"); barText:SetPoint("CENTER", 0, 0)
  do local font, _, flags = barText:GetFont(); if font then barText:SetFont(font, 13, "OUTLINE") end end
  local ticks, frac = {}, 0
  local function placeFill()
    local w = (bar:GetWidth() or 0) - 6
    if w <= 0 then return end
    fill:SetWidth(math.max(0.01, w * frac)); fill:SetShown(frac > 0); shine:SetShown(frac > 0)
  end
  bar:SetScript("OnSizeChanged", placeFill)
  -- 6.2.6-beta12 (user 12.11.: "sollte immer bei 0 anfangen"): the bar runs from 0 to the target, what is done shows
  local function setProgress(skill, to)
    local from = 0
    frac = (to > 0) and math.max(0, math.min(1, skill / to)) or 1
    placeFill()
    barText:SetText(string.format(L["Skill %d / %d (%d%%)"], math.min(skill, to), to, math.floor(frac * 100 + 0.5)))
    -- the rank caps inside the range as fine marks
    for _, t in ipairs(ticks) do t:Hide() end
    local w, n = (bar:GetWidth() or 0) - 6, 0
    for _, cap in ipairs({ 75, 150, 225 }) do
      if cap > from and cap < to and w > 0 then
        n = n + 1
        local t = ticks[n]; if not t then t = UI.makeTexture(bar, "OVERLAY", 1, 0.85, 0.45, 0.55); t:SetWidth(1); ticks[n] = t end
        t:ClearAllPoints(); t:SetPoint("TOP", bar, "TOPLEFT", 3 + w * (cap - from) / (to - from), -4); t:SetPoint("BOTTOM", bar, "BOTTOMLEFT", 3 + w * (cap - from) / (to - from), 4); t:Show()
      end
    end
  end
  -- the costs as a row of tiles (6.2.6-beta12, user 12.11.: the text block was "sehr unuebersichtlich"): a small label,
  -- the value under it, details in the tooltip
  -- the row spans exactly the bar's width; the tiles share it (beta13, user 12.11.: flush with the bar)
  local tiles = {}
  local TILE_GAP = 6
  local row = CreateFrame("Frame", nil, f); row:SetPoint("TOPLEFT", 10, -184); row:SetPoint("RIGHT", f, "RIGHT", -10, 0); row:SetHeight(46)
  local function layoutTiles()
    local w = row:GetWidth() or 0
    if w <= 0 then return end
    local tw = (w - TILE_GAP * (#tiles - 1)) / #tiles
    for i, t in ipairs(tiles) do t:SetWidth(tw); t:ClearAllPoints(); t:SetPoint("TOPLEFT", row, "TOPLEFT", (i - 1) * (tw + TILE_GAP), 0) end
  end
  row:SetScript("OnSizeChanged", layoutTiles)
  local function tile(i, label, big)
    local t = CreateFrame("Frame", nil, row); t:SetSize(112, 46); t:SetPoint("TOPLEFT", (i - 1) * (112 + TILE_GAP), 0)
    UI.MarkBG(UI.RoundRect(t, t, "BACKGROUND", 0, 7, 1, 0.07, 0.06, 0.05, 0.95))
    UI.RoundRect(t, t, "BORDER", 0, 8, 0, big and 0.72 or 0.45, big and 0.55 or 0.35, big and 0.25 or 0.20, 0.9, UI.ASSET_ROOT .. "window_ring")
    t.label = FLT.NewFS(t, nil, "OVERLAY", "GameFontDisableSmall"); t.label:SetPoint("TOP", 0, -6); t.label:SetText(UI.Upper and UI.Upper(label) or label)
    t.value = FLT.NewFS(t, nil, "OVERLAY", big and "GameFontNormal" or "GameFontHighlight"); t.value:SetPoint("BOTTOM", 0, 8)
    do local font, _, flags = t.value:GetFont(); if font then t.value:SetFont(font, big and 14 or 12, flags) end end
    if big then t.value:SetTextColor(FLT.SkinC(1, 0.82, 0.25)) end
    t:EnableMouse(true)
    t:SetScript("OnEnter", function(self)
      if not self.tip then return end
      GameTooltip:SetOwner(self, "ANCHOR_BOTTOM"); GameTooltip:AddLine(label, GOLD[1], GOLD[2], GOLD[3])
      GameTooltip:AddLine(self.tip, 1, 1, 1, true); GameTooltip:Show()
    end)
    t:SetScript("OnLeave", function() GameTooltip:Hide() end)
    tiles[#tiles + 1] = t
    return t
  end
  local tTotal = tile(1, L["Total"], true)
  local tAH = tile(2, L["Auction house"])
  local tVendor = tile(3, L["Vendors"])
  local tPattern = tile(4, L["Patterns"])
  local tTrain = tile(5, L["Training"])
  local tCrafts = tile(6, L["Crafts"])
  local tResale = tile(7, L["Resale value"])
  tResale.value:SetTextColor(0.62, 0.62, 0.62)
  layoutTiles()
  local note = FLT.NewFS(f, nil, "OVERLAY", "GameFontDisableSmall"); note:SetPoint("TOPLEFT", 12, -234); note:SetPoint("RIGHT", f, "RIGHT", -10, 0)
  note:SetJustifyH("LEFT")
  local open = UI.GoldButton(f, L["Open guide"], 120, 24, nil, 12); open:SetPoint("TOPRIGHT", -10, -2)
  open.wantGreen = true; open:SetGreen(true) -- 6.2.12-beta17 (user 18.11.: it did not catch the eye); grey while there is no plan
  open:SetScript("OnClick", function() SU.ShowGuide(plan, prof) end)
  -- beta28 (user 12.11.: "Send to Auctionator in diesem Fenster bitte entfernen, das soll man dann ueber den Guide machen")
  -- beta18: the route stays the same until this is clicked (or target / switches change)
  local recalc = UI.GoldButton(f, L["Recalculate"], 110, 24, nil, 12); recalc:SetPoint("RIGHT", open, "LEFT", -8, 0)
  recalc:SetScript("OnClick", function() if calc then calc(true) end end)
  recalc:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM"); GameTooltip:AddLine(L["Recalculate"], GOLD[1], GOLD[2], GOLD[3])
    GameTooltip:AddLine(L["The plan keeps its recipes so the amounts do not jump. Click to work it out again with the current prices and what you have."], 1, 1, 1, true)
    GameTooltip:Show()
  end)
  recalc:SetScript("OnLeave", function() GameTooltip:Hide() end)
  local cols = { { x = 0, w = 80, text = L["Skill"] }, { x = 80, w = 360, text = L["Recipe"] }, { x = 440, w = 90, text = L["Crafts"] },
    { x = 530, w = 130, text = L["Cost"] }, { x = 660, w = 160, text = L["Learn"] } }
  UI.ColumnHeader(f, cols, 820, -250) -- 6.2.13 (Discord archdruidbris): under the price note at -234, not over it
  local sf = FLT.SkinBlizz(CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate"))
  sf:SetPoint("TOPLEFT", 4, -278); sf:SetPoint("BOTTOMRIGHT", -26, 4)
  local child = CreateFrame("Frame", nil, sf); child:SetSize(800, 10); sf:SetScrollChild(child)
  if UI.PlaceScrollBar then UI.PlaceScrollBar(sf) end
  local empty = FLT.NewFS(child, nil, "OVERLAY", "GameFontDisable"); empty:SetPoint("TOP", 0, -30); empty:SetWidth(700)
  local prow, pused = {}, 0
  local function row(y)
    pused = pused + 1
    local b = prow[pused]
    if not b then
      b = CreateFrame("Button", nil, child); b:SetHeight(28); UI.QuietRow(b)
      b.skill = FLT.NewFS(b, nil, "OVERLAY", "GameFontHighlight"); b.skill:SetPoint("LEFT", 12, 0)
      b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetSize(20, 20); b.icon:SetPoint("LEFT", 88, 0)
      b.name = FLT.NewFS(b, nil, "OVERLAY", "GameFontHighlight"); b.name:SetPoint("LEFT", 114, 0); b.name:SetWidth(320); b.name:SetJustifyH("LEFT"); b.name:SetWordWrap(false)
      b.crafts = FLT.NewFS(b, nil, "OVERLAY", "GameFontHighlight"); b.crafts:SetPoint("LEFT", 448, 0); b.crafts:SetWidth(80); b.crafts:SetJustifyH("LEFT")
      b.cost = FLT.NewFS(b, nil, "OVERLAY", "GameFontHighlightSmall"); b.cost:SetPoint("LEFT", 538, 0); b.cost:SetWidth(120); b.cost:SetJustifyH("LEFT")
      b.note = FLT.NewFS(b, nil, "OVERLAY", "GameFontDisableSmall"); b.note:SetPoint("LEFT", 668, 0); b.note:SetWidth(130); b.note:SetJustifyH("LEFT"); b.note:SetWordWrap(false)
      b:SetScript("OnLeave", function() GameTooltip:Hide() end)
      prow[pused] = b
    end
    -- rows are reused; the "Materials" head and its rows move icon and name to the left edge
    b.icon:ClearAllPoints(); b.icon:SetPoint("LEFT", 88, 0); b.name:ClearAllPoints(); b.name:SetPoint("LEFT", 114, 0); b.name:SetWidth(320)
    b:ClearAllPoints(); b:SetPoint("TOPLEFT", 0, y); b:SetPoint("RIGHT", child, "RIGHT", 0, 0); b:Show()
    return b
  end
  local function stepTooltip(self)
    local st = self.step
    if not st then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(recipeName(st.r), GOLD[1], GOLD[2], GOLD[3])
    GameTooltip:AddLine(string.format(L["Skill %d - %d: about %d crafts, %d with the buffer (9 of 10 times enough)"], st.from, st.to, math.ceil(st.expected - 1e-9), st.safe), 1, 1, 1, true)
    if st.learn then GameTooltip:AddLine((learnText(st)), 0.6, 0.85, 1, true) end
    for _, pr in ipairs(st.prep) do GameTooltip:AddLine(string.format(L["First craft %dx %s"], pr.n, recipeName(pr.r)), 0.6, 0.85, 1) end
    if #st.buy > 0 then
      GameTooltip:AddLine(" "); GameTooltip:AddLine(L["To buy"], GOLD[1], GOLD[2], GOLD[3])
      for _, b in ipairs(st.buy) do
        local where = b.src == "ah" and L["Auction house"] or (b.src == "vendor" and L["Vendor"] or L["no price"])
        GameTooltip:AddDoubleLine(b.n .. "x " .. itemName(b.id) .. " |cff9d9d9d(" .. where .. ")|r", b.price and money(b.price * b.n) or "-", 1, 1, 1, 1, 1, 1)
      end
    end
    if st.resale then GameTooltip:AddLine(" "); GameTooltip:AddLine(string.format(L["Resale value at the auction house: about %s (not counted)"], money(st.resale)), 0.7, 0.7, 0.7, true) end
    GameTooltip:AddLine(L["Click: open the recipe in All recipes."], 0.5, 0.5, 0.5)
    GameTooltip:Show()
  end
  local premain = {}
  local function draw()
    for i = 1, pused do prow[i]:Hide() end
    pused = 0
    local p = state(prof)
    skillFS:SetText(string.format(L["Your skill: %s"], (p.skill or "?") .. (p.maxSkill and ("/" .. p.maxSkill) or "")))
    -- status: where prices come from
    local st
    if SU.HasAuctionator() then st = L["Prices: Auctionator (scan the auction house with it for fresh prices), vendors and trainers."]
    else st = "|cffffb040" .. L["Auctionator is not installed: only vendor prices and rough estimates for everything else."] .. "|r" end
    status:SetText(st)
    scanFS:SetText(SU.ScanText())
    setProgress(p.skill or 0, tonumber(box:GetText()) or sdb().target[prof] or 300)
    empty:SetText("")
    if not plan then
      for _, t in ipairs(tiles) do t.value:SetText("-"); t.tip = nil end
      note:SetText(""); open:SetLook(false)
      child:SetHeight(1)
      return
    end
    open:SetLook(true)
    local ahC, vC = 0, 0
    for _, x in ipairs(plan.ah) do ahC = ahC + (x.price or 0) * x.n end
    for _, x in ipairs(plan.vendor) do vC = vC + (x.price or 0) * x.n end
    local short = function(c) return money(c >= 10000 and math.floor(c / 100) * 100 or c) end -- no copper next to gold
    tTotal.value:SetText(short(plan.cost)); tTotal.tip = SU.NoOwn() and L["Every material is bought or farmed - your own ones are not used."] or L["Materials you have count as free."]
    tAH.value:SetText(short(ahC)); tAH.tip = string.format(L["%d different materials at the auction house."], #plan.ah)
    tVendor.value:SetText(short(vC)); tVendor.tip = L["Trade supplies vendors sell these (in every big city):"]:gsub(":$", "") .. "."
    tPattern.value:SetText(short(plan.recipeCost)); tPattern.tip = L["Recipes and patterns to learn on the way (trainer, vendor or auction house)."]
    tTrain.value:SetText(short(plan.trainCost)); tTrain.tip = L["Ranks to train on the way."]
    tCrafts.value:SetText(math.ceil(plan.expected - 1e-9) .. " |cff9d9d9d/ " .. plan.safe .. "|r")
    tCrafts.tip = string.format(L["%d crafts expected, %d planned with the buffer. Materials you have count as free."], math.ceil(plan.expected - 1e-9), plan.safe)
    if SU.NoOwn() then tCrafts.tip = tCrafts.tip .. "\n" .. L["Every material is bought or farmed - your own ones are not used."] end
    tResale.value:SetText(plan.resale > 0 and short(plan.resale) or "-")
    tResale.tip = string.format(L["Resale value at the auction house: about %s (not counted)"], money(plan.resale))
    note:SetText(plan.guessed and ("|cffffb040" .. L["Some prices are estimates (no auction house price)."] .. "|r") or "")
    local y = 0
    for _, step in ipairs(plan.steps) do
      local b = row(y)
      b.step = nil
      if step.kind == "train" then
        b.skill:SetText(step.at); b.icon:SetTexture(step.book and icon(step.book) or profIcon(prof))
        b.name:SetText(trainText(step, prof)); b.name:SetTextColor(0.6, 0.85, 1)
        b.crafts:SetText(""); b.cost:SetText(money(step.cost))
        local t = trainerFor(prof, step.rank)
        b.note:SetText(t and NM(t[2]) or "")
        b:SetScript("OnEnter", nil); b:SetScript("OnClick", nil)
      else
        b.step = step
        b.skill:SetText(step.to > step.from and (step.from .. " - " .. step.to) or tostring(step.from)); b.icon:SetTexture(recipeIcon(step.r))
        b.name:SetText(recipeName(step.r)); b.name:SetTextColor(1, 1, 1)
        b.crafts:SetText(math.ceil(step.expected - 1e-9) .. " |cff9d9d9d(" .. step.safe .. ")|r")
        b.cost:SetText(money(step.cost))
        local kind = step.learn == "trainer" and L["Trainer"] or (step.learn == "vendor" and L["Vendor"] or (step.learn == "ah" and L["Auction house"] or (step.learn == "bag" and L["Bags"] or "")))
        b.note:SetText(kind)
        b:SetScript("OnEnter", stepTooltip)
        b:SetScript("OnClick", function(self)
          if self.step and FLT.ShowRecipeInProfessions then FLT.ShowRecipeInProfessions(prof, self.step.r.s) end
        end)
      end
      y = y - 30
    end
    -- beta22 (user 12.11.: "im skill-up helper die mats auch angezeigt"): the materials of the plan under the steps -
    -- have (all characters, bank) / need, how many are in the bags
    -- beta25: only what the rest of the route still needs (shrinks while you craft)
    local rest = SU.RemainingMats(plan, prof, p.skill or plan.from, premain)
    local ids = {}
    for id in pairs(rest) do ids[#ids + 1] = id end
    table.sort(ids)
    if #ids > 0 then
      local h = row(y - 6); h.step, h.item = nil, nil
      h.skill:SetText(""); h.icon:SetTexture(nil); h.crafts:SetText(""); h.cost:SetText(""); h.note:SetText("")
      h.name:SetText(L["Materials"]); h.name:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
      h.name:ClearAllPoints(); h.name:SetPoint("LEFT", 12, 0) -- at the left edge of the table, like the skill column (user 13.11. 10:58: still "nicht ganz links")
      h:SetScript("OnEnter", nil); h:SetScript("OnClick", nil)
      y = y - 36
      for _, id in ipairs(ids) do
        local b = row(y)
        local want, have = rest[id], SU.Have(id)
        local bags = FLT.CraftList and FLT.CraftList.InBags and FLT.CraftList.InBags(id) or 0
        b.step, b.item = nil, id
        b.skill:SetText(""); b.icon:SetTexture(icon(id))
        -- under the "Materials" heading (user 13.11. 11:00: "damit die materialien auch unter materials stehen")
        b.icon:ClearAllPoints(); b.icon:SetPoint("LEFT", 12, 0); b.name:ClearAllPoints(); b.name:SetPoint("LEFT", 38, 0); b.name:SetWidth(396)
        b.name:SetText(itemName(id)); b.name:SetTextColor(1, 1, 1)
        b.crafts:SetText((have >= want and "|cff40ff60" or "|cffffffff") .. have .. " / " .. want .. "|r")
        local where = bags < want and not SU.NoOwn() and elsewhere(id)
        b.cost:SetText(""); b.note:SetText(where and ("|cffffd060" .. where .. "|r") or string.format(L["%d in bags"], bags))
        b:SetScript("OnEnter", function(self)
          if not self.item then return end
          GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
          if GameTooltip.SetItemByID then GameTooltip:SetItemByID(self.item) else GameTooltip:AddLine(itemName(self.item)) end
          local CL = FLT.CraftList
          local places; if CL and CL.Stock then places = select(2, CL.Stock(self.item)) end
          if places and #places > 0 then GameTooltip:AddLine(" "); for _, pl in ipairs(places) do GameTooltip:AddLine(pl, 1, 1, 1) end end
          GameTooltip:Show()
        end)
        b:SetScript("OnClick", nil)
        y = y - 30
      end
    end
    child:SetHeight(-y + 4)
  end
  calc = function(fresh)
    if not prof then return end
    if FLT.ReadSkillLines then FLT.ReadSkillLines() end
    local p = state(prof)
    local to = tonumber(box:GetText())
    if not to then
      to = sdb().target[prof]
      if not to then for _, cap in ipairs({ 75, 150, 225, 300 }) do if (p.skill or 0) < cap then to = cap; break end end end
      box:SetText(tostring(to or 300))
    end
    sdb().target[prof] = to
    local why, reached
    plan, why, reached = SU.Plan(prof, { from = p.skill or 1, to = to, ah = on("ah"), vendor = on("vendor"), fresh = fresh })
    draw()
    if not plan then
      if why == "done" then empty:SetText(L["You are already at this skill. Set a higher target."])
      elseif why == "stuck" then empty:SetText(string.format(L["No plannable recipe beyond skill %d. Allow patterns from vendors or the auction house above."], reached or 0))
      elseif not (p.skill and p.skill > 0) then empty:SetText(string.format(L["Open your %s window once so OneForAll knows your skill and recipes."], L[prof]))
      else empty:SetText(L["No plan possible."]) end
    end
    if guide and guide:IsShown() and gprof == prof and plan then gplan = plan; refreshGuide() end
  end
  function f:ShowProfession(name)
    if prof ~= name then box:SetText(""); plan = nil end
    prof = name
    f:Show()
    calc()
  end
  -- a new Auctionator scan / the skill went up: work it out again while the page is shown (SkillUp.lua calls these)
  SU._onDB = function() if f:IsShown() then calc() end end
  SU._onSkillPage = function() if f:IsShown() and prof then draw() end end
  return f
end
