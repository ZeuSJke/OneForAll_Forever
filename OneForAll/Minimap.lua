local _, FLT = ...
local L = FLT.L or setmetatable({}, { __index = function(_, k) return k end }) -- (tests without Locales)

local button

local function getAngle(y, x)
  if math.atan2 then return math.atan2(y, x) end
  if atan2 then return atan2(y, x) end
  if x == 0 then
    if y >= 0 then return math.pi / 2 else return -math.pi / 2 end
  end
  local a = math.atan(y / x)
  if x < 0 then a = a + math.pi end
  return a
end

-- The button sits on the rim of the minimap: half the minimap size plus a small
-- overhang, so it follows a bigger (or scaled) minimap like the buttons of other
-- addons. Square minimaps: the point is pushed out to the square's edge.
local function positionButton(angle)
  if not button or not Minimap then return end
  angle = angle or 225
  local half = (Minimap:GetWidth() or 140) / 2
  local radius = half + 5
  local r = math.rad(angle)
  local x, y = math.cos(r), math.sin(r)
  local shape = GetMinimapShape and GetMinimapShape() or "ROUND"
  if shape == "SQUARE" then
    local m = math.max(math.abs(x), math.abs(y))
    if m > 0 then x, y = x / m, y / m end
    radius = half + 4
  end
  button:ClearAllPoints()
  button:SetPoint("CENTER", Minimap, "CENTER", x * radius, y * radius)
end
FLT.PositionMinimapButton = function() positionButton(OneForAllDB and OneForAllDB.minimapAngle or 225) end

local function stopDragging(self)
  self:SetScript("OnUpdate", nil)
  self.dragging = nil
end

local function updateDragging(self)
  local mx, my = Minimap:GetCenter()
  if not mx or not my then return end

  local scale = UIParent:GetEffectiveScale()
  local cx, cy = GetCursorPosition()
  cx, cy = cx / scale, cy / scale

  local angle = math.deg(getAngle(cy - my, cx - mx))
  if angle < 0 then angle = angle + 360 end

  OneForAllDB.minimapAngle = angle
  positionButton(angle)
end

-- the logo in the chosen color: "round" (minimap button) or "card" (collector button)
local LOGO_COLORS = { red = true, blue = true, green = true, teal = true, violet = true, black = true } -- black: 6.2.11, user 17.11.
-- "bronze" (header test, user 31.10.): the logo of the window header - the turquoise file without colour, tinted
-- bronze-gold (FLT.TintLogo on every texture that shows it)
function FLT.LogoTexture(kind)
  local c = FLT.QoL and FLT.QoL.Get and FLT.QoL.Get("logoColor")
  if not LOGO_COLORS[c] then c = "teal" end
  return "Interface\\AddOns\\OneForAll\\Assets\\logo_" .. kind .. "_" .. c
end
function FLT.TintLogo(tex, color)
  if not tex then return tex end
  local bronze = (color or (FLT.QoL and FLT.QoL.Get and FLT.QoL.Get("logoColor"))) == "bronze"
  if tex.SetDesaturated then tex:SetDesaturated(bronze) end
  if bronze then tex:SetVertexColor(1, 0.80, 0.45) else tex:SetVertexColor(1, 1, 1) end
  return tex
