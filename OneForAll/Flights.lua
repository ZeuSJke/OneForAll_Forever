local _, FLT = ...
local L = FLT.L or setmetatable({}, { __index = function(_, k) return k end }) -- (tests without Locales)

-- Flight times (6.1.5, user 05.11.): from the length of the flight paths in the client data (Data/FlightPaths.lua,
-- yards / taxi speed, summed over the stops of the route), corrected by the flights you take: per route "From>To" the
-- measured time is kept in OneForAllDB.flightTimes and used first; the ratio measured / computed
-- (OneForAllDB.flightFactor) corrects the other routes. Without path data: an estimate from the straight distance on
-- the flight map (OneForAllDB.flightPace), marked "about".
-- Shows: a small bar with the destination and the time left while flying, and the time in the tooltip of the
-- destinations on the flight map. Option "Flight times" (QoL > World Map). A 1 s ticker runs only while flying.
-- 6.2.18-beta5 (user 26.11.2026 22:39: "das endziel und den naechsten zwischenstopp ... den button ... damit er einen raus
-- laesst"): the bar names the destination and, on a route over several flight masters, the next stop with its time; its
-- button asks the game to land at the next flight master (TaxiRequestEarlyLanding, the call of the game's own "Request Stop").

local Q = FLT.QoL
local function on() return Q and Q.Get and Q.Get("flightTimes") end
local function db()
  if type(OneForAllDB) ~= "table" then return nil end
  OneForAllDB.flightTimes = OneForAllDB.flightTimes or {}
  return OneForAllDB
end

-- the flight map: name and position of the node you stand at, and of node i
local function currentNode()
  if not (NumTaxiNodes and TaxiNodeGetType) then return nil end
  for i = 1, NumTaxiNodes() do
    if TaxiNodeGetType(i) == "CURRENT" then return i end
  end
end
local function nodeName(i) local n = TaxiNodeName and TaxiNodeName(i); return type(n) == "string" and n or nil end
-- node ID of flight map slot i (user 05.11.: the German client has other node names - Undercity -> Silverpine counted
-- up): from C_TaxiMap.GetAllTaxiNodes of the flight map, else the English name
local slotIDs, slotMap = {}, nil
local function nodeID(i)
  if not i then return nil end
  local map = GetTaxiMapID and GetTaxiMapID()
  if map ~= slotMap then
    wipe(slotIDs); slotMap = map
    local ok, list = pcall(function() return map and C_TaxiMap and C_TaxiMap.GetAllTaxiNodes and C_TaxiMap.GetAllTaxiNodes(map) end)
    if ok and type(list) == "table" then
      for _, n in ipairs(list) do if n.slotIndex and n.nodeID then slotIDs[n.slotIndex] = n.nodeID end end
    end
  end
  return slotIDs[i] or (FLT.FLIGHT_NODES and FLT.FLIGHT_NODES[nodeName(i) or ""])
end
local function dist(a, b)
  if not TaxiNodePosition then return nil end
  local ax, ay = TaxiNodePosition(a); local bx, by = TaxiNodePosition(b)
  if not (ax and bx) then return nil end
  return math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2)
end

-- seconds of a route from the path data: each stop of the route (GetNumRoutes / TaxiGetNodeSlot), or the direct path
local SPEED, OVERHEAD = 30, 3 -- taxi speed in yards per second; take-off and landing
local function pathSecs(a, b)
  local p = a and b and FLT.FLIGHT_PATHS and FLT.FLIGHT_PATHS[a] and FLT.FLIGHT_PATHS[a][b]
  if not p then return nil end
  if type(p) == "table" then return p[1] / SPEED + (p[2] or 0) / 1000 end
  return p / SPEED
end
local function dataTime(i, from, to)
  local total
  local ok, n = pcall(function() return GetNumRoutes and GetNumRoutes(i) end)
  if ok and n and n > 0 and TaxiGetNodeSlot then
    total = 0
    for r = 1, n do
      local s = pathSecs(nodeID(TaxiGetNodeSlot(i, r, true)), nodeID(TaxiGetNodeSlot(i, r, false)))
      if not s then total = nil; break end
      total = total + s
    end
  end
  total = total or pathSecs(nodeID(currentNode()), nodeID(i))
  return total and (total + OVERHEAD)
end

-- seconds for node i from here: measured, from the path data, or estimated ("about"); nil = nothing known
local function timeTo(i)
  local d = db(); local cur = currentNode()
  if not (d and cur) or i == cur then return nil end
  local from, to = nodeName(cur), nodeName(i)
  if not (from and to) then return nil end
  local t = d.flightTimes[from .. ">" .. to]
  if t then return t, false end
  local raw = dataTime(i, from, to)
  if raw then return raw * (d.flightFactor or 1), false, raw end
  local pace, dd = d.flightPace, dist(cur, i)
  if pace and dd and dd > 0 then return dd * pace, true end
end
local function fmt(s) s = math.floor(s + 0.5); return string.format("%d:%02d", math.floor(s / 60), s % 60) end
FLT.FlightTimeTo = timeTo -- tests

-- the flight that was picked, and the one in the air
local picked, flight
-- the stops of the route to node i: { {name, at = share of the whole flight when it is reached}, ... } (the last one is the
-- destination); by the path data of each leg, else by the map distance; nil for a direct flight
local function routeStops(i)
  local ok, n = pcall(function() return GetNumRoutes and GetNumRoutes(i) end)
  if not (ok and n and n > 1 and TaxiGetNodeSlot) then return nil end
  local stops, sum, byDist = {}, 0, false
  for r = 1, n do
    local a, b = TaxiGetNodeSlot(i, r, true), TaxiGetNodeSlot(i, r, false)
    local len = pathSecs(nodeID(a), nodeID(b))
    if not len then byDist = true end
    stops[r] = { name = nodeName(b), len = len, d = dist(a, b) or 1 }
  end
  for _, st in ipairs(stops) do st.len = byDist and st.d or st.len; sum = sum + st.len end
  if sum <= 0 then return nil end
  local acc = 0
  for _, st in ipairs(stops) do acc = acc + st.len; st.at = acc / sum; st.len, st.d = nil, nil end
  return stops
end
local function onTake(i)
  if not on() then return end
  local cur = currentNode()
  local from, to = cur and nodeName(cur), nodeName(i)
  if not (from and to) then return end
  local est, about, raw = timeTo(i)
  picked = { from = from, to = to, d = cur and dist(cur, i), est = est, about = about, raw = raw, stops = routeStops(i) }
end
if hooksecurefunc and TakeTaxiNode then hooksecurefunc("TakeTaxiNode", function(i) FLT.SafeCall("Flights", onTake, i) end) end

-- the small window while flying (user 05.11.): the flight master icon, the destination and the time left; drag to move
-- (kept in OneForAllDB.qol.flightPos). 6.2.18-beta5/6 (user 26.11.2026 22:51: "der knopf sollte in unserem stil sein ... und ein
-- schoenerer aufbau"): destination (gold) and time (large) on top, below the next stop of the route (or the destination's zone),
-- at the bottom a progress line with a mark for each stop; the gold button on the right asks to land at the next flight master
local bar
local W, PAD, H = 210, 7, 44 -- 6.2.18-beta7 (user 26.11. 22:58: "kompakter ... zu gross"): was 244 x 54
local function short(name) return name and (name:match("^(.-),%s") or name) end -- "Camp Taurajo, The Barrens" -> "Camp Taurajo"
local function zoneOf(name) return name and name:match(",%s*(.+)$") end
local function nextStop(f, t)
  if not (f and f.stops and f.est) then return nil end
  for k = 1, #f.stops - 1 do
    local st = f.stops[k]
    if st.at * f.est > t then return st, st.at * f.est - t end
  end
end
local function requestStop()
  if not (flight and TaxiRequestEarlyLanding) then return end
  TaxiRequestEarlyLanding()
  flight.noKeep = true -- a flight cut short is not a measured time for its route
  local st = nextStop(flight, (GetTime and GetTime() or 0) - flight.start)
  flight.landAt = st and st.name or true
  flight.landT = st and st.at * flight.est -- the time left counts to that stop
  if bar and bar.stop.SetLook then bar.stop:SetLook(false); bar.stop:Disable() end
end
local function makeBar()
  local UI = FLT.UI
  bar = CreateFrame("Frame", "OneForAllFlightTimer", UIParent)
  bar:SetSize(W, H); bar:SetFrameStrata("MEDIUM"); bar:SetClampedToScreen(true)
  bar:SetMovable(true); bar:EnableMouse(true); bar:RegisterForDrag("LeftButton")
  local pos = Q and Q.Get and Q.Get("flightPos")
  if type(pos) == "table" then bar:SetPoint("CENTER", UIParent, "BOTTOMLEFT", pos[1], pos[2]) else bar:SetPoint("TOP", UIParent, "TOP", 0, -110) end
  if UI and UI.FramedPanel then UI.FramedPanel(bar) end
  -- 6.2.18-beta8 (user 26.11. 23:04, his sketch: "die zeiten auch direkt untereinander"): the icon on a dark square, the
  -- times in one column on the right (time left on top, time to the next stop in gold below)
  bar.iconBG = (UI.makeTexture or function(p, l) return p:CreateTexture(nil, l) end)(bar, "ARTWORK", 0, 0, 0, 0.45)
  bar.iconBG:SetSize(26, 26); bar.iconBG:SetPoint("TOPLEFT", PAD, -5)
  bar.icon = bar:CreateTexture(nil, "OVERLAY"); bar.icon:SetSize(22, 22); bar.icon:SetPoint("CENTER", bar.iconBG, "CENTER")
  FLT.SetTex(bar.icon, "Interface\\Minimap\\Tracking\\FlightMaster")
  -- our gold button with a "down to land" arrow (Assets/icon_land.tga = the quest share arrow turned)
  bar.stop = UI.GoldButton(bar, "", 22, 20, UI.ASSET_ROOT .. "icon_land", 11); bar.stop:SetPoint("TOPRIGHT", -PAD, -7)
  bar.stop:SetScript("OnClick", function() FLT.SafeCall("Flights", requestStop) end)
  bar.stop:HookScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM"); GameTooltip:AddLine(L["Request stop"], 1, 0.82, 0)
    GameTooltip:AddLine(L["Land at the next flight master on the route."], 1, 1, 1, true); GameTooltip:Show()
  end)
  bar.stop:HookScript("OnLeave", function() GameTooltip:Hide() end)
  bar.text = FLT.NewFS(bar, nil, "OVERLAY", "GameFontHighlight"); bar.text:SetPoint("TOPRIGHT", bar.stop, "TOPLEFT", -6, 1)
  bar.text:SetJustifyH("RIGHT")
  do local font, _, flags = bar.text:GetFont(); if font then bar.text:SetFont(font, 14, flags) end end
  bar.ntime = FLT.NewFS(bar, nil, "OVERLAY", "GameFontHighlightSmall"); bar.ntime:SetPoint("TOPRIGHT", bar.text, "BOTTOMRIGHT", 0, -1)
  bar.ntime:SetJustifyH("RIGHT"); bar.ntime:SetTextColor(1, 0.82, 0.38)
  bar.dest = FLT.NewFS(bar, nil, "OVERLAY", "GameFontNormal"); bar.dest:SetPoint("TOPLEFT", bar.iconBG, "TOPRIGHT", 6, -1)
  bar.dest:SetJustifyH("LEFT"); bar.dest:SetWordWrap(false); if FLT.TextC then bar.dest:SetTextColor(FLT.TextC(1, 0.82, 0.25)) else bar.dest:SetTextColor(1, 0.82, 0.25) end
  bar.next = FLT.NewFS(bar, nil, "OVERLAY", "GameFontHighlightSmall"); bar.next:SetPoint("TOPLEFT", bar.dest, "BOTTOMLEFT", 0, -1)
  bar.next:SetJustifyH("LEFT"); bar.next:SetWordWrap(false); bar.next:SetTextColor(0.72, 0.72, 0.72)
  -- the progress line: a dark track, the gold part flown so far, a small mark for every stop
  local mk = UI.makeTexture or function(p, layer, r, g, b, a) local t = p:CreateTexture(nil, layer); t:SetColorTexture(r, g, b, a); return t end
  bar.track = mk(bar, "ARTWORK", 0, 0, 0, 0.55); bar.track:SetHeight(3)
  bar.track:SetPoint("BOTTOMLEFT", PAD, 5); bar.track:SetPoint("BOTTOMRIGHT", -PAD, 5)
  bar.fill = mk(bar, "OVERLAY", 1, 0.78, 0.25, 0.95); bar.fill:SetHeight(3); bar.fill:SetPoint("LEFT", bar.track, "LEFT")
  bar.ticks = {}
  bar.mk = mk
  bar:SetScript("OnDragStart", function(self) self:StartMoving() end)
  bar:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local x, y = self:GetCenter()
    if x and y and Q and Q.Set then Q.Set("flightPos", { math.floor(x + 0.5), math.floor(y + 0.5) }) end
  end)
  bar:SetScript("OnEnter", function(self)
    if not flight then return end
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM"); GameTooltip:AddLine(flight.to, 1, 0.82, 0)
    if flight.stops then
      for k = 1, #flight.stops - 1 do GameTooltip:AddLine(flight.stops[k].name or "?", 0.85, 0.85, 0.85) end
    end
    GameTooltip:AddLine(L["Drag to move."], 0.75, 0.75, 0.75); GameTooltip:Show()
  end)
  bar:SetScript("OnLeave", function() GameTooltip:Hide() end)
  bar:Hide()
