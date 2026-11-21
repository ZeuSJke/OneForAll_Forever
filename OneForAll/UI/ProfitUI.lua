local _, FLT = ...
local L = FLT.L or setmetatable({}, { __index = function(_, k) return k end }) -- (tests without Locales)
local UI = FLT.UI
local GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local GetItemIcon = (C_Item and C_Item.GetItemIconByID) or GetItemIcon

-- Profit page (Professions > a profession > "Profit", 6.2.6-beta28, user 12.11.: "einen Search starten ... der die
-- Rezepte durchsucht und prueft wo anhand des Herstellungspreises ein Profit geholt werden kann indem man es im AH
-- verkauft"; "only known recipes" on by default; when the AH was scanned; shopping list for Auctionator; into the
-- Crafting List). Logic: SkillUp.lua SU.Profit. Lean: worked out only when "Search" is clicked.
-- Saved: OneForAllDB.skillUp.profitAll = true when "Only known recipes" is switched off.

local SU = FLT.SkillUp
if not SU then return end
local GOLD = UI.GOLD or { 1, 0.82, 0.20 }

local function sdb()
  if type(OneForAllDB) ~= "table" then return {} end
  OneForAllDB.skillUp = OneForAllDB.skillUp or {}
  return OneForAllDB.skillUp
end
local function money(c) if FLT.QoL and FLT.QoL.Money then return FLT.QoL.Money(math.floor((c or 0) + 0.5)) end return tostring(c) end
local function itemName(id) local n = GetItemInfo and GetItemInfo(id); return n or (L["Item"] .. " " .. id) end
local function recipeName(r) return FLT.RecipeName and FLT.RecipeName(r) or r.n end