end
function FLT.ApplyLogoColor()
  if button and button.icon then button.icon:SetTexture(FLT.LogoTexture("round")); FLT.TintLogo(button.icon) end
  if FLT.collectorIcon then FLT.collectorIcon:SetTexture(FLT.LogoTexture("card")); FLT.TintLogo(FLT.collectorIcon) end
  if FLT.trainerTabIcon then FLT.trainerTabIcon:SetTexture(FLT.LogoTexture("round")); FLT.TintLogo(FLT.trainerTabIcon) end
  if FLT.collectorHi then FLT.collectorHi:SetTexture(FLT.LogoTexture("card")); FLT.TintLogo(FLT.collectorHi) end
  -- the LibDBIcon button that replaces ours with Leatrix Plus (6.2.13-beta23, Discord deyreth_redrock 21.11.: "can't change color
  -- of minimap button" - guessed cause: it always showed its own fixed picture); LibDataBroker passes the new icon on
  if FLT.ldbObj then
    FLT.ldbObj.icon = FLT.LogoTexture("round")
    local b = FLT.ldbIcon and FLT.ldbIcon.GetMinimapButton and FLT.ldbIcon:GetMinimapButton("OneForAll")
    if b and b.icon then FLT.TintLogo(b.icon) end
  end
end
-- QoL "logoSize" (6.2.11, user 17.11.): size of the OneForAll minimap button and of the collector button, 60 - 150 %.
-- Sizes, not SetScale: the minimap button keeps its centre on the ring (positionButton), the collector its corner.
function FLT.ApplyLogoSize()
  local s = (FLT.QoL and FLT.QoL.Get and tonumber(FLT.QoL.Get("logoSize")) or 100) / 100
  if s < 0.6 or s > 1.5 then s = 1 end
  if button then button:SetSize(31 * s, 31 * s); button.icon:SetSize(25 * s, 25 * s); button.hl:SetSize(31 * s, 31 * s) end
  local c = FLT.collectorIcon and FLT.collectorIcon:GetParent()
  if c then c:SetSize(34 * s, 42 * s) end
end

function FLT:CreateMinimapButton()
  if button or not Minimap then return end

  button = CreateFrame("Button", "OneForAllMinimapButton", Minimap)
  FLT.minimapButton = button
  button:SetSize(31, 31)
  button:SetFrameStrata("MEDIUM")
  button:SetFrameLevel((Minimap:GetFrameLevel() or 0) + 8)
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:RegisterForDrag("LeftButton")

  -- Same geometry as LibDBIcon (used by most addons), so the button matches
  -- other minimap buttons and button-collector bars.
  -- MiniMap-TrackingBorder contains transparent padding, so it must be
  -- anchored to the button's TOPLEFT without a manual offset.
  -- the round logo (5.7.3, user 26./27.10.) brings its own gold ring: no Blizzard border / background; about the size
  -- of the rings of other minimap buttons. Its color: QoL "logoColor" (turquoise by default, user 27.10.)
  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetTexture(FLT.LogoTexture("round")); FLT.TintLogo(icon)
  icon:SetSize(25, 25)
  icon:SetPoint("CENTER", 0, 0)
  button.icon = icon

  local highlight = button:CreateTexture(nil, "HIGHLIGHT")
  highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  highlight:SetBlendMode("ADD")
  highlight:SetSize(31, 31)
  highlight:SetPoint("CENTER", 0, 0)
  button.hl = highlight
  FLT.ApplyLogoSize()

  -- Shift-right-click: the Crafting List (user 24.10.)
  button:SetScript("OnClick", function(_, mouse)
    if mouse == "RightButton" then
      if IsAltKeyDown and IsAltKeyDown() and FLT.SkillUp and FLT.SkillUp.ToggleLastGuide then FLT.SkillUp.ToggleLastGuide()
      elseif IsShiftKeyDown and IsShiftKeyDown() and FLT.CraftList then FLT.CraftList.Toggle() end
      return
    end
    if FLT.ToggleUI then FLT:ToggleUI() end
  end)

  button:SetScript("OnDragStart", function(self)
    self.dragging = true
    self:SetScript("OnUpdate", updateDragging)
  end)

  button:SetScript("OnDragStop", stopDragging)
  button:SetScript("OnHide", stopDragging)

  button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine(FLT.DISPLAY_NAME or "OneForAll", 1, 0.82, 0)
    GameTooltip:AddLine(L["Left-click: Open / close"], 1, 1, 1)
    GameTooltip:AddLine(L["Shift-right-click: Crafting List"], 1, 1, 1)
    GameTooltip:AddLine(L["Alt-right-click: last Skill-Up guide"], 1, 1, 1)
    GameTooltip:AddLine(L["Drag: Move around the minimap"], 0.75, 0.75, 0.75)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function() GameTooltip:Hide() end)

  positionButton((OneForAllDB and OneForAllDB.minimapAngle) or 225)
  -- also in the game's AddOns list at the minimap (with ElvUI or a hidden button it is the way in, user 22.10.)
  if type(AddonCompartmentFrame) == "table" and type(AddonCompartmentFrame.RegisterAddon) == "function" and not FLT.compartmentAdded then
    FLT.compartmentAdded = true
    pcall(AddonCompartmentFrame.RegisterAddon, AddonCompartmentFrame, {
      text = FLT.DISPLAY_NAME or "OneForAll", icon = "Interface\\AddOns\\OneForAll\\Assets\\minimap_icon", notCheckable = true,
      func = function() if FLT.ToggleUI then FLT:ToggleUI() end end,
      funcOnEnter = function(b)
        GameTooltip:SetOwner(b, "ANCHOR_LEFT"); GameTooltip:AddLine(FLT.DISPLAY_NAME or "OneForAll", 1, 0.82, 0)
        GameTooltip:AddLine(L["Click: Open / close"], 1, 1, 1); GameTooltip:Show()
      end,
      funcOnLeave = function() GameTooltip:Hide() end,
    })
  end
  -- minimap size can change after login (other addons, UI scale)
  if Minimap.HookScript then Minimap:HookScript("OnSizeChanged", FLT.PositionMinimapButton) end
  if C_Timer and C_Timer.After then C_Timer.After(3, FLT.PositionMinimapButton) end
  button:Show()
  FLT.RegisterLDBIcon()
  if FLT.MinimapCollectorRefresh then FLT.MinimapCollectorRefresh() end
