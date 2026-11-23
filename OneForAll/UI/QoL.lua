local _, FLT = ...
local function N(s) return s end -- marks an English text translated where it is shown (tools/locale/extract.py)
local L = FLT.L or setmetatable({}, { __index = function(_, k) return k end }) -- (tests without Locales)
-- 6.2.0: the builders below (category, group, row, check, check2, choice, button, hint) get the ENGLISH texts (N"...")
-- and translate them where they are shown; the search finds both the English and the translated words
local UI = FLT.UI

-- Quality of Life tab: one switch per feature (defaults in QoL.lua DEFAULTS).
-- Logic lives in QoL.lua (FLT.QoL).

local unpack = unpack or table.unpack
local GOLD = UI.GOLD
local openDropDown -- below

-- Yellow "!" (tooltip "New") next to options added since the last live release.
-- Kept for all versions of a minor line (5.7.0 ... 5.7.x); emptied when the next minor line
-- (5.8.0) starts (TODO.md "Neu-Markierungen").
local NEW_TAGS = { -- user 20.11.2026 23:02: all marks from before 6.2.13 removed, only this version's stay
  gossipSkip = "6.2.13",
  gvMode = "6.2.13",
  ahScan = "6.2.13",
  runTracker = "6.2.14",
}
-- placed left of the checkbox (or of the label when there is none), user 16.10.
local function newTag(parent, anchor, key, dx)
  if not NEW_TAGS[key] then return end
  local m = UI.NewMark(parent, string.format(L["New in OneForAll %s."], NEW_TAGS[key]))
  m:SetPoint("RIGHT", anchor, "LEFT", dx or -2, 0)
  return m
end

-- Shared drop-down list (UI.OpenDropDown in Widgets.lua)
openDropDown = function(...) return UI.OpenDropDown(...) end