function UI.CreateProfitPage(parent)
  local f = CreateFrame("Frame", nil, parent); f:SetAllPoints(); f:Hide()
  local prof, results, sel = nil, nil, {}
  local allResults -- the whole search result; results = what the filters let through
  local qty = {} -- crafts per selected recipe (beta29, user 12.11.: "ein feld wo ich die anzahl eingeben kann ... 10 oder 20")
  local function count(s) return math.max(1, math.floor(tonumber(qty[s]) or 1)) end
  UI.SectionTitle(f, L["Profit"], 8, -4, -430)

  local search = UI.GoldButton(f, L["Search"], 100, 22, nil, 12); search:SetPoint("TOPLEFT", 10, -32)
  local known = FLT.SkinBlizz(CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")); known:SetSize(22, 22)
  known:SetPoint("LEFT", search, "RIGHT", 16, 0)
  local knownFS = FLT.NewFS(f, nil, "OVERLAY", "GameFontHighlightSmall"); knownFS:SetPoint("LEFT", known, "RIGHT", 4, 0)
  knownFS:SetText(L["Only known recipes"])
  if UI.NoAltsSwitch then -- only the shopping list for Auctionator uses what you have
    local cb, fs = UI.NoAltsSwitch(f); cb:SetPoint("LEFT", knownFS, "RIGHT", 18, 0); fs:SetPoint("LEFT", cb, "RIGHT", 4, 0)
  end
  local scanFS = FLT.NewFS(f, nil, "OVERLAY", "GameFontHighlightSmall"); scanFS:SetPoint("TOPRIGHT", -12, -38); scanFS:SetJustifyH("RIGHT")
  -- filters (beta32, user 12.11.: "mehr einstellen ... Skill von bis, und Profit von"): learn level from - to and the
  -- least profit in gold, applied to the search result at once; empty = no limit (OneForAllDB.skillUp.profitFilter)
  local function fdb() local d = sdb(); d.profitFilter = d.profitFilter or {}; return d.profitFilter end
  local apply -- forward
  local function numBox(w, letters, key)
    local e = FLT.SkinBlizz(CreateFrame("EditBox", nil, f, "InputBoxTemplate"))
    e:SetSize(w, 20); e:SetAutoFocus(false); e:SetNumeric(true); e:SetMaxLetters(letters); e:SetJustifyH("CENTER")
    local v = tonumber(fdb()[key]); e:SetText(v and tostring(v) or "")
    e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    e:SetScript("OnTextChanged", function(self, user)
      if not user then return end
      fdb()[key] = tonumber(self:GetText())
      if apply then apply() end
    end)
    return e
  end
  local skFS = FLT.NewFS(f, nil, "OVERLAY", "GameFontHighlightSmall"); skFS:SetPoint("TOPLEFT", 14, -64); skFS:SetText(L["Skill"])
  local lo = numBox(40, 3, "lo"); lo:SetPoint("LEFT", skFS, "RIGHT", 10, 0)
  local dash = FLT.NewFS(f, nil, "OVERLAY", "GameFontHighlightSmall"); dash:SetPoint("LEFT", lo, "RIGHT", 6, 0); dash:SetText("-")
  local hi = numBox(40, 3, "hi"); hi:SetPoint("LEFT", dash, "RIGHT", 8, 0)
  local mpFS = FLT.NewFS(f, nil, "OVERLAY", "GameFontHighlightSmall"); mpFS:SetPoint("LEFT", hi, "RIGHT", 24, 0); mpFS:SetText(L["Min. profit (silver)"])
  -- beta36 (user 12.11.: "momentan gibt es noch nichts mit 1g profit, das muss weiter runtergebrochen werden"): in silver
  local minS = numBox(60, 6, "minS"); minS:SetPoint("LEFT", mpFS, "RIGHT", 10, 0)
  -- beta36 (user 12.11.: "oben eine anzeige wieviel profit ... und wieviel gold ich investieren muss"): for the selection,
  -- right on the filter row: the gold to put in (material cost x crafts) and the profit about
  local selFS = FLT.NewFS(f, nil, "OVERLAY", "GameFontNormal"); selFS:SetPoint("TOPRIGHT", -12, -88); selFS:SetJustifyH("RIGHT")
  local status = FLT.NewFS(f, nil, "OVERLAY", "GameFontDisableSmall"); status:SetPoint("TOPLEFT", 12, -90); status:SetPoint("RIGHT", selFS, "LEFT", -16, 0)
  status:SetJustifyH("LEFT"); status:SetWordWrap(false)

  local addCL = UI.GoldButton(f, L["Add to Crafting List"], 160, 24, nil, 12); addCL:SetPoint("TOPRIGHT", -10, -2)
  local sendA = UI.GoldButton(f, L["Send to Auctionator"], 150, 24, nil, 12); sendA:SetPoint("RIGHT", addCL, "LEFT", -8, 0)
  -- beta36 (user 12.11.: "dann brauchen wir einen button all mats from AH"): the same list with every material, also
  -- the ones a vendor sells (who would rather buy them at the auction house)

  local cols = { { x = 0, w = 270, text = L["Recipe"] }, { x = 270, w = 50, text = L["Skill"] }, { x = 320, w = 60, text = L["Crafts"] }, { x = 380, w = 110, text = L["Cost"] }, { x = 490, w = 110, text = L["Sale"] },
    { x = 600, w = 120, text = L["Profit"] }, { x = 720, w = 80, text = L["Margin"] } }
  UI.ColumnHeader(f, cols, 820, -108)
  local sf = FLT.SkinBlizz(CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate"))
  sf:SetPoint("TOPLEFT", 4, -136); sf:SetPoint("BOTTOMRIGHT", -26, 4)
  local child = CreateFrame("Frame", nil, sf); child:SetSize(800, 10); sf:SetScrollChild(child)
  if UI.PlaceScrollBar then UI.PlaceScrollBar(sf) end
  local empty = FLT.NewFS(child, nil, "OVERLAY", "GameFontDisable"); empty:SetPoint("TOP", 0, -30); empty:SetWidth(700)

  local function selected()
    local out = {}
    for _, e in ipairs(results or {}) do if sel[e.r.s] then out[#out + 1] = e end end
    return out
  end
  local summary -- the status line with what is selected
  local function paintButtons()
    local n = #selected()
    if summary then summary() end
    addCL:SetLook(n > 0 and FLT.CraftList ~= nil)
    sendA:SetLook(n > 0 and SU.HasAuctionator())
  end

  local rows, used = {}, 0
  local function row(i)
    local b = rows[i]
    if b then return b end
    b = CreateFrame("Button", nil, child); b:SetHeight(28); UI.QuietRow(b)
    if b.RegisterForClicks then b:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
    b:SetPoint("TOPLEFT", 0, -(i - 1) * 30); b:SetPoint("RIGHT", child, "RIGHT", 0, 0)
    b.check = UI.Mark(b, 14, "ring", 0.55, 0.55, 0.55); b.check:SetPoint("LEFT", 10, 0)
    b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetSize(20, 20); b.icon:SetPoint("LEFT", 32, 0)
    b.name = FLT.NewFS(b, nil, "OVERLAY", "GameFontHighlight"); b.name:SetPoint("LEFT", 58, 0); b.name:SetWidth(208)
    -- the skill needed to learn it (beta30, user 12.11.: "die stufe zum erlernen waere sehr hilfreich"); red above yours
    b.req = FLT.NewFS(b, nil, "OVERLAY", "GameFontHighlightSmall"); b.req:SetPoint("LEFT", 278, 0); b.req:SetWidth(44); b.req:SetJustifyH("LEFT"); b.name:SetJustifyH("LEFT"); b.name:SetWordWrap(false)
    b.cost = FLT.NewFS(b, nil, "OVERLAY", "GameFontHighlightSmall"); b.cost:SetPoint("LEFT", 388, 0); b.cost:SetWidth(104); b.cost:SetJustifyH("LEFT")
    b.sale = FLT.NewFS(b, nil, "OVERLAY", "GameFontHighlightSmall"); b.sale:SetPoint("LEFT", 498, 0); b.sale:SetWidth(104); b.sale:SetJustifyH("LEFT")
    b.profit = FLT.NewFS(b, nil, "OVERLAY", "GameFontHighlightSmall"); b.profit:SetPoint("LEFT", 608, 0); b.profit:SetWidth(114); b.profit:SetJustifyH("LEFT")
    b.margin = FLT.NewFS(b, nil, "OVERLAY", "GameFontHighlightSmall"); b.margin:SetPoint("LEFT", 728, 0); b.margin:SetWidth(70); b.margin:SetJustifyH("LEFT")
    -- how many crafts: typing a number selects the recipe
    b.qty = FLT.SkinBlizz(CreateFrame("EditBox", nil, b, "InputBoxTemplate"))
    b.qty:SetSize(36, 18); b.qty:SetPoint("LEFT", 332, 0); b.qty:SetAutoFocus(false); b.qty:SetNumeric(true); b.qty:SetMaxLetters(3); b.qty:SetJustifyH("CENTER")
    b.qty:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    b.qty:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    b.qty:SetScript("OnTextChanged", function(self, user)
      local e = b.e
      if not (e and user) then return end
      local n = tonumber(self:GetText())
      qty[e.r.s] = n and n > 0 and n or nil
      if n and n > 0 and not sel[e.r.s] then
        sel[e.r.s] = true; b.check:SetKind("check"); b.check:SetColor(0.35, 0.85, 0.40)
      end
      paintButtons()
    end)
    b:SetScript("OnClick", function(self, button)
      if not self.e then return end
      -- beta29 (user 12.11.: "per rechtsklick ... direkt in die professions zu diesem recipe springen")
      if button == "RightButton" then
        if FLT.ShowRecipeInProfessions then FLT.ShowRecipeInProfessions(prof, self.e.r.s) end
        return
      end
      sel[self.e.r.s] = not sel[self.e.r.s] or nil
      self.check:SetKind(sel[self.e.r.s] and "check" or "ring")
      if sel[self.e.r.s] then self.check:SetColor(0.35, 0.85, 0.40) else self.check:SetColor(0.55, 0.55, 0.55) end
      paintButtons()
    end)
    b:SetScript("OnEnter", function(self)
      local e = self.e
      if not e then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      if e.r.i and GameTooltip.SetItemByID then GameTooltip:SetItemByID(e.r.i) else GameTooltip:AddLine(recipeName(e.r), GOLD[1], GOLD[2], GOLD[3]) end
      GameTooltip:AddLine(" ")
      for _, g in ipairs(e.r.r or {}) do
        local price, src = SU.BuyPrice(g[1])
        local where = src == "ah" and L["Auction house"] or (src == "vendor" and L["Vendor"] or L["no price"])
        GameTooltip:AddDoubleLine(g[2] .. "x " .. itemName(g[1]) .. " |cff9d9d9d(" .. where .. ")|r", price and money(price * g[2]) or "-", 1, 1, 1, 1, 1, 1)
      end
      GameTooltip:AddLine(" ")
      GameTooltip:AddLine(L["Sale: the auction house price minus the 5% auction house cut."], 0.62, 0.62, 0.62, true)
      if e.guess then GameTooltip:AddLine(L["A material has no price yet - its cost is only estimated."], 1, 0.6, 0.25, true) end
      if not e.known then GameTooltip:AddLine(L["You do not know this recipe yet."], 1, 0.6, 0.25, true) end
      GameTooltip:AddLine(L["Click: select for the shopping list and the Crafting List. Right-click: open the recipe in All recipes."], 0.5, 0.5, 0.5, true)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    rows[i] = b
    return b
  end

  summary = function()
    if not results then return end
    local n, crafts, total, invest = 0, 0, 0, 0
    for _, e in ipairs(results) do
      if sel[e.r.s] then local c = count(e.r.s); n = n + 1; crafts = crafts + c; total = total + e.profit * c; invest = invest + e.cost * c end
    end
    selFS:SetText(n > 0 and (string.format(L["Invest: %s"], "|cffffffff" .. money(invest) .. "|r") .. "     " .. string.format(L["Profit: %s"], "|cff40ff60+" .. money(total) .. "|r")) or "")
    local t = string.format(L["%d recipes with profit (after the 5%% auction house cut)."], #results)
    local hid = (allResults and #allResults or 0) - #results
    if hid > 0 then t = t .. " |cff9d9d9d(" .. string.format(L["%d hidden by the filters"], hid) .. ")|r" end
    if n > 0 then t = t .. "   |cffffd060" .. string.format(L["Selected: %d recipes, %d crafts"], n, crafts) .. "|r" end
    status:SetText(t)
  end
  local mySkill
  local function draw()
    local st = prof and FLT.GetProfessionState and FLT.GetProfessionState(prof)
    mySkill = st and st.skill or 0
    for i = 1, used do rows[i]:Hide() end
    used = 0
    scanFS:SetText(SU.ScanText())
    if not SU.HasAuctionator() then
      status:SetText("|cffffb040" .. L["Needs Auctionator: the auction house prices come from it."] .. "|r")
    elseif not results then status:SetText(L["Click Search to find the recipes that sell for more than their materials cost."])
    else summary() end
    local why = ""
    if results and #results == 0 then
      local st = SU.profitStats
      if allResults and #allResults == 0 and st and st.priced == 0 then
        why = L["None of these items is on the auction house in the last Auctionator scan - scan it again (Auctionator: Full Scan)."]
      elseif allResults and #allResults == 0 and st and st.costed == 0 then
        why = string.format(L["%d items have an auction house price, but a price for at least one of their materials is missing."], st.priced)
      elseif allResults and #allResults == 0 and st then
        why = string.format(L["%d items have prices: none sells for more than its materials cost right now."], st.costed)
      end
      why = L["Nothing found that sells with profit right now."] .. (why ~= "" and ("\n|cff9d9d9d" .. why .. "|r") or "")
    end
    empty:SetText(why)
    for i, e in ipairs(results or {}) do
      local b = row(i); used = i; b.e = e
      b.check:SetKind(sel[e.r.s] and "check" or "ring")
      if sel[e.r.s] then b.check:SetColor(0.35, 0.85, 0.40) else b.check:SetColor(0.55, 0.55, 0.55) end
      b.icon:SetTexture((e.r.i and GetItemIcon and GetItemIcon(e.r.i)) or e.r.ic or "Interface\\Icons\\INV_Misc_QuestionMark")
      local nm = recipeName(e.r)
      if (e.r.c or 1) > 1 then nm = nm .. " |cff9d9d9dx" .. e.r.c .. "|r" end
      -- the product's rarity colour (beta29, user 12.11.: "seltenheitsfarben werden nicht angezeigt"); beta36 (user 12.11.:
      -- "items sind viele grau, die die ich nicht kann ... die tatsaechliche farbe"): also for recipes not learned yet
      -- (those show by the red skill and the tooltip)
      local gi = (C_Item and C_Item.GetItemInfo) or GetItemInfo
      local q = e.r.q or (e.r.i and gi and select(3, gi(e.r.i)))
      local qc = q and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
      if qc then nm = string.format("|cff%02x%02x%02x", math.floor(qc.r * 255), math.floor(qc.g * 255), math.floor(qc.b * 255)) .. nm .. "|r" end
      b.name:SetText(nm)
      b.qty:SetText(tostring(count(e.r.s)))
      local req, sk = e.r.req, mySkill or 0
      b.req:SetText(req and ((req > sk and "|cffff6060" or "|cffd8d8d8") .. req .. "|r") or "-")
      b.cost:SetText((e.guess and "~" or "") .. money(e.cost))
      b.sale:SetText(money(e.sale))
      b.profit:SetText("|cff40ff60+" .. money(e.profit) .. "|r")
      b.margin:SetText(string.format("%d%%", math.floor(e.margin * 100 + 0.5)))
      b:Show()
    end
    child:SetHeight(math.max(10, used * 30 + 10))
    paintButtons()
  end

  apply = function()
    if not allResults then return end
    local d = fdb()
    local l, h, m = tonumber(d.lo), tonumber(d.hi), tonumber(d.minS)
    results = {}
    for _, e in ipairs(allResults) do
      local req = e.r.req or 1
      if (not l or req >= l) and (not h or req <= h) and (not m or e.profit >= m * 100) then results[#results + 1] = e end
    end
    local keep = {}
    for _, e in ipairs(results) do if sel[e.r.s] then keep[e.r.s] = true end end
    sel = keep
    draw()
  end
  local function doSearch()
    if not prof then return end
    allResults = SU.Profit(prof, not sdb().profitAll)
    apply()
  end
  known:SetChecked(not sdb().profitAll)
  -- (beta32: the switch searches again when there is a result, so the list always matches it)
  known:SetScript("OnClick", function(self) sdb().profitAll = (not self:GetChecked()) or nil; if allResults then doSearch() end end)
  search:SetScript("OnClick", doSearch)
  -- 6.2.8 (user 14.11.: "einen Reset button ... der die Maske zurueck setzt"): empty filters, no selection, no result
  local reset = UI.GoldButton(f, L["Reset"], 70, 20, nil, 11); reset:SetPoint("LEFT", minS, "RIGHT", 14, 0)
  -- 6.2.12-beta19: "Don't use own materials" behind Reset (beta19 first put it on top of Reset - user 18.11. "was hast du
  -- denn da gemacht?"); the shopping list takes nothing off (SU.ProfitBuyList)
  if UI.NoOwnSwitch then
    local cb, fs = UI.NoOwnSwitch(f); cb:SetPoint("LEFT", reset, "RIGHT", 18, 0); fs:SetPoint("LEFT", cb, "RIGHT", 4, 0)
  end
  reset:SetScript("OnClick", function()
    local d = fdb(); d.lo, d.hi, d.minS = nil, nil, nil
    lo:SetText(""); hi:SetText(""); minS:SetText(""); lo:ClearFocus(); hi:ClearFocus(); minS:ClearFocus()
    sel, allResults, results = {}, nil, nil
    for k in pairs(qty) do qty[k] = nil end
    draw()
  end)
  reset:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM"); GameTooltip:AddLine(L["Reset"], GOLD[1], GOLD[2], GOLD[3])
    GameTooltip:AddLine(L["Clears the filters, the selection and the search result."], 1, 1, 1, true); GameTooltip:Show()
  end)
  reset:SetScript("OnLeave", function() GameTooltip:Hide() end)
  f.resetButton = reset
  addCL:SetScript("OnClick", function()
    local CL, list = FLT.CraftList, selected()
    if not CL or #list == 0 then return end
    local function add()
      for _, e in ipairs(list) do CL.Add(prof, e.r.s, (e.r.c or 1) * count(e.r.s)) end -- the list counts items
      if CL.Show then CL.Show() end
      if FLT.Msg then FLT.Msg(string.format(L["%d recipes added to the Crafting List."], #list)) end
    end
    if CL.AddAsk then CL.AddAsk(add) else add() end -- asks to clear a list that has recipes (6.2.10)
  end)
  local function send()
    local list = selected()
    if #list == 0 then return end
    -- beta36 (user 12.11.): what the bags hold is taken off; beta37: a material cheaper to make (Bolt of Silk Cloth) is
    -- broken down into its own materials (Silk Cloth), as the profit cost counts it - SU.ProfitBuyList
    local picks, items = {}, {}
    for _, e in ipairs(list) do picks[#picks + 1] = { r = e.r, n = count(e.r.s) } end
    for id, n in pairs(SU.ProfitBuyList(picks)) do
      local _, src = SU.BuyPrice(id)
      if src == "ah" then items[#items + 1] = { id = id, n = n } end
    end
    table.sort(items, function(a, b) return a.id < b.id end)
    local function msg(ok, missing)
      if not FLT.Msg then return end
      FLT.Msg(ok and L["Shopping list \"OneForAll Profit\" is in Auctionator (Shopping tab)."] or L["Auctionator did not take the list (open the auction house once, then try again)."])
      if ok and missing > 0 then FLT.Msg(string.format(L["%d materials could not be added yet (item data still loading) - send the list again."], missing)) end
    end
    if #items > 0 then SU.SendToAuctionator({ ah = items }, "OneForAll Profit", msg) else msg(false, 0) end
  end
  sendA:SetScript("OnClick", send)
  addCL:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM"); GameTooltip:AddLine(L["Add to Crafting List"], GOLD[1], GOLD[2], GOLD[3])
    GameTooltip:AddLine(L["Puts every selected recipe on the Crafting List, as many crafts as in its field."], 1, 1, 1, true); GameTooltip:Show()
  end)
  addCL:SetScript("OnLeave", function() GameTooltip:Hide() end)
  sendA:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM"); GameTooltip:AddLine(L["Send to Auctionator"], GOLD[1], GOLD[2], GOLD[3])
    GameTooltip:AddLine(L["The auction house materials for the selected recipes (as many crafts as in their fields), as the shopping list \"OneForAll Profit\"."], 1, 1, 1, true)
    GameTooltip:AddLine((SU.NoOwn and SU.NoOwn() and L["Nothing you already have is taken off."]) or (SU.NoAlts and SU.NoAlts() and L["What you already have (bags, bank) is taken off."]) or L["What you already have (bags, bank, other characters) is taken off."], 0.7, 0.7, 0.7, true); GameTooltip:Show()
  end)
  sendA:SetScript("OnLeave", function() GameTooltip:Hide() end)

  function f:ShowProfession(p)
    if p ~= prof then prof, results, allResults, sel = p, nil, nil, {} end
    self:Show(); draw()
  end
  return f
end