end

-- Leatrix Plus gathers only LibDBIcon buttons in its button bag (6.2.5, Discord vkinglouie 11.11.: our button stayed at
-- the minimap). With Leatrix Plus loaded and its LibDBIcon / LibDataBroker there, OneForAll registers a LibDBIcon button
-- of the same use and hides its own; MinimapCollectorRefresh shows / hides it like our button.
function FLT.RegisterLDBIcon()
  if FLT.ldbIcon ~= nil then return FLT.ldbIcon end
  FLT.ldbIcon = false
  local loaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
  if not (loaded and loaded("Leatrix_Plus")) or type(LibStub) ~= "table" then return false end
  local LDB, LDBI = LibStub("LibDataBroker-1.1", true), LibStub("LibDBIcon-1.0", true)
  if not (LDB and LDBI and LDB.NewDataObject and LDBI.Register) then return false end
  local obj = LDB:NewDataObject("OneForAll", {
    type = "launcher", icon = FLT.LogoTexture("round"), -- in the chosen logo color (6.2.13-beta23)
    OnClick = function(_, mouse)
      if mouse == "RightButton" then
        if IsAltKeyDown and IsAltKeyDown() and FLT.SkillUp and FLT.SkillUp.ToggleLastGuide then FLT.SkillUp.ToggleLastGuide()
        elseif IsShiftKeyDown and IsShiftKeyDown() and FLT.CraftList then FLT.CraftList.Toggle() end
      elseif FLT.ToggleUI then FLT:ToggleUI() end
    end,
    OnTooltipShow = function(tt)
      tt:AddLine(FLT.DISPLAY_NAME or "OneForAll", 1, 0.82, 0)
      tt:AddLine(L["Left-click: Open / close"], 1, 1, 1)
      tt:AddLine(L["Shift-right-click: Crafting List"], 1, 1, 1)
      tt:AddLine(L["Alt-right-click: last Skill-Up guide"], 1, 1, 1)
    end,
  })
  if not obj then return false end
  FLT.ldbObj = obj
  if type(OneForAllDB) ~= "table" then return false end
  OneForAllDB.ldbIcon = OneForAllDB.ldbIcon or {}
  if not pcall(LDBI.Register, LDBI, "OneForAll", obj, OneForAllDB.ldbIcon) then return false end
  FLT.ldbIcon = LDBI
  local b = LDBI.GetMinimapButton and LDBI:GetMinimapButton("OneForAll")
  if b and b.icon then FLT.TintLogo(b.icon) end -- bronze
  return LDBI
end
-- registered as early as possible (when our saved variables are there), so Leatrix Plus finds the button when it gathers
-- them; Leatrix_Plus loads before OneForAll (alphabetical), its libraries are there by then
do
  local f = CreateFrame("Frame")
  f:RegisterEvent("ADDON_LOADED")
  f:SetScript("OnEvent", function(self, _, name)
    if name ~= "OneForAll" then return end
    self:UnregisterAllEvents()
    pcall(FLT.RegisterLDBIcon)
  end)
end

