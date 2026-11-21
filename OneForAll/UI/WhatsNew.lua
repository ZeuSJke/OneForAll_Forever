local _, FLT = ...
local L = FLT.L or setmetatable({}, { __index = function(_, k) return k end }) -- (tests without Locales)
local function N(s) return s end -- marks an English text translated where it is shown (tools/locale/extract.py)
local UI = FLT.UI
local makeTexture, makeButton = UI.makeTexture, UI.makeButton

-- "Noteworthy changes" popup. Shown once per account after logging in with a
-- new NEWS_ID (change it for the next release with news). /ofa news reopens it.
-- 5.6.3 (user 16.10.): only the Gear Planner. 5.7.0 (user 22.10.): Quality of Life, enchants, set buttons.
-- 6.0.2 (user 01.11.): World Map, dungeon quests, Gear Planner filters, talent import - not shown automatically.

local NEWS_AUTO = true -- set true (and a new NEWS_ID) for the next release with news
-- 6.1.6 (agreed with the user 06.11.): more reagent sources and more quest "!" on the world map, not shown automatically.
-- 6.2.0 (user 07.11.): only the languages, shown automatically once.
-- 6.2.2 (user 09.11.): the info bar and guild members on the world map, shown automatically once.
-- 6.2.6 (user 12.11.): Skill-Up Helper, Profit, the new stat weights - shown automatically once.
-- 6.2.10 (user 16.11.): the new dungeon pictures and the armor / weapon type filter - NOT shown automatically.
-- 6.2.12 (user 19.11.): Guild Games with special thanks to Gaelda, Ritter Roulade and Deaders, and "Smaller changes"
-- (Skill-Up changes, low level quests, walking routes) - shown automatically once.
-- 6.2.13 (user 21.11.): BiS List, Cheap Upgrades with the Cheap Upgrade Scan, the new stat weights - shown automatically once.
local NEWS_ID = "6.2.13"

