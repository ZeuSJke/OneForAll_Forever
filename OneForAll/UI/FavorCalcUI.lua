local _, FLT = ...
local L = FLT.L or setmetatable({}, { __index = function(_, k) return k end }) -- (tests without Locales)
local UI = FLT.UI
local GetItemIcon = (C_Item and C_Item.GetItemIconByID) or GetItemIcon
local GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local unpack = unpack or table.unpack

-- Professions > Merchant's Favor > Calculator (6.2.18-beta16, user 27.11.2026): wanted Favor in, the cheapest crates + bundles
-- out (FavorCalc.lua), with a shopping list. Built on first view, computed only on a click / Enter.

local GOLD, DIM, TEXT = { 1, 0.82, 0.20 }, { 0.62, 0.60, 0.56 }, { 0.88, 0.86, 0.80 }
local function money(c) if FLT.QoL and FLT.QoL.Money then return FLT.QoL.Money(math.floor(c or 0)) end return tostring(c) end
local function icon(id) return (GetItemIcon and GetItemIcon(id)) or "Interface\\Icons\\INV_Misc_QuestionMark" end
local missing -- an item name the client has not loaded yet: paint again once
local function iname(id)
  local n = GetItemInfo and GetItemInfo(id)
  if not n then
    missing = true
    if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
    return "#" .. id
  end
  return (n:gsub("^[^:]+: ", "", 1)) -- "Waylaid Crate: Apprentice Herbs" -> "Apprentice Herbs"
end
local function newText(parent, font, w, color)
  local fs = FLT.NewFS(parent, nil, "OVERLAY", font or "GameFontHighlight")
  if w then fs:SetWidth(w) end
  fs:SetJustifyH("LEFT")
  if color then fs:SetTextColor(FLT.TextC(unpack(color))) end
  return fs
end
local function tipItem(self)
  if not self.item then return end
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  if GameTooltip.SetItemByID then GameTooltip:SetItemByID(self.item) else GameTooltip:SetHyperlink("item:" .. self.item) end
  GameTooltip:Show()
end