-- QoL "mmSquare" (5.7.3, user 25.10., off by default): a square minimap with a thin black frame. The round border,
-- compass and north tag are hidden, GetMinimapShape() answers "SQUARE" so other addons' buttons follow the edge.
-- Left alone when ElvUI runs or another addon already made the minimap square. Switching off restores everything.
local square = { on = false }
-- MinimapCompassTextureUnderlay: Forever's own round ring, shown again by MinimapCluster:UpdateMinimapConfig() (beta39,
-- found by ProEvilz on Discord 12.11.: "Enabling the square minimap doesn't remove the circular border")
local SQUARE_HIDE = { "MinimapBorder", "MinimapCompassTexture", "MinimapNorthTag", "MinimapCompassTextureUnderlay" }
-- the zoom buttons sit on the round rim; on the square map they go to its corner (user 25.10.; GameTimeFrame is the
-- calendar in Forever, not the sun - left alone): name, anchor point on the Minimap, x, y
-- the frames may also hang under Minimap / MinimapCluster as .ZoomIn / .ZoomOut (newer client code, user 26.10.:
-- the global names moved nothing in Forever)
local SQUARE_MOVE = {
  { "MinimapZoomIn", "BOTTOMRIGHT", 12, 34, "ZoomIn" }, -- just outside the edge (user 26.10.)
  { "MinimapZoomOut", "BOTTOMRIGHT", 12, 10, "ZoomOut" },
  { "dial", "TOPRIGHT", 0, 0 }, -- the day / night moon centred on the top right corner (user 26.10.)
}
-- Forever's day / night dial (Blizzard_Minimap/Camelot/Diel.lua, user 26.10. via /fstack): an unnamed child of
-- MinimapCluster.MinimapContainer, anchored CENTER to the container, with a .Background texture
local function findDial()
  if square.dial then return square.dial end -- once moved it no longer hangs on the container
  local box = type(MinimapCluster) == "table" and MinimapCluster.MinimapContainer
  if type(box) ~= "table" or not box.GetChildren then return nil end
  for _, c in ipairs({ box:GetChildren() }) do
    if c ~= Minimap and rawget(c, "Background") and c.GetPoint then
      local p, rel = c:GetPoint(1)
      if p == "CENTER" and rel == box then square.dial = c; return c end
    end
  end
end
local function findFrame(m)
  if m[1] == "dial" then return findDial() end
  local f = _G[m[1]]
  if type(f) ~= "table" and m[5] then
    for _, holder in ipairs({ Minimap, MinimapCluster, MinimapBackdrop }) do
      local c = type(holder) == "table" and rawget(holder, m[5])
      if type(c) == "table" then f = c; break end
    end
  end
  return type(f) == "table" and f or nil
end
local function moveCorners(on)
  local unpk = unpack or table.unpack
  for _, m in ipairs(SQUARE_MOVE) do
    local f = findFrame(m)
    if f and f.GetPoint and not (f.IsProtected and f:IsProtected() and InCombatLockdown and InCombatLockdown()) then
      if on then
        if not square.points then square.points = {} end
        if not square.points[m[1]] then
          local pts = {}
          for i = 1, (f:GetNumPoints() or 0) do pts[i] = { f:GetPoint(i) } end
          square.points[m[1]] = pts
        end
        f:ClearAllPoints(); f:SetPoint("CENTER", Minimap, m[2], m[3], m[4])
      elseif square.points and square.points[m[1]] then
        f:ClearAllPoints()
        for _, p in ipairs(square.points[m[1]]) do f:SetPoint(unpk(p)) end
        square.points[m[1]] = nil
      end
    end
  end