end
-- the stop marks on the progress line (once per flight, at takeoff)
local function placeTicks(f)
  for _, tk in ipairs(bar.ticks) do tk:Hide() end
  if not (f and f.stops) then return end
  local tw = W - 2 * PAD
  for k = 1, #f.stops - 1 do
    local tk = bar.ticks[k]
    if not tk then tk = bar.mk(bar, "OVERLAY", 1, 0.93, 0.70, 1); tk:SetSize(2, 7); bar.ticks[k] = tk end
    tk:ClearAllPoints(); tk:SetPoint("CENTER", bar.track, "LEFT", math.floor(f.stops[k].at * tw + 0.5), 0); tk:Show()
  end
end
local ticker
local function paint()
  if not (flight and bar) then return end
  local f = flight
  local t = (GetTime and GetTime() or 0) - f.start
  if f.est then
    local left = math.max(0, (f.landT or f.est) - t)
    bar.text:SetText((f.about and "~" or "") .. fmt(left))
    bar.fill:SetWidth(math.max(1, (W - 2 * PAD) * math.min(1, t / f.est))); bar.fill:Show()
  else
    bar.text:SetText("|cff9d9d9d" .. fmt(t) .. "|r")
    bar.fill:Hide()
  end
  bar.dest:SetText(short(f.to))
  -- the line below: where it lands after "Request stop", the next stop of the route, or the destination's zone
  local line, ntime
  if f.landAt then
    line = f.landAt == true and L["Landing at the next flight master"] or string.format(L["Landing at %s"], short(f.landAt))
  else
    local st, inSecs = nextStop(f, t)
    if st then line, ntime = string.format(L["Next: %s"], "|cffffffff" .. (short(st.name) or "?") .. "|r"), fmt(inSecs)
    else line = zoneOf(f.to) end
  end
  bar.next:SetText(line or ""); bar.ntime:SetText(ntime or "")
  -- the names take the room the time column leaves (both lines end before the wider of the two times)
  local tw = math.max(bar.text:GetStringWidth() or 36, ntime and bar.ntime:GetStringWidth() or 0)
  local room = math.max(40, W - PAD - 26 - 6 - tw - 6 - 22 - PAD - 4)
  bar.dest:SetWidth(room); bar.next:SetWidth(room)
  for k, tk in ipairs(bar.ticks) do -- passed stops fade
    local st = f.stops and f.stops[k]
    if st and f.est then tk:SetAlpha(st.at * f.est <= t and 0.35 or 1) end
  end
  bar.stop:SetShown(TaxiRequestEarlyLanding ~= nil)