function UI.CreateFavorCalc(parent, getFavor)
  local f = CreateFrame("Frame", nil, parent); f:Hide()
  local W = 780
  UI.SectionTitle(f, L["Favor Calculator"], 8, -4, -20)
  local box = CreateFrame("Frame", nil, f); box:SetPoint("TOPLEFT", 10, -30); box:SetSize(W - 20, 106)
  UI.MarkBG(UI.RoundRect(box, box, "BACKGROUND", 0, 7, 1, 0.07, 0.06, 0.05, 0.95))
  UI.RoundRect(box, box, "BORDER", 0, 8, 0, 0.45, 0.35, 0.20, 0.9, UI.ASSET_ROOT .. "window_ring")
  local lab = newText(box, "GameFontNormal", nil, GOLD); lab:SetPoint("TOPLEFT", 14, -14); lab:SetText(L["Favor to earn:"])
  local amount = FLT.SkinBlizz(CreateFrame("EditBox", nil, box, "InputBoxTemplate"))
  amount:SetSize(60, 20); amount:SetPoint("LEFT", lab, "RIGHT", 12, 0); amount:SetAutoFocus(false); amount:SetNumeric(true)
  amount:SetMaxLetters(4); amount:SetJustifyH("CENTER")
  local saved = type(OneForAllDB) == "table" and tonumber(OneForAllDB.favorCalcWant)
  amount:SetText(tostring(saved or 100))
  local calc = UI.GoldButton(box, L["Calculate"], 110, 22, nil, 12); calc:SetPoint("LEFT", amount, "RIGHT", 12, 0)
  local have = newText(box, "GameFontHighlightSmall", 240, TEXT); have:SetPoint("TOPRIGHT", -14, -16); have:SetJustifyH("RIGHT")
  local own = FLT.SkinBlizz(CreateFrame("CheckButton", nil, box, "UICheckButtonTemplate")); own:SetSize(22, 22)
  own:SetPoint("TOPLEFT", 10, -38)
  local ownText = newText(box, "GameFontHighlightSmall", nil, TEXT); ownText:SetPoint("LEFT", own, "RIGHT", 2, 0)
  ownText:SetText(L["Use crates and materials from my bags and bank first"])
  own:SetChecked(not (type(OneForAllDB) == "table" and OneForAllDB.favorCalcNoOwn == true))
  -- beta17: the Legacy "Performance Bonus" (3 points: +15 % Favor from crates) - the game does not tell it, so a switch
  local bonus = FLT.SkinBlizz(CreateFrame("CheckButton", nil, box, "UICheckButtonTemplate")); bonus:SetSize(22, 22)
  bonus:SetPoint("TOPLEFT", 10, -60)
  local bonusText = newText(box, "GameFontHighlightSmall", nil, TEXT); bonusText:SetPoint("LEFT", bonus, "RIGHT", 2, 0)
  bonusText:SetText(L["Legacy \"Performance Bonus\" (3 points: +15% Favor from crates)"])
  bonus:SetChecked(type(OneForAllDB) == "table" and OneForAllDB.favorCalcBonus == true)
  local src = newText(box, "GameFontDisableSmall", W - 50); src:SetPoint("TOPLEFT", 14, -86); src:SetWordWrap(false)
  -- beta17: the shopping list as an Auctionator shopping list
  local toAuc = UI.GoldButton(box, L["Auctionator shopping list"], 180, 22, nil, 11); toAuc:SetPoint("TOPRIGHT", -14, -36)

  local sum = newText(f, "GameFontNormalLarge", W - 30, GOLD); sum:SetPoint("TOPLEFT", 14, -146)
  local short = newText(f, "GameFontHighlightSmall", W - 30, { 1, 0.45, 0.35 }); short:SetPoint("TOPLEFT", 14, -168)
  local sf = FLT.SkinBlizz(CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate"))
  sf:SetPoint("TOPLEFT", 0, -186); sf:SetPoint("BOTTOMRIGHT", -26, 0)
  local child = CreateFrame("Frame", nil, sf); child:SetSize(W, 1); sf:SetScrollChild(child)
  UI.AutoHideScrollBar(sf)
  local rows, heads = {}, {}
  local function head(i, y, text)
    local h = heads[i]
    if not h then
      h = CreateFrame("Frame", nil, child); h:SetSize(W - 16, 24)
      h.text = newText(h, "GameFontNormal", W - 30, UI.HEAD_GOLD or GOLD); h.text:SetPoint("LEFT", 6, -2)
      local line = UI.makeTexture(h, "ARTWORK", 0.72, 0.50, 0.12, 0.45); line:SetPoint("BOTTOMLEFT", 2, 0); line:SetPoint("BOTTOMRIGHT", -2, 0); line:SetHeight(1)
      heads[i] = h
    end
    h:ClearAllPoints(); h:SetPoint("TOPLEFT", 8, y); h.text:SetText(text); h:Show()
  end
  local function iconBtn(parent, size)
    local b = CreateFrame("Button", nil, parent); b:SetSize(size, size)
    b.tex = b:CreateTexture(nil, "ARTWORK"); b.tex:SetAllPoints(); b.tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b:SetScript("OnEnter", tipItem); b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
  end
  local function row(i)
    local r = rows[i]; if r then return r end
    r = CreateFrame("Frame", nil, child); r:SetSize(W - 16, 34)
    r.card = UI.CardRow(r)
    r.ic = iconBtn(r, 24); r.ic:SetPoint("LEFT", 8, 0)
    r.name = newText(r, "GameFontHighlight", 250); r.name:SetPoint("LEFT", 40, 0); r.name:SetWordWrap(false)
    r.mid = iconBtn(r, 20); r.mid:SetPoint("LEFT", 296, 0)
    r.midText = newText(r, "GameFontHighlightSmall", 230, TEXT); r.midText:SetPoint("LEFT", 322, 0); r.midText:SetWordWrap(false)
    r.cost = newText(r, "GameFontHighlightSmall", 200, GOLD); r.cost:SetPoint("RIGHT", -10, 0); r.cost:SetJustifyH("RIGHT")
    rows[i] = r
    return r
  end

  local crow = {}
  local CCOL = { { 8, 210, "LEFT" }, { 222, 50, "RIGHT" }, { 290, 110, "RIGHT" }, { 410, 110, "RIGHT" }, { 530, 60, "RIGHT" }, { 600, 150, "RIGHT" } }
  local function cmpRow(i)
    local r = crow[i]; if r then return r end
    r = CreateFrame("Frame", nil, child); r:SetSize(W - 16, 20); r:EnableMouse(true)
    local hi = r:CreateTexture(nil, "HIGHLIGHT"); hi:SetAllPoints(); hi:SetColorTexture(FLT.SkinC(0.90, 0.66, 0.22, 0.07))
    r.c = {}
    for k, c in ipairs(CCOL) do
      local fs = newText(r, k == 1 and "GameFontHighlight" or "GameFontHighlightSmall", c[2]); fs:SetPoint("LEFT", c[1], 0); fs:SetJustifyH(c[3])
      fs:SetWordWrap(false); r.c[k] = fs
    end
    r:SetScript("OnEnter", function(self) if self.item then tipItem(self) end end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    crow[i] = r
    return r
  end

  local function sourceText()
    local AS = FLT.AHScan
    local age = AS and AS.Age and AS.Age()
    local d = AS and AS.Data and AS.Data()
    if age and d and d.fav then
      return string.format(L["Prices: your auction house scan from %s ago (button \"Cheap Upgrade Scan\" at the auction house)."], AS.FormatAge and AS.FormatAge(age) or tostring(math.floor(age / 60)))
    end
    return nil
  end

  local function paint()
    missing = false
    local want = tonumber(amount:GetText()) or 0
    if type(OneForAllDB) == "table" then OneForAllDB.favorCalcWant = want end
    local cur = getFavor and getFavor()
    have:SetText(cur and string.format(L["You have %d Favor"], cur) or "")
    local opts = { own = own:GetChecked() and true or false, bonus = bonus:GetChecked() and 1.15 or 1, label = FLT.FavorCalc.LabelOpen() }
    local plan = FLT.FavorCalc.Plan(want, opts)
    f.plan = plan
    toAuc:SetShown(type(Auctionator) == "table" and Auctionator.API and Auctionator.API.v1 and Auctionator.API.v1.CreateShoppingList and next(plan.buy) and true or false)
    local st = sourceText()
    if plan.source == "auctionator" then st = L["Prices: Auctionator (one price per item, without amounts) - a scan with \"Cheap Upgrade Scan\" at the auction house is more exact."]
    elseif not st then st = L["No prices yet: open the auction house and press \"Cheap Upgrade Scan\"."] end
    src:SetText(st)
    for _, h in ipairs(heads) do h:Hide() end
    for _, r in ipairs(rows) do r:Hide() end
    for _, r in ipairs(crow) do r:Hide() end
    if plan.favor == 0 then
      sum:SetText(want > 0 and L["No way found with the current prices."] or "")
      short:SetText("")
      child:SetHeight(1)
      return
    end
    sum:SetText(string.format(L["%d Favor for %s  ·  %s per Favor"], plan.favor, money(plan.cost), money(plan.cost / plan.favor)))
    local note = plan.short and string.format(L["The auction house has not enough crates or materials for more than %d Favor."], plan.favor)
      or (plan.label and string.format(L["Counted: +%d Favor from the one-time quest \"Shipping Label\" with your first crate."], FLT.FavorCalc.LABEL_FAVOR)) or ""
    short:SetText(note)
    local y, nr, nh = -2, 0, 0
    nh = nh + 1; head(nh, y, L["Crates to fill"]); y = y - 28
    for _, e in ipairs(plan.crates) do
      nr = nr + 1; local r = row(nr); r:ClearAllPoints(); r:SetPoint("TOPLEFT", 8, y); r:Show(); y = y - 36
      r.ic.item = e.crate.id; FLT.SetTex(r.ic.tex, icon(e.crate.id))
      r.name:SetText(string.format("%d x %s", e.n, iname(e.crate.id)) .. "  |cff9d9d9d(" .. string.format(L["%d Favor each"], e.crate.favor) .. ")|r")
      r.mid.item = e.bundle[1]; FLT.SetTex(r.mid.tex, icon(e.bundle[1])); r.mid:Show()
      r.midText:SetText(string.format(L["each %d x %s"], e.bundle[2], iname(e.bundle[1])))
      r.cost:SetText(money(e.cost + e.mats) .. (e.own > 0 and ("  |cff9d9d9d" .. string.format(L["(%d from your bags)"], e.own) .. "|r") or ""))
    end
    y = y - 8
    nh = nh + 1; head(nh, y, L["Shopping list"]); y = y - 28
    local list = {}
    for id, b in pairs(plan.buy) do list[#list + 1] = { id = id, b = b } end
    table.sort(list, function(a, b) return a.b.cost > b.b.cost end)
    for _, it in ipairs(list) do
      nr = nr + 1; local r = row(nr); r:ClearAllPoints(); r:SetPoint("TOPLEFT", 8, y); r:Show(); y = y - 36
      r.ic.item = it.id; FLT.SetTex(r.ic.tex, icon(it.id))
      r.name:SetText(string.format("%d x %s", it.b.n, iname(it.id)))
      r.mid:Hide()
      r.midText:SetText(it.b.max and string.format(L["up to %s each"], money(it.b.max)) or "")
      local o = plan.useOwn[it.id]
      r.cost:SetText(money(it.b.cost) .. (o and ("  |cff9d9d9d" .. string.format(L["(+%d from your bags)"], o) .. "|r") or ""))
    end
    -- what comes from your bags only
    for id, o in pairs(plan.useOwn) do
      if not plan.buy[id] then
        nr = nr + 1; local r = row(nr); r:ClearAllPoints(); r:SetPoint("TOPLEFT", 8, y); r:Show(); y = y - 36
        r.ic.item = id; FLT.SetTex(r.ic.tex, icon(id))
        r.name:SetText(string.format("%d x %s", o, iname(id)))
        r.mid:Hide(); r.midText:SetText(L["from your bags"]); r.cost:SetText("")
      end
    end
    -- beta17 (user 27.11., screenshot of another addon): every crate on its own for this amount, cheapest per Favor first
    y = y - 8
    nh = nh + 1; head(nh, y, L["All crates compared"]); y = y - 26
    local hr = cmpRow(1); hr:ClearAllPoints(); hr:SetPoint("TOPLEFT", 8, y); hr:Show(); hr.item = nil; y = y - 22
    local htext = { L["Crate"], L["Favor"], L["Each"], L["Per Favor"], L["Crates"], L["Total"] }
    for k = 1, 6 do hr.c[k]:SetText(htext[k]); hr.c[k]:SetTextColor(FLT.TextC(0.90, 0.78, 0.53)) end
    local mult = opts.bonus or 1
    for i, e in ipairs(FLT.FavorCalc.Compare(want, { own = opts.own, bonus = opts.bonus })) do
      local r = cmpRow(i + 1); r:ClearAllPoints(); r:SetPoint("TOPLEFT", 8, y); r:Show(); y = y - 22
      r.item = e.crate.id
      local gathered = e.crate.kind == "g"
      r.c[1]:SetText(iname(e.crate.id)); r.c[1]:SetTextColor(FLT.TextC(unpack(gathered and TEXT or { 0.35, 0.90, 0.35 })))
      local fv = e.crate.favor * mult
      r.c[2]:SetText((e.crate.tier == 4 and "~" or "") .. (fv == math.floor(fv) and tostring(fv) or string.format("%.1f", fv)))
      for k = 2, 6 do r.c[k]:SetTextColor(FLT.TextC(unpack(TEXT))) end
      if e.per then
        r.c[3]:SetText(money(e.each)); r.c[4]:SetText(money(e.per)); r.c[5]:SetText(e.n .. (e.short and "*" or ""))
        r.c[6]:SetText(money(e.cost)); r.c[4]:SetTextColor(FLT.TextC(unpack(GOLD)))
      else
        r.c[3]:SetText(L["no offers"]); r.c[4]:SetText(""); r.c[5]:SetText(""); r.c[6]:SetText("")
        for k = 3, 6 do r.c[k]:SetTextColor(FLT.TextC(unpack(DIM))) end
      end
    end
    local legend = crow.legend
    if not legend then legend = newText(child, "GameFontDisableSmall", W - 30); crow.legend = legend end
    legend:ClearAllPoints(); legend:SetPoint("TOPLEFT", 12, y - 4)
    legend:SetText(L["Green = crafted goods. Each = crate + its cheapest bundle. Crates = if you bought only that crate; * = the auction house has not enough of it. ~ = Favor not confirmed yet."])
    y = y - 40
    child:SetHeight(-y + 10)
    if missing and C_Timer then C_Timer.After(1, function() if f:IsVisible() then paint() end end) end
  end
  calc:SetScript("OnClick", function() amount:ClearFocus(); paint() end)
  amount:SetScript("OnEnterPressed", function(self) self:ClearFocus(); paint() end)
  amount:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  bonus:SetScript("OnClick", function(self)
    if type(OneForAllDB) == "table" then OneForAllDB.favorCalcBonus = self:GetChecked() and true or nil end
    paint()
  end)
  toAuc:SetScript("OnClick", function()
    if FLT.FavorCalc.ToAuctionator(f.plan) then
      if FLT.Msg then FLT.Msg(L["Auctionator shopping list \"OneForAll Favor\" created."]) end
    elseif FLT.Msg then FLT.Msg(L["Could not create the Auctionator list - are the item names loaded? Try again in a moment."]) end
  end)
  toAuc:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:AddLine(L["Auctionator shopping list"], 1, 0.82, 0)
    GameTooltip:AddLine(L["Puts the shopping list into Auctionator as the list \"OneForAll Favor\" (Shopping tab at the auction house)."], 1, 1, 1, true)
    GameTooltip:Show()
  end)
  toAuc:SetScript("OnLeave", function() GameTooltip:Hide() end)
  own:SetScript("OnClick", function(self)
    if type(OneForAllDB) == "table" then OneForAllDB.favorCalcNoOwn = not self:GetChecked() or nil end
    paint()
  end)
  f:SetScript("OnShow", paint)
  f.Paint = paint
  return f
end
