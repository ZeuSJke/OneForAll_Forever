-- Item API: newer clients only have these under C_Item.
local GetItemInfo = GetItemInfo or (C_Item and C_Item.GetItemInfo)
local ADDON, FLT = ...
local L = FLT.L or setmetatable({}, { __index = function(_, k) return k end }) -- (tests without Locales)

local function msg(text)
  DEFAULT_CHAT_FRAME:AddMessage("|cff66ccff" .. tostring(FLT.DISPLAY_NAME or "OneForAll") .. ":|r " .. tostring(text))
end
FLT.Msg = msg

-- The English profession key (our data and saved data use it) for a profession name in the client's language (6.2.0:
-- "Schneiderei" -> "Tailoring"; the trainer and the old skill list give the name only). From the profession spells,
-- whose names the client knows in its language.
local PROF_SPELLS = { Alchemy = 2259, Blacksmithing = 2018, Enchanting = 7411, Engineering = 4036, Leatherworking = 2108,
  Tailoring = 3908, Cooking = 2550, ["First Aid"] = 3273, Mining = 2575, Herbalism = 2366, Skinning = 8613, Fishing = 7620 }
FLT.PROF_SPELLS = PROF_SPELLS
local profByName
function FLT.ProfKey(name)
  if type(name) ~= "string" then return nil end
  if PROF_SPELLS[name] then return name end
  if not profByName then
    local t, all = {}, true
    for key, id in pairs(PROF_SPELLS) do
      local n
      pcall(function() n = (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)) or (GetSpellInfo and GetSpellInfo(id)) end)
      if type(n) == "string" then t[n] = key else all = false end
    end
    if not all then return t[name] end -- spell data not ready yet: try again next time
    profByName = t
  end
  return profByName[name]
end
-- true once the client knows every profession spell's name (ProfKey can map all of them; early after login it can't)
function FLT.ProfKeyReady() if not profByName then FLT.ProfKey("") end; return profByName ~= nil end

-- Safe calls for event handlers: an error is caught instead of popping up again and
-- again (e.g. in combat, when the Forever client hands out "secret" values). The
-- last errors are kept in OneForAllDB.errors; /ofa errors prints them so
-- players can copy them into a bug report.
local errorSaid = false
local function logError(tag, err)
  local db = type(OneForAllDB) == "table" and OneForAllDB
  if db then
    db.errors = db.errors or {}
    local ver = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version")) or (GetAddOnMetadata and GetAddOnMetadata(ADDON, "Version")) or "?"
    local line = string.format("%s | %s | %s | %s | %s", date and date("%Y-%m-%d %H:%M") or "", tostring(ver), GetLocale and GetLocale() or "?", tostring(tag), tostring(err))
    if db.errors[1] ~= line then table.insert(db.errors, 1, line) end
    while #db.errors > 20 do table.remove(db.errors) end
  end
  if not errorSaid then
    errorSaid = true
    msg(L["An error was caught and the feature skipped. Type /ofa errors to see it (for a bug report)."])
  end
end
function FLT.SafeCall(tag, fn, ...)
  local ok, err = pcall(fn, ...)
  if not ok then logError(tag, err) end
  return ok
end
-- true when any of the values is a "secret" (newer clients hide some values in combat)
function FLT.IsSecret(...)
  if not issecretvalue then return false end
  for i = 1, select("#", ...) do if issecretvalue((select(i, ...))) then return true end end
  return false
end
-- a text the game handed us, only when we may read it: a plain string, else nil (6.2.18-beta2, user 26.11.2026: check every place
-- that reads names, tooltip text, chat lines, GUIDs - "secret" values cannot be searched, compared or cut and raise errors)
function FLT.Str(v)
  if type(v) ~= "string" or (issecretvalue and issecretvalue(v)) then return nil end
  return v
end

