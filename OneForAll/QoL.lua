local _, FLT = ...

-- Quality of Life: small automations and tooltip additions. Every feature has
-- its own switch in the Quality of Life tab. The default (on/off) is decided by
-- the user per option (DEFAULTS); most are off so they do not clash with other
-- QoL addons. Holding Shift pauses the automations
-- (repair, junk, quests, invites, duels).
-- Settings: OneForAllDB.qol[key].

local QoL = {}
local L = FLT.L or setmetatable({}, { __index = function(_, k) return k end }) -- (tests without Locales)
local function N(s) return s end -- marks an English text translated where it is shown (tools/locale/extract.py)
FLT.QoL = QoL

local DEFAULTS = {
  lootFeedQuality = 1, lootFeedMoney = true,
  inviteMode = "friendsguild", keywordMode = "friendsguild", keyword = "inv", duelMode = "friendsguild",
  durabilityPct = 20, mmDir = "auto", logoColor = "teal", -- logo color: turquoise by default (user 27.10.)
  logoSize = 100, -- size of the minimap / collector button in % (6.2.11, user 17.11.; 100 = as before)
  junkKey = "alt-right", -- the click that marks junk in the bags (6.2.12-beta3, user 18.11.: default stays Alt + right-click)
  lowRank = true, -- on by default (user 15.10.)
  tipMousePos = "BOTTOMRIGHT", -- Tooltip at the mouse: off, bottom right preselected (user 13.11.; the list showed "Top left" before)
  mapLandmarks = true, lmDungeons = true, lmFlight = true, lmTransport = true, lmTransitions = true, -- transitions: on like all landmarks (user 01.11.) -- Map Landmarks: on with all parts (user 16.10.)
  gearValue = true, -- Gear Planner Value in item tooltips: on (user 16.10.)
  ahScan = true, -- "Cheap Upgrade Scan" button in the auction house (6.2.13-beta19): on (user 21.11.)
  runTracker = true, -- dungeon tracker (6.2.14): on (user 23.11.: "ja an")
  gvMode = "overall", -- which % the Gear Value line shows (6.2.13): the whole gear's, as before (user 20.11.)
  spellbookTrainer = true, -- trainer button in the spellbook: on (user 22.10.)
  classBright = true, -- brighter class colors: on (user 22.10.)
  mapFog = true, -- Remove Fog: on (user 22.10.)
  hideAppearance = false, -- hide "You haven't collected this appearance" in item tooltips: off (user 01.11.)
  questSellCoin = true, -- gold coin on the quest reward with the best sell price: on (user 02.11.)
  infoBarScale = 100, -- info bar size in % (6.2.2, slider; 100 = as before)
  infoBarAlpha = 100, -- info bar opacity in % (whole bar, 6.2.2-beta43, user 09.11.); infoBarColor { r, g, b } = background, nil = default
  infoBarDelay = 3, -- seconds the info bar stays open after the mouse left it, when not pinned (user 09.11.: default 3)
  buffScale = 100, buffIconOnly = false, -- buff reminder size in % and icon only (6.0.3, user 01.11.)
  flightMapNow = true, -- open the flight map at once at a flight master (6.1.5): on (user 05.11.)
  -- skip the talk at service NPCs (6.2.13): every service off at first start (user 20.11.)
  gossipVendor = false, gossipBank = false, gossipTrainer = false, gossipAuction = false,
  gossipStable = false, gossipGuildBank = false, gossipTabard = false, gossipBattle = false,
  flightTimes = true, -- flight times: bar while flying, times on the flight map (6.1.5): on (user 05.11.)
  buffFlash = true, -- buff reminder cards glow (6.1.4, Discord 05.11.): on (user 05.11.)
  buffSnoozeBtn = false, -- "Zz" snooze button on the cards (6.1.4): off (user 05.11.)
  mapZoneLevel = true, -- level range of the zone on the world map: on (user 01.11.)
  mapQuests = true, -- quest icons on the world map: on (user 01.11., first off)
  npcQuestTip = true, -- quests to take / turn in on NPC tooltips (6.2.2): on, off while Questie is loaded (user 08.11.)
  mapQuestsContinent = true, -- quest icons also on the continent map: on (user 04.11.)
  mapQuestsGrey = false, -- also grey (low level) quests on the map (6.2.12-beta15, user 18.11.: "standard: Aus")
  mapQuestNoRoutes = false, -- hide the routes of walking quest givers (6.2.12-beta5; off = routes shown as before)
  mapQuestGivers = true, mapQuestTurnins = true, -- "!" and "?" each on their own: both on (user 07.11.)
  guildGames = false, -- Guild Games (6.2.12-beta4, user 14.11.: "standard aus")
  guildMap = true, -- guild members on the map, sends and shows (MapGuild.lua, 6.2.2): on (user 09.11.)
  mapFogAlpha = 100, -- how visible the unexplored parts are, 0-100 %; 100 (user 01.11.)
  mapBooks = true, -- Library Books on the world map: on (user 23.10.)
  mapButton = true, -- OneForAll button on the world map: on (user 01.11.)
  petAlertLower = false, -- pet ability alert also for missing lower ranks: off (user 17.11.)
  questMarkPos = "right", -- quest marks on nameplates: the switch is off, the mark right of the bar (user 01.11.)
  chatHistory = true, -- last sent messages with arrow up / down: on (user 31.10.)
  chatHide = true, chatAutoHide = 0, -- hide chat button: on, "Hide chat after": Never (user 27.10., 6.0.0)
}

local function db()
  if type(OneForAllDB) ~= "table" then return nil end
  OneForAllDB.qol = OneForAllDB.qol or {}
  return OneForAllDB.qol
end

-- 5.3: Social got own switches; keep what older settings did
local function migrate()
  local d = db(); if not d or d.socialMigrated then return end
  d.socialMigrated = true
  if d.inviteMode == "off" then d.inviteMode = nil elseif d.inviteMode then d.inviteOn = true end
  if d.keywordMode == "off" then d.keywordMode = nil elseif d.keywordMode then d.keywordOn = true end
  if d.duelMode == "all" then d.duelMode = nil elseif d.duelMode then d.duelOn = true end
end
QoL.Migrate = migrate

QoL.DEFAULTS = DEFAULTS -- read by the profile import (types)
function QoL.Get(key)
  local d = db()
  local v = d and d[key]
  if v == nil then v = DEFAULTS[key] end
  -- Skyborne map pins: on by default for Skyborne characters, off for the other races (user 30.10.)
  if v == nil and key == "lmSkyborne" then v = UnitRace and select(2, UnitRace("player")) == "Skyborne" or false end
  -- all ammo on the quiver: on by default for hunters, off for the other classes (user 09.11.)
  if v == nil and key == "quiverAmmo" then v = UnitClass and select(2, UnitClass("player")) == "HUNTER" or false end
  return v
end

local listeners = {}
-- In combat (6.2.2, user 08.11.: "fehler weil jemand waehrend des kampfes irgendwas im addon umstellt") a change is
-- saved at once but put into effect after combat: many switches touch Blizzard frames that are locked in combat.
function QoL.Set(key, value)
  local d = db()
  if not d then return end
  d[key] = value
  if not listeners[key] then return end
  if InCombatLockdown and InCombatLockdown() then QoL._waiting = QoL._waiting or {}; QoL._waiting[key] = true; return end
  listeners[key](value)
end
function QoL.ApplyWaiting()
  local w, d = QoL._waiting, db()
  QoL._waiting = nil
  if not (w and d) then return end
  for key in pairs(w) do if listeners[key] then listeners[key](d[key]) end end
end
local function on(key, fn) listeners[key] = fn end
QoL.On = on
QoL.LOGO_COLORS = { { key = "red", label = N"Red" }, { key = "blue", label = N"Blue" }, { key = "green", label = N"Green" },
  { key = "teal", label = N"Turquoise" }, { key = "violet", label = N"Violet" },
  { key = "bronze", label = N"Bronze" }, { key = "black", label = N"Black" } }
QoL.CHAT_HIDE_OPTIONS = { { key = 0, label = N"Never" }, { key = 10, label = N"10 seconds" }, { key = 20, label = N"20 seconds" },
  { key = 30, label = N"30 seconds" }, { key = 60, label = N"1 minute" } }
QoL.MM_DIR_OPTIONS = { { key = "auto", label = N"Automatic" }, { key = "top", label = N"Top" }, { key = "bottom", label = N"Bottom" },
  { key = "left", label = N"Left" }, { key = "right", label = N"Right" } }
-- the click that puts a bag item on the junk list (6.2.12-beta3, user 18.11.: some addons use Alt + right-click themselves).
-- Always with a modifier: a plain right-click uses the item. Not Shift + left (link to chat) or Ctrl + left (try on).
QoL.JUNK_KEY_OPTIONS = { { key = "alt-right", label = N"Alt + right-click" }, { key = "ctrl-right", label = N"Ctrl + right-click" },
  { key = "alt-left", label = N"Alt + left-click" }, { key = "ctrl-alt-right", label = N"Ctrl + Alt + right-click" },
  { key = "shift-alt-right", label = N"Shift + Alt + right-click" } }
-- Gear Value in tooltips: which % it shows (6.2.13, user 20.11.: drop-down "item<>item, overall, both"; default "Overall" =
-- as players had it): % of the replaced item, % of the whole gear, or both ("65% (overall 6%)")
QoL.GV_MODE_OPTIONS = { { key = "overall", label = N"Whole gear" }, { key = "item", label = N"Item against item" },
  { key = "both", label = N"Both" } }
QoL.JUNK_KEYS = { ["alt-right"] = { alt = true, b = "RightButton" }, ["ctrl-right"] = { ctrl = true, b = "RightButton" },
  ["alt-left"] = { alt = true, b = "LeftButton" }, ["ctrl-alt-right"] = { ctrl = true, alt = true, b = "RightButton" },
  ["shift-alt-right"] = { shift = true, alt = true, b = "RightButton" } }
function QoL.JunkKeyText() -- the chosen click in the player's language (tooltips)
  local k = QoL.Get("junkKey")
  for _, o in ipairs(QoL.JUNK_KEY_OPTIONS) do if o.key == k then return L[o.label] end end
  return L["Alt + right-click"]
end

