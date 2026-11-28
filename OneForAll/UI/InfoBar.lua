local _, FLT = ...

-- Quality of Life "infoBar" (6.2.2, user 08.11.2026): a band at the top middle of the screen, "like Titan Panel, only
-- nicer" - idea only, own code. Off by default; it starts empty and the player adds the elements he wants (right-click
-- the band). Pinned it stays open; unpinned it folds up to a small handle and opens while the mouse is on it.
-- It never moves Blizzard frames (the minimap / Edit Mode trouble of 6.2.0).
-- Lean: events only for the chosen elements and only while the bar is on; changes are gathered and drawn once (0.2 s);
-- the one 1 s ticker runs only while the band is open and an element needs it (clock, FPS, location, hearthstone).
-- Settings: OneForAllDB.qol.infoBar (on), .infoBarItems { element keys in order }, .infoBarPinned;
-- gold per character for the gold tooltip: OneForAllDB.infoGold[FLT.CharKey()] = { copper, class token, name =, realm = }
-- (6.2.5: GUID key, Core.lua; old entries "Realm|Name").

local L = FLT.L or setmetatable({}, { __index = function(_, k) return k end }) -- (tests without Locales)
local function N(s) return s end
local IB = {}
FLT.InfoBar = IB
local UI = FLT.UI
local floor, max, fmt = math.floor, math.max, string.format
local unpack = unpack or table.unpack

local function db() return type(OneForAllDB) == "table" and OneForAllDB.qol or nil end
local function on() local d = db(); return d and d.infoBar == true end
-- the look from Quality of Life (6.2.2-beta43, user 09.11.): qol.infoBarColor { r, g, b } tints the background only
-- (the gold line stays), qol.infoBarAlpha (10 - 100 %) is the whole bar; nil = the defaults
local DEFAULT_COLOR = { 11 / 255, 10 / 255, 9 / 255 }
IB.DEFAULT_COLOR = DEFAULT_COLOR
local function barColor()
  local c = db() and db().infoBarColor
  if type(c) == "table" and tonumber(c[1]) and tonumber(c[2]) and tonumber(c[3]) then return c[1], c[2], c[3] end
  return DEFAULT_COLOR[1], DEFAULT_COLOR[2], DEFAULT_COLOR[3]
end
local function barAlpha()
  local d = db()
  return math.max(0.1, math.min(1, (tonumber(d and d.infoBarAlpha) or 100) / 100))
end
local function call(fn, ...) if type(fn) ~= "function" then return nil end local ok, a, b, c, d = pcall(fn, ...); if ok then return a, b, c, d end end
local function inCombat() return InCombatLockdown and InCombatLockdown() end
local function money(c) return FLT.QoL and FLT.QoL.Money and FLT.QoL.Money(c) or tostring(c) end
local function grey(s) return "|cff9d9d9d" .. s .. "|r" end
-- a tab of the OneForAll window: open it with the tab sound, a second click closes the window (user 08.11.: like the
-- game's own windows)
local function togglePanel(key)
  if not FLT.OpenPanel then return end
  if UI.IsWindowShown and UI.IsWindowShown() and UI.ActiveTab and UI.ActiveTab() == key and FLT.ToggleUI then FLT:ToggleUI(); return end
  if PlaySound and type(SOUNDKIT) == "table" and SOUNDKIT.IG_CHARACTER_INFO_TAB then pcall(PlaySound, SOUNDKIT.IG_CHARACTER_INFO_TAB) end
  FLT:OpenPanel(key)
end

-- class reagents (the one each class needs most); hunters: the ammo in the ammo slot
local REAGENT = { WARLOCK = 6265, MAGE = 17020, PRIEST = 17029, DRUID = 17026, SHAMAN = 17030, ROGUE = 5140, PALADIN = 21177 }

-- Elements -----------------------------------------------------------------------------------------------------------
-- key, label (N), icon, events, tick (needs the 1 s ticker), text() -> string, tip(tt), click()
local E = {}
IB.E = E -- (tests)
local ORDER = {}
local function add(e) E[e.key] = e; ORDER[#ORDER + 1] = e.key end

-- 12 or 24 hours like the game's clock (its "24-hour mode" setting; 6.2.10, asked 4 times in #help)
local function clockText(h, m)
  if not (GetCVarBool and GetCVarBool("timeMgrUseMilitaryTime") == false) then return fmt("%02d:%02d", h, m) end
  local ap = h >= 12 and (TIMEMANAGER_PM or "PM") or (TIMEMANAGER_AM or "AM")
  h = h % 12
  return fmt("%d:%02d %s", h == 0 and 12 or h, m, ap)
end
local function localClock() return clockText(tonumber(date("%H")) or 0, tonumber(date("%M")) or 0) end
add({ key = "clock", label = N"Clock", icon = "Interface\\Icons\\INV_Misc_PocketWatch_01", noIcon = true, tick = true, -- no icon on the bar (user 08.11.)
  text = localClock,
  tip = function(tt)
    tt:AddDoubleLine(L["Local time"], localClock(), 1, 0.82, 0, 1, 1, 1)
    local h, m = call(GetGameTime)
    if h then tt:AddDoubleLine(L["Server time"], clockText(h, m), 1, 0.82, 0, 1, 1, 1) end
  end,
  click = function() if TimeManager_Toggle then call(TimeManager_Toggle) end end })

add({ key = "fps", label = N"FPS and latency", icon = "Interface\\Icons\\INV_Gizmo_02", tick = true,
  text = function()
    local fps = floor((call(GetFramerate) or 0) + 0.5)
    local _, _, home, world = call(GetNetStats)
    return fmt("%d fps  %d ms", fps, max(home or 0, world or 0))
  end,
  tip = function(tt)
    local _, _, home, world = call(GetNetStats)
    tt:AddDoubleLine(L["Latency (home)"], fmt("%d ms", home or 0), 1, 0.82, 0, 1, 1, 1)
    tt:AddDoubleLine(L["Latency (world)"], fmt("%d ms", world or 0), 1, 0.82, 0, 1, 1, 1)
  end })

local sessionStart, moneyEvent, goldSaved
-- 6.2.14 (Discord yanthir 22.11.: "This session" stayed +0 after gold came in): the start amount is read at login, not at the
-- bar's first redraw (that could come only with the first money); a 0 read too early waits for the first PLAYER_MONEY
do
  local f = CreateFrame("Frame")
  f:RegisterEvent("PLAYER_ENTERING_WORLD")
  f:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    local function take() if not sessionStart and GetMoney and (GetMoney() or 0) > 0 then sessionStart = GetMoney() end end
    take()
    if C_Timer and C_Timer.After then C_Timer.After(2, take) end
  end)
end
-- 6.2.5 (Discord amalae. 11.11.: every alt had 0 gold): the money read too early after login or at logout can be 0 -
-- a 0 replaces a stored amount only after a PLAYER_MONEY event (the money really changed); nothing saved at logout
local function saveGold()
  if type(OneForAllDB) ~= "table" or not GetMoney or not FLT.CharKey then return end
  OneForAllDB.infoGold = OneForAllDB.infoGold or {}
  local t, c = OneForAllDB.infoGold, GetMoney() or 0
  local legacy = (GetRealmName and GetRealmName() or "?") .. "|" .. (UnitName("player") or "?")
  local old = t[FLT.CharKey()]
  if c == 0 and not moneyEvent and type(old) == "table" and (old[1] or 0) > 0 then return end
  local _, cls = UnitClass("player")
  FLT.CharSave(t, { c, cls }, legacy)
end
-- gold / bag slots open the bags: with the combined bag a secure click on the game's backpack button (6.2.10, Discord
-- kaanu 15.11.: ToggleAllBags from our code tainted the combined bag - with a controller the pad controls broke until
-- /reload); separate bags keep the ordinary click (the backpack button opens only the backpack there)
local function bagButton()
  local on
  pcall(function()
    if ContainerFrameSettingsManager and ContainerFrameSettingsManager.IsUsingCombinedBags then
      on = ContainerFrameSettingsManager:IsUsingCombinedBags()
    elseif C_CVar and C_CVar.GetCVarBool then on = C_CVar.GetCVarBool("combinedBags") end
  end)
  if on then return "MainMenuBarBackpackButton" end
