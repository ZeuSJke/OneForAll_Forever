-- Translations (6.2.0, user 07.11.2026). FLT.L["English text"] gives the text in the chosen language, or the English
-- text itself when there is no translation (so nothing can ever be empty).
--  * The key is the English text. Placeholders stay in it: string.format(L["%d recipes"], n).
--  * The language is chosen in Settings > General (a drop-down with every language, in every client; default English,
--    user 07.11.): OneForAllDB.language = "enUS" / "deDE" / ... A change needs a reload (a popup offers it).
--  * Each language file (Locales/deDE.lua ...) only puts a function into FLT.LOCALES; on ADDON_LOADED, when the setting
--    is known, the chosen one makes its table and the others are let go (the garbage collector frees them).
--  * Never use L[...] while the files load (in the main chunk of a file): the setting is not known yet then. Translate
--    when the text is shown (tools/locale/extract.py warns about L[ at the start of a line).
local ADDON, FLT = ...
local active -- the table of the language in use, or nil (English)
FLT.L = setmetatable({}, { __index = function(_, k)
  local v = active and active[k]
  return v or k
end })
FLT.LOCALES = FLT.LOCALES or {} -- [code] = function returning the table, put there by the language files

-- the languages OneForAll speaks, in the order of the drop-down, each in its own language
FLT.LANGUAGES = { { key = "enUS", label = "English" }, { key = "deDE", label = "Deutsch" },
  { key = "frFR", label = "Français" }, { key = "esES", label = "Español" }, -- frFR / esES: beta37
  { key = "ruRU", label = "Русский" } }

-- the client's language as one of ours: a Mexican Spanish client uses esES, a British English one enUS
local CLIENT_ALIAS = { esMX = "esES", enGB = "enUS" }
function FLT.ClientLocale()
  local c = type(GetLocale) == "function" and GetLocale() or "enUS"
  return CLIENT_ALIAS[c] or c
end

-- the chosen language ("enUS" when none or not known); beta1/2 saved "game" / "english"
function FLT.Language()
  local v = type(OneForAllDB) == "table" and OneForAllDB.language
  if v == "game" then v = FLT.ClientLocale() end
  for _, l in ipairs(FLT.LANGUAGES) do if l.key == v then return v end end
  return "enUS"
end

-- true when names may come from the game client (items, factions, zones, item sets): the chosen language is not
-- English and is the client's own language (an English choice keeps our English data names; beta12)
function FLT.ClientTexts()
  local lang = FLT.Language()
  return lang ~= "enUS" and FLT.ClientLocale() == lang
end
-- a name from our data (quest, NPC, boss, object, item, quest objective) in the client's language when ClientTexts
-- (6.2.0 step 2b): Locales/Names_<loc>.lua from QuestieDB's translations (tools/locale/names.lua); else the name itself
local names -- English -> translation, made on ADDON_LOADED when ClientTexts
function FLT.Name(s)
  return names and type(s) == "string" and names[s] or s
end
-- "Gerrig Bonegrip, Ironforge (50.8, 5.6)": the name and the zone translated, the rest as it is
function FLT.PlaceText(s)
  if not names or type(s) ~= "string" then return s end
  local who, rest = s:match("^(.-), (.+)$")
  if not who then return names[s] or FLT.ZoneName(s) end
  local zone, tail = rest:match("^(.-)(%s*%(.*)$")
  if not zone then zone, tail = rest, "" end
  local inside = zone:match("^inside (.+)$") -- "Maur Grimtotem, inside Ragefire Chasm"
  if inside then return (names[who] or who) .. ", " .. string.format(FLT.L["inside %s"], FLT.DungeonName(inside)) .. tail end
  return (names[who] or who) .. ", " .. FLT.ZoneName(zone) .. tail
end
-- a dungeon / raid name (FLT.DUNGEON_REGISTRY key) in the client's language: the instance's name from the game
-- (GetRealZoneText of the instance map ID in Data/DungeonMaps.lua) when ClientTexts; else the name itself
local dungeonCache = {}
function FLT.DungeonName(name)
  if not names or type(name) ~= "string" then return name end
  local c = dungeonCache[name]
  if c then return c end
  local m = FLT.DUNGEON_MAPS and FLT.DUNGEON_MAPS[name]
  local id = type(m) == "table" and m.map
  local ok, n = false, nil
  if id and GetRealZoneText then ok, n = pcall(GetRealZoneText, id) end
  c = (ok and type(n) == "string" and n ~= "") and n or names[name] or name
  dungeonCache[name] = c
  return c
end
-- an equipment slot or item word ("Head", "One-Hand" ...); "Back" has its own key, the button "Back" is another word
function FLT.SlotWord(w)
  if w == "Back" then local v = FLT.L["Back (slot)"]; return v ~= "Back (slot)" and v or w end
  return w and FLT.L[w]
end

-- A data text with numbers ("Bite the enemy, causing 7 to 9 damage."): the numbers become %s, the sentence is translated
-- as a whole and the numbers go back in (6.2.0; the key is the English sentence with %s, "%" written as "%%")
local nums, unpack = {}, unpack or table.unpack
local function numOut(m)
  local tail = ""
  if m:sub(-1) == "." then m, tail = m:sub(1, -2), "." end
  nums[#nums + 1] = m
  return "%s" .. tail
end
function FLT.LNum(text)
  if not active or type(text) ~= "string" or text == "" then return text end
  for i = #nums, 1, -1 do nums[i] = nil end
  local key = text:gsub("%%", "%%%%"):gsub("%d[%d%.]*", numOut)
  local tr = active[key]
  if not tr then return text end
  local ok, out = pcall(string.format, tr, unpack(nums))
  return ok and out or text
end
-- a zone name from our data ("The Barrens") in the client's language when ClientTexts (map ID from Data.lua MAP_IDS)
local zoneCache = {}
function FLT.ZoneName(zone)
  if type(zone) ~= "string" or not FLT.ClientTexts() then return zone end
  local c = zoneCache[zone]
  if c then return c end
  local id = FLT.MAP_IDS and FLT.MAP_IDS[zone]
  local info = id and type(C_Map) == "table" and type(C_Map.GetMapInfo) == "function" and C_Map.GetMapInfo(id)
  c = type(info) == "table" and info.name or zone
  zoneCache[zone] = c
  return c
end
-- an item's name: the client's when ClientTexts (German client + German), else our English one from the data
function FLT.ItemName(id, fallback)
  if fallback and not FLT.ClientTexts() then return fallback end
  local n = id and C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
  if not n and id and GetItemInfo then n = GetItemInfo(id) end
  return n or (names and fallback and names[fallback]) or fallback -- not cached: the QuestieDB name (6.2.0)
end
-- "Head, Leather" / "Two-Hand, Staff" from the data, word by word
local function slotPart(w) local lead, word = w:match("^(%s*)(.-)%s*$"); return lead .. (FLT.SlotWord(word) or word) end
function FLT.SlotText(s)
  if not active or type(s) ~= "string" then return s end
  return (s:gsub("[^,]+", slotPart))
end

-- Game words the client gives in its language (German pet families and abilities from UnitCreatureFamily / the pet
-- spellbook) back to our English data name: a reverse look-up of the client language's translations (6.2.0). Words
-- without a translation stay as they are.
local clientLang, clientMake, reverse
function FLT.EnglishOf(word)
  if not word or not clientLang or clientLang == "enUS" then return word end -- (nil: before ADDON_LOADED)
  if not reverse then
    local t = (clientLang == FLT.Language()) and active or (clientMake and clientMake())
    clientMake = nil
    reverse = {}
    for en, tr in pairs(t or {}) do if reverse[tr] == nil then reverse[tr] = en end end
  end
  return reverse[word] or word
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, _, name)
  if name ~= ADDON then return end
  self:UnregisterEvent("ADDON_LOADED")
  local make = FLT.LOCALES[FLT.Language()]
  if type(make) == "function" then active = make() end
  -- the client's own language (when we have it): for FLT.EnglishOf, made only when first needed
  local own = FLT.ClientLocale()
  if own ~= "enUS" and own ~= FLT.Language() and type(FLT.LOCALES[own]) == "function" then clientMake = FLT.LOCALES[own] end
  clientLang = own
  FLT.LOCALES = {} -- the other languages are not needed any more
  local nm = FLT.NAME_LOCALES and FLT.NAME_LOCALES[FLT.Language()]
  if FLT.ClientTexts() and type(nm) == "function" then names = nm() end
  FLT.NAME_LOCALES = nil -- the name lists are big: only the one in use stays
end)