-- [charkey] (tools/tests/charkey.lua loads this block)
-- Account-wide data per character (gold of the info bar, recipes and stock of the alts). 6.2.5 (user 11.11.2026): on WoW
-- Forever characters share a first name (surnames: "Smörgi Rogue", "Smörgi Hunt"; UnitName gives "Smörgi" only), so the
-- old key "Name-Realm" made all of them one character -> the key is the GUID, name / realm / class are stored in the
-- entry. Old entries ("Name-Realm", info bar "Realm|Name") are still read; a character drops its old one when it saves.
local function oldKey()
  local n = UnitName and UnitName("player")
  return n and (n .. "-" .. (GetRealmName and GetRealmName() or "")) or nil
end
function FLT.CharKey() return (UnitGUID and UnitGUID("player")) or oldKey() end
function FLT.IsMyChar(key) return key == FLT.CharKey() or key == oldKey() end
-- name, realm, class token of an entry
function FLT.CharOf(key, d)
  local t = type(d) == "table"
  if t and d.name then return d.name, d.realm, d.class or d[2] end
  local r, n = tostring(key):match("^(.-)|(.*)$")
  if not r then n, r = tostring(key):match("^(.-)%-(.*)$") end
  return n or key, r, t and (d.class or d[2]) or nil
end
-- save this character's entry d in tbl (stamps name, realm, class; removes its old key)
function FLT.CharSave(tbl, d, legacy)
  local key = FLT.CharKey(); if not key then return end
  local _, cls = UnitClass("player")
  d.name, d.realm, d.class = UnitName("player"), GetRealmName and GetRealmName() or "", cls
  if type(OneForAllCharDB) == "table" and OneForAllCharDB.fullName then d.full = OneForAllCharDB.fullName end -- with surname
  tbl[key] = d
  local old = legacy or oldKey()
  if old and old ~= key then tbl[old] = nil end
end
-- the name to show; with the class when another of my characters (or this one) has the same name
function FLT.CharLabel(tbl, key, d)
  local name, _, cls = FLT.CharOf(key, d)
  local dup = name == (UnitName and UnitName("player"))
  if not dup then
    for k, o in pairs(tbl) do if k ~= key and FLT.CharOf(k, o) == name then dup = true; break end end
  end
  if dup and type(d) == "table" and d.full and d.full ~= name then return d.full end -- "Smörgi Banklshofer"
  local cn = dup and cls and LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[cls]
  return cn and (name .. " (" .. cn .. ")") or name
end
-- [/charkey]

local function numSlots(bag)
  if C_Container and C_Container.GetContainerNumSlots then return C_Container.GetContainerNumSlots(bag) or 0 end
  if GetContainerNumSlots then return GetContainerNumSlots(bag) or 0 end
  return 0
end

local function itemID(bag, slot)
  if C_Container and C_Container.GetContainerItemID then return C_Container.GetContainerItemID(bag, slot) end
  if GetContainerItemID then return GetContainerItemID(bag, slot) end
  local link = GetContainerItemLink and GetContainerItemLink(bag, slot)
  if link then return tonumber(link:match("item:(%d+)")) end
end

function FLT:IsQuestDone(qid)
  if not qid then return false end
  if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then return C_QuestLog.IsQuestFlaggedCompleted(qid) and true or false end
  if IsQuestFlaggedCompleted then return IsQuestFlaggedCompleted(qid) and true or false end
  return false
end

function FLT:FindBookByQuestID(qid)
  qid = tonumber(qid)
  if not qid then return nil end
  for _, book in ipairs(self.BOOKS) do
    if book.questId == qid then return book end
  end
end

function FLT:RecordObservedTurnIn(qid)
  local book = self:FindBookByQuestID(qid)
  if not book then return end
  OneForAllCharDB.confirmedDone[book.itemId] = true
  msg(string.format(L["Confirmed turn-in: %s (quest %d)."], FLT.ItemName and FLT.ItemName(book.itemId, book.name) or book.name, book.questId))
end

function FLT:ScanBags()
  -- reuse the table: bag updates come often
  self.bagItems = self.bagItems or {}
  for k in pairs(self.bagItems) do self.bagItems[k] = nil end
  for bag = 0, 4 do
    for slot = 1, numSlots(bag) do
      local id = itemID(bag, slot)
      if id then self.bagItems[id] = true end
    end
  end