end
FLT.FlightNow = function() return flight, nextStop, requestStop end -- tests
local function stopTicker() if ticker then ticker:Cancel(); ticker = nil end end
local function landed()
  stopTicker()
  if bar then bar:Hide() end
  local f = flight; flight = nil
  if not f then return end
  local t = (GetTime and GetTime() or 0) - f.start
  local d = db()
  if not d or t < 5 or f.noKeep then return end
  -- a flight far off its estimate was cut short or broke off (e.g. a disconnect): not kept
  if f.est and not f.about and (t < f.est * 0.6 or t > f.est * 1.6) then return end
  local key = f.from .. ">" .. f.to
  local old = d.flightTimes[key]
  d.flightTimes[key] = old and (old * 0.5 + t * 0.5) or t
  if f.raw and f.raw > 0 then -- how far the path data is off (taxi speed, stops): corrects the other routes
    local k = t / f.raw
    if k > 0.6 and k < 1.6 then d.flightFactor = d.flightFactor and (d.flightFactor * 0.8 + k * 0.2) or k end
  end
  if f.d and f.d > 0 then
    local pace = t / f.d
    d.flightPace = d.flightPace and (d.flightPace * 0.8 + pace * 0.2) or pace
  end
end
local function takeOff()
  if not (picked and on()) then return end
  flight = picked; picked = nil
  flight.start = GetTime and GetTime() or 0
  if not bar then makeBar() end
  bar.stop:Enable(); if bar.stop.SetLook then bar.stop:SetLook(true) end
  placeTicks(flight)
  -- no time known for this route (user 05.11.: counting up looked wrong): no window, the flight is still measured
  paint(); bar:SetShown(flight.est and true or false)
  stopTicker()
  -- every second: paint, and notice the landing (user 05.11.: the window stayed - the control event alone is not
  -- reliable on the live client)
  if C_Timer and C_Timer.NewTicker then
    ticker = C_Timer.NewTicker(1, function()
      local f = flight
      if not f then return end
      local t = (GetTime and GetTime() or 0) - f.start
      -- landed: off the taxi, or (user 05.11.: the window stayed - UnitOnTaxi did not change on the live client) no
      -- longer moving at taxi speed (taxis fly about 30 yards/s, running or riding is below 20); fallback: well past
      -- the expected time
      local speed = GetUnitSpeed and GetUnitSpeed("player")
      if type(speed) == "number" and speed >= 20 then f.fast = true end -- the speed rule only once it was seen flying fast
      local off = (UnitOnTaxi and not UnitOnTaxi("player"))
        or (f.fast and type(speed) == "number" and speed < 20)
      if off then FLT.SafeCall("Flights", landed)
      elseif f.est and t > f.est + 15 then f.noKeep = true; FLT.SafeCall("Flights", landed) -- landing not seen: not kept
      else paint() end
    end)
  end