-- images (optional): pictures in a row under the lines, each { tex, shown width, shown height, texcoord right,
-- texcoord bottom } (made by tools/art/proc_news.py from the user's screenshots in source_images/news)
-- qol = the Quality of Life group the button opens; shot = a screenshot behind a "Show me" button (user 09.11.):
-- { texture, shown width, shown height, texcoord right, texcoord bottom } (tools/art/proc_news.py)
local NEWS = {
  { icon = "Interface\\Icons\\INV_Sword_39", title = N"BiS List", tab = "armory", button = N"Open Armory",
    lines = {
      N"Armory > Gear Planner > BiS List: the best items per slot before raids for every class and spec, from the WoW Forever BiS lists of wowtbc.gg.",
      N"Your class and spec are picked at first, and every item shows where you get it. More lists will follow.",
    } },
  { icon = "Interface\\Icons\\INV_Misc_Coin_02", title = N"Cheap Upgrades", tab = "armory", button = N"Open Armory",
    lines = {
      N"Armory > Gear Planner > Cheap Upgrades: Bind on Equip gear from the auction house that improves your gear, up to a highest price you set.",
      N"Click \"Cheap Upgrade Scan\" in the auction house: it reads all auctions, also items with a random bonus (\"of the Eagle\"), each with its own price.",
    } },
  { icon = "Interface\\Icons\\INV_Misc_Spyglass_02", title = N"New stat weights", tab = "qol", qol = "tips", button = N"Open Quality of Life",
    lines = {
      N"The Gear Value uses new stat weights for every class and spec (from Geared Forever).",
      N"Quality of Life > Tooltips > \"Gear Value shows\": the change for your whole gear, item against item, or both.",
    } },
}

local frame

-- the screenshot of an entry, in its own window over the popup (a click anywhere on it closes it)
local shotFrame
local function showShot(shot)
  if not shotFrame then
    local f = CreateFrame("Button", "OneForAllNewsShot", UIParent)
    f:SetFrameStrata("FULLSCREEN_DIALOG"); f:SetFrameLevel(50); f:SetPoint("CENTER", 0, 160)
    UI.FramedPanel(f)
    for _, t in ipairs(UI.OrnateFrame(f, f, 18, 3, "OVERLAY", 4)) do t:SetVertexColor(FLT.SkinC(1, 1, 1, 1)) end
    f.pic = f:CreateTexture(nil, "ARTWORK"); f.pic:SetPoint("TOPLEFT", 16, -32)
    local close = UI.CloseButton(f, function() f:Hide() end); close:SetPoint("TOPRIGHT", -6, -6); close:SetFrameLevel(f:GetFrameLevel() + 5)
    f:SetScript("OnClick", function(self) self:Hide() end)
    -- movable like the popup (user 09.11.); a drag does not count as the closing click
    f:SetMovable(true); f:SetClampedToScreen(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
    if UISpecialFrames then table.insert(UISpecialFrames, "OneForAllNewsShot") end -- Esc closes it
    shotFrame = f
  end
  local f = shotFrame
  FLT.SetTex(f.pic, UI.ASSET_ROOT .. shot[1]); f.pic:SetTexCoord(0, shot[4], 0, shot[5]); f.pic:SetSize(shot[2], shot[3])
  f:SetSize(shot[2] + 32, shot[3] + 48)
  f:Show()
end

local function addonVersion()
  local v
  if C_AddOns and C_AddOns.GetAddOnMetadata then v = C_AddOns.GetAddOnMetadata("OneForAll", "Version")
  elseif GetAddOnMetadata then v = GetAddOnMetadata("OneForAll", "Version") end
  return v or NEWS_ID
end

local function create()
  local f = CreateFrame("Frame", "OneForAllWhatsNew", UIParent)
  f:SetSize(680, 200); f:SetPoint("CENTER", 0, 60); f:SetFrameStrata("FULLSCREEN_DIALOG")
  f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
  if UISpecialFrames then table.insert(UISpecialFrames, "OneForAllWhatsNew") end -- Esc closes it

  UI.FramedPanel(f)
  for _, t in ipairs(UI.OrnateFrame(f, f, 18, 3, "OVERLAY", 4)) do t:SetVertexColor(FLT.SkinC(1, 1, 1, 1)) end
  local band = makeTexture(f, "BORDER", 0.075, 0.062, 0.040, 0.90); band:SetPoint("TOPLEFT", 3, -3); band:SetPoint("TOPRIGHT", -3, -3); band:SetHeight(58)
  local dv = f:CreateTexture(nil, "ARTWORK"); FLT.SetTex(dv, UI.ASSET_ROOT .. "divider_ornate"); dv:SetHeight(14); dv:SetPoint("TOPLEFT", 6, -54); dv:SetPoint("TOPRIGHT", -6, -54)

  local logo = f:CreateTexture(nil, "OVERLAY"); logo:SetSize(42, 42); logo:SetPoint("TOPLEFT", 12, -8)
  FLT.SetTex(logo, "Interface\\AddOns\\OneForAll\\Assets\\minimap_icon")
  local title = UI.SmallCaps(f, L["OneForAll - Noteworthy changes"], 23, 18, {1, 0.82, 0.20}, "GameFontNormalLarge"); title:SetPoint("TOPLEFT", 64, -9)
  local ver = FLT.NewFS(f, nil, "OVERLAY", "GameFontDisableSmall"); ver:SetPoint("TOPLEFT", 64, -36)
  ver:SetText(L["Version"] .. " " .. addonVersion())

  local close = UI.CloseButton(f); close:SetPoint("TOPRIGHT", -12, -12)

  local class = UnitClass and select(2, UnitClass("player"))
  local y = -82
  for _, entry in ipairs(NEWS) do
    do
      -- 6.2.6 (user 12.11.: "groesser und auffaelliger"): every entry on its own card with a gold edge
      -- the card's textures belong to f (BORDER layer), cf is only their anchor: textures of a child frame are drawn
      -- over all of f's icons and texts (6.2.6 release check, user screenshot 12.11. 23:39)
      local cf = CreateFrame("Frame", nil, f); cf:SetPoint("TOPLEFT", 10, y + 10); cf:SetPoint("TOPRIGHT", -10, y + 10)
      UI.Card(f, cf, 6, {0.80, 0.60, 0.22, 0.85}, {0.10, 0.085, 0.055, 0.92}, "BORDER", 2)
      local ic = f:CreateTexture(nil, "ARTWORK"); ic:SetSize(46, 46); ic:SetPoint("TOPLEFT", 22, y)
      FLT.SetTex(ic, entry.icon); ic:SetTexCoord(0.07, 0.93, 0.07, 0.93)
      if ic.AddMaskTexture and f.CreateMaskTexture then
        local m = f:CreateMaskTexture(); FLT.SetTex(m, UI.ASSET_ROOT .. "talent_icon_mask2", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE"); m:SetAllPoints(ic); ic:AddMaskTexture(m)
      end
      local icf = f:CreateTexture(nil, "OVERLAY"); FLT.SetTex(icf, UI.ASSET_ROOT .. "talent_frame"); icf:SetPoint("TOPLEFT", ic, -3, 3); icf:SetPoint("BOTTOMRIGHT", ic, 3, -3); icf:SetVertexColor(FLT.SkinC(0.98, 0.76, 0.30, 1))
      local h = FLT.NewFS(f, nil, "OVERLAY", "GameFontNormalLarge"); h:SetPoint("TOPLEFT", 82, y - 2)
      h:SetText(L[entry.title] .. (entry.note and ("  |cff9d9d9d" .. L[entry.note] .. "|r") or "")); h:SetTextColor(FLT.SkinC(1, 0.82, 0.20))
      -- the button only for characters that have that tab (Hunter Pets: hunters)
      if entry.tab and (not entry.buttonClass or entry.buttonClass == class) then
        local b = UI.GoldButton(f, L[entry.button], 180, 30, nil, 14); b:SetPoint("TOPRIGHT", -22, y)
        b:SetScript("OnClick", function()
          f:Hide(); if shotFrame then shotFrame:Hide() end
          if FLT.OpenPanel then FLT:OpenPanel(entry.tab) end
          if entry.qol and UI.QoLSelect then UI.QoLSelect(entry.qol) end
          if entry.sub and FLT.ShowProfessionSub then FLT.ShowProfessionSub(entry.sub) end
        end)
        if entry.hint then -- a small note under the button (user 12.11. 23:43)
          local hn = FLT.NewFS(f, nil, "OVERLAY", "GameFontDisableSmall"); hn:SetPoint("TOP", b, "BOTTOM", 0, -5)
          hn:SetWidth(210); hn:SetJustifyH("CENTER"); hn:SetText(L[entry.hint])
        end
      end
      if entry.shot then -- "Show me" (user 09.11.): the screenshot in its own window
        local b = UI.GoldButton(f, L["Show me"], 180, 30, nil, 14); b:SetPoint("TOPRIGHT", -22, y - 36)
        b:SetScript("OnClick", function() showShot(entry.shot) end)
      end
      local ly = y - 28
      for _, line in ipairs(entry.lines) do
        local dot = FLT.NewFS(f, nil, "OVERLAY", "GameFontHighlight"); dot:SetPoint("TOPLEFT", 84, ly); dot:SetText(FLT.SkinHex("d9a63a") .. "•|r")
        local t = FLT.NewFS(f, nil, "OVERLAY", "GameFontHighlight"); t:SetPoint("TOPLEFT", 98, ly)
        -- the lines stay left of the buttons column (user 22.10.); full width only for entries without a button
        t:SetWidth(entry.tab and 360 or 550); t:SetJustifyH("LEFT"); t:SetText(L[line]); t:SetTextColor(FLT.SkinC(0.90, 0.88, 0.82))
        ly = ly - math.max(18, (t:GetStringHeight() or 14) + 6)
      end
      if entry.images then
        local x, hmax = 98, 0
        for _, im in ipairs(entry.images) do
          local pic = f:CreateTexture(nil, "ARTWORK"); pic:SetSize(im[2], im[3]); pic:SetPoint("TOPLEFT", x, ly - 4)
          FLT.SetTex(pic, UI.ASSET_ROOT .. im[1]); pic:SetTexCoord(0, im[4], 0, im[5])
          local pf = CreateFrame("Frame", nil, f); pf:SetAllPoints(pic)
          UI.OrnateFrame(pf, pf, 10, 2, "OVERLAY", 1)
          x = x + im[2] + 10; hmax = math.max(hmax, im[3])
        end
        ly = ly - hmax - 12
      end
      ly = math.min(ly, y - 74) -- the card holds the icon and the buttons too
      cf:SetHeight(y + 10 - ly + 4)
      y = ly - 24
    end
  end

  local foot = FLT.NewFS(f, nil, "OVERLAY", "GameFontDisableSmall"); foot:SetPoint("BOTTOMLEFT", 16, 16)
  foot:SetText(L["Type /ofa news to show this again."])
  local ok = UI.GoldButton(f, L["Got it"], 130, 30, nil, 14); ok:SetPoint("BOTTOMRIGHT", -16, 14)
  ok:SetScript("OnClick", function() f:Hide() end)
  f:HookScript("OnHide", function() if shotFrame then shotFrame:Hide() end end)

  f:SetHeight(-y + 44)
  f:Hide()
  return f
end

function FLT.ShowNews()
  if not frame then frame = create() end
  frame:Show()
  if type(OneForAllDB) == "table" then OneForAllDB.newsSeen = NEWS_ID end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
  if not NEWS_AUTO then return end -- 6.0.0: no news popup, a clean start; only the welcome setup (user 27.10.)
  if type(OneForAllDB) ~= "table" then return end
  if FLT.WelcomeDue and FLT.WelcomeDue() then return end -- the welcome setup first; the news come with the next login
  local seen = OneForAllDB.newsSeen
  if type(seen) == "string" and (seen == NEWS_ID or seen:sub(1, #NEWS_ID + 1) == NEWS_ID .. ".") then return end
  if C_Timer and C_Timer.After then C_Timer.After(6, FLT.ShowNews) else FLT.ShowNews() end
end)