end

function FLT:ScanBank()
  self.bankItems = self.bankItems or {}
  wipe(self.bankItems)
  local bags = {-1, 5, 6, 7, 8, 9, 10, 11}
  for _, bag in ipairs(bags) do
    for slot = 1, numSlots(bag) do
      local id = itemID(bag, slot)
      if id then self.bankItems[id] = true end
    end
  end
  OneForAllCharDB.bankItems = self.bankItems
  OneForAllCharDB.bankScanned = time()
end

-- Deliberately conservative completion logic:
-- "done" is only used after this addon actually observed QUEST_TURNED_IN.
-- The server quest-completion flag is still shown, but as "questflag" because
-- some Forever beta characters appear to report unexpected completion flags.
function FLT:GetBookState(book)
  if OneForAllCharDB.confirmedDone[book.itemId] then return "done" end
  if OneForAllCharDB.manualDone[book.itemId] then return "manual" end
  if self.bagItems and self.bagItems[book.itemId] then return "bag" end
  if self.bankItems and self.bankItems[book.itemId] then return "bank" end
  if self:IsQuestDone(book.questId) then return "questflag" end
  return "missing"
end

function FLT:GetCounts()
  local done, owned = 0, 0
  for _, b in ipairs(self.BOOKS) do
    local s = self:GetBookState(b)
    -- "manual" = marked as turned in by hand (6.2.6, user 12.11.: turned in before OneForAll was installed - it counts)
    if s == "done" or s == "manual" then
      done = done + 1
      owned = owned + 1
    elseif s == "bag" or s == "bank" then
      owned = owned + 1
    end
  end
  return done, owned
end

function FLT:GetItemStorageState(id)
  if not id then return "unknown" end
  if self.bagItems and self.bagItems[id] then return "bag" end
  if self.bankItems and self.bankItems[id] then return "bank" end
  return "missing"
end


function FLT:GetRecipeFullName(recipe)
  if not recipe then return nil end
  return ((self.RECIPE_PREFIX or {})[recipe.profession] or "") .. (recipe.name or "")
end

function FLT:RequestRecipeItemData(id)
  id = tonumber(id)
  if not id then return end
  if C_Item and C_Item.RequestLoadItemDataByID then
    pcall(C_Item.RequestLoadItemDataByID, id)
  elseif GetItemInfo then
    -- On older clients, querying by ID itself starts the server cache request.
    pcall(GetItemInfo, id)
  end
end

function FLT:GetRecipeItemLink(recipe)
  local id = self:GetRecipeItemID(recipe)
  if not id then return nil end
  self:RequestRecipeItemData(id)
  local _, link = GetItemInfo(id)
  return link or ("item:" .. tostring(id))
end

function FLT:Refresh()
  self:ScanBags()
  if self.UIRefresh then self:UIRefresh() end
  if self.MapLandmarks and self.MapLandmarks.BooksChanged then self.MapLandmarks.BooksChanged() end
end

function FLT:PrintDebug()
  msg("Debug: books where the server says the quest is completed but this addon did not observe the turn-in:")
  local n = 0
  for _, book in ipairs(self.BOOKS) do
    if self:IsQuestDone(book.questId) and not OneForAllCharDB.confirmedDone[book.itemId] then
      n = n + 1
      msg(string.format("%s | quest=%d | item=%d | state=%s", book.name, book.questId, book.itemId, self:GetBookState(book)))
    end
  end
  if n == 0 then msg("No unverified quest-completion flags found.") end
end

