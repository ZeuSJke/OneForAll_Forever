local _, FLT = ...
local L = FLT.L or setmetatable({}, { __index = function(_, k) return k end }) -- (tests without Locales)
local function N(s) return s end -- marks an English text translated where it is shown (tools/locale/extract.py)
-- Item API: newer clients only have these under C_Item.
local GetItemInfo = GetItemInfo or (C_Item and C_Item.GetItemInfo)
local GetItemCount = GetItemCount or (C_Item and C_Item.GetItemCount)
local GetItemIcon = GetItemIcon or (C_Item and C_Item.GetItemIconByID)
local UI = FLT.UI
local unpack = unpack or table.unpack
local makeTexture, makeButton = UI.makeTexture, UI.makeButton

-- "All recipes" browser for the Professions tab (no "(beta)" in the title since 6.2.1, user 08.11.). Data: Data/Professions/*.lua
-- (extracted from the Forever client database). Known recipes and the current
-- skill are read from the profession window and stored per character in
-- OneForAllCharDB.professions[profession] = { skill, maxSkill, known = {spellID=true} }.

local GOLD = {1, 0.82, 0.20}
local DIFF = {
  orange = {1.00, 0.50, 0.25}, yellow = {1.00, 1.00, 0.00},
  green  = {0.25, 0.75, 0.25}, gray   = {0.55, 0.55, 0.55},
  red    = {0.90, 0.25, 0.25},
}
local QCOL = { [0]={0.62,0.62,0.62}, [1]={1,1,1}, [2]={0.12,1,0}, [3]={0,0.44,0.87}, [4]={0.64,0.21,0.93}, [5]={1,0.5,0} }

-- ---------------------------------------------------------------------------
-- Character data (skill + known recipes)
-- ---------------------------------------------------------------------------
-- a recipe's name in the client's language when ClientTexts (6.2.0): the made item's name, else the craft spell's;
-- cached once known (the item may not be loaded yet on the first call)
local rnames = setmetatable({}, { __mode = "k" })
local function recipeName(r)
  if not (FLT.ClientTexts and FLT.ClientTexts()) then return r.n end
  local n = rnames[r]
  if n then return n end
  if r.i then n = FLT.ItemName(r.i) end
  if not n and r.s then pcall(function() n = (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(r.s)) or (GetSpellInfo and GetSpellInfo(r.s)) end) end
  if type(n) ~= "string" or n == "" then return r.n end
  rnames[r] = n
  return n
end
FLT.RecipeName = recipeName
-- the reagents of a recipe as one lower-case text for the search (6.2.2, user 09.11.: "coarse thread" finds every
-- recipe that needs it): our English names + the client's names; kept once all client names are loaded
local rhay = setmetatable({}, { __mode = "k" })
local function reagentText(r)
  local h = rhay[r]
  if h then return h end
  local parts, done, client = {}, true, FLT.ClientTexts and FLT.ClientTexts()
  for _, rg in ipairs(r.r or {}) do
    if rg[3] and rg[3] ~= "" then parts[#parts + 1] = rg[3] end
    if client and rg[1] then
      local n = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(rg[1])
      if not n and GetItemInfo then n = GetItemInfo(rg[1]) end
      if type(n) == "string" then parts[#parts + 1] = n else done = false end
    end
  end
  h = table.concat(parts, " "):lower()
  if done then rhay[r] = h end
  return h
end
FLT._reagentText = reagentText -- tests
local function NM(s) return FLT.Name and FLT.Name(s) or s end -- NPC / object / item names (6.2.0 step 2b)
local function DN(s) return FLT.DungeonName and FLT.DungeonName(s) or s end
local function profDB(prof)
  if type(OneForAllCharDB) ~= "table" then return {known = {}} end
  OneForAllCharDB.professions = OneForAllCharDB.professions or {}
  local p = OneForAllCharDB.professions[prof]
  if not p then p = {known = {}}; OneForAllCharDB.professions[prof] = p end
  p.known = p.known or {}
  return p
end
FLT.GetProfessionState = profDB
FLT.ReadSkillLines = function() if FLT._readSkillLines then FLT._readSkillLines() end end

-- Favourite recipes (account wide): OneForAllDB.recipeFavorites[prof][spell]
local function favDB(prof, create)
  if type(OneForAllDB) ~= "table" then return nil end
  OneForAllDB.recipeFavorites = OneForAllDB.recipeFavorites or {}
  local t = OneForAllDB.recipeFavorites[prof]
  if not t and create then t = {}; OneForAllDB.recipeFavorites[prof] = t end
  return t
end
local function isFavorite(prof, spell) local t = favDB(prof); return t and t[spell] and true or false end
local function setFavorite(prof, spell, on) local t = favDB(prof, true); if t then t[spell] = on and true or nil end end
FLT.IsRecipeFavorite = isFavorite

local SKILL_LINE_PROF = {
  [171] = "Alchemy", [197] = "Tailoring", [164] = "Blacksmithing", [165] = "Leatherworking",
  [202] = "Engineering", [333] = "Enchanting", [185] = "Cooking", [129] = "First Aid",
}
local function profFromName(name, skillLine)
  local recipes = FLT.PROFESSION_RECIPES or {}
  if skillLine and SKILL_LINE_PROF[skillLine] and recipes[SKILL_LINE_PROF[skillLine]] then return SKILL_LINE_PROF[skillLine] end
  name = FLT.ProfKey and FLT.ProfKey(name) or name -- in the client's language (6.2.0)
  if name and recipes[name] then return name end
  return nil
end

-- calls fn(prof, rank, maxRank) for every profession the character has; returns true if a list was readable, and as
-- second value true when that list is surely complete (6.2.12-beta16: then a saved profession missing there was unlearned)
local function eachOwnProfession(fn)
  local any, full = false, false
  -- Old skill list API
  if GetNumSkillLines and GetSkillLineInfo then
    any = true
    local n = GetNumSkillLines() or 0
    -- complete only with lines at all (early after login there are none), no folded header (its lines are not listed)
    -- and every profession name known in the client's language
    full = n > 0 and (not FLT.ProfKeyReady or FLT.ProfKeyReady())
    for i = 1, n do
      local name, isHeader, isExpanded, rank, _, _, maxRank = GetSkillLineInfo(i)
      if isHeader and not isExpanded then full = false end
      local prof = not isHeader and profFromName(name)
      if prof and rank then fn(prof, rank, maxRank) end
    end
  end
  -- Modern profession API (profession book)
  if GetProfessions and GetProfessionInfo then
    any = true
    local list, found = {GetProfessions()}, false
    for k = 1, 6 do
      local idx = list[k]
      if idx then
        local ok, name, _, rank, maxRank, _, _, skillLine = pcall(GetProfessionInfo, idx)
        local prof = ok and profFromName(name, skillLine)
        if prof and rank then fn(prof, rank, maxRank); found = true end
      end
    end
    -- the profession book lists all of them at once (6.2.13-beta15, Discord gullols 21.11.: a changed profession stayed - the
    -- old skill list alone was never "complete" on the Forever client); only with at least one profession found (early
    -- after login the list can be empty) and the names known
    if found and (not FLT.ProfKeyReady or FLT.ProfKeyReady()) then full = true end
  end
  return any, full
end
local function readSkillLines()
  local seen = {}
  local _, full = eachOwnProfession(function(prof, rank, maxRank) local p = profDB(prof); p.skill = rank; p.maxSkill = maxRank; seen[prof] = true end)
  -- an unlearned profession is forgotten (6.2.12-beta16, user 18.11.: "wenn man eine verlernt bleibt die fuer immer im OFA
  -- gelernt"): only when the skill list is surely complete, and only professions with recipes (the only ones saved here);
  -- learned again, its recipes come back with the next look into the profession window
  if full and type(OneForAllCharDB) == "table" and type(OneForAllCharDB.professions) == "table" then
    local recipes = FLT.PROFESSION_RECIPES or {}
    for prof in pairs(OneForAllCharDB.professions) do
      if not seen[prof] and recipes[prof] then OneForAllCharDB.professions[prof] = nil end
    end
  end
end
FLT._readSkillLines = readSkillLines

local browser -- set when created; refreshed after scans
-- the browser holds the secure craft buttons (RecipeBar): resizing it in combat is blocked (ADDON_ACTION_BLOCKED
-- SetHeight, user 27.10.: SKILL_LINES_CHANGED from a weapon skill-up in combat) -> wait for the end of combat
local refreshAfterCombat
local function refreshBrowser(onlyShown)
  if not (browser and browser.Refresh) or (onlyShown and not browser:IsShown()) then return end
  if InCombatLockdown and InCombatLockdown() then
    if not refreshAfterCombat then
      refreshAfterCombat = CreateFrame("Frame")
      refreshAfterCombat:SetScript("OnEvent", function(self) self:UnregisterAllEvents(); refreshBrowser(true) end)
    end
    refreshAfterCombat:RegisterEvent("PLAYER_REGEN_ENABLED")
    return
  end
  browser:Refresh(true)
end
local lastScan = {}

-- Which of our professions does a set of recipe spell IDs belong to?
local function profFromSpells(spells)
  local spellProf = FLT._spellProf
  if not spellProf then
    spellProf = {}
    for prof, list in pairs(FLT.PROFESSION_RECIPES or {}) do
      for _, r in ipairs(list) do spellProf[r.s] = prof end
    end
    FLT._spellProf = spellProf
  end
  local count, best, bestN = {}, nil, 0
  for _, s in ipairs(spells) do
    local pr = spellProf[s]
    if pr then count[pr] = (count[pr] or 0) + 1; if count[pr] > bestN then best, bestN = pr, count[pr] end end
  end
  return best
end

-- Removes stored "known" recipes that need far more skill than the character
-- has (wrong entries written by 4.18.0). Learn level, or yellow - 50.
local function cleanImplausible(prof)
  local list = FLT.PROFESSION_RECIPES and FLT.PROFESSION_RECIPES[prof]
  if not list or type(OneForAllCharDB) ~= "table" or type(OneForAllCharDB.professions) ~= "table" then return end
  local p = OneForAllCharDB.professions[prof]
  if not (p and p.known and p.skill) then return end
  for _, r in ipairs(list) do
    if p.known[r.s] then
      local need = r.req or ((r.y and r.y > 0) and (r.y - 50)) or 0
      if need > p.skill then p.known[r.s] = nil end
    end
  end
end
local function cleanAllProfessions()
  for prof in pairs(FLT.PROFESSION_RECIPES or {}) do cleanImplausible(prof) end
end

-- The trade skill window can also show someone else's recipes: a profession link from chat, a guild
-- member's profession or an NPC crafter. Those must not be stored as our own (bug report 16.10.:
-- a linked Enchanting 225 showed up as known until the own window was opened again).
local function call(fn) if type(fn) ~= "function" then return nil end local ok, v = pcall(fn); return ok and v end
local function foreignTradeSkill()
  local T = C_TradeSkillUI
  if T and (call(T.IsTradeSkillLinked) or call(T.IsTradeSkillGuild) or call(T.IsTradeSkillGuildMember) or call(T.IsNPCCrafting)) then
    return true
  end
  return call(IsTradeSkillLinked) or call(IsTradeSkillGuild) or false
end

-- Reagents as the server has them (user 13.11.2026: Green Silk Pack needs 5 Bolts of Silk Cloth in the game, 4 in the
-- client files and on wowtbc.gg - a server-side change): read from the open profession window and, when they differ from
-- the data, saved account wide (OneForAllDB.recipeReagents[spell] = {{item, count, name}, ...}) and laid over the data
-- (Crafting List, Skill-Up Helper, Profit all read r.r). Compared first, a new table only when something differs.
local function applyReagentFixes()
  local db = type(OneForAllDB) == "table" and OneForAllDB.recipeReagents
  if type(db) ~= "table" then return end
  for _, recipes in pairs(FLT.PROFESSION_RECIPES or {}) do
    for _, r in ipairs(recipes) do local l = db[r.s]; if type(l) == "table" and #l > 0 then r.r = l end end
  end
end
local function hasReagent(r, id, count)
  for _, g in ipairs(r.r or {}) do if g[1] == id then return g[2] == count, g[3] end end
  return false
end
-- n reagents, get(src, k) -> item ID, count, name; returns true when the recipe changed
local function takeReagents(r, n, get, src)
  if not n or n == 0 then return false end
  local same = n == #(r.r or {})
  for k = 1, n do
    local id, count = get(src, k)
    if not (id and count and count > 0) then return false end -- not loaded yet: the next scan reads it
    if same and not hasReagent(r, id, count) then same = false end
  end
  if same then return false end
  local list = {}
  for k = 1, n do
    local id, count, name = get(src, k)
    local _, oldName = hasReagent(r, id, count)
    list[k] = { id, count, name or oldName }
  end
  r.r = list
  if type(OneForAllDB) == "table" then
    OneForAllDB.recipeReagents = OneForAllDB.recipeReagents or {}
    OneForAllDB.recipeReagents[r.s] = list
  end
  return true
end
local function oldReagent(i, k)
  local l2 = GetTradeSkillReagentItemLink(i, k)
  local name, _, count = GetTradeSkillReagentInfo(i, k)
  return l2 and tonumber(l2:match("item:(%d+)")), count, name
end
local basic = {} -- the basic reagent slots of one recipe (reused)
local function newReagent(_, k) return basic[k].reagents[1].itemID, basic[k].quantityRequired end
local function readReagents(recipeBySpell, knownNew)
  local changed = false
  -- old trade skill window
  if GetNumTradeSkills and GetTradeSkillRecipeLink and GetTradeSkillNumReagents and GetTradeSkillReagentInfo and GetTradeSkillReagentItemLink then
    for i = 1, GetNumTradeSkills() or 0 do
      local link = GetTradeSkillRecipeLink(i)
      local r = link and recipeBySpell[tonumber(link:match("enchant:(%d+)") or link:match("spell:(%d+)") or 0)]
      if r and takeReagents(r, GetTradeSkillNumReagents(i), oldReagent, i) then changed = true end
    end
  end
  -- new profession window (Enchanting on Forever): only the basic reagent slots
  local T = C_TradeSkillUI
  if T and T.GetRecipeSchematic and knownNew then
    for _, id in ipairs(knownNew) do
      local r = recipeBySpell[id]
      local ok, sc = pcall(T.GetRecipeSchematic, id, false)
      local slots = ok and type(sc) == "table" and sc.reagentSlotSchematics
      if r and type(slots) == "table" then
        wipe(basic)
        for _, sl in ipairs(slots) do
          if (sl.reagentType == nil or sl.reagentType == 1) and sl.reagents and sl.reagents[1] then basic[#basic + 1] = sl end
        end
        if takeReagents(r, #basic, newReagent) then changed = true end
      end
    end
  end
  return changed
end

local function scanTradeSkill()
  if foreignTradeSkill() then lastScan = {foreign = true}; return end
  local prof, rank, maxRank, hint
  local known = {}
  local fullList = false -- the new API lists every recipe, independent of the window's filters
  local stats = {ids = 0, yes = 0, no = 0, noField = 0, noInfo = 0}

  -- New profession window (C_TradeSkillUI)
  local T = C_TradeSkillUI
  if T and T.GetAllRecipeIDs then
    local ok, ids = pcall(T.GetAllRecipeIDs)
    if ok and type(ids) == "table" and #ids > 0 then
      -- GetAllRecipeIDs also returns recipes the character has NOT learned yet;
      -- only recipes whose info says learned = true count as known.
      local infos, anyField = {}, false
      for _, id in ipairs(ids) do
        stats.ids = stats.ids + 1
        local info
        if T.GetRecipeInfo then
          local ok2, i2 = pcall(T.GetRecipeInfo, id)
          if ok2 and type(i2) == "table" then info = i2 end
        end
        infos[id] = info or false
        if info and info.learned ~= nil then anyField = true end
      end
      for _, id in ipairs(ids) do
        local info = infos[id]
        if not info then stats.noInfo = stats.noInfo + 1
        elseif info.learned == true then stats.yes = stats.yes + 1; known[#known + 1] = id
        elseif info.learned == false then stats.no = stats.no + 1
        else
          stats.noField = stats.noField + 1
          -- no learned flag yet: the recipe data is still loading - don't guess
          -- (an early scan like this caused the wrong checks in 4.18.0)
        end
      end
      fullList = anyField
    end
    if T.GetBaseProfessionInfo then
      local ok3, info = pcall(T.GetBaseProfessionInfo)
      if ok3 and type(info) == "table" then
        hint = profFromName(info.professionName, info.professionID)
        rank, maxRank = info.skillLevel, info.maxSkillLevel
        if (not rank or rank == 0) and T.GetProfessionInfoBySkillLineID and info.professionID then
          local ok4, i2 = pcall(T.GetProfessionInfoBySkillLineID, info.professionID)
          if ok4 and type(i2) == "table" then rank, maxRank = i2.skillLevel, i2.maxSkillLevel end
        end
      end
    end
    if not hint and T.GetTradeSkillLine then
      local ok5, a, b, c, d = pcall(T.GetTradeSkillLine)
      if ok5 then
        if type(a) == "number" then hint = profFromName(b, a); rank, maxRank = rank or c, maxRank or d
        else hint = profFromName(a); rank, maxRank = rank or b, maxRank or c end
      end
    end
  end

  -- Old trade skill window
  if GetTradeSkillLine then
    local n, r, m = GetTradeSkillLine()
    if n and n ~= "UNKNOWN" then hint = hint or profFromName(n); rank, maxRank = rank or r, maxRank or m end
  end
  local itemLinks = {}
  if GetNumTradeSkills and GetTradeSkillInfo then
    for i = 1, GetNumTradeSkills() or 0 do
      local _, kind = GetTradeSkillInfo(i)
      if kind and kind ~= "header" and kind ~= "subheader" then
        local spell
        if GetTradeSkillRecipeLink then
          local link = GetTradeSkillRecipeLink(i)
          spell = link and tonumber(link:match("enchant:(%d+)") or link:match("spell:(%d+)"))
        end
        if spell then known[#known + 1] = spell
        elseif GetTradeSkillItemLink then
          local link = GetTradeSkillItemLink(i)
          local item = link and tonumber(link:match("item:(%d+)"))
          if item then itemLinks[#itemLinks + 1] = item end
        end
      end
    end
  end

  prof = hint or profFromSpells(known)
  if not prof then
    -- maybe only item links: match by crafted item
    for p, list in pairs(FLT.PROFESSION_RECIPES or {}) do
      local byItem = {}
      for _, r in ipairs(list) do if r.i then byItem[r.i] = r.s end end
      for _, it in ipairs(itemLinks) do if byItem[it] then prof = p; break end end
      if prof then break end
    end
  end
  if not prof then lastScan = {count = #known, items = #itemLinks}; return end
  -- second guard: the window shows a profession we don't have, or a different skill than ours
  do
    local own
    local readable = eachOwnProfession(function(p2, r2) if p2 == prof then own = r2 end end)
    if readable and (own == nil or (rank and rank > 0 and own ~= rank)) then lastScan = {foreign = true, prof = prof}; return end
  end

  local p = profDB(prof)
  if rank and rank > 0 then p.skill, p.maxSkill = rank, maxRank end
  local skillNow = (rank and rank > 0) and rank or p.skill
  -- Plausibility: a recipe can't be known when it needs far more skill than
  -- the character has (learn level, or yellow - 50 when the learn level is unknown).
  local recipeBySpell, byItem = {}, {}
  for _, r in ipairs(FLT.PROFESSION_RECIPES[prof]) do recipeBySpell[r.s] = r; if r.i then byItem[r.i] = r.s end end
  local function plausible(r)
    if not skillNow then return true end
    if r.req then return r.req <= skillNow end
    if r.y and r.y > 0 then return r.y - 50 <= skillNow end
    return true
  end
  -- a complete list from the new API replaces what was stored (removes wrong entries)
  if fullList then wipe(p.known) end
  local n = 0
  for _, s in ipairs(known) do local r = recipeBySpell[s]; if r and plausible(r) then p.known[s] = true; n = n + 1 end end
  for _, it in ipairs(itemLinks) do local r = recipeBySpell[byItem[it]]; if r and plausible(r) then p.known[r.s] = true; n = n + 1 end end
  -- also drop implausible entries stored by older versions
  for s in pairs(p.known) do local r = recipeBySpell[s]; if r and not plausible(r) then p.known[s] = nil end end
  p.scanned = true
  readReagents(recipeBySpell, fullList and known)
  lastScan = {prof = prof, count = #known, matched = n, skill = rank, stats = stats}
  readSkillLines()
  if FLT.OnProfessionScan then FLT.OnProfessionScan() end
  refreshBrowser()
end

FLT.RefreshRecipeBrowser = function()
  refreshBrowser(true)
end

local scanPending = false
local function scanSoon()
  if scanPending then return end
  if C_Timer and C_Timer.After then
    scanPending = true
    C_Timer.After(0.5, function() scanPending = false; scanTradeSkill() end)
  else
    scanTradeSkill()
  end
end

FLT.ScanProfessions = function()
  readSkillLines(); scanTradeSkill()
  local T = C_TradeSkillUI
  return {
    newAPI = (T and T.GetAllRecipeIDs) and true or false,
    oldAPI = (GetNumTradeSkills and GetTradeSkillInfo) and true or false,
    profAPI = (GetProfessions and GetProfessionInfo) and true or false,
    last = lastScan,
  }
end

do
  local ev = CreateFrame("Frame")
  for _, e in ipairs({"TRADE_SKILL_SHOW", "TRADE_SKILL_UPDATE", "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_DATA_SOURCE_CHANGED",
                      "NEW_RECIPE_LEARNED", "SKILL_LINES_CHANGED", "PLAYER_LOGIN"}) do pcall(ev.RegisterEvent, ev, e) end
  ev:SetScript("OnEvent", function(_, event)
    if event == "SKILL_LINES_CHANGED" or event == "PLAYER_LOGIN" then
      if event == "PLAYER_LOGIN" then applyReagentFixes() end
      readSkillLines(); cleanAllProfessions(); refreshBrowser(true)
      if FLT.SkillUp and FLT.SkillUp.OnSkill then FLT.SkillUp.OnSkill() end -- the Skill-Up guide ticks its steps
    else
      scanSoon()
    end
  end)
end

-- Recipes of a profession for the player's faction (side="A"/"H" = one faction only).
local factionLists = {}
-- Sorted by the level shown in the list (learn level, or the yellow skill
-- when the learn level is unknown), then by name.
local function sortLevel(r) return r.req or r.y or 0 end
local function recipesFor(prof)
  local all = FLT.PROFESSION_RECIPES and FLT.PROFESSION_RECIPES[prof] or {}
  local fac = UnitFactionGroup and UnitFactionGroup("player")
  local side = fac == "Alliance" and "A" or fac == "Horde" and "H" or nil
  local key = prof .. (side or "-")
  if not factionLists[key] then
    local t = {}
    for _, r in ipairs(all) do if not side or not r.side or r.side == side then t[#t + 1] = r end end
    table.sort(t, function(a, b)
      local la, lb = sortLevel(a), sortLevel(b)
      if la ~= lb then return la < lb end
      if a.n ~= b.n then return a.n < b.n end
      return a.s < b.s
    end)
    factionLists[key] = t
  end
  return factionLists[key]
end

-- Difficulty of a recipe for the current skill (like the profession window).
-- Other OneForAll users who know a recipe and are online right now.
local function onlineOthers(prof, spell)
  local list = FLT.GetOtherRecipeKnowers and FLT.GetOtherRecipeKnowers(prof, spell)
  if not list then return nil end
  for _, g in ipairs(list) do if g[2] then return list end end
  return nil
end

-- Recipes a dungeon boss drops: Data\Professions\BossDrops.lua (Wowhead
-- Forever drop data) plus the drop sources stored with the recipes.
local bossIndex
local function buildBossIndex()
  bossIndex = {}
  local byItem = {}
  for prof, list in pairs(FLT.PROFESSION_RECIPES or {}) do
    for _, r in ipairs(list) do
      if r.ri and not byItem[r.ri] then byItem[r.ri] = {prof = prof, r = r} end
    end
  end
  local function add(npc, e)
    local t = bossIndex[npc]
    if not t then t = {}; bossIndex[npc] = t end
    for _, x in ipairs(t) do if x == e then return end end
    t[#t + 1] = e
  end
  for npc, items in pairs(FLT.RECIPE_BOSS_DROPS or {}) do
    for _, ri in ipairs(items) do if byItem[ri] then add(npc, byItem[ri]) end end
  end
  for _, e in pairs(byItem) do
    for _, n in ipairs((e.r.src and e.r.src.d) or {}) do if n[1] then add(n[1], e) end end
  end
  for _, t in pairs(bossIndex) do
    table.sort(t, function(a, b) if a.prof ~= b.prof then return a.prof < b.prof end return (a.r.rn or a.r.n) < (b.r.rn or b.r.n) end)
  end
end
function FLT.GetBossRecipes(npcID)
  if not npcID then return nil end
  if not bossIndex then buildBossIndex() end
  return bossIndex[npcID]
end
-- yellow / green / blue state of a recipe for other modules
function FLT.RecipeKnowState(prof, r)
  local p = profDB(prof)
  local guild = FLT.GetGuildRecipeKnowers and FLT.GetGuildRecipeKnowers(prof, r.s)
  local list = FLT.GetOtherRecipeKnowers and FLT.GetOtherRecipeKnowers(prof, r.s)
  local other = false
  for _, g in ipairs(list or {}) do if g[2] then other = true; break end end
  return p.known[r.s] and true or false, guild and true or false, other
end

local function difficulty(r, skill)
  if not skill then return nil end
  if r.req and skill < r.req then return "red" end
  if r.gr and r.gr > 0 and skill >= r.gr then return "gray" end
  if r.g and r.g > 0 and skill >= r.g then return "green" end
  if r.y and r.y > 0 and skill >= r.y then return "yellow" end
  return "orange"
end

-- chance of a skill-up for yellow and green recipes (Classic: (grey - skill) / (grey - yellow)); nil for orange,
-- grey, red or without data (6.0.1, Discord noel.puldon: the colour stays, the number is added)
local function skillUpChance(r, d, skill)
  if (d ~= "yellow" and d ~= "green") or not skill or not r.y or not r.gr or r.gr <= r.y then return nil end
  local p = math.floor((r.gr - skill) / (r.gr - r.y) * 100 + 0.5)
  return math.max(1, math.min(100, p))
end

-- how many you can make with the reagents in your bags (6.0.1-beta2, user 30.10.: "(2)" like the game's window)
local function canMake(r)
  if not r.r or #r.r == 0 or not GetItemCount then return 0 end
  local n
  for _, rg in ipairs(r.r) do
    local have = FLT.CraftList and FLT.CraftList.InBags and FLT.CraftList.InBags(rg[1]) or GetItemCount(rg[1]) or 0
    local k = math.floor(have / math.max(1, rg[2] or 1))
    if not n or k < n then n = k end
  end
  return n or 0
end

local function itemIcon(id)
  local icon = (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)) or (GetItemIcon and GetItemIcon(id))
  return icon or "Interface\\Icons\\INV_Misc_QuestionMark"
end
-- Icon of a recipe: crafted item, or the spell icon for enchants.
local function recipeIcon(r)
  if r.i then return itemIcon(r.i) end
  if r.ic then return r.ic end
  local t = (C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(r.s)) or (GetSpellTexture and GetSpellTexture(r.s))
  return t or "Interface\\Icons\\Spell_Holy_GreaterHeal"
end
-- Shift-click: crafted item link, or the spell link for enchants.
local function linkRecipe(r, button, H)
  if r.i then
    if H and H.handleDungeonItemClick then H.handleDungeonItemClick({id = r.i, name = r.n, quality = r.q}, button or "LeftButton") end
    return
  end
  local link = (C_Spell and C_Spell.GetSpellLink and C_Spell.GetSpellLink(r.s)) or (GetSpellLink and GetSpellLink(r.s))
  if link then
    if ChatEdit_InsertLink and ChatEdit_InsertLink(link) then return end
    if ChatFrame_OpenChat then ChatFrame_OpenChat(link) end
  end
end
FLT.RecipeIcon = recipeIcon

local function itemName(id)
  local n = GetItemInfo and GetItemInfo(id)
  if not n and C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
  return n
end

-- ---------------------------------------------------------------------------
-- Browser
-- ---------------------------------------------------------------------------
function UI.CreateRecipeBrowser(parent)
  local H = UI.DungeonHelpers
  local f = CreateFrame("Frame", nil, parent); f:SetAllPoints(); f:Hide()
  browser = f
  local prof, filter, search = nil, "all", ""

  local title = FLT.NewFS(f, nil, "OVERLAY", "GameFontNormalLarge")
  local profIcon = f:CreateTexture(nil, "ARTWORK"); profIcon:SetSize(40, 40); profIcon:SetPoint("TOPLEFT", 12, -6)
  title:SetPoint("TOPLEFT", 60, -8); title:SetTextColor(FLT.SkinC(unpack(GOLD)))
  local meta = FLT.NewFS(f, nil, "OVERLAY", "GameFontHighlightSmall")
  meta:SetPoint("TOPLEFT", 60, -32); meta:SetTextColor(FLT.SkinC(0.82, 0.80, 0.72))

  -- the search line of the open recipe (6.1.0): its text and "Search again" change without rebuilding the details
  local searchUI = {}
  local function updateSearchUI()
    local ui = searchUI
    if not (ui.fs and ui.r and FLT.RecipeSearchState) then return end
    local state, ago, canAgain = FLT.RecipeSearchState(prof, ui.r.s)
    local msg = ""
    if not state then msg = (ui.n or 0) > 0 and "" or "|cff9d9d9d" .. L["Click Search to find players who know this recipe."] .. "|r"
    elseif state == "connecting" then msg = "|cffd0c8b0" .. L["Connecting to the other OneForAll users ..."] .. "|r"
    elseif state == "searching" then msg = "|cffd0c8b0" .. L["Searching ..."] .. "|r"
    elseif state == "error" then msg = "|cffff9933" .. L["The game did not let this character reach the other OneForAll users (low level?). Try again later."] .. "|r"
    elseif state == "limited" then msg = "|cffff9933" .. L["Many searches right now - try again in 30 s."] .. "|r"
    elseif state == "done" and (ui.n or 0) == 0 then msg = "|cff9d9d9d" .. L["No current results received."] .. "|r"
    elseif state == "done" and ago then
      msg = "|cff9d9d9d" .. (ago < 60 and L["Searched just now."] or string.format(L["Searched %d min ago."], math.floor(ago / 60))) .. "|r"
    end
    local wait = (state ~= "searching" and not canAgain and ago) and math.max(1, 30 - math.floor(ago)) or nil
    if wait then msg = msg .. "  |cff9d9d9d(" .. string.format(L["search again in %d s"], wait) .. ")|r" end
    ui.fs:SetText(msg)
    -- grey while it can't be used (plain Disable() keeps the gold look of our buttons)
    local can = (state == nil) or (state ~= "searching" and state ~= "connecting" and canAgain) or false
    if ui.btn.SetLabel then ui.btn:SetLabel(state and state ~= "connecting" and L["Search again"] or L["Search"]) end
    if can then ui.btn:Enable() else ui.btn:Disable() end
    if ui.btn.SetLook then ui.btn:SetLook(can) end
  end

  -- Re-check who is online once a minute while the browser is open; the search line every second.
  local tick, stick = 0, 0
  f:SetScript("OnUpdate", function(_, elapsed)
    tick = tick + (elapsed or 0)
    stick = stick + (elapsed or 0)
    if stick >= 1 then stick = 0; updateSearchUI() end -- a few SetText calls, only while a recipe is open
    if tick >= 60 and not (InCombatLockdown and InCombatLockdown()) then tick = 0; f:Refresh(true) end -- not in combat (secure craft buttons)
  end)

  -- Legend for the check columns (top right)
  local legendFirst
  do
    local lx = -14
    local K = UI.KNOW_COLORS
    local M = UI.KNOW_MARKS
    local specs = {{L["Other users"] .. " |cff9d9d9d(" .. L["only visible when online"] .. ")|r", K.other, M.other}, {L["Guild member"], K.guild, M.guild}, {L["I know it"], K.me, M.me}}
    if FLT.RecipeChannelOff then table.remove(specs, 1) end -- 6.1.4: no search among other users
    for i, spec in ipairs(specs) do
      local t = FLT.NewFS(f, nil, "OVERLAY", "GameFontHighlightSmall"); t:SetPoint("TOPRIGHT", lx, -14); t:SetText(spec[1]); t:SetTextColor(FLT.SkinC(0.85, 0.82, 0.75))
      if i == 1 and not FLT.RecipeChannelOff then
        -- keeps its width when the text changes (see f:Refresh), so the other entries stay put
        t:SetWidth(t:GetStringWidth() or 200); t:SetJustifyH("RIGHT"); f.otherLegend = t
      end
      local ic = UI.Mark(f, 14, spec[3], unpack(spec[2])); ic:SetPoint("RIGHT", t, "LEFT", -4, 0)
      legendFirst = ic -- the last one created is the left-most ("I know it")
      lx = lx - (t:GetStringWidth() or 60) - 34
    end
  end
  -- hint in the second line, right-aligned under the legend; it may reach left over the whole detail column (user
  -- 06.11.: with only "I know it" and "Guild member" it started at the "I know it" check and was cut off: "re...")
  local scanHint = FLT.NewFS(f, nil, "OVERLAY", "GameFontHighlightSmall"); scanHint:SetTextColor(FLT.SkinC(1, 0.82, 0))
  scanHint:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, legendFirst and -33 or -32)
  scanHint:SetPoint("LEFT", f, "LEFT", 344, 0) -- the detail column (the list is 336 wide)
  scanHint:SetJustifyH("RIGHT"); scanHint:SetWordWrap(false)

  -- the Crafting List window (5.7.3, UI/CraftList.lua; stays open when OneForAll closes) - its button lives here since
  -- 6.2.6-beta28 (user 12.11.: out of the sub-tab row, "in All Recipes und Favorites ... da ist er besser aufgehoben")
  do
    local b = UI.GoldButton(f, L["Crafting List"], 130, 22, nil, 12); b:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, -52)
    b:SetScript("OnClick", function() if FLT.CraftList then FLT.CraftList.Toggle() end end)
    b:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:AddLine(L["Crafting List"], 1, 0.82, 0)
      GameTooltip:AddLine(L["Plan what to craft: the materials you have in your bags, bank and on your other characters, and what is still missing. Add recipes with \"+ List\". Also /ofa craft."], 1, 1, 1, true)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end

  -- filters + search
  local filters = {}
  local box = FLT.SkinBlizz(CreateFrame("EditBox", nil, f, "InputBoxTemplate"))
  box:SetSize(220, 20); box:SetPoint("TOPLEFT", 18, -53); box:SetAutoFocus(false)
  local hint = FLT.NewFS(box, nil, "OVERLAY", "GameFontDisableSmall"); hint:SetPoint("LEFT", 4, 0); hint:SetText(L["Search name or material..."])
  -- clear button next to the search field (only while there is text)
  local clear = UI.GoldButton(f, "X", 22, 20, nil, 11); clear:SetPoint("LEFT", box, "RIGHT", 6, 0); clear:Hide()
  clear:SetScript("OnClick", function() box:SetText(""); box:ClearFocus() end)
  clear:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText(L["Clear search"]); GameTooltip:Show() end)
  clear:SetScript("OnLeave", function() GameTooltip:Hide() end)
  box:SetScript("OnTextChanged", function(self) search = (self:GetText() or ""):lower(); hint:SetShown(search == ""); clear:SetShown(search ~= ""); f:Refresh() end)
  -- who knows it (6.2.0, user 07.11.: "Meine Rezepte / Gilde / Beides" and back to "Alle"): the funnel like the source
  -- filter of the Gear Planner; OneForAllDB.recipeKnowFilter = "mine" / "guild" / "both" (you or the guild), nil = all
  -- "notmine" (6.2.1, user 08.11.): the recipes this character has not learned yet
  local KNOW = { { key = "all", label = N"All recipes" }, { key = "mine", label = N"My recipes" },
    { key = "notmine", label = N"Not learned" }, { key = "guild", label = N"Guild" }, { key = "both", label = N"Mine or guild" } }
  local function knowFilter() local v = type(OneForAllDB) == "table" and OneForAllDB.recipeKnowFilter; return v ~= "all" and v or nil end
  local function knowLabel(k) for _, o in ipairs(KNOW) do if o.key == k then return L[o.label] end end end
  local funnel = CreateFrame("Button", nil, f); funnel:SetSize(22, 22); funnel:SetPoint("LEFT", box, "RIGHT", 34, 0)
  funnel.tex = funnel:CreateTexture(nil, "ARTWORK"); funnel.tex:SetAllPoints(); FLT.SetTex(funnel.tex, UI.ASSET_ROOT .. "icon_filter")
  local fhl = UI.makeTexture(funnel, "HIGHLIGHT", 1, 0.82, 0.3, 0.12); fhl:SetAllPoints()
  local function paintFunnel() funnel.tex:SetAlpha(knowFilter() and 1 or 0.5) end
  funnel:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:AddLine(L["Recipe filter"], 1, 0.82, 0)
    GameTooltip:AddLine(knowLabel(knowFilter() or "all"), 1, 1, 1)
    GameTooltip:AddLine(L["Who knows the recipe: you, a guild member, or either of you - or what you have not learned yet."], 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
  end)
  funnel:SetScript("OnLeave", function() GameTooltip:Hide() end)
  funnel:SetScript("OnClick", function(self)
    local opts = {}
    for _, o in ipairs(KNOW) do opts[#opts + 1] = { key = o.key, label = L[o.label] } end
    UI.OpenDropDown(self, opts, knowFilter() or "all", function(k)
      if type(OneForAllDB) == "table" then OneForAllDB.recipeKnowFilter = k ~= "all" and k or nil end
      paintFunnel(); f:Refresh()
    end, 180)
  end)
  paintFunnel()
  box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

  -- "Show offline": also list guild members / players who are offline (off by default).
  local function showOffline() return type(OneForAllDB) == "table" and OneForAllDB.recipeShowOffline == true end

  -- list (left) and detail (right)
  local left = CreateFrame("Frame", nil, f); left:SetPoint("TOPLEFT", 0, -82); left:SetPoint("BOTTOMLEFT", 0, 0); left:SetWidth(336)
  UI.Column(left, 4) -- ht3: no frame, a line to the right
  local lsf = FLT.SkinBlizz(CreateFrame("ScrollFrame", nil, left, "UIPanelScrollFrameTemplate")); lsf:SetPoint("TOPLEFT", 8, -8); lsf:SetPoint("BOTTOMRIGHT", -26, 8)
  local lchild = CreateFrame("Frame", nil, lsf); lchild:SetSize(296, 1); lsf:SetScrollChild(lchild)
  UI.AutoHideScrollBar(lsf)

  local right = CreateFrame("Frame", nil, f); right:SetPoint("TOPLEFT", left, "TOPRIGHT", 8, 0); right:SetPoint("BOTTOMRIGHT", 0, 0)
  local rsf = FLT.SkinBlizz(CreateFrame("ScrollFrame", nil, right, "UIPanelScrollFrameTemplate")); rsf:SetPoint("TOPLEFT", 14, -12); rsf:SetPoint("BOTTOMRIGHT", -28, 10)
  local rchild = CreateFrame("Frame", nil, rsf); rchild:SetSize(420, 1); rsf:SetScrollChild(rchild)
  -- Crafting List / Craft buttons stacked right of Skill / Use / Learned from (5.7.3, user 24.10.; UI/CraftList.lua).
  -- Anchored once, it scrolls with the detail.
  local recipeBar = FLT.CraftList and FLT.CraftList.RecipeBar(rchild)
  if recipeBar then recipeBar:SetPoint("TOPRIGHT", rchild, "TOPRIGHT", -32, -100); recipeBar:Hide() end
  UI.AutoHideScrollBar(rsf)

  -- favourite star (top right of the recipe header)
  -- in the scrolling detail, so it moves with the recipe header (user 06.11.: it stayed put and covered the Reagents box)
  local star = CreateFrame("Button", nil, rchild); star:SetSize(26, 26); star:SetPoint("TOPRIGHT", rchild, "TOPRIGHT", 0, -4)
  star:SetFrameLevel(rchild:GetFrameLevel() + 5)
  star.tex = star:CreateTexture(nil, "ARTWORK"); star.tex:SetAllPoints(); FLT.SetTex(star.tex, UI.ASSET_ROOT .. "icon_star")
  local starHi = star:CreateTexture(nil, "HIGHLIGHT"); starHi:SetAllPoints(); FLT.SetTex(starHi, UI.ASSET_ROOT .. "icon_star"); starHi:SetBlendMode("ADD"); starHi:SetAlpha(0.35)
  local selectedRecipe -- forward: set below
  local function paintStar()
    local r = selectedRecipe and selectedRecipe()
    star:SetShown(r ~= nil and prof ~= nil)
    if not r then return end
    if isFavorite(prof, r.s) then star.tex:SetVertexColor(FLT.SkinC(1, 0.82, 0.25)); star.tex:SetAlpha(1)
    else star.tex:SetVertexColor(0.6, 0.6, 0.6); star.tex:SetAlpha(0.55) end
  end
  star:SetScript("OnEnter", function(self)
    local r = selectedRecipe and selectedRecipe()
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText((r and isFavorite(prof, r.s)) and L["Remove from favorites"] or L["Add to favorites"])
    GameTooltip:Show()
  end)
  star:SetScript("OnLeave", function() GameTooltip:Hide() end)

  local rows, selected = {}, nil
  local openReagent, reagentSources -- the reagent whose sources are open (6.1.5), its builder (below)
  local allDrops, redrawDetail = {}, nil -- [itemID] = true: "Show all" mobs that drop it; redraw (set below showDetail)
  selectedRecipe = function() return selected end
  star:SetScript("OnClick", function()
    if not (prof and selected) then return end
    setFavorite(prof, selected.s, not isFavorite(prof, selected.s))
    paintStar()
    if filter == "fav" then f:Refresh(true) end
  end)
  -- hint when the favourites list is empty
  local favEmpty = FLT.NewFS(left, nil, "OVERLAY", "GameFontDisableSmall")
  favEmpty:SetPoint("TOPLEFT", 16, -16); favEmpty:SetWidth(296); favEmpty:SetJustifyH("LEFT")
  favEmpty:SetText(L["No favorites yet. Open a recipe in All recipes and click the star at the top right to add it here."])
  favEmpty:Hide()
  local detailWidgets = {}

  local function clearDetail()
    for _, w in ipairs(detailWidgets) do w:Hide() end
    wipe(detailWidgets)
    searchUI.fs, searchUI.btn, searchUI.r = nil, nil, nil
  end
  local function dtext(template, w, parent)
    local t = FLT.NewFS(parent or rchild, nil, "OVERLAY", template or "GameFontHighlightSmall")
    if w then t:SetWidth(w); t:SetJustifyH("LEFT") end
    detailWidgets[#detailWidgets + 1] = t
    return t
  end
  local function dframe(kind, template, parent)
    local fr = CreateFrame(kind or "Frame", nil, parent or rchild, template)
    detailWidgets[#detailWidgets + 1] = fr
    return fr
  end
  local function itemRow(id, y, label, sub, count, parent)
    local b = dframe("Button", nil, parent); b:SetSize(parent and 384 or 400, 30); b:SetPoint("TOPLEFT", parent and 8 or 0, y)
    UI.CardRow(b)
    local ic = b:CreateTexture(nil, "ARTWORK"); ic:SetSize(24, 24); ic:SetPoint("LEFT", 4, 0); FLT.SetTex(ic, itemIcon(id))
    local t = FLT.NewFS(b, nil, "OVERLAY", "GameFontHighlight"); t:SetPoint("LEFT", 36, sub and 6 or 0); t:SetWidth(300); t:SetJustifyH("LEFT"); t:SetText(label or itemName(id) or (L["Item"] .. " " .. id))
    if sub then local s = FLT.NewFS(b, nil, "OVERLAY", "GameFontDisableSmall"); s:SetPoint("LEFT", 34, -8); s:SetText(sub) end
    if count then local c = FLT.NewFS(b, nil, "OVERLAY", "GameFontHighlight"); c:SetPoint("RIGHT", -6, 0); c:SetText(count) end
    b:SetScript("OnEnter", function(self) if H and H.tryShowItemTooltip then H.tryShowItemTooltip(self, {id, label or ""}) end end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:RegisterForClicks("LeftButtonUp")
    b:SetScript("OnClick", function(_, button) if H and H.handleDungeonItemClick and H.normalizeDungeonItem then H.handleDungeonItemClick(H.normalizeDungeonItem({id, label or ""}), button) end end)
    return b
  end
  local function npcRow(n, y, parent)
    local row = dframe("Frame", nil, parent); row:SetSize(parent and 376 or 400, 22); row:SetPoint("TOPLEFT", parent and 14 or 8, y)
    -- thin line under each row (like the family abilities of Hunter Pets)
    local sep = UI.makeTexture(row, "BORDER", 0.72, 0.50, 0.12, 0.18); sep:SetPoint("BOTTOMLEFT", 0, -1); sep:SetPoint("BOTTOMRIGHT", 0, -1); sep:SetHeight(1)
    local t = FLT.NewFS(row, nil, "OVERLAY", "GameFontHighlightSmall"); t:SetPoint("LEFT", 0, 0); t:SetWidth(300); t:SetJustifyH("LEFT")
    local fac = n.fac == "A" and " |cff4f9fff(" .. L["Alliance"] .. ")|r" or (n.fac == "H" and " |cffff5040(" .. L["Horde"] .. ")|r" or "")
    t:SetText((NM(n[2]) or "?") .. (n[3] == "" and "" or ("  |cff9d9d9d- " .. (n[3] or "?") .. "|r")) .. fac)
    if n[4] and n[5] then
      local mb = UI.GoldButton(row, L["Map"], 62, 20, UI.ASSET_ROOT .. "icon_map", 11); mb:SetPoint("RIGHT", 0, 0)
      mb:SetScript("OnClick", function() FLT:ShowOnMap({mapID = n[4], x = n[5], y = n[6], zone = n[3], name = NM(n[2]), area = n.area}) end)
    end
  end

  -- framed box with a small-caps title, like Hunter Pets (5.7.3, user 24.10.); build(box, y) fills it from y down and
  -- returns where it ended; returns the y below the box
  local function section(title, y0, build)
    local b = dframe("Frame"); b:SetPoint("TOPLEFT", 0, y0); b:SetWidth(400)
    UI.FramedPanel(b)
    local t = UI.SmallCaps(b, title, 15, 11, GOLD); t:SetPoint("TOPLEFT", 12, -9)
    local h = -build(b, -32) + 8
    b:SetHeight(h)
    return y0 - h - 10
  end

  -- where to get a reagent (6.1.5): made with a profession (our recipe data), vendors of your side (nearest map first),
  -- the objects it comes from (herbs, veins, fishing schools) or the mobs that drop it (Data/ReagentSources.lua); 6.1.6:
  -- also smelting, skinning, fishing zones, disenchanting and containers (Wowhead item pages, where QuestieDB has nothing)
  local function mapName(id)
    local i = id and C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(id)
    return i and i.name or "?"
  end
  reagentSources = function(item, ry, b)
    -- a little room under the reagent and between the parts (user 05.11.: looked squeezed)
    ry = ry - 6
    local first = true
    local function sub(text)
      if not first then ry = ry - 6 end
      first = false
      local t = dtext("GameFontDisableSmall", 370, b); t:SetPoint("TOPLEFT", 16, ry); t:SetText(text); ry = ry - 20
    end
    local any = false
    for prof, list in pairs(FLT.PROFESSION_RECIPES or {}) do
      for _, x in ipairs(list) do
        if x.i == item then sub("|cffffd100" .. string.format(L["Made with %s:"], L[prof]) .. "|r " .. recipeName(x)); any = true; break end
      end
    end
    local src = FLT.REAGENT_SOURCES and FLT.REAGENT_SOURCES[item]
    if src and src.c then
      -- made by a spell (6.1.6): smelting, or combining smaller ones
      sub("|cffffd100" .. (src.c[1] == 186 and L["Smelted with Mining from:"] or L["Made from:"]) .. "|r " .. src.c[2]); any = true
    end
    if src then
      local side = UnitFactionGroup and UnitFactionGroup("player")
      side = side == "Alliance" and "A" or (side == "Horde" and "H" or nil)
      local here = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
      -- the nearest first (user 05.11.: in the Barrens it showed Stranglethorn; drops looked random): world distance
      -- where the game tells it (same continent), else your zone first
      local wpos = C_Map and C_Map.GetWorldPosFromMapPos
      local me, meCont
      if wpos and here and C_Map.GetPlayerMapPosition then
        local p = C_Map.GetPlayerMapPosition(here, "player")
        if p then meCont, me = wpos(here, p) end
      end
      local function nearest(ids, tbl, keep)
        local l = {}
        for _, id in ipairs(ids) do
          local v = tbl and tbl[id]
          if v and (not keep or keep(v)) then
            local d = v[2] == here and 1e6 or 1e9
            if me and CreateVector2D then
              local ok, cont, pos = pcall(wpos, v[2], CreateVector2D(v[3] / 100, v[4] / 100))
              if ok and cont == meCont and pos then local x1, y1 = me:GetXY(); local x2, y2 = pos:GetXY(); d = math.sqrt((x1 - x2) ^ 2 + (y1 - y2) ^ 2) end
            end
            l[#l + 1] = { id, v, d }
          end
        end
        table.sort(l, function(a, c) if a[3] ~= c[3] then return a[3] < c[3] end return a[1] < c[1] end)
        return l
      end
      if src.v then
        local l = nearest(src.v, FLT.REAGENT_VENDORS, function(v) return not side or not v[5] or v[5] == side end)
        if #l > 0 then
          sub("|cffffd100" .. L["Sold by"] .. "|r" .. (#l > 3 and "  |cff9d9d9d(" .. string.format(L["the nearest of %d vendors"], #l) .. ")|r" or "")); any = true
          for i = 1, math.min(3, #l) do local v = l[i][2]; npcRow({ l[i][1], v[1], mapName(v[2]), v[2], v[3], v[4] }, ry, b); ry = ry - 24 end
        end
      end
      if src.oz then
        sub("|cffffd100" .. string.format(L["From %s"], NM(src.o)) .. "|r"); any = true
        for i = 1, math.min(3, #src.oz) do
          local z = src.oz[i]
          npcRow({ 0, z[5] and (DN(z[5]) .. " (" .. L["entrance"] .. ")") or mapName(z[1]), "", z[1], z[2], z[3], area = z[4] }, ry, b); ry = ry - 24
        end
      end
      -- mobs (drops, skinning): the 3 nearest, "Show all" lists every one we have (up to 2 per zone; user 05.11.); in a
      -- dungeon or raid the map shows its entrance (6.1.6)
      local function mobList(ids, total, title, key)
        local l = nearest(ids, FLT.REAGENT_MOBS)
        local all = allDrops[key]
        local n = all and #l or math.min(3, #l)
        total = total or #l
        sub("|cffffd100" .. title .. "|r" .. (total > n and "  |cff9d9d9d(" .. string.format(L["the nearest %d of %d mobs"], n, total) .. ")|r" or "")); any = true
        if #l > 3 then
          local sb = UI.GoldButton(b, all and L["Fewer"] or L["Show all"], 74, 18); sb:SetPoint("TOPRIGHT", -14, ry + 21)
          sb:SetScript("OnClick", function() allDrops[key] = not all or nil; if redrawDetail then redrawDetail() end end)
        end
        for i = 1, n do
          local v = l[i][2]
          npcRow({ l[i][1], v[1], v[6] and (DN(v[6]) .. " (" .. L["entrance"] .. ")") or mapName(v[2]), v[2], v[3], v[4], area = v[5] }, ry, b); ry = ry - 24
        end
      end
      if src.d then mobList(src.d, src.dn, L["Drops from"], item) end
      if src.sk then mobList(src.sk, src.skn, L["Skinned from"] .. " (" .. L["Skinning"] .. ")", -item) end
      -- from the Wowhead item pages (6.1.6): fishing, disenchanting, containers
      if src.f then sub("|cffffd100" .. L["Fished in:"] .. "|r " .. (FLT.ZoneName and src.f:gsub("[^,]+", function(z) local lead, zz = z:match("^(%s*)(.-)$"); return lead .. FLT.ZoneName(zz) end) or src.f)); any = true end
      if src.de then
        sub("|cffffd100" .. L["Disenchanting"] .. "|r " .. (src.de[1] and string.format(L["items of item level %d-%d"], src.de[1], src.de[2]) or L["items"]) .. " (" .. L["Enchanting"] .. ")"); any = true
      end
      if src.ci then sub("|cffffd100" .. L["Found in:"] .. "|r " .. NM(src.ci)); any = true end
    end
    if not any then sub(L["Where to get it is not known."]) end
    return ry - 4
  end
  local function showDetail(r, keepScroll)
    clearDetail()
    if recipeBar then recipeBar:SetRecipe(prof, r) end
    if not r then return end
    local p = profDB(prof)
    local y = 0
    local big = dframe("Frame"); big:SetSize(46, 46); big:SetPoint("TOPLEFT", 0, y)
    local bic = big:CreateTexture(nil, "ARTWORK"); bic:SetAllPoints(); FLT.SetTex(bic, recipeIcon(r))
    -- 330 wide: leaves room for the favourite star (beta7: the SetPoint stood behind this comment on the same line, so
    -- the recipe name never showed - user screenshot 07.11.)
    local name = dtext("GameFontNormalLarge", 330); name:SetPoint("TOPLEFT", 56, y - 2)
    name:SetText(recipeName(r) .. ((r.c and r.c > 1) and (" x" .. r.c) or "")); local qc = QCOL[r.q or 1] or QCOL[1]; name:SetTextColor(FLT.SkinC(qc[1], qc[2], qc[3]))
    local sub = dtext("GameFontDisableSmall", 350); sub:SetPoint("TOPLEFT", 56, y - 26)
    -- 6.1.0 (user 03.11.): no automatic search when a recipe is opened - only the "Search" button asks the channel
    local guild = FLT.GetGuildRecipeKnowers and FLT.GetGuildRecipeKnowers(prof, r.s)
    local others = onlineOthers(prof, r.s)
    sub:SetText((r.cat or "") .. (p.known[r.s] and "   " .. FLT.SkinHex("ffd926") .. L["Known"] .. "|r" or (guild and "   |cff59ff73" .. L["Known in your guild"] .. "|r" or (others and "   |cff5ab3ff" .. L["Known by other players"] .. "|r" or ""))))
    big:EnableMouse(true)
    big:SetScript("OnMouseUp", function(_, button)
      if button == "LeftButton" and IsShiftKeyDown and IsShiftKeyDown() then linkRecipe(r, button, H) end
    end)
    big:SetScript("OnEnter", function(self)
      if r.i then
        if H and H.tryShowItemTooltip then H.tryShowItemTooltip(self, {r.i, r.n}) end
      else
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if GameTooltip.SetSpellByID then GameTooltip:SetSpellByID(r.s) else GameTooltip:AddLine(r.n) end
        GameTooltip:Show()
      end
    end)
    big:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local dv = rchild:CreateTexture(nil, "ARTWORK"); FLT.SetTex(dv, UI.ASSET_ROOT .. "divider_ornate"); dv:SetSize(400, 16); dv:SetPoint("TOPLEFT", 0, y - 48)
    detailWidgets[#detailWidgets + 1] = dv
    y = y - 70
    local textW = (recipeBar and recipeBar:IsShown()) and 176 or 290 -- the Crafting List / Craft stack sits on the right
    local box, by -- the Details box and the y inside it

    local function line(label, text)
      local h = dtext("GameFontNormalSmall", nil, box); h:SetPoint("TOPLEFT", 12, by); h:SetText(label); h:SetTextColor(FLT.SkinC(unpack(GOLD)))
      local b = dtext("GameFontHighlightSmall", textW, box); b:SetPoint("TOPLEFT", 104, by); b:SetText(text)
      by = by - math.max(18, (b:GetStringHeight() or 14) + 6)
    end
    local function c(col, v) local k = DIFF[col]; return string.format("|cff%02x%02x%02x%s|r", math.floor(k[1] * 255), math.floor(k[2] * 255), math.floor(k[3] * 255), tostring(v)) end
    y = section(L["Details"], y, function(b, y1) box, by = b, y1
    line(L["Skill"], (r.req and (string.format(L["learn at %s"], r.req) .. "   ") or ((not r.ri and not r.fav and not r.start) and "|cff9d9d9d" .. L["learn level: visit a trainer"] .. "|r   " or "")) .. c("yellow", r.y) .. "  " .. c("green", r.g) .. "  " .. c("gray", r.gr))
    do -- chance of a skill-up at your skill (yellow / green only)
      local d = difficulty(r, p.skill)
      local pct = skillUpChance(r, d, p.skill)
      if pct then line(L["Skill-up"], c(d, string.format(L["%s%% chance"], pct)) .. "  |cff9d9d9d(" .. string.format(L["at skill %s"], p.skill) .. ")|r") end
    end
    if r.lv then
      local pl = UnitLevel and UnitLevel("player") or 0
      line(L["Use"], (pl < r.lv and "|cffff6060" or "") .. string.format(L["Requires level %s"], r.lv) .. (pl < r.lv and "|r" or ""))
    end
    local learn
    if r.start then learn = string.format(L["Known when you learn %s"], L[prof])
    elseif r.ri then
      -- How to get the recipe item: vendor, world drop, specific mobs, quest, Favor.
      local src, how = r.src or {}, {}
      if r.fav then how[#how + 1] = FLT.SkinHex("ffd200") .. L["Merchant's Favor"] .. "|r" end
      if src.v then
        local fa, fh = false, false
        for _, n in ipairs(src.v) do if n.fac == "A" then fa = true elseif n.fac == "H" then fh = true else fa, fh = true, true end end
        how[#how + 1] = "|cff59ff73" .. L["Vendor"] .. "|r" .. ((fa and not fh) and " (" .. L["Alliance"] .. ")" or ((fh and not fa) and " (" .. L["Horde"] .. ")" or ""))
      end
      if src.d then
        local n = src.dn or #src.d
        how[#how + 1] = (n >= 10) and "|cffff9933" .. L["World drop"] .. "|r" or "|cffff9933" .. L["Drop"] .. "|r (" .. (n == 1 and L["1 mob"] or string.format(L["%d mobs"], n)) .. ")"
      end
      if src.qs then how[#how + 1] = "|cff7fbfff" .. L["Quest reward"] .. "|r" end
      learn = (r.rn or L["Recipe item"]) .. "\n" .. (#how > 0 and table.concat(how, "  +  ") or "|cff9d9d9d" .. L["Source not known yet"] .. "|r")
    else learn = L["Profession trainer"] end
    line(L["Learned from"], learn)
    -- the Crafting List / Craft stack (anchored in rchild at y -100) must fit into the box
    if recipeBar and recipeBar:IsShown() then by = math.min(by, -30 - recipeBar:UsedHeight()) end
    return by + 4 end)

    y = section(L["Reagents"], y, function(b, ry)
      for _, rg in ipairs(r.r or {}) do
        local have = GetItemCount and GetItemCount(rg[1], true) or 0
        local col = have >= rg[2] and "|cff59ff73" or "|cffff6060"
        local row = itemRow(rg[1], ry, itemName(rg[1]) or (rg[3] ~= "" and rg[3]) or nil, nil, col .. have .. "|r / " .. rg[2], b); ry = ry - 32
        -- a click shows where to get it (6.1.5, user 05.11.); Shift / Ctrl-click as before
        local old = row:GetScript("OnClick")
        row:SetScript("OnClick", function(self, button)
          if IsModifiedClick and IsModifiedClick() then if old then old(self, button) end; return end
          openReagent = (openReagent ~= rg[1]) and rg[1] or nil
          showDetail(selected, true)
        end)
        if openReagent == rg[1] then ry = reagentSources(rg[1], ry, b) end
      end
      return ry + 2
    end) + 10

    -- Who else can craft it: online first, with zone and a whisper button.
    local INST = { raid = N"in a raid", party = N"in a dungeon", pvp = N"in a battleground", arena = N"in an arena", scenario = N"in a scenario" }
    -- Guild: online members, offline ones with "Show offline".
    -- Other players: only those online right now.
    local function knowers(label, list, col, isGuild)
      if not list then return end
      local hidden = 0
      if not (isGuild and showOffline()) then
        local on = {}
        for _, g in ipairs(list) do if g[2] then on[#on + 1] = g else hidden = hidden + 1 end end
        list = on
      end
      -- other players: search state line (6.1.0), shown also without results
      local state
      if not isGuild then
        hidden = 0
        if FLT.RecipeSearchState then state = FLT.RecipeSearchState(prof, r.s) end -- (not "a and f()": keeps one value)
        if state == "off" then return end -- shown also before any search, with the "Search" button
      end
      y = y - 12
      y = y - 6
      -- tinted box behind the section (size set below)
      local top = y + 6
      -- rounded box: the textures belong to rchild (behind the text), the
      -- empty frame only gives them their position and size
      local box = dframe("Frame")
      local card
      if col == "|cff59ff73" then card = UI.Card(rchild, box, 5, {0.30, 0.55, 0.30, 0.85}, {0.06, 0.13, 0.07, 0.80}, "BACKGROUND", 0)
      else card = UI.Card(rchild, box, 5, {0.30, 0.45, 0.68, 0.85}, {0.05, 0.09, 0.16, 0.80}, "BACKGROUND", 0) end
      for _, t in ipairs(card.border.pieces) do detailWidgets[#detailWidgets + 1] = t end
      for _, t in ipairs(card.fill.pieces) do detailWidgets[#detailWidgets + 1] = t end
      y = y - 6
      local hk = dtext("GameFontNormal"); hk:SetPoint("TOPLEFT", 10, y); hk:SetText(label); hk:SetTextColor(FLT.SkinC(unpack(GOLD)))
      if not isGuild then
        -- "Search again" (at most every 30 s) and the state of the search
        local holder = dframe("Frame"); holder:SetSize(104, 22); holder:SetPoint("TOPLEFT", 286, y + 2)
        local sb = UI.GoldButton(holder, state and L["Search again"] or L["Search"], 100, 20, nil, 11); sb:SetPoint("RIGHT", 0, 0)
        sb:SetScript("OnClick", function()
          if FLT.SearchRecipe then FLT.SearchRecipe(prof, r.s, true); f:Refresh(true) end
        end)
        -- explain the wait (the button is grey for 30 s after a search; the tooltip shows while grey too)
        if sb.SetMotionScriptsWhileDisabled then sb:SetMotionScriptsWhileDisabled(true) end
        sb:SetScript("OnEnter", function(self)
          GameTooltip:SetOwner(self, "ANCHOR_TOP")
          GameTooltip:AddLine(L["Search"], 1, 0.82, 0)
          GameTooltip:AddLine(L["Asks the other OneForAll users who know this recipe. Only a few of them answer, and you can search again 30 seconds after the last search - so the channel stays quiet and fast with many players."], 1, 1, 1, true)
          GameTooltip:Show()
        end)
        sb:SetScript("OnLeave", function() GameTooltip:Hide() end)
        -- text and button state are kept up to date by updateSearchUI (no rebuild for "2 min ago")
        y = y - 20
        local st = dtext("GameFontHighlightSmall", 380); st:SetPoint("TOPLEFT", 12, y)
        searchUI.fs, searchUI.btn, searchUI.r, searchUI.n = st, sb, r, #list
        updateSearchUI()
      end
      if isGuild then
        -- "Show offline" next to the guild heading (off by default)
        local cb = dframe("CheckButton", "UICheckButtonTemplate"); cb:SetSize(22, 22)
        cb:SetPoint("LEFT", hk, "RIGHT", 14, 0); cb:SetChecked(showOffline())
        local cl = dtext("GameFontHighlightSmall"); cl:SetPoint("LEFT", cb, "RIGHT", 2, 0); cl:SetText(L["Show offline"])
        cb:SetScript("OnClick", function(self)
          if type(OneForAllDB) == "table" then OneForAllDB.recipeShowOffline = self:GetChecked() and true or false end
          f:Refresh(true)
        end)
      end
      y = y - 22
      for k, g in ipairs(list) do
        if k > 8 then
          local more = dtext("GameFontDisableSmall"); more:SetPoint("TOPLEFT", 12, y)
          more:SetText(string.format(L["+%d more"], #list - 8)); y = y - 18; break
        end
        local row = dframe("Frame"); row:SetSize(396, 22); row:SetPoint("TOPLEFT", 12, y)
        local t = FLT.NewFS(row, nil, "OVERLAY", "GameFontHighlightSmall"); t:SetPoint("LEFT", 0, 0); t:SetWidth(300); t:SetJustifyH("LEFT"); t:SetWordWrap(false)
        local where
        if g[2] then
          where = g[3] and ("|cffd0c8b0" .. g[3] .. "|r") or "|cffd0c8b0" .. L["online"] .. "|r"
          if g[4] and INST[g[4]] then where = where .. "  |cffff9933(" .. L[INST[g[4]]] .. ")|r" end
        else
          where = "|cff7f7f7f" .. L["offline"] .. "|r"
        end
        -- "Name, lvl 23 Priest - Zone" (level and class in grey)
        local who = ""
        if g.level or g.class then
          local cls = g.class and ((LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[g.class]) or (g.class:sub(1, 1) .. g.class:sub(2):lower())) or nil
          local parts = {}
          if g.level and g.level > 0 then parts[#parts + 1] = string.format(L["lvl %s"], g.level) end
          if cls then parts[#parts + 1] = cls end
          if #parts > 0 then who = "|cff9d9d9d, " .. table.concat(parts, " ") .. "|r" end
        end
        t:SetText((g[2] and col or "|cff9d9d9d") .. g[1] .. "|r" .. who .. "|cff9d9d9d - |r" .. where)
        if g.seen then
          row:EnableMouse(true)
          local seen = g.seen
          row:SetScript("OnEnter", function(self)
            local m = math.max(0, math.floor(((time and time() or 0) - seen) / 60))
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(m < 1 and L["Last heard just now"] or string.format(L["Last heard %d min ago"], m), 1, 1, 1)
            GameTooltip:Show()
          end)
          row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end
        if g[2] then
          local wb = UI.GoldButton(row, L["Whisper"], 70, 20, nil, 11); wb:SetPoint("RIGHT", -10, 0)
          local who = g[1]
          wb:SetScript("OnClick", function()
            if ChatFrame_SendTell then ChatFrame_SendTell(who)
            elseif ChatFrame_OpenChat then ChatFrame_OpenChat("/w " .. who .. " ") end
          end)
        end
        y = y - 22
      end
      if hidden > 0 then
        local hn = dtext("GameFontDisableSmall", 390); hn:SetPoint("TOPLEFT", 12, y)
        hn:SetText((#list > 0 and "+ " or "") .. string.format(L["%d offline"], hidden)); y = y - 18
      end
      y = y - 6
      box:SetPoint("TOPLEFT", 0, top); box:SetSize(400, top - y)
    end
    knowers(L["Guild members who know it"], guild, "|cff59ff73", true)
    knowers(L["Other OneForAll users online who know it"], others or {}, "|cff5ab3ff", false)

    if r.ri then
      y = section(L["Recipe"], y - 10, function(b, ry)
        itemRow(r.ri, ry, r.rn, nil, nil, b); ry = ry - 38
        local src = r.src or {}
        local function sub(text)
          local t = dtext("GameFontNormalSmall", nil, b); t:SetPoint("TOPLEFT", 12, ry); t:SetText(text); t:SetTextColor(FLT.SkinC(unpack(GOLD))); ry = ry - 20
        end
        if src.v then
          -- only vendors of the own side (and neutral ones), user 05.11.
          local side = UnitFactionGroup and UnitFactionGroup("player")
          side = side == "Alliance" and "A" or (side == "Horde" and "H" or nil)
          sub(L["Sold by"])
          local shown, other = 0, nil
          for _, n in ipairs(src.v) do
            -- "AH" = both sides (6.1.8: neutral vendors like Kzixx were hidden for everyone)
            if not side or not n.fac or n.fac == side or n.fac == "AH" then npcRow(n, ry, b); ry = ry - 24; shown = shown + 1
            else other = n.fac end
          end
          if shown == 0 then
            local t = dtext("GameFontDisableSmall", 370, b); t:SetPoint("TOPLEFT", 14, ry)
            t:SetText(other == "A" and L["Only sold by Alliance vendors."] or L["Only sold by Horde vendors."]); ry = ry - 18
          end
          ry = ry - 6
        end
        if src.d then
          sub(L["Drops from"] .. ((src.dn and src.dn > #src.d) and "  |cff9d9d9d(" .. string.format(L["%d of %d shown"], #src.d, src.dn) .. ")|r" or ""))
          for _, n in ipairs(src.d) do npcRow(n, ry, b); ry = ry - 24 end
          ry = ry - 6
        end
        if src.qs then
          sub(L["Quest reward"])
          for _, q in ipairs(src.qs) do local qt = dtext("GameFontHighlightSmall", 370, b); qt:SetPoint("TOPLEFT", 14, ry); qt:SetText(q[2]); ry = ry - 18 end
        end
        if not (src.v or src.d or src.qs) then
          local t = dtext("GameFontDisableSmall", 370, b); t:SetPoint("TOPLEFT", 12, ry)
          t:SetText(r.fav and L["Bought with Merchant's Favor - see the Favor pages."] or L["Where this recipe comes from is not known yet."]); ry = ry - 18
        end
        return ry
      end)
    end
    rchild:SetHeight(math.max(1, -y + 10))
    if not keepScroll then rsf:SetVerticalScroll(0) end
  end

  if recipeBar then recipeBar.onChange = function() if selected then showDetail(selected, true) end end end
  redrawDetail = function() if selected then showDetail(selected, true) end end

  local function rowFor(i)
    if rows[i] then return rows[i] end
    local b = CreateFrame("Button", nil, lchild); b:SetSize(298, 26)
    b.card = UI.CardRow(b)
    -- quality bar on the left edge (colour of the crafted item's rarity)
    b.qbar = b:CreateTexture(nil, "BORDER"); b.qbar:SetPoint("TOPLEFT", 2, -3); b.qbar:SetPoint("BOTTOMLEFT", 2, 3); b.qbar:SetWidth(2)
    b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetSize(20, 20); b.icon:SetPoint("LEFT", 7, 0)
    b.name = FLT.NewFS(b, nil, "OVERLAY", "GameFontHighlightSmall"); b.name:SetPoint("LEFT", 32, 0); b.name:SetWidth(150); b.name:SetJustifyH("LEFT"); b.name:SetWordWrap(false)
    b.lvl = FLT.NewFS(b, nil, "OVERLAY", "GameFontHighlightSmall"); b.lvl:SetPoint("RIGHT", -6, 0); b.lvl:SetJustifyH("RIGHT")
    -- character level needed to use the crafted item ("L51"), left of the checks
    b.req = FLT.NewFS(b, nil, "OVERLAY", "GameFontDisableSmall"); b.req:SetPoint("RIGHT", -84, 0); b.req:SetJustifyH("RIGHT")
    -- three check columns side by side: yellow = you, green = guild, blue = other players
    b.checks = {}
    local K = UI.KNOW_COLORS
    local M = UI.KNOW_MARKS
    for k, spec in ipairs({{-66, K.me, M.me}, {-50, K.guild, M.guild}, {-34, K.other, M.other}}) do
      local c = UI.Mark(b, 14, spec[3], unpack(spec[2])); c:SetPoint("RIGHT", spec[1], 0); c:Hide()
      b.checks[k] = c
    end
    b:SetScript("OnClick", function(self, button)
      -- Shift-click links the crafted item in the chat; a normal click selects.
      local r = self.recipe
      if r and IsShiftKeyDown and IsShiftKeyDown() and H and H.handleDungeonItemClick then
        linkRecipe(r, button, H); return
      end
      selected = r; f:Refresh(true); rsf:SetVerticalScroll(0)
    end)
    rows[i] = b
    return b
  end

  local ROW_STEP = 29
  -- Draws the rows that are visible at the current scroll position.
  function f:DrawRows()
    local vis = f.visible
    if not vis then return end
    local skill, knownT = f.visSkill, f.visKnown or {}
    local off = lsf:GetVerticalScroll() or 0
    local viewH = lsf:GetHeight() or 0
    if viewH < 50 then viewH = 900 end -- not laid out yet: draw enough rows
    local first = math.max(1, math.floor(off / ROW_STEP) + 1)
    local last = math.min(#vis, math.ceil((off + viewH) / ROW_STEP) + 1)
    local pl = UnitLevel and UnitLevel("player") or 0
    local used = 0
    for idx = first, last do
      local r = vis[idx]
      used = used + 1
      local b = rowFor(used); b.recipe = r
      b:ClearAllPoints(); b:SetPoint("TOPLEFT", 0, -2 - (idx - 1) * ROW_STEP)
      FLT.SetTex(b.icon, recipeIcon(r))
      local qc = r.i and QCOL[r.q or 1]
      if qc then b.qbar:SetColorTexture(FLT.SkinC(qc[1], qc[2], qc[3], (r.q or 1) <= 1 and 0.45 or 0.95)); b.qbar:Show() else b.qbar:Hide() end
      local d = difficulty(r, skill)
      local pct = skillUpChance(r, d, skill)
      local n = knownT[r.s] and canMake(r) or 0
      b.name:SetText(recipeName(r) .. (n > 0 and (" (" .. n .. ")") or "") .. (pct and ("  " .. pct .. "%") or ""))
      local col = d and DIFF[d] or {0.92, 0.90, 0.84}
      b.name:SetTextColor(FLT.SkinC(col[1], col[2], col[3]))
      -- learn level; "?" when not known yet (6.1.5: the yellow level was shown here and read like the learn level)
      b.lvl:SetText(r.req and tostring(r.req) or "|cff9d9d9d?|r")
      if r.lv then
        b.req:SetText((pl < r.lv and "|cffcc5555" or "|cff8f8f8f") .. "L" .. r.lv .. "|r")
      else
        b.req:SetText("")
      end
      -- yellow = you, green = guild member, blue = other OneForAll user
      b.checks[1]:SetShown(knownT[r.s] and true or false)
      b.checks[2]:SetShown((FLT.GetGuildRecipeKnowers and FLT.GetGuildRecipeKnowers(prof, r.s)) and true or false)
      b.checks[3]:SetShown(onlineOthers(prof, r.s) and true or false)
      b.card:SetSelected(selected == r)
      b:Show()
    end
    for i = used + 1, #rows do rows[i]:Hide() end
  end
  lsf:HookScript("OnVerticalScroll", function() f:DrawRows() end)
  -- the "(n)" you can make follows your bags, but only while the list is open (6.0.1-beta2)
  f:SetScript("OnShow", function(self) self:RegisterEvent("BAG_UPDATE_DELAYED") end)
  f:SetScript("OnHide", function(self) self:UnregisterEvent("BAG_UPDATE_DELAYED") end)
  f:SetScript("OnEvent", function(self) if self:IsVisible() then self:DrawRows() end end)
  lsf:HookScript("OnSizeChanged", function() f:DrawRows() end)

  -- what the detail view of a recipe shows, as a string (see f:Refresh)
  local lastSig
  local sigParts = {}
  local function addKnowers(list)
    for _, g in ipairs(list or {}) do
      sigParts[#sigParts + 1] = tostring(g[1]) .. (g[2] and "+" or "-") .. tostring(g[3]) .. tostring(g[4]) .. tostring(g.level)
    end
  end
  local function detailSig(r)
    wipe(sigParts)
    local p = profDB(prof)
    sigParts[1] = prof .. ":" .. r.s .. (p.known[r.s] and "k" or "") .. (showOffline() and "o" or "") .. tostring(p.skill)
    sigParts[2] = (recipeBar and recipeBar:IsShown()) and "b" or ""
    if FLT.RecipeSearchState then sigParts[3] = tostring((FLT.RecipeSearchState(prof, r.s))) end -- time and button: updateSearchUI
    for _, rg in ipairs(r.r or {}) do sigParts[#sigParts + 1] = GetItemCount and GetItemCount(rg[1], true) or 0 end
    addKnowers(FLT.GetGuildRecipeKnowers and FLT.GetGuildRecipeKnowers(prof, r.s))
    addKnowers(FLT.GetOtherRecipeKnowers and FLT.GetOtherRecipeKnowers(prof, r.s))
    return table.concat(sigParts, "|")
  end

  function f:Refresh(keepScroll)
    if self.otherLegend then
      local on = not FLT.IsRecipeShareEnabled or FLT.IsRecipeShareEnabled()
      self.otherLegend:SetText(L["Other users"] .. " |cff9d9d9d(" .. (on and L["only visible when online"] or L["sharing is off"]) .. ")|r")
    end
    if not prof then return end
    local list = recipesFor(prof)
    local p = profDB(prof)
    local skill = p.skill
    local knownCount = 0
    for _, r in ipairs(list) do if p.known[r.s] then knownCount = knownCount + 1 end end
    local kf = knowFilter()
    title:SetText(L[prof] .. " - " .. (filter == "fav" and L["Favorites"] or knowLabel(kf or "all")))
    FLT.SetTex(profIcon, (FLT.PROFESSION_ICONS and FLT.PROFESSION_ICONS[prof]) or "Interface\\Icons\\INV_Misc_QuestionMark")
    -- The skill comes from the profession book; no skill = not learned on this character.
    meta:SetText((skill and string.format(L["Your skill: %s"], skill .. (p.maxSkill and ("/" .. p.maxSkill) or "")) or "|cff9d9d9d" .. L["Not learned on this character"] .. "|r") ..
      "   |   " .. string.format(L["%d recipes, %d known"], #list, knownCount))
    -- user 05.11.: a quiet note while learn levels are missing (only the trainer tells them; read when you visit one)
    local noLvl = 0
    for _, r in ipairs(list) do if not r.req then noLvl = noLvl + 1 end end
    if skill and not p.scanned then scanHint:SetText(string.format(L["Open your %s window once to mark known recipes"], L[prof]))
    elseif noLvl > 0 then scanHint:SetText("|cff9d9d9d" .. string.format(L["%d learn levels unknown (?) - read at the trainer"], noLvl) .. "|r")
    else scanHint:SetText("") end

    -- Filtered list first (cheap); rows are only drawn for the visible part
    -- (virtual list), so a profession with 500 recipes builds ~20 rows.
    local vis = {}
    for _, r in ipairs(list) do
      local ok = true
      if filter == "missing" and p.known[r.s] then ok = false end
      if filter == "fav" and not isFavorite(prof, r.s) then ok = false end
      if ok and kf then
        local mine = p.known[r.s] and true or false
        if kf == "mine" then ok = mine
        elseif kf == "notmine" then ok = not mine
        else
          local g = FLT.GuildKnowsRecipe and FLT.GuildKnowsRecipe(prof, r.s) or false
          ok = (kf == "guild" and g) or (kf == "both" and (mine or g))
        end
      end
      if ok and search ~= "" then
        local cn = recipeName(r)
        local hay = (r.n .. " " .. (cn ~= r.n and (cn .. " ") or "") .. (r.cat or "") .. " " .. (r.rn or "")):lower()
        if not hay:find(search, 1, true) and not reagentText(r):find(search, 1, true) then ok = false end
      end
      if ok then vis[#vis + 1] = r end
    end
    if filter == "fav" or kf then
      local still = false
      for _, r in ipairs(vis) do if r == selected then still = true end end
      if not still then selected = vis[1] end
    end
    favEmpty:SetText(filter == "fav" and L["No favorites yet. Open a recipe in All recipes and click the star at the top right to add it here."] or L["No recipe for this filter. The funnel next to the search changes it."])
    favEmpty:SetShown((filter == "fav" or kf ~= nil) and #vis == 0)
    f.visible, f.visSkill, f.visKnown = vis, skill, p.known
    lchild:SetHeight(math.max(1, #vis * ROW_STEP + 4))
    if not keepScroll then lsf:SetVerticalScroll(0) end
    f:DrawRows()
    if selected then
      -- rebuild the details only when something in them changed (the frames of a detail view can't be freed; the
      -- browser refreshes once a minute and after search answers)
      local sig = detailSig(selected)
      if sig ~= lastSig or not keepScroll then lastSig = sig; showDetail(selected, keepScroll) else updateSearchUI() end
    else
      lastSig = nil; clearDetail(); if recipeBar then recipeBar:SetRecipe(nil) end
    end
    paintStar()
  end

  function f:ShowProfession(name, mode)
    if FLT.RequestGuildRoster then FLT.RequestGuildRoster() end
    if prof ~= name then selected = nil end
    filter = (mode == "fav") and "fav" or "all"
    prof = name
    readSkillLines()
    local list = recipesFor(prof)
    selected = selected or list[1]
    f:Show(); f:Refresh()
  end

  -- Opens the browser on one recipe (used by the dungeon loot list).
  function f:SelectRecipe(name, spell)
    -- an old search or recipe filter would hide the recipe: clear both first (user 11.11.)
    search = ""
    box:SetText(""); box:ClearFocus()
    if knowFilter() and type(OneForAllDB) == "table" then OneForAllDB.recipeKnowFilter = nil; paintFunnel() end
    f:ShowProfession(name, "all")
    for _, r in ipairs(recipesFor(prof)) do
      if r.s == spell then
        selected = r
        f:Refresh()
        local idx = 1
        for i, v in ipairs(f.visible or {}) do if v == r then idx = i; break end end
        local function scrollTo()
          local range = lsf:GetVerticalScrollRange() or 0
          lsf:SetVerticalScroll(math.max(0, math.min(range, (idx - 1) * 29 - 120)))
        end
        scrollTo()
        -- the first time the tab opens the list has no scroll range yet: once more on the next frame (user 22.10.)
        if C_Timer and C_Timer.After then C_Timer.After(0, function() if selected == r then scrollTo() end end) end
        return true
      end
    end
    f:Refresh()
    return false
  end

  return f
end