local function msg(text) if FLT.Msg then FLT.Msg(text) end end
local function paused() return IsShiftKeyDown and IsShiftKeyDown() end
local COIN = {
  g = "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t",
  s = "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t",
  c = "|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t",
}
-- 13940 -> "1g 39s 40c" with coin icons (zero parts are left out)
local function money(c)
  c = math.floor(tonumber(c) or 0)
  local g, s, cu = math.floor(c / 10000), math.floor(c / 100) % 100, c % 100
  local parts = {}
  if g > 0 then parts[#parts + 1] = (BreakUpLargeNumbers and BreakUpLargeNumbers(g) or g) .. COIN.g end
  if s > 0 then parts[#parts + 1] = s .. COIN.s end
  if cu > 0 or #parts == 0 then parts[#parts + 1] = cu .. COIN.c end
  return table.concat(parts, " ")
end
QoL.Money = money
local function inCombat() return InCombatLockdown and InCombatLockdown() end

-- ---------------------------------------------------------------------------
-- Friends / guild checks (name may include a realm)
-- ---------------------------------------------------------------------------
local function short(n) return n and (tostring(n):match("^([^%-]+)") or n) or nil end

local function isFriend(name, guid)
  if guid and C_FriendList and C_FriendList.IsFriend then
    local ok, r = pcall(C_FriendList.IsFriend, guid); if ok and r then return true end
  end
  if guid and C_BattleNet and C_BattleNet.GetGameAccountInfoByGUID then
    local ok, r = pcall(C_BattleNet.GetGameAccountInfoByGUID, guid); if ok and r then return true end
  end
  local s = short(name)
  if s and C_FriendList and C_FriendList.GetNumFriends and C_FriendList.GetFriendInfoByIndex then
    for i = 1, C_FriendList.GetNumFriends() or 0 do
      local info = C_FriendList.GetFriendInfoByIndex(i)
      if info and short(info.name) == s then return true end
    end
  end
  return false
end

local function isGuild(name, guid)
  if not (IsInGuild and IsInGuild()) then return false end
  if guid and IsGuildMember then
    local ok, r = pcall(IsGuildMember, guid); if ok and r then return true end
  end
  local s = short(name)
  if s and GetNumGuildMembers and GetGuildRosterInfo then
    for i = 1, GetNumGuildMembers() or 0 do
      if short(GetGuildRosterInfo(i)) == s then return true end
    end
  end
  return false
end

-- mode: off/none, friends, guild, friendsguild, all
local function allowed(mode, name, guid)
  if mode == "all" then return true end
  if mode == "friends" then return isFriend(name, guid) end
  if mode == "guild" then return isGuild(name, guid) end
  if mode == "friendsguild" then return isFriend(name, guid) or isGuild(name, guid) end
  return false
end
QoL.WHO_OPTIONS = {
  { key = "friends", label = N"Friends" }, { key = "guild", label = N"Guild" },
  { key = "friendsguild", label = N"Friends & guild" }, { key = "all", label = N"Everyone" },
}

-- ---------------------------------------------------------------------------
-- Bags
-- ---------------------------------------------------------------------------
local NUM_BAGS = tonumber(NUM_BAG_SLOTS) or 4
local function numSlots(bag)
  local f = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
  return f and f(bag) or 0
end
local function itemInfo(bag, slot)
  if C_Container and C_Container.GetContainerItemInfo then
    local i = C_Container.GetContainerItemInfo(bag, slot)
    if i then return i.hyperlink, i.stackCount or 1, i.quality, i.hasNoValue, i.isLocked, i.iconFileID end
    return nil
  end
  if GetContainerItemInfo then
    local icon, count, locked, quality, _, _, link, _, noValue = GetContainerItemInfo(bag, slot)
    return link, count or 1, quality, noValue, locked, icon
  end
end
-- vendor price of an item (C_Item first; GetItemInfo can be missing or wrapped)
local function sellPrice(item)
  if C_Item and C_Item.GetItemInfo then
    local ok, p = pcall(function() return select(11, C_Item.GetItemInfo(item)) end)
    if ok and tonumber(p) then return p end
  end
  if GetItemInfo then
    local ok, p = pcall(function() return select(11, GetItemInfo(item)) end)
    if ok and tonumber(p) then return p end
  end
  return 0
end
local function useItem(bag, slot)
  local f = (C_Container and C_Container.UseContainerItem) or UseContainerItem
  if f then pcall(f, bag, slot) end
end

-- ---------------------------------------------------------------------------
-- Loot, repair, junk
-- ---------------------------------------------------------------------------
-- Auto loot is the game's own setting (shown as a switch, see QoL.CVARS).
-- Quicker loot takes everything at once instead of item by item whenever the
-- game auto loots; holding the Auto Loot key (Shift) gives the loot window.
local function quickLoot()
  if not QoL.Get("quickLoot") or not GetNumLootItems or not LootSlot then return end
  local auto = GetCVarBool and GetCVarBool("autoLootDefault") and true or false
  -- 6.2.13-beta2 (Discord slips9497 20.11.: "quick loot stopped working ... basically its using the old auto loot"): with the
  -- Auto Loot key set to "None" the game answers IsModifiedClick("AUTOLOOTTOGGLE") with true all the time - then no key
  -- counts as held (guessed cause)
  local mod = GetModifiedClick and GetModifiedClick("AUTOLOOTTOGGLE")
  local key = mod ~= "NONE" and IsModifiedClick and IsModifiedClick("AUTOLOOTTOGGLE") and true or false
  if auto == key then return end
  -- once per loot window (6.2.13-beta23, Discord emzime 21.11. with log and patch): with full bags every LootSlot fails
  -- ("Inventory is full") and the server sends the loot again (LOOT_OPENED without LOOT_CLOSED) - asking for every slot again
  -- made a loop at network speed (game frozen, disconnect). QoL._quickLootAt: cleared on LOOT_CLOSED; after 10 s it may try
  -- once more (in case a LOOT_CLOSED was missed). A field, not a local: this file is at Lua's limit of 200 locals.
  if QoL._quickLootAt and GetTime() - QoL._quickLootAt < 10 then return end
  local n = GetNumLootItems() or 0
  if n == 0 then return end -- not known yet (LOOT_READY): LOOT_OPENED does it
  QoL._quickLootAt = GetTime()
  for i = n, 1, -1 do pcall(LootSlot, i) end
end

local function autoRepair()
  if not QoL.Get("autoRepair") or paused() then return end
  if not (CanMerchantRepair and CanMerchantRepair() and GetRepairAllCost and RepairAllItems) then return end
  local cost, can = GetRepairAllCost()
  if not can or not cost or cost <= 0 then return end
  if GetMoney and GetMoney() >= cost then
    RepairAllItems()
    msg(string.format(L["Repaired for %s."], money(cost)))
  else
    msg(string.format(L["Not enough money to repair (%s)."], money(cost)))
  end
end

-- own junk list (5.7.3, GitHub #22, user 27.10.): item IDs per character (OneForAllCharDB.junkList), sold by
-- "Sell junk" like grey items. The junk click (default Alt + right-click) on an item in the bags puts it on the list or off.
local function junkList()
  if type(OneForAllCharDB) ~= "table" then return {} end
  OneForAllCharDB.junkList = OneForAllCharDB.junkList or {}
  return OneForAllCharDB.junkList
end
function QoL.IsJunk(id) return id and junkList()[id] and true or false end
function QoL.GetJunkItems()
  local out = {}
  for id in pairs(junkList()) do if tonumber(id) then out[#out + 1] = tonumber(id) end end
  table.sort(out)
  return out
end
-- the junk coin on bag items (user 27.10.: like the game's coin on grey items). Baganator: a junk plugin (its coin,
-- grey-out and Vendor button), registered at login so Baganator always finds it (its settings dialog resets a junk
-- source it cannot find, user 27.10.: no coin on a new character); it answers like Baganator's own "Poor quality"
-- plus our list. Baganator > Junk detection picks it;
-- the game's bags: our own coin on the item buttons, painted when a bag frame updates.
local markBags -- forward
local bgnPlugin
local function bgnJunk(_, _, itemID, itemLink)
  if not itemID then return false end
  if QoL.Get("sellJunk") and junkList()[itemID] then return true end
  local _, _, q, _, _, _, _, _, _, _, price = ((C_Item and C_Item.GetItemInfo) or GetItemInfo)(itemLink or itemID)
  return q == 0 and (price or 0) > 0 -- like Baganator's own: grey items with a sell price
end
-- Baganator uses one junk source at a time, and other addons register their own (RestedXP takes it over when a guide
-- is picked, user 27.10.). Every source registered after OneForAll also marks the items of our list: the callback of
-- each new plugin is wrapped (Baganator's own "Poor quality" is not a plugin; ours answers for grey items itself).
do
  local api = type(Baganator) == "table" and type(Baganator.API) == "table" and Baganator.API
  local orig = api and api.RegisterJunkPlugin
  if type(orig) == "function" then
    api.RegisterJunkPlugin = function(label, id, callback)
      if id ~= "oneforall_junk" and id ~= "none" and type(callback) == "function" then
        local cb = callback
        callback = function(bagID, slotID, itemID, itemLink)
          if itemID and QoL.Get("sellJunk") and junkList()[itemID] then return true end
          return cb(bagID, slotID, itemID, itemLink)
        end
      end
      return orig(label, id, callback)
    end
  end
end
local function junkChanged()
  local api = type(Baganator) == "table" and type(Baganator.API) == "table" and Baganator.API
  if api and api.RegisterJunkPlugin and not bgnPlugin then
    bgnPlugin = pcall(api.RegisterJunkPlugin, L["OneForAll junk list"], "oneforall_junk", bgnJunk)
  end
  if bgnPlugin and api and api.RequestItemButtonsRefresh then pcall(api.RequestItemButtonsRefresh) end
  if markBags then markBags() end
end
QoL.JunkChanged = junkChanged
function QoL.RemoveJunk(id) junkList()[id] = nil; junkChanged() end
function QoL.ClearJunk() if type(OneForAllCharDB) == "table" then OneForAllCharDB.junkList = {} end; junkChanged() end
function QoL.ToggleJunk(link)
  local id = type(link) == "string" and tonumber(link:match("item:(%d+)"))
  if not id then return end
  local l = junkList()
  -- grey items are always junk (sold and marked anyway): no list entry, no misleading message (user 27.10.)
  local q = select(3, ((C_Item and C_Item.GetItemInfo) or GetItemInfo)(link))
  if q == 0 then
    l[id] = nil
    msg(string.format(L["%s is a grey item - Sell junk always sells grey items, the junk list is for other items."], link))
    return junkChanged()
  end
  if l[id] then l[id] = nil; msg(string.format(L["%s is no longer on your junk list."], link))
  else l[id] = true; msg(string.format(L["%s is on your junk list now - Sell junk sells it at merchants."], link)) end
  junkChanged()
end

local sellTicker
local function sellJunk()
  if not QoL.Get("sellJunk") or paused() then return end
  if sellTicker then sellTicker:Cancel(); sellTicker = nil end
  local list, total = {}, 0
  -- 6.2.13 (Discord seekay1): the reagent bag too (bag 5 = NUM_TOTAL_EQUIPPED_BAG_SLOTS; the other bag loops stay 0-4)
  for bag = 0, math.max(NUM_BAGS, tonumber(NUM_TOTAL_EQUIPPED_BAG_SLOTS) or 0) do
    for slot = 1, numSlots(bag) do
      local link, count, quality, noValue, locked = itemInfo(bag, slot)
      local id = link and tonumber(link:match("item:(%d+)"))
      if link and (quality == 0 or junkList()[id]) and not noValue and not locked then
        local price = sellPrice(link)
        if price > 0 then list[#list + 1] = { bag, slot, link, price } end
      end
    end
  end
  if #list == 0 or not (C_Timer and C_Timer.NewTicker) then return end
  local i, sold, gold = 0, 0, 0
  local function stop()
    if sellTicker then sellTicker:Cancel(); sellTicker = nil end
    if sold > 0 then msg(sold == 1 and string.format(L["Sold 1 junk item for %s."], money(gold)) or string.format(L["Sold %d junk items for %s."], sold, money(gold))) end
  end
  -- each slot is checked again right before it is sold (code review 03.11.): the same item, still junk, not
  -- locked, the option still on, the merchant still open, Shift not held - items moved in between are skipped
  sellTicker = C_Timer.NewTicker(0.15, function()
    i = i + 1
    if not (type(MerchantFrame) == "table" and MerchantFrame:IsShown()) or not QoL.Get("sellJunk") or paused() then stop(); return end
    local e = list[i]
    if e then
      local link, count, quality, noValue, locked = itemInfo(e[1], e[2])
      local id = link and tonumber(link:match("item:(%d+)"))
      if link == e[3] and (quality == 0 or junkList()[id]) and not noValue and not locked then
        useItem(e[1], e[2])
        sold = sold + 1; gold = gold + e[4] * (count or 1)
      end
    end
    if i >= #list then stop() end
  end, #list)
end

-- ---------------------------------------------------------------------------
-- Quests
-- ---------------------------------------------------------------------------
-- grey quests are not accepted by themselves (6.1.5, user 05.11.)
local function grey(id, level, trivial)
  if trivial then return true end
  return FLT.IsQuestGrey and FLT.IsQuestGrey(id, level) or false
end
local function questDetail()
  if not (QoL.Get("autoAccept") and not paused() and AcceptQuest) then return end
  if grey(GetQuestID and GetQuestID()) then return end
  AcceptQuest()
end
-- quests that take battleground marks (Warsong Gulch, Arathi Basin, Alterac Valley) are not turned in by themselves:
-- the marks are worth keeping for other rewards (user 05.11.)
QoL.MARKS = { [20558] = true, [20559] = true, [20560] = true } -- (a table field: the file is at 200 locals)
local function takesMarks()
  if not (GetNumQuestItems and GetQuestItemLink) then return false end
  for i = 1, GetNumQuestItems() or 0 do
    local link = GetQuestItemLink("required", i)
    local id = type(link) == "string" and tonumber(link:match("item:(%d+)"))
    if id and QoL.MARKS[id] then return true end
  end
  return false
end
local function questProgress()
  if not (QoL.Get("autoTurnIn") and not paused() and IsQuestCompletable and IsQuestCompletable() and CompleteQuest) then return end
  if takesMarks() then msg(L["Not turned in automatically: this quest takes your battleground marks."]); return end
  CompleteQuest()
end
-- 6.2.10-beta16 (Discord thunderous_one 16.11.: a quest with two reward choices handed out the cloth head by itself after
-- the player came back to the NPC): reward choices were already left alone (n > 1), but a count read too early (0) would
-- have turned the quest in with GetQuestReward(0). Now the turn-in waits a moment, reads the count again, asks the quest
-- log too (its reward data is there since the quest was accepted) and gives up on any doubt.
function QoL.ChoicesInLog(id)
  if not (id and id > 0 and GetNumQuestLogChoices) then return 0 end
  local ok, n = pcall(GetNumQuestLogChoices, id, true)
  return ok and tonumber(n) or 0
end
local function questComplete()
  if not QoL.Get("autoTurnIn") or paused() or not GetQuestReward then return end
  local n = GetNumQuestChoices and GetNumQuestChoices() or 0
  local id = GetQuestID and GetQuestID() or 0
  if n > 1 or QoL.ChoicesInLog(id) > 1 then return end -- reward choices stay manual
  local title = GetTitleText and GetTitleText()
  local function turnIn()
    if paused() or not (QuestFrame and QuestFrame:IsShown()) then return end
    if (GetTitleText and GetTitleText()) ~= title or (GetQuestID and GetQuestID() or 0) ~= id then return end
    local now = GetNumQuestChoices and GetNumQuestChoices() or 0
    if now ~= n or now > 1 or QoL.ChoicesInLog(id) > 1 then return end
    if title and GetTime then QoL.recentTurnIn[title] = GetTime() end
    GetQuestReward(now)
  end
  if C_Timer and C_Timer.After then C_Timer.After(0.3, turnIn) else turnIn() end
end
-- repeatable quests are left alone (6.2.5, Discord kersey 11.11.: Mangletooth's repeatable Blood Shard quests were turned
-- in again and again, the other quests never). Gossip and the available list say "repeatable"; for the active list of a
-- quest greeting the quest log is asked, and a quest turned in a moment ago is not picked again (the loop's safety net)
-- (table fields, not locals: the file is at 200 locals)
QoL.recentTurnIn = {} -- [title] = GetTime() of the automatic turn-in
function QoL.RepeatableID(id)
  return id and C_QuestLog and C_QuestLog.IsRepeatableQuest and C_QuestLog.IsRepeatableQuest(id) or false
end
function QoL.JustTurnedIn(title)
  local t = title and QoL.recentTurnIn[title]
  return t and GetTime and GetTime() - t < 60 or false
end
local function questGreeting()
  if paused() then return end
  if QoL.Get("autoTurnIn") and GetNumActiveQuests then
    for i = 1, GetNumActiveQuests() or 0 do
      local title, complete = GetActiveTitle(i)
      local id = GetActiveQuestID and GetActiveQuestID(i)
      if complete and not QoL.RepeatableID(id) and not QoL.JustTurnedIn(title) then SelectActiveQuest(i); return end
    end
  end
  if QoL.Get("autoAccept") and GetNumAvailableQuests then
    for i = 1, GetNumAvailableQuests() or 0 do
      local trivial, _, rep, _, id
      if GetAvailableQuestInfo then trivial, _, rep, _, id = GetAvailableQuestInfo(i) end
      if not rep and not grey(id, nil, trivial) then SelectAvailableQuest(i); return end
    end
  end
end
-- flight master: straight to the flight map (6.1.5, user 05.11.) - not when it also has quests, not with Shift
local function taxiOption()
  if not (C_GossipInfo and C_GossipInfo.GetOptions) then return nil end
  if #(C_GossipInfo.GetAvailableQuests and C_GossipInfo.GetAvailableQuests() or {}) > 0 then return nil end
  if #(C_GossipInfo.GetActiveQuests and C_GossipInfo.GetActiveQuests() or {}) > 0 then return nil end
  for _, o in ipairs(C_GossipInfo.GetOptions() or {}) do
    local icon = o.icon
    if o.type == "taxi" or icon == 132057 or (type(icon) == "string" and icon:lower():find("taxi")) then return o end
  end
end
-- skip the talk at service NPCs (6.2.13, user 20.11.: "gossip ueberspringen wie Dialoge, Bank, etc"; a drop-down with each
-- service on its own, all off at first start): only when the NPC has no quests for you and exactly ONE option, and that
-- one is the service; Shift talks normally. The client's gossip icons (Interface\GossipFrame\*GossipIcon, Mainline file
-- IDs) - auctioneer / stable master / guild bank by the icon path where the client gives one (im Spiel pruefen)
QoL.GOSSIP_SERVICES = {
  { "gossipVendor", { [132060] = true }, "vendor" },
  { "gossipBank", { [132050] = true }, "banker" },
  { "gossipTrainer", { [132058] = true }, "trainer" },
  { "gossipAuction", {}, "auction" },
  { "gossipStable", {}, "stable" },
  { "gossipGuildBank", {}, "guildbank" },
  { "gossipTabard", { [132056] = true }, "tabard" },
  { "gossipBattle", { [132051] = true }, "battlemaster" },
}
function QoL.ServiceOption() -- (a field, not a local: this file is at the 200 locals limit)
  if not (C_GossipInfo and C_GossipInfo.GetOptions) then return nil end
  if #(C_GossipInfo.GetAvailableQuests and C_GossipInfo.GetAvailableQuests() or {}) > 0 then return nil end
  if #(C_GossipInfo.GetActiveQuests and C_GossipInfo.GetActiveQuests() or {}) > 0 then return nil end
  local opts = C_GossipInfo.GetOptions() or {}
  if #opts ~= 1 then return nil end
  local o = opts[1]
  local icon = o.icon
  local path = type(icon) == "string" and icon:lower() or nil
  for _, sv in ipairs(QoL.GOSSIP_SERVICES) do
    if QoL.Get(sv[1]) and (sv[2][icon] or (path and path:find(sv[3], 1, true)) or o.type == sv[3]) then return o end
  end
end
local function gossipShow()
  if paused() or not C_GossipInfo then return end
  if QoL.Get("flightMapNow") then
    local o = taxiOption()
    if o and o.gossipOptionID and C_GossipInfo.SelectOption then C_GossipInfo.SelectOption(o.gossipOptionID); return end
  end
  do
    local o = QoL.ServiceOption()
    if o and o.gossipOptionID and C_GossipInfo.SelectOption then C_GossipInfo.SelectOption(o.gossipOptionID); return end
  end
  if QoL.Get("autoTurnIn") and C_GossipInfo.GetActiveQuests then
    for _, q in ipairs(C_GossipInfo.GetActiveQuests() or {}) do
      if q.isComplete and q.questID and not q.repeatable and (q.frequency or 0) == 0 and not QoL.RepeatableID(q.questID)
        and not QoL.JustTurnedIn(q.title) then C_GossipInfo.SelectActiveQuest(q.questID); return end
    end
  end
  if QoL.Get("autoAccept") and C_GossipInfo.GetAvailableQuests then
    for _, q in ipairs(C_GossipInfo.GetAvailableQuests() or {}) do
      if q.questID and not q.repeatable and (q.frequency or 0) == 0 and not grey(q.questID, q.questLevel, q.isTrivial) then
        C_GossipInfo.SelectAvailableQuest(q.questID); return
      end
    end
  end
end

-- ---------------------------------------------------------------------------
-- Social: invites, keyword invites, duels, thanks for buffs
-- ---------------------------------------------------------------------------
local function partyInvite(name, ...)
  if not QoL.Get("inviteOn") or paused() then return end
  local mode = QoL.Get("inviteMode")
  local guid = select(6, ...)
  if allowed(mode, name, guid) and AcceptGroup then
    AcceptGroup()
    if StaticPopup_Hide then StaticPopup_Hide("PARTY_INVITE") end
    msg(string.format(L["Accepted the group invite from %s."], tostring(short(name))))
  end
end

local function whisper(text, sender, ...)
  if not QoL.Get("keywordOn") or type(text) ~= "string" then return end
  local mode = QoL.Get("keywordMode")
  local kw = tostring(QoL.Get("keyword") or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  if kw == "" or text:lower():gsub("^%s+", ""):gsub("%s+$", "") ~= kw then return end
  local guid = select(10, ...)
  if not allowed(mode, sender, guid) then return end
  if IsInGroup and IsInGroup() and not ((UnitIsGroupLeader and UnitIsGroupLeader("player")) or (UnitIsGroupAssistant and UnitIsGroupAssistant("player"))) then return end
  local invite = (C_PartyInfo and C_PartyInfo.InviteUnit) or InviteUnit
  if invite then pcall(invite, sender) end
end

local function duelRequested(name)
  if not QoL.Get("duelOn") then return end
  local mode = QoL.Get("duelMode")
  if not allowed(mode, name) and CancelDuel then
    CancelDuel()
    if StaticPopup_Hide then StaticPopup_Hide("DUEL_REQUESTED") end
    msg(string.format(L["Declined a duel from %s."], tostring(short(name))))
  end
end
QoL.DUEL_OPTIONS = {
  { key = "friendsguild", label = N"Friends & guild" },
  { key = "friends", label = N"Friends" }, { key = "guild", label = N"Guild" }, { key = "off", label = N"No one" },
}

-- Thanks for buffs (5.6.2): a /thank emote for players outside the group who give
-- you a longer buff. The caster comes from the buff itself
-- (C_UnitAuras.GetAuraCasterGUID), so he does not have to be your target, under the
-- mouse or on a nameplate; the unit token the game sometimes passes is a fallback.
-- Rules: helpful buff > 2 minutes, just applied or refreshed (not an old buff the
-- game reports again after login, /reload or a loading screen), another player,
-- not in your group or raid. The emote goes out THANKS_DELAY seconds later, out of
-- combat, at most once per THANKS_PLAYER_CD per player and one every THANKS_GAP s.
-- The combat log cannot be used: registering COMBAT_LOG_EVENT_UNFILTERED is
-- forbidden in the Forever client (5.5.0-beta11). /ofa thanks shows what happened.
local THANKS_DELAY, THANKS_GAP, THANKS_PLAYER_CD = 1, 3, 300 -- 1 s delay (user 16.10.)
local THANKS_MIN_DURATION, THANKS_FRESH, THANKS_SETTLE = 120, 3, 6
local thanked, thanksPending, lastThanks, settleUntil = {}, {}, 0, 0
local thanksLog = {} -- last few buffs for /ofa thanks
local function logThanks(text)
  table.insert(thanksLog, 1, date and (date("%H:%M:%S ") .. text) or text)
  thanksLog[9] = nil
end
function QoL.PrintThanksLog()
  if #thanksLog == 0 then msg(L["Thanks for buffs: no buffs seen yet."]); return end
  for i = #thanksLog, 1, -1 do msg(string.format(L["Thanks: %s"], thanksLog[i])) end
end
local function now() return GetTime and GetTime() or 0 end
local function readable(...) return not FLT.IsSecret(...) end

-- after a loading screen the game reports all buffs again: wait until it is quiet
local function thanksSettle() settleUntil = now() + THANKS_SETTLE end

local function inMyGroup(guid)
  if not guid or not UnitGUID then return false end
  if IsInRaid and IsInRaid() then
    for i = 1, 40 do if UnitGUID("raid" .. i) == guid then return true end end
  elseif IsInGroup and IsInGroup() then
    for i = 1, 4 do if UnitGUID("party" .. i) == guid then return true end end
  end
  return false
end

local function nameFromGUID(guid)
  local name
  if UnitNameFromGUID then pcall(function() name = UnitNameFromGUID(guid) end) end
  if not name and GetPlayerInfoByGUID then pcall(function() name = select(6, GetPlayerInfoByGUID(guid)) end) end
  if type(name) ~= "string" or name == "" or not readable(name) then return nil end
  return (name:match("^([^%-]+)")) -- the emote wants the plain name
end

local function sendThank(name)
  if C_ChatInfo and C_ChatInfo.PerformEmote then
    local ok, restricted = pcall(C_ChatInfo.PerformEmote, "THANK", name)
    return ok and not (readable(restricted) and restricted)
  end
  if DoEmote then return (pcall(DoEmote, "THANK", name)) end
  return false
end

local function fireThanks(guid)
  local p = thanksPending[guid]
  if not p then return end
  if not QoL.Get("thanksBuff") then thanksPending[guid] = nil; return end
  local t = now()
  -- in combat or right after another thank: try again a little later
  if inCombat() or t - lastThanks < THANKS_GAP then
    if C_Timer and C_Timer.After then C_Timer.After(THANKS_GAP, function() fireThanks(guid) end) end
    return
  end
  thanksPending[guid] = nil
  if thanked[guid] and t - thanked[guid] < THANKS_PLAYER_CD then logThanks(string.format(L["%s from %s: thanked recently"], p.spell, p.name)); return end
  thanked[guid], lastThanks = t, t
  if sendThank(p.name) then logThanks(string.format(L["%s from %s: /thank"], p.spell, p.name))
  else logThanks(string.format(L["%s from %s: the game did not allow the emote"], p.spell, p.name)) end
end

local function considerAura(a)
  if type(a) ~= "table" then return end
  local helpful, id, duration, expires, spell = a.isHelpful, a.auraInstanceID, a.duration, a.expirationTime, a.name
  if not readable(helpful, id, duration, expires, spell) then logThanks(L["buff hidden by the game"]); return end
  if not helpful or type(duration) ~= "number" or type(expires) ~= "number" then return end
  spell = type(spell) == "string" and spell or L["a buff"]
  if duration <= THANKS_MIN_DURATION then return end -- short effects (Renew, procs ...)
  local t = now()
  if math.abs((expires - duration) - t) > THANKS_FRESH then return end -- not just applied
  -- the caster: from the buff itself, else the unit the game named
  local guid
  if C_UnitAuras and C_UnitAuras.GetAuraCasterGUID and id then
    pcall(function() guid = C_UnitAuras.GetAuraCasterGUID("player", id) end)
  end
  if not guid and type(a.sourceUnit) == "string" and readable(a.sourceUnit) and UnitGUID then guid = UnitGUID(a.sourceUnit) end
  if not readable(guid) then logThanks(string.format(L["%s: caster hidden by the game"], spell)); return end
  if type(guid) ~= "string" then logThanks(string.format(L["%s: the game gave no caster"], spell)); return end
  if not guid:match("^Player%-") or (UnitGUID and guid == UnitGUID("player")) then return end
  local name = nameFromGUID(guid)
  if not name then logThanks(string.format(L["%s: caster name unknown"], spell)); return end
  if inMyGroup(guid) then logThanks(string.format(L["%s from %s: group member, no emote"], spell, name)); return end
  if thanksPending[guid] then return end -- several buffs from one player: one thank
  thanksPending[guid] = { name = name, spell = spell }
  if C_Timer and C_Timer.After then C_Timer.After(THANKS_DELAY, function() fireThanks(guid) end) else fireThanks(guid) end
end

local function scanAuraUpdate(info)
  if type(info) ~= "table" or not readable(info.isFullUpdate) or info.isFullUpdate then return end
  if type(info.addedAuras) == "table" and readable(info.addedAuras) then
    for _, a in ipairs(info.addedAuras) do considerAura(a) end
  end
  -- refreshed buffs (same aura, new duration)
  local upd = info.updatedAuraInstanceIDs
  if type(upd) == "table" and readable(upd) and C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID then
    for _, id in ipairs(upd) do
      local ok, a = pcall(C_UnitAuras.GetAuraDataByAuraInstanceID, "player", id)
      if ok and readable(a) then considerAura(a) end
    end
  end
end
local function playerAura(unit, info)
  if unit ~= "player" or not QoL.Get("thanksBuff") or inCombat() or now() < settleUntil then return end
  pcall(scanAuraUpdate, info)
end
QoL._thanks = { consider = considerAura, fire = fireThanks, settle = thanksSettle, pending = thanksPending,
  reset = function() for k in pairs(thanked) do thanked[k] = nil end; lastThanks, settleUntil = 0, 0 end }

-- ---------------------------------------------------------------------------
-- Buff reminder (6.0.1, user 31.10.): own buffs (e.g. Demon Skin) with a time in seconds. When one has less time
-- left - or ran out after it was up - a small popup says so; a click on its icon casts the buff again. It goes away by
-- itself once the buff is back. The popup can be dragged, its place is remembered (qol.buffPopupPos).
-- Checks: UNIT_AURA (player, short debounce) plus ONE timer to the next moment a buff reaches its time; the 1 s
-- countdown only runs while the popup is shown. The list lives in OneForAllCharDB.buffReminders = { [spell name] = seconds }
-- (per character since 6.2.13; before: qol.buffReminders for the whole account, copied to each character once).
-- ---------------------------------------------------------------------------
local checkBuffs, buffAura, syncBuffButton, inCapital, layoutCard, noteRanks -- set in the block below (keeps the file under 200 locals)
do
  -- per character since 6.2.13 (user 20.11.: "den buff-reminder characterbezogen machen"): OneForAllCharDB.buffReminders /
  -- .buffIDs; a character without its own list starts with a copy of the old account-wide one (qol.buffReminders), so
  -- nobody loses entries - then each character keeps its own. Without the character table (very early): the account one.
  local function charList(field)
    local c = OneForAllCharDB
    if type(c) ~= "table" then
      local d = db(); if not d then return {} end
      d[field] = d[field] or {}
      return d[field]
    end
    if type(c[field]) ~= "table" then
      local d, copy = db(), {}
      for k, v in pairs(d and d[field] or {}) do copy[k] = v end
      c[field] = copy
    end
    return c[field]
  end
  local function buffList() return charList("buffReminders") end
  -- the spell / item ID of each watched buff (6.2.0, user 07.11.: after switching the client from English to German the
  -- saved English names matched nothing): qol.buffIDs[key] = spell ID or "i<item ID>". The list keys stay names in the
  -- client's language (the cast buttons need them); migrateBuffs() renames them when the client language changed.
  local function buffIDs() return charList("buffIDs") end
  -- weapon enchants (6.0.3, user 01.11.: oils, sharpening stones, poisons): key "<item name>@mh" / "@oh"
  local SLOTS = { mh = 16, oh = 17 }
  local SLOT_LABEL = { mh = N"main hand", oh = N"off hand" } -- shown with L[...]
  local function weapon(key) -- item name, slot id, "mh"/"oh" (nil for normal buffs)
    local item, hand = tostring(key):match("^(.+)@(%a%a)$")
    if item and SLOTS[hand] then return item, SLOTS[hand], hand end
  end
  QoL.BuffWeapon = weapon
  local function label(key)
    local item, _, hand = weapon(key)
    return item and (item .. " (" .. L[SLOT_LABEL[hand]] .. ")") or key
  end
  QoL.BuffLabel = label
  function QoL.GetBuffReminders()
    local out = {}
    for name, sec in pairs(buffList()) do out[#out + 1] = { name = name, sec = sec, label = label(name) } end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
  end
  -- icons of buffs that are no spell of yours (Well Fed, flasks, buffs from others; user 05.11.: question mark):
  -- taken from the aura when it is up, kept in OneForAllDB.qol.buffIcons
  local function noteIcon(name, icon)
    if not icon or FLT.IsSecret(icon) then return end
    local d = db(); if not d then return end
    d.buffIcons = d.buffIcons or {}
    if d.buffIcons[name] ~= icon then d.buffIcons[name] = icon end
  end
  local function spellIcon(name)
    local item, slot = weapon(name)
    if item then
      local ok, tex = pcall(function()
        local id = C_Item and C_Item.GetItemInfoInstant and C_Item.GetItemInfoInstant(item) or (GetItemInfoInstant and GetItemInfoInstant(item))
        local icon = id and (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id) or (GetItemIcon and GetItemIcon(id)))
        return icon or (GetInventoryItemTexture and GetInventoryItemTexture("player", slot))
      end)
      return ok and tex or "Interface\\Icons\\INV_Misc_QuestionMark"
    end
    local ok, tex = pcall(function()
      if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(name) end
      return GetSpellTexture and GetSpellTexture(name)
    end)
    if ok and tex then return tex end
    local d = db()
    return d and d.buffIcons and d.buffIcons[name] or "Interface\\Icons\\INV_Misc_QuestionMark"
  end
  QoL.BuffIcon = spellIcon
  -- expiration time (0 = no duration) and duration; nil when not on you; false when the game does not tell (in combat
  -- newer clients may keep aura data secret - then the card keeps its state, see checkBuffs)
  local weaponDur = {} -- the longest time seen per weapon key = the full duration for the bar
  -- shaman weapon imbues (user 05.11., Discord "Flametongue Weapon"): the spell puts an enchant on the main hand weapon,
  -- not a buff on you - read like an oil on the main hand
  -- user 05.11.: matched by name in the client's language (German "Waffe der Flammenzunge"): the names of the rank 1
  -- spells Rockbiter 8017, Flametongue 8024, Frostbrand 8033, Windfury 8232; "Weapon" / "Waffe" in the name as fallback
  local imbueNames
  local function imbue(name)
    if type(name) ~= "string" or not (UnitClass and select(2, UnitClass("player")) == "SHAMAN") then return false end
    if not imbueNames then
      imbueNames = {}
      for _, id in ipairs({ 8017, 8024, 8033, 8232 }) do
        local ok, n = pcall(function() return C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id) or (GetSpellInfo and GetSpellInfo(id)) end)
        if ok and type(n) == "string" then imbueNames[n] = true end
      end
    end
    return imbueNames[name] or name:find("Weapon") or name:find("Waffe") or false
  end
  -- tracking (6.2.2, user 09.11.: Find Herbs / Find Minerals as suggestions for gatherers): not a buff on you but the
  -- minimap's tracking - read from there (no duration: 0 = on, nil = off; nil from tracking() = not a tracking spell)
  local TRACKING = { 2383, 2580, 2481 } -- Find Herbs, Find Minerals, Find Treasure (dwarves)
  QoL.TRACKING = TRACKING
  local trackNames, trackCount = {}, 0
  local function tracking(name)
    if trackCount < #TRACKING then -- (again until the client has named all three)
      trackCount = 0
      for _, id in ipairs(TRACKING) do
        local ok, n = pcall(function() return C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id) or (GetSpellInfo and GetSpellInfo(id)) end)
        if ok and type(n) == "string" then trackNames[n] = id; trackCount = trackCount + 1 end
      end
    end
    local id = trackNames[name]
    if not id then return nil end
    local M = C_Minimap
    if M and M.GetNumTrackingTypes and M.GetTrackingInfo then
      local ok, num = pcall(M.GetNumTrackingTypes)
      for i = 1, (ok and tonumber(num) or 0) do
        local ok2, a, _, c = pcall(M.GetTrackingInfo, i) -- Classic: name, texture, active; newer: one table
        if ok2 then
          local n, active, sid = a, c, nil
          if type(a) == "table" then n, active, sid = a.name, a.active, a.spellID end
          if sid == id or n == name then return active and true or false end
        end
      end
    end
    if GetTrackingTexture then
      local ok, tex = pcall(GetTrackingTexture)
      local ok2, mine = pcall(function() return C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id) or (GetSpellTexture and GetSpellTexture(id)) end)
      if ok and ok2 then return tex ~= nil and tex == mine end
    end
    return nil
  end
  local function findBuff(name)
    local tr = tracking(name)
    if tr ~= nil then if tr then return 0, 0 end return end
    local item, slot = weapon(name)
    if not item and imbue(name) then item, slot = name, 16 end
    if item then -- expiration, duration, charges of the temporary enchant on that weapon
      if not GetWeaponEnchantInfo then return end
      local hasMH, mhMs, mhCharges, _, hasOH, ohMs, ohCharges = GetWeaponEnchantInfo()
      local has, ms, charges
      if slot == 16 then has, ms, charges = hasMH, mhMs, mhCharges else has, ms, charges = hasOH, ohMs, ohCharges end
      if FLT.IsSecret(has, ms, charges) then return false end
      if not has then return end
      local left = (tonumber(ms) or 0) / 1000
      if left > (weaponDur[name] or 0) then weaponDur[name] = left end
      return now() + left, weaponDur[name], tonumber(charges) or 0
    end
    -- go through the buffs ourselves (idea from GitHub #34, 05.11.): in combat the live client keeps some aura
    -- names secret; AuraUtil.FindAuraByName then just finds nothing ("run out"), here a secret one means "unknown"
    local get = type(C_UnitAuras) == "table" and C_UnitAuras.GetAuraDataByIndex
    if get then
      for i = 1, 40 do
        local ok, a = pcall(get, "player", i, "HELPFUL")
        if not ok then return false end
        if not a then return end
        if FLT.IsSecret(a.name) then return false end
        if a.name == name then
          noteIcon(name, a.icon)
          if a.spellId and not FLT.IsSecret(a.spellId) and not buffIDs()[name] then buffIDs()[name] = a.spellId end
          if FLT.IsSecret(a.expirationTime, a.duration) then return false end
          return a.expirationTime or 0, a.duration or 0
        end
      end
      return
    end
    if type(AuraUtil) == "table" and AuraUtil.FindAuraByName then
      local ok, n, icon, _, _, dur, exp = pcall(AuraUtil.FindAuraByName, name, "player", "HELPFUL")
      if ok and n and not FLT.IsSecret(n) then noteIcon(name, icon) end
      if not ok or FLT.IsSecret(n) then return false end
      if n and FLT.IsSecret(exp, dur) then return false end
      if n then return exp or 0, dur or 0 end
      return
    end
    for i = 1, 40 do
      local n, _, _, _, dur, exp = UnitBuff("player", i)
      if not n then return end
      if FLT.IsSecret(n, exp, dur) then return false end
      if n == name then return exp or 0, dur or 0 end
    end
  end
  -- buffs you cast again in combat (user 01.11.: the card stayed after rebuffing in combat): the card goes away at once;
  -- after combat the real check takes over again
  local renewed, wasDue = {}, {}

  -- Cards (user 31.10. mock-up): gold frame, big icon, the buff's name in gold, a grey line, a thin time bar at the
  -- bottom. Up to 4 under each other (the most urgent on top). Left-click the icon: cast it (secure button, made /
  -- changed only out of combat); right-click a card: not now; drag a card: move all (place in qol.buffPopupPos).
  local MAXC, CARD_W, CARD_H, GAP, ICON = 4, 270, 64, 6, 46
  local holder, cards, secures, due = nil, {}, {}, {}
  local testUntil = 0 -- "Test" in Quality of Life shows the cards for 10 s (user 01.11.)
  local buffSeen, buffDur, buffExp = {}, {}, {}
  -- snoozed (6.1.4, user 05.11.: Battle Shout while fishing): no card until the buff is up again or cast again
  local snoozed = {}
  local buffToken, buffDebounce, buffTicker = 0, false, nil
  local function scheduleBuffCheck(delay)
    buffToken = buffToken + 1
    local my = buffToken
    C_Timer.After(math.max(0.1, delay), function() if my == buffToken then checkBuffs() end end)
  end
  local function barColor()
    local c = type(RAID_CLASS_COLORS) == "table" and UnitClass and RAID_CLASS_COLORS[select(2, UnitClass("player")) or ""]
    if c then return c.r, c.g, c.b end
    return 0.58, 0.51, 0.79
  end
  local function paintCard(c)
    local exp, dur, charges = findBuff(c.spell)
    if exp == false then exp, dur, charges = nil, nil, nil end
    if not exp and buffExp[c.spell] then exp = buffExp[c.spell] end -- not readable (combat): the time we know
    local left = exp and exp > 0 and (exp - now()) or 0
    local item, _, hand = weapon(c.spell)
    local pre = item and ((L[SLOT_LABEL[hand]]:gsub("^%l", string.upper)) .. "  ") or ""
    local extra = (charges and charges > 0) and ("  |cff9d9d9d" .. string.format(L["%d charges"], charges) .. "|r") or ""
    if item and GetItemCount and (GetItemCount(item) or 0) == 0 then extra = extra .. "  |cffff6040" .. L["none in bags"] .. "|r" end
    if left > 0 then
      c.sub:SetText(pre .. L["Running out"] .. string.format("  |cffffd100%d:%02d|r", math.floor(left / 60), math.floor(left % 60)) .. extra)
    else
      c.sub:SetText(item and (pre .. L["run out"] .. extra) or L["Buff has run out"])
    end
    c.charges:SetText((charges and charges > 0) and tostring(charges) or "")
    if left > 0 then
      c.time:SetText(left >= 60 and (math.ceil(left / 60) .. "m") or tostring(math.floor(left)))
    else c.time:SetText("|cffff5050!|r") end
    dur = (dur and dur > 0) and dur or buffDur[c.spell]
    local frac = (dur and dur > 0) and math.max(0, math.min(1, left / dur)) or 0
    c.bar:SetWidth(math.max(1, (c.barW or (CARD_W - 24)) * frac)); c.bar:SetShown(frac > 0)
  end
  local function tick() for _, c in ipairs(cards) do if c:IsShown() then paintCard(c) end end end
  local function scale() return math.max(0.5, math.min(1.5, (tonumber(QoL.Get("buffScale")) or 100) / 100)) end
  local function makeHolder()
    holder = CreateFrame("Frame", "OneForAllBuffReminder", UIParent)
    holder:SetScale(scale())
    holder:SetSize(CARD_W, CARD_H); holder:SetFrameStrata("MEDIUM"); holder:SetClampedToScreen(true); holder:SetMovable(true)
    local pos = QoL.Get("buffPopupPos")
    if type(pos) == "table" then holder:SetPoint("CENTER", UIParent, "BOTTOMLEFT", pos[1], pos[2]) else holder:SetPoint("TOP", UIParent, "TOP", 0, -160) end
    holder:SetScript("OnShow", function() if not buffTicker and C_Timer.NewTicker then buffTicker = C_Timer.NewTicker(1, tick) end end)
    holder:SetScript("OnHide", function() if buffTicker then buffTicker:Cancel(); buffTicker = nil end end)
    holder:Hide()
  end
  -- normal: a card with name and time (cards under each other); icon only (user 01.11.): the icon with the time on
  -- it and the bar as wide as the icon (icons next to each other)
  function layoutCard(c)
    local only = QoL.Get("buffIconOnly")
    local i = c.i
    c.iconX, c.iconY = only and 4 or 10, only and -4 or -6
    c:SetSize(only and (ICON + 8) or CARD_W, only and (ICON + 16) or CARD_H)
    c:ClearAllPoints()
    if i == 1 then c:SetPoint("TOPLEFT")
    elseif only then c:SetPoint("TOPLEFT", cards[i - 1], "TOPRIGHT", GAP, 0)
    else c:SetPoint("TOPLEFT", cards[i - 1], "BOTTOMLEFT", 0, -GAP) end
    c.icon:ClearAllPoints(); c.icon:SetPoint("TOPLEFT", c.iconX, c.iconY)
    if c.zz then c.zz:ClearAllPoints(); if only then c.zz:SetPoint("BOTTOMRIGHT", c, "TOPRIGHT", 0, 0) else c.zz:SetPoint("TOPRIGHT", -6, -4) end end
    c.title:SetShown(not only); c.sub:SetShown(not only); c.time:SetShown(only and true or false); c.charges:SetShown(only and true or false)
    c.barBg:ClearAllPoints()
    if only then c.barBg:SetPoint("TOPLEFT", c.icon, "BOTTOMLEFT", 0, -4); c.barBg:SetPoint("TOPRIGHT", c.icon, "BOTTOMRIGHT", 0, -4); c.barW = ICON
    else c.barBg:SetPoint("BOTTOMLEFT", 12, 6); c.barBg:SetPoint("BOTTOMRIGHT", -12, 6); c.barW = CARD_W - 24 end
  end
  -- proc glow of the game (ActionButtonSpellAlertManager on newer clients, ActionButton_ShowOverlayGlow on older),
  -- else our pulsing border
  local procShow = type(ActionButtonSpellAlertManager) == "table" and ActionButtonSpellAlertManager.ShowAlert
    and function(f) return pcall(ActionButtonSpellAlertManager.ShowAlert, ActionButtonSpellAlertManager, f) end
    or (type(ActionButton_ShowOverlayGlow) == "function" and function(f) return pcall(ActionButton_ShowOverlayGlow, f) end)
  local procHide = type(ActionButtonSpellAlertManager) == "table" and ActionButtonSpellAlertManager.HideAlert
    and function(f) return pcall(ActionButtonSpellAlertManager.HideAlert, ActionButtonSpellAlertManager, f) end
    or (type(ActionButton_HideOverlayGlow) == "function" and function(f) return pcall(ActionButton_HideOverlayGlow, f) end)
  local function setFlash(c, on)
    if on == c.flashOn then return end
    c.flashOn = on
    local proc = procShow and procHide and not c.noProc
    if on and proc then
      if not procShow(c.iconBox) then c.noProc = true; proc = false end
    elseif not on and proc then procHide(c.iconBox) end
    c.glow:SetShown(on and not proc)
    if on and not proc then c.pulse:Play() elseif c.pulse:IsPlaying() then c.pulse:Stop() end
  end
  local function card(i)
    if cards[i] then return cards[i] end
    local c = CreateFrame("Frame", nil, holder); c.i = i
    c:EnableMouse(true); c:RegisterForDrag("LeftButton")
    -- no frame any more, a plain dark card (user 01.11.: cleaner)
    c.back = c:CreateTexture(nil, "BACKGROUND"); c.back:SetAllPoints(); c.back:SetColorTexture(0.04, 0.04, 0.05, 0.78)
    c.icon = c:CreateTexture(nil, "ARTWORK"); c.icon:SetSize(ICON, ICON)
    c.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local ring = CreateFrame("Frame", nil, c); ring:SetPoint("TOPLEFT", c.icon, -1, 1); ring:SetPoint("BOTTOMRIGHT", c.icon, 1, -1)
    FLT.UI.RoundRect(c, ring, "OVERLAY", 0, 6, 0, 0.62, 0.48, 0.26, 0.9, FLT.UI.ASSET_ROOT .. "window_ring")
    c.title = FLT.NewFS(c, nil, "OVERLAY", "GameFontNormalLarge"); c.title:SetPoint("TOPLEFT", c.icon, "TOPRIGHT", 12, -5)
    c.title:SetTextColor(1, 0.82, 0.20)
    c.sub = FLT.NewFS(c, nil, "OVERLAY", "GameFontHighlight"); c.sub:SetPoint("TOPLEFT", c.title, "BOTTOMLEFT", 0, -4)
    c.sub:SetTextColor(0.80, 0.78, 0.72)
    -- icon only: the time left on the icon
    c.time = FLT.NewFS(c, nil, "OVERLAY", "GameFontHighlight"); c.time:SetPoint("BOTTOM", c.icon, "BOTTOM", 0, 2)
    do local font = c.time:GetFont(); if font then c.time:SetFont(font, 13, "OUTLINE") end end
    c.charges = FLT.NewFS(c, nil, "OVERLAY", "GameFontHighlightSmall"); c.charges:SetPoint("TOPRIGHT", c.icon, "TOPRIGHT", -2, -2)
    do local font = c.charges:GetFont(); if font then c.charges:SetFont(font, 11, "OUTLINE") end end
    c.barBg = c:CreateTexture(nil, "ARTWORK"); c.barBg:SetColorTexture(0.12, 0.12, 0.14, 0.95); c.barBg:SetHeight(4)
    c.bar = c:CreateTexture(nil, "OVERLAY"); c.bar:SetColorTexture(barColor()); c.bar:SetHeight(4); c.bar:SetPoint("BOTTOMLEFT", c.barBg, "BOTTOMLEFT")
    c:SetScript("OnDragStart", function() if not inCombat() then holder:StartMoving() end end)
    c:SetScript("OnDragStop", function()
      holder:StopMovingOrSizing()
      local x, y = holder:GetCenter()
      if x and y then QoL.Set("buffPopupPos", { math.floor(x + 0.5), math.floor(y + 0.5) }) end
      syncBuffButton() -- the cast buttons follow
    end)
    c:SetScript("OnMouseUp", function(self, button)
      if button == "RightButton" and self.spell then QoL.SnoozeBuff(self.spell) end -- snooze: until it is up again
    end)
    c:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:AddLine(label(self.spell or ""), 1, 0.82, 0)
      GameTooltip:AddLine(L["Click the icon to cast it again."], 1, 1, 1)
      GameTooltip:AddLine(L["Zz or right-click: snooze until you cast it again. Drag: move."], 0.75, 0.75, 0.75); GameTooltip:Show()
    end)
    c:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- snooze button (user 05.11.): sleeps until the buff is up again
    c.zz = CreateFrame("Button", nil, c); c.zz:SetSize(18, 16)
    local zt = FLT.NewFS(c.zz, nil, "OVERLAY", "GameFontNormalSmall"); zt:SetAllPoints(); zt:SetText("Zz"); zt:SetTextColor(0.75, 0.75, 0.80)
    c.zz:SetScript("OnEnter", function(self)
      zt:SetTextColor(1, 0.82, 0.2)
      GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:AddLine(L["Snooze"], 1, 0.82, 0)
      GameTooltip:AddLine(L["No reminder for this buff until you cast it again (or it is up again)."], 1, 1, 1, true); GameTooltip:Show()
    end)
    c.zz:SetScript("OnLeave", function() zt:SetTextColor(0.75, 0.75, 0.80); GameTooltip:Hide() end)
    c.zz:SetScript("OnClick", function() if c.spell then QoL.SnoozeBuff(c.spell); GameTooltip:Hide() end end)
    -- "Flash cards" (Discord 05.11.; user: the soft glow was hardly visible): the game's own proc glow of the action
    -- bars around the icon when the client has it, else the bright action button border, pulsing (an animation, no
    -- OnUpdate). c.iconBox = a frame on the icon for the proc glow.
    c.iconBox = CreateFrame("Frame", nil, c); c.iconBox:SetPoint("TOPLEFT", c.icon); c.iconBox:SetPoint("BOTTOMRIGHT", c.icon)
    c.glow = c:CreateTexture(nil, "OVERLAY", nil, 7); FLT.SetTex(c.glow, "Interface\\Buttons\\UI-ActionButton-Border")
    c.glow:SetBlendMode("ADD"); c.glow:SetVertexColor(1, 0.85, 0.3, 1); c.glow:Hide()
    c.glow:SetPoint("CENTER", c.icon); c.glow:SetSize(ICON * 1.9, ICON * 1.9)
    c.pulse = c.glow:CreateAnimationGroup(); c.pulse:SetLooping("BOUNCE")
    local a = c.pulse:CreateAnimation("Alpha"); a:SetFromAlpha(0.35); a:SetToAlpha(1); a:SetDuration(0.5)
    cards[i] = c
    layoutCard(c)
    return c
  end
  -- the cast buttons: made, set, placed and shown / hidden only out of combat. Placed on UIParent at the icon's
  -- spot, NOT anchored to the card: a frame that a protected button hangs on becomes protected itself, and then the
  -- cards could not be hidden in combat (beta20 ADDON_ACTION_BLOCKED; beta18: no anchoring to textures either).
  -- In combat (user 01.11.): the cards stay and keep counting, only the cast buttons are hidden when combat starts
  -- (PLAYER_REGEN_DISABLED still allows it) - the icons cannot be clicked then; after combat they are set again.
  syncBuffButton = function()
    if inCombat() then return end
    for i = 1, MAXC do
      local c = cards[i]
      local on = c and c:IsShown() and holder:IsShown() and c.spell and c.spell ~= "Example buff"
      local sb = secures[i]
      if on and not sb then
        sb = CreateFrame("Button", "OneForAllBuffReminderCast" .. i, UIParent, "SecureActionButtonTemplate")
        sb:SetSize(ICON, ICON); sb:SetFrameStrata("MEDIUM"); sb:SetFrameLevel(c:GetFrameLevel() + 20)
        sb:RegisterForClicks("AnyUp", "AnyDown"); sb:SetAttribute("type", "spell")
        sb:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        sb:SetScript("OnEnter", function(self)
          local it = self:GetAttribute("item")
          GameTooltip:SetOwner(self, "ANCHOR_TOP")
          GameTooltip:AddLine(it and string.format(self:GetAttribute("target-slot") == 17 and L["Click: use %s on your off hand"] or L["Click: use %s on your main hand"], it) or string.format(L["Click: cast %s"], self:GetAttribute("spell") or ""), 1, 0.82, 0)
          GameTooltip:Show()
        end)
        sb:SetScript("OnLeave", function() GameTooltip:Hide() end)
        secures[i] = sb
      end
      if sb then
        if on and c:GetLeft() then
          -- same scale as the cards, so the card's own numbers fit (size slider, user 01.11.)
          sb:SetScale(holder:GetScale()); sb:ClearAllPoints()
          sb:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", c:GetLeft() + c.iconX, c:GetTop() + c.iconY)
          local item, slot = weapon(c.spell)
          if item then -- use the item on that weapon (the game's own "target-slot")
            sb:SetAttribute("type", "item"); sb:SetAttribute("item", item); sb:SetAttribute("target-slot", slot); sb:SetAttribute("spell", nil)
            sb:SetAttribute("unit", nil)
          else
            -- always on yourself (6.2.2, user 09.11.: with a friendly target the buff went on the target)
            sb:SetAttribute("type", "spell"); sb:SetAttribute("spell", c.spell); sb:SetAttribute("item", nil); sb:SetAttribute("target-slot", nil)
            sb:SetAttribute("unit", "player")
          end
          sb:Show()
        else sb:Hide() end
      end
      if c and c:IsShown() then paintCard(c) end
    end
  end
  -- "Sleep in cities" (user 31.10.): no reminder in the six capitals (also their sub-maps)
  local CAPITALS = { [1453] = true, [1454] = true, [1455] = true, [1456] = true, [1457] = true, [1458] = true }
  function inCapital()
    local id = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    for _ = 1, 4 do
      if not id then return false end
      if CAPITALS[id] then return true end
      local info = C_Map.GetMapInfo and C_Map.GetMapInfo(id)
      id = info and info.parentMapID
    end
    return false
  end
  -- names of the watched buffs in the client's language: by the stored ID; old entries without an ID by the spellbook
  -- name or, for an English name, by the class trainer list (Data/TrainerSpells.lua, English names + spell IDs)
  local migrated = false
  local function migrateBuffs()
    local list, ids, d, again = buffList(), buffIDs(), db(), false
    local en
    local keys = {}
    for key in pairs(list) do keys[#keys + 1] = key end
    for _, key in ipairs(keys) do
      local item, _, hand = weapon(key)
      local id = ids[key]
      if not id and not item then
        local ok, info = pcall(function() return C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(key) end)
        id = ok and type(info) == "table" and info.spellID or nil
        if not id then
          if not en then
            en = {}
            local cid = UnitClass and select(3, UnitClass("player"))
            for _, s in ipairs(FLT.TRAINER_SPELLS and FLT.TRAINER_SPELLS[cid] or {}) do en[s[3]] = en[s[3]] or s[2] end
          end
          id = en[key]
        end
      elseif not id and item then
        local ok, iid = pcall(function() return C_Item and C_Item.GetItemInfoInstant and C_Item.GetItemInfoInstant(item) or (GetItemInfoInstant and GetItemInfoInstant(item)) end)
        id = ok and iid and ("i" .. iid) or nil
      end
      if id then
        local cur
        if type(id) == "string" then
          local iid = tonumber(id:sub(2))
          pcall(function() cur = (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(iid)) or (GetItemInfo and GetItemInfo(iid)) end)
          if type(cur) ~= "string" then cur = nil; again = true; if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, iid) end
          else cur = cur .. "@" .. (hand or "mh") end
        else
          pcall(function() cur = (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)) or (GetSpellInfo and GetSpellInfo(id)) end)
          if type(cur) ~= "string" or FLT.IsSecret(cur) then cur = nil end
        end
        if cur and cur ~= key and not list[cur] then
          list[cur], list[key] = list[key], nil
          ids[key] = nil
          if d and d.buffIcons and d.buffIcons[key] then d.buffIcons[cur], d.buffIcons[key] = d.buffIcons[key], nil end
          key = cur
        end
        if cur or not ids[key] then ids[key] = id end
      end
    end
    migrated = not again
  end
  QoL._migrateBuffs = migrateBuffs -- tests
  checkBuffs = function()
    buffToken = buffToken + 1 -- an older timer is no longer needed
    -- the buffs seen on this character are kept over logging out (6.2.1, user 08.11. "A": a buff that ran out while
    -- logged out gives its card right after the login); the session's list joins the saved one once
    local cdb = OneForAllCharDB
    if type(cdb) == "table" and buffSeen ~= cdb.buffSeen then
      cdb.buffSeen = type(cdb.buffSeen) == "table" and cdb.buffSeen or {}
      for n in pairs(buffSeen) do cdb.buffSeen[n] = true end
      buffSeen = cdb.buffSeen
      for n in pairs(buffSeen) do if buffList()[n] == nil then buffSeen[n] = nil end end -- no longer watched
    end
    if not migrated and not inCombat() then migrateBuffs() end
    local list = buffList()
    for i = #due, 1, -1 do due[i] = nil end
    if QoL.Get("buffReminder") and next(list) then
      local t, nextAt = now(), nil
      local fight = inCombat()
      if not fight then
        for n, at in pairs(renewed) do if t - at > 5 then renewed[n] = nil end end
        noteRanks()
      end
      for name, sec in pairs(list) do
        local exp, dur = findBuff(name)
        sec = tonumber(sec) or 30
        local z = snoozed[name]
        if z and exp and (z == true or (exp > 0 and exp > z + 1)) then snoozed[name] = nil; z = nil end -- up again / renewed
        if QoL.OtherClassBuff and QoL.OtherClassBuff(name) then -- 6.2.14: another class's own buff (e.g. Battle Shout from a warrior in the group)
        elseif z then -- snoozed (user 05.11.): no card until the buff is up again or renewed
        elseif exp then
          renewed[name] = nil; snoozed[name] = nil
          buffSeen[name] = true
          buffExp[name] = exp > 0 and exp or nil
          if dur and dur > 0 then buffDur[name] = dur end
          if exp > 0 then -- buffs without a duration need no reminder
            local left = exp - t
            if left <= sec then due[#due + 1] = name
            elseif not nextAt or left - sec < nextAt then nextAt = left - sec end
          end
        elseif buffExp[name] and (fight or exp == false or renewed[name]) then
          -- a cast counts 5 s out of combat; look again then - a buff cast on someone else is not on you, and no
          -- aura event of yours would bring the card back (6.2.2, user 09.11.)
          local g = renewed[name] and not fight and renewed[name] + 5.05 - t
          if g and g > 0 and (not nextAt or g < nextAt) then nextAt = g end
          -- the game does not tell (combat, or the aura of a cast is not there yet): go by the time the buff has -
          -- from when it was last seen, or cast time + its duration (6.1.3/6.1.4, Discord 05.11.: a Seal cast before
          -- the pull gave no card at 10 s)
          local left = buffExp[name] - t
          if left <= sec then due[#due + 1] = name
          elseif not nextAt or left - sec < nextAt then nextAt = left - sec end
        elseif renewed[name] then -- cast again, its time not known: done for now (look again after the 5 s)
          local g = not fight and renewed[name] + 5.05 - t
          if g and g > 0 and (not nextAt or g < nextAt) then nextAt = g end
        elseif fight or exp == false then -- not readable and no time known (idea from PR #36): keep the card as it was
          if wasDue[name] then due[#due + 1] = name end
        elseif buffSeen[name] then due[#due + 1] = name; buffExp[name] = nil -- ran out after it was up
        end
      end
      if nextAt then scheduleBuffCheck(nextAt + 0.05) end
      -- the most urgent first: run out, then the least time left
      table.sort(due, function(a, b)
        local ea, eb = findBuff(a) or 0, findBuff(b) or 0
        if ea == eb then return a < b end
        return ea < eb
      end)
    end
    wipe(wasDue); for _, n in ipairs(due) do wasDue[n] = true end
    local test = testUntil > now()
    if test and #due == 0 then -- Test: the watched buffs (or an example) so the size and place can be set
      for _, e in ipairs(QoL.GetBuffReminders()) do if #due < 2 then due[#due + 1] = e.name end end
      if #due == 0 then due[1] = "Example buff" end
    end
    -- dead or a ghost (user 07.11.): no cards, nothing can be cast; UNIT_AURA after the resurrection checks again
    local dead = not test and UnitIsDeadOrGhost and UnitIsDeadOrGhost("player")
    if #due == 0 or dead or (not test and QoL.Get("buffSleepCities") and inCapital()) then
      if holder then holder:Hide() end
    else
      if not holder then makeHolder() end
      for i = 1, MAXC do
        local name = due[i]
        if name then
          local c = card(i)
          c.spell = name; c.title:SetText((weapon(name)) or (name == "Example buff" and L["Example buff"]) or name); FLT.SetTex(c.icon, spellIcon(name)); layoutCard(c); c:Show()
          setFlash(c, QoL.Get("buffFlash") and true or false)
          c.zz:SetShown(QoL.Get("buffSnoozeBtn") and true or false)
          paintCard(c)
        elseif cards[i] then
          setFlash(cards[i], false); cards[i]:Hide(); cards[i].spell = nil
        end
      end
      holder:Show()
    end
    syncBuffButton()
  end
  buffAura = function(weaponsOnly)
    if buffDebounce or not QoL.Get("buffReminder") then return end
    if weaponsOnly then -- only when a weapon enchant is watched
      local any = false
      for name in pairs(buffList()) do if weapon(name) or imbue(name) then any = true; break end end
      if not any then return end
    end -- also in combat (user 01.11.), debounced
    buffDebounce = true
    C_Timer.After(0.2, function() buffDebounce = false; checkBuffs() end)
  end
  function QoL.AddBuffReminder(name, sec)
    name = tostring(name or ""):match("^%s*(.-)%s*$")
    if name == "" then return end
    do -- "Superior Wizard Oil (main hand)" as typed or picked from the suggestions
      -- also in the chosen language ("(Haupthand)", 6.2.0)
      local it, h = name:match("^(.-)%s*%((.-)%)$")
      h = h and h:lower()
      local mh = h == "main hand" or h == L["main hand"]:lower()
      if it and (mh or h == "off hand" or h == L["off hand"]:lower()) then name = it .. (mh and "@mh" or "@oh") end
    end
    local item, _, hand = weapon(name)
    if item then -- an item for a weapon: the game's spelling when it knows the item
      pcall(function()
        local n = C_Item and C_Item.GetItemInfo and C_Item.GetItemInfo(item) or (GetItemInfo and GetItemInfo(item))
        if type(n) == "string" and n ~= "" then name = n .. "@" .. hand end
      end)
      buffList()[name] = math.max(5, math.min(3600, math.floor(tonumber(sec) or 30)))
      pcall(function()
        local iid = C_Item and C_Item.GetItemInfoInstant and C_Item.GetItemInfoInstant(item) or (GetItemInfoInstant and GetItemInfoInstant(item))
        if iid then buffIDs()[name] = "i" .. iid end
      end)
      checkBuffs()
      return name
    end
    -- the game's spelling when the spell is known ("demon skin" -> "Demon Skin")
    pcall(function()
      local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(name)
      local n = type(info) == "table" and info.name or (GetSpellInfo and GetSpellInfo(name))
      if type(n) == "string" and n ~= "" then name = n end
      if type(info) == "table" and info.spellID then buffIDs()[name] = info.spellID end
    end)
    buffList()[name] = math.max(5, math.min(3600, math.floor(tonumber(sec) or 30)))
    checkBuffs()
    return name
  end
  function QoL.RemoveBuffReminder(name) buffList()[name] = nil; buffIDs()[name] = nil; buffSeen[name] = nil; checkBuffs() end
  function QoL.ClearBuffReminders() wipe(buffList()); wipe(buffIDs()); wipe(buffSeen); checkBuffs() end
  QoL.CheckBuffs = checkBuffs
  QoL._buffCard = function(i) return cards[i] end -- tests
  -- snooze: remember the end time it has now (a buff still running low stays quiet until it is cast again);
  -- true = it is not up (quiet until it is up again)
  function QoL.SnoozeBuff(name)
    local exp = findBuff(name)
    if not exp and buffExp[name] then exp = buffExp[name] end
    snoozed[name] = (type(exp) == "number" and exp > 0) and exp or true
    checkBuffs()
  end
  -- combat starts: everything away (the secure buttons may still be hidden in this event)
  -- UNIT_SPELLCAST_SUCCEEDED (player): only in combat and only for a watched buff
  -- 6.1.4 (seal re-cast in combat, 05.11.): the spell name can be secret in combat, so spell ID -> name of the watched
  -- buffs is noted out of combat (own casts and the spellbook rank of each name) and used in combat
  local castName, noted = {}, {}
  -- the current spellbook rank of every watched buff (once per name, out of combat)
  noteRanks = function()
    if inCombat() or not (C_Spell and C_Spell.GetSpellInfo) then return end
    for n in pairs(buffList()) do
      if not noted[n] then
        noted[n] = true
        local ok, info = pcall(C_Spell.GetSpellInfo, n)
        local id = ok and type(info) == "table" and info.spellID
        if id and not FLT.IsSecret(id) then castName[id] = n end
      end
    end
  end
  local function spellName(id)
    local n = (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)) or (GetSpellInfo and GetSpellInfo(id))
    if type(n) == "string" and not FLT.IsSecret(n) then return n end
  end
  function QoL.BuffCast(spellID)
    if not QoL.Get("buffReminder") or not spellID or FLT.IsSecret(spellID) then return end
    local n = castName[spellID]
    if not inCombat() then
      n = n or spellName(spellID)
      if n and buffList()[n] then castName[spellID] = n end
    end
    n = n or spellName(spellID)
    if not n or not buffList()[n] then return end
    -- also out of combat (05.11.: cast and pulled at once - the aura was not read yet when combat began); with a
    -- known duration the new end time counts, so the card still comes when it runs low in the fight
    renewed[n] = now(); snoozed[n] = nil
    buffExp[n] = buffDur[n] and (now() + buffDur[n]) or nil
    checkBuffs()
  end
  function QoL.BuffCombatStart()
    for _, sb in pairs(secures) do sb:Hide() end
    noteRanks()
  end
  -- size / icon only changed: the cards and the cast buttons follow
  function QoL.BuffLayout()
    if not holder then return end
    holder:SetScale(scale())
    for _, c in ipairs(cards) do layoutCard(c) end
    syncBuffButton()
  end
  function QoL.BuffTest()
    testUntil = now() + 10
    checkBuffs()
    C_Timer.After(10.1, checkBuffs)
  end
  -- Suggestions for the name box (user 31.10.): the class's usual self buffs first, then the spellbook. As spell IDs
  -- (rank 1), the names come from the client in its language (6.2.0: the English names matched nothing in German)
  local PRESETS = {
    WARLOCK = { 687, 706, 6229 }, -- Demon Skin, Demon Armor, Shadow Ward
    MAGE = { 168, 7302, 6117, 1459, 11426, 1463, 604, 1008 }, -- Frost / Ice / Mage Armor, Arcane Intellect, Ice Barrier, Mana Shield, Dampen / Amplify Magic
    PRIEST = { 1243, 588, 14752, 976, 6346 }, -- Power Word: Fortitude, Inner Fire, Divine Spirit, Shadow Protection, Fear Ward
    DRUID = { 1126, 467, 16864 }, -- Mark of the Wild, Thorns, Omen of Clarity
    PALADIN = { 25780, 19740, 19742, 20217, 20911 }, -- Righteous Fury, Blessing of Might / Wisdom / Kings / Sanctuary (Light and Salvation removed in Forever, bluepost 02.11.)
    SHAMAN = { 324 }, -- Lightning Shield
    WARRIOR = { 6673 }, -- Battle Shout
    HUNTER = { 19506 }, -- Trueshot Aura
  }
  -- weapon items suggested even when none is in the bags (main hand; type "(off hand)" for the other weapon); item IDs
  -- named by the client in its language (6.2.0; IDs checked against QuestieDB)
  local WEAPON_ITEMS = {
    2862, 2863, 2871, 7964, 12404, 18262, -- Rough / Coarse / Heavy / Solid / Dense / Elemental Sharpening Stone
    3239, 3240, 3241, 7965, 12643, -- Rough / Coarse / Heavy / Solid / Dense Weightstone
    20744, 20746, 20750, 20749, 20745, 20747, 20748, 3824, 3829, -- Wizard and Mana Oils, Shadow Oil, Frost Oil
  }
  local POISONS = { 6947, 2892, 3775, 5237, 10918 } -- Instant, Deadly, Crippling, Mind-numbing, Wound Poison
  -- warlock stones imbue the weapon in Forever (Discord 08.11., Knucklarn: only suggested with a stone in the bags):
  -- Spellstone, Greater / Major Spellstone, Lesser / - / Greater / Major Firestone (Wowhead dataEnv=16)
  local WARLOCK_STONES = { 5522, 13602, 13603, 1254, 13699, 13700, 13701 }
  local function spellNameOf(id)
    local n
    pcall(function() n = (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)) or (GetSpellInfo and GetSpellInfo(id)) end)
    return type(n) == "string" and n or nil
  end
  -- 6.2.14 (Discord yanthir 22.11.: "Why does it remind my hunter to cast Battle Shout?" - a new character's list starts as a
  -- copy of the account's old list, so a warrior's buffs came along): the own buffs of the other classes (their presets,
  -- by name - every rank) give no reminder; the names are read once the client knows them
  function QoL.OtherClassBuff(name)
    local mine = UnitClass and select(2, UnitClass("player"))
    if not mine then return false end
    if QoL._otherBuffsFor ~= mine then QoL._otherBuffs, QoL._otherBuffsFor = nil, mine end
    if not QoL._otherBuffs then
      local set, own, ok = {}, {}, true
      for _, id in ipairs(PRESETS[mine] or {}) do local n = spellNameOf(id); if n then own[n] = true end end
      for cls, ids in pairs(PRESETS) do
        if cls ~= mine then
          for _, id in ipairs(ids) do local n = spellNameOf(id); if n then if not own[n] then set[n] = true end else ok = false end end
        end
      end
      if not ok then return set[name] or false end -- names not all there yet: ask again next time
      QoL._otherBuffs = set
    end
    return QoL._otherBuffs[name] or false
  end
  local function itemNameOf(id)
    local n
    pcall(function() n = (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)) or (GetItemInfo and GetItemInfo(id)) end)
    if type(n) ~= "string" and C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
    return type(n) == "string" and n or nil
  end
  function QoL.BuffSuggestions(text)
    text = (text or ""):lower()
    local out, seen = {}, {}
    local function add(name, preset, active)
      if #out >= 8 or seen[name] or buffList()[name] then return end
      if text ~= "" and not name:lower():find(text, 1, true) then return end
      seen[name] = true; out[#out + 1] = { name = name, preset = preset, active = active }
    end
    -- the buffs you have right now (with a duration) come first (user 05.11.); out of combat only (secret in combat)
    if not inCombat() then
      local get = type(C_UnitAuras) == "table" and C_UnitAuras.GetAuraDataByIndex
      for i = 1, 40 do
        local n, dur
        if get then
          local ok, a = pcall(get, "player", i, "HELPFUL")
          if not ok or not a then break end
          n, dur = a.name, a.duration
          if type(n) == "string" and not FLT.IsSecret(n) then noteIcon(n, a.icon) end
        elseif UnitBuff then
          local ok, bn, _, _, _, bdur = pcall(UnitBuff, "player", i)
          if not ok or not bn then break end
          n, dur = bn, bdur
        else break end
        if type(n) == "string" and not FLT.IsSecret(n, dur) and (tonumber(dur) or 0) > 0 and #out < 6 then add(n, false, true) end
      end
    end
    local known = {}
    local book = BOOKTYPE_SPELL or "spell"
    pcall(function()
      if GetNumSpellTabs and GetSpellTabInfo and GetSpellBookItemName then
        for tab = 1, GetNumSpellTabs() do
          local _, _, offset, num = GetSpellTabInfo(tab)
          for i = (offset or 0) + 1, (offset or 0) + (num or 0) do
            local n = GetSpellBookItemName(i, book)
            if n and not FLT.IsSecret(n) then known[#known + 1] = n end
          end
        end
      elseif C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines then
        local bank = (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or 0
        for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
          local li = C_SpellBook.GetSpellBookSkillLineInfo(line)
          for i = (li and li.itemIndexOffset or 0) + 1, (li and li.itemIndexOffset or 0) + (li and li.numSpellBookItems or 0) do
            local info = C_SpellBook.GetSpellBookItemInfo(i, bank)
            if type(info) == "table" and info.name and not FLT.IsSecret(info.name) then known[#known + 1] = info.name end
          end
        end
      end
    end)
    local isKnown = {}
    for _, n in ipairs(known) do isKnown[n] = true end
    local class = UnitClass and select(2, UnitClass("player"))
    for _, id in ipairs(PRESETS[class or ""] or {}) do
      local n = spellNameOf(id)
      if n and (isKnown[n] or #known == 0) then add(n, true) end
    end
    -- gatherers: Find Herbs / Find Minerals (and Find Treasure) when you know them (user 09.11.)
    for _, id in ipairs(TRACKING) do
      local n = spellNameOf(id)
      if n and isKnown[n] then add(n, true) end
    end
    if text ~= "" then for _, n in ipairs(known) do add(n, false) end end
    -- usable items in the bags (oils, sharpening stones, poisons ...) for the main / off hand, from 2 letters on
    -- (user 03.11.: "sh" showed nothing); then the usual weapon items even when none is in the bags
    local items = {}
    if #text >= 2 and C_Container and C_Container.GetContainerNumSlots then
      -- each slot on its own (beta4: one missing global stopped the whole scan, user 01.11.); the name from the bag
      -- info, a "Use:" effect when the client can tell (sharpening stones are trade goods, not consumables)
      local itemName = C_Item and C_Item.GetItemNameByID or C_Item and C_Item.GetItemInfo or GetItemInfo
      local itemSpell = C_Item and C_Item.GetItemSpell or GetItemSpell
      for bag = 0, 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
          pcall(function()
            local info = C_Container.GetContainerItemInfo and C_Container.GetContainerItemInfo(bag, slot)
            local id = type(info) == "table" and info.itemID or (C_Container.GetContainerItemID and C_Container.GetContainerItemID(bag, slot))
            if not id then return end
            local n = type(info) == "table" and info.itemName or (itemName and itemName(id))
            if type(n) ~= "string" or items[n] or not n:lower():find(text, 1, true) then return end
            if itemSpell and not itemSpell(id) then return end
            items[n] = true; items[#items + 1] = n
          end)
        end
      end
      table.sort(items)
      for _, n in ipairs(items) do
        for _, hand in ipairs({ "mh", "oh" }) do
          local key = n .. "@" .. hand
          if #out < 8 and not buffList()[key] then out[#out + 1] = { name = key, label = label(key), item = true } end
        end
      end
    end
    if #text >= 2 then
      local function suggest(ids)
        for _, id in ipairs(ids) do
          if #out >= 8 then return end
          local n = itemNameOf(id)
          if n and not items[n] and n:lower():find(text, 1, true) then
            local key = n .. "@mh"
            if not buffList()[key] then out[#out + 1] = { name = key, label = label(key), item = true, notInBags = true } end
          end
        end
      end
      suggest(WEAPON_ITEMS)
      if class == "ROGUE" then suggest(POISONS) elseif class == "WARLOCK" then suggest(WARLOCK_STONES) end
    end
    return out
  end
end

-- ---------------------------------------------------------------------------
-- Durability warning
-- ---------------------------------------------------------------------------
local warnedDurability = false
local function checkDurability()
  if not QoL.Get("durability") or not GetInventoryItemDurability then return end
  local low = 1
  for slot = 1, 19 do
    local cur, max = GetInventoryItemDurability(slot)
    if cur and max and max > 0 then low = math.min(low, cur / max) end
  end
  local limit = (QoL.Get("durabilityPct") or 20) / 100
  if low <= limit and not warnedDurability then
    warnedDurability = true
    local text = string.format(L["Your gear is at %d%% durability - time to repair."], math.floor(low * 100 + 0.5))
    if UIErrorsFrame then UIErrorsFrame:AddMessage(text, 1, 0.35, 0.3) end
    msg(text)
    if PlaySound and SOUNDKIT and SOUNDKIT.RAID_WARNING then pcall(PlaySound, SOUNDKIT.RAID_WARNING) end
  elseif low > limit + 0.05 then
    warnedDurability = false
  end
end

-- ---------------------------------------------------------------------------
-- Camera zoom, chat font, raid frame CVars
-- ---------------------------------------------------------------------------
local function applyCamera(on)
  if not GetCVar or not SetCVar then return end
  local d = db(); if not d then return end
  if on then
    if not d.cameraOrig then d.cameraOrig = GetCVar("cameraDistanceMaxZoomFactor") end
    if not pcall(SetCVar, "cameraDistanceMaxZoomFactor", "4") then pcall(SetCVar, "cameraDistanceMaxZoomFactor", "2.6") end
  elseif d.cameraOrig then
    pcall(SetCVar, "cameraDistanceMaxZoomFactor", d.cameraOrig); d.cameraOrig = nil
  end
end

local function applyChatFont(size)
  size = tonumber(size)
  if not size or size <= 0 then return end
  for i = 1, tonumber(NUM_CHAT_WINDOWS) or 10 do
    local cf = _G["ChatFrame" .. i]
    if type(cf) == "table" then
      if FCF_SetChatWindowFontSize then pcall(FCF_SetChatWindowFontSize, nil, cf, size)
      else local f, _, fl = cf:GetFont(); if f then cf:SetFont(f, size, fl) end end
    end
  end
end

-- Game settings (CVars) shown as switches; they stay in sync with the game menu.
QoL.CVARS = { raidClassColor = "raidFramesDisplayClassColor", raidPowerBars = "raidFramesDisplayPowerBars", autoLoot = "autoLootDefault" }
function QoL.GetCVarSwitch(key)
  local name = QoL.CVARS[key]
  return name and GetCVarBool and GetCVarBool(name) or false
end
-- Item comparison only with Shift: the game setting alwaysCompareItems, inverted
-- (switch on = 0, the same as /console alwaysCompareItems 0). It is read from the
-- game every time, so the switch always shows the current state.
function QoL.GetCompareShift()
  return not (GetCVarBool and GetCVarBool("alwaysCompareItems"))
end
function QoL.SetCompareShift(on)
  if SetCVar then pcall(SetCVar, "alwaysCompareItems", on and "0" or "1") end
end
function QoL.SetCVarSwitch(key, value)
  local name = QoL.CVARS[key]
  if not name or not SetCVar then return end
  if inCombat() and key ~= "autoLoot" then msg(L["This can be changed after combat."]); return end
  pcall(SetCVar, name, value and "1" or "0")
  if CompactUnitFrameProfiles_ApplyCurrentSettings then pcall(CompactUnitFrameProfiles_ApplyCurrentSettings) end
end

-- ---------------------------------------------------------------------------
-- Class colours on the default unit frames (player, target, party ...)
-- ---------------------------------------------------------------------------
-- "Brighter colors" (5.6.8, user 22.10.): the client's health bar art is dark, desaturated and tinted it makes
-- the class colors dull; a plain bar instead, the original art is put back when it is switched off
local function plainBar(tex, on)
  if on then
    if not tex.ofaOrigTex then tex.ofaOrigTex = { tex.GetAtlas and tex:GetAtlas(), tex:GetTexture() } end
    tex:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
  elseif tex.ofaOrigTex then
    local o = tex.ofaOrigTex; tex.ofaOrigTex = nil
    if o[1] and tex.SetAtlas then tex:SetAtlas(o[1]) elseif o[2] then tex:SetTexture(o[2]) end
  end
end
local function restoreBar(bar)
  if not bar.ofaColored then return end
  bar.ofaColored = nil
  local tex = bar.GetStatusBarTexture and bar:GetStatusBarTexture()
  if tex and tex.SetDesaturated then tex:SetDesaturated(false) end
  if tex then plainBar(tex, false) end
  local o = bar.ofaOrigColor
  if o then bar:SetStatusBarColor(o[1], o[2], o[3]) end
end
local function colorBar(bar, unit)
  if not bar or not bar.SetStatusBarColor then return end
  unit = unit or bar.unit
  -- only the player, target, focus and party frames: nameplate bars are left alone
  -- (their values are hidden in combat and touching them taints the nameplates)
  if type(unit) ~= "string" or FLT.IsSecret(unit) or unit:find("^nameplate") then return end
  local isPlayer = UnitIsPlayer and UnitIsPlayer(unit)
  if FLT.IsSecret(isPlayer) then return end
  if not QoL.Get("classColors") or not isPlayer then restoreBar(bar); return end
  local _, cls = UnitClass(unit)
  if FLT.IsSecret(cls) then return end
  local c = cls and (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS or {})[cls]
  if not c then restoreBar(bar); return end
  if not bar.ofaColored and bar.GetStatusBarColor then
    local r, g, b = bar:GetStatusBarColor()
    bar.ofaOrigColor = { r or 1, g or 1, b or 1 }
  end
  bar.ofaColored = true
  local tex = bar.GetStatusBarTexture and bar:GetStatusBarTexture()
  if tex then plainBar(tex, QoL.Get("classBright") and true or false) end
  if tex and tex.SetDesaturated then tex:SetDesaturated(true) end
  bar:SetStatusBarColor(c.r, c.g, c.b)
end
local function setupClassColors()
  if type(UnitFrameHealthBar_Update) == "function" and hooksecurefunc then
    hooksecurefunc("UnitFrameHealthBar_Update", function(bar, unit) FLT.SafeCall("ClassColors", colorBar, bar, unit) end)
  end
  if type(HealthBar_OnValueChanged) == "function" and hooksecurefunc then
    hooksecurefunc("HealthBar_OnValueChanged", function(bar) FLT.SafeCall("ClassColors", colorBar, bar) end)
  end
end
local COLOR_FRAMES = { "PlayerFrame", "TargetFrame", "TargetFrameToT", "FocusFrame",
  "PartyMemberFrame1", "PartyMemberFrame2", "PartyMemberFrame3", "PartyMemberFrame4" }
local function refreshClassColors()
  for _, name in ipairs(COLOR_FRAMES) do
    local f = _G[name]
    local bar = type(f) == "table" and (f.healthbar or f.HealthBar)
    if bar then colorBar(bar, bar.unit or f.unit) end
  end
end

-- ---------------------------------------------------------------------------
-- Move Blizzard windows (positions are remembered)
-- ---------------------------------------------------------------------------
local MOVABLE = {
  "CharacterFrame", "SpellBookFrame", "QuestLogFrame", "FriendsFrame", "GossipFrame", "QuestFrame",
  "MerchantFrame", "MailFrame", "OpenMailFrame", "BankFrame", "TradeFrame", "TaxiFrame", "PetStableFrame",
  "DressUpFrame", "ItemTextFrame", "TabardFrame", "GuildRegistrarFrame", "PetitionFrame", "LootFrame",
  "ClassTrainerFrame", "TradeSkillFrame", "CraftFrame", "PlayerTalentFrame", "TalentFrame", "InspectFrame",
  "AuctionFrame", "AuctionHouseFrame", "MacroFrame", "KeyBindingFrame", "GuildFrame", "CommunitiesFrame",
  "ContainerFrameCombinedBags", -- the "Combined Backpack" (user 27.10.)
  -- the newer (Mainline) windows of the Forever client (user 27.10.: map, professions, spellbook did not move)
  "WorldMapFrame", "ProfessionsFrame", "ProfessionsBookFrame", "PlayerSpellsFrame", "ClassTalentFrame", "CollectionsJournal",
  "EncounterJournal", "AchievementFrame", "PVEFrame", "QuestLogPopupDetailFrame", "ItemSocketingFrame", "GuildBankFrame",
  "LFGParentFrame", -- Looking For Group (user 31.10.)
  "AddonList", -- the AddOns window (user 02.11.)
  "SettingsPanel", "HelpFrame", "GameMenuFrame", -- Options, Customer Support, Game Menu (user 02.11.)
  "SocialUIFrame", "CalendarFrame", "CatalogShopFrame", -- Social (Friends), Calendar, Shop (Discord Stiandresius 06.11.)
  "LegacySystemFrame", -- Forever's Legacy System (user 09.11.)
  "CooldownViewerSettings", -- Cooldown Settings (6.2.10, Discord sumomo8681 15.11.)
}
-- windows whose pages cover them completely: the pages take the mouse, so they are grips as well
local GRIPS = { LFGParentFrame = { "LFGWhoListFrame", "LFGListingFrame", "LFGBrowseFrame" } }
local function positions()
  local d = db(); if not d then return {} end
  d.windowPos = d.windowPos or {}
  return d.windowPos
end
-- with a controller connected the bags stay where the game puts them (Discord 06.11.: the controller's cursor jumped
-- between the bag slots while the bag was moved / resized); GamePadEnable alone is 1 also without one (user 06.11.)
local function padBag(name)
  if name ~= "ContainerFrameCombinedBags" or not GetCVar or GetCVar("GamePadEnable") ~= "1" then return false end
  local ok, ids = pcall(function() return C_GamePad and C_GamePad.GetAllDeviceIDs and C_GamePad.GetAllDeviceIDs() end)
  return ok and type(ids) == "table" and #ids > 0
end
-- another addon hides the game's window by moving it off the screen or making it invisible (TSM's crafting / vendor
-- view, Discord Levixa 09.11.: both windows showed): leave it where that addon put it
local function hiddenByAddon(f)
  if f.GetAlpha and (f:GetAlpha() or 1) < 0.05 then return true end
  local sc = f.GetScale and f:GetScale()
  if sc and sc < 0.1 then return true end
  local l, t, r, b = f:GetLeft(), f:GetTop(), f.GetRight and f:GetRight(), f.GetBottom and f:GetBottom()
  if not (l and t and UIParent.GetWidth) then return false end
  local k = (f.GetEffectiveScale and f:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)
  local W, H = UIParent:GetWidth() or 0, UIParent:GetHeight() or 0
  if W <= 0 or H <= 0 then return false end
  return l * k >= W or t * k <= 0 or (r and r * k <= 0) or (b and b * k >= H) or false
end
-- a saved place inside the screen (6.2.13-beta14, user 20.11.: "fenster einfach nicht im sichtbaren bereich" - Discord again and
-- again: map, bags, game menu gone after a new resolution / UI scale or a size from "Resize Blizzard windows"): the whole window
-- on the screen when it fits, else its top left corner. x, y = TOPLEFT offsets from UIParent's BOTTOMLEFT, in the window's
-- own units (as saved). (A field, not a local: this file is at the 200 locals limit.)
function QoL.OnScreen(f, x, y)
  if not (f.GetWidth and f.GetHeight and UIParent.GetEffectiveScale) then return x, y end
  local ue, fe = UIParent:GetEffectiveScale() or 1, f.GetEffectiveScale and f:GetEffectiveScale() or 1
  if ue <= 0 or fe <= 0 then return x, y end
  local W, H = (UIParent:GetWidth() or 0) * ue / fe, (UIParent:GetHeight() or 0) * ue / fe
  if W <= 0 or H <= 0 then return x, y end
  local w, h = f:GetWidth() or 0, f:GetHeight() or 0
  x = math.max(0, math.min(x, W - math.min(w, W)))
  y = math.min(H, math.max(y, math.min(h, H)))
  return math.floor(x + 0.5), math.floor(y + 0.5)
end
local function applyPos(f, name)
  local p = positions()[name]
  -- a window that is off the screen because of OUR saved place is not "hidden by another addon" (6.2.13-beta14: such a
  -- window was then never put back)
  local ours = false
  if p and f.GetPoint then
    local pt, rel, rp, x, y = f:GetPoint(1)
    ours = pt == "TOPLEFT" and rel == UIParent and rp == "BOTTOMLEFT" and x and y and math.abs(x - p[1]) < 1 and math.abs(y - p[2]) < 1
  end
  if padBag(name) or (not ours and hiddenByAddon(f)) then return end
  -- the full screen map has its own place (6.2.13-beta15, Discord kritch 21.11.: "if you move the quest map it changes the
  -- alignment of the fullscreen map") - the saved place is only for the small map
  if f.IsMaximized and f:IsMaximized() then return end
  -- "Open loot window at mouse" (6.2.6, Discord 0xveri 12.11.): the game puts the loot window at the cursor - leave it there
  if name == "LootFrame" and GetCVar and GetCVar("lootUnderMouse") == "1" then return end
  if not p or not QoL.Get("moveWindows") then return end
  if inCombat() and f:IsProtected() then return end
  local x, y = QoL.OnScreen(f, p[1], p[2])
  if x ~= p[1] or y ~= p[2] then p[1], p[2] = x, y end -- the corrected place is kept
  f:ClearAllPoints(); f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
end
-- Resize Blizzard windows (6.0.1, Discord the_txab, own switch): drag with the right mouse button on a window -
-- right / down = larger, left / up = smaller (50 - 150 %); the size shows at the cursor while dragging and is
-- remembered per window. The OnUpdate only runs while the right button is held.
local function scales()
  local d = db(); if not d then return {} end
  d.windowScale = d.windowScale or {}
  return d.windowScale
end
local function applyScale(f, name)
  if padBag(name) or hiddenByAddon(f) then return end
  local sc = scales()[name]
  if not sc or not QoL.Get("resizeWindows") then return end
  if inCombat() and f:IsProtected() then return end
  f:SetScale(sc)
end
local sizer -- the window being resized: { f =, name =, x =, y =, s =, pct = }
local sizerFrame = CreateFrame("Frame")
local sizeStop -- below
local function sizeUpdate()
  local z = sizer
  if not z then return end
  -- fail-safe (user 01.11.): the window closed or the button was let go somewhere else (the loot window went away
  -- while dragging and the "100 %" stayed on screen): stop; and the % goes away after 3 s without a change
  if not z.f:IsShown() or (IsMouseButtonDown and not IsMouseButtonDown("RightButton")) then sizeStop(); return end
  if z.tip and GetTime() - z.t > 3 then z.tip = nil; if GameTooltip:GetOwner() == z.f then GameTooltip:Hide() end end
  local x, y = GetCursorPosition()
  local ui = UIParent:GetEffectiveScale()
  local d = ((x - z.x) - (y - z.y)) / ui -- right or down = larger
  local sc = math.max(0.5, math.min(1.5, z.s + d / 400))
  sc = math.floor(sc * 20 + 0.5) / 20 -- steps of 5 %
  local pct = math.floor(sc * 100 + 0.5)
  if pct == z.pct then return end
  z.pct, z.t, z.tip = pct, GetTime(), true
  -- keep the top left corner where it is
  local f, old = z.f, z.f:GetScale()
  local left, top = f:GetLeft(), f:GetTop()
  f:SetScale(sc)
  if left and top and not (inCombat() and f:IsProtected()) then
    f:ClearAllPoints(); f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left * old / sc, top * old / sc)
  end
  GameTooltip:SetOwner(f, "ANCHOR_CURSOR"); GameTooltip:SetText(pct .. " %", 1, 0.82, 0); GameTooltip:Show()
end
local function sizeStart(f, name)
  if inCombat() and f:IsProtected() then return end
  local x, y = GetCursorPosition()
  sizer = { f = f, name = name, x = x, y = y, s = f:GetScale() or 1 }
  sizerFrame:SetScript("OnUpdate", sizeUpdate)
end
sizeStop = function()
  local z = sizer
  if not z then return end
  sizer = nil; sizerFrame:SetScript("OnUpdate", nil)
  if GameTooltip:GetOwner() == z.f then GameTooltip:Hide() end
  if z.pct then -- it was dragged: remember the size (and the place, when windows are moved too)
    local sc = z.f:GetScale()
    scales()[z.name] = (math.abs(sc - 1) > 0.001) and sc or nil
    if QoL.Get("moveWindows") then
      local left, top = z.f:GetLeft(), z.f:GetTop()
      if left and top then positions()[z.name] = { math.floor(left + 0.5), math.floor(top + 0.5) } end
    end
  end
end

local movablePending -- windows that loaded in combat (protected ones can only be changed after it), user 05.11.
local function makeMovable(name)
  local f = _G[name]
  if type(f) ~= "table" then return end
  -- windows the game closes to addons (the shop can be one): touching them would be an error - left as they are
  if f.IsForbidden and f:IsForbidden() then return end
  if f.ofaMovable or not f.HookScript or padBag(name) then return end
  if inCombat() and f.IsProtected and f:IsProtected() then
    movablePending = movablePending or {}; movablePending[name] = true
    return
  end
  f.ofaMovable = true
  -- kept on the screen only while it is dragged (6.2.2, Discord Levixa 09.11.: always clamped, TSM's off-screen hiding
  -- pulled the game's crafting / vendor window back into the corner - both windows showed)
  f:SetMovable(true)
  if f.EnableMouse then f:EnableMouse(true) end
  local function down(_, button)
    if button == "RightButton" then
      -- Ctrl + right mouse button (6.2.12-beta2, user 18.11.: a plain right-click inside windows started resizing them)
      if QoL.Get("resizeWindows") and IsControlKeyDown and IsControlKeyDown() then sizeStart(f, name) end
      return
    end
    if button ~= "LeftButton" or not QoL.Get("moveWindows") then return end
    if inCombat() and f:IsProtected() then return end
    if f.IsMaximized and f:IsMaximized() then return end -- the full screen map is not dragged
    if f.SetClampedToScreen then f.ofaClamp = f.IsClampedToScreen and f:IsClampedToScreen() or false; f:SetClampedToScreen(true) end
    f.ofaMoving = true; f:StartMoving()
  end
  local function up(_, button)
    if button == "RightButton" then sizeStop(); return end
    if not f.ofaMoving then return end
    f.ofaMoving = nil; f:StopMovingOrSizing()
    if f.SetClampedToScreen and not (inCombat() and f:IsProtected()) then f:SetClampedToScreen(f.ofaClamp and true or false) end
    if f.SetUserPlaced then pcall(f.SetUserPlaced, f, false) end
    local left, top = f:GetLeft(), f:GetTop()
    if left and top then positions()[name] = { math.floor(left + 0.5), math.floor(top + 0.5) } end
  end
  -- newer windows: the title bar (TitleContainer, on the map inside BorderFrame) lies on top and takes the mouse.
  -- Only the title bar, never BorderFrame itself: it spans the whole map and would swallow every click and tooltip
  -- (user 27.10., beta45-58)
  local border = type(f.BorderFrame) == "table" and f.BorderFrame or nil
  local handles = { f, f.TitleContainer or false, border and border.TitleContainer or false, false }
  for _, g in ipairs(GRIPS[name] or {}) do handles[#handles + 1] = _G[g] or false end
  for i = 1, #handles do
    local h = handles[i]
    if type(h) == "table" and h.HookScript then
      if h ~= f and h.EnableMouse then
        h:EnableMouse(true)
        -- 6.2.9 (Discord Nigel 14.11.: Leatrix Plus' Wowhead link at the top of the map could no longer be copied): the
        -- title bar now takes the mouse, so hovering stays on it and never reaches what other addons put beneath it.
        -- Passing the hover on lets their text boxes get the mouse again; clicks (dragging) stay with the title bar.
        -- 6.2.10 (Discord fightincowboy 15.11.): only on the world map, where Leatrix' link is - on every window it was
        -- blocked when a window loaded during a protected action (Inspect from the player menu) and the chat menu broke
        if name == "WorldMapFrame" and h.SetPropagateMouseMotion and not (h.IsProtected and h:IsProtected()) then
          pcall(h.SetPropagateMouseMotion, h, true)
        end
      end
      h:HookScript("OnMouseDown", down); h:HookScript("OnMouseUp", up)
    end
  end
  -- a title bar that takes the mouse may lie over the close button (AddOns window: the X could not be clicked, user
  -- 02.11.): the close button goes above it
  local close = f.CloseButton or f.ClosePanelButton or _G[name .. "CloseButton"]
  local title = f.TitleContainer
  if type(close) == "table" and close.SetFrameLevel and type(title) == "table" and title.GetFrameLevel
    and not (close.IsProtected and close:IsProtected()) and close:GetFrameLevel() <= title:GetFrameLevel() then
    close:SetFrameLevel(title:GetFrameLevel() + 2)
  end
  -- the world map switching to full screen: back to the middle when it still sits at our place of the small map; back to
  -- small: our place again (6.2.13-beta15)
  if name == "WorldMapFrame" and f.Maximize and f.Minimize then
    hooksecurefunc(f, "Maximize", function(self)
      local p = positions()[name]
      if not p or (inCombat() and self:IsProtected()) then return end
      local pt, rel, rp, x, y = self:GetPoint(1)
      if pt == "TOPLEFT" and rel == UIParent and rp == "BOTTOMLEFT" and x and y and math.abs(x - p[1]) < 1 and math.abs(y - p[2]) < 1 then
        self:ClearAllPoints(); self:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
      end
    end)
    hooksecurefunc(f, "Minimize", function(self) applyPos(self, name) end)
  end
  -- at once (Discord 09.11., Faith: the window showed at its default place for a moment, then jumped), and once more a
  -- frame later in case the game places it again after its OnShow
  f:HookScript("OnShow", function(self)
    applyScale(self, name); applyPos(self, name)
    if C_Timer and C_Timer.After then C_Timer.After(0, function() applyScale(self, name); applyPos(self, name) end) end
  end)
  -- set up a moment after its addon loaded (ADDON_LOADED below): the window may already be open
  if f:IsShown() then applyScale(f, name); applyPos(f, name) end
end
local function setupMovable()
  if not QoL.Get("moveWindows") and not QoL.Get("resizeWindows") then return end
  for _, name in ipairs(MOVABLE) do makeMovable(name) end
  -- the game lines up its windows (UIParent panels) again whenever one opens: our places again after that
  if type(UpdateUIPanelPositions) == "function" and not QoL._panelHook then
    QoL._panelHook = true
    hooksecurefunc("UpdateUIPanelPositions", function()
      if not QoL.Get("moveWindows") then return end
      for name in pairs(positions()) do
        local f = _G[name]
        if type(f) == "table" and f.ofaMovable and not f.ofaMoving and f:IsShown() then applyPos(f, name) end
      end
    end)
  end
  -- the game puts the combined bag back at the right edge every time bags open or change: our place again after it
  if type(UpdateContainerFrameAnchors) == "function" and type(ContainerFrameCombinedBags) == "table" and not QoL._bagHook then
    QoL._bagHook = true
    hooksecurefunc("UpdateContainerFrameAnchors", function()
      local f = ContainerFrameCombinedBags
      if f.ofaMovable and not f.ofaMoving and f:IsShown() then applyPos(f, "ContainerFrameCombinedBags") end
    end)
  end
end
function QoL.ResetWindowSizes()
  local d = db(); if d then d.windowScale = {} end
  for _, name in ipairs(MOVABLE) do
    local f = _G[name]
    if type(f) == "table" and f.ofaMovable and f.SetScale and not (inCombat() and f:IsProtected()) then f:SetScale(1) end
  end
  msg(L["Window sizes reset."])
end
function QoL.ResetWindowPositions()
  local d = db(); if d then d.windowPos = {} end
  msg(L["Window positions reset. They return to their default place the next time they open."])
end

-- ---------------------------------------------------------------------------
-- XP from completed quests (marker on the experience bar + tooltip line)
-- ---------------------------------------------------------------------------
local fallbackXP
local function questFallbackXP(questID)
  if not fallbackXP then
    fallbackXP = {}
    for _, d in ipairs(FLT.DUNGEONS or {}) do
      for _, q in ipairs(d.quests or {}) do if q.id and q.liveXPFallback then fallbackXP[q.id] = q.liveXPFallback end end
    end
  end
  return fallbackXP[questID]
end
local function rewardXP(questID, index)
  if GetQuestLogRewardXP and questID then
    local ok, xp = pcall(GetQuestLogRewardXP, questID)
    if ok and tonumber(xp) and xp > 0 then return xp end
  end
  return questFallbackXP(questID) or 0
end
-- "Only tracked quests" (6.2.2, Discord 09.11., Deaders; off): a quest counts only while it is watched in the tracker
local function watched(questID, index)
  if C_QuestLog and C_QuestLog.GetQuestWatchType and questID then
    local ok, w = pcall(C_QuestLog.GetQuestWatchType, questID)
    if ok then return w ~= nil end
  end
  if IsQuestWatched and index then local ok, w = pcall(IsQuestWatched, index); if ok then return w and true or false end end
  return true
end
-- list (optional, 6.2.0, user 07.11.): filled with { title, xp } of each quest for the tooltip of the XP bar
function QoL.CompletedQuestXP(list)
  local total, n = 0, 0
  local onlyWatched = QoL.Get("questXPTracked")
  if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo then
    for i = 1, C_QuestLog.GetNumQuestLogEntries() or 0 do
      local info = C_QuestLog.GetInfo(i)
      if info and not info.isHeader and info.questID then
        local complete = C_QuestLog.IsComplete and C_QuestLog.IsComplete(info.questID)
        if complete and (not onlyWatched or watched(info.questID, i)) then
          local xp = rewardXP(info.questID, i)
          total = total + xp; n = n + 1
          if list then list[#list + 1] = { info.title or "?", xp } end
        end
      end
    end
  elseif GetNumQuestLogEntries and GetQuestLogTitle then
    for i = 1, GetNumQuestLogEntries() or 0 do
      local title, _, _, isHeader, _, isComplete, _, questID = GetQuestLogTitle(i)
      if not isHeader and (isComplete == 1 or isComplete == true) and (not onlyWatched or watched(questID, i)) then
        local xp = rewardXP(questID, i)
        total = total + xp; n = n + 1
        if list then list[#list + 1] = { title or "?", xp } end
      end
    end
  end
  return total, n
end

local xpMarker, xpCap, xpBar, xpHooked -- xpHooked = { line = tooltip hook, done = { XP bars that have it } }
local xpPending
-- Each status bar container has its own XP bar: with a tracked reputation the game shows the
-- reputation in one container and the XP in the other, so take the XP bar that is shown
-- (Discord sparklebeard 09.11.: quest XP gone while a reputation was tracked).
local findXPBar
do
  -- XP bars below c (depth levels of children): the first shown one, else remember the first hidden one in acc
  local function scanXP(c, depth, acc)
    if type(c) ~= "table" or not c.GetChildren then return end
    for _, ch in ipairs({ c:GetChildren() }) do
      if ch.ExhaustionTick or ch.ExhaustionLevelFillBar then
        local sb = ch.StatusBar or ch
        if sb.GetMinMaxValues then
          if not ch.IsVisible or ch:IsVisible() then return sb, ch end
          if not acc[1] then acc[1], acc[2] = sb, ch end
        end
      elseif depth > 1 then
        local sb, h = scanXP(ch, depth - 1, acc)
        if sb then return sb, h end
      end
    end
  end
  local acc, lastBar, lastHolder = {}, nil, nil
  local function search()
    -- the old bar only while it is shown (6.2.11, Discord jadyn_karn 16.11.: quest XP gone for several players - a hidden
    -- MainMenuExpBar, e.g. from another addon, was taken although the game shows its status bars)
    local old = type(MainMenuExpBar) == "table" and MainMenuExpBar
    if old and (not old.IsVisible or old:IsVisible()) then return old, old end
    wipe(acc)
    for _, cname in ipairs({ "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer", "StatusTrackingBarManager" }) do
      local sb, h = scanXP(_G[cname], 1, acc)
      if sb then return sb, h end
    end
    -- Bartender4 moves the game's XP bar into containers of its own under BT4BarStatus (6.2.11-beta23, Discord jadyn_karn
    -- 17.11., /fstack: BT4BarStatus.content.<frame>.<frame>.<bar>); the game's own containers stay hidden
    local sb, h = scanXP(_G.BT4BarStatus, 4, acc)
    if sb then return sb, h end
    if old and not acc[1] then return old, old end
    return acc[1], acc[2]
  end
  findXPBar = function()
    -- the bar found last time while it is still shown (no search on every XP / quest update)
    if lastHolder and (not lastHolder.IsVisible or lastHolder:IsVisible()) then return lastBar, lastHolder end
    local sb, h = search()
    if h and (not h.IsVisible or h:IsVisible()) then lastBar, lastHolder = sb, h else lastBar, lastHolder = nil, nil end
    return sb, h
  end
end
local function updateXP()
  if not QoL.Get("questXP") then if xpMarker then xpMarker:Hide(); xpCap:Hide() end; return end
  local bar, holder = findXPBar()
  if not bar then return end
  if not xpMarker then
    xpMarker = bar:CreateTexture(nil, "ARTWORK", nil, 2)
    xpMarker:SetColorTexture(1, 0.82, 0.25, 0.45)
    -- the pointed end, like the bar's own end (user 11.11. 23:13: "am Ende abrunden")
    xpCap = bar:CreateTexture(nil, "ARTWORK", nil, 2)
    if xpCap.SetTexture then FLT.SetTex(xpCap, "Interface\\AddOns\\OneForAll\\Assets\\xp_cap") end
    if xpCap.SetVertexColor then xpCap:SetVertexColor(1, 0.82, 0.25, 0.45) end
  elseif xpBar ~= bar then
    xpMarker:SetParent(bar); xpCap:SetParent(bar) -- the shown XP bar changed (reputation tracked / untracked)
  end
  xpBar = bar
  if not xpHooked then
    xpHooked = { done = {}, mgr = {} }
    -- the game swaps the bars when a reputation is tracked or untracked: follow it (fires only then)
    xpHooked.swap = function()
      if QoL.Get("questXP") and not xpPending and C_Timer and C_Timer.After then
        xpPending = true
        C_Timer.After(0.5, function() xpPending = false; updateXP() end)
      end
    end
    local quests = {} -- reused (only while the tooltip is built)
    local function byXP(a, b) return a[2] > b[2] end
    local function addLine(self)
      if not QoL.Get("questXP") then return end
      local function add()
        wipe(quests)
        local xp, n = QoL.CompletedQuestXP(quests)
        if n <= 0 or not GameTooltip:IsShown() or GameTooltip.ofaQuestXP then return end
        GameTooltip.ofaQuestXP = true
        local num = BreakUpLargeNumbers and BreakUpLargeNumbers(xp) or tostring(xp)
        local max = UnitXPMax and UnitXPMax("player") or 0
        local pct = max > 0 and string.format("  (%d%%)", math.floor(xp / max * 100 + 0.5)) or ""
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(string.format(L["Finished quests: %d"], n), 1, 0.82, 0.25)
        GameTooltip:AddLine(string.format(L["Turn them in for +%s XP"], num) .. pct, 1, 1, 1)
        -- each quest with its XP (user 07.11.: the count looked too high - a talk quest counts as done in the game)
        table.sort(quests, byXP)
        for i = 1, math.min(10, #quests) do
          local q = quests[i]
          GameTooltip:AddDoubleLine("  " .. q[1], BreakUpLargeNumbers and BreakUpLargeNumbers(q[2]) or tostring(q[2]), 0.85, 0.85, 0.85, 0.85, 0.85, 0.85)
        end
        GameTooltip:Show()
      end
      if C_Timer and C_Timer.After then C_Timer.After(0, add) else add() end
    end
    xpHooked.line = addLine
    if GameTooltip and GameTooltip.HookScript then GameTooltip:HookScript("OnHide", function(t) t.ofaQuestXP = nil end) end
  end
  -- the manager that swaps the bars: the game's, and Bartender4's own one above the bar (each hooked once)
  local m = holder and holder.GetParent and holder:GetParent()
  for _, mgr in ipairs({ _G.StatusTrackingBarManager, m, m and m.GetParent and m:GetParent() }) do
    if hooksecurefunc and type(mgr) == "table" and type(mgr.UpdateBarsShown) == "function" and not xpHooked.mgr[mgr] then
      xpHooked.mgr[mgr] = true; hooksecurefunc(mgr, "UpdateBarsShown", xpHooked.swap)
    end
  end
  -- tooltip line on every XP bar we use (each container has its own); only frames that already
  -- show the game's tooltip (adding an OnEnter to another frame would catch the mouse and hide it)
  if not xpHooked.done[holder or bar] then
    xpHooked.done[holder or bar] = true
    for _, f in ipairs({ holder, bar }) do
      if f and f.HookScript and f.GetScript and f:GetScript("OnEnter") then pcall(f.HookScript, f, "OnEnter", xpHooked.line) end
    end
  end
  local xp = QoL.CompletedQuestXP()
  local cur, max = UnitXP and UnitXP("player") or 0, UnitXPMax and UnitXPMax("player") or 0
  local w = bar:GetWidth() or 0
  xpCap:Hide()
  if xp <= 0 or max <= 0 or w <= 0 then xpMarker:Hide(); return end
  -- measure the track on the game's own fill (user 11.11.2026: at a full bar the mark stuck out past the end cap, and
  -- guessing the cap with fixed insets put the mark on top of the fill in beta2): the fill starts where the track starts
  -- and its width is cur/max of the track, so the track's 100 % end is where the fill would end at a full bar
  local fill = bar.GetStatusBarTexture and bar:GetStatusBarTexture()
  local bl = bar.GetLeft and bar:GetLeft()
  local fl, fr = fill and fill.GetLeft and fill:GetLeft(), fill and fill.GetRight and fill:GetRight()
  local frac = cur / max
  local start, full = 0, w
  if bl and fl and fr and frac >= 0.05 and fr > fl then
    local s0, f0 = fl - bl, (fr - fl) / frac
    if s0 >= 0 and f0 > w * 0.5 and s0 + f0 <= w * 1.05 then start, full = s0, math.min(f0, w - s0) end
  end
  local x1 = start + full * math.min(1, frac)
  local x2 = start + full * math.min(1, (cur + xp) / max)
  -- height of the game's own fill (the bar frame is taller: a full-height mark showed outside the frame, beta3);
  -- the track ends in a point: measured on the user's screenshots (11.11. 23:04 / 23:27, beta7 stopped ~5 px short)
  -- the point starts 0.27 fill heights before the 100 % end and ends 0.08 after it - the mark ends there with the same point (Assets/xp_cap.tga)
  local top, bottom, hf = 0, 0, bar.GetHeight and bar:GetHeight() or 0
  local bt, bb = bar.GetTop and bar:GetTop(), bar.GetBottom and bar:GetBottom()
  local ft, fb = fill and fill.GetTop and fill:GetTop(), fill and fill.GetBottom and fill:GetBottom()
  if bt and bb and ft and fb and ft > fb and ft <= bt + 1 and fb >= bb - 1 then top, bottom, hf = ft - bt, fb - bb, ft - fb end
  local tipStart, tipEnd = start + full - hf * 0.27, start + full + hf * 0.08
  local capped = x2 >= tipStart
  if capped then x2 = tipStart end
  if x2 - x1 < 1 and not capped then xpMarker:Hide(); return end
  xpMarker:ClearAllPoints()
  xpMarker:SetPoint("TOPLEFT", bar, "TOPLEFT", x1, top); xpMarker:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", x1, bottom)
  xpMarker:SetWidth(math.max(x2 - x1, 0.01)); if x2 - x1 >= 1 then xpMarker:Show() else xpMarker:Hide() end
  if capped then
    local cx = math.max(x1, tipStart)
    xpCap:ClearAllPoints()
    xpCap:SetPoint("TOPLEFT", bar, "TOPLEFT", cx, top); xpCap:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", cx, bottom)
    xpCap:SetWidth(math.max(tipEnd - tipStart, 1)); xpCap:Show()
  end
end

-- ---------------------------------------------------------------------------
-- Free bag slots (normal bags only: no quivers, ammo or profession bags)
-- ---------------------------------------------------------------------------
local bagText
function QoL.FreeBagSlots()
  local f = (C_Container and C_Container.GetContainerNumFreeSlots) or GetContainerNumFreeSlots
  if not f then return nil end
  local free = 0
  for bag = 0, NUM_BAGS do
    local n, family = f(bag)
    if n and (family == 0 or family == nil) then free = free + n end
  end
  return free
end
local function updateBagSlots()
  local btn = MainMenuBarBackpackButton
  if type(btn) ~= "table" then return end
  local on = QoL.Get("bagSlots")
  if not bagText then
    bagText = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    bagText:SetPoint("BOTTOMRIGHT", -2, 3)
  end
  local blizz = btn.Count or _G["MainMenuBarBackpackButtonCount"]
  if blizz and blizz.SetAlpha then blizz:SetAlpha(on and 0 or 1) end
  if not on then bagText:Hide(); return end
  local free = QoL.FreeBagSlots()
  bagText:SetText(free and tostring(free) or "")
  if free and free <= 2 then bagText:SetTextColor(1, 0.3, 0.3) else bagText:SetTextColor(1, 1, 1) end
  bagText:Show()
end

-- Ammo on the bag bar (beta48/49, user 09.11.): a quiver / ammo pouch slot (and the ammo slot) shows ALL arrows / bullets
-- in the bags, the same number as the info bar's Class reagent ("wie im info panel alle aus den taschen"), not only
-- what the quiver holds, and never the game's "*" (more than 999; above 9999 as "12k"). A hook after
-- SetItemButtonCount: returns at once for item buttons that are not the bag bar / ammo slot.
function QoL._bagBarCount(btn, count) -- a field, not a local: QoL.lua is at Lua's 200 locals
  if type(count) ~= "number" or count < 1 then return end
  local ammoSlot = btn == _G.CharacterAmmoSlot
  if not (ammoSlot or btn.isBag) or not QoL.Get("quiverAmmo") then return end
  if not ammoSlot then -- bag slots: only quivers and ammo pouches (item class 11)
    local GII = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    local id = GetInventoryItemID and btn.GetID and GetInventoryItemID("player", btn:GetID())
    if not (id and GII and select(6, GII(id)) == 11) then return end
  end
  local IB = FLT.InfoBar
  local n = IB and IB.AmmoCount and IB.AmmoCount() or count
  local fs = btn.Count or (btn.GetName and btn:GetName() and _G[btn:GetName() .. "Count"])
  if fs and fs.SetText then fs:SetText(n > 9999 and (math.floor(n / 1000) .. "k") or tostring(n)) end
end
if hooksecurefunc and type(SetItemButtonCount) == "function" then hooksecurefunc("SetItemButtonCount", QoL._bagBarCount) end
-- switched on or off: the bag slots draw their count again (the game's own number when off)
function QoL._bagBarRedraw()
  if type(SetItemButtonCount) ~= "function" or not GetInventoryItemCount then return end
  for _, n in ipairs({ "CharacterBag0Slot", "CharacterBag1Slot", "CharacterBag2Slot", "CharacterBag3Slot", "CharacterAmmoSlot" }) do
    local b = _G[n]
    if type(b) == "table" and b.GetID then pcall(SetItemButtonCount, b, GetInventoryItemCount("player", b:GetID()) or 0) end
  end
end

-- ---------------------------------------------------------------------------
-- Tooltips: sell price, boss drops, who knows a recipe
-- ---------------------------------------------------------------------------
local dropIndex
local function bossDrops(id)
  if not dropIndex then
    dropIndex = {}
    for _, d in ipairs(FLT.DUNGEONS or {}) do
      for _, b in ipairs(d.bosses or {}) do
        for _, it in ipairs(b.loot or {}) do
          if it.id then
            dropIndex[it.id] = dropIndex[it.id] or {}
            -- boss and dungeon in the client's language (6.2.0; the index is built at the first tooltip, after ADDON_LOADED)
            table.insert(dropIndex[it.id], (FLT.Name and FLT.Name(b.name) or b.name) .. " (" .. (FLT.DungeonName and FLT.DungeonName(d.name) or d.name) .. ")")
          end
        end
      end
    end
  end
  return dropIndex[id]
end

local recipeIndex
local function recipeByItem(id)
  if not recipeIndex then
    recipeIndex = {}
    for prof, list in pairs(FLT.PROFESSION_RECIPES or {}) do
      for _, r in ipairs(list) do if r.ri then recipeIndex[r.ri] = { prof = prof, s = r.s } end end
    end
  end
  return recipeIndex[id]
end

-- Copy this character's known recipes to the account (for "Twinks: ..."; key FLT.CharKey, 6.2.5).
function QoL.SnapshotRecipes()
  if type(OneForAllDB) ~= "table" or type(OneForAllCharDB) ~= "table" or not FLT.CharKey then return end
  local profs = OneForAllCharDB.professions
  if type(profs) ~= "table" then return end
  OneForAllDB.altRecipes = OneForAllDB.altRecipes or {}
  local snap = {}
  for prof, p in pairs(profs) do
    if type(p) == "table" and type(p.known) == "table" then
      local t = {}
      for s, v in pairs(p.known) do if v then t[s] = true end end
      snap[prof] = t
    end
  end
  FLT.CharSave(OneForAllDB.altRecipes, snap)
end
local function twinksKnowing(prof, s)
  local out, all = {}, type(OneForAllDB) == "table" and OneForAllDB.altRecipes or {}
  for key, data in pairs(all) do
    if not FLT.IsMyChar(key) and type(data) == "table" and type(data[prof]) == "table" and data[prof][s] then
      out[#out + 1] = FLT.CharLabel(all, key, data)
    end
  end
  table.sort(out)
  return out
end

local function nameList(list, max)
  if #list <= max then return table.concat(list, ", ") end
  local t = {}
  for i = 1, max do t[i] = list[i] end
  return table.concat(t, ", ") .. string.format(" +%d", #list - max)
end

-- Disenchant value (6.2.6-beta33, user 12.11.: "disenchant value ... als schalter im qol ... nur wenn auctionator
-- installiert ist ... im gleichen stil wie auctionator und darunter"): the expected worth of the dust, essences and shards
-- (Data/Disenchant.lua chances x Auctionator prices) for green, blue and purple weapons and armor; nil = none / no prices
do -- (in a block: the file is at Lua's limit of 200 locals)
local NO_DE = { INVTYPE_BODY = true, INVTYPE_TABARD = true, INVTYPE_BAG = true, INVTYPE_AMMO = true, INVTYPE_QUIVER = true }
-- (beta34, user 12.11.: "sehe keinen tooltip fuer disenchant" - the Forever client has these only under C_Item; looked
-- up at call time so the tests can swap them)
local function info(id) local f = (C_Item and C_Item.GetItemInfo) or GetItemInfo; if f then return f(id) end end
local function instant(id) local f = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant; if f then return f(id) end end
function QoL.DisenchantValue(id)
  local SU, T = FLT.SkillUp, FLT.DISENCHANT
  if not (SU and SU.AHPrice and T) then return nil end
  local _, _, _, loc, _, cls = instant(id)
  if not (cls == 2 or cls == 4) or not loc or loc == "" or NO_DE[loc] then return nil end
  local _, _, q, ilvl = info(id)
  local list = q and T[q]
  if not (list and ilvl and ilvl > 0) then return nil end
  for _, b in ipairs(list) do
    if ilvl <= b[1] then
      local parts = (cls == 2 and b.weapon) or b.armor
      local v = 0
      for _, p in ipairs(parts) do
        local price = SU.AHPrice(p[1])
        if price then v = v + price * p[2] * (p[3] + p[4]) / 2 end
      end
      return v > 0 and v or nil
    end
  end
end
end

-- beta35 (user 12.11.: "bekommt man den eintrag irgendwie direkt drunter ... also unter Auction"): right under Auctionator's
-- "Auction" line. 6.2.12-beta22 (Discord razoroth 18.11.: ItemTree's divider sat on our moved text, lines pushed out of the
-- tooltip): no more moving text between the tooltip's lines (other addons anchor their pieces to those lines) - the line is
-- added while Auctionator writes its own, right after its Auction line (post-hook on Auctionator.Tooltip.AddAuctionTip).
-- Without that hook, or with Auctionator's auction price line switched off: at the end of the tooltip as before.
do
  -- beta25 (tester Deaders 19.11.: "this line is not displayed at all" - an enchanter, recipe tooltips): Auctionator's pass
  -- may run before ours or not at all (no auction line for that item), and tt:GetItem() can be empty there. So: the item of
  -- our pass is remembered; Auctionator's pass uses it; if Auctionator already ran without adding, or does not run in this
  -- fill, the line goes at the end (next frame at the latest).
  local hooked, done, watched, lastId, fired = false, {}, {}, {}, {}
  local function watch(tt)
    if watched[tt] or not tt.HookScript then return end
    watched[tt] = true
    tt:HookScript("OnTooltipCleared", function(self) done[self], lastId[self], fired[self] = nil, nil, nil end)
  end
  local function add(tt, id)
    if done[tt] then return end
    local v = id and QoL.DisenchantValue(id)
    if not v then return end
    watch(tt)
    tt:AddDoubleLine(L["Disenchant"], money(v), 1, 0.82, 0, 1, 1, 1)
    done[tt] = true
  end
  local function hook()
    if hooked then return true end -- (not cached while missing: Auctionator may load after the first tooltip)
    local tips = Auctionator and Auctionator.Tooltip
    hooked = hooksecurefunc and type(tips) == "table" and type(tips.AddAuctionTip) == "function" and true or false
    if hooked then
      hooksecurefunc(tips, "AddAuctionTip", function(tt)
        if type(tt) ~= "table" or not QoL.Get("deValue") then return end
        if tt.IsForbidden and tt:IsForbidden() then return end
        watch(tt); fired[tt] = true
        local id = lastId[tt]
        if not id and tt.GetItem then
          local ok, _, link = pcall(tt.GetItem, tt)
          if ok and type(link) == "string" and not FLT.IsSecret(link) then id = tonumber(link:match("item:(%d+)")) end
        end
        if id then pcall(add, tt, id) end
      end)
    end
    return hooked
  end
  local function auctionLineOn()
    local C = Auctionator and Auctionator.Config
    local ok, on = pcall(function() return C.Get(C.Options.AUCTION_TOOLTIPS) end)
    return ok and on and true or false
  end
  function QoL.DisenchantLine(tt, id)
    if done[tt] or not id then return end
    watch(tt); lastId[tt] = id
    if not (hook() and auctionLineOn()) or fired[tt] then add(tt, id); return end -- no hook / Auctionator was first
    -- Auctionator's pass comes later in this fill and adds it under Auction; if it never comes: at the end, next frame
    if C_Timer then
      C_Timer.After(0, function()
        if not done[tt] and lastId[tt] == id and tt.IsShown and tt:IsShown() then add(tt, id); if done[tt] then tt:Show() end end
      end)
    end
  end
  QoL._deDone = done -- tests
end

local function addItemLines(tt, link)
  if type(link) ~= "string" then return end
  local id = tonumber(link:match("item:(%d+)"))
  if not id then return end
  -- right under Auctionator's "Vendor" / "Auction" lines, in their look (only with Auctionator: the prices come from it)
  if QoL.Get("deValue") and FLT.SkillUp and FLT.SkillUp.HasAuctionator() then
    pcall(QoL.DisenchantLine, tt, id)
  end
  if QoL.Get("bossDrops") then
    local drops = bossDrops(id)
    if drops then tt:AddLine(L["Drops from:"] .. " " .. nameList(drops, 2), 0.95, 0.80, 0.45, true) end
  end
  if QoL.Get("gearValue") and FLT.GearValue then FLT.GearValue.TooltipLine(tt, id, link) end
  -- on the wishlist (Armory > Gear Planner): always, it is the player's own choice (user 03.11.)
  if FLT.IsOnWishlist and FLT.GearValue and FLT.GearValue.WISH and FLT.IsOnWishlist(id) then tt:AddLine(FLT.GearValue.WISH .. L["Wishlist"], 1, 0.82, 0.25) end
  if QoL.Get("sellJunk") and junkList()[id] then tt:AddLine(string.format(L["On your junk list (%s to take it off)"], QoL.JunkKeyText()), 0.62, 0.62, 0.62) end
  if FLT.CraftList then FLT.CraftList.TooltipLine(tt, id) end -- only while something is planned
  if QoL.Get("recipeTip") then
    local r = recipeByItem(id)
    if r then
      local me = FLT.GetProfessionState and FLT.GetProfessionState(r.prof)
      if me and me.known and me.known[r.s] then tt:AddLine(L["You know this recipe"], 0.45, 1, 0.45) end
      local tw = twinksKnowing(r.prof, r.s)
      if #tw > 0 then tt:AddLine(L["Twinks:"] .. " " .. nameList(tw, 4), 0.75, 0.75, 1, true) end
      local g = FLT.GetGuildRecipeKnowers and FLT.GetGuildRecipeKnowers(r.prof, r.s)
      if g and #g > 0 then
        local names = {}
        for _, k in ipairs(g) do names[#names + 1] = short(k[1]) end
        tt:AddLine(L["Guild:"] .. " " .. nameList(names, 4), 0.45, 0.85, 0.45, true)
      end
    end
  end
end

-- "Target: name" in the tooltip of players (and NPCs) under the mouse
local function addTargetLine(tt)
  if not QoL.Get("unitTarget") or not tt or not tt.GetUnit then return end
  local _, unit = tt:GetUnit()
  if not unit then return end
  -- 6.2.10 (Discord darkgameover / olgi 15.11.: tooltips of units in the world stayed 2 s and longer): the game refreshes
  -- the tooltip while it fades out after the mouse left the unit - our Show() below stopped the fade every time
  if UnitExists and not UnitExists("mouseover") then return end
  local tu = unit .. "target"
  if not (UnitExists and UnitExists(tu)) then return end
  local name = UnitName(tu)
  if not name or (issecretvalue and issecretvalue(name)) then return end
  local text
  if UnitIsUnit and UnitIsUnit(tu, "player") then
    text = "|cffff4040>> " .. L["You"] .. " <<|r"
  elseif UnitIsPlayer(tu) then
    local _, cls = UnitClass(tu)
    local c = cls and (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS or {})[cls]
    text = c and string.format("|cff%02x%02x%02x%s|r", c.r * 255, c.g * 255, c.b * 255, name) or name
  else
    text = name
  end
  tt:AddLine(L["Target:"] .. " " .. text, 1, 0.82, 0)
  tt:Show()
end

-- Short green stats (6.0.1, user 31.10.; the idea from EasyGreenStats, our own code and patterns): long "Equip:" lines
-- in item tooltips become short stats, e.g. "Equip: Improves your chance to hit by 1%." -> "+1% Hit". Lines we do not
-- know stay as they are. "Enchanted:" lines get the number in front. English game texts only (other clients: no match).
local SHORT = { -- { pattern, result } in this order; %1 %2 = captures (percent values may have decimals: "1.0%")
  { "^Increases healing done by up to (%d+) and damage done by up to (%d+) for all magical spells and effects%.$", "+%2 Spell Damage\n+%1 Spell Healing" },
  { "^Increases damage and healing done by magical spells and effects by up to (%d+)%.$", "+%1 Spell Damage and Healing" },
  { "^Increases healing done by spells and effects by up to (%d+)%.$", "+%1 Spell Healing" },
  { "^Increases healing done by magical spells and effects by up to (%d+)%.$", "+%1 Spell Healing" },
  { "^Increases damage done to (%a+) by magical spells and effects by up to (%d+)%.$", "+%2 Spell Damage vs %1" },
  { "^Increases damage done by (%a+) spells and effects by up to (%d+)%.$", "+%2 %1 Spell Damage" },
  { "^Improves your chance to get a critical strike with spells by ([%d%.]+)%%%.$", "+%1%% Spell Critical Strike" },
  { "^Improves your chance to get a critical strike by ([%d%.]+)%%%.$", "+%1%% Critical Strike" },
  { "^Improves your chance to hit with spells by ([%d%.]+)%%%.$", "+%1%% Spell Hit" },
  { "^Improves your chance to hit by ([%d%.]+)%%%.$", "+%1%% Hit" },
  { "^%+(%d+) ranged Attack Power%.$", "+%1 Ranged Attack Power" },
  { "^%+(%d+) Attack Power when fighting (%a+)%.$", "+%1 Attack Power vs %2" },
  { "^%+(%d+) Attack Power%.$", "+%1 Attack Power" },
  { "^Increases attack power by (%d+)%.$", "+%1 Attack Power" },
  { "^Restores (%d+) [Mm]ana per 5 sec%.$", "+%1 Mana per 5 sec" },
  { "^Restores (%d+) [Hh]ealth per 5 sec%.$", "+%1 Health per 5 sec" },
  { "^Increased Defense %+(%d+)%.$", "+%1 Defense" },
  { "^Increases your chance to dodge an attack by ([%d%.]+)%%%.$", "+%1%% Dodge" },
  { "^Increases your chance to parry an attack by ([%d%.]+)%%%.$", "+%1%% Parry" },
  { "^Increases your chance to block attacks with a shield by ([%d%.]+)%%%.$", "+%1%% Block" },
  { "^Increases the [Bb]lock [Vv]alue of your shield by (%d+)%.$", "+%1 Block Value" }, -- "Block Value" (Discord 11.11.)
  -- 6.2.5 (Discord vkinglouie 11.11.: lines left long), checked against all equip spells of the Forever client
  { "^Increases all threat generated by ([%d%.]+)%%%.$", "+%1%% Threat" },
  { "^Decreases all threat generated by ([%d%.]+)%%%.$", "-%1%% Threat" },
  { "^%+(%d+) Attack Power in Cat, Bear, and Dire Bear forms only%.$", "+%1 Feral Attack Power" },
  { "^Increases melee and ranged attack power by (%d+)%.$", "+%1 Attack Power" },
  { "^%+(%d+) (%a+)%.$", "+%1 %2" }, -- "+5 Spirit."
  { "^Decreases the magical resistances of your spell targets by (%d+)%.$", "+%1 Spell Penetration" },
  { "^Increases your attack speed by ([%d%.]+)%%%.$", "+%1%% Attack Speed" },
  { "^Increased ([%a%- ]+) %+(%d+)%.$", "+%2 %1" }, -- weapon skills ("Increased Daggers +3.")
}
-- the game client's language (6.2.0, user 07.11.: "keine short stats auf deutsch"): German patterns made from the German
-- item texts on Wowhead Forever (tools/locale/shortstats_fetch.py + shortstats_de.py); the short results stay German
-- in a German client (the tooltip around them is German). Other clients: no match, lines stay as they are.
SHORT.de = { -- (fields of SHORT: QoL.lua is at the 200 locals limit)
--SHORT_DE_BEGIN
    { "^Verbessert Eure Trefferchance um ([%d%.,]+)%%%.$", "+%1%% Trefferchance" },
    { "^Erhöht durch magische Zauber und Effekte verursachten Schaden und Heilung um bis zu (%d+)%.$", "+%1 Zauberschaden und Heilung" },
    { "^Erhöht durch sämtliche Zauber und magische Effekte verursachte Heilung um bis zu (%d+) und den verursachten Schaden um bis zu (%d+)%.$", "+%2 Zauberschaden\n+%1 Heilung" },
    { "^Verteidigung %+(%d+)%.$", "+%1 Verteidigung" },
    { "^Erhöht Eure kritische Trefferchance um ([%d%.,]+)%%%.$", "+%1%% kritische Treffer" },
    { "^%+(%d+) Angriffskraft%.$", "+%1 Angriffskraft" },
    { "^Erhöht den durch Feuerzauber und %-effekte verursachten Schaden um bis zu (%d+)%.$", "+%1 Feuerschaden" },
    { "^Erhöht den von Schattenzaubern und %-effekten verursachten Schaden um bis zu (%d+)%.$", "+%1 Schattenschaden" },
    { "^Erhöht den von Heiligzaubern und %-effekten verursachten Schaden um bis zu (%d+)%.$", "+%1 Heiligschaden" },
    { "^Erhöht den durch Naturzauber und %-effekte verursachten Schaden um bis zu (%d+)%.$", "+%1 Naturschaden" },
    { "^Erhöht den durch Frostzauber und %-effekte verursachten Schaden um bis zu (%d+)%.$", "+%1 Frostschaden" },
    { "^Erhöht den von Arkanzaubern und %-effekten verursachten Schaden um bis zu (%d+)%.$", "+%1 Arkanschaden" },
    { "^Erhöht die durch magische Zauber und Effekte verursachte Heilung um bis zu (%d+)%.$", "+%1 Heilung" },
    -- by hand (user's screenshot 07.11. and samples whose wording has a word in it, see tools/locale/shortstats_de.py)
    { "^Stellt alle 5 Sek%. (%d+) Mana wieder her%.$", "+%1 Mana alle 5 Sek." },
    { "^Erhöht den durch magische Zauber und magische Effekte verursachten Schaden gegen (.-) um bis zu (%d+)%.$", "+%2 Zauberschaden gg. %1" },
    { "^([^%d%+]-) %+(%d+)%.$", "+%2 %1" }, -- skills ("Kräuterkunde +2.", weapon skills)
--SHORT_DE_END
}
SHORT.equip, SHORT.ench, SHORT.list = "^Equip: ", "^Enchanted: ", SHORT
if GetLocale and GetLocale() == "deDE" then SHORT.equip, SHORT.list = "^Anlegen: ", SHORT.de end
local function shortStat(text)
  local body = text:match(SHORT.equip .. "(.+)$")
  if body then
    local list = SHORT.list
    for i = 1, #list do
      local out, n = body:gsub(list[i][1], list[i][2])
      if n > 0 then return (out:gsub("(%d)%.0%%", "%1%%")) end -- "+1.0% Hit" -> "+1% Hit"
    end
    return
  end
  body = text:match(SHORT.ench .. "(.+)$")
  if body and body:find(" %+%d") then -- "Stamina +1 and Armor +8" -> "+1 Stamina and +8 Armor"
    return "Enchanted: " .. (body .. " and "):gsub("(.-) %+(%d+%%?) and ", "+%2 %1 and "):sub(1, -6)
  end
end
-- only the game's own item tooltips (6.2.14, Discord hedek1 23.11.: Dugi Guides' hidden stat-reading tooltip has lines without
-- a font - "SetText(): Font not set" and taint - and other addons read the original text there)
QoL.SHORT_TIPS = { GameTooltip = true, ItemRefTooltip = true, ShoppingTooltip1 = true, ShoppingTooltip2 = true,
  ItemRefShoppingTooltip1 = true, ItemRefShoppingTooltip2 = true, EmbeddedItemTooltip = true }
local function shortenTooltip(tt)
  if not QoL.Get("shortStats") or type(tt) ~= "table" or not tt.GetName or not tt.NumLines then return end
  local name = tt:GetName(); if not name or not QoL.SHORT_TIPS[name] then return end
  local changed
  for i = 2, tt:NumLines() do
    local line = _G[name .. "TextLeft" .. i]
    local text = line and line:GetText()
    if text and (text:find(SHORT.equip) or text:find(SHORT.ench)) then
      local out = shortStat(text)
      if out then line:SetText(out); changed = true end
    end
  end
  if changed then tt:Show() end -- size the tooltip to the shorter lines
end
QoL.ShortStat = shortStat -- mock tests

-- quests you can take / turn in at the NPC (MapQuests.lua, 6.2.2)
local function addQuestLines(tt)
  if not QoL.Get("npcQuestTip") or not (FLT.MapQuests and FLT.MapQuests.AddUnitLines) or not tt.GetUnit then return end
  local _, unit = tt:GetUnit()
  FLT.MapQuests.AddUnitLines(tt, unit)
end
-- Tooltip at the mouse (6.2.7-beta15, user 13.11.: "eine option damit der tool tip an der maus geankert werden kann ...
-- top mit jeweils left center right und das gleiche mit bottom ... in dungeon, raids nicht aktiv und auf pvp schlachtfeldern,
-- das aber getrennt"). Only tooltips that use the game's default place (GameTooltip_SetDefaultAnchor: units in the world,
-- action buttons, ...); "Top left" = above the mouse, to its left. Follows the mouse only while such a tooltip is shown.
do -- own block: this file is at Lua's limit of 200 top-level locals
QoL.TIP_ANCHORS = {
  { key = "TOPLEFT", label = N"Top left" }, { key = "TOP", label = N"Top center" }, { key = "TOPRIGHT", label = N"Top right" },
  { key = "BOTTOMLEFT", label = N"Bottom left" }, { key = "BOTTOM", label = N"Bottom center" }, { key = "BOTTOMRIGHT", label = N"Bottom right" },
}
local TIP_POINT = { -- tooltip corner at the cursor, offset (the bottom ones keep clear of the mouse pointer)
  TOPLEFT = { "BOTTOMRIGHT", -4, 6 }, TOP = { "BOTTOM", 0, 8 }, TOPRIGHT = { "BOTTOMLEFT", 4, 6 },
  BOTTOMLEFT = { "TOPRIGHT", -4, -20 }, BOTTOM = { "TOP", 0, -24 }, BOTTOMRIGHT = { "TOPLEFT", 18, -20 },
}
local function tipMouseOff()
  if not QoL.Get("tipMouse") then return true end
  local inside, kind -- not "a, b = f and f()": the "and" keeps one value (kind was always nil, 6.2.12)
  if IsInInstance then inside, kind = IsInInstance() end
  if not inside then return false end
  if (kind == "party" or kind == "raid" or kind == "scenario") and QoL.Get("tipMouseNoDungeon") then return true end
  if (kind == "pvp" or kind == "arena") and QoL.Get("tipMouseNoPvP") then return true end
  return false
end
QoL._tipMouseOff = tipMouseOff -- tests
local function tipAtMouse(tt)
  local p = TIP_POINT[QoL.Get("tipMousePos") or "BOTTOMRIGHT"] or TIP_POINT.BOTTOMRIGHT
  local x, y = GetCursorPosition()
  local sc = UIParent:GetEffectiveScale()
  tt:ClearAllPoints(); tt:SetPoint(p[1], UIParent, "BOTTOMLEFT", x / sc + p[2], y / sc + p[3])
end
function QoL.SetupTipMouse()
  if not (hooksecurefunc and GameTooltip and GameTooltip.HookScript and GetCursorPosition) then return end
  hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tt, parent)
    tt._ofaMouse = nil
    if tt ~= GameTooltip or tipMouseOff() then return end
    tt:SetOwner(parent or UIParent, "ANCHOR_NONE"); tt._ofaMouse = true; tipAtMouse(tt)
  end)
  GameTooltip:HookScript("OnUpdate", function(tt) if tt._ofaMouse then tipAtMouse(tt) end end)
  GameTooltip:HookScript("OnHide", function(tt) tt._ofaMouse = nil end)
end
end

local function setupTooltips()
  pcall(QoL.SetupTipMouse)
  if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tt)
      if tt == GameTooltip then pcall(addTargetLine, tt); pcall(addQuestLines, tt) end
    end)
  elseif GameTooltip and GameTooltip.HookScript then
    pcall(GameTooltip.HookScript, GameTooltip, "OnTooltipSetUnit", function(tt) pcall(addTargetLine, tt); pcall(addQuestLines, tt) end)
  end
  local function handler(tt)
    if not (QoL.Get("bossDrops") or QoL.Get("recipeTip") or QoL.Get("gearValue") or QoL.Get("deValue")) then return end
    if not tt or not tt.GetItem then return end
    local _, link = tt:GetItem()
    addItemLines(tt, link)
  end
  -- the blue appearance lines in item tooltips (6.0.2, user 01.11.: switch hideAppearance): left out while the tooltip
  -- is built (a line pre-call that returns true skips the line), matched with the client's own strings (any language)
  local function appearanceLine(t)
    return type(t) == "string" and not FLT.IsSecret(t) and (t == TRANSMOGRIFY_TOOLTIP_APPEARANCE_UNKNOWN
      or t == TRANSMOGRIFY_TOOLTIP_ITEM_UNKNOWN_APPEARANCE_KNOWN)
  end
  if TooltipDataProcessor and TooltipDataProcessor.AddLinePreCall and TooltipDataProcessor.AllTypes then
    TooltipDataProcessor.AddLinePreCall(TooltipDataProcessor.AllTypes, function(_, line)
      if line and QoL.Get("hideAppearance") and appearanceLine(line.leftText) then return true end
    end)
  end
  if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt)
      if tt == GameTooltip or tt == ItemRefTooltip then handler(tt) end
      shortenTooltip(tt) -- every item tooltip, also the comparison ones
    end)
  else
    for _, tt in ipairs({ GameTooltip, ItemRefTooltip }) do
      if tt and tt.HookScript then pcall(tt.HookScript, tt, "OnTooltipSetItem", handler) end
    end
    for _, tt in ipairs({ GameTooltip, ItemRefTooltip, ShoppingTooltip1, ShoppingTooltip2 }) do
      if type(tt) == "table" and tt.HookScript then pcall(tt.HookScript, tt, "OnTooltipSetItem", shortenTooltip) end
    end
  end
end

-- ---------------------------------------------------------------------------
-- Loot feed: looted items and money float up next to the character
-- ---------------------------------------------------------------------------
local FEED_W, FEED_H, FEED_LIFE, FEED_GAP = 260, 200, 4.5, 22
local feed, feedPool, feedActive = nil, {}, {}
local QUALITY_RGB = { [0]={0.62,0.62,0.62}, [1]={1,1,1}, [2]={0.12,1,0}, [3]={0,0.44,0.87}, [4]={0.64,0.21,0.93}, [5]={1,0.5,0} }
QoL.QUALITY_OPTIONS = {
  { key = 0, label = N"Poor (grey)" }, { key = 1, label = N"Common (white)" }, { key = 2, label = N"Uncommon (green)" },
  { key = 3, label = N"Rare (blue)" }, { key = 4, label = N"Epic (purple)" },
}

local function feedPos()
  local d = db(); local p = d and d.lootFeedPos
  if p then return p[1], p[2] end
  -- default: well to the right of the character, a little above the middle
  local w = UIParent and UIParent.GetWidth and UIParent:GetWidth() or 1920
  return math.floor(w * 0.19 + 0.5), 20
end
local function feedFrame()
  if feed then return feed end
  feed = CreateFrame("Frame", "OneForAllLootFeed", UIParent)
  feed:SetSize(FEED_W, FEED_H); feed:SetFrameStrata("FULLSCREEN_DIALOG"); feed:SetClampedToScreen(true)
  local x, y = feedPos()
  feed:SetPoint("CENTER", UIParent, "CENTER", x, y)
  feed:SetMovable(true)
  local bg = feed:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(0.1, 0.1, 0.12, 0.55)
  local edge = feed:CreateTexture(nil, "BORDER"); edge:SetPoint("TOPLEFT", -1, 1); edge:SetPoint("BOTTOMRIGHT", 1, -1); edge:SetColorTexture(FLT.SkinC(0.85, 0.66, 0.25, 0.6))
  bg:SetDrawLayer("BACKGROUND", 1); edge:SetDrawLayer("BACKGROUND", 0)
  local label = feed:CreateFontString(nil, "OVERLAY", "GameFontNormal"); label:SetPoint("CENTER")
  label:SetText(L["Loot feed"] .. "\n|cffffffff" .. L["Drag to move, then click Lock in the Quality of Life tab"] .. "|r")
  feed.mover = { bg, edge, label }
  feed:SetScript("OnMouseDown", function(self, b) if b == "LeftButton" and self.unlocked then self:StartMoving() end end)
  feed:SetScript("OnMouseUp", function(self)
    self:StopMovingOrSizing()
    local cx, cy = self:GetCenter(); local ux, uy = UIParent:GetCenter()
    if cx and ux then
      local d = db(); if d then d.lootFeedPos = { math.floor(cx - ux + 0.5), math.floor(cy - uy + 0.5) } end
    end
  end)
  -- runs only while lines are moving (started in the code that adds a line, stopped when the last one is gone)
  feed.tick = function(self, elapsed)
    local speed = FEED_H / FEED_LIFE
    for i = #feedActive, 1, -1 do
      local e = feedActive[i]
      e.age = e.age + elapsed; e.y = e.y + speed * elapsed
      local a = 1
      if e.age < 0.2 then a = e.age / 0.2 elseif e.age > FEED_LIFE - 1 then a = math.max(0, FEED_LIFE - e.age) end
      e:SetAlpha(a)
      e:ClearAllPoints(); e:SetPoint("BOTTOMLEFT", feed, "BOTTOMLEFT", 4, e.y)
      if e.age >= FEED_LIFE or e.y > FEED_H - 18 then e:Hide(); table.remove(feedActive, i); feedPool[#feedPool + 1] = e end
    end
    if #feedActive == 0 then self:SetScript("OnUpdate", nil) end
  end
  QoL.SetLootFeedUnlocked(false)
  return feed
end

function QoL.SetLootFeedUnlocked(on)
  local f = feed or feedFrame()
  f.unlocked = on and true or false
  for _, r in ipairs(f.mover) do r:SetShown(f.unlocked) end
  f:EnableMouse(f.unlocked)
  f:Show()
end
function QoL.IsLootFeedUnlocked() return feed and feed.unlocked or false end
function QoL.ResetLootFeed()
  local d = db(); if d then d.lootFeedPos = nil end
  if feed then local x, y = feedPos(); feed:ClearAllPoints(); feed:SetPoint("CENTER", UIParent, "CENTER", x, y) end
end

local function feedAdd(icon, text, r, g, b)
  local f = feedFrame()
  local e = table.remove(feedPool)
  if not e then
    e = CreateFrame("Frame", nil, f); e:SetSize(FEED_W - 8, 20)
    e.icon = e:CreateTexture(nil, "ARTWORK"); e.icon:SetSize(18, 18); e.icon:SetPoint("LEFT")
    e.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    e.text = e:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    e.text:SetJustifyH("LEFT"); e.text:SetWidth(FEED_W - 34); e.text:SetWordWrap(false)
    do local font, _, flags = e.text:GetFont(); if font then e.text:SetFont(font, 14, "OUTLINE") end end
  end
  -- icon = false: no icon, the text starts at the left (money: the coins are in the text already; 6.2.6, user 11.11.)
  e.icon:SetShown(icon ~= false)
  e.text:ClearAllPoints()
  if icon == false then e.text:SetPoint("LEFT", e, "LEFT", 0, 0)
  else e.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark"); e.text:SetPoint("LEFT", e.icon, "RIGHT", 6, 0) end
  e.text:SetText(text); e.text:SetTextColor(r or 1, g or 1, b or 1)
  -- keep a gap to the entry above
  local newest = feedActive[#feedActive]
  if newest and newest.y < FEED_GAP then
    local push = FEED_GAP - newest.y
    for _, o in ipairs(feedActive) do o.y = o.y + push end
  end
  e.age, e.y = 0, 0
  e:SetAlpha(0); e:Show()
  feedActive[#feedActive + 1] = e
  if not f:GetScript("OnUpdate") then f:SetScript("OnUpdate", f.tick) end
end

-- "You receive loot: %s." -> Lua pattern (localised from the game strings)
local function toPattern(fmt)
  if type(fmt) ~= "string" then return nil end
  local p = fmt:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
  p = p:gsub("%%%d?%$?s", "(.+)"):gsub("%%%d?%$?d", "(%%d+)")
  return "^" .. p .. "$"
end
local lootPatterns
local function selfLoot(text)
  if not lootPatterns then
    lootPatterns = {}
    for _, k in ipairs({ "LOOT_ITEM_SELF_MULTIPLE", "LOOT_ITEM_PUSHED_SELF_MULTIPLE", "LOOT_ITEM_CREATED_SELF_MULTIPLE",
                         "LOOT_ITEM_SELF", "LOOT_ITEM_PUSHED_SELF", "LOOT_ITEM_CREATED_SELF" }) do
      local p = toPattern(_G[k]); if p then lootPatterns[#lootPatterns + 1] = p end
    end
    if #lootPatterns == 0 then lootPatterns = { "^You receive loot: (.+)x(%d+)%.$", "^You receive item: (.+)x(%d+)%.$", "^You receive loot: (.+)%.$", "^You receive item: (.+)%.$" } end
  end
  for _, p in ipairs(lootPatterns) do
    local link, count = text:match(p)
    if link then return link, tonumber(count) or 1 end
  end
end

local function itemQualityIcon(link)
  local q, icon
  if C_Item and C_Item.GetItemInfo then pcall(function() local _, _, qq, _, _, _, _, _, _, ii = C_Item.GetItemInfo(link); q, icon = qq, ii end) end
  if (not q or not icon) and GetItemInfo then pcall(function() local _, _, qq, _, _, _, _, _, _, ii = GetItemInfo(link); q, icon = q or qq, icon or ii end) end
  if not icon then
    local id = tonumber(link:match("item:(%d+)"))
    if id and GetItemIcon then pcall(function() icon = GetItemIcon(id) end) end
  end
  if not q then
    local hex = link:match("|c%x%x(%x%x%x%x%x%x)")
    local map = { ["9d9d9d"] = 0, ffffff = 1, ["1eff00"] = 2, ["0070dd"] = 3, a335ee = 4, ff8000 = 5 }
    q = hex and map[hex:lower()] or 1
  end
  return q, icon
end

local function lootMessage(text)
  if not QoL.Get("lootFeed") or type(text) ~= "string" then return end
  local link, count = selfLoot(text)
  if not link then return end
  local q, icon = itemQualityIcon(link)
  if (q or 1) < (tonumber(QoL.Get("lootFeedQuality")) or 1) then return end
  local name = link:match("%[(.-)%]") or link
  local c = QUALITY_RGB[q or 1] or QUALITY_RGB[1]
  feedAdd(icon, (count > 1 and ("+" .. count .. " ") or "+") .. name, c[1], c[2], c[3])
end

-- Money: PLAYER_MONEY gives the amount, CHAT_MSG_MONEY tells that it was loot.
-- The two events can come in either order, so whichever comes second shows it.
local lastMoney, moneyMsgAt, pendingGain, pendingAt = nil, -10, 0, -10
local function showMoney(amount)
  if amount > 0 and QoL.Get("lootFeed") and QoL.Get("lootFeedMoney") then
    feedAdd(false, "+" .. money(amount), 1, 0.85, 0.3)
  end
end
local function moneyChanged()
  local now = GetMoney and GetMoney() or 0
  local before = lastMoney
  lastMoney = now
  if not before or now <= before then return end
  local t = GetTime and GetTime() or 0
  if t - moneyMsgAt < 1.5 then moneyMsgAt = -10; showMoney(now - before)
  else pendingGain, pendingAt = now - before, t end
end
local function moneyMessage()
  local t = GetTime and GetTime() or 0
  if t - pendingAt < 1.5 and pendingGain > 0 then showMoney(pendingGain); pendingGain, pendingAt = 0, -10
  else moneyMsgAt = t end
end

function QoL.TestLootFeed()
  feedAdd("Interface\\Icons\\INV_Misc_Pelt_Wolf_01", "+3 Light Leather", 1, 1, 1)
  feedAdd("Interface\\Icons\\INV_Sword_04", "+Trogg Scepter", 0, 0.44, 0.87)
  feedAdd(false, "+" .. money(31240), 1, 0.85, 0.3)
  feedAdd("Interface\\Icons\\INV_Sword_39", "+Thunderfury, Blessed Blade of the Windseeker", 1, 0.5, 0)
end

-- ---------------------------------------------------------------------------
-- Copy chat: a small button on every chat window opens its text in a window
-- where it can be selected and copied (Ctrl+C).
-- ---------------------------------------------------------------------------
local copyFrame, copyButtons = nil, {}
-- keeps item / spell link colours, marks web addresses blue, drops the rest
local function cleanLine(t)
  if type(t) ~= "string" then return nil end
  if issecretvalue and issecretvalue(t) then return nil end
  -- colour of a link stays, other colour codes go
  t = t:gsub("(|c%x%x%x%x%x%x%x%x)|H.-|h(.-)|h|r", "%1%2|r")
  t = t:gsub("|H.-|h(.-)|h", "%1")
  t = t:gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|K.-|k", "?")
  local keep = {}
  t = t:gsub("(|c%x%x%x%x%x%x%x%x)(%b[])|r", function(c, name) keep[#keep + 1] = c .. name .. "|r"; return "\001" .. #keep .. "\002" end)
  t = t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  t = t:gsub("\001(%d+)\002", function(i) return keep[tonumber(i)] end)
  -- web addresses
  t = t:gsub("(https?://[%w%-%._~:/%?#%[%]@!%$&'%(%)%*%+,;=%%]+)", "|cff4fb3ff%1|r")
  t = t:gsub("([^/%w])(www%.[%w%-%.]+%.%a%a+[%w%-%._~:/%?#@!%$&'%*%+,;=%%]*)", "%1|cff4fb3ff%2|r")
  return t
end
local function copyWindow()
  if copyFrame then return copyFrame end
  local UI = FLT.UI
  local f = CreateFrame("Frame", "OneForAllCopyChat", UIParent)
  f:SetSize(620, 420); f:SetPoint("CENTER"); f:SetFrameStrata("FULLSCREEN_DIALOG"); f:EnableMouse(true)
  f:SetMovable(true); f:RegisterForDrag("LeftButton"); f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
  if UI and UI.FramedPanel then UI.FramedPanel(f) end
  if UI and UI.OrnateFrame then for _, t in ipairs(UI.OrnateFrame(f, f, 16, 3, "OVERLAY", 4)) do t:SetVertexColor(FLT.SkinC(1, 1, 1, 1)) end end
  local title = FLT.NewFS(f, nil, "OVERLAY", "GameFontNormalLarge"); title:SetPoint("TOPLEFT", 18, -14); title:SetText(L["Copy chat"])
  title:SetTextColor(FLT.TextC(1, 0.82, 0.2))
  local hint = FLT.NewFS(f, nil, "OVERLAY", "GameFontDisableSmall"); hint:SetPoint("LEFT", title, "RIGHT", 12, -1)
  hint:SetText(L["Ctrl+C copies the selected text.  Esc closes."])
  local close = UI and UI.GoldButton and UI.GoldButton(f, L["Close"], 90, 22, nil, 12)
  if close then close:SetPoint("TOPRIGHT", -14, -12); close:SetScript("OnClick", function() f:Hide() end) end
  local sf = FLT.SkinBlizz(CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate"))
  sf:SetPoint("TOPLEFT", 16, -44); sf:SetPoint("BOTTOMRIGHT", -34, 14)
  local eb = CreateFrame("EditBox", nil, sf)
  eb:SetMultiLine(true); eb:SetAutoFocus(false); eb:SetFontObject(ChatFontNormal or GameFontHighlightSmall)
  eb:SetWidth(560); eb:SetMaxLetters(0)
  eb:SetScript("OnEscapePressed", function() f:Hide() end)
  eb:SetScript("OnTextChanged", function(self, user) if user then self:SetText(f.text or "") ; self:HighlightText() end end)
  sf:SetScrollChild(eb)
  if UI and UI.AutoHideScrollBar then UI.AutoHideScrollBar(sf) end
  f.eb, f.sf = eb, sf
  if UISpecialFrames then table.insert(UISpecialFrames, "OneForAllCopyChat") end
  f:Hide()
  copyFrame = f
  return f
end
function QoL.OpenCopyChat(chatFrame)
  chatFrame = chatFrame or (SELECTED_CHAT_FRAME or DEFAULT_CHAT_FRAME)
  if type(chatFrame) ~= "table" or not chatFrame.GetNumMessages then return end
  local lines = {}
  local n = chatFrame:GetNumMessages() or 0
  for i = math.max(1, n - 299), n do
    local ok, text = pcall(chatFrame.GetMessageInfo, chatFrame, i)
    local line = ok and cleanLine(text)
    if line then lines[#lines + 1] = line end
  end
  local f = copyWindow()
  f.text = table.concat(lines, "\n")
  f.eb:SetText(f.text)
  f:Show()
  f.eb:SetFocus(); f.eb:HighlightText()
  if C_Timer and C_Timer.After then C_Timer.After(0, function() f.sf:SetVerticalScroll(f.sf:GetVerticalScrollRange() or 0) end) end
end
local function setupCopyButtons()
  local on = QoL.Get("copyChat")
  for i = 1, tonumber(NUM_CHAT_WINDOWS) or 10 do
    local cf = _G["ChatFrame" .. i]
    if type(cf) == "table" then
      local b = copyButtons[i]
      if not b and on then
        b = CreateFrame("Button", nil, cf); b:SetSize(18, 18); b:SetPoint("TOPRIGHT", cf, "TOPRIGHT", 2, 2)
        b:SetFrameLevel((cf:GetFrameLevel() or 1) + 10)
        local tex = b:CreateTexture(nil, "ARTWORK"); tex:SetAllPoints(); tex:SetTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up")
        b:SetHighlightTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up", "ADD")
        b:SetAlpha(0.35)
        b:SetScript("OnEnter", function(self) self:SetAlpha(1); GameTooltip:SetOwner(self, "ANCHOR_LEFT"); GameTooltip:SetText(L["Copy chat"]); GameTooltip:Show() end)
        b:SetScript("OnLeave", function(self) self:SetAlpha(0.35); GameTooltip:Hide() end)
        b:SetScript("OnClick", function() QoL.OpenCopyChat(cf) end)
        copyButtons[i] = b
      end
      if b then b:SetShown(on and true or false) end
    end
  end
end

-- Chat history with the arrow keys (6.0.1, user 31.10.): arrow up / down in the chat box brings back the last
-- 5 sent messages (with their chat type / whisper target). Own list: the game's built-in history did not answer
-- in the Forever client (beta12). The arrow keys only reach the box with SetAltArrowKeyMode(false); while typing
-- they then move the cursor / history instead of the character. Hooks on the chat boxes only, nothing runs idle.
local chatHist, histPos = {}, 0
local function histPush(eb)
  local text = eb.ofaTyped
  eb.ofaTyped = nil
  if not text or not text:find("%S") then return end
  -- no commands (user 06.11., Discord /focus): a recalled "/focus" counts as addon code for the game and is blocked
  -- (ADDON_ACTION_FORBIDDEN FocusUnit) - only messages come back
  if text:find("^%s*/") then return end
  for i = #chatHist, 1, -1 do if chatHist[i].text == text then table.remove(chatHist, i) end end
  table.insert(chatHist, 1, { text = text, type = eb.ofaType, tell = eb.ofaTell, chan = eb.ofaChan })
  chatHist[6] = nil
end
local function histRecall(eb, key)
  if (key ~= "UP" and key ~= "DOWN") or not QoL.Get("chatHistory") or #chatHist == 0 then return end
  histPos = key == "UP" and math.min(histPos + 1, #chatHist) or math.max(histPos - 1, 0)
  local e = chatHist[histPos]
  if e and e.type then
    eb:SetAttribute("chatType", e.type); eb:SetAttribute("tellTarget", e.tell); eb:SetAttribute("channelTarget", e.chan)
    if type(ChatEdit_UpdateHeader) == "function" then pcall(ChatEdit_UpdateHeader, eb) end
  end
  eb:SetText(e and e.text or ""); eb:SetCursorPosition(#(e and e.text or ""))
end
local function chatHistoryBox(eb)
  if type(eb) ~= "table" or not eb.HookScript or not eb.SetAltArrowKeyMode then return end
  if not eb.ofaHist then
    if not QoL.Get("chatHistory") then return end
    eb.ofaHist = true
    local m = eb.GetAltArrowKeyMode and eb:GetAltArrowKeyMode()
    if m == nil then m = true end
    eb.ofaArrow = m
    eb:HookScript("OnTextChanged", function(self, user)
      local t = self:GetText()
      if t and t:find("%S") then
        self.ofaTyped, self.ofaType = t, self:GetAttribute("chatType")
        self.ofaTell, self.ofaChan = self:GetAttribute("tellTarget"), self:GetAttribute("channelTarget")
      elseif user then self.ofaTyped = nil end -- emptied by hand: nothing to remember
    end)
    eb:HookScript("OnEnterPressed", function(self) if QoL.Get("chatHistory") then histPush(self) end; self.ofaTyped = nil; histPos = 0 end)
    eb:HookScript("OnEscapePressed", function(self) self.ofaTyped = nil; histPos = 0 end)
    eb:HookScript("OnEditFocusGained", function(self)
      self.ofaTyped = nil; histPos = 0
      if QoL.Get("chatHistory") then self:SetAltArrowKeyMode(false) end
    end)
    eb:HookScript("OnArrowPressed", histRecall)
  end
  eb:SetAltArrowKeyMode((not QoL.Get("chatHistory")) and eb.ofaArrow or false)
end
local function setupChatHistory()
  for i = 1, (tonumber(NUM_CHAT_WINDOWS) or 10) + 10 do chatHistoryBox(_G["ChatFrame" .. i .. "EditBox"]) end
  -- whisper windows get their own box later: set it up when it opens
  if not QoL._histHook and QoL.Get("chatHistory") and type(ChatEdit_ActivateChat) == "function" then
    QoL._histHook = true
    hooksecurefunc("ChatEdit_ActivateChat", chatHistoryBox)
  end
end
-- /ofa chathistory: what the chat history sees (for bug reports)
function QoL.ChatHistoryInfo()
  local eb = _G.ChatFrame1EditBox
  msg(string.format("Message history: %s, %d saved, box hooked: %s, Alt arrow mode: %s, ActivateChat: %s",
    QoL.Get("chatHistory") and "on" or "off", #chatHist, tostring(eb and eb.ofaHist or false),
    tostring(eb and eb.GetAltArrowKeyMode and eb:GetAltArrowKeyMode()), type(ChatEdit_ActivateChat)))
end

-- ---------------------------------------------------------------------------
-- Bags full helper: when loot does not fit, suggest the cheapest item in the
-- bags (sell value x stack) and destroy it + loot with one click.
-- ---------------------------------------------------------------------------
local bookItems
local function isBookItem(id)
  if not bookItems then
    bookItems = {}
    for _, b in ipairs(FLT.BOOKS or {}) do if b.itemId then bookItems[b.itemId] = true end end
  end
  return bookItems[id]
end
-- profession tools are never suggested
local TOOLS = {
  [6218]=true, [6339]=true, [11130]=true, [11145]=true, [16207]=true, -- runed enchanting rods
  [6217]=true, [6338]=true, [11128]=true, [11144]=true, [16206]=true, -- plain rods
  [2901]=true, [7005]=true, [5956]=true, [6219]=true, [9149]=true, [10498]=true, -- pick, knife, hammer, spanner, stone, micro-adjustor
  [6256]=true, [6365]=true, [6366]=true, [6367]=true, [12225]=true, [19022]=true, [19970]=true, -- fishing poles
  [5060]=true, [6948]=true, -- Thieves' Tools, Hearthstone
}
local function isTool(id, link)
  if TOOLS[id] then return true end
  -- any other fishing pole (weapon class 2, subclass 20) in every language (6.2.0: before by the English name)
  local classID, subID
  pcall(function()
    local get = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
    if get then classID, subID = select(6, get(id or link)) end
  end)
  return classID == 2 and subID == 20
end

local function neverList()
  local d = db(); if not d then return {} end
  d.bagsNever = d.bagsNever or {}
  return d.bagsNever
end
-- the "never suggest" list for the settings: sorted item IDs, remove one, clear all
function QoL.GetNeverItems()
  local out = {}
  for id in pairs(neverList()) do if tonumber(id) then out[#out + 1] = tonumber(id) end end
  table.sort(out)
  return out
end
function QoL.RemoveNever(id)
  neverList()[id] = nil
end
function QoL.ClearNever()
  local d = db(); if d then d.bagsNever = {} end
end
local function itemDetails(link)
  local quality, classID, setID
  pcall(function()
    local info = { (C_Item and C_Item.GetItemInfo or GetItemInfo)(link) }
    quality, classID, setID = info[3], info[12], info[16]
  end)
  if not classID and GetItemInfoInstant then pcall(function() classID = select(6, GetItemInfoInstant(link)) end) end
  return quality, classID, setID
end
local function questInfo(bag, slot)
  if C_Container and C_Container.GetContainerItemQuestInfo then
    local ok, q = pcall(C_Container.GetContainerItemQuestInfo, bag, slot)
    if ok and type(q) == "table" then return q.isQuestItem or q.questID end
  end
  if GetContainerItemQuestInfo then
    local ok, isQuest, questID = pcall(GetContainerItemQuestInfo, bag, slot)
    if ok then return isQuest or questID end
  end
end

-- cheapest item in the normal bags (nil when nothing qualifies)
-- all items that may be suggested, cheapest first
function QoL.FindCandidates()
  local list = {}
  local never = neverList()
  local onlyLow = QoL.Get("bagsLowOnly")
  local famFn = (C_Container and C_Container.GetContainerNumFreeSlots) or GetContainerNumFreeSlots
  for bag = 0, NUM_BAGS do
    local family
    if famFn then family = select(2, famFn(bag)) end -- special bags (herbs, soul shards ...) are skipped
    if family == 0 or family == nil then
      for slot = 1, numSlots(bag) do
        local link, count, quality, noValue, locked, icon = itemInfo(bag, slot)
        local id = link and tonumber(link:match("item:(%d+)"))
        if id and not noValue and not locked and not never[id] and not isBookItem(id) and not isTool(id, link) and not questInfo(bag, slot) then
          local q, classID, setID = itemDetails(link)
          quality = quality or q or 1
          local price = sellPrice(link)
          local skip = price <= 0 or classID == 12 or classID == 9 or (tonumber(setID) or 0) > 0 or quality >= 4
            or (onlyLow and quality > 1)
          if not skip then
            list[#list + 1] = { bag = bag, slot = slot, link = link, id = id, count = count or 1,
              value = price * (count or 1), quality = quality, icon = icon }
          end
        end
      end
    end
  end
  table.sort(list, function(x, y) if x.value ~= y.value then return x.value < y.value end return x.id < y.id end)
  return list
end
function QoL.FindCheapest() return QoL.FindCandidates()[1] end

local function remainingLoot()
  local out = {}
  if not (GetNumLootItems and LootSlotHasItem) then return out end
  for i = 1, GetNumLootItems() or 0 do
    local isItem = (not GetLootSlotType) or GetLootSlotType(i) == (LOOT_SLOT_ITEM or 1)
    if isItem and LootSlotHasItem(i) then
      local link = GetLootSlotLink and GetLootSlotLink(i)
      local icon, name, qty, _, quality, _, isQuest, questID = GetLootSlotInfo(i)
      local value = link and sellPrice(link) * (qty or 1) or 0
      out[#out + 1] = { slot = i, link = link, name = name, qty = qty or 1, icon = icon, quality = quality or 1,
        value = value, quest = (isQuest or questID) and true or false,
        -- quest items and items without a sell price are always worth taking
        prio = ((isQuest or questID) or value <= 0) and true or false }
    end
  end
  return out
end

-- window ---------------------------------------------------------------------
local helper, pendingLoot
local lootSeq = 0 -- counts loot windows opened (the delayed hide on LOOT_CLOSED skips when a new one opened)
local W, CARD_W, CARD_H = 372, 162, 80
local function qcolor(q) local c = QUALITY_RGB[q or 1] or QUALITY_RGB[1]; return c[1], c[2], c[3] end

-- item card: small caption, big icon with quality border, name (2 lines), value
local function itemCard(parent, caption, captionGold)
  local UI = FLT.UI
  local c = CreateFrame("Button", nil, parent); c:SetSize(CARD_W, CARD_H)
  c.card = UI.Card(c, c, 5, {0.28, 0.25, 0.20, 0.9}, {0.05, 0.052, 0.062, 0.97}, "BACKGROUND", 0)
  c.caption = FLT.NewFS(c, nil, "OVERLAY", "GameFontHighlightSmall"); c.caption:SetPoint("TOPLEFT", 8, -7); c.caption:SetText(caption)
  if captionGold then c.caption:SetTextColor(FLT.TextC(1, 0.82, 0.2)) end
  c.iconBorder = c:CreateTexture(nil, "BORDER"); c.iconBorder:SetSize(38, 38); c.iconBorder:SetPoint("TOPLEFT", 8, -26); c.iconBorder:SetColorTexture(1, 1, 1, 1)
  c.icon = c:CreateTexture(nil, "ARTWORK"); c.icon:SetPoint("TOPLEFT", c.iconBorder, 1, -1); c.icon:SetPoint("BOTTOMRIGHT", c.iconBorder, -1, 1)
  c.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  c.count = FLT.NewFS(c, nil, "OVERLAY", "NumberFontNormal"); c.count:SetPoint("BOTTOMRIGHT", c.iconBorder, "BOTTOMRIGHT", -2, 2)
  c.name = FLT.NewFS(c, nil, "OVERLAY", "GameFontHighlightSmall"); c.name:SetPoint("TOPLEFT", c.iconBorder, "TOPRIGHT", 7, -1)
  c.name:SetWidth(CARD_W - 62); c.name:SetJustifyH("LEFT"); c.name:SetJustifyV("TOP"); c.name:SetHeight(26)
  if c.name.SetMaxLines then c.name:SetMaxLines(2) end
  c.value = FLT.NewFS(c, nil, "OVERLAY", "GameFontHighlightSmall"); c.value:SetPoint("BOTTOMLEFT", c.iconBorder, "BOTTOMRIGHT", 7, 1)
  c.msg = FLT.NewFS(c, nil, "OVERLAY", "GameFontHighlightSmall"); c.msg:SetPoint("TOPLEFT", 8, -26); c.msg:SetWidth(CARD_W - 16); c.msg:SetJustifyH("LEFT")
  c:SetScript("OnEnter", function(self)
    if not self.link then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); pcall(GameTooltip.SetHyperlink, GameTooltip, self.link)
    if self.extra then GameTooltip:AddLine(" "); GameTooltip:AddLine(self.extra, 0.6, 0.8, 1) end
    GameTooltip:Show()
  end)
  c:SetScript("OnLeave", function() GameTooltip:Hide() end)
  function c:SetItem(e)
    self.link = e.link
    for _, w in ipairs({ self.iconBorder, self.icon, self.count, self.name, self.value }) do w:Show() end
    self.msg:Hide()
    self.icon:SetTexture(e.icon or (GetItemIcon and e.id and GetItemIcon(e.id)) or "Interface\\Icons\\INV_Misc_QuestionMark")
    local qr, qg, qb = qcolor(e.quality)
    self.iconBorder:SetVertexColor(qr * 0.8, qg * 0.8, qb * 0.8)
    self.name:SetText((e.link and e.link:match("%[(.-)%]")) or e.name or "?"); self.name:SetTextColor(qr, qg, qb)
    local n = e.count or e.qty or 1
    self.count:SetText(n > 1 and n or "")
    self.value:SetText(e.value and e.value > 0 and money(e.value) or "|cff9d9d9d" .. L["no value"] .. "|r")
  end
  function c:SetMessage(text)
    self.link = nil
    for _, w in ipairs({ self.iconBorder, self.icon, self.count, self.name, self.value }) do w:Hide() end
    self.msg:SetText(text); self.msg:Show()
  end
  return c
end

local function helperFrame()
  if helper then return helper end
  local UI = FLT.UI
  local f = CreateFrame("Frame", "OneForAllBagsFull", UIParent)
  f:SetSize(W, 172); f:SetFrameStrata("FULLSCREEN_DIALOG"); f:EnableMouse(true)
  f:SetClampedToScreen(true) -- next to a loot window at the right edge it was cut off (user 06.11. video)
  -- 6.2.10 (Discord scylon77 15.11.): drag it anywhere (the place is kept, qol.bagsFullPos), Esc closes it
  f:SetMovable(true); f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local x, y, d = self:GetLeft(), self:GetTop(), db()
    if x and y and d then d.bagsFullPos = { math.floor(x + 0.5), math.floor(y + 0.5) } end
  end)
  if UISpecialFrames then table.insert(UISpecialFrames, "OneForAllBagsFull") end
  f.left, f.ti, f.cands, f.ci = {}, 1, {}, 1
  UI.FramedPanel(f)
  -- header: alert icon, title, subtitle, close
  local alert = f:CreateTexture(nil, "ARTWORK"); alert:SetSize(36, 36); alert:SetPoint("TOPLEFT", 10, -9)
  alert:SetTexture("Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew")
  local title = FLT.NewFS(f, nil, "OVERLAY", "GameFontNormalLarge"); title:SetPoint("TOPLEFT", 52, -11); title:SetText(L["Bags full!"])
  title:SetTextColor(FLT.TextC(1, 0.82, 0.2))
  f.sub = FLT.NewFS(f, nil, "OVERLAY", "GameFontHighlightSmall"); f.sub:SetPoint("TOPLEFT", 52, -30); f.sub:SetWidth(W - 90); f.sub:SetJustifyH("LEFT")
  local close = UI.GoldButton(f, "", 18, 16, UI.ASSET_ROOT .. "icon_close", 10); close:SetPoint("TOPRIGHT", -8, -8)
  if close.icon then close.icon:ClearAllPoints(); close.icon:SetSize(10, 10); close.icon:SetPoint("CENTER") end
  close:SetScript("OnClick", function() f:Hide(); pendingLoot = nil end)

  -- left: what gets destroyed (with browse + never), right: what you get
  f.out = itemCard(f, L["Destroy:"]); f.out:SetPoint("TOPLEFT", 10, -52)
  f.inc = itemCard(f, L["You get:"], true); f.inc:SetPoint("TOPRIGHT", -10, -52)
  f.arrow = f:CreateTexture(nil, "ARTWORK"); f.arrow:SetSize(20, 20); f.arrow:SetPoint("CENTER", f, "TOP", 0, -52 - CARD_H / 2)
  FLT.SetTex(f.arrow, UI.ASSET_ROOT .. "chevron"); f.arrow:SetTexCoord(0.5, 1, 0, 1)
  f.next = UI.GoldButton(f.out, ">", 16, 14, nil, 10); f.next:SetPoint("TOPRIGHT", -6, -5)
  f.counter = FLT.NewFS(f.out, nil, "OVERLAY", "GameFontDisableSmall"); f.counter:SetPoint("RIGHT", f.next, "LEFT", -3, 0)
  f.prev = UI.GoldButton(f.out, "<", 16, 14, nil, 10); f.prev:SetPoint("RIGHT", f.counter, "LEFT", -3, 0)
  f.never = UI.GoldButton(f.out, "", 18, 18, "Interface\\Buttons\\UI-GroupLoot-Pass-Up", 10); f.never:SetPoint("BOTTOMRIGHT", -6, 6)
  if f.never.icon then f.never.icon:ClearAllPoints(); f.never.icon:SetSize(12, 12); f.never.icon:SetPoint("CENTER") end
  f.never:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText(L["Never suggest this item"]); GameTooltip:AddLine(L["It will not be suggested again (any character)."], 1, 1, 1, true); GameTooltip:Show() end)
  f.never:SetScript("OnLeave", function() GameTooltip:Hide() end)
  f.destroy = UI.GoldButton(f, L["Destroy & loot"], 160, 24, nil, 12); f.destroy:SetPoint("BOTTOM", 0, 12)

  f.prev:SetScript("OnClick", function() if #f.cands > 0 then f.ci = (f.ci - 2) % #f.cands + 1; f:Paint() end end)
  f.next:SetScript("OnClick", function() if #f.cands > 0 then f.ci = f.ci % #f.cands + 1; f:Paint() end end)
  f.inc:SetScript("OnClick", function() if #f.left > 1 then f.ti = f.ti % #f.left + 1; f:Paint() end end)
  f.never:SetScript("OnClick", function()
    local b = f.cands[f.ci]; if not b then return end
    neverList()[b.id] = true
    msg(string.format(L["%s will not be suggested any more."], b.link))
    QoL.CheckBagsFull(true)
  end)
  f.destroy:SetScript("OnClick", function()
    local b, l = f.cands[f.ci], f.left[f.ti]
    if not b or (not l and not f.noLoot) then return end
    -- also in combat (Discord 05.11.: the game allows destroying items in combat; the old block only got in the way)
    local link = itemInfo(b.bag, b.slot)
    if link ~= b.link then QoL.CheckBagsFull(true); return end
    -- anything better than grey needs a second click
    if (b.quality or 1) >= 1 and not f.armed then
      f.armed = true; f.destroy:SetLabel(L["Click again to destroy"]); return
    end
    ClearCursor()
    local pick = (C_Container and C_Container.PickupContainerItem) or PickupContainerItem
    pick(b.bag, b.slot)
    pendingLoot = l and l.slot or nil
    DeleteCursorItem()
    if f.noLoot then msg(L["Made room - loot it again."]) end
    f:Hide()
  end)

  function f:Paint()
    self.armed = false
    local b, target = self.cands[self.ci], self.left[self.ti]
    -- right card
    if target then
      self.inc:SetItem(target)
      self.inc.extra = #self.left > 1 and string.format(L["%d items left - click for the next one"], #self.left) or nil
      self.inc.caption:SetText(#self.left > 1 and string.format(L["You get (%d/%d):"], self.ti, #self.left) or L["You get:"])
    else
      self.inc:SetMessage(L["Loot it again after making room."])
      self.inc.caption:SetText(L["You get:"])
    end
    -- left card + button
    -- not worth it either when the loot is worth exactly as much (6.2.13-beta16, user 21.11.: "1c gegen 1c .. sowas sollte doch
    -- eigentlich nicht vorgeschlagen werden")
    local notWorth = b and target and not target.prio and target.value <= b.value
    local showBrowse = b and not notWorth
    for _, w in ipairs({ self.prev, self.next, self.counter, self.never }) do w:SetShown(showBrowse and true or false) end
    if notWorth then
      self.sub:SetText(L["This loot is not worth more than anything in your bags."])
      self.out:SetMessage("|cffffd27f" .. L["Not worth picking up."] .. "|r\n" .. L["Everything in your bags is worth as much or more."])
      self.destroy:Hide()
    elseif b then
      self.sub:SetText(self.noLoot and L["Destroy a low-value item, then loot again."] or L["Destroy a low-value item to loot."])
      self.out:SetItem(b); self.out.extra = nil
      self.counter:SetText(self.ci .. "/" .. #self.cands)
      local many = #self.cands > 1
      self.prev:SetLook(many); self.prev:SetEnabled(many); self.next:SetLook(many); self.next:SetEnabled(many)
      self.destroy:SetLabel(self.noLoot and L["Destroy"] or L["Destroy & loot"]); self.destroy:Show()
    else
      self.sub:SetText(L["Nothing in your bags can be suggested."])
      self.out:SetMessage(L["Quest items, books, recipes, tools and set pieces are kept."])
      self.destroy:Hide()
    end
    self:SetHeight(self.destroy:IsShown() and 172 or 142)
  end

  f:Hide()
  helper = f
  return f
end

function QoL.CheckBagsFull(force, fromError)
  if not QoL.Get("bagsFull") and not force then return end
  local left = remainingLoot()
  local f = helperFrame()
  if (QoL.FreeBagSlots() or 0) > 0 then f:Hide(); return end
  -- no loot window (e.g. a quest object or herb that could not be looted):
  -- only make room; loot it again afterwards
  if #left == 0 then
    if not fromError and not (f:IsShown() and f.noLoot) then f:Hide(); return end
    f.noLoot = true
  else
    f.noLoot = false
  end
  -- keep the chosen loot row if it is still there, else the most valuable
  local ti = 1
  local function better(a, b)
    if a.prio ~= b.prio then return a.prio end
    return a.value > b.value
  end
  for i, l in ipairs(left) do if better(l, left[ti]) then ti = i end end
  if f:IsShown() and f.left and f.left[f.ti] then
    for i, l in ipairs(left) do if l.slot == f.left[f.ti].slot then ti = i end end
  end
  f.left, f.ti = left, ti
  -- keep the item browsed to while it is still in the same place (CurseForge comment 06.11.: every re-show went back to 1/N)
  local keep = f.cands and f.cands[f.ci]
  f.cands, f.ci = QoL.FindCandidates(), 1
  if keep then
    for i, c in ipairs(f.cands) do if c.bag == keep.bag and c.slot == keep.slot and c.link == keep.link then f.ci = i; break end end
  end
  f:Paint()
  -- placed when it opens or its anchor changes (saved place / at the loot window / centre), not again on every check
  -- (6.2.13-beta23, Discord emzime: it was moved on every round of the loot loop, ~35 times a second)
  local pos = db() and db().bagsFullPos
  local at = (type(pos) == "table" and pos[1] and "saved") or (type(LootFrame) == "table" and LootFrame:IsShown() and "loot") or "center"
  if not f:IsShown() or f.placedAt ~= at then
    f:ClearAllPoints()
    if at == "saved" then f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", pos[1], pos[2])
    elseif at == "loot" then f:SetPoint("TOPLEFT", LootFrame, "TOPRIGHT", 6, 0)
    else f:SetPoint("CENTER", UIParent, "CENTER", 0, 120) end
    f.placedAt = at
  end
  f:Show()
end
-- one waiting check at a time (6.2.13-beta23, Discord emzime): every "Inventory is full" and every reopened loot window started
-- a timer of its own, each scanning all bags. QoL._bfPending / QoL._bfError: fields (this file is at the 200-locals limit)
function QoL.ScheduleBagsFull(delay, fromError)
  if fromError then QoL._bfError = true end
  if not (C_Timer and C_Timer.After) then QoL.CheckBagsFull(false, fromError); return end
  if QoL._bfPending then return end
  QoL._bfPending = true
  C_Timer.After(delay or 0.1, function()
    local e = QoL._bfError
    QoL._bfPending, QoL._bfError = nil, nil
    QoL.CheckBagsFull(false, e)
  end)
end

function QoL.PrintCheapest()
  local b = QoL.FindCheapest()
  if b then msg(L["Cheapest item:"] .. " " .. (b.count > 1 and (b.count .. "x ") or "") .. b.link .. " (" .. money(b.value) .. ")")
  else msg(L["Nothing in your bags can be suggested."]) end
end

local function bagsChanged()
  if not pendingLoot then return end
  local slot = pendingLoot
  pendingLoot = nil
  if GetNumLootItems and (GetNumLootItems() or 0) >= slot and LootSlotHasItem(slot) then
    pcall(LootSlot, slot)
    QoL.ScheduleBagsFull(0.4)
  end
end

local function lootError(_, message)
  if not QoL.Get("bagsFull") then return end
  if message == ERR_INV_FULL or message == ERR_LOOT_NO_SPACE or message == "Inventory is full." then
    -- a Soul Shard from Drain Soul with full bags (6.2.10, Discord elipz 15.11.): no helper - only loot counts then
    if QoL._drainAt and GetTime() - QoL._drainAt < 16 and not (GetNumLootItems and (GetNumLootItems() or 0) > 0) then return end
    QoL.ScheduleBagsFull(0.1, true)
  end
end

-- ---------------------------------------------------------------------------
-- Hide error messages (6.0.1, CurseForge comment 29.10.): the red messages in the middle of the screen ("Out of
-- range", "Not enough rage" ...). The game's error frame stops listening to UI_ERROR_MESSAGE; the few messages worth
-- seeing are shown again from our own handler. Our own messages (AddMessage) are not affected.
-- ---------------------------------------------------------------------------
local KEEP_ERRORS -- built on first use (the global strings exist then)
local function keepError(message)
  if not KEEP_ERRORS then
    KEEP_ERRORS = {}
    for _, k in ipairs({ "ERR_INV_FULL", "ERR_BAG_FULL", "ERR_LOOT_NO_SPACE", "ERR_QUEST_LOG_FULL", "ERR_ITEM_MAX_COUNT",
      "ERR_NOT_ENOUGH_MONEY" }) do
      local v = _G[k]; if type(v) == "string" then KEEP_ERRORS[v] = true end
    end
    KEEP_ERRORS["Inventory is full."] = true
  end
  return KEEP_ERRORS[message]
end
local function applyHideErrors(on)
  if type(UIErrorsFrame) ~= "table" or not UIErrorsFrame.UnregisterEvent then return end
  -- another addon or the game may register the event again (Discord punchline5958 16.11.: "There is nothing to attack."
  -- still shown): undo that while the option is on (hook set once, only when the option is used)
  if on and not QoL._errHook and hooksecurefunc then
    QoL._errHook = true
    hooksecurefunc(UIErrorsFrame, "RegisterEvent", function(f, e)
      if e == "UI_ERROR_MESSAGE" and QoL.Get("hideErrors") and not QoL._errOff then f:UnregisterEvent(e) end
    end)
  end
  QoL._errOff = not on -- our own RegisterEvent below must not be undone
  if on then UIErrorsFrame:UnregisterEvent("UI_ERROR_MESSAGE") else UIErrorsFrame:RegisterEvent("UI_ERROR_MESSAGE") end
end
local function errorMessage(a1, a2)
  local message = type(a1) == "string" and a1 or a2 -- (errorType, message) on newer clients, (message) on old ones
  lootError(nil, message)
  if QoL.Get("hideErrors") and type(message) == "string" and keepError(message) and type(UIErrorsFrame) == "table" then
    UIErrorsFrame:AddMessage(message, 1, 0.1, 0.1)
  end
end

-- ---------------------------------------------------------------------------
-- Quest loot sparkles: the game's loot glow on quest items (game settings)
-- ---------------------------------------------------------------------------
-- Only the loot glow setting (6.2.1, user 08.11. tested: quest items sparkle also with the outline on, Self Highlight
-- stays). Up to 6.2.0 the four outline settings went off too - that took the player outline away (Discord
-- [d:1568607243702640721]); those players get their saved outline values back once (outlineBack).
local SPK = { cvars = { outlineModeShowLootEffectWhenDisabled = "1" },
  outline = { "graphicsOutlineMode", "OutlineEngineMode", "raidGraphicsOutlineMode", "RAIDOutlineEngineMode" },
  -- graphics presets set the glow back: only these and our own setting are watched
  watch = { graphicsquality = true, raidgraphicsquality = true, outlinemodeshowlooteffectwhendisabled = true },
  pending = false, setting = false, timer = false }
function SPK.outlineBack(d)
  local o = d.sparkleOrig
  if not o then return end
  for _, k in ipairs(SPK.outline) do
    -- only while it is still our "0": a value the player chose since then stays
    if o[k] ~= nil and o[k] ~= "0" and GetCVar(k) == "0" then pcall(SetCVar, k, o[k]) end
    o[k] = nil
  end
end
local function applySparkles()
  if not QoL.Get("questSparkles") or not SetCVar or not GetCVar then return end
  if inCombat() then SPK.pending = true; return end
  SPK.pending = false
  local d = db(); if not d then return end
  d.sparkleOrig = d.sparkleOrig or {}
  SPK.setting = true
  SPK.outlineBack(d)
  for k, v in pairs(SPK.cvars) do
    local cur = GetCVar(k)
    if cur ~= nil then
      if d.sparkleOrig[k] == nil then d.sparkleOrig[k] = cur end
      if cur ~= v then pcall(SetCVar, k, v) end
    end
  end
  SPK.setting = false
end
local function sparkleSwitch(on)
  if on then applySparkles(); return end
  local d = db(); if not d then return end
  if not d.sparkleOrig and GetCVar and GetCVar("outlineModeShowLootEffectWhenDisabled") ~= "1" then return end -- already off
  if inCombat() then msg(L["This can be changed after combat."]); return end
  d.sparkleOrig = d.sparkleOrig or {}
  SPK.outlineBack(d)
  d.sparkleOrig = nil
  -- back to the game's default "0", not to a saved value (6.2.10, Discord locksmite 16.11.: NPCs kept glowing - a saved
  -- "1" from earlier versions came back; players needed /console outlineModeShowLootEffectWhenDisabled 0)
  for k in pairs(SPK.cvars) do pcall(SetCVar, k, "0") end
  msg(L["Quest loot sparkles switched off. Restart the game for it to take full effect."])
end
local function cvarChanged(name)
  if SPK.setting or SPK.timer or type(name) ~= "string" or not SPK.watch[name:lower()] then return end
  if not QoL.Get("questSparkles") then return end
  if not (C_Timer and C_Timer.After) then applySparkles(); return end
  SPK.timer = true -- one check for a whole preset change
  C_Timer.After(1, function() SPK.timer = false; applySparkles() end)
end

-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------
local ev = CreateFrame("Frame")

local EVENTS = {
  "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_LOGOUT", "ADDON_LOADED",
  "LOOT_READY", "LOOT_OPENED", "MERCHANT_SHOW",
  "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE", "QUEST_GREETING", "GOSSIP_SHOW", "QUEST_ACCEPT_CONFIRM",
  "PARTY_INVITE_REQUEST", "CHAT_MSG_WHISPER", "DUEL_REQUESTED",
  "UPDATE_INVENTORY_DURABILITY", "BAG_UPDATE_DELAYED", "QUEST_LOG_UPDATE", "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "QUEST_WATCH_LIST_CHANGED",
  "PLAYER_TARGET_CHANGED", "GROUP_ROSTER_UPDATE", "CHAT_MSG_LOOT", "CHAT_MSG_MONEY", "PLAYER_MONEY", "UI_ERROR_MESSAGE", "LOOT_CLOSED", "CVAR_UPDATE", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "ZONE_CHANGED_NEW_AREA",
}
for _, e in ipairs(EVENTS) do pcall(ev.RegisterEvent, ev, e) end
if ev.RegisterUnitEvent then pcall(ev.RegisterUnitEvent, ev, "UNIT_AURA", "player") else pcall(ev.RegisterEvent, ev, "UNIT_AURA") end
pcall(ev.RegisterEvent, ev, "MINIMAP_UPDATE_TRACKING") -- Find Herbs / Minerals in the buff reminder (6.2.2)
-- buff reminder: weapon enchants are no aura (user 05.11.: Flametongue clicked off gave no card until another buff
-- changed) - the weapon enchant / inventory events check too (debounced)
pcall(ev.RegisterEvent, ev, "WEAPON_ENCHANT_CHANGED")
if ev.RegisterUnitEvent then pcall(ev.RegisterUnitEvent, ev, "UNIT_INVENTORY_CHANGED", "player") end
-- buff reminder: a watched buff cast again in combat (6.0.3)
if ev.RegisterUnitEvent then pcall(ev.RegisterUnitEvent, ev, "UNIT_SPELLCAST_SUCCEEDED", "player") end

local function onEventSafe(_, event, ...)
  -- chat texts can be "secret" in combat on newer clients: nothing to read then
  if (event:find("^CHAT_MSG") or event == "UI_ERROR_MESSAGE") and FLT.IsSecret(...) then return end
  if event == "PLAYER_LOGIN" then
    junkChanged()
    migrate()
    setupClassColors(); setupTooltips(); setupMovable(); setupCopyButtons(); setupChatHistory()
    if QoL.Get("cameraZoom") then applyCamera(true) end
    if QoL.Get("hideErrors") then applyHideErrors(true) end
    if QoL.Get("questSparkles") then applySparkles() end
    QoL.SnapshotRecipes()
    lastMoney = GetMoney and GetMoney() or 0
    if C_Timer and C_Timer.After then
      C_Timer.After(2, function() applyChatFont(QoL.Get("chatFont")); updateBagSlots(); updateXP(); checkDurability() end)
    end
  elseif event == "PLAYER_ENTERING_WORLD" then
    thanksSettle()
    if QoL.Get("hideErrors") then applyHideErrors(true) end
    if QoL.Get("buffReminder") then C_Timer.After(2, checkBuffs) end
    updateBagSlots(); checkDurability()
  elseif event == "PLAYER_LOGOUT" then
    QoL.SnapshotRecipes()
  elseif event == "ADDON_LOADED" then
    -- a moment later (6.2.10): a window addon can load inside a protected action of the game (Inspect from the player
    -- menu loads Blizzard_InspectUI) - touching its window right there taints that action
    if C_Timer and C_Timer.After then C_Timer.After(0, setupMovable) else setupMovable() end
  elseif event == "LOOT_READY" or event == "LOOT_OPENED" then
    lootSeq = lootSeq + 1
    quickLoot()
    -- the helper still shown from the last loot (a right-click on the open corpse reopens it): checked again at once,
    -- so it stays, sits at the new loot window and shows the loot (user 06.11. video: it blinked, and an early
    -- "Inventory is full" had switched it to "loot again" while the loot was open)
    if event == "LOOT_OPENED" and helper and helper:IsShown() then QoL.ScheduleBagsFull(0.05) end
  elseif event == "MERCHANT_SHOW" then
    autoRepair(); sellJunk()
  elseif event == "QUEST_DETAIL" then questDetail()
  elseif event == "QUEST_PROGRESS" then questProgress()
  elseif event == "QUEST_COMPLETE" then questComplete()
  elseif event == "QUEST_GREETING" then questGreeting()
  elseif event == "GOSSIP_SHOW" then gossipShow()
  elseif event == "QUEST_ACCEPT_CONFIRM" then
    if QoL.Get("autoAccept") and not paused() and ConfirmAcceptQuest then ConfirmAcceptQuest(); if StaticPopup_Hide then StaticPopup_Hide("QUEST_ACCEPT") end end
  elseif event == "PARTY_INVITE_REQUEST" then partyInvite(...)
  elseif event == "CHAT_MSG_WHISPER" then whisper(...)
  elseif event == "DUEL_REQUESTED" then duelRequested(...)
  elseif event == "UNIT_AURA" then playerAura(...); if (...) == "player" then buffAura() end
  elseif event == "MINIMAP_UPDATE_TRACKING" then buffAura()
  elseif event == "WEAPON_ENCHANT_CHANGED" or event == "UNIT_INVENTORY_CHANGED" then buffAura(true)
  elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
    local id = select(3, ...)
    QoL.BuffCast(id)
    -- Drain Soul started (its name: all ranks, any client language); the bags full helper skips its Soul Shard
    if QoL._drainName == nil and GetSpellInfo then QoL._drainName = GetSpellInfo(1120) or false end
    if QoL._drainName and id and GetSpellInfo and GetSpellInfo(id) == QoL._drainName then QoL._drainAt = GetTime() end
  elseif event == "UI_ERROR_MESSAGE" then errorMessage(...)
  elseif event == "LOOT_CLOSED" then
    pendingLoot = nil; QoL._quickLootAt = nil
    -- 6.1.6 (CurseForge comment 06.11.): a right-click on an open corpse closes and reopens the loot, and the "Inventory
    -- is full" error showed the helper again - it blinked. Hidden a moment later, and not when the loot is open again
    -- (user 06.11. video: 0.3 s was too short - the server reopens the loot later; now 1.5 s and only when no loot
    -- window opened in between)
    if helper and not helper.noLoot then
      if C_Timer and C_Timer.After then
        local seq = lootSeq
        C_Timer.After(1.5, function()
          local open = (GetNumLootItems and (GetNumLootItems() or 0) > 0) or (type(LootFrame) == "table" and LootFrame:IsShown())
          if helper and not helper.noLoot and not open and seq == lootSeq then helper:Hide() end
        end)
      else helper:Hide() end
    end
  elseif event == "CVAR_UPDATE" then cvarChanged(...)
  elseif event == "PLAYER_REGEN_ENABLED" then if QoL._waiting then QoL.ApplyWaiting() end
    if SPK.pending then applySparkles() end; if QoL.Get("buffReminder") then checkBuffs() end
    if movablePending then local l = movablePending; movablePending = nil; for name in pairs(l) do makeMovable(name) end end
  elseif event == "PLAYER_REGEN_DISABLED" then QoL.BuffCombatStart()
  elseif event == "ZONE_CHANGED_NEW_AREA" then if QoL.Get("buffReminder") and QoL.Get("buffSleepCities") then checkBuffs() end
  elseif event == "CHAT_MSG_LOOT" then lootMessage(...)
  elseif event == "CHAT_MSG_MONEY" then moneyMessage()
  elseif event == "PLAYER_MONEY" then moneyChanged()
  elseif event == "UPDATE_INVENTORY_DURABILITY" then checkDurability()
  elseif event == "BAG_UPDATE_DELAYED" then updateBagSlots(); bagsChanged()
  elseif event == "QUEST_LOG_UPDATE" or event == "PLAYER_XP_UPDATE" or event == "PLAYER_LEVEL_UP" or event == "QUEST_WATCH_LIST_CHANGED" then
    -- QUEST_LOG_UPDATE fires very often; read the quest log at most twice a second
    if QoL.Get("questXP") and not xpPending then
      xpPending = true
      if C_Timer and C_Timer.After then C_Timer.After(0.5, function() xpPending = false; updateXP() end) else xpPending = false; updateXP() end
    elseif not QoL.Get("questXP") then updateXP() end
  elseif event == "PLAYER_TARGET_CHANGED" or event == "GROUP_ROSTER_UPDATE" then refreshClassColors()
  end
end
ev:SetScript("OnEvent", function(...) FLT.SafeCall("QoL", onEventSafe, ...) end)

-- live reaction to switches in the tab
on("cameraZoom", applyCamera)
on("hideErrors", applyHideErrors)
on("chatFont", applyChatFont)
on("questSparkles", sparkleSwitch)
on("copyChat", setupCopyButtons)
on("chatHistory", setupChatHistory)
on("buffReminder", function() checkBuffs() end)
on("buffSleepCities", function() checkBuffs() end)
on("buffScale", function() QoL.BuffLayout() end)
on("buffIconOnly", function() QoL.BuffLayout() end)
on("buffFlash", function() checkBuffs() end)
on("buffSnoozeBtn", function() checkBuffs() end) -- shown / hidden at once (user 05.11.)
on("moveWindows", setupMovable)
on("resizeWindows", function(v)
  setupMovable()
  -- switched off: back to the normal size (the remembered sizes stay for when it is switched on again)
  for name, sc in pairs(scales()) do
    local f = _G[name]
    if type(f) == "table" and f.ofaMovable and f:IsShown() and not (inCombat() and f:IsProtected()) then f:SetScale(v and sc or 1) end
  end
end)
on("bagSlots", updateBagSlots)
on("quiverAmmo", QoL._bagBarRedraw)
on("questXP", updateXP)
on("questXPTracked", updateXP)
on("classColors", refreshClassColors)
on("classBright", refreshClassColors)
on("mapFog", function() if FLT.RefreshMapFog then FLT.RefreshMapFog() end end)
on("mapFogAlpha", function() if FLT.RefreshMapFog then FLT.RefreshMapFog() end end)
on("durability", function() warnedDurability = false; checkDurability() end)

-- the junk click (default Alt + right-click, "Junk list key") on an item in the bags: on / off the junk list (only while
-- "Sell junk" is on). Bag buttons (and bag addons) pass modified clicks to HandleModifiedItemClick; a click with a modifier
-- does not use the item. The modifiers must match exactly (Ctrl + Alt + right-click is not Alt + right-click).
if type(HandleModifiedItemClick) == "function" then
  hooksecurefunc("HandleModifiedItemClick", function(link)
    if not QoL.Get("sellJunk") then return end
    local want = QoL.JUNK_KEYS[QoL.Get("junkKey")] or QoL.JUNK_KEYS["alt-right"]
    local function down(fn) return fn and fn() and true or false end
    if down(IsAltKeyDown) ~= (want.alt or false) or down(IsControlKeyDown) ~= (want.ctrl or false)
      or down(IsShiftKeyDown) ~= (want.shift or false) then return end
    if not (GetMouseButtonClicked and GetMouseButtonClicked() == want.b) then return end
    local id = type(link) == "string" and tonumber(link:match("item:(%d+)"))
    local count = id and ((C_Item and C_Item.GetItemCount and C_Item.GetItemCount(id)) or (GetItemCount and GetItemCount(id))) or 0
    if (count or 0) > 0 then QoL.ToggleJunk(link) end -- items in your bags only
  end)
end

-- the game's bags: a coin in the corner of items on the junk list
do
  local getID = (C_Container and C_Container.GetContainerItemID) or GetContainerItemID
  local coins = {} -- [button] = texture
  local function coin(b)
    local t = coins[b]
    if not t then
      t = b:CreateTexture(nil, "OVERLAY", nil, 2); t:SetSize(14, 14); t:SetPoint("TOPLEFT", 2, -2)
      if not (t.SetAtlas and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("bags-junkcoin") and t:SetAtlas("bags-junkcoin") ~= false)
      then t:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon") end
      coins[b] = t
    end
    return t
  end
  local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
  local function isJunk(id, list)
    if list[id] then return true end
    local _, _, q, _, _, _, _, _, _, _, price = getInfo(id)
    return q == 0 and (price or 0) > 0
  end
  local function paintButton(b, bag, on, list)
    local id = on and bag and getID(bag, b:GetID())
    if id and isJunk(id, list) then coin(b):Show() elseif coins[b] then coins[b]:Hide() end
  end
  -- the coin on grey items and items of the list, while "Sell junk" is on (the game's own coin only shows at a merchant)
  local function paint(frame)
    if type(frame) ~= "table" or not getID then return end
    local on = QoL.Get("sellJunk") and true or false
    if not on and not next(coins) then return end
    local list = junkList()
    if frame.EnumerateValidItems then -- newer bag frames (also the Combined Backpack)
      for _, b in frame:EnumerateValidItems() do
        paintButton(b, b.GetBagID and b:GetBagID() or (b:GetParent() and b:GetParent():GetID()), on, list)
      end
      return
    end
    local name = frame.GetName and frame:GetName()
    if not name then return end
    for i = 1, frame.size or 0 do
      local b = _G[name .. "Item" .. i]
      if type(b) == "table" then paintButton(b, frame:GetID(), on, list) end
    end
  end
  markBags = function()
    for i = 1, tonumber(NUM_CONTAINER_FRAMES) or 13 do
      local f = _G["ContainerFrame" .. i]
      if type(f) == "table" and f.IsShown and f:IsShown() then paint(f) end
    end
    if type(ContainerFrameCombinedBags) == "table" and ContainerFrameCombinedBags:IsShown() then paint(ContainerFrameCombinedBags) end
  end
  if type(ContainerFrame_Update) == "function" then hooksecurefunc("ContainerFrame_Update", paint) end
  -- newer clients: every bag frame (and the Combined Backpack) redraws its items in UpdateItems
  local function hookFrame(f) if type(f) == "table" and type(f.UpdateItems) == "function" then hooksecurefunc(f, "UpdateItems", paint) end end
  hookFrame(ContainerFrameCombinedBags)
  for i = 1, tonumber(NUM_CONTAINER_FRAMES) or 13 do hookFrame(_G["ContainerFrame" .. i]) end
end
on("sellJunk", junkChanged)

-- test hooks
QoL._allowed, QoL._addItemLines, QoL._ev, QoL._sellJunk = allowed, addItemLines, ev, sellJunk
QoL._helperFrame = helperFrame