-- 5.6.2: own SavedVariables names. Up to 5.6.1 they were ForeverCompanionDB / ForeverCompanionCharDB
-- (from the old addon name), the same names as the addon "Forever Companion: Discovery Journal": both
-- addons then shared one table and our data replaced the journal's at every login or /reload.
-- This chunk runs before our SavedVariables are loaded, so whatever is in the old globals now belongs
-- to another addon. At ADDON_LOADED we take our old data over once and hand those globals back.
-- (The old names stay in the .toc for the 5.6 versions so old data can be moved; remove them in 5.7.)
local OLD_DB, OLD_CHAR = "ForeverCompanionDB", "ForeverCompanionCharDB"
local foreignDB, foreignChar = _G[OLD_DB], _G[OLD_CHAR]
local function moveOldSavedVariables()
  local old, oldChar = _G[OLD_DB], _G[OLD_CHAR]
  if OneForAllDB == nil and type(old) == "table" and old ~= foreignDB then OneForAllDB = old end
  if OneForAllCharDB == nil and type(oldChar) == "table" and oldChar ~= foreignChar then OneForAllCharDB = oldChar end
  _G[OLD_DB], _G[OLD_CHAR] = foreignDB, foreignChar
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("BAG_UPDATE_DELAYED")
f:RegisterEvent("BANKFRAME_OPENED")
f:RegisterEvent("BANKFRAME_CLOSED")
f:RegisterEvent("QUEST_TURNED_IN")
f:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == ADDON then
    moveOldSavedVariables()
    -- Migrate settings/progress from the old Forever Library Tracker name.
    if not OneForAllDB and ForeverLibraryTrackerDB then OneForAllDB = ForeverLibraryTrackerDB end
    OneForAllDB = OneForAllDB or {}

    -- Book progress and bank contents are per character (SavedVariablesPerCharacter).
    -- Before 4.3 they were stored account-wide: the first character that logs
    -- in with 4.3 takes over the old turn-ins/manual marks. The old bank scan is
    -- dropped because it may belong to another character; it is rebuilt on the
    -- next bank visit.
    OneForAllCharDB = OneForAllCharDB or {}
    local char = OneForAllCharDB
    if not char.initialized then
      if OneForAllDB.confirmedDone or OneForAllDB.manualDone then
        char.confirmedDone = OneForAllDB.confirmedDone
        char.manualDone = OneForAllDB.manualDone
      end
      char.initialized = true
    end
    OneForAllDB.confirmedDone = nil
    OneForAllDB.manualDone = nil
    OneForAllDB.bankItems = nil
    OneForAllDB.bankScanned = nil
    char.manualDone = char.manualDone or {}
    char.confirmedDone = char.confirmedDone or {}
    char.bankItems = char.bankItems or {}
    OneForAllDB.recipeItemIDs = nil -- obsolete merchant cache (pre-4.1.2)
    OneForAllDB.talentPlans = OneForAllDB.talentPlans or {}
    FLT.bankItems = char.bankItems
    -- 6.0.1: the character's profile (UI/Profiles.lua) into the live settings, before the first-start defaults
    if FLT.Profiles then FLT.Profiles.Load() end
    -- 5.6.2: first start (no Quality of Life settings yet): these options start switched on
    -- (chosen by the user 16.10.); existing installs keep what they have
    if OneForAllDB.qol == nil then
      OneForAllDB.qol = {
        quickLoot = true, bagsFull = true,
        lootFeed = true, lootFeedMoney = true, lootFeedQuality = 0,
        questSparkles = true,
        bossDrops = true, recipeTip = true, unitTarget = true,
        classColors = true, thanksBuff = true,
        bagSlots = true, questXP = true, durability = true, copyChat = true, mmCollect = true,
        cameraZoom = true, moveWindows = true, -- 5.7.0 (user 22.10.)
      }
    end
    if OneForAllDB.nearbyAlertsEnabled == nil then OneForAllDB.nearbyAlertsEnabled = true end
    -- 5.7.3: one skin only (Gold Modern, user 27.10.); old skin choices are not read any more - clear them
    OneForAllDB.skin, OneForAllDB.frameStyle, OneForAllDB.skinDefault561 = nil, nil, nil
  elseif event == "PLAYER_LOGIN" then
    FLT:Refresh()
    if FLT.CreateMinimapButton then FLT:CreateMinimapButton() end
    if FLT.StartNearbyMonitor then FLT:StartNearbyMonitor() end
  elseif event == "BAG_UPDATE_DELAYED" then
    FLT:Refresh()
  elseif event == "QUEST_TURNED_IN" then
    FLT:RecordObservedTurnIn(arg1)
    FLT:Refresh()
  elseif event == "BANKFRAME_OPENED" then
    FLT:ScanBank(); FLT:Refresh()
  elseif event == "BANKFRAME_CLOSED" then
    FLT:Refresh()
  end