-- Preview popup: a framed picture that shows what a feature looks like in game.
-- previews[key] = { tex, width, height (shown size), texcoord bottom }
local PREVIEWS = {
  questSparkles = { title = N"Quest loot sparkles", tex = "preview_sparkles", w = 300, h = 300, t = 1 },
  bagsFull = { title = N"Bags full helper", tex = "preview_bagsfull", w = 560, h = 183, t = 167 / 256 },
  questXP = { title = N"Quest XP on the experience bar", tex = "preview_questxp", w = 640, h = 119, t = 190 / 256 },
  nodeGlow = { title = N"Sparkle on herbs & ore", tex = "preview_nodeglow", w = 300, h = 300, t = 1 }, -- user 26.10.
  -- the user's screenshots of 01.11.2026 (tools/art/proc_qol_previews.py, source_images/qol_previews)
  bossDrops = { title = N"Boss drops", tex = "preview_bossdrops", w = 462, h = 285, r = 462/512, t = 285/512 },
  buffIconOnly = { title = N"Buff reminder - icon only", tex = "preview_bufficononly", w = 158, h = 178, r = 99/128, t = 111/128 },
  buffReminder = { title = N"Buff reminder", tex = "preview_buffreminder", w = 451, h = 124, r = 451/512, t = 124/128 },
  classBright = { title = N"Brighter colors", tex = "preview_classbright", w = 301, h = 78, r = 301/512, t = 78/128 },
  classColors = { title = N"Class colors", tex = "preview_classcolors", w = 301, h = 81, r = 301/512, t = 81/128 },
  gearValue = { title = N"Gear Value", tex = "preview_gearvalue", w = 352, h = 237, r = 352/512, t = 237/256 },
  lowRank = { title = N"Check low spell ranks", tex = "preview_lowrank", w = 600, h = 217, r = 823/1024, t = 297/512 },
  mapButton = { title = N"OneForAll button on the map", tex = "preview_mapbutton", w = 312, h = 322, r = 312/512, t = 322/512 },
  mapZoneLevel = { title = N"Zone level range", tex = "preview_mapzonelevel", w = 442, h = 82, r = 442/512, t = 82/128 },
  mmCollect = { title = N"Collect minimap buttons", tex = "preview_collector", w = 276, h = 97, r = 276/512, t = 97/128 },
  mmSquare = { title = N"Square minimap", tex = "preview_mmsquare", w = 418, h = 498, r = 418/512, t = 498/512 },
  questMarks = { title = N"Quest marks on nameplates", tex = "preview_questmarks", w = 462, h = 195, r = 462/512, t = 195/256 },
  shortStats = { title = N"Short green stats", tex = "preview_shortstats", w = 465, h = 402, r = 465/512, t = 402/512 },
  spellbookTrainer = { title = N"Trainer button in the spellbook", tex = "preview_spellbooktrainer", w = 600, h = 128, r = 1024/1024, t = 219/256 },
}
local previewFrame
local function showPreview(key)
  local pv = PREVIEWS[key]; if not pv then return end
  if not previewFrame then
    local f = CreateFrame("Frame", "OneForAllPreviewFrame", UIParent)
    f:SetFrameStrata("DIALOG"); f:SetToplevel(true); f:EnableMouse(true); f:SetClampedToScreen(true)
    f:SetMovable(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
    UI.FramedPanel(f)
    f.title = FLT.NewFS(f, nil, "OVERLAY", "GameFontNormalLarge"); f.title:SetPoint("TOPLEFT", 16, -12); f.title:SetTextColor(FLT.TextC(1, 0.82, 0.20))
    local close = UI.CloseButton(f); close:SetPoint("TOPRIGHT", -10, -10)
    f.pic = f:CreateTexture(nil, "ARTWORK"); f.pic:SetPoint("TOPLEFT", 16, -40)
    f.picFrame = CreateFrame("Frame", nil, f); f.picFrame:SetAllPoints(f.pic)
    UI.OrnateFrame(f.picFrame, f.picFrame, 10, 2, "OVERLAY", 1)
    f.note = FLT.NewFS(f, nil, "OVERLAY", "GameFontDisableSmall"); f.note:SetPoint("BOTTOMLEFT", 16, 10)
    f.note:SetText(L["Example from the game. Click and drag to move, Escape to close."])
    if UISpecialFrames then table.insert(UISpecialFrames, "OneForAllPreviewFrame") end
    previewFrame = f
  end
  local f = previewFrame
  f.title:SetText(L[pv.title])
  FLT.SetTex(f.pic, UI.ASSET_ROOT .. pv.tex); f.pic:SetTexCoord(0, pv.r or 1, 0, pv.t)
  f.pic:SetSize(pv.w, pv.h)
  f:SetSize(math.max(pv.w + 32, 360), pv.h + 74)
  f:ClearAllPoints(); f:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
  f:Show(); f:Raise()
end

-- "Never suggested" list of the bags full helper: one row per item with an X to
-- take it off the list again, plus "Remove all". Opens below its button.
local neverMenu
local NEVER_ROWS = 10
local function itemLook(id)
  local name, quality, icon
  pcall(function()
    local info = { (C_Item and C_Item.GetItemInfo or GetItemInfo)(id) }
    name, quality, icon = info[1], info[3], info[10]
  end)
  if not icon then pcall(function() icon = (C_Item and C_Item.GetItemIconByID or GetItemIcon)(id) end) end
  if not name then pcall(function() if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end end) end
  return name, quality, icon or "Interface\\Icons\\INV_Misc_QuestionMark"
end
-- src (optional): another list in the same menu - { get, remove, clear, title, empty, removeTip, confirm }
-- (the own junk list, 5.7.3)
local function showNeverList(owner, onChange, src)
  local Q = FLT.QoL
  if not neverMenu then
    local catcher = CreateFrame("Button", nil, UIParent); catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata("FULLSCREEN_DIALOG"); catcher:SetFrameLevel(1); catcher:RegisterForClicks("AnyUp"); catcher:Hide()
    local m = CreateFrame("Frame", nil, UIParent); m:SetFrameStrata("FULLSCREEN_DIALOG"); m:SetFrameLevel(20)
    m:EnableMouse(true); m:EnableMouseWheel(true); m:Hide(); m:SetWidth(300)
    UI.FramedPanel(m)
    catcher:SetScript("OnClick", function() m:Hide() end)
    m:SetScript("OnHide", function() catcher:Hide() end)
    m.catcher, m.rows, m.offset = catcher, {}, 0
    m.title = FLT.NewFS(m, nil, "OVERLAY", "GameFontNormal"); m.title:SetPoint("TOPLEFT", 12, -10); m.title:SetTextColor(FLT.TextC(1, 0.82, 0.20))
    m.empty = FLT.NewFS(m, nil, "OVERLAY", "GameFontDisableSmall"); m.empty:SetPoint("TOPLEFT", 12, -32); m.empty:SetWidth(276); m.empty:SetJustifyH("LEFT")
    m.empty:SetText(L["Nothing on the list. In the bags full helper, the X button puts an item here so it is never suggested again."])
    m.more = FLT.NewFS(m, nil, "OVERLAY", "GameFontDisableSmall")
    m.clear = UI.GoldButton(m, L["Remove all"], 110, 22, nil, 11); m.clear:SetPoint("BOTTOMRIGHT", -10, 10)
    m.more:SetPoint("BOTTOMLEFT", 12, 16)
    for i = 1, NEVER_ROWS do
      local r = CreateFrame("Frame", nil, m); r:SetSize(280, 22); r:SetPoint("TOPLEFT", 10, -30 - (i - 1) * 24)
      r:EnableMouse(true)
      local hi = r:CreateTexture(nil, "BACKGROUND"); hi:SetAllPoints(); hi:SetColorTexture(FLT.SkinC(0.90, 0.66, 0.22, 0.12)); hi:Hide()
      r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(18, 18); r.icon:SetPoint("LEFT", 2, 0); r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
      r.text = FLT.NewFS(r, nil, "OVERLAY", "GameFontHighlight"); r.text:SetPoint("LEFT", 26, 0); r.text:SetWidth(222); r.text:SetJustifyH("LEFT"); r.text:SetWordWrap(false)
      r.x = CreateFrame("Button", nil, r); r.x:SetSize(16, 16); r.x:SetPoint("RIGHT", -4, 0)
      r.x:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up"); r.x:SetHighlightTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Highlight", "ADD")
      r.x:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText(L["Remove from the list"]); GameTooltip:AddLine(L[neverMenu.src.removeTip], 1, 1, 1, true); GameTooltip:Show() end)
      r.x:SetScript("OnLeave", function() GameTooltip:Hide() end)
      r:SetScript("OnEnter", function(self)
        hi:Show()
        if self.id then GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); pcall(GameTooltip.SetItemByID, GameTooltip, self.id); GameTooltip:Show() end
      end)
      r:SetScript("OnLeave", function() hi:Hide(); GameTooltip:Hide() end)
      m.rows[i] = r
    end
    m:SetScript("OnMouseWheel", function(self, delta)
      local n = #(self.ids or {})
      self.offset = math.max(0, math.min(math.max(0, n - NEVER_ROWS), self.offset - delta))
      self.fill()
    end)
    neverMenu = m
  end
  local m = neverMenu
  if m:IsShown() and m.owner == owner then m:Hide(); return end
  src = src or { get = Q.GetNeverItems, remove = Q.RemoveNever, clear = Q.ClearNever, title = N"Never suggested",
    empty = N"Nothing on the list. In the bags full helper, the X button puts an item here so it is never suggested again.",
    removeTip = N"The bags full helper may suggest this item again.", confirm = N"Remove all items from the\n\"never suggest\" list?" }
  m.src = src
  m.empty:SetText(L[src.empty])
  local retried = false
  m.fill = function()
    local ids = src.get(); m.ids = ids
    m.offset = math.max(0, math.min(m.offset, #ids - NEVER_ROWS))
    m.title:SetText(L[src.title] .. "  |  " .. (#ids == 1 and L["1 item"] or string.format(L["%d items"], #ids)))
    m.empty:SetShown(#ids == 0)
    local missing = false
    for i, r in ipairs(m.rows) do
      local id = ids[i + m.offset]
      if id then
        local name, quality, icon = itemLook(id)
        if not name then missing = true end
        r.id = id
        r.icon:SetTexture(icon)
        r.text:SetText(name or (L["Item"] .. " " .. id))
        local c = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
        if c then r.text:SetTextColor(c.r, c.g, c.b) else r.text:SetTextColor(0.92, 0.90, 0.84) end
        r.x:SetScript("OnClick", function() src.remove(id); m.fill(); if onChange then onChange() end end)
        r:Show()
      else
        r.id = nil; r:Hide()
      end
    end
    local shown = math.min(#ids, NEVER_ROWS)
    if #ids > NEVER_ROWS then m.more:SetText(L["Scroll for more"]); m.more:Show() else m.more:Hide() end
    m.clear:SetEnabled(#ids > 0); m.clear:SetLook(#ids > 0)
    m:SetHeight(#ids == 0 and 110 or (30 + shown * 24 + 40))
    if missing and not retried and C_Timer and C_Timer.After then
      retried = true
      C_Timer.After(0.6, function() if m:IsShown() then m.fill() end end)
    end
  end
  m.clear:SetScript("OnClick", function()
    m:Hide()
    UI.Confirm(L[src.confirm], function() src.clear(); if onChange then onChange() end end, L["Remove all"])
  end)
  m.offset = 0
  m.fill()
  m:ClearAllPoints(); m:SetPoint("TOPRIGHT", owner, "BOTTOMRIGHT", 0, -2)
  m.owner = owner
  m.catcher:Show(); m:Show()
end

-- Layout (user 22.10.): a fixed list of groups on the left like Armory and Professions, the options
-- of one group on the right (one per row: switch, name, short description, controls on the right),
-- a search over all options. Opens on Interface.
local CHILD_W = 770          -- scroll child inside the right frame (body 814 - margins - scroll bar; ht6: +16)
local ROW_W = CHILD_W - 8
local function createQoLPanel(parent)
  local Q = FLT.QoL
  local panel = CreateFrame("Frame", nil, parent)
  UI.PlacePanel(panel, parent)
  UI.TitleBand(panel, { emblem = UI.ASSET_ROOT .. "emblem_qol", art = UI.ASSET_ROOT .. "qol_banner",
    title = L["Quality of Life"], subtitle = L["Small helpers for everyday play. Switch on what you like."], fadeRight = 200 })

  local nav, navTop = UI.SideNav(panel, -74, "emblem_qol", L["Quality of Life"]) -- ht8: the same side list in every tab
  local body = CreateFrame("Frame", nil, panel)
  body:SetPoint("TOPLEFT", 182, -74); body:SetPoint("BOTTOMRIGHT", -8, 4)

  -- header of the right side: icon, group name, one line about it, search (UI.PageHeader, shared with Dungeons / Hunter Pets)
  local onSearch -- below
  local head = UI.PageHeader(body, { placeholder = L["Search all settings..."], onSearch = function(t) if onSearch then onSearch(t) end end })
  local hIcon, hTitle, hSub = head.icon, head.title, head.sub
  -- ht7 (user 30.10.): no line under the group header any more

  local sf = FLT.SkinBlizz(CreateFrame("ScrollFrame", nil, body, "UIPanelScrollFrameTemplate"))
  sf:SetPoint("TOPLEFT", 10, -60); sf:SetPoint("BOTTOMRIGHT", -28, 8)
  local child = CreateFrame("Frame", nil, sf); child:SetSize(CHILD_W, 10); sf:SetScrollChild(child)
  UI.PlaceScrollBar(sf)
  local empty = FLT.NewFS(child, nil, "OVERLAY", "GameFontDisable"); empty:SetPoint("TOPLEFT", 12, -12); empty:SetText(L["No setting matches your search."]); empty:Hide()

  local refreshers, cats, current, search = {}, {}, nil, ""
  local layout, updateCounts -- below

  -- at: the option name of a row: the tooltip then sits in a fixed column of that row (user 01.11.; was right of the
  -- name, user 24.10.)
  local function hint(widget, title, text, at)
    local function show(self)
      if at then
        -- under the row, left-aligned with the name (user 03.11.: right of the text it covered the boxes and
        -- buttons; 01.11.: a fixed place, not next to the name where it jumped with every row)
        GameTooltip:SetOwner(self, "ANCHOR_NONE"); GameTooltip:ClearAllPoints()
        GameTooltip:SetPoint("TOPLEFT", at:GetParent() or at, "BOTTOMLEFT", 56, 2)
      else
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      end
      GameTooltip:AddLine(L[title], FLT.SkinC(1, 0.82, 0))
      if text then GameTooltip:AddLine(L[text], 1, 1, 1, true) end
      GameTooltip:Show()
    end
    if not at then
      widget:HookScript("OnEnter", show)
      widget:HookScript("OnLeave", function() GameTooltip:Hide() end)
      return
    end
    -- rows: only over the name and the description, not over the controls on the right (user 03.11.: the big
    -- tooltip covered the boxes); followed while the mouse is on the row only
    local row = at:GetParent() or at
    local shown = false
    local function over(self)
      local x = GetCursorPosition and GetCursorPosition()
      local sc = self:GetEffectiveScale() or 1
      local right = math.max(at:GetRight() or 0, (row.desc and row.desc:GetRight()) or 0) + 12
      local inside = not x or (x / sc) <= right
      if inside and not shown then shown = true; show(self)
      elseif not inside and shown then shown = false; GameTooltip:Hide() end
    end
    widget:HookScript("OnEnter", function(self) shown = false; over(self); self:SetScript("OnUpdate", over) end)
    widget:HookScript("OnLeave", function(self) self:SetScript("OnUpdate", nil); shown = false; GameTooltip:Hide() end)
  end

  -- nav = shorter name for the button on the left (when the full one touches the count)
  local function category(key, label, icon, desc, nav)
    local c = { key = key, label = label, icon = icon, desc = desc, nav = nav, groups = {}, checks = {} }
    c.title = UI.SectionTitle(child, L[label], 8, 0, -8); c.title:Hide(); c.title.divider:Hide() -- heading in search results
    cats[#cats + 1] = c
    return c
  end
  local function group(cat, title)
    local g = { cat = cat, rows = {} }
    g.title = UI.SectionTitle(child, L[title], 8, 0, -8); g.title:Hide(); g.title.divider:Hide()
    g.name = title
    cat.groups[#cat.groups + 1] = g
    return g
  end

  -- search text of a row: the English and the shown (translated) words
  local function findText(...)
    local t = {}
    for i = 1, select("#", ...) do local v = select(i, ...); if v then t[#t + 1] = v; if L[v] ~= v then t[#t + 1] = L[v] end end end
    return table.concat(t, " "):lower()
  end
  -- one option row: name and a short grey line below; tip = the longer text in the tooltip
  local function row(g, label, desc, tip, indent)
    local r = CreateFrame("Button", nil, child); r:SetSize(ROW_W, 34); r:Hide() -- 40 -> 34 (user 01.11.: tighter)
    local hl = r:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(FLT.SkinC(0.90, 0.66, 0.22, 0.06))
    r.indent = indent or 0
    r.label = FLT.NewFS(r, nil, "OVERLAY", "GameFontHighlight"); r.label:SetPoint("TOPLEFT", 60 + r.indent, -3); r.label:SetText(L[label]) -- 12 pt, rows closer (user 01.11.); room for the switch (was 42)
    r.desc = FLT.NewFS(r, nil, "OVERLAY", "GameFontDisableSmall"); r.desc:SetPoint("TOPLEFT", r.label, "BOTTOMLEFT", 0, -3)
    r.desc:SetJustifyH("LEFT"); r.desc:SetWordWrap(false); r.desc:SetText(desc and L[desc] or "")
    r.rightW = 0
    r.find = findText(label, desc, tip, g.name, g.cat.label)
    if tip then hint(r, label, tip, r.label) end
    r.name, r.tip = label, tip
    g.rows[#g.rows + 1] = r
    return r
  end
  -- controls sit on the right of the row, right to left
  local function place(r, w, gap)
    w:ClearAllPoints(); w:SetPoint("RIGHT", r, "RIGHT", -10 - r.rightW, 0)
    r.rightW = r.rightW + w:GetWidth() + (gap or 6)
  end
  local function button(r, text, w, tip, onClick)
    local b = UI.GoldButton(r, L[text], w, 22, nil, 11); place(r, b)
    b:SetScript("OnClick", onClick)
    if tip then hint(b, text, tip) end
    return b
  end
  local function dropButton(r, w)
    local b = UI.GoldButton(r, "", w or 128, 22, nil, 11); place(r, b)
    local arrow = b:CreateTexture(nil, "OVERLAY"); arrow:SetSize(12, 12); arrow:SetPoint("RIGHT", -8, 0)
    FLT.SetTex(arrow, UI.ASSET_ROOT .. "chevron"); arrow:SetTexCoord(0, 0.5, 0, 1)
    return b, arrow
  end

  -- switch in front of the row; get/set default to Q.Get/Q.Set(key); clicking the row toggles it too
  local function switch(r, g, key, get, set, onChange)
    local cb = FLT.SkinBlizz(CreateFrame("CheckButton", nil, r, "UICheckButtonTemplate"))
    cb:SetSize(24, 24); cb:SetPoint("LEFT", 8 + r.indent, 0)
    get = get or function() return Q.Get(key) and true or false end
    set = set or function(v) Q.Set(key, v) end
    cb:SetScript("OnClick", function(b) set(b:GetChecked() and true or false); if onChange then onChange() end; updateCounts() end)
    r:SetScript("OnClick", function() cb:Click() end)
    refreshers[#refreshers + 1] = function() cb:SetChecked(get()) end
    if r.tip then hint(cb, r.name, r.tip, r.label) end
    g.cat.checks[#g.cat.checks + 1] = get
    if key then
      if newTag(r, cb, key, 4) then g.cat.new = true end
      if PREVIEWS[key] then -- small preview button behind the name for features with a picture
        local pb = CreateFrame("Button", nil, r); pb:SetSize(18, 18); pb:SetPoint("LEFT", r.label, "RIGHT", 6, 0)
        local pic = pb:CreateTexture(nil, "ARTWORK"); pic:SetAllPoints(); FLT.SetTex(pic, "Interface\\Icons\\INV_Misc_Spyglass_02"); pic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        pb:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        pb:SetScript("OnClick", function() showPreview(key) end)
        hint(pb, N"Show preview", N"A picture of how it looks in the game.")
      end
    end
    r.cb = cb
    return cb
  end
  local function check(g, label, desc, tip, key, indent, get, set)
    local r = row(g, label, desc, tip, indent)
    switch(r, g, key, get, set)
    return r
  end
  -- two switches in one row (user 05.11.: the sub-options took too much room): a = left, b = right half;
  -- each { label, desc, tip, key }
  local function check2(g, a, b, indent)
    local r = check(g, a[1], a[2], a[3], a[4], indent)
    local half = math.floor((ROW_W - (indent or 0)) / 2)
    r.rightW = ROW_W - half - (indent or 0) -- the left text ends at the middle
    local h = CreateFrame("Button", nil, r); h:SetSize(ROW_W - half - (indent or 0), 34); h:SetPoint("TOPLEFT", half + (indent or 0), 0)
    h.indent = 0
    h.label = FLT.NewFS(h, nil, "OVERLAY", "GameFontHighlight"); h.label:SetPoint("TOPLEFT", 60, -3); h.label:SetText(L[b[1]])
    h.desc = FLT.NewFS(h, nil, "OVERLAY", "GameFontDisableSmall"); h.desc:SetPoint("TOPLEFT", h.label, "BOTTOMLEFT", 0, -3)
    h.desc:SetJustifyH("LEFT"); h.desc:SetWordWrap(false); h.desc:SetText(b[2] and L[b[2]] or ""); h.desc:SetWidth(h:GetWidth() - 76)
    h.name, h.tip = b[1], b[3]
    if b[3] then hint(h, b[1], b[3], h.label) end
    r.find = r.find .. " " .. findText(b[1], b[2], b[3])
    switch(h, g, b[4])
    return r
  end
  -- drop-down on the right; onKey: optional switch in front, the drop-down is greyed out while it is off
  local function choice(g, label, desc, tip, key, options, onKey, indent)
    local r = row(g, label, desc, tip, indent)
    local b, arrow = dropButton(r)
    local function show()
      local cur, text = Q.Get(key), options[1].label
      for _, o in ipairs(options) do if o.key == cur then text = o.label end end
      b:SetLabel(L[text])
      if onKey then
        local on = Q.Get(onKey) and true or false
        b:SetLook(on); b:SetEnabled(on); arrow:SetAlpha(on and 1 or 0.35)
      end
    end
    b:SetScript("OnClick", function(self)
      local shown = {} -- the option labels in the chosen language (the tables keep the English ones)
      for i, o in ipairs(options) do shown[i] = { key = o.key, label = L[o.label] } end
      openDropDown(self, shown, Q.Get(key), function(v) Q.Set(key, v); show() end)
    end)
    if tip then hint(b, label, tip) end
    if onKey then switch(r, g, onKey, nil, nil, show) else newTag(r, r.label, key) end
    refreshers[#refreshers + 1] = show
    return r
  end

  ---------------------------------------------------------------------------------------------------
  -- INTERFACE (first, the tab opens here; user 22.10.)
  local c = category("iface", N"Interface", "Interface\\Icons\\INV_Misc_Gear_01", N"Bags, windows, the minimap and other helpers for the game's interface.")
  local g = group(c, N"General")
  check(g, N"Free bag slots on the backpack", N"Shows the number of free slots on your backpack.", N"Counts all normal bags (quivers, ammo and profession bags are not counted).", "bagSlots")
  check(g, N"All ammo on the quiver", N"Your quiver or ammo pouch shows all arrows / bullets in your bags.", N"Instead of only what it holds; the game shows \"*\" for more than 999. On by default for hunters.", "quiverAmmo")
  check(g, N"Info bar", N"A band at the top of the screen with the information you choose.", N"Starts empty: right-click the band to add elements (gold, bags, durability, experience, location, clock, FPS, new trainer spells, Library Books, hearthstone, class reagent, guild, friends, mail, Value spec, the tabs of the OneForAll window) or to pin it. Pinned it stays open; else it folds up to a small tab 3 seconds after the mouse left it and opens while the mouse is on it. Click an element to open what belongs to it.", "infoBar")
  do -- size of the info bar (user 08.11.)
    local r = row(g, N"Size", N"How large the info bar is.", nil, 24)
    local val = FLT.NewFS(r, nil, "OVERLAY", "GameFontHighlight"); val:SetTextColor(FLT.TextC(1, 0.82, 0.2))
    val:SetWidth(40); val:SetJustifyH("RIGHT"); place(r, val, 10)
    local sl = UI.Slider(r, 130, 50, 150, 5, function(v)
      val:SetText(v .. " %")
      if Q.Get("infoBarScale") ~= v then Q.Set("infoBarScale", v) end
    end)
    place(r, sl, 10)
    hint(sl, N"Size", N"50 - 150 %. Mouse wheel or drag.")
    refreshers[#refreshers + 1] = function() local v = Q.Get("infoBarScale") or 100; sl:SetValue(v); val:SetText(v .. " %") end
  end
  do -- how long the bar stays open after the mouse left it (user 09.11.)
    local r = row(g, N"Stay open", N"Only when not pinned.", nil, 24)
    local val = FLT.NewFS(r, nil, "OVERLAY", "GameFontHighlight"); val:SetTextColor(FLT.TextC(1, 0.82, 0.2))
    val:SetWidth(40); val:SetJustifyH("RIGHT"); place(r, val, 10)
    local sl = UI.Slider(r, 130, 1, 10, 1, function(v)
      val:SetText(v .. " s")
      if Q.Get("infoBarDelay") ~= v then Q.Set("infoBarDelay", v) end
    end)
    place(r, sl, 10)
    hint(sl, N"Stay open", N"1 - 10 seconds after the mouse left the bar. Mouse wheel or drag.")
    refreshers[#refreshers + 1] = function() local v = Q.Get("infoBarDelay") or 3; sl:SetValue(v); val:SetText(v .. " s") end
  end
  do -- background colour, opacity and back to the defaults (6.2.2-beta43, user 09.11.)
    local r = row(g, N"Background colour", N"The colour of the bar's background; the gold line stays.", nil, 24)
    local sw = UI.GoldButton(r, "", 50, 22, nil, 11); place(r, sw)
    local chip = sw:CreateTexture(nil, "OVERLAY"); chip:SetSize(30, 12); chip:SetPoint("CENTER")
    local function show() local c = Q.Get("infoBarColor"); local d = FLT.InfoBar and FLT.InfoBar.DEFAULT_COLOR or { 0, 0, 0 }
      if type(c) ~= "table" then c = d end; chip:SetColorTexture(c[1], c[2], c[3], 1) end
    local function setColor(cr, cg, cb) Q.Set("infoBarColor", { cr, cg, cb }); show() end
    sw:SetScript("OnClick", function()
      local CPF = ColorPickerFrame
      if type(CPF) ~= "table" then return end
      local c = Q.Get("infoBarColor"); local d = FLT.InfoBar and FLT.InfoBar.DEFAULT_COLOR or { 0, 0, 0 }
      if type(c) ~= "table" then c = d end
      local old = { c[1], c[2], c[3] }
      local function picked() local cr, cg, cb = CPF:GetColorRGB(); setColor(cr, cg, cb) end
      local function cancel() setColor(old[1], old[2], old[3]) end
      if CPF.SetupColorPickerAndShow then
        CPF:SetupColorPickerAndShow({ r = old[1], g = old[2], b = old[3], hasOpacity = false, swatchFunc = picked, cancelFunc = cancel })
      else -- older clients
        CPF.hasOpacity = false; CPF.func = picked; CPF.cancelFunc = cancel; CPF.previousValues = old
        CPF:SetColorRGB(old[1], old[2], old[3]); CPF:Hide(); CPF:Show()
      end
    end)
    hint(sw, N"Background colour", N"Click to choose a colour.")
    refreshers[#refreshers + 1] = show
  end
  do
    local r = row(g, N"Opacity", N"How visible the whole bar is.", nil, 24)
    local val = FLT.NewFS(r, nil, "OVERLAY", "GameFontHighlight"); val:SetTextColor(FLT.TextC(1, 0.82, 0.2))
    val:SetWidth(40); val:SetJustifyH("RIGHT"); place(r, val, 10)
    local sl = UI.Slider(r, 130, 10, 100, 5, function(v)
      val:SetText(v .. " %")
      if Q.Get("infoBarAlpha") ~= v then Q.Set("infoBarAlpha", v) end
    end)
    place(r, sl, 10)
    hint(sl, N"Opacity", N"10 - 100 %. Mouse wheel or drag.")
    refreshers[#refreshers + 1] = function() local v = Q.Get("infoBarAlpha") or 100; sl:SetValue(v); val:SetText(v .. " %") end
  end
  do
    local r = row(g, N"Default look", N"Size, stay open, colour and opacity back to the default values.", nil, 24)
    button(r, N"Default", 70, N"Your elements stay as they are.", function()
      Q.Set("infoBarScale", nil); Q.Set("infoBarDelay", nil); Q.Set("infoBarColor", nil); Q.Set("infoBarAlpha", nil)
      for _, fn in ipairs(refreshers) do pcall(fn) end
    end)
  end
  do -- 6.2.5 (user 11.11.): the bar can be moved (Shift-drag) - this puts it back when it got lost somewhere
    local r = row(g, N"Bar position", N"Back to the top middle of the screen.", nil, 24)
    button(r, N"Reset", 60, N"For when the bar was moved somewhere you can't reach it.", function()
      if FLT.InfoBar and FLT.InfoBar.ResetPosition then FLT.InfoBar.ResetPosition() end
    end)
  end
  g = group(c, N"Windows")
  do
    local r = check(g, N"Move Blizzard windows", N"Drag windows like the character or quest log window anywhere.", N"Drag windows such as the character, merchant or quest log window with the left mouse button. Positions are remembered.", "moveWindows")
    button(r, N"Reset", 60, N"Moved Blizzard windows go back to their default place.", function() Q.ResetWindowPositions() end)
  end
  do
    local r = check(g, N"Resize Blizzard windows", N"Hold Ctrl and drag a window with the right mouse button to change its size.", N"Hold Ctrl and the right mouse button on a window like the character or quest log window and drag: right or down makes it larger, left or up smaller (50 - 150 %). The size shows at the cursor and is remembered.", "resizeWindows")
    button(r, N"Reset", 60, N"Resized Blizzard windows go back to their normal size.", function() Q.ResetWindowSizes() end)
  end
  -- the dungeon tracker (6.2.14): here with the other windows of OneForAll, not under World Map (user 23.11.)
  g = group(c, N"Dungeons & Raids")
  do
    local r = check(g, N"Dungeon tracker", N"A small window in dungeons and raids: time, bosses, XP, quests.", N"Shows the run: its time (with your best time for this dungeon), the mobs' XP, the gold you earned, the dungeon's quests in your log, the instances of this hour (the game allows 5 new ones per hour) and a portrait per boss - crossed off when dead, a green arrow when it drops an upgrade for you, a star for your wishlist, \"!\" when a quest in your log needs it. Left-click a boss: OneForAll on that boss, right-click: its loot. Drag to move, the corner to resize, /ofa tracker hides or shows it. Every run is kept in Dungeons & Raids > History, also with the tracker off.", "runTracker")
    -- test button: the same as /ofa tracker test (user 23.11.)
    button(r, N"Test", 60, N"Shows a test tracker with made-up values; each click shows the next of five dungeons, after the fifth it closes.", function() if FLT.RunTracker then FLT.RunTracker.Test() end end)
  end
  g = group(c, N"Minimap")
  do -- the logo colours as small logos to click (like the welcome setup; user 31.10.: no drop-down)
    local r = row(g, N"Logo color", N"The color of the OneForAll minimap button.", N"Also the button of the minimap button collector.")
    local marks = {}
    for i = #Q.LOGO_COLORS, 1, -1 do
      local o = Q.LOGO_COLORS[i]
      local b = CreateFrame("Button", nil, r); b:SetSize(26, 26); place(r, b, 8)
      local t = b:CreateTexture(nil, "ARTWORK"); t:SetAllPoints(); t:SetTexture(UI.ASSET_ROOT .. "logo_round_" .. (o.key == "bronze" and "teal" or o.key))
      if FLT.TintLogo then FLT.TintLogo(t, o.key) end
      local sel = b:CreateTexture(nil, "OVERLAY"); sel:SetPoint("TOPLEFT", -4, 4); sel:SetPoint("BOTTOMRIGHT", 4, -4)
      sel:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight"); sel:SetBlendMode("ADD")
      b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")
      b:SetScript("OnClick", function() Q.Set("logoColor", o.key); for k, m in pairs(marks) do m:SetShown(k == o.key) end end)
      b:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:SetText(L[o.label]); GameTooltip:Show() end)
      b:SetScript("OnLeave", function() GameTooltip:Hide() end)
      marks[o.key] = sel
    end
    refreshers[#refreshers + 1] = function() local cur = Q.Get("logoColor") for k, m in pairs(marks) do m:SetShown(k == cur) end end
  end
  do -- size of the logo button (6.2.11, user 17.11.): the minimap button and the collector button
    local r = row(g, N"Logo size", N"How large the OneForAll minimap button is.", N"Also the button of the minimap button collector.", 24)
    local val = FLT.NewFS(r, nil, "OVERLAY", "GameFontHighlight"); val:SetTextColor(FLT.TextC(1, 0.82, 0.2))
    val:SetWidth(40); val:SetJustifyH("RIGHT"); place(r, val, 10)
    local sl = UI.Slider(r, 130, 60, 150, 5, function(v)
      val:SetText(v .. " %")
      if Q.Get("logoSize") ~= v then Q.Set("logoSize", v) end
    end)
    place(r, sl, 10)
    hint(sl, N"Logo size", N"60 - 150 %. Mouse wheel or drag.")
    if newTag(r, r.label, "logoSize", -4) then g.cat.new = true end
    refreshers[#refreshers + 1] = function() local v = Q.Get("logoSize") or 100; sl:SetValue(v); val:SetText(v .. " %") end
  end
  -- "Collect minimap buttons" and "Hide the OneForAll button" exclude each other: the one that is on greys out
  -- the other (user 24.10.; the bar needs its button)
  local collectRow, hideRow
  local function paintMinimap()
    if not (collectRow and hideRow) then return end
    if Q.Get("mmCollect") and Q.Get("mmHide") then Q.Set("mmHide", false) end -- both on (beta1): the collector wins
    local function look(r, on) r.cb:SetEnabled(on); r:SetEnabled(on); r.label:SetAlpha(on and 1 or 0.45); r.desc:SetAlpha(on and 1 or 0.45) end
    look(hideRow, not Q.Get("mmCollect")); look(collectRow, not Q.Get("mmHide"))
  end
  do
    collectRow = row(g, N"Collect minimap buttons", N"Puts the minimap buttons of other addons into one bar.", N"The bar opens from a bigger OneForAll button that you can drag anywhere (it is not tied to the minimap). Right-click that button to open OneForAll. Switching this off puts all buttons back on the minimap. Not together with \"Hide the OneForAll button\".")
    switch(collectRow, g, "mmCollect", nil, nil, paintMinimap)
    button(collectRow, N"Reset", 60, N"Puts the minimap button collector back to its default place next to the minimap.", function() if FLT.ResetMinimapCollector then FLT.ResetMinimapCollector() end end)
  end
  choice(g, N"Bar opens", N"Where the bar opens next to the OneForAll button.", N"Automatic: towards the middle of the screen.", "mmDir", Q.MM_DIR_OPTIONS, nil, 24)
  hideRow = row(g, N"Hide the OneForAll button", N"No OneForAll button at the minimap.", N"Open OneForAll from the game's AddOns list at the minimap or with /ofa. Not together with \"Collect minimap buttons\": the bar needs its button.")
  switch(hideRow, g, "mmHide", nil, nil, paintMinimap)
  refreshers[#refreshers + 1] = paintMinimap
  -- beta44 (user 07.11.): no own switch any more - the game's Edit Mode moves the minimap (ours fought it)
  row(g, N"Move the minimap", N"Use the game's Edit Mode: Game Menu > Edit Mode, then drag the minimap.", N"OneForAll no longer moves the minimap itself: it fought with the Edit Mode, the minimap jumped back and could not be moved any more.")
  check(g, N"Square minimap", N"A square minimap with a thin black frame.", N"The round border and the compass are hidden; minimap buttons of other addons follow the square edge. Does nothing with ElvUI or when another addon already makes the minimap square.", "mmSquare")

  ---------------------------------------------------------------------------------------------------
  -- LOOT & VENDORS
  c = category("loot", N"Loot & Vendors", "Interface\\Icons\\INV_Misc_Bag_10", N"Looting, merchants, full bags and the loot feed.")
  g = group(c, N"Looting")
  check(g, N"Auto loot", N"The game's own Auto Loot setting.", N"Same as Options > Controls > Auto Loot.", nil, nil,
    function() return Q.GetCVarSwitch("autoLoot") end, function(v) Q.SetCVarSwitch("autoLoot", v) end)
  check(g, N"Quicker loot", N"Takes everything at once when the game auto loots.", N"Instead of item by item.", "quickLoot")
  g = group(c, N"Merchants")
  check(g, N"Auto repair", N"Repairs all gear at merchants that can repair.", nil, "autoRepair")
  check(g, N"Sell junk", N"Sells all grey items when you open a merchant.", N"Also the items on your own junk list: click an item in your bags with the junk list key (default Alt + right-click) to put it on the list or take it off. Hold Shift at the merchant to skip.", "sellJunk")
  -- the click for the junk list (6.2.12-beta3, user 18.11.: other addons use Alt + right-click too)
  choice(g, N"Junk list key", N"The click that puts an item in your bags on the junk list.", N"Choose another one when an addon of yours uses Alt + right-click on bag items. Clicking again takes the item off the list.", "junkKey", Q.JUNK_KEY_OPTIONS, nil, 24)
  do -- own junk list (5.7.3, GitHub #22)
    local r = row(g, N"Junk list", N"Items you added with the junk list key in your bags.", N"This character's list. Sell junk sells these items too.", 24)
    local b = dropButton(r, 110)
    local function show() local n = #Q.GetJunkItems(); b:SetLabel(n == 1 and L["1 item"] or string.format(L["%d items"], n)) end
    local JUNK = { get = Q.GetJunkItems, remove = Q.RemoveJunk, clear = Q.ClearJunk, title = N"Junk list",
      empty = N"Nothing on the list. Click an item in your bags with the junk list key (default Alt + right-click) to add it - Sell junk then sells it at merchants.",
      removeTip = N"Sell junk will not sell this item any more.", confirm = N"Remove all items from your junk list?" }
    b:SetScript("OnClick", function(self) showNeverList(self, show, JUNK) end)
    refreshers[#refreshers + 1] = show
    newTag(r, r.label, "junkList")
  end
  -- 6.2.13-beta19 (user 21.11.: on by default; off = only the button in the auction house is gone)
  check(g, N"Cheap Upgrade Scan button", N"A button in the auction house that scans it for Armory > Cheap Upgrades.", N"Reads the whole auction house (Blizzard's full scan, once every 15 minutes) and keeps the cheapest price of every Bind on Equip piece of gear, items with a random bonus (\"of the Eagle\") each with their own price - Auctionator has only one price per item. Off: no button, nothing is read; the Cheap Upgrades then use Auctionator's prices.", "ahScan")
  g = group(c, N"Full bags")
  check(g, N"Bags full helper", N"When loot does not fit, offers to destroy the cheapest item.", N"Suggests the cheapest item in your bags (value x stack), destroys it and loots with one click. Quest items, library books, recipes, set pieces, profession tools and items without value are never suggested. Items better than grey need a second click. /ofa cheapest shows it any time.", "bagsFull")
  check(g, N"Only grey and white items", N"The helper only suggests poor and common items.", nil, "bagsLowOnly", 24)
  do -- items the player put on the "never suggest" list
    local r = row(g, N"Never suggested", N"Items you blocked with the X button in the helper.", N"Open the list to allow single items again, or remove all.", 24)
    local b = dropButton(r, 110)
    local function show() local n = #Q.GetNeverItems(); b:SetLabel(n == 1 and L["1 item"] or string.format(L["%d items"], n)) end
    b:SetScript("OnClick", function(self) showNeverList(self, show) end)
    refreshers[#refreshers + 1] = show
  end
  g = group(c, N"Loot feed")
  check(g, N"Show loot feed", N"Looted items and money float up next to your character.", N"Like scrolling combat text.", "lootFeed")
  choice(g, N"Minimum quality", N"Items below this quality are not shown.", nil, "lootFeedQuality", Q.QUALITY_OPTIONS, nil, 24)
  check(g, N"Show money", N"Also shows looted money.", nil, "lootFeedMoney", 24)
  do
    local r = row(g, N"Position", N"Move the feed, show sample entries or put it back.", nil, 24)
    button(r, N"Reset", 70, N"Puts the loot feed back to its default place right of your character.", function() Q.ResetLootFeed() end)
    button(r, N"Test", 70, N"Shows a few sample entries.", function() Q.TestLootFeed() end)
    local move = button(r, N"Move", 70, N"Shows the loot feed area. Drag it where you want it, then click Lock.", nil)
    local function show() move:SetLabel(Q.IsLootFeedUnlocked() and L["Lock"] or L["Move"]); move:SetActive(Q.IsLootFeedUnlocked()) end
    move:SetScript("OnClick", function() Q.SetLootFeedUnlocked(not Q.IsLootFeedUnlocked()); show() end)
    refreshers[#refreshers + 1] = show
  end
  g = group(c, N"Gathering")
  local r = check(g, N"Sparkle on herbs & ore", N"The herb or ore vein near you sparkles.", N"Only for professions you have. Uses the game's soft targeting (interaction target): one object at a time, the nearest one around you. Vendors and other NPCs get no sparkle. Works only close up (about 15 yards) - a limit of the game. Switching it on turns on the game's \"Enable Interact Key\" and its interact icons on objects - both are needed to find the nodes; if you switch them off later, nothing sparkles. Whether icons show above nodes and NPCs is up to you (game setting \"Interact Key Icons\"). Everything goes back when you switch this off. Not with a controller. Idea and sparkle from the addon Lueur (MIT).", "nodeGlow")
  do -- red warning sign behind the name: it changes soft targeting (user 25.10.)
    local w = CreateFrame("Frame", nil, r); w:SetSize(22, 22); w:SetPoint("LEFT", r.label, "RIGHT", 32, 0) -- right of the preview spyglass
    local x = w:CreateTexture(nil, "ARTWORK"); x:SetAllPoints(); FLT.SetTex(x, UI.ASSET_ROOT .. "icon_warning") -- as in the gear planner
    w:EnableMouse(true) -- own tooltip, not the row's
    w:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(L["Care!"], 1, 0.25, 0.25)
      GameTooltip:AddLine(L["This option changes soft-targeting, read hint text!"], 1, 1, 1, true)
      GameTooltip:Show()
    end)
    w:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end

  -- QUESTS
  c = category("quests", N"Quests", "Interface\\Icons\\INV_Misc_Note_01", N"Quest givers and quest items in the world.")
  g = group(c, N"Quest givers")
  check(g, N"Accept quests automatically", N"Accepts quests when you talk to a quest giver. Hold Shift to do it by hand.", nil, "autoAccept")
  check(g, N"Turn in quests automatically", N"Turns in finished quests. Hold Shift to do it by hand.", N"If you can choose between rewards, you still pick yourself.", "autoTurnIn")
  g = group(c, N"Experience")
  check(g, N"Quest XP on the experience bar", N"Shows the XP of your finished quests on the experience bar.", N"Marks on the experience bar how much XP your finished quests give when you turn them in. The amount is also shown in the bar's tooltip.", "questXP")
  check(g, N"Only tracked quests", N"Counts only the finished quests you track.", N"Quests you do not track (e.g. ones for later or in a dungeon) are left out.", "questXPTracked", 24)
  g = group(c, N"In the world")
  check(g, N"Best sell price on rewards", N"A gold coin on the quest reward choice that sells for the most.", N"In the quest log and when you turn in a quest with two or more rewards to choose from: the one with the highest vendor price (times the count) gets a gold coin at its top right. The green upgrade arrow stays at the top left, so an item can have both.", "questSellCoin")
  check(g, N"Quest loot sparkles", N"Quest items in the world sparkle again.", N"The game's loot glow. Quest givers and some other NPCs glow too - that comes with this game setting. Changes only this one setting - your outline settings stay as they are. After switching it off, restart the game.", "questSparkles")
  check(g, N"Quest marks on nameplates", N"A sword or a bag with your progress on mobs you need for a quest.", N"Sword: you must kill it for a quest. Bag: it drops a quest item. With the progress (3/10); nothing once that part is done. Uses the quest lines the game shows in the mob's tooltip. Not inside dungeons yet.", "questMarks")
  if FLT.QuestMarks then -- mark position: drag the mark anywhere around a sample nameplate (6.2.11, user 17.11.: no drop-down, "360 grad um
    -- die nameplate", also below it). The sample is fixed; the place is saved like QuestMarks.lua reads it (QM.At).
    local QM = FLT.QuestMarks
    local r = row(g, N"Mark position", N"Drag the mark to where you want it on the nameplate.", nil, 24)
    -- the sample nameplate is the user's own picture (17.11.: "würde dir eine grafik helfen?"; Assets/nameplate_sample.tga,
    -- tools/art/nameplate_sample.py: 512x128, bar fill from x 12.4, level box right edge 504.9, bar middle y 80.4, bar 19.6
    -- high). The mark is as big as QuestMarks.lua makes it on a plate (bar 10 high -> 20), x1.25 = twice the bar height.
    -- Scaled by the gold frame (45.8 px high in the picture): in the game the frame is 16 high around a bar of 10, so the
    -- bar counts as 45.8 x 10/16 = 28.6 px - the picture's rim is thicker than the game's (beta12 was too big, user 17.11.)
    local U = 22
    local D = U / (2 * 28.6) -- screen units per picture pixel
    local bx0, bx1, byc, bh = 12.4 * D, 504.9 * D, 81.6 * D, 28.6 * D
    local MX, MY = QM.LIMIT_X * U, QM.LIMIT_Y * U
    local AW, AH = MX * 2 + (bx1 - bx0), MY * 2 + bh
    r:SetHeight(40 + AH)
    local area = CreateFrame("Frame", nil, r); area:SetSize(AW, AH); area:SetPoint("TOPLEFT", 60 + r.indent, -38)
    UI.Card(area, area, 4, { 0.36, 0.33, 0.28, 0.85 }, { 0.17, 0.17, 0.185, 0.97 }, "BACKGROUND", 0) -- anthracite: the black plate shows on it (user 17.11.)
    local pic = area:CreateTexture(nil, "ARTWORK"); FLT.SetTex(pic, UI.ASSET_ROOT .. "nameplate_sample")
    pic:SetSize(512 * D, 128 * D); pic:SetPoint("TOPLEFT", MX - bx0, -(MY + bh / 2 - byc))
    local mark = CreateFrame("Frame", nil, area); mark:SetSize(U, U); mark:SetFrameLevel(area:GetFrameLevel() + 5)
    mark.icon = mark:CreateTexture(nil, "OVERLAY"); mark.icon:SetAllPoints()
    if mark.icon.SetAtlas and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("Crosshair_Attack_32") then mark.icon:SetAtlas("Crosshair_Attack_32")
    else FLT.SetTex(mark.icon, "Interface\\Cursor\\Attack") end
    mark.text = FLT.NewFS(mark, nil, "OVERLAY", "GameFontHighlightSmall"); mark.text:SetText("3/8")
    mark:EnableMouse(true); mark:RegisterForDrag("LeftButton")
    -- sample coordinates (from the area's top left, y down) <-> QM.At(); spans as in QuestMarks.lua: L from the bar's left
    -- edge, C across bar + level box, R from the level box's right edge
    local x0, x1, yc = MX, MX + (bx1 - bx0), MY + bh / 2 -- bar left, level box right, bar middle (as QuestMarks.lua)
    local function toXY(a)
      local x = a.z == "L" and x0 + a.x * U or a.z == "R" and x1 + a.x * U or x0 + a.x * (x1 - x0)
      return x, yc - a.y * U
    end
    local function fromXY(x, y)
      local a = { y = (yc - y) / U }
      if x < x0 then a.z, a.x = "L", (x - x0) / U elseif x > x1 then a.z, a.x = "R", (x - x1) / U else a.z, a.x = "C", (x - x0) / (x1 - x0) end
      return a
    end
    local function setMark(x, y, left)
      mark:ClearAllPoints(); mark:SetPoint("CENTER", area, "TOPLEFT", x, -y)
      mark.text:ClearAllPoints()
      if left then mark.text:SetPoint("RIGHT", mark, "LEFT", -1, 0) else mark.text:SetPoint("LEFT", mark, "RIGHT", 2, 0) end
    end
    local function show() local a = QM.At(); local x, y = toXY(a); setMark(x, y, a.z == "L") end
    local function cursor() -- clamped to the area (half a mark inside the edge)
      local s = area:GetEffectiveScale()
      local cx, cy = GetCursorPosition()
      local x = math.max(U / 2, math.min(AW - U / 2, cx / s - area:GetLeft()))
      local y = math.max(U / 2, math.min(AH - U / 2, area:GetTop() - cy / s))
      return x, y
    end
    -- following the mouse only while dragging (lean)
    mark:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", function() local x, y = cursor(); setMark(x, y, x < x0) end) end)
    mark:SetScript("OnDragStop", function(self)
      self:SetScript("OnUpdate", nil)
      local a = fromXY(cursor())
      a.x, a.y = math.floor(a.x * 100 + 0.5) / 100, math.floor(a.y * 100 + 0.5) / 100
      Q.Set("questMarkAt", a); show()
    end)
    hint(mark, N"Mark position", N"Drag the mark to where you want it on the nameplate.")
    local reset = button(r, N"Reset", 90, nil, function() Q.Set("questMarkPos", nil); Q.Set("questMarkAt", nil); show() end)
    reset:ClearAllPoints(); reset:SetPoint("TOPRIGHT", r, "TOPRIGHT", -10, -6)
    refreshers[#refreshers + 1] = show
  end

  -- TOOLTIPS
  c = category("tips", N"Tooltips", "Interface\\Icons\\INV_Misc_Spyglass_03", N"Extra lines in item and unit tooltips.")
  g = group(c, N"Items")
  check(g, N"Boss drops", N"Shows which dungeon boss drops an item.", nil, "bossDrops")
  check(g, N"Gear Value", N"Upgrade or downgrade in % against what you wear.", N"On gear you can use: how much better (green) or worse (red) it is than what you wear, weighted for your talent spec like Armory > Gear Planner. Also a green arrow on upgrades in your bags, the loot roll window and quest rewards, and a gold star for wishlist items (/ofa rolltest shows an example).", "gearValue")
  choice(g, N"Gear Value shows", N"Which change in % the tooltip line shows.", N"Whole gear: how much the item changes all the gear you wear. Item against item: against the item it replaces (bigger numbers). Both: \"65% (overall 6%)\". The arrows stay the same.", "gvMode", Q.GV_MODE_OPTIONS, nil, 24)
  check(g, N"Arrow color by armor type", N"Yellow arrow for upgrades in a lighter armor type.", N"The green arrow stays for upgrades in the best armor type of your class. Upgrades in a lighter type get a yellow arrow: warriors and paladins wear plate from level 40 (mail before), hunters and shamans mail from 40 (leather before), rogues and druids leather. Cloaks, jewelry, shields and weapons are not affected. Needs \"Gear Value\".", "arrowTiers", 24)
  check(g, N"Short green stats", N"Long \"Equip:\" lines as short stats, e.g. \"+1% Hit\".", N"\"Equip: Improves your chance to hit by 1%.\" becomes \"+1% Hit\", spell damage and healing get a line each, and \"Enchanted:\" lines put the number first. Lines it does not know stay as they are. Hover the item again after switching.", "shortStats")
  check(g, N"Hide \"appearance not collected\"", N"No more blue \"You haven't collected this appearance\" line on items.", N"Also hides \"You've collected this appearance, but not from this item\". Hover the item again after switching.", "hideAppearance")
  -- off until the user decides (CLAUDE.md "Fixed rules"), 6.2.6-beta33
  check(g, N"Disenchant value", N"What an item is worth disenchanted, at auction house prices.", N"Needs Auctionator (the prices come from it); without it the line stays away. Green, blue and purple weapons and armor: the dust, essences and shards it usually gives, from the known disenchant chances by quality and item level - an estimate.", "deValue")
  check(g, N"Recipes: who knows it", N"Whether you, an alt or a guild member knows a recipe.", nil, "recipeTip")
  check(g, N"Disable automatic compare tooltip", N"Hold Shift to see your equipped item next to the tooltip.", N"Item tooltips no longer show your equipped item next to them automatically.", nil, nil,
    function() return Q.GetCompareShift() end, function(v) Q.SetCompareShift(v) end)
  -- 6.2.7-beta15 (user 13.11.): off until the user decides the defaults (CLAUDE.md "Fixed rules")
  g = group(c, N"Tooltip position")
  choice(g, N"Tooltip at the mouse", N"Tooltips that normally appear at the bottom right show at your mouse.", N"Choose on which side of the mouse it opens. Tooltips that addons or windows place themselves stay where they are.", "tipMousePos", Q.TIP_ANCHORS, "tipMouse")
  check2(g, { N"Not in dungeons and raids", N"There the tooltip stays at its usual place.", nil, "tipMouseNoDungeon" },
    { N"Not in battlegrounds", N"There the tooltip stays at its usual place.", nil, "tipMouseNoPvP" }, 24)
  g = group(c, N"Units")
  check(g, N"Target of players", N"Shows who a player or NPC under your mouse is targeting.", N"\"You\" when it is you.", "unitTarget")
  check(g, N"Quests on NPCs", N"Quests you can take (!) or turn in (?) at the NPC under your mouse.", N"The same quests as the quest icons on the world map: for your level, side, race and class, pre-quests done. Off while Questie is loaded (it shows its own).", "npcQuestTip")

  -- SOCIAL
  c = category("social", N"Social", "Interface\\Icons\\INV_Letter_15", N"Group invites, duels and recipe sharing.")
  g = group(c, N"Groups")
  choice(g, N"Group invites from", N"Accepts group invites from the players you choose.", N"Off: OneForAll does nothing with invites.", "inviteMode", Q.WHO_OPTIONS, "inviteOn")
  choice(g, N"Keyword invites from", N"Invites players who whisper you the keyword.", N"Off: OneForAll does nothing with whispers.", "keywordMode", Q.WHO_OPTIONS, "keywordOn")
  do
    local r = row(g, N"Keyword", N"The word players whisper you to get an invite.", nil, 24)
    local eb = FLT.SkinBlizz(CreateFrame("EditBox", nil, r, "InputBoxTemplate"))
    eb:SetSize(122, 20); eb:SetAutoFocus(false); eb:SetMaxLetters(24); place(r, eb)
    eb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    eb:SetScript("OnEscapePressed", function(self) self:SetText(Q.Get("keyword") or ""); self:ClearFocus() end)
    eb:SetScript("OnEditFocusLost", function(self) Q.Set("keyword", self:GetText()) end)
    r:SetScript("OnClick", function() eb:SetFocus() end)
    refreshers[#refreshers + 1] = function() if not eb:HasFocus() then eb:SetText(Q.Get("keyword") or "") end end
  end
  g = group(c, N"Duels")
  choice(g, N"Allow duels from", N"Duel requests from everyone else are declined.", N"Off: OneForAll does nothing with duels.", "duelMode", Q.DUEL_OPTIONS, "duelOn")
  if not FLT.RecipeChannelOff then -- 6.1.4: the channel search is off
  g = group(c, N"Recipes")
  check(g, N"Share recipes with other OneForAll users", N"Finds OneForAll users outside your guild who know a recipe.",
    N"The Search button of a recipe in Professions > All recipes asks the other OneForAll users who know it (blue marker); only a few of them answer, so it stays fast with many players. When off, you are not asked and do not search either. Guild members are always shared. Moved here from Settings in 6.1.0.",
    nil, nil, function() return FLT.IsRecipeShareEnabled and FLT.IsRecipeShareEnabled() end,
    function(v) if FLT.SetRecipeShareEnabled then FLT.SetRecipeShareEnabled(v) end end)
  end

  -- GUILD (own category, user 09.11.: "eventuell kommt ja noch mehr dazu")
  c = category("guild", N"Guild", "Interface\\Icons\\INV_Shirt_GuildTabard_01", N"What you share with your guild members who also use OneForAll.")
  g = group(c, N"World Map")
  check(g, N"Guild members on the map", N"Guild members with OneForAll as dots in their class colour - and you on their map.", N"Only guild members who also use OneForAll and have this switched on. Switched off, your position is not sent any more and you see nobody else either. Inside a dungeon or raid only which one is sent: a green guild flag on its entrance, the names in its tooltip. Members in your group are left out, the game shows them already. Also on the continent map, a little smaller. Guild members who share their position with the addon OpenMap are shown too.", "guildMap")
  g = group(c, N"Guild Games")
  local ggRow = check(g, N"Play with Guildies", N"Small games with your guild members in their own window: Death Roll, High / Low, Tic Tac Toe.", N"Only guild members who also have this switched on can invite you or be invited. Open the window with /ofa play, the info bar element \"Guild Games\" or a key binding. Invites never pop up in combat or in a dungeon, raid or battleground. Gold stakes are only written down - you trade the gold yourselves.", "guildGames")
  do -- 6.2.12-beta4 (user 18.11.): a button below the switch that opens the games window, and where else it opens
    local r = row(g, N"Games window", N"Also with the info bar element \"Guild Games\", /ofa play or your own key in the game's Options > Keybindings (OneForAll).", nil, 24)
    r:SetHeight(46); r.desc:SetWordWrap(true); r.desc:SetWidth(ROW_W - 84 - 150)
    local b = button(r, N"Start", 90, nil, function() if FLT.GuildGames then FLT.GuildGames.Open() end end)
    -- (SetLook too: SetEnabled alone left it looking active - tester Deaders 19.11.: "not greyed out", beta25)
    local function upd() local on = Q.Get("guildGames") and true or false; b:SetEnabled(on); if b.SetLook then b:SetLook(on) end end
    refreshers[#refreshers + 1] = upd
    ggRow.cb:HookScript("OnClick", upd) -- greyed out while the switch is off
  end

  -- WORLD MAP
  c = category("map", N"World Map", "Interface\\Icons\\INV_Misc_Map_01", N"Icons on the world map.")
  g = group(c, N"Map Landmarks")
  check(g, N"Map Landmarks", N"Dungeon entrances, flight masters, ships, the tram and Library Books on the map.", N"Your faction and neutral ones. Click an entrance to open that dungeon in OneForAll. Zeppelins, ships, the tram and flight masters show where they go.", "mapLandmarks")
  check2(g, { N"Dungeon & raid entrances", N"Click to open the dungeon in OneForAll.", nil, "lmDungeons" },
    { N"Flight masters", N"Shows where they fly to.", nil, "lmFlight" }, 24)
  check2(g, { N"Zeppelins, ships & tram", N"Shows where they go.", nil, "lmTransport" },
    { N"Zone transitions", N"A signpost where a road leads into the next zone.", N"The tooltip names the other zone; a click shows it on the map. Places from the addon Carbonite (GPL).", "lmTransitions" }, 24)
  check2(g, { N"Library Books", N"A book icon where each Library Book you still need lies.", N"Books in your bags or bank, turned in or marked by you are not shown. Click a book to see it in the Library Books tab.", "mapBooks" },
    { N"Skyborne: Ley Lines & Convergences", N"For Skyborne: where to charge your racial for an hour.", N"High Order (Alliance) see the Ley Lines for Read Leyline (Attuned: 100% regeneration for 1 hour), Windshapers (Horde) the Elemental Convergences for Skysight (Charged: 30% movement speed for 1 hour). On by default for Skyborne; other races see the spots of their faction when they switch it on. Locations from the addon \"Skyborne Leyline & Convergence Marker\" by tr0tsky.", "lmSkyborne" }, 24)
  g = group(c, N"Quests")
  check(g, N"Quest icons", N"A yellow ! at quest givers with quests for your level, a ? where you turn in finished quests.", N"Only quests you can take now: your level (no grey ones, none too high), your side and class, pre-quests done. Hover an icon for the quests and their levels. Hidden while Questie is loaded, it shows its own. Quest data from QuestieDB (GPL); the new Forever zones are not in it yet.", "mapQuests")
  -- 6.1.9 (user 07.11.: our ? lay over the game's own one): the ! and the ? each on their own
  check2(g, { N"Quest givers (!)", N"A yellow ! where you can take a quest.", nil, "mapQuestGivers" },
    { N"Turn-ins (?)", N"A yellow ? where you turn in a finished quest.", N"Switch it off when the game's own ? already shows on the map.", "mapQuestTurnins" }, 24)
  check(g, N"Also on the continent map", N"The quest icons also when you zoom out of a zone.", N"All zones of the continent at once, a little smaller, without the routes of walking quest givers. Needs \"Quest icons\".", "mapQuestsContinent", 24)
  check(g, N"Low level quests (grey)", N"Also a grey ! for quests that are grey for you.", N"They give little or no experience. Needs \"Quest icons\".", "mapQuestsGrey", 24)
  check(g, N"Hide walking routes", N"No yellow lines where quest givers walk around.", N"The icon of a walking quest giver stays; it shows where the giver is in the quest data. Needs \"Quest icons\".", "mapQuestNoRoutes", 24)
  g = group(c, N"Map button")
  check(g, N"OneForAll button on the map", N"A logo at the top left of the world map with all these switches.", N"Click it for a quick list: Map Landmarks and its parts, Remove Fog and the dungeon map. It sits below other addons' buttons there (RareScanner ...).", "mapButton")
  g = group(c, N"Exploration")
  do -- with a slider for how visible the unexplored parts are (user 01.11.)
    local r = check(g, N"Remove Fog", N"Shows the parts of a zone you have not explored yet.", N"The world map normally hides the areas you have not visited. With this the whole zone map is shown. The slider sets how visible the unexplored parts are (0 % hidden, 100 % fully shown).", "mapFog")
    local val = FLT.NewFS(r, nil, "OVERLAY", "GameFontHighlight"); val:SetTextColor(FLT.TextC(1, 0.82, 0.2))
    val:SetWidth(40); val:SetJustifyH("RIGHT"); place(r, val)
    local sl = UI.Slider(r, 130, 0, 100, 5, function(v)
      val:SetText(v .. " %")
      if Q.Get("mapFogAlpha") ~= v then Q.Set("mapFogAlpha", v) end
    end)
    place(r, sl, 10)
    hint(sl, N"Unexplored areas", N"How visible the parts you have not explored yet are: 0 % hidden, 100 % fully shown. Mouse wheel or drag.")
    local function show()
      local v = Q.Get("mapFogAlpha") or 100; sl:SetValue(v); val:SetText(v .. " %")
      local on = Q.Get("mapFog") and true or false; sl:SetAlpha(on and 1 or 0.4); sl:EnableMouse(on); sl:EnableMouseWheel(on)
    end
    refreshers[#refreshers + 1] = show
    r.cb:HookScript("OnClick", show) -- greyed out while Remove Fog is off
  end
  check(g, N"Zone level range", N"The zone's level range at the top right of the world map and when you hover a zone.", N"At the top right of a zone map, and behind the zone name when you hover a zone on the continent map. Gold: your level, red: still too low, grey: you are above it.", "mapZoneLevel")
  g = group(c, N"Dungeons")
  -- moved from Settings (5.6.8, user 22.10.); on by default: only an explicit "off" turns it off
  check(g, N"Dungeon map on M", N"Inside a dungeon, M opens OneForAll's dungeon map.", N"Inside a dungeon that has a map, the world map key (M) opens OneForAll's dungeon map instead of the world map. Press it again to close. Takes effect outside combat.", nil, nil,
    function() return type(OneForAllDB) == "table" and OneForAllDB.dungeonMapKey ~= false end,
    function(v) if type(OneForAllDB) == "table" then OneForAllDB.dungeonMapKey = v and true or false end; if FLT.ApplyDungeonMapKey then FLT.ApplyDungeonMapKey() end end)

  -- UNIT FRAMES
  c = category("frames", N"Unit Frames", "Interface\\Icons\\INV_Misc_Head_Human_01", N"Colors and bars of the unit and raid frames.")
  g = group(c, N"Player, target & party")
  check(g, N"Class colors: player, target & party", N"Health bars of players in their class color.", N"NPCs keep their normal color.", "classColors")
  check(g, N"Brighter colors", N"Plain bright bars for the class colors.", N"The game's health bar texture is dark; with this the class colors use a plain bright bar.", "classBright", 24)
  g = group(c, N"Raid frames")
  check(g, N"Class colors: raid frames", N"The game's own setting.", N"Same as Interface > Display Class Colors.", nil, nil,
    function() return Q.GetCVarSwitch("raidClassColor") end, function(v) Q.SetCVarSwitch("raidClassColor", v) end)
  check(g, N"Power bars: raid frames", N"Mana, rage and energy bars in the raid frames.", N"A game setting.", nil, nil,
    function() return Q.GetCVarSwitch("raidPowerBars") end, function(v) Q.SetCVarSwitch("raidPowerBars", v) end)

  -- SPELLS
  c = category("spells", N"Spells", "Interface\\Icons\\INV_Misc_Book_11", N"Your action bars and the spellbook.")
  g = group(c, N"Action bars")
  do
    local LR = FLT.LowRank
    local r = check(g, N"Check low spell ranks", N"Offers the highest rank for spells on your bars.", N"Looks for spells on your action bars that use a lower rank than one you already know, and offers to put the highest rank there. After a trainer visit it waits until you close the trainer window. Macros are not checked.", "lowRank")
    button(r, N"Check now", 90, N"Checks your action bars right away.", function() if LR then LR.Check("button") end end)
    r = row(g, N"Kept ranks", N"Ranks you keep on purpose (Keep in the popup).", N"Click one to have it reported again.", 24)
    local b = dropButton(r, 110)
    local function show() local n = LR and #LR.GetKept() or 0; b:SetLabel(n == 1 and L["1 spell"] or string.format(L["%d spells"], n)) end
    b:SetScript("OnClick", function(self)
      if not LR then return end
      local opts = LR.GetKept()
      for _, e in ipairs(opts) do e.remove = true end -- a click removes it: red cross
      if #opts == 0 then opts = { { key = "__none", label = "|cff9d9d9d" .. L["Nothing kept"] .. "|r" } }
      else opts[#opts + 1] = { key = "__all", label = FLT.SkinHex("ffd35a") .. L["Remove all"] .. "|r" } end
      openDropDown(self, opts, nil, function(k)
        if k == "__all" then LR.ClearKept() elseif k ~= "__none" then LR.RemoveKept(k) end
        show()
      end, 260)
    end)
    refreshers[#refreshers + 1] = show
  end
  g = group(c, N"Spellbook")
  check(g, N"Trainer button in the spellbook", N"A book button in the spellbook (P) opens the trainer window.", N"Shows the spells and ranks your class trainer teaches that you do not know yet, next to the spellbook.", "spellbookTrainer",
    nil, nil, function(v) Q.Set("spellbookTrainer", v); local psf = rawget(_G, "PlayerSpellsFrame"); local b = type(psf) == "table" and psf.ofaTrainerButton; if b then b:SetShown(v) end end)
  -- POPUPS & ALERTS (moved from Settings, 5.6.8, user 22.10.)
  c = category("alerts", N"Popups & Alerts", "Interface\\Icons\\INV_Misc_Bell_01", N"Popups that come up on their own while you play.")
  g = group(c, N"Buff reminder")
  check(g, N"Buff reminder", N"A small popup when one of your buffs runs out.", N"Add your own buffs below (e.g. Demon Skin) with the time in seconds. When the buff has less time left, or has run out, a small popup says so; click its icon to cast the buff again (not in combat - there it only shows). It goes away by itself once you renew the buff. Drag the popup to move it.", "buffReminder")
  check2(g, { N"Sleep in cities", N"No buff reminder in the capitals.", N"Stormwind, Ironforge, Darnassus, Orgrimmar, Thunder Bluff and Undercity. Buffs that ran out there are shown once you leave.", "buffSleepCities" },
    { N"Show icon only", N"Only the icon with the time left on it.", N"The time bar under it is as wide as the icon. Several icons sit next to each other.", "buffIconOnly" }, 24)
  check2(g, { N"Flash cards", N"The cards glow so you notice them.", N"Only while a card is shown.", "buffFlash" },
    { N"Snooze button (Zz)", N"On each card: quiet until you cast it again.", N"Right-click on a card snoozes it too.", "buffSnoozeBtn" }, 24)
  do -- size slider and Test (user 01.11.): Test shows the reminder for 10 seconds to set its size and drag it
    local r = row(g, N"Size", N"How large the reminder is. Test shows it for 10 seconds.", nil, 24)
    button(r, N"Test", 50, N"Shows the reminder for 10 seconds, so you can see its size and drag it where you want it.", function() Q.BuffTest() end)
    local val = FLT.NewFS(r, nil, "OVERLAY", "GameFontHighlight"); val:SetTextColor(FLT.TextC(1, 0.82, 0.2))
    val:SetWidth(40); val:SetJustifyH("RIGHT"); place(r, val, 10)
    local sl = UI.Slider(r, 130, 50, 150, 5, function(v)
      val:SetText(v .. " %")
      if Q.Get("buffScale") ~= v then Q.Set("buffScale", v) end
    end)
    place(r, sl, 10)
    hint(sl, N"Size", N"50 - 150 %. Mouse wheel or drag.")
    refreshers[#refreshers + 1] = function() local v = Q.Get("buffScale") or 100; sl:SetValue(v); val:SetText(v .. " %") end
  end
  do
    local r = row(g, N"Add a buff", N"Spell name and seconds left when you want the reminder.", N"Any buff name works, also without a suggestion - the list only helps. The name as in your spellbook, e.g. \"Demon Skin\". Flasks and elixirs: the name of their buff (e.g. \"Supreme Power\"). Weapon oils, sharpening stones and poisons: type their name (\"sh\" shows the sharpening stones) and pick \"(main hand)\", or add \"(off hand)\" for the other weapon; a click on the reminder uses it on that weapon when it is in your bags. Seconds: 5 - 3600.", 24)
    local list -- the list button, below
    local nameBox, secBox
    local function add()
      local n = Q.AddBuffReminder(nameBox:GetText(), secBox:GetText())
      if n then nameBox:SetText(""); nameBox:ClearFocus(); secBox:ClearFocus(); if list then list.show() end end
    end
    button(r, N"Add", 50, nil, add)
    secBox = FLT.SkinBlizz(CreateFrame("EditBox", nil, r, "InputBoxTemplate"))
    -- "sec" behind the box (user 03.11.: not clear that 30 are seconds)
    local secLabel = FLT.NewFS(r, nil, "OVERLAY", "GameFontDisableSmall"); secLabel:SetText(L["sec"])
    secLabel:SetPoint("RIGHT", r, "RIGHT", -10 - r.rightW, 0); r.rightW = r.rightW + (secLabel:GetStringWidth() or 18) + 6
    secBox:SetSize(40, 20); secBox:SetAutoFocus(false); secBox:SetMaxLetters(4); secBox:SetNumeric(true); secBox:SetText("30"); place(r, secBox, 10)
    nameBox = FLT.SkinBlizz(CreateFrame("EditBox", nil, r, "InputBoxTemplate"))
    nameBox:SetSize(150, 20); nameBox:SetAutoFocus(false); nameBox:SetMaxLetters(40); place(r, nameBox, 12)
    for _, eb in ipairs({ nameBox, secBox }) do
      eb:SetScript("OnEnterPressed", add)
      eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    end
    -- suggestions while typing (and the class's usual buffs on an empty box): click one to take it
    local function suggest(self)
      UI.CloseDropDown()
      if not self:HasFocus() then return end
      local opts = {}
      for _, e in ipairs(Q.BuffSuggestions(self:GetText())) do
        opts[#opts + 1] = { key = e.label or e.name, label = "|T" .. Q.BuffIcon(e.name) .. ":14:14|t " .. (e.label or e.name) .. (e.active and "  |cff9d9d9d(" .. L["active now"] .. ")|r" or (e.preset and "  |cff9d9d9d(" .. L["class buff"] .. ")|r" or (e.notInBags and "  |cff9d9d9d(" .. L["none in bags"] .. ")|r" or ""))) }
      end
      -- no suggestion: say that any name works (user 03.11.: players thought they could only pick from the list)
      if #opts == 0 and self:GetText() ~= "" then
        opts[1] = { key = "__any", label = "|cff9d9d9d" .. L["No suggestion - any buff name works: press Enter or Add"] .. "|r" }
      end
      if #opts > 0 then openDropDown(self, opts, nil, function(k)
        if k == "__any" then self:SetFocus(); return end
        nameBox:SetText(k); secBox:SetFocus(); secBox:HighlightText()
      end, 340) end -- 260 was too narrow for "... (main hand)" (user 01.11.)
    end
    -- grey example while empty: any name can be typed, the list only helps (hooked after SetScript - beta13 set it
    -- before, the SetScript calls replaced the hooks and the example stayed under the typed text)
    local hint = FLT.NewFS(nameBox, nil, "ARTWORK", "GameFontDisableSmall"); hint:SetPoint("LEFT", 6, 0); hint:SetPoint("RIGHT", -4, 0)
    hint:SetJustifyH("LEFT"); hint:SetText(L["any buff, e.g. Demon Skin"]); if hint.SetWordWrap then hint:SetWordWrap(false) end
    local function paintHint() hint:SetShown(nameBox:GetText() == "" and not nameBox:HasFocus()) end
    nameBox:SetScript("OnTextChanged", function(self, user) paintHint(); if user then suggest(self) end end)
    nameBox:SetScript("OnEditFocusGained", function(self) paintHint(); if self:GetText() == "" then suggest(self) end end)
    nameBox:SetScript("OnEditFocusLost", paintHint)
    paintHint()
    r:SetScript("OnClick", function() nameBox:SetFocus() end)
    -- the watched buffs: a click on one removes it
    local lr = row(g, N"Watched buffs", N"Click a buff in the list to remove it.", nil, 24)
    local b, arrow = dropButton(lr, 200)
    local function show()
      local n = #Q.GetBuffReminders()
      b:SetLabel(n == 0 and L["None yet"] or (n == 1 and L["1 buff"] or string.format(L["%d buffs"], n)))
    end
    b:SetScript("OnClick", function(self)
      local opts = {}
      for _, e in ipairs(Q.GetBuffReminders()) do
        opts[#opts + 1] = { key = e.name, label = "|T" .. Q.BuffIcon(e.name) .. ":14:14|t " .. (e.label or e.name) .. "  |cff9d9d9d" .. e.sec .. " s|r", remove = true }
      end
      if #opts == 0 then opts = { { key = "__none", label = "|cff9d9d9d" .. L["No buffs yet"] .. "|r" } }
      else opts[#opts + 1] = { key = "__all", label = FLT.SkinHex("ffd35a") .. L["Remove all"] .. "|r" } end
      openDropDown(self, opts, nil, function(k)
        if k == "__all" then Q.ClearBuffReminders() elseif k ~= "__none" then Q.RemoveBuffReminder(k) end
        show()
      end, 340) -- room for "... (main hand)  60 s" (user 01.11.)
    end)
    b.show = show; list = b
    refreshers[#refreshers + 1] = show
  end
  g = group(c, N"Popups")
  check(g, N"Durability warning", N"Warns when your gear drops to 20% durability.", nil, "durability")
  check(g, N"Nearby Library Book alerts", N"Popup when you are close to a missing library book.", nil, nil, nil,
    function() return FLT.IsNearbyAlertsEnabled and FLT:IsNearbyAlertsEnabled() and true or false end,
    function(v) if FLT.SetNearbyAlertsEnabled then FLT:SetNearbyAlertsEnabled(v) end end)
  -- 6.2.7 (user 13.11.: "damit man es ausschalten kann waehrend man fliegt")
  check(g, N"Not while flying", N"No book popup while you are on a flight path or flying mount.", nil, "bookAlertNoFlying", 24)
  check(g, N"Pet ability alerts (Hunter)", N"Popup when a beast nearby teaches a higher ability rank your pets can learn.", nil, nil, nil,
    function() return FLT.IsPetTeachAlertsEnabled and FLT:IsPetTeachAlertsEnabled() and true or false end,
    function(v) if FLT.SetPetTeachAlertsEnabled then FLT:SetPetTeachAlertsEnabled(v) end end)
  -- 6.2.11 (user 17.11.: "schalter fuer popup bei niedrigeren raengen, standard aus")
  check(g, N"Also lower ranks", N"Also a popup for a lower rank you have not learned yet (for lower level pets).", nil, "petAlertLower", 24)
  check(g, N"Quest share popup in dungeons", N"Opens when a group member can still accept one of your dungeon quests.", nil, nil, nil,
    function() return not (type(OneForAllDB) == "table" and type(OneForAllDB.questShare) == "table" and OneForAllDB.questShare.popup == false) end,
    function(v) if type(OneForAllDB) == "table" then OneForAllDB.questShare = OneForAllDB.questShare or {}; OneForAllDB.questShare.popup = v and true or false end end)
  ---------------------------------------------------------------------------------------------------
  -- MISCELLANEOUS (6.2.13-beta11, user 20.11.: the NPC shortcuts, the chat options (the Chat entry is gone), camera zoom,
  -- error messages, flight times and thanking for buffs in one place)
  c = category("misc", N"Miscellaneous", "Interface\\Icons\\INV_Misc_Rune_01", N"NPC shortcuts, the chat and other small helpers.")
  g = group(c, N"NPCs")
  do -- skip the talk at service NPCs (6.2.13, user 20.11.: a drop-down with each service, all off at first start)
    local r = row(g, N"Skip the talk at service NPCs", N"Opens the vendor, bank, trainer ... window at once.",
      N"Only when the NPC has no quests for you and offers just this one service. Hold Shift to talk normally. Tick the services in the list.")
    r.find = r.find .. " gossip" -- found by "gossip" too (6.2.13-beta13, user 20.11.)
    local b, arrow = dropButton(r, 150)
    local NAMES = { gossipVendor = N"Vendors", gossipBank = N"Bank", gossipTrainer = N"Trainers",
      gossipAuction = N"Auction House", gossipStable = N"Stable Master", gossipGuildBank = N"Guild Bank", gossipTabard = N"Guild Tabard",
      gossipBattle = N"Battlemaster" }
    -- the flight master ("Open flight map at once", flightMapNow - its own key, QoL.lua taxiOption) first in the list
    -- (6.2.13-beta11, user 20.11.: "den flightmaster sollte man eigentlich in dieses drop down menue packen")
    NAMES.flightMapNow = N"Flight master"
    local KEYS = { "flightMapNow" }
    for _, sv in ipairs(Q.GOSSIP_SERVICES) do KEYS[#KEYS + 1] = sv[1] end
    local function show()
      local on, last, n = 0, nil, #KEYS
      for _, k in ipairs(KEYS) do if Q.Get(k) then on = on + 1; last = k end end
      b:SetLabel(on == 0 and L["None"] or on == 1 and L[NAMES[last]] or string.format(L["%d of %d"], on, n))
    end
    local function open(self)
      -- "All" on top (6.2.13-beta10, user 20.11.): ticks every service at once; when all are ticked it clears them
      local all = true
      for _, k in ipairs(KEYS) do if not Q.Get(k) then all = false end end
      local opts = { { key = "*", label = L["All"], checked = all } }
      for _, k in ipairs(KEYS) do opts[#opts + 1] = { key = k, label = L[NAMES[k]], checked = Q.Get(k) and true or false } end
      openDropDown(self, opts, nil, function(k)
        if k == "*" then for _, key in ipairs(KEYS) do Q.Set(key, not all) end else Q.Set(k, not Q.Get(k)) end
        show(); open(self)
      end, 190) -- stays open for the next tick
    end
    b:SetScript("OnClick", open)
    hint(b, N"Skip the talk at service NPCs", N"Tick the services in the list.")
    newTag(r, r.label, "gossipSkip")
    refreshers[#refreshers + 1] = show
  end
  g = group(c, N"General")
  check(g, N"Farther camera zoom", N"Lets you zoom the camera out further.", nil, "cameraZoom")
  check(g, N"Hide error messages", N"Hides the red messages in the middle of the screen.", N"Messages like \"Out of range\" or \"Not enough rage\" are no longer shown. Still shown: inventory or bags full, quest log full, not enough money, carrying too many of an item.", "hideErrors")
  check(g, N"Flight times", N"A bar with the time left while you fly.", N"The time also shows in the tooltip of the destinations on the flight map. OneForAll measures your flights; routes you never flew are estimated (\"about\").", "flightTimes")
  check(g, N"Thank players who buff you", N"Sends a /thank to players outside your group who buff you.", N"For buffs that last longer than 2 minutes. It comes 1 second later, not in combat, at most once every 5 minutes per player. Your target is not changed. /ofa thanks shows the last buffs.", "thanksBuff")
  g = group(c, N"Chat windows")
  do -- chat font size: -, value, +
    local r = row(g, N"Chat font size", N"The same font size for every chat window.", N"Go below 10 to switch it off (then the game's own setting is kept).")
    local function step(d)
      local v = tonumber(Q.Get("chatFont"))
      if not v then v = 14 else v = v + d end
      if v < 10 then v = nil elseif v > 24 then v = 24 end
      Q.Set("chatFont", v); r.show()
    end
    button(r, "+", 26, nil, function() step(1) end)
    local val = FLT.NewFS(r, nil, "OVERLAY", "GameFontNormal"); val:SetWidth(46); val:SetJustifyH("CENTER"); val:SetHeight(20); place(r, val, 4)
    button(r, "-", 26, nil, function() step(-1) end)
    r.show = function() local v = tonumber(Q.Get("chatFont")); val:SetText(v and tostring(v) or L["Off"]) end
    refreshers[#refreshers + 1] = r.show
  end
  check(g, N"Copy chat button", N"Adds a button to every chat window to copy its text.", N"A small button at the top right of every chat window. It opens the chat text so you can select and copy it (Ctrl+C).", "copyChat")
  check(g, N"Hide chat button", N"A button next to the chat hides and shows it.", N"It sits above the chat menu button. Also as a key: Key Bindings > OneForAll > Hide / show chat. Pressing Enter to type brings the chat back.", "chatHide")
  choice(g, N"Hide chat after", N"Hides the chat after that long without a new message.", N"A new message or typing shows it again. Not while the mouse is on the chat.", "chatAutoHide", Q.CHAT_HIDE_OPTIONS)
  g = group(c, N"Typing")
  check(g, N"Message history", N"Arrow up / down in the chat box brings back your last 5 messages.", N"Type, send, open the chat again and press arrow up: the message is there again, Enter sends it. While typing, the arrow keys no longer turn your character.", "chatHistory")

  ---------------------------------------------------------------------------------------------------

  -- left: one button per group with "on / switches"
  local navButtons = {}
  local function selectCat(key)
    current = key
    for _, b in ipairs(navButtons) do b:SetActive(b.key == key) end
    layout()
  end
  local searchBox
  for i, cat in ipairs(cats) do
    local b = UI.NavEntry(nav, navTop - (i - 1) * UI.NAV.step, L[cat.nav or cat.label], cat.icon)
    b.key = cat.key
    b.count = FLT.NewFS(b, nil, "OVERLAY", "GameFontDisableSmall"); b.count:SetPoint("RIGHT", -5, 0)
    do local font, _, flags = b.count:GetFont(); if font then b.count:SetFont(font, 10, flags) end end

    -- left of the button, outside its gold bar (6.2.13-beta23, user 21.11.: "links vor das icon ... schaut dann besser aus")
    if cat.new then local m = UI.NewMark(b, L["New options in this group."]); m:SetPoint("RIGHT", b, "LEFT", -1, 0) end
    b:SetScript("OnClick", function() if search ~= "" then searchBox:SetText("") end; selectCat(cat.key) end)
    cat.nav = b
    navButtons[i] = b
  end
  updateCounts = function()
    for _, cat in ipairs(cats) do
      local on = 0
      for _, get in ipairs(cat.checks) do if get() then on = on + 1 end end
      cat.nav.count:SetText(on .. "/" .. #cat.checks)
      -- a long name (German "Popups & Hinweise") ran into the count: a smaller font, then cut with "..." (beta7)
      local lb = cat.nav._label
      local room = lb and ((cat.nav:GetWidth() or 0) - 29 - (cat.nav.count:GetStringWidth() or 20) - 8)
      if lb and not cat.fitted and room > 0 and (lb:GetStringWidth() or 0) > room then
        cat.fitted = true
        local font, _, flags = lb:GetFont(); if font then lb:SetFont(font, 11, flags) end
        if (lb:GetStringWidth() or 0) > room then lb:SetWidth(room); if lb.SetWordWrap then lb:SetWordWrap(false) end end
      end
    end
  end

  -- search over all groups (name, description and tooltip text)
  onSearch = function(t)
    search = t
    for _, b in ipairs(navButtons) do b:SetActive(search == "" and b.key == current) end
    layout()
  end
  searchBox = head.box

  local function heading(t, y)
    t:ClearAllPoints(); t:SetPoint("TOPLEFT", 8, y); t:Show(); t.divider:Show()
    return y - 30
  end
  local function put(r, y)
    if not r.fitted then -- the grey line ends before the controls on the right
      r.desc:SetWidth(ROW_W - 60 - r.indent - r.rightW - 16); r.fitted = true
    end
    r:ClearAllPoints(); r:SetPoint("TOPLEFT", 4, y); r:Show()
    return y - (r:GetHeight() + 2) -- 34 + 2; taller rows (the quest mark sample) take their height
  end
  layout = function()
    for _, cat in ipairs(cats) do
      cat.title:Hide(); cat.title.divider:Hide()
      for _, gr in ipairs(cat.groups) do gr.title:Hide(); gr.title.divider:Hide(); for _, r in ipairs(gr.rows) do r:Hide() end end
    end
    local y = -6
    if search == "" then
      local cat
      for _, x in ipairs(cats) do if x.key == current then cat = x end end
      FLT.SetTex(hIcon, cat.icon); hTitle:SetText(L[cat.label]); hSub:SetText(L[cat.desc])
      for _, gr in ipairs(cat.groups) do
        y = heading(gr.title, y)
        for _, r in ipairs(gr.rows) do y = put(r, y) end
        y = y - 10
      end
      empty:Hide()
    else
      local n = 0
      for _, cat in ipairs(cats) do
        local first = true
        for _, gr in ipairs(cat.groups) do
          for _, r in ipairs(gr.rows) do
            if r.find:find(search, 1, true) then
              if first then y = heading(cat.title, y); first = false end
              y = put(r, y); n = n + 1
            end
          end
        end
        if not first then y = y - 10 end
      end
      FLT.SetTex(hIcon, "Interface\\Icons\\INV_Misc_Spyglass_02"); hTitle:SetText(L["Search"])
      hSub:SetText(n == 1 and L["1 setting found in all groups."] or string.format(L["%d settings found in all groups."], n))
      empty:SetShown(n == 0)
    end
    child:SetHeight(-y + 8)
    if sf.SetVerticalScroll then sf:SetVerticalScroll(0) end
  end
  selectCat("iface")
  -- open one group from elsewhere (the Noteworthy changes buttons, 6.2.2)
  UI.QoLSelect = function(key) if search ~= "" then searchBox:SetText("") end; selectCat(key) end

  panel:SetScript("OnShow", function() for _, f in ipairs(refreshers) do f() end; updateCounts() end)
  panel:SetScript("OnHide", function() UI.CloseDropDown(); if neverMenu then neverMenu:Hide() end end)
  panel:Hide()
  return panel
end

UI.RegisterPanel({ key="qol", label=N"Quality of Life", order=4, tabWidth=140, create=createQoLPanel, combatLock=true })
