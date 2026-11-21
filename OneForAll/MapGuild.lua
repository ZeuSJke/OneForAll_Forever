local _, FLT = ...
local L = FLT.L or setmetatable({}, { __index = function(_, k) return k end }) -- (tests without Locales)

-- Guild members on the world map (6.2.2, user 09.11.): guild members who also use OneForAll share where they are
-- (addon message to GUILD) and show as dots in class colour on the zone map and, a little smaller, on the continent map.
-- One switch, qol.guildMap (on, user 09.11.), for both ways: switched off you are not on the others' maps any more and
-- you see nobody either (user: "wenn man es deaktiviert, sehen andere leute einen nicht mehr ..., man selbst sieht andere
-- aber auch nicht mehr"). Only exact positions of OneForAll users, no zone markers for the others (user 09.11.).
-- OpenMap (6.2.5, idea and code by CaptainBritish, public repo PR #63, user 10.11.): guildmates who share through OpenMap
-- v0.8.3 (prefix "OpenMapLoc", "L1<tab>uiMapID<tab>x<tab>y<tab>CLASS<tab>level" with x / y 0..1, "L0" = stopped sharing)
-- show the same way. Only received, nothing is sent in its format; kept apart (openMapMembers, forgotten after 150 s), and
-- a fresh OneForAll message of the same player wins (also "inside a dungeon").
-- Sent: your zone map and position, only when it changed (at most every 5 s), else every 60 s that you are still there;
-- inside a dungeon / raid only which one ("I", user 09.11.: a green dot on its entrance, the names in its tooltip -
-- MapLandmarks.lua asks GM.Inside); battlegrounds and unknown instances send "gone". Members in your group get no dot
-- (the game shows them). Your own messages come back to you: a random token per session tells them apart (user 09.11.:
-- a dot sat under the own arrow), the name check stays as a second guard. Someone switching it on asks once ("Q"), the others answer with
-- their next tick. Members not heard from for 3 minutes are dropped.
-- Lean: a 5 s ticker only while switched on and in a guild; the messages are only listened to then; dots are only drawn
-- while the map is open; a member's world position is worked out once per message.

local GM = {}
FLT.MapGuild = GM

local PREFIX = "OFAGuildPos"
local OPENMAP_PREFIX, OPENMAP_FORGET = "OpenMapLoc", 150
local SEND_EVERY, ALIVE_EVERY, FORGET = 5, 60, 180
local SIZE, SIZE_CONT = 14, 10

local function Q(key) return FLT.QoL and FLT.QoL.Get(key) end
local function now() return GetTime and GetTime() or 0 end
local function on() return Q("guildMap") and IsInGuild and IsInGuild() and true or false end

local members = {} -- [sender] = { map, x, y, cls, lvl, t, cont, world } or { inst = dungeon key, cls, lvl, t }
local openMapMembers = {} -- keep each addon's location and stop-sharing messages independent
GM._members = members -- tests
GM._openMap = openMapMembers -- tests

local TOKEN = string.format("%06x", math.random(0, 0xffffff)) -- this session's messages
local lmDirty = false -- somebody went into / came out of a dungeon: the entrances need a redraw
local function send(msg)
  if C_ChatInfo and C_ChatInfo.SendAddonMessage then pcall(C_ChatInfo.SendAddonMessage, PREFIX, msg, "GUILD") end
end

-- ---------------------------------------------------------------------------
-- sending
-- ---------------------------------------------------------------------------
local last = { map = nil, x = 0, y = 0, t = -1000, inst = nil }
local gone = true -- the others were told we are not on the map (start: nothing sent yet)
local force = false
local function myDungeon()
  local d = FLT.FindCurrentDungeon and FLT.FindCurrentDungeon()
  return d and d.key
end
local function myPosition()
  if IsInInstance and IsInInstance() then return end
  local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  if not map then return end
  local pos = C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(map, "player")
  if not pos then return end
  local x, y
  if pos.GetXY then x, y = pos:GetXY() else x, y = pos.x, pos.y end
  if not (x and y) or (x == 0 and y == 0) then return end
  return map, x, y
end
local function sendPosition()
  local t = now()
  local _, cls = UnitClass("player")
  local inInst = IsInInstance and IsInInstance()
  local inst = inInst and myDungeon()
  if inst then -- inside a dungeon / raid: only which one
    if inst ~= last.inst or force or t - last.t >= ALIVE_EVERY then
      send(string.format("I\t%s\t%s\t%d\t%s", inst, cls or "", UnitLevel("player") or 0, TOKEN))
      last.inst, last.map, last.t, gone, force = inst, nil, t, false, false
    end
    return
  end
  last.inst = nil
  local map, x, y
  if not inInst then map, x, y = myPosition() end
  if not map then
    if not gone then send("X"); gone = true; last.map = nil end
    return
  end
  local moved = map ~= last.map or math.abs(x - last.x) > 0.002 or math.abs(y - last.y) > 0.002
  if not (moved or force or t - last.t >= ALIVE_EVERY) then return end
  send(string.format("P\t%d\t%d\t%d\t%s\t%d\t%s", map, math.floor(x * 10000 + 0.5), math.floor(y * 10000 + 0.5), cls or "", UnitLevel("player") or 0, TOKEN))
  last.map, last.x, last.y, last.t, gone, force = map, x, y, t, false, false
end

-- ---------------------------------------------------------------------------
-- receiving
-- ---------------------------------------------------------------------------
local refreshSoon
local function isMe(sender)
  local me = UnitName and UnitName("player")
  if not me or sender == me then return sender == me end
  local short = Ambiguate and Ambiguate(sender, "short") or sender:match("^[^-]+")
  return short == me
end
local function setPosition(m, map, x, y, cls, lvl)
  m.map, m.x, m.y, m.cls, m.lvl, m.t = map, x, y, cls, lvl, now()
  -- where that is in the world, for other maps (the continent): once per message
  m.cont, m.world = nil, nil
  if C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D then
    local ok, cont, world = pcall(C_Map.GetWorldPosFromMapPos, map, CreateVector2D(x, y))
    if ok and cont and world then m.cont, m.world = cont, world end
  end
  refreshSoon()
end
function GM.Receive(msg, sender)
  if not Q("guildMap") or type(msg) ~= "string" or not sender or isMe(sender) then return end
  local kind = msg:sub(1, 1)
  if kind == "Q" then force = true; return end
  if kind == "X" then
    local m = members[sender]
    if m then members[sender] = nil; if m.inst then lmDirty = true end; refreshSoon() end
    return
  end
  if kind == "I" then
    local key, cls, lvl, tok = msg:match("^I\t([%w_]+)\t(%u*)\t(%d+)\t?(%x*)")
    if not key or tok == TOKEN then return end
    local m = members[sender] or {}
    members[sender] = m
    if m.inst ~= key then lmDirty = true end
    m.inst, m.map, m.cont, m.world, m.cls, m.lvl, m.t = key, nil, nil, nil, cls, tonumber(lvl), now()
    refreshSoon()
    return
  end
  if kind ~= "P" then return end
  local map, x, y, cls, lvl, tok = msg:match("^P\t(%d+)\t(%d+)\t(%d+)\t(%u*)\t(%d+)\t?(%x*)")
  map, x, y = tonumber(map), tonumber(x), tonumber(y)
  if not (map and x and y) or tok == TOKEN then return end
  local m = members[sender] or {}
  members[sender] = m
  if m.inst then m.inst = nil; lmDirty = true end
  setPosition(m, map, x / 10000, y / 10000, cls, tonumber(lvl))
end

local function receiveOpenMap(msg, sender)
  if not on() or type(msg) ~= "string" or type(sender) ~= "string" or sender == "" or isMe(sender) then return end
  if msg == "L0" then
    if openMapMembers[sender] then openMapMembers[sender] = nil; refreshSoon() end
    return
  end
  -- OpenMap v0.8.3 sends normalized decimal coordinates on the client's uiMapID.
  local map, x, y, cls, lvl = msg:match("^L1\t(%d+)\t(%d+%.?%d*)\t(%d+%.?%d*)\t(%u*)\t(%d+)$")
  map, x, y = tonumber(map), tonumber(x), tonumber(y)
  if not (map and map > 0 and x and y and x <= 1 and y <= 1) then return end
  if not (C_Map and C_Map.GetMapInfo) then return end
  local ok, info = pcall(C_Map.GetMapInfo, map)
  if not (ok and info) then return end
  local m = openMapMembers[sender] or {}
  openMapMembers[sender] = m
  setPosition(m, map, x, y, cls, tonumber(lvl))
end
GM._ReceiveOpenMap = receiveOpenMap -- tests

-- ---------------------------------------------------------------------------
-- drawing (only while the map is open)
-- ---------------------------------------------------------------------------
local pool, used = {}, 0
local near = {} -- the pins under the mouse (reused)
local function onEnter(pin)
  local m, name = pin.m, pin.name
  if not (m and GameTooltip) then return end
  GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
  -- dots on top of each other share one tooltip with every name (6.2.10, user 15.11.: "da sind drei gildenleute,
  -- solltest du die nicht mal zusammenfuegen im tool tip?")
  wipe(near)
  for i = 1, used do
    local p = pool[i]
    if p.m and p.cx and pin.cx and math.abs(p.cx - pin.cx) <= pin.reach and math.abs(p.cy - pin.cy) <= pin.reach then near[#near + 1] = p end
  end
  if #near < 2 then near[1] = pin; for i = #near, 2, -1 do near[i] = nil end end
  table.sort(near, function(a, b) return a.name < b.name end)
  for _, p in ipairs(near) do
    local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[p.m.cls]
    local cname = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[p.m.cls] or p.m.cls
    local who, lvl = Ambiguate and Ambiguate(p.name, "guild") or p.name, string.format(L["Level %s %s"], p.m.lvl or "?", cname or "")
    if #near == 1 then
      GameTooltip:AddLine(who, c and c.r or 1, c and c.g or 1, c and c.b or 1)
      GameTooltip:AddLine(lvl, 1, 1, 1)
    else
      GameTooltip:AddDoubleLine(who, lvl, c and c.r or 1, c and c.g or 1, c and c.b or 1, 1, 1, 1)
    end
  end
  local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(m.map)
  if info and info.name then GameTooltip:AddLine(info.name, 0.8, 0.8, 0.8) end
  GameTooltip:AddLine(L["Guild member"], 0.4, 0.8, 1)
  GameTooltip:Show()
end
local function onLeave() if GameTooltip then GameTooltip:Hide() end end
local function acquire(parent)
  used = used + 1
  local pin = pool[used]
  if not pin then
    pin = CreateFrame("Frame", nil, parent)
    pin.tex = pin:CreateTexture(nil, "OVERLAY")
    pin.tex:SetAllPoints()
    if pin.tex.SetAtlas and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("PlayerPartyBlip") then
      pin.tex:SetAtlas("PlayerPartyBlip")
    else
      FLT.SetTex(pin.tex, (FLT.UI and FLT.UI.ASSET_ROOT or "Interface\\AddOns\\OneForAll\\Assets\\") .. "gem_fill")
    end
    pin:EnableMouse(true)
    pin:SetScript("OnEnter", onEnter); pin:SetScript("OnLeave", onLeave)
    pool[used] = pin
  end
  return pin
end
local function hideAll()
  for i = 1, used do pool[i]:Hide(); pool[i].m = nil end
  used = 0
end

-- members in your party / raid are left out: the game shows them on the map already (user 09.11.)
local function inGroup(name)
  if not (IsInGroup and IsInGroup()) then return false end
  local n = Ambiguate and Ambiguate(name, "none") or name
  return (UnitInParty and UnitInParty(n)) or (UnitInRaid and UnitInRaid(n)) and true or false
end
local CONT = Enum and Enum.UIMapType and Enum.UIMapType.Continent or 2
local function where(m, shown)
  if m.map == shown then return m.x, m.y end
  if not (m.cont and m.world and C_Map.GetMapPosFromWorldPos) then return end
  local ok, _, pos = pcall(C_Map.GetMapPosFromWorldPos, m.cont, m.world, shown)
  if not (ok and pos) then return end
  local x, y
  if pos.GetXY then x, y = pos:GetXY() else x, y = pos.x, pos.y end
  if x and y and x >= 0 and x <= 1 and y >= 0 and y <= 1 then return x, y end
end
local function drawMember(m, name, shown, child, w, h, scale, level, size)
  if inGroup(name) then return end
  local x, y = where(m, shown)
  if not x then return end
  local pin = acquire(child)
  pin.m, pin.name = m, name
  local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[m.cls]
  pin.tex:SetVertexColor(c and c.r or 1, c and c.g or 1, c and c.b or 1)
  pin:SetSize(size, size); pin:SetScale(scale); pin:SetFrameLevel(level + 1)
  pin:ClearAllPoints()
  pin:SetPoint("CENTER", child, "TOPLEFT", x * w / scale, -y * h / scale)
  pin.cx, pin.cy, pin.reach = x * w, y * h, size * scale -- where it sits on the map, for the shared tooltip
  pin:Show()
end
function GM.Refresh()
  hideAll()
  if not (WorldMapFrame and WorldMapFrame:IsShown() and on()) then return end
  local shown = WorldMapFrame.GetMapID and WorldMapFrame:GetMapID()
  local info = shown and C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(shown)
  if not (info and (info.mapType or 0) >= CONT) then return end -- not the whole world / cosmic map
  local LM = FLT.MapLandmarks
  local child, w, h, scale, level
  if LM and LM.Canvas then child, w, h, scale, level = LM.Canvas() end
  if not child then return end
  local size = info.mapType == CONT and SIZE_CONT or SIZE
  local t = now()
  for name, m in pairs(members) do
    if m.map and t - (m.t or 0) <= FORGET then
      drawMember(m, name, shown, child, w, h, scale, level, size)
    end
  end
  for name, m in pairs(openMapMembers) do
    local native = members[name]
    -- A fresh OneForAll report also takes precedence when it places the member inside a dungeon.
    if t - m.t <= OPENMAP_FORGET and (not native or t - native.t > FORGET) then
      drawMember(m, name, shown, child, w, h, scale, level, size)
    end
  end
end
-- guild members inside one of these dungeons (the entries of one entrance): names, sorted; a reused table
local inside = {}
function GM.Inside(dungeons)
  wipe(inside)
  if not on() or not dungeons then return inside end
  local t = now()
  for name, m in pairs(members) do
    if m.inst and t - (m.t or 0) <= FORGET then
      for _, d in ipairs(dungeons) do if d.key == m.inst then inside[#inside + 1] = name; break end end
    end
  end
  table.sort(inside)
  return inside
end
function GM.Member(name) return members[name] end

local function redraw()
  GM.Refresh()
  if lmDirty then
    lmDirty = false
    local LM = FLT.MapLandmarks
    if LM and LM.Refresh and WorldMapFrame and WorldMapFrame:IsShown() then LM.Refresh() end
  end
end
local pending = false
refreshSoon = function()
  if pending or not (WorldMapFrame and WorldMapFrame:IsShown()) then return end
  pending = true
  if C_Timer and C_Timer.After then C_Timer.After(1, function() pending = false; redraw() end)
  else pending = false; redraw() end
end

-- ---------------------------------------------------------------------------
-- switching
-- ---------------------------------------------------------------------------
local ticker
local function tick()
  local t = now()
  for name, m in pairs(members) do
    if t - (m.t or 0) > FORGET then members[name] = nil; if m.inst then lmDirty = true end end
  end
  for name, m in pairs(openMapMembers) do
    if t - m.t > OPENMAP_FORGET then openMapMembers[name] = nil end
  end
  sendPosition()
  if WorldMapFrame and WorldMapFrame:IsShown() then redraw() end
end
local ev = CreateFrame("Frame")
ev:SetScript("OnEvent", function(_, event, prefix, msg, channel, sender)
  if event == "CHAT_MSG_ADDON" then
    if channel ~= "GUILD" then return end
    if prefix == PREFIX then GM.Receive(msg, sender)
    elseif prefix == OPENMAP_PREFIX then receiveOpenMap(msg, sender) end
  elseif event == "PLAYER_GUILD_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
    GM.Apply()
  end
end)
ev:RegisterEvent("PLAYER_GUILD_UPDATE"); ev:RegisterEvent("PLAYER_ENTERING_WORLD")
local hooked, registered
function GM.Apply()
  if on() then
    if not registered and C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
      registered = true
      pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)
      pcall(C_ChatInfo.RegisterAddonMessagePrefix, OPENMAP_PREFIX)
    end
    ev:RegisterEvent("CHAT_MSG_ADDON")
    if not ticker and C_Timer and C_Timer.NewTicker then
      ticker = C_Timer.NewTicker(SEND_EVERY, tick)
      send("Q") -- the others answer with their next tick
    end
    if not hooked and WorldMapFrame and WorldMapFrame.HookScript then
      hooked = true
      WorldMapFrame:HookScript("OnShow", function() GM.Refresh() end)
      WorldMapFrame:HookScript("OnHide", hideAll)
      if WorldMapFrame.OnMapChanged then hooksecurefunc(WorldMapFrame, "OnMapChanged", GM.Refresh) end
      if WorldMapFrame.OnCanvasScaleChanged then hooksecurefunc(WorldMapFrame, "OnCanvasScaleChanged", GM.Refresh) end
    end
    sendPosition()
  else
    if not gone then send("X"); gone = true; last.map = nil end
    if ticker then ticker:Cancel(); ticker = nil end
    pcall(ev.UnregisterEvent, ev, "CHAT_MSG_ADDON")
    if next(members) then lmDirty = true end
    wipe(members)
    wipe(openMapMembers)
  end
  redraw()
end

local login = CreateFrame("Frame")
login:RegisterEvent("PLAYER_LOGIN")
login:SetScript("OnEvent", function(self)
  self:UnregisterAllEvents()
  if FLT.QoL and FLT.QoL.On then FLT.QoL.On("guildMap", GM.Apply) end
  if FLT.SafeCall then FLT.SafeCall("MapGuild", GM.Apply) else pcall(GM.Apply) end
end)