end)

SLASH_ONEFORALL1 = "/oneforall"
SLASH_ONEFORALL2 = "/ofa"
SLASH_ONEFORALL3 = "/forever"
SLASH_ONEFORALL4 = "/flt"
SLASH_ONEFORALL5 = "/librarybooks"
SlashCmdList.ONEFORALL = function(cmd)
  cmd = (cmd or ""):lower():match("^%s*(.-)%s*$")
  if cmd == "reset" then
    OneForAllCharDB.manualDone = {}
    msg(L["Manual marks reset. Observed turn-ins are kept."])
    FLT:Refresh()
  elseif cmd == "craft" then
    if FLT.CraftList then FLT.CraftList.Toggle() end
  elseif cmd == "tracker" then
    if FLT.RunTracker then FLT.RunTracker.Toggle() end
  elseif cmd == "tracker test" then
    if FLT.RunTracker then FLT.RunTracker.Test() end
  elseif cmd == "where" then
    -- Prints the current map and coordinates, to correct map pins in the data.
    local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    local pos = mapID and C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(mapID, "player")
    local info = mapID and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
    if pos then
      local x, y = pos:GetXY()
      msg(string.format("%s (mapID %d): %.1f, %.1f", info and info.name or "?", mapID, x * 100, y * 100))
    else
      msg(L["No map position available here (e.g. inside an instance)."])
    end
  elseif cmd == "scale" or cmd:match("^scale%s") then
    local value = cmd:match("^scale%s+([%d%.]+)")
    if FLT.SetWindowScale then
      local applied = FLT:SetWindowScale(value)
      msg(string.format(L["Window size set to %d%%."], math.floor(applied * 100 + 0.5)) .. (value and "" or (" " .. L["Position reset to the screen center."])))
    end
  elseif cmd == "tabs reset" then
    if FLT.UI and FLT.UI.ResetTabs then FLT.UI.ResetTabs() end
    msg(L["Tab selection reset to the defaults for this character."])
  elseif cmd == "share test" then
    if FLT.QuestShareTest then FLT:QuestShareTest() end
  elseif cmd == "questmarks test" then
    if FLT.QuestMarks then FLT.QuestMarks.Test() end
  elseif cmd == "chathistory" then
    if FLT.QoL and FLT.QoL.ChatHistoryInfo then FLT.QoL.ChatHistoryInfo() end
  elseif cmd == "share" then
    if FLT.OpenQuestShare then FLT:OpenQuestShare() end
  elseif cmd == "share on" or cmd == "share off" then
    if FLT.SetQuestShareOption then FLT:SetQuestShareOption("popup", cmd == "share on") end
    msg(cmd == "share on" and L["Quest share popup enabled."] or L["Quest share popup disabled. /ofa share still opens it manually."])
  elseif cmd == "share emote on" or cmd == "share emote off" then
    if FLT.SetQuestShareOption then FLT:SetQuestShareOption("emote", cmd == "share emote on") end
    msg(cmd == "share emote on" and L["Share emote enabled."] or L["Share emote disabled."])
  elseif cmd == "mem" then
    -- memory check: the number includes garbage that Lua has not freed yet
    local get = (C_AddOns and C_AddOns.GetAddOnMemoryUsage) or GetAddOnMemoryUsage
    if UpdateAddOnMemoryUsage then UpdateAddOnMemoryUsage() end
    local kb = get and get("OneForAll")
    if kb then msg(string.format(L["Memory: %.1f MB (includes garbage the game has not cleaned up yet)."], kb / 1024)) end
  elseif cmd == "cpu" or cmd == "cpu reset" then
    -- which of our files use the CPU (6.2.17-beta54; only with /console scriptProfile 1 and a /reload, see Profiler.lua)
    if not (FLT.Profiler and FLT.Profiler.on) then msg(L["CPU check: type /console scriptProfile 1, then /reload, play a few minutes and type /ofa cpu again. Turn it off afterwards with /console scriptProfile 0 and /reload."])
    elseif cmd == "cpu reset" then FLT.Profiler.Reset() else FLT.Profiler.Report() end
  elseif cmd == "gv" or cmd:match("^gv%s") then
    if FLT.GearValue then FLT.GearValue.Debug(cmd:match("(item:[%-%d:]+)")) end
  elseif cmd == "trainer" then
    if FLT.PrintTrainerDebug then FLT.PrintTrainerDebug() end
  elseif cmd == "buttons" then
    if FLT.PrintMinimapCollector then FLT.PrintMinimapCollector() end
  elseif cmd == "errors" then
    local list = type(OneForAllDB) == "table" and OneForAllDB.errors
    if not list or #list == 0 then msg(L["No errors caught."]) else
      msg(string.format(L["%d caught error(s), newest first (date | version | client language | where | error):"], #list))
      for i = 1, math.min(10, #list) do msg("  " .. list[i]) end
    end
  elseif cmd == "errors clear" then
    if type(OneForAllDB) == "table" then OneForAllDB.errors = nil end
    msg(L["Caught errors cleared."])
  elseif cmd == "bug" then
    if FLT.UI and FLT.UI.ShowBugReport then FLT.UI.ShowBugReport() end
  elseif cmd == "play" then
    if FLT.GuildGames then FLT.GuildGames.Toggle() end
  elseif cmd == "play invite" then
    if FLT.GuildGames then FLT.GuildGames.TestInvite() end
  elseif cmd == "play debug" then
    if FLT.GuildGames and FLT.GuildGames.ToggleDebug then FLT.GuildGames.ToggleDebug() end
  elseif cmd == "play bots" then
    if FLT.GuildGames then FLT.GuildGames.ToggleBots(); FLT.GuildGames.Open() end
  elseif cmd == "rolltest" then
    if FLT.GearMarks then FLT.GearMarks.RollTest() end
  elseif cmd == "questtest" then
    if FLT.GearMarks then FLT.GearMarks.QuestTest() end
  elseif cmd == "cheapest" then
    if FLT.QoL and FLT.QoL.PrintCheapest then FLT.QoL.PrintCheapest() end
  elseif cmd == "thanks" then
    if FLT.QoL and FLT.QoL.PrintThanksLog then FLT.QoL.PrintThanksLog() end
  elseif cmd == "petscan" then
    if FLT.ScanPetAbilities then FLT.ScanPetAbilities() end
    local t = type(OneForAllCharDB) == "table" and OneForAllCharDB.petAbilities or {}
    local parts = {}
    for name, v in pairs(t) do -- each rank on its own since 6.2.11 (an old number = the highest rank)
      local rs = {}
      if type(v) == "table" then for r in pairs(v) do rs[#rs + 1] = r end; table.sort(rs) else rs[1] = v end
      parts[#parts + 1] = name .. " " .. table.concat(rs, "/")
    end
    table.sort(parts)
    msg(#parts > 0 and string.format(L["Known pet abilities: %s"], table.concat(parts, ", ")) or L["Open Beast Training once so OneForAll knows your ranks"])
  elseif cmd == "news" then
    if FLT.ShowNews then FLT.ShowNews() end
  elseif cmd == "setup" then
    if FLT.ShowWelcome then FLT.ShowWelcome() end
  elseif cmd == "channel" then
    local st = FLT.RecipeShareStatus and FLT.RecipeShareStatus()
    if not st then return end
    if FLT.RecipeChannelOff then msg(L["OneForAll no longer uses a chat channel: the game blocks channels with many players. Recipes are shared in your guild."]) return end
    if not st.enabled then msg(L["Recipe sharing with other OneForAll users is off (Settings)."]) return end
    msg(string.format("Recipe channel: %s. Other users online: %d, known recipe holders: %d. Own status sent: %s (every %d min).%s",
      st.channel and ("joined as channel " .. st.channel) or ("not joined (" .. st.tries .. " tries)"),
      st.online, st.known, st.lastStatus and (st.lastStatus .. " s ago") or "not yet", math.floor((st.every or 600) / 60),
      st.queued > 0 and (" Waiting to send: " .. st.queued .. ".") or ""))
    if st.recv then
      msg(string.format("Received: %d messages (this minute %d, peak %d per minute), dropped %d. Searches %d, players found %d, answers sent %d.",
        st.recv, st.recvMin, st.recvPeak, st.dropped, st.searches, st.hits, st.answers))
      if st.lastErr then msg("Last message the game refused: result " .. st.lastErr .. " (7 = channel refused, 3/8 = throttled).") end
      if st.refused then msg("The game refuses the channel for this character right now (low level?).") end
    end
  elseif cmd == "dmap" then -- the dungeon map as on M (outside a dungeon: the first one with a map), for testing
    if FLT.ToggleDungeonMap then FLT.ToggleDungeonMap(true) end
  elseif cmd == "profscan" then
    if not FLT.ScanProfessions then return end
    local r = FLT.ScanProfessions()
    local l = r.last or {}
    msg(string.format("Profession scan: new API %s, old API %s, profession API %s. Last: %s, %d recipes read, %d matched, skill %s.",
      tostring(r.newAPI), tostring(r.oldAPI), tostring(r.profAPI), tostring(l.prof or "none"), l.count or 0, l.matched or 0, tostring(l.skill)))
    if l.foreign then msg("The last profession window showed another player's recipes (a link or guild member) - not stored.") end
    local st = l.stats
    if st then msg(string.format("Recipe list: %d ids, learned %d, not learned %d, no flag %d, no info %d.", st.ids, st.yes, st.no, st.noField, st.noInfo)) end
  elseif cmd == "talentdump" then
    if not FLT.DumpTalents then return end
    local classes, talents = FLT:DumpTalents()
    if not classes then
      msg(string.format(L["Talent dump failed: %s"], tostring(talents)))
    else
      msg(string.format(L["Talent dump saved: %d classes, %d talents. Type /reload (or log out), then send WTF\\Account\\<account>\\SavedVariables\\OneForAll.lua."], classes, talents))
    end
  elseif cmd == "debug" then
    FLT:PrintDebug()
  elseif cmd == "portraits" then
    if FLT.PrintPortraitDebug then FLT:PrintPortraitDebug() else msg("Portrait diagnostics are not available until the UI module has loaded.") end
  elseif cmd == "bank" then
    msg(L["Bank status is refreshed whenever you open your bank. The last successful scan is kept after closing it."])
  elseif cmd == "profdb" or cmd == "profdata" then
    local resolved, total = FLT:GetProfessionResolutionCount()
    msg(string.format("Profession data: standalone and embedded. %d/%d Merchant's Favor recipes have built-in result mappings.", resolved, total))
  else
    if FLT.ToggleUI then FLT:ToggleUI() end
  end
end

-- /rl = reload the interface (6.2.18, Discord Merdos 27.11.2026, user: "dann aufnehmen bitte"). Many players have /rl from another
-- addon already: it is added at login (when every addon is loaded) and only when no other one uses it.
do
  local f = CreateFrame("Frame")
  f:RegisterEvent("PLAYER_LOGIN")
  f:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    if type(SlashCmdList) ~= "table" or not ReloadUI then return end
    for name in pairs(SlashCmdList) do
      for i = 1, 9 do
        local s = _G["SLASH_" .. name .. i]
        if s == nil then break end
        if type(s) == "string" and s:lower() == "/rl" then return end
      end
    end
    SLASH_OFARELOAD1 = "/rl"
    SlashCmdList.OFARELOAD = function() ReloadUI() end
  end)
end