end

-- the flight map tooltip (classic TaxiFrame buttons)
local function tipFor(button)
  if not on() or not (button and button.GetID) then return end
  local t, about = timeTo(button:GetID())
  if not t then return end
  GameTooltip:AddLine(string.format(about and L["Flight time: about %s"] or L["Flight time: %s"], fmt(t)), 1, 0.82, 0)
  GameTooltip:Show()
end
if hooksecurefunc and type(TaxiNodeOnButtonEnter) == "function" then
  hooksecurefunc("TaxiNodeOnButtonEnter", function(b) FLT.SafeCall("Flights", tipFor, b) end)
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED", "PLAYER_ENTERING_WORLD" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function(_, event)
  FLT.SafeCall("Flights", function()
    if event == "PLAYER_CONTROL_LOST" then
      if C_Timer and C_Timer.After then
        C_Timer.After(0.5, function() if UnitOnTaxi and UnitOnTaxi("player") then takeOff() end end)
      end
    elseif event == "PLAYER_CONTROL_GAINED" and flight and C_Timer and C_Timer.After then
      C_Timer.After(0.5, function() if flight and not (UnitOnTaxi and UnitOnTaxi("player")) then landed() end end)
    elseif flight and not (UnitOnTaxi and UnitOnTaxi("player")) then
      landed()
    end
  end)
end)