end
add({ key = "gold", label = N"Gold", icon = "Interface\\Icons\\INV_Misc_Coin_02", events = { "PLAYER_MONEY", "PLAYER_LOGOUT" },
  text = function()
    local c = GetMoney and GetMoney() or 0
    if not sessionStart and (c > 0 or moneyEvent) then sessionStart = c end
    saveGold()
    return money(c - c % 100) -- gold and silver are enough here
  end,
  tip = function(tt)
    local c = GetMoney and GetMoney() or 0
    local diff = c - (sessionStart or c)
    tt:AddDoubleLine(L["This session"], (diff < 0 and "-" or "+") .. money(math.abs(diff)), 1, 0.82, 0,
      diff < 0 and 1 or 0.3, diff < 0 and 0.3 or 1, 0.3)
    local all, total, realm = {}, 0, GetRealmName and GetRealmName() or "?"
    local t = type(OneForAllDB) == "table" and OneForAllDB.infoGold or {}
    -- 6.2.18 (Discord leyssa 26.11.: RP and normal rule set characters were listed together): realms of both rule sets carry
    -- the same name, the server number in the GUID ("Player-<server>-<id>") tells them apart; old name keys stay in the list
    local server = tostring(FLT.CharKey and FLT.CharKey() or ""):match("^Player%-(%d+)%-")
    for k, v in pairs(t) do
      local _, r, cls = FLT.CharOf(k, v)
      local ks = tostring(k):match("^Player%-(%d+)%-")
      if r == realm and type(v) == "table" and not (server and ks and ks ~= server) then
        -- the full name with the surname when we know it (Discord leyssa 26.11.)
        local full = type(v.full) == "string" and v.full:gsub("%-.*$", "") or nil
        local label = (full and full:find(" ", 1, true)) and full or FLT.CharLabel(t, k, v)
        all[#all + 1] = { label, v[1] or 0, cls }; total = total + (v[1] or 0)
      end
    end
    if #all > 1 then
      table.sort(all, function(a, b) return a[2] > b[2] end)
      tt:AddLine(" "); tt:AddLine(L["Characters on this realm"], 1, 0.82, 0)
      for _, a in ipairs(all) do
        local cc = RAID_CLASS_COLORS and a[3] and RAID_CLASS_COLORS[a[3]]
        tt:AddDoubleLine(a[1], money(a[2]), cc and cc.r or 1, cc and cc.g or 1, cc and cc.b or 1, 1, 1, 1)
      end
      tt:AddDoubleLine(L["Total"], money(total), 1, 0.82, 0, 1, 1, 1)
    end
  end,
  click = function() if ToggleAllBags then call(ToggleAllBags) end end, secureClick = bagButton })

add({ key = "bags", label = N"Free bag slots", icon = "Interface\\Icons\\INV_Misc_Bag_08", events = { "BAG_UPDATE_DELAYED" },
  text = function()
    local free = FLT.QoL and FLT.QoL.FreeBagSlots and FLT.QoL.FreeBagSlots()
    if not free then return "?" end
    return free <= 2 and ("|cffff4040" .. free .. "|r") or tostring(free)
  end,
  click = function() if ToggleAllBags then call(ToggleAllBags) end end, secureClick = bagButton })

local SLOTS = { 1, 3, 5, 6, 7, 8, 9, 10, 16, 17, 18 }
local function durability()
  local low, list = nil, {}
  for _, s in ipairs(SLOTS) do
    local cur, mx = call(GetInventoryItemDurability, s)
    if cur and mx and mx > 0 then
      local p = cur / mx
      if not low or p < low then low = p end
      if p < 1 then list[#list + 1] = { s, p } end
    end
  end
  return low, list
end
-- secureClick: the character window is opened by a secure button that clicks the game's own micro button - opened from
-- our code it was tainted (user 08.11.: "attempt to compare a secret number value (execution tainted by 'OneForAll')")
add({ key = "durability", label = N"Durability", icon = "Interface\\Icons\\Trade_BlackSmithing", events = { "UPDATE_INVENTORY_DURABILITY" },
  secureClick = "CharacterMicroButton",
  text = function()
    local low = durability()
    if not low then return "100%" end
    local p = floor(low * 100 + 0.5)
    local col = p <= 20 and "|cffff4040" or (p <= 50 and "|cffffd040" or "")
    return col .. p .. "%" .. (col ~= "" and "|r" or "")
  end,
  tip = function(tt)
    local _, list = durability()
    for _, e in ipairs(list) do
      local link = call(GetInventoryItemLink, "player", e[1])
      tt:AddDoubleLine(link or "?", fmt("%d%%", floor(e[2] * 100 + 0.5)), 1, 1, 1, 1, 1, 1)
    end
  end,
  click = function() if not inCombat() and ToggleCharacter then call(ToggleCharacter, "PaperDollFrame") end end })

add({ key = "xp", label = N"Experience", icon = "Interface\\Icons\\INV_Misc_Book_09",
  events = { "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "UPDATE_EXHAUSTION", "QUEST_LOG_UPDATE" },
  text = function()
    local lvl, mx = UnitLevel("player") or 1, call(GetMaxPlayerLevel) or 60
    if lvl >= mx then return fmt(L["Level %d"], lvl) end
    local cur, need = UnitXP("player") or 0, max(1, UnitXPMax("player") or 1)
    local s = fmt("%d%%", floor(cur / need * 100))
    local rest = call(GetXPExhaustion)
    if rest and rest > 0 then s = s .. "  |cff6fa8ff+" .. floor(rest / need * 100) .. "%|r" end
    return s
  end,
  tip = function(tt)
    local cur, need = UnitXP("player") or 0, max(1, UnitXPMax("player") or 1)
    tt:AddDoubleLine(fmt(L["Level %d"], UnitLevel("player") or 1), fmt("%s / %s", BreakUpLargeNumbers and BreakUpLargeNumbers(cur) or cur,
      BreakUpLargeNumbers and BreakUpLargeNumbers(need) or need), 1, 0.82, 0, 1, 1, 1)
    local rest = call(GetXPExhaustion)
    if rest and rest > 0 then tt:AddDoubleLine(L["Rested"], BreakUpLargeNumbers and BreakUpLargeNumbers(rest) or rest, 0.44, 0.66, 1, 1, 1, 1) end
    local qxp, n = FLT.QoL and FLT.QoL.CompletedQuestXP and FLT.QoL.CompletedQuestXP()
    if qxp and qxp > 0 then tt:AddDoubleLine(fmt(L["Finished quests (%d)"], n or 0), "+" .. (BreakUpLargeNumbers and BreakUpLargeNumbers(qxp) or qxp), 0.3, 1, 0.3, 1, 1, 1) end
  end })

local function position()
  local map = C_Map and call(C_Map.GetBestMapForUnit, "player")
  local pos = map and C_Map.GetPlayerMapPosition and call(C_Map.GetPlayerMapPosition, map, "player")
  if pos and pos.GetXY then local x, y = pos:GetXY(); if x and (x > 0 or y > 0) then return x * 100, y * 100 end end
end
add({ key = "location", label = N"Location", icon = "Interface\\Icons\\INV_Misc_Map_01", tick = true, events = { "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA" },
  text = function()
    local zone = call(GetSubZoneText); if not zone or zone == "" then zone = call(GetZoneText) or "" end
    local x, y = position()
    return x and fmt("%s  %.1f, %.1f", zone, x, y) or zone
  end,
  tip = function(tt)
    tt:AddLine(call(GetZoneText) or "", 1, 0.82, 0)
    local sub = call(GetSubZoneText); if sub and sub ~= "" then tt:AddLine(sub, 1, 1, 1) end
  end,
  -- opened by the game's own map button (6.2.2, Discord kaanu: a map opened from addon code tainted the controller's close)
  secureClick = "QuestLogMicroButton", -- Forever has no WorldMapMicroButton (user 09.11.)
  click = function() if not inCombat() and ToggleWorldMap then call(ToggleWorldMap) end end })

-- (6.2.2-beta12: the professions element is gone - user 08.11.: "den alten profession raus schmeissen"; the Professions
-- tab is in "Addon tabs")

add({ key = "trainer", label = N"New trainer spells", icon = "Interface\\Icons\\INV_Misc_Book_11", events = { "PLAYER_LEVEL_UP", "SPELLS_CHANGED" },
  text = function()
    local n = FLT.TrainerSpellsDue and FLT.TrainerSpellsDue() or 0
    return n > 0 and ("|cff40ff40" .. n .. "|r") or grey("0")
  end,
  tip = function(tt)
    local n, list = 0, nil
    if FLT.TrainerSpellsDue then n, list = FLT.TrainerSpellsDue() end
    if n == 0 then tt:AddLine(L["Nothing new at your trainer right now."], 0.8, 0.8, 0.8, true) end
    for i, s in ipairs(list or {}) do
      if i > 12 then tt:AddLine("...", 0.8, 0.8, 0.8); break end
      tt:AddDoubleLine(s[3] .. (s[4] and s[4] > 0 and (" " .. fmt(L["Rank %d"], s[4])) or ""), fmt(L["Level %d"], s[1]), 1, 1, 1, 0.8, 0.8, 0.8)
    end
  end,
  click = function() if FLT.ToggleTrainerSpells then FLT.ToggleTrainerSpells() end end })

add({ key = "books", label = N"Library Books", icon = "Interface\\Icons\\INV_Misc_Book_07", events = { "QUEST_TURNED_IN", "BAG_UPDATE_DELAYED" },
  text = function()
    if not (FLT.GetCounts and FLT.BOOKS) then return "?" end
    local done = call(FLT.GetCounts, FLT) or 0
    return fmt("%d/%d", done, #FLT.BOOKS)
  end,
  click = function() togglePanel("books") end })

local HEARTH = 6948
local function hearthLeft()
  local start, dur = call(C_Container and C_Container.GetItemCooldown or GetItemCooldown, HEARTH)
  if start and dur and dur > 1.5 and start > 0 then return start + dur - (GetTime and GetTime() or 0) end
end
add({ key = "hearth", label = N"Hearthstone", icon = "Interface\\Icons\\INV_Misc_Rune_01", tick = true, secureItem = HEARTH,
  events = { "HEARTHSTONE_BOUND", "BAG_UPDATE_COOLDOWN" },
  text = function()
    local left = hearthLeft()
    local where = call(GetBindLocation) or "?"
    if left and left > 0 then return fmt("%s  %d:%02d", where, floor(left / 60), floor(left % 60)) end
    return where
  end })

-- hunters: the arrows / bullets they have (beta47, user 09.11.: showed 0 with 200 shots in the bags). The ammo slot
-- first; when it is empty or the client has none: the bags, only the kind the ranged weapon shoots (gun: bullets,
-- bow / crossbow: arrows; no such weapon: both). Returns the count and the item of the biggest pile (tooltip).
local itemCount = (C_Item and C_Item.GetItemCount) or GetItemCount
local itemInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
local function itemClass(id) if id and itemInstant then local _, _, _, _, _, c, s = itemInstant(id); return c, s end end
local function ammo()
  local slot = call(GetInventoryItemID, "player", INVSLOT_AMMO or 0)
  if slot and itemClass(slot) == 6 then return call(itemCount, slot) or 0, slot end
  local want -- projectile subclass: 2 arrow, 3 bullet
  local c, s = itemClass(call(GetInventoryItemID, "player", INVSLOT_RANGED or 18))
  if c == 2 then want = s == 3 and 3 or (s == 2 or s == 18) and 2 or nil end
  local CC = C_Container
  local nSlots = (CC and CC.GetContainerNumSlots) or GetContainerNumSlots
  local n, per, best = 0, {}, nil
  for bag = 0, NUM_BAG_SLOTS or 4 do
    for i = 1, nSlots and (call(nSlots, bag) or 0) or 0 do
      local id, cnt
      if CC and CC.GetContainerItemInfo then
        local info = CC.GetContainerItemInfo(bag, i)
        if info then id, cnt = info.itemID, info.stackCount end
      elseif GetContainerItemInfo then
        local _; _, cnt, _, _, _, _, _, _, _, id = GetContainerItemInfo(bag, i)
      end
      local pc, ps = itemClass(id)
      if pc == 6 and (ps == 2 or ps == 3) and (not want or ps == want) then
        n = n + (cnt or 1); per[id] = (per[id] or 0) + (cnt or 1)
        if not best or per[id] > per[best] then best = id end
      end
    end
  end
  return n, best
end

IB.AmmoCount = function() return (ammo()) end -- the quiver / ammo pouch on the bag bar shows this too (QoL.lua, beta49)
local reagentId -- the item the text was worked out for (icon and tooltip; beta48, user 09.11.: the icon of the ammo you have)
add({ key = "reagent", label = N"Class reagent", icon = "Interface\\Icons\\INV_Misc_Dust_02", events = { "BAG_UPDATE_DELAYED", "UNIT_INVENTORY_CHANGED" },
  text = function()
    local _, cls = UnitClass("player")
    local n
    if cls == "HUNTER" then n, reagentId = ammo()
    elseif REAGENT[cls] then reagentId = REAGENT[cls]; n = call(itemCount, reagentId) or 0 end
    if not n then return grey("-") end
    return n < 10 and ("|cffff4040" .. n .. "|r") or tostring(n)
  end,
  iconFn = function() return reagentId and itemInstant and select(5, itemInstant(reagentId)) end,
  tip = function(tt)
    local id = reagentId
    local name = id and call(C_Item and C_Item.GetItemNameByID or GetItemInfo, id)
    tt:AddLine(name or L["Ammunition"], 1, 1, 1)
  end })

local function guildOnline()
  if not (IsInGuild and IsInGuild()) then return nil end
  local total, online = call(GetNumGuildMembers)
  return online or 0, total or 0
end
add({ key = "guild", label = N"Guild", icon = "Interface\\Icons\\INV_Shirt_GuildTabard_01", events = { "GUILD_ROSTER_UPDATE", "PLAYER_GUILD_UPDATE" },
  blizz = true, secureClick = "GuildMicroButton",
  text = function() local o = guildOnline(); return o and tostring(o) or grey("-") end,
  tip = function(tt)
    local online = guildOnline()
    if not online then tt:AddLine(L["Not in a guild."], 0.8, 0.8, 0.8); return end
    local shown = 0
    for i = 1, select(1, call(GetNumGuildMembers)) or 0 do
      local name, _, _, level, _, zone, _, _, isOnline, _, cls = call(GetGuildRosterInfo, i)
      if isOnline then
        shown = shown + 1
        if shown > 20 then tt:AddLine("...", 0.8, 0.8, 0.8); break end
        local cc = RAID_CLASS_COLORS and cls and RAID_CLASS_COLORS[cls]
        tt:AddDoubleLine(fmt("%s (%d)", (name or "?"):gsub("%-.*", ""), level or 0), zone or "", cc and cc.r or 1, cc and cc.g or 1, cc and cc.b or 1, 0.8, 0.8, 0.8)
      end
    end
  end,
  click = function() if ToggleGuildFrame then call(ToggleGuildFrame) end end })

-- friends online: the game's friend list and Battle.net friends who are online (user 09.11.: "zeigt 0 an sind aber
-- welche online" - they were Battle.net friends); the server is asked for a fresh list when the element is shown
local function bnetOnline()
  local list = {}
  local _, online = call(BNGetNumFriends)
  if not (online and online > 0 and C_BattleNet and C_BattleNet.GetFriendAccountInfo) then return list end
  local total = call(BNGetNumFriends) or 0
  for i = 1, total do
    local a = call(C_BattleNet.GetFriendAccountInfo, i)
    local g = a and a.gameAccountInfo
    if g and g.isOnline then list[#list + 1] = { a.accountName or "?", g.characterName, g.richPresence or g.areaName or "" } end
  end
  return list
end
add({ key = "friends", label = N"Friends", icon = "Interface\\Icons\\Achievement_GuildPerk_EverybodysFriend", -- not a letter (user 08.11.)
  events = { "FRIENDLIST_UPDATE", "BN_FRIEND_ACCOUNT_ONLINE", "BN_FRIEND_ACCOUNT_OFFLINE", "BN_FRIEND_INFO_CHANGED", "BN_CONNECTED" },
  blizz = true, secureClick = { "SocialsMicroButton", "QuickJoinToastButton" }, -- Forever: no SocialsMicroButton (09.11.)
  text = function()
    local _, bn = call(BNGetNumFriends)
    return tostring((C_FriendList and call(C_FriendList.GetNumOnlineFriends) or 0) + (bn or 0))
  end,
  tip = function(tt)
    local n = C_FriendList and call(C_FriendList.GetNumFriends) or 0
    for i = 1, n do
      local info = call(C_FriendList.GetFriendInfoByIndex, i)
      if info and info.connected then tt:AddDoubleLine(fmt("%s (%d)", info.name or "?", info.level or 0), info.area or "", 1, 1, 1, 0.8, 0.8, 0.8) end
    end
    for _, b in ipairs(bnetOnline()) do
      tt:AddDoubleLine("|cff82c5ff" .. b[1] .. "|r" .. (b[2] and (" (" .. b[2] .. ")") or ""), b[3], 1, 1, 1, 0.8, 0.8, 0.8)
    end
  end,
  click = function() if ToggleFriendsFrame then call(ToggleFriendsFrame) end end })

-- the game's own windows (user 09.11.: a "Blizzard" entry in the menu with its own list - guild, friends, LFG ...):
-- opened by a secure click on the game's micro button (opened from our code they get tainted, see Durability); the
-- plain click is only the fallback when a client has no such button. Shown with their name.
local function blizz(key, label, icon, micro, fallback)
  add({ key = key, label = label, icon = icon, blizz = true, secureClick = micro,
    text = function() return L[label] end,
    click = function() if not inCombat() then call(fallback) end end })
end
blizz("blz:character", N"Character", "Interface\\Icons\\INV_Chest_Cloth_17", "CharacterMicroButton",
  function() if ToggleCharacter then ToggleCharacter("PaperDollFrame") end end)
blizz("blz:spellbook", N"Spellbook", "Interface\\Icons\\INV_Misc_Book_09", "SpellbookMicroButton",
  function() if ToggleSpellBook then ToggleSpellBook(BOOKTYPE_SPELL or "spell") end end)
blizz("blz:talents", N"Talents", "Interface\\Icons\\Ability_Marksmanship", "TalentMicroButton",
  function() if ToggleTalentFrame then ToggleTalentFrame() end end)
-- Forever has no WorldMapMicroButton: its quest log button opens the map with the quests (user 09.11.: one "Map / Quests"
-- entry is enough; the old "blz:map" becomes "blz:quests" in items())
blizz("blz:quests", N"Map / Quests", "Interface\\Icons\\INV_Misc_Map_01", "QuestLogMicroButton",
  function() if ToggleQuestLog then ToggleQuestLog() end end)
-- the first of the names the client has (Forever: LFDMicroButton, user 09.11.; Classic: LFGMicroButton)
blizz("blz:lfg", N"Looking for Group", "Interface\\Icons\\INV_Misc_GroupNeedMore", { "LFDMicroButton", "LFGMicroButton" },
  function() if PVEFrame_ToggleFrame then PVEFrame_ToggleFrame() elseif ToggleLFGParentFrame then ToggleLFGParentFrame() end end)
-- no "Game menu" (6.2.2-beta39): its micro button only reacts to a real mouse press, a click from a secure button does
-- nothing, and opened from our code the menu would be tainted - Esc opens it
blizz("blz:calendar", N"Calendar", "Interface\\Icons\\INV_Misc_Note_02", "GameTimeFrame",
  function() if ToggleCalendar then ToggleCalendar() end end)
blizz("blz:legacy", N"Legacy", "Interface\\Icons\\Achievement_General", "LegacyMicroButton", nil)
blizz("blz:shop", N"Shop", "Interface\\Icons\\INV_Misc_Coin_17", "StoreMicroButton", nil)

add({ key = "mail", label = N"New mail", icon = "Interface\\Icons\\INV_Letter_01", events = { "UPDATE_PENDING_MAIL", "MAIL_CLOSED" },
  text = function() return call(HasNewMail) and ("|cff40ff40" .. L["New mail"] .. "|r") or grey(L["No mail"]) end,
  tip = function(tt)
    for _, s in ipairs({ call(GetLatestThreeSenders) }) do if s then tt:AddLine(s, 1, 1, 1) end end
  end })

add({ key = "spec", label = N"Spec for the Value", icon = "Interface\\Icons\\INV_Misc_Gear_01", events = { "CHARACTER_POINTS_CHANGED", "PLAYER_TALENT_UPDATE" },
  text = function() local s = FLT.GearValue and call(FLT.GearValue.SpecName); return s and L[s] or grey("-") end,
  tip = function(tt) tt:AddLine(L["The stat weights of this spec are used for the upgrades here, in tooltips, bags and loot rolls. \"Active spec\" follows your talents. \"Edit custom weights...\" sets your own weights."], 0.8, 0.8, 0.8, true) end,
  -- pick the spec right here (user 08.11.), the same list as in the Gear Planner
  click = function(c)
    local GV = FLT.GearValue
    if not (GV and GV.Specs and UI.OpenDropDown) then return end
    local specs, pick, auto = GV.Specs()
    local opts = { { key = 0, label = L["Active spec"] .. (auto and specs[auto] and ("  |cffb0b0b0(" .. L[specs[auto].name] .. ")|r") or "") } }
    for i, sp in ipairs(specs) do opts[#opts + 1] = { key = i, label = L[sp.name] } end
    opts[#opts + 1] = { key = "custom", label = L["Custom weights"] }
    UI.OpenDropDown(c, opts, pick or 0, function(k)
      GV.SetSpec(k ~= 0 and k or nil)
      if IB.Refresh then IB.Refresh("spec") end
    end, 220)
  end })

-- Guild Games (6.2.12-beta4): opens the window; the text shows how many guild members can play
add({ key = "games", label = N"Guild Games", icon = "Interface\\Buttons\\UI-GroupLoot-Dice-Up",
  -- "(n)" while guild members have open tables (gg35, user 17.11.)
  text = function()
    local n = FLT.GuildGames and FLT.GuildGames.OpenTables and FLT.GuildGames.OpenTables() or 0
    return L["Guild Games"] .. (n > 0 and (" |cffffd200(" .. n .. ")|r") or "")
  end,
  tip = function(tt) tt:AddLine(L["Small games with your guild members: Death Roll, High / Low, Tic Tac Toe."], 0.8, 0.8, 0.8, true) end,
  click = function() if FLT.GuildGames then FLT.GuildGames.Toggle() end end })

-- the tabs of the OneForAll window as quick access (user 08.11.: "jeden tab aus dem addon dort quasi als schnell
-- zugriff"; menu "Addon tabs" with its own list to the right). Keys "tab:<panel key>"; made from UI.panels on first use.
local TAB_GLYPH = { settings = 7, armory = 0, dungeons = 1, professions = 2, qol = 3, talents = 4, books = 5, pets = 6 } -- Assets/tab_icons (MainFrame.lua)
local TABS = {}
local function tabElements()
  if #TABS > 0 or not (UI and UI.panels) then return TABS end
  for _, spec in ipairs(UI.panels) do
    local key, pk = "tab:" .. spec.key, spec.key
    local gi = TAB_GLYPH[pk]
    E[key] = { key = key, label = spec.label, tab = true,
      icon = gi and (UI.ASSET_ROOT .. "tab_icons") or spec.icon or "Interface\\Icons\\INV_Misc_QuestionMark",
      coords = gi and { (gi % 4) * 0.25, (gi % 4) * 0.25 + 0.25, math.floor(gi / 4) * 0.5, math.floor(gi / 4) * 0.5 + 0.5 },
      text = function() return L[spec.label] end,
      click = function() togglePanel(pk) end }
    TABS[#TABS + 1] = key
  end
  return TABS
end

IB.ORDER, IB.ELEMENTS = ORDER, E -- tests and the settings

-- the chosen elements, in the order of ORDER
-- the chosen elements in the player's order (drag & drop on the bar, user 08.11.); unknown or doubled keys are skipped
-- old keys in the saved list are renamed there (not only when reading): "blz:map" became "Map / Quests" in beta39,
-- and unticking "Map / Quests" did not find the old key, so it stayed (user 09.11.)
local RENAMED = { ["blz:map"] = "blz:quests" }
local function migrate(list)
  for i = #list, 1, -1 do
    local new = RENAMED[list[i]]
    if new then
      local dup
      for j, k in ipairs(list) do if j ~= i and k == new then dup = true end end
      if dup then table.remove(list, i) else list[i] = new end
    end
  end
end
local function items()
  tabElements()
  local d = db(); local list = d and d.infoBarItems
  if type(list) ~= "table" then return {} end
  migrate(list)
  local seen, out = {}, {}
  for _, k in ipairs(list) do
    if E[k] and not seen[k] then seen[k] = true; out[#out + 1] = k end
  end
  return out
end
-- move element "key" in front of position "to" of the SHOWN elements (1 .. #items + 1). The saved list can hold keys that
-- are not shown (an element that was removed, a doubled key): "to" is turned into the place in front of the shown element
-- (beta47, user 09.11.: "zwei nach rechts um eins nach rechts zu kommen" - a hidden old key shifted every drop by one)
local function moveItem(key, to)
  local d = db(); local list = d and d.infoBarItems
  if type(list) ~= "table" then return end
  local before = items()[to] -- nil: to the end
  if before == key then return end
  local found
  for i = #list, 1, -1 do if list[i] == key then table.remove(list, i); found = true end end -- doubled keys too
  if not found then return end
  local at = #list + 1
  if before then for i, k in ipairs(list) do if k == before then at = i; break end end end
  table.insert(list, at, key)
end
IB._moveItem = moveItem -- tests
IB._items = items -- tests
local function pinned() local d = db(); return d and d.infoBarPinned == true end
-- the place (6.2.5, user 10.11.): Shift-drag moves the bar along the screen edge and to the top or the bottom half;
-- qol.infoBarEdge = "BOTTOM" (nil = top), qol.infoBarX = offset from the middle (bar units, nil = middle). At the bottom
-- the bar is turned upside down: the tab sits at the bottom edge and the bar slides in from below.
local function bottom() local d = db(); return d and d.infoBarEdge == "BOTTOM" end
local function barX() local d = db(); return tonumber(d and d.infoBarX) or 0 end

-- Frames ---------------------------------------------------------------------------------------------------------------
local band, handle, cells, ev, ticker = nil, nil, {}, nil, nil
local open = false -- the band is shown (pinned, or the mouse is on it)
-- texts are worked out only for the elements whose events fired (or that tick); all = when the band opens
local textOf, dirty, allDirty, drawQueued = {}, {}, true, false
local iconOf = {} -- element -> its current icon (iconFn)
local widthOf = {} -- the widest each element was this session: the band does not jump with changing numbers (user 08.11.)
-- ... only while just the numbers change (6.2.18, Discord flikera 25.11.: a gap after Experience once the rested part was gone)
local shapeOf = {}
local byEvent = {} -- event -> { element keys }
local H, PAD, ICON = 24, 10, 14

local function tipFor(cell)
  local e = E[cell.key]
  GameTooltip:SetOwner(cell, bottom() and "ANCHOR_TOP" or "ANCHOR_BOTTOM")
  GameTooltip:AddLine(L[e.label], 1, 0.82, 0)
  if e.tip then e.tip(GameTooltip) end
  if e.click then GameTooltip:AddLine(L["Click: open"], 0.6, 0.6, 0.6) end
  GameTooltip:AddLine(L["Right-click: elements and pin"], 0.6, 0.6, 0.6)
  GameTooltip:AddLine(L["Drag: change the order"], 0.6, 0.6, 0.6)
  GameTooltip:AddLine(L["Shift-drag: move the bar"], 0.6, 0.6, 0.6)
  GameTooltip:Show()
end

local openMenu -- forward
local syncSecure -- forward (the secure buttons, below)
local secures, secureFolds = {}, false -- secure buttons over the cells of click-to-use elements (hearthstone, character)
local function secureShown() for _, b in ipairs(secures) do if b:IsShown() then return true end end return false end
local function secureUnderMouse() for _, b in ipairs(secures) do if b:IsShown() and b:IsMouseOver() then return true end end return false end
local shownP, animTarget, animFrame = 0, nil, nil -- the band slides: 0 = up out of view, 1 = in place
local foldLater, applyEdge -- forward
local function cell(i)
  local c = cells[i]
  if c then return c end
  c = CreateFrame("Button", nil, band); c:SetHeight(H)
  c:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  c.icon = c:CreateTexture(nil, "ARTWORK"); c.icon:SetSize(ICON, ICON); c.icon:SetPoint("LEFT", 0, 0); c.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  c.text = FLT.NewFS(c, nil, "OVERLAY", "GameFontHighlightSmall")
  c.sep = UI.makeTexture(band, "ARTWORK", 0.50, 0.42, 0.30, 0.45); c.sep:SetSize(1, 12)
  local hl = UI.makeTexture(c, "HIGHLIGHT", 1, 0.82, 0.3, 0.10); hl:SetPoint("TOPLEFT", -4, -3); hl:SetPoint("BOTTOMRIGHT", 4, 3)
  c:SetScript("OnEnter", function(self) if foldLater then foldLater(false) end; tipFor(self) end)
  c:SetScript("OnLeave", function() GameTooltip:Hide(); if foldLater then foldLater(true) end end)
  c:SetScript("OnClick", function(self, button)
    if button == "RightButton" then openMenu(self); return end
    local e = E[self.key]; if e and e.click then e.click(self) end
  end)
  -- drag & drop to change the order (user 08.11.): a gold line shows where it goes; the OnUpdate only while dragging
  c:RegisterForDrag("LeftButton")
  c:SetScript("OnDragStart", function(self) IB.DragStart(self) end)
  c:SetScript("OnDragStop", function(self) IB.DragStop(self) end)
  cells[i] = c
  return c
end

-- draw the texts and place the cells (the band grows with them, centred at the top)
local function layout()
  local list = items()
  local x, y = PAD, bottom() and 1 or -1 -- the text sits a bit away from the gold line
  for i, k in ipairs(list) do
    local c = cell(i)
    local e = E[k]
    if c.key ~= k then
      c.key = k; c.tex = nil; c.icon:SetShown(not e.noIcon)
      -- tab elements: the tab glyph from the window's atlas, in the tabs' gold
      if e.coords then c.icon:SetTexCoord(unpack(e.coords)); c.icon:SetVertexColor(1, 0.80, 0.40)
      else c.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92); c.icon:SetVertexColor(1, 1, 1) end
      c.text:ClearAllPoints()
      if e.noIcon then c.text:SetPoint("LEFT", c, "LEFT", 0, 0) else c.text:SetPoint("LEFT", c.icon, "RIGHT", 4, 0) end
    end
    if allDirty or dirty[k] or textOf[k] == nil then
      local ok, s = pcall(e.text)
      textOf[k] = ok and s or "?"
      if e.iconFn then local ok2, t = pcall(e.iconFn); iconOf[k] = ok2 and t or nil end
    end
    local tex = e.iconFn and iconOf[k] or e.icon -- elements with their own icon (the ammo you have)
    if c.tex ~= tex then c.tex = tex; FLT.SetTex(c.icon, tex) end
    c.text:SetText(textOf[k])
    local shape = tostring(textOf[k]):gsub("%d+", "0")
    if shapeOf[k] ~= shape then shapeOf[k] = shape; widthOf[k] = nil end
    local w = (e.noIcon and 0 or ICON + 4) + math.ceil(c.text:GetStringWidth() or 20)
    w = math.max(w, widthOf[k] or 0); widthOf[k] = w
    c:SetWidth(w); c:ClearAllPoints(); c:SetPoint("LEFT", band, "LEFT", x, y)
    c.sep:ClearAllPoints(); c.sep:SetPoint("CENTER", band, "LEFT", x - PAD / 2 - 1, y); c.sep:SetShown(i > 1)
    c:Show()
    x = x + w + PAD + 2
  end
  for i = #list + 1, #cells do cells[i]:Hide(); cells[i].sep:Hide() end
  band.empty:SetShown(#list == 0)
  local width = #list == 0 and (band.empty:GetStringWidth() or 200) + 2 * PAD or x - 2
  band:SetWidth(math.max(120, width))
  allDirty = false; wipe(dirty)
  if #secures > 0 or open then syncSecure() end
end

-- where a dragged element would go: in front of the first cell whose middle is right of the cursor
local function dropIndex()
  local scale = band:GetEffectiveScale() or 1
  local cx = (GetCursorPosition and select(1, GetCursorPosition()) or 0) / scale
  local list = items()
  for i = 1, #list do
    local c = cells[i]
    local l, w = c and c:GetLeft(), c and c:GetWidth()
    if l and w and cx < l + w / 2 then return i end
  end
  return #list + 1
end
local dragKey, moving
function IB.DragStart(c)
  if IsShiftKeyDown and IsShiftKeyDown() then IB.MoveStart(); return end
  dragKey = c.key
  GameTooltip:Hide(); foldLater(false)
  c:SetAlpha(0.4)
  if not band.mark then band.mark = UI.makeTexture(band, "OVERLAY", 1, 0.82, 0.25, 0.95); band.mark:SetSize(2, H - 6) end
  band:SetScript("OnUpdate", function()
    local i, list = dropIndex(), items()
    local ref = cells[math.min(i, #list)]
    band.mark:ClearAllPoints()
    if ref and i <= #list then band.mark:SetPoint("RIGHT", ref, "LEFT", -PAD / 2, 0)
    elseif ref then band.mark:SetPoint("LEFT", ref, "RIGHT", PAD / 2, 0) end
    band.mark:Show()
  end)
end
function IB.DragStop(c)
  if moving then IB.MoveStop(); return end
  band:SetScript("OnUpdate", nil)
  if band.mark then band.mark:Hide() end
  c:SetAlpha(1)
  if dragKey then moveItem(dragKey, dropIndex()); dragKey = nil; allDirty = true; layout() end
  -- the click buttons follow their cells once the new places are worked out (a frame later; user 09.11.: those
  -- elements could not be dropped where wanted - their buttons still lay over the old places)
  if C_Timer and C_Timer.After then C_Timer.After(0, syncSecure) end
  foldLater(true)
end

local function draw()
  drawQueued = false
  if not band or not open then return end -- folded up: worked out when it opens (allDirty)
  layout()
end
local function queue()
  if drawQueued then return end
  drawQueued = true
  if C_Timer and C_Timer.After then C_Timer.After(0.2, draw) else draw() end
end

function IB.Refresh(key) if key then dirty[key] = true else allDirty = true end; queue() end

local function needsTick()
  for _, k in ipairs(items()) do if E[k].tick then return true end end
  return false
end
local function setTicker()
  local want = on() and open and needsTick()
  if want and not ticker and C_Timer and C_Timer.NewTicker then
    ticker = C_Timer.NewTicker(1, function()
      -- only the ticking elements change their text; the rest stays
      if not band or not open then return end
      for _, k in ipairs(items()) do if E[k].tick then dirty[k] = true end end
      layout()
    end)
  elseif not want and ticker then ticker:Cancel(); ticker = nil end
end

-- Items you use by a click (the hearthstone; user 08.11.: "Ruhestein ueber druecken nicht betaetigen"): a secure button
-- lies over the element's cell. Secure frames can't be shown, hidden or moved in combat - so this only happens out of
-- combat (again after combat), and the bar does not fold up during combat while one is shown.
-- Placed by screen position on UIParent, NOT anchored to the cell (beta7, user 08.11.: "leiste ist weg nachdem ich im
-- kampf drauf geklickt habe"): anchored, the cell and the band became protected, the band could not be shown in combat
-- and the handle was already hidden (DESIGN.md "Frames holding secure buttons").
-- what an element's secure button does: use an item, or click one of the game's own buttons; nil = an ordinary click
local function secureOf(e)
  if e.secureItem then return "item", "item:" .. e.secureItem end
  local sc, b = e.secureClick
  if type(sc) == "function" then sc = sc() end
  if type(sc) == "table" then for _, n in ipairs(sc) do b = b or _G[n] end else b = sc and _G[sc] end
  if type(b) == "table" then return "click", b end
end
local lit = {} -- secure button -> the cell it lights up while the mouse is on it
local function unlight(b) if lit[b] then lit[b]:UnlockHighlight(); lit[b] = nil end end
local function newSecure(n)
  local b = CreateFrame("Button", "OneForAllInfoBarUse" .. (n > 1 and n or ""), UIParent, "SecureActionButtonTemplate")
  b:SetFrameStrata("HIGH"); b:SetFrameLevel((band:GetFrameLevel() or 1) + 10)
  b:RegisterForClicks("LeftButtonUp", "LeftButtonDown", "RightButtonUp")
  -- act on the release, never on the press (beta45, user 09.11.: dragging the hearthstone / Looking for Group used it -
  -- with the game's "cast on key down" setting the press fired before the drag began); a drag swallows the release
  b:SetAttribute("useOnKeyDown", false)
  b:HookScript("OnClick", function(self, button) if button == "RightButton" then openMenu(self) end end)
  -- the cell lies under this button and gets no mouse: its highlight is switched on by hand (beta47, user 09.11.:
  -- "manche haben kein highlight")
  b:SetScript("OnEnter", function(self)
    foldLater(false)
    if self.cell then lit[self] = self.cell; self.cell:LockHighlight(); tipFor(self.cell) end
  end)
  b:SetScript("OnLeave", function(self) unlight(self); GameTooltip:Hide(); foldLater(true) end)
  b:RegisterForDrag("LeftButton")
  b:SetScript("OnDragStart", function(self) if self.cell then IB.DragStart(self.cell) end end)
  b:SetScript("OnDragStop", function(self) if self.cell then IB.DragStop(self.cell) end end)
  secures[n] = b
  return b
end
syncSecure = function()
  if inCombat() then return end
  local n = 0
  if open and shownP >= 1 then -- placed when the band has arrived
    for i, k in ipairs(items()) do
      local c = cells[i]
      local typ, val = secureOf(E[k])
      local l, b, w, h
      if typ and c and c:IsShown() then l, b, w, h = c:GetLeft(), c:GetBottom(), c:GetWidth(), c:GetHeight() end
      if l and b and w and h then
        n = n + 1
        local s = secures[n] or newSecure(n)
        local k2 = (c:GetEffectiveScale() or 1) / (s:GetEffectiveScale() or 1)
        if lit[s] ~= c then unlight(s) end
        s.cell = c
        s:SetAttribute("type1", typ)
        s:SetAttribute("item", typ == "item" and val or nil); s:SetAttribute("clickbutton", typ == "click" and val or nil)
        s:ClearAllPoints(); s:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l * k2, b * k2); s:SetSize(w * k2, h * k2)
        s:Show()
      end
    end
  end
  for j = n + 1, #secures do unlight(secures[j]); secures[j]:Hide() end
end

-- slide in and out (user 08.11.: "rein und raus fahren statt direkt zu erscheinen"): 0.2 s, an OnUpdate only while
-- it moves; without a clock (tests) at once. The hearthstone button is placed when the band has arrived.
local SLIDE = 0.2
local function placeBand(p)
  shownP = p
  local e = p * p * (3 - 2 * p) -- eased
  local off = 2 + (1 - e) * (H + 4)
  band:ClearAllPoints()
  if bottom() then band:SetPoint("BOTTOM", UIParent, "BOTTOM", barX(), -off) else band:SetPoint("TOP", UIParent, "TOP", barX(), off) end
  band:SetAlpha((0.2 + 0.8 * e) * barAlpha())
end
local function placeHandle()
  handle:ClearAllPoints()
  if bottom() then handle:SetPoint("BOTTOM", UIParent, "BOTTOM", barX(), -2) else handle:SetPoint("TOP", UIParent, "TOP", barX(), 2) end
end
local function arrived()
  if animTarget == 0 then band:Hide(); handle:SetShown(on() and not open) else syncSecure() end
  animTarget = nil
end
local function slideTo(target, instant)
  animTarget = target
  if instant or not (GetTime and CreateFrame) then
    if animFrame then animFrame:SetScript("OnUpdate", nil) end
    placeBand(target); arrived(); return
  end
  if not animFrame then animFrame = CreateFrame("Frame") end
  animFrame:SetScript("OnUpdate", function(self, elapsed)
    local p = shownP + (animTarget == 1 and 1 or -1) * (elapsed or 0) / SLIDE
    if p >= 1 or p <= 0 then p = p >= 1 and 1 or 0; self:SetScript("OnUpdate", nil); placeBand(p); arrived(); return end
    placeBand(p)
  end)
end

local function setOpen(v, slide)
  -- the hearthstone button can't hide in combat: the bar stays open with it and folds after combat
  if not v and open and inCombat() and secureShown() then secureFolds = true; return end
  open = v and true or false
  if not band then return end
  if open then
    handle:Hide(); band:Show()
    allDirty = true; layout()
    if shownP < 1 or animTarget == 0 then slideTo(1, not slide) end
  else
    syncSecure() -- hides the hearthstone button (out of combat)
    if band:IsShown() then slideTo(0, not slide) else handle:SetShown(on()) end
  end
  setTicker()
end

-- the element menu (user 08.11.: a pick keeps it open, it closes when the mouse has left it; "Addon tabs" opens a
-- second list to the right). Its own small menu: the shared drop-down closes on every pick.
local menu, subMenu
local menuToken = 0
local function menuOpen() return menu and menu:IsShown() end
local function closeMenu() if subMenu then subMenu:Hide() end; if menu then menu:Hide() end end
local function menuStay() menuToken = menuToken + 1 end
local function menuLeave()
  menuToken = menuToken + 1
  local my = menuToken
  if not (C_Timer and C_Timer.After) then return end
  C_Timer.After(0.4, function()
    if my ~= menuToken or not menuOpen() then return end
    if menu:IsMouseOver() or (subMenu and subMenu:IsShown() and subMenu:IsMouseOver()) then return end
    closeMenu(); foldLater(true)
  end)
end
local function skin(r, g, b, a) if FLT.SkinC then return FLT.SkinC(r, g, b, a) end return r, g, b, a end
local function newMenu()
  local m = CreateFrame("Frame", nil, UIParent); m:SetFrameStrata("FULLSCREEN_DIALOG"); m:SetFrameLevel(20)
  m:EnableMouse(true); m:SetClampedToScreen(true); m:Hide()
  UI.FramedPanel(m); m.rows = {}
  m:SetScript("OnEnter", menuStay); m:SetScript("OnLeave", menuLeave)
  return m
end
local function fillMenu(m, opts)
  local w = 170
  for _, r in ipairs(m.rows) do r:Hide() end
  for i, o in ipairs(opts) do
    local r = m.rows[i]
    if not r then
      r = CreateFrame("Button", nil, m); r:SetHeight(22)
      local hi = r:CreateTexture(nil, "HIGHLIGHT"); hi:SetAllPoints(); hi:SetColorTexture(skin(0.90, 0.66, 0.22, 0.18))
      r.text = FLT.NewFS(r, nil, "OVERLAY", "GameFontHighlight"); r.text:SetPoint("LEFT", 22, 0)
      r.check = r:CreateTexture(nil, "OVERLAY"); r.check:SetSize(14, 14); r.check:SetPoint("LEFT", 5, 0)
      r.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
      r.arrow = r:CreateTexture(nil, "OVERLAY"); r.arrow:SetSize(12, 12); r.arrow:SetPoint("RIGHT", -6, 0)
      r.arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
      r:SetScript("OnEnter", function(self) menuStay(); if self.opt and self.opt.hover then self.opt.hover(self) end end)
      r:SetScript("OnLeave", menuLeave)
      r:SetScript("OnClick", function(self) if self.opt and self.opt.pick then self.opt.pick(self) end end)
      m.rows[i] = r
    end
    r.opt = o
    r:ClearAllPoints(); r:SetPoint("TOPLEFT", 4, -4 - (i - 1) * 22)
    r.text:SetText(o.label)
    local need = (r.text:GetStringWidth() or 0) + 22 + (o.sub and 28 or 12)
    if need > w then w = math.ceil(need) end
    if o.icon then r.check:SetTexture(o.icon); r.check:SetAlpha(o.checked and 1 or 0.45); r.check:Show()
    else r.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check"); r.check:SetAlpha(1); r.check:SetShown(o.checked and true or false) end
    r.arrow:SetShown(o.sub and true or false)
    if o.checked then r.text:SetTextColor(skin(1, 0.82, 0.2)) else r.text:SetTextColor(0.92, 0.90, 0.84) end
    r:Show()
  end
  for i = 1, #opts do m.rows[i]:SetWidth(w - 8) end
  m:SetSize(w, #opts * 22 + 8)
end
local function toggleItem(k)
  local d = db(); if not d then return end
  d.infoBarItems = type(d.infoBarItems) == "table" and d.infoBarItems or {}
  migrate(d.infoBarItems)
  local found
  for i, c in ipairs(d.infoBarItems) do if c == k then found = i end end
  if found then table.remove(d.infoBarItems, found) else d.infoBarItems[#d.infoBarItems + 1] = k end
  IB.Apply(true)
end
IB._toggleItem = toggleItem -- tests
local function chosenSet() local t = {}; for _, k in ipairs(items()) do t[k] = true end; return t end
local fillMain -- forward
-- the second list: "#tabs" = the OneForAll window's tabs, "#blizz" = the game's windows (user 09.11.)
local subKind
local function subKeys(kind)
  if kind == "#tabs" then return tabElements() end
  local t = {}
  for _, k in ipairs(ORDER) do if E[k].blizz then t[#t + 1] = k end end
  return t
end
-- the other characters of this realm in the gold list (6.2.12-beta15, user 18.11.: "eine moeglichkeit charactere zu entfernen,
-- geloeschte charactere verschwinden oben nicht"): key, label (with class colour), copper; never the one we play
local function goldChars()
  local t, out, realm = type(OneForAllDB) == "table" and OneForAllDB.infoGold or nil, {}, GetRealmName and GetRealmName() or "?"
  if not t then return out end
  for k, v in pairs(t) do
    local _, r, cls = FLT.CharOf(k, v)
    if r == realm and type(v) == "table" and not (FLT.IsMyChar and FLT.IsMyChar(k)) then
      local cc = RAID_CLASS_COLORS and cls and RAID_CLASS_COLORS[cls]
      local label = FLT.CharLabel(t, k, v)
      if cc then label = string.format("|cff%02x%02x%02x%s|r", cc.r * 255, cc.g * 255, cc.b * 255, label) end
      out[#out + 1] = { key = k, label = label .. "  |cff9d9d9d" .. money(v[1] or 0) .. "|r", copper = v[1] or 0 }
    end
  end
  table.sort(out, function(a, b) return a.copper > b.copper end)
  return out
end
IB._goldChars = goldChars -- tests
local function hideSub() if subMenu then subMenu:Hide() end end
local function fillSub()
  local ch, opts = chosenSet(), {}
  if subKind == "#gold" then -- a click takes the character off the list (he comes back when he logs in again)
    for _, c in ipairs(goldChars()) do
      opts[#opts + 1] = { key = c.key, label = c.label, pick = function()
        OneForAllDB.infoGold[c.key] = nil
        if #goldChars() == 0 then hideSub() else fillSub() end
        fillMain()
      end }
    end
    fillMenu(subMenu, opts)
    return
  end
  for _, k in ipairs(subKeys(subKind)) do
    opts[#opts + 1] = { key = k, label = L[E[k].label], checked = ch[k], pick = function() toggleItem(k); fillSub(); fillMain() end }
  end
  fillMenu(subMenu, opts)
end
local function showSub(row)
  if not subMenu then subMenu = newMenu() end
  subKind = row.opt and row.opt.key
  fillSub(); subMenu:ClearAllPoints(); subMenu:SetPoint("TOPLEFT", row, "TOPRIGHT", 6, 4); subMenu:Show()
end
fillMain = function()
  local ch, opts = chosenSet(), {}
  -- the pin row with a map pin instead of the check mark (user 09.11.)
  opts[1] = { key = "#pin", label = L["Pinned (stays open)"], checked = pinned(), hover = hideSub,
    icon = pinned() and "Interface\\Minimap\\Minimap-Waypoint-MapPin-Tracked" or "Interface\\Minimap\\Minimap-Waypoint-MapPin-Untracked", pick = function()
    local d = db(); if d then d.infoBarPinned = not pinned() or nil end; IB.Apply(true); fillMain() end }
  opts[2] = { key = "#bottom", label = L["At the bottom of the screen"], checked = bottom(), hover = hideSub, pick = function()
    local d = db(); if d then d.infoBarEdge = not bottom() and "BOTTOM" or nil; applyEdge() end; fillMain() end }
  if barX() ~= 0 then
    opts[3] = { key = "#middle", label = L["Back to the middle"], hover = hideSub, pick = function()
      local d = db(); if d then d.infoBarX = nil; applyEdge() end; fillMain() end }
  end
  for _, k in ipairs(ORDER) do
    if not E[k].blizz then
      opts[#opts + 1] = { key = k, label = L[E[k].label], checked = ch[k], hover = hideSub, pick = function() toggleItem(k); fillMain() end }
    end
  end
  if ch.gold and #goldChars() > 0 then
    opts[#opts + 1] = { key = "#gold", label = L["Remove a character from the gold list"], sub = true, hover = showSub, pick = showSub }
  end
  for _, sub in ipairs({ { "#blizz", N"Blizzard" }, { "#tabs", N"Addon tabs" } }) do
    local n = 0; for _, k in ipairs(subKeys(sub[1])) do if ch[k] then n = n + 1 end end
    opts[#opts + 1] = { key = sub[1], label = L[sub[2]] .. (n > 0 and (" |cff9d9d9d(" .. n .. ")|r") or ""), sub = true,
      hover = showSub, pick = showSub }
  end
  fillMenu(menu, opts)
end
openMenu = function()
  if not menu then menu = newMenu() end
  if menuOpen() then closeMenu(); return end
  local scale = UIParent:GetEffectiveScale() or 1
  local x, y = 0, 0
  if GetCursorPosition then x, y = GetCursorPosition() end
  fillMain()
  menu:ClearAllPoints()
  if bottom() then menu:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x / scale - 20, y / scale + 14) -- above the bar
  else menu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale - 20, y / scale + 6) end
  menu:Show(); menuStay()
end
IB._menus = function() return menu, subMenu end -- tests

-- unpinned: fold up 3 s after the mouse left the band (user 08.11.); not while one of its menus is open - then it looks
-- again 3 s later
-- seconds before it folds: Quality of Life "Stay open" (qol.infoBarDelay, 1 - 10, default 3; user 09.11.)
local function foldAfter() local d = db(); return math.max(1, math.min(10, tonumber(d and d.infoBarDelay) or 3)) end
local foldToken = 0
foldLater = function(start)
  foldToken = foldToken + 1
  if not start or pinned() then return end
  local my = foldToken
  if C_Timer and C_Timer.After then
    C_Timer.After(foldAfter(), function()
      if my ~= foldToken or pinned() or not band then return end
      if (band:IsShown() and band:IsMouseOver()) or secureUnderMouse() then return end
      if menuOpen() or (UI.DropDownShown and UI.DropDownShown()) then foldLater(true); return end
      setOpen(false, true) -- in combat with the hearthstone button shown: after combat
    end)
  end
end

-- the look (user 08.11.): the sides slant up to the screen edge (wider at the top) at 62 degrees, the corners at the
-- bottom rounded, a thin gold line. From own art (tools/art/infobar.py, user 09.11.: the drawn lines looked pixelated):
-- a cap 24 x 24 units for the left side, mirrored for the right, a strip for the middle; all scale with the height.
-- where the corner sits in the cap = the frame's edge (printed by the script); the folded tab has its own small art
-- (user 09.11.: the big one scaled down that far looked pixelated), mipmapped ("TRILINEAR") for smooth scaling
local CAPS = { [""] = 13.253 / 24, ["_s"] = 5.739 / 10 }
local function shape(f, h, suffix)
  suffix = suffix or ""
  local cx = CAPS[suffix]
  local function tex(file, sub) local t = f:CreateTexture(nil, "BACKGROUND", nil, sub); t:SetTexture(UI.ASSET_ROOT .. file .. suffix, nil, nil, "TRILINEAR")
    if t.SetSnapToPixelGrid then t:SetSnapToPixelGrid(false); t:SetTexelSnappingBias(0) end; return t end
  f.fills, f.parts, f.capH, f.capX = {}, {}, h, cx
  -- the fill (white, tinted with the chosen colour) under the line (beta43)
  for _, part in ipairs({ "_fill", "" }) do
    local l, r, m = tex("infobar_cap" .. part, part == "" and 1 or 0), tex("infobar_cap" .. part, part == "" and 1 or 0), tex("infobar_mid" .. part, part == "" and 1 or 0)
    l:SetSize(h, h); r:SetSize(h, h)
    f.parts[#f.parts + 1] = { l, r, m }
    if part ~= "" then f.fills[1], f.fills[2], f.fills[3] = l, r, m end
  end
end
-- top (as drawn) or at the bottom upside down (6.2.5)
local function orient(f, down)
  local h, cx = f.capH, f.capX
  local inner, v, t0, t1 = h * (1 - cx), down and "BOTTOM" or "TOP", down and 1 or 0, down and 0 or 1
  for _, p in ipairs(f.parts) do
    local l, r, m = p[1], p[2], p[3]
    l:ClearAllPoints(); l:SetPoint(v .. "LEFT", f, v .. "LEFT", -h * cx, 0); l:SetTexCoord(0, 1, t0, t1)
    r:ClearAllPoints(); r:SetPoint(v .. "RIGHT", f, v .. "RIGHT", h * cx, 0); r:SetTexCoord(1, 0, t0, t1)
    m:ClearAllPoints(); m:SetPoint("TOPLEFT", f, "TOPLEFT", inner, 0); m:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -inner, 0)
    m:SetTexCoord(0, 1, t0, t1)
  end
end
applyEdge = function()
  local down = bottom()
  orient(band, down); orient(handle, down)
  band.empty:ClearAllPoints(); band.empty:SetPoint("LEFT", PAD, down and 1 or -1)
  placeHandle(); placeBand(shownP)
  if open then layout() end
  if not moving and C_Timer and C_Timer.After then C_Timer.After(0, syncSecure) end
end
-- Shift-drag: the bar follows the cursor (an OnUpdate only while dragging); the half of the screen decides top or bottom,
-- near the middle it snaps to the middle. Not in combat while a click button lies on it (those can't move then).
function IB.MoveStart()
  if inCombat() and secureShown() then return end
  local d = db(); if not d or not GetCursorPosition then return end
  moving = true; GameTooltip:Hide(); foldLater(false); closeMenu()
  if not inCombat() then for _, b in ipairs(secures) do unlight(b); b:Hide() end end
  local s = band:GetEffectiveScale() or 1
  local grab = select(1, GetCursorPosition()) / s - ((band:GetLeft() or 0) + (band:GetWidth() or 0) / 2)
  band:SetScript("OnUpdate", function()
    -- the button was let go: stop here (beta8, user 11.11.: the bar kept following the cursor - OnDragStop never came
    -- when the drag began on a click button, which is hidden while moving)
    if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then IB.MoveStop(); return end
    local x, y = GetCursorPosition(); x, y = x / s, y / s
    local k = (UIParent:GetEffectiveScale() or 1) / s
    local sw, sh = (UIParent:GetWidth() or 0) * k, (UIParent:GetHeight() or 0) * k
    local half = math.max(0, (sw - (band:GetWidth() or 0)) / 2)
    local nx = math.floor(math.max(-half, math.min(half, x - grab - sw / 2)) + 0.5)
    if math.abs(nx) < 12 then nx = 0 end
    local edge = y < sh / 2 and "BOTTOM" or nil
    local flip = edge ~= d.infoBarEdge
    d.infoBarX, d.infoBarEdge = nx ~= 0 and nx or nil, edge
    if flip then applyEdge() else placeBand(shownP); placeHandle() end
  end)
end
-- Quality of Life "Bar position: Reset" (user 11.11.): top middle again
function IB.ResetPosition()
  local d = db(); if not d then return end
  d.infoBarX, d.infoBarEdge = nil, nil
  if band then applyEdge() end
end
function IB.MoveStop()
  if not moving then return end
  moving = false
  band:SetScript("OnUpdate", nil)
  if C_Timer and C_Timer.After then C_Timer.After(0, syncSecure) end
  foldLater(true)
end
-- colour and opacity from Quality of Life
local function applyLook()
  local r, g, b = barColor()
  for _, f in ipairs({ band, handle }) do
    for _, t in ipairs(f.fills or {}) do t:SetVertexColor(r, g, b) end
  end
  handle:SetAlpha(barAlpha())
  if shownP then band:SetAlpha((0.2 + 0.8 * shownP * shownP * (3 - 2 * shownP)) * barAlpha()) end
end

local function build()
  band = CreateFrame("Frame", "OneForAllInfoBar", UIParent)
  band:SetFrameStrata("HIGH"); band:SetHeight(H); band:SetPoint("TOP", UIParent, "TOP", 0, 2)
  band:EnableMouse(true); band:Hide()
  shape(band, H)
  band.empty = FLT.NewFS(band, nil, "OVERLAY", "GameFontDisableSmall"); band.empty:SetPoint("LEFT", PAD, -1)
  band.empty:SetText(L["Right-click to add elements"])
  -- (beta15, user 09.11.: no pin button on the band any more - pinning is in the right-click menu, with a pin icon)
  band:SetScript("OnEnter", function() foldLater(false) end)
  band:SetScript("OnLeave", function() foldLater(true) end)
  band:SetScript("OnMouseUp", function(self, button) if button == "RightButton" then openMenu(self) end end)
  band:RegisterForDrag("LeftButton") -- Shift-drag on the empty parts moves it too
  band:SetScript("OnDragStart", function() if IsShiftKeyDown and IsShiftKeyDown() then IB.MoveStart() end end)
  band:SetScript("OnDragStop", function() if moving then IB.MoveStop() end end)
  -- the handle: a small tab at the edge while the bar is folded up; the mouse on it opens the bar
  handle = CreateFrame("Button", nil, UIParent); handle:SetFrameStrata("HIGH"); handle:SetSize(128, 10) -- user 08.11.: twice as wide, no arrow
  handle:SetPoint("TOP", UIParent, "TOP", 0, 2); handle:Hide()
  shape(handle, 10, "_s")
  handle:SetScript("OnEnter", function() setOpen(true, true); foldLater(false) end)
  handle:SetScript("OnLeave", function() foldLater(true) end)
  -- one event frame: only the events of the chosen elements
  ev = CreateFrame("Frame")
  ev:SetScript("OnEvent", function(_, event)
    -- the gold of this character is saved at once, not only when the bar draws its text (6.2.12-beta9, user 18.11.: the
    -- mage had 21 g, the list of the other characters still 12 g - a folded bar draws nothing, so nothing was saved);
    -- at logout only a real amount (the 0 read there is not trusted, see saveGold)
    if event == "PLAYER_MONEY" then moneyEvent = true; saveGold()
    elseif event == "PLAYER_LOGOUT" then if GetMoney and (GetMoney() or 0) > 0 then saveGold() end return end
    if event == "PLAYER_REGEN_ENABLED" then
      if secureFolds then secureFolds = false; foldLater(true) end
      syncSecure(); return
    end
    for _, k in ipairs(byEvent[event] or {}) do dirty[k] = true end
    queue()
  end)
end

local function registerEvents()
  ev:UnregisterAllEvents()
  wipe(byEvent)
  if not on() then return end
  for _, k in ipairs(items()) do
    for _, e in ipairs(E[k].events or {}) do
      if not byEvent[e] then byEvent[e] = {}; pcall(ev.RegisterEvent, ev, e) end
      table.insert(byEvent[e], k)
    end
  end
  for _, k in ipairs(items()) do if E[k].secureItem or E[k].secureClick then pcall(ev.RegisterEvent, ev, "PLAYER_REGEN_ENABLED") end end
end

-- the switch, the elements or the pin changed: build lazily, then show / hide. keepOpen: open now (just switched on in
-- Quality of Life - QoL.On passes true - or an element / the pin was picked), it folds later when not pinned
-- size from Quality of Life (qol.infoBarScale, 50 - 150 %, user 08.11.)
local function applyScale()
  local d = db()
  local sc = math.max(0.5, math.min(1.5, (tonumber(d and d.infoBarScale) or 100) / 100))
  band:SetScale(sc); handle:SetScale(sc)
end
function IB.SetScale() if band then applyScale(); syncSecure() end end
function IB.SetLook() if band then applyLook() end end

function IB.Apply(keepOpen)
  if not on() then
    if band then band:Hide(); handle:Hide(); ev:UnregisterAllEvents(); closeMenu(); open = false; syncSecure() end -- secure buttons too
    open = false; setTicker(); syncSecure()
    return
  end
  if not band then build() end
  applyScale(); applyLook(); applyEdge()
  registerEvents()
  -- the amount after login, a moment later (read too early it can be 0), also with the bar folded
  if not goldSaved and byEvent.PLAYER_MONEY and C_Timer and C_Timer.After then
    goldSaved = true; C_Timer.After(5, saveGold)
  end
  -- a guild element asks the server for the roster once (the client does not keep it fresh on its own)
  for _, k in ipairs(items()) do if k == "guild" and C_GuildInfo and C_GuildInfo.GuildRoster then call(C_GuildInfo.GuildRoster) end end
  for _, k in ipairs(items()) do if k == "friends" and C_FriendList and C_FriendList.ShowFriends then call(C_FriendList.ShowFriends) end end
  setOpen(pinned() or keepOpen == true or (band:IsShown() and band:IsMouseOver()))
end
IB._layout, IB._setOpen = layout, setOpen -- tests

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self)
  self:UnregisterAllEvents()
  if FLT.QoL and FLT.QoL.On then FLT.QoL.On("infoBar", IB.Apply); FLT.QoL.On("infoBarScale", IB.SetScale)
    FLT.QoL.On("infoBarColor", IB.SetLook); FLT.QoL.On("infoBarAlpha", IB.SetLook) end
  if on() then if FLT.SafeCall then FLT.SafeCall("InfoBar", IB.Apply) else pcall(IB.Apply) end end
end)