end
-- the client sets the round mask and shows its ring again whenever it sets up the minimap (UpdateMinimapConfig, e.g.
-- when the rotation changes): put the square back right after it (hooked once, does nothing while the option is off)
local function squareAgain()
  if not square.on then return end
  Minimap:SetMaskTexture("Interface\\ChatFrame\\ChatFrameBackground")
  for _, n in ipairs(SQUARE_HIDE) do
    local t = _G[n]
    if type(t) == "table" and t.IsShown and t:IsShown() then
      t:Hide()
      local known = false
      for _, h in ipairs(square.hidden or {}) do if h == t then known = true end end
      if not known and square.hidden then square.hidden[#square.hidden + 1] = t end
    end
  end
end
function FLT.ApplySquareMinimap()
  if type(Minimap) ~= "table" or not Minimap.SetMaskTexture then return end
  local want = FLT.QoL and FLT.QoL.Get and FLT.QoL.Get("mmSquare") and true or false
  if want == square.on then return end
  if want then
    local loaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    if (loaded and loaded("ElvUI")) or (GetMinimapShape and GetMinimapShape() == "SQUARE") then return end
    square.on = true
    Minimap:SetMaskTexture("Interface\\ChatFrame\\ChatFrameBackground")
    square.hidden = {}
    for _, n in ipairs(SQUARE_HIDE) do
      local t = _G[n]
      if type(t) == "table" and t.IsShown and t:IsShown() then t:Hide(); square.hidden[#square.hidden + 1] = t end
    end
    if not square.frame then
      local f = CreateFrame("Frame", nil, Minimap); f:SetAllPoints(); f:SetFrameLevel((Minimap:GetFrameLevel() or 0) + 1)
      local W = 2 -- thin black line just outside the map
      local function edge(p1, p2, x1, y1, x2, y2, w, h)
        local t = f:CreateTexture(nil, "OVERLAY"); t:SetColorTexture(0, 0, 0, 1)
        t:SetPoint(p1, Minimap, p1, x1, y1); t:SetPoint(p2, Minimap, p2, x2, y2)
        if w then t:SetWidth(w) else t:SetHeight(h) end
      end
      edge("TOPLEFT", "TOPRIGHT", -W, W, W, W, nil, W)
      edge("BOTTOMLEFT", "BOTTOMRIGHT", -W, -W, W, -W, nil, W)
      edge("TOPLEFT", "BOTTOMLEFT", -W, W, -W, -W, W, nil)
      edge("TOPRIGHT", "BOTTOMRIGHT", W, W, W, -W, W, nil)
      square.frame = f
    end
    square.frame:Show()
    if not square.hooked and type(MinimapCluster) == "table" and type(MinimapCluster.UpdateMinimapConfig) == "function" and hooksecurefunc then
      hooksecurefunc(MinimapCluster, "UpdateMinimapConfig", squareAgain); square.hooked = true
    end
    moveCorners(true)
    -- once more a moment later, in case the game lays out the minimap after us
    if C_Timer and C_Timer.After then C_Timer.After(1, function() if square.on then moveCorners(true) end end) end
    square.shape = GetMinimapShape
    GetMinimapShape = function() return "SQUARE" end -- the usual way addons ask for the shape (LibDBIcon & co.)
  else
    square.on = false
    -- the round mask by its file ID: the path "Textures\\MinimapMask" left the round map empty in Forever (user 27.10.)
    Minimap:SetMaskTexture(186178)
    for _, t in ipairs(square.hidden or {}) do t:Show() end
    square.hidden = nil
    -- let the client set its minimap up again (its own mask, the ring only where it belongs); not in combat
    if square.hooked and not (InCombatLockdown and InCombatLockdown()) then pcall(MinimapCluster.UpdateMinimapConfig, MinimapCluster) end
    if square.frame then square.frame:Hide() end
    moveCorners(false)
    GetMinimapShape = square.shape
  end
  if FLT.PositionMinimapButton then FLT.PositionMinimapButton() end
  -- LibDBIcon buttons go to the new edge right away (they only did when dragged, user 25.10.)
  local LDBI = type(LibStub) == "table" and LibStub("LibDBIcon-1.0", true)
  if LDBI and LDBI.objects and LDBI.Refresh then for name in pairs(LDBI.objects) do pcall(LDBI.Refresh, LDBI, name) end end
end

-- QoL "mmMove" (Shift-drag moved the MinimapCluster, 5.7.3 - 6.2.0-beta43) is gone (beta44, user 07.11.): the client's
-- Edit Mode moves the minimap, and our SetPoint hook / SetUserPlaced fought it (it jumped back and was locked, taint).
-- The settings row only points to the Edit Mode now; the old saved values are dropped at login.
do
  local ev = CreateFrame("Frame")
  ev:RegisterEvent("PLAYER_LOGIN")
  ev:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    if FLT.QoL and FLT.QoL.On then
      FLT.QoL.On("mmSquare", FLT.ApplySquareMinimap); FLT.QoL.On("logoColor", FLT.ApplyLogoColor); FLT.QoL.On("logoSize", FLT.ApplyLogoSize)
    end
    if FLT.SafeCall then FLT.SafeCall("SquareMinimap", FLT.ApplySquareMinimap) else pcall(FLT.ApplySquareMinimap) end
    local q = type(OneForAllDB) == "table" and OneForAllDB.qol
    if type(q) == "table" then q.mmMove, q.mmPos = nil, nil end
  end)
end
