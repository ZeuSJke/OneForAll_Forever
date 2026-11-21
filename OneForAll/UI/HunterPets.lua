local _, FLT = ...
local L = FLT.L or setmetatable({}, { __index = function(_, k) return k end }) -- (tests without Locales)
local function N(s) return s end -- marks an English text translated where it is shown (tools/locale/extract.py)
local UI = FLT.UI
local makeTexture, makeButton = UI.makeTexture, UI.makeButton

-- Hunter Pets tab: pet families, pet abilities (ranks, where to learn them)
-- and notable rare tames. Data: Data/HunterPets.lua.

local FAMILY_ICON = {
  ["Bat"]="Ability_Hunter_Pet_Bat", ["Bear"]="Ability_Hunter_Pet_Bear", ["Boar"]="Ability_Hunter_Pet_Boar",
  ["Carrion Bird"]="Ability_Hunter_Pet_Vulture", ["Cat"]="Ability_Hunter_Pet_Cat", ["Crab"]="Ability_Hunter_Pet_Crab",
  ["Crocolisk"]="Ability_Hunter_Pet_Crocolisk", ["Gorilla"]="Ability_Hunter_Pet_Gorilla", ["Hyena"]="Ability_Hunter_Pet_Hyena",
  ["Owl"]="Ability_Hunter_Pet_Owl", ["Raptor"]="Ability_Hunter_Pet_Raptor", ["Scorpid"]="Ability_Hunter_Pet_Scorpid",
  ["Spider"]="Ability_Hunter_Pet_Spider", ["Tallstrider"]="Ability_Hunter_Pet_TallStrider", ["Turtle"]="Ability_Hunter_Pet_Turtle",
  ["Wind Serpent"]="Ability_Hunter_Pet_WindSerpent", ["Wolf"]="Ability_Hunter_Pet_Wolf",
}
local ABILITY_ICON = {
  ["Bite"]="Ability_Racial_Cannibalize", ["Claw"]="Ability_Druid_Rake", ["Charge"]="Ability_Hunter_Pet_Boar",
  ["Cower"]="Ability_Druid_Cower", ["Dash"]="Ability_Druid_Dash", ["Dive"]="Spell_Shadow_BurningSpirit",
  ["Furious Howl"]="Ability_Hunter_Pet_Wolf", ["Lightning Breath"]="Spell_Nature_Lightning",
  ["Prowl"]="Ability_Druid_SupriseAttack", ["Scorpid Poison"]="Ability_PoisonSting", ["Screech"]="Ability_Hunter_Pet_Bat",
  ["Shell Shield"]="Ability_Hunter_Pet_Turtle", ["Thunderstomp"]="Ability_Hunter_Pet_Gorilla",
  ["Growl"]="Ability_Physical_Taunt", ["Arcane Resistance"]="Spell_Nature_StarFall",
  ["Fire Resistance"]="Spell_Fire_FireArmor", ["Frost Resistance"]="Spell_Frost_FrostWard",
  ["Nature Resistance"]="Spell_Nature_ResistNature", ["Shadow Resistance"]="Spell_Shadow_AntiShadow",
  ["Great Stamina"]="Spell_Nature_UnyeildingStamina", ["Natural Armor"]="Spell_Nature_SpiritArmor",
}
-- Icons come from the data (Petopia icon names); the tables above are fallbacks.
-- 6.2.0: family, ability, diet and role words of Data/HunterPets.lua are shown with L[...]; only the ones whose German
-- client name is known are marked here (the client reports pets and abilities in its language: FLT.EnglishOf maps back)
local function _words() return N"Fox", N"Demoralizing Screech", N"Dismember", N"Lava Breath", N"Mine!", N"Pinch",
  N"Savage Rend", N"Tendon Rip", N"Trickster's Dance", N"Web", N"Bat", N"Bear", N"Bird of Prey", N"Boar", N"Carrion Bird", N"Cat", N"Core Hound", N"Crab",
  N"Crocolisk", N"Gorilla", N"Hyena", N"Raptor", N"Scorpid", N"Spider", N"Tallstrider", N"Turtle", N"Wind Serpent", N"Wolf",
  N"Bite", N"Claw", N"Charge", N"Cower", N"Dash", N"Dive", N"Dust Cloud", N"Furious Howl", N"Lightning Breath", N"Prowl",
  N"Scorpid Poison", N"Shell Shield", N"Swipe", N"Thunderstomp", N"Growl", N"Arcane Resistance", N"Fire Resistance",
  N"Frost Resistance", N"Nature Resistance", N"Shadow Resistance", N"Great Stamina", N"Natural Armor",
  N"Meat", N"Fruit", N"Fish", N"Fungus", N"Bread", N"Cheese", N"Raw Fish", N"Offense", N"Defense", N"General",
  N"Health", N"Armor", N"Damage", N"All families" end
-- data sentences of Data/HunterPets.lua (effects, rank texts, notes, rare tames), shown with FLT.LNum (numbers -> %s)
local function _texts() return {
  N"Increases Arcane Resistance.",
  N"Bite the enemy, causing damage.",
  N"Charges an enemy, immobilizes it for %s sec, and adds melee attack power to the boar's next attack.",
  N"Claw the enemy, causing damage.",
  N"Cower, causing no damage but lowering threat, making the enemy less likely to attack.",
  N"Increases movement speed for %s seconds.",
  N"Blasts a single enemy for damage and lowers the melee attack power of all enemies in melee range. Effect lasts %s sec.",
  N"Viciously bites enemy appendages for damage and reduces the effectiveness of any healing by %s%% for %s sec.",
  N"Your tallstrider kicks up an abrasive cloud of dust, reducing the target's Armor for %s sec.",
  N"Increases Fire Resistance.",
  N"Increases Frost Resistance.",
  N"The wolf howls, increasing the melee attack power of all party members within %s yards.  Lasts %s min.",
  N"Stamina increased.",
  N"Taunt the target, increasing the likelihood the creature will focus attacks on your pet.",
  N"Breathes molten lava at %s nearby enemies, instantly dealing Fire damage and reducing the target's casting speed by %s%% for %s sec.",
  N"Breathes lightning, instantly dealing Nature damage to a single target.",
  N"Grabs an enemy's weapon with its talons, causing damage and disarming them for %s sec.",
  N"Armor increased.",
  N"Increases Nature Resistance.",
  N"Pinches an enemy's legs for damage and reduces movement speed by %s%% for %s sec.",
  N"Puts your pet in stealth mode, but slows its movement speed. The first attack from stealth receives a bonus to damage. Lasts until cancelled.",
  N"Slash an enemy with razor talons, causing the target to Bleed for damage over %s sec.",
  N"Inflicts Nature damage over %s sec. Effect can stack up to %s times on a single target.",
  N"Increases Shadow Resistance.",
  N"Reduces all damage your pet takes by %s%% and increases the time between your pet's attacks by %s%%, but deals more damage with each attack. Lasts %s sec.",
  N"Swipe %s nearby enemies, inflicting damage.",
  N"Tears at an enemy's legs for damage over %s sec and reduces movement speed by %s%% for %s sec.",
  N"Shakes the ground with thundering force, doing Nature damage to all enemies within %s yards.",
  N"Increases your pet's chance to Dodge by %s%% and decreases the time between your pet's attacks by %s%%. Lasts %s sec.",
  N"Entangles an enemy in a corrosive web, immobilizing them and dealing Nature damage over %s sec.",
  N"Increases Arcane Resistance by %s.",
  N"Bite the enemy, causing %s to %s damage.",
  N"Charges an enemy, immobilizes it for %s sec, and adds %s melee attack power to the boar's next attack.",
  N"Claw the enemy, causing %s to %s damage.",
  N"Increases movement speed by %s%% for %s seconds.",
  N"Blasts a single enemy for %s to %s damage and lowers the melee attack power of all enemies in melee range by %s. Effect lasts %s sec.",
  N"Viciously bites enemy appendages for %s to %s damage and reduces the effectiveness of any healing by %s%% for %s sec.",
  N"Your tallstrider kicks up an abrasive cloud of dust, reducing the target's Armor by %s for %s sec.",
  N"Increases Fire Resistance by %s.",
  N"Increases Frost Resistance by %s.",
  N"The wolf howls, increasing the melee attack power of all party members within %s yards by %s.  Lasts %s min.",
  N"The wolf howls, increasing the melee attack power of all party members within %s yards by %s to %s.  Lasts %s min.",
  N"Stamina increased by %s.",
  N"Breathes molten lava at %s nearby enemies, instantly dealing %s to %s Fire damage and reducing the target's casting speed by %s%% for %s sec.",
  N"Breathes lightning, instantly dealing %s to %s Nature damage to a single target.",
  N"Grabs an enemy's weapon with its talons, causing %s to %s damage and disarming them for %s sec.",
  N"Armor increased by %s.",
  N"Increases Nature Resistance by %s.",
  N"Pinches an enemy's legs for %s to %s damage and reduces movement speed by %s%% for %s sec.",
  N"Puts your pet in stealth mode, but slows its movement speed by %s%%. The first attack from stealth receives a %s%% bonus to damage. Lasts until cancelled.",
  N"Slash an enemy with razor talons, causing the target to Bleed for %s damage over %s sec.",
  N"Inflicts %s Nature damage over %s sec. Effect can stack up to %s times on a single target.",
  N"Increases Shadow Resistance by %s.",
  N"Swipe %s nearby enemies, inflicting %s damage.",
  N"Swipe %s nearby enemies, inflicting %s to %s damage.",
  N"Tears at an enemy's legs for %s damage over %s sec and reduces movement speed by %s%% for %s sec.",
  N"Shakes the ground with thundering force, doing %s to %s Nature damage to all enemies within %s yards.",
  N"Entangles an enemy in a corrosive web, immobilizing them and dealing %s Nature damage over %s sec.",
  N"Only family with %s.",
  N"White lion skin; marked as a spawned (not always present) mob.",
  N"Rare spawn; only tameable black lion; fast %s attack speed.",
  N"Translucent ghostly cat summoned from cat figurines at Ruins of Mathystra; keeps its look after taming; teaches Claw %s.",
  N"Rare spawned nightsaber with spotted black skin.",
  N"Named cat; teaches Dash %s.",
  N"Named panther; teaches Dash %s.",
  N"Elite striped white tiger; teaches Claw %s and Dash %s.",
  N"Rare aqua-colored saber cat; teaches Dash %s.",
  N"Elite aqua saber cat.",
  N"Spawned elite white lion.",
  N"Only tameable lavender saber cat.",
  N"Red raptor summoned via a quest (spawned).",
  N"Named tallstrider; teaches Cower %s.",
  N"Rare red vulture.",
  N"Rare red carrion bird; teaches Dive %s.",
  N"Rare elite red carrion bird; teaches Dive %s.",
  N"Rare white wind serpent.",
  N"Rare white wind serpent; teaches Dive %s and Lightning Breath %s.",
  N"Rare red gorilla.",
  N"Rare-listed white gorilla; teaches Bite %s.",
  N"Named red gorilla; teaches Thunderstomp %s.",
  N"Rare white crocolisk found in the Stormwind canals; teaches Bite %s.",
  N"Named white crocolisk; teaches Bite %s.",
  N"Named wolf; teaches Bite %s.",
  N"Named wolf; teaches Bite %s and Dash %s.",
  N"Named wolf; teaches Bite %s and Furious Howl %s.",
  N"Named bear; teaches Claw %s.",
  N"Named bird of prey; teaches Claw %s and Dive %s.",
  N"Named spider; teaches Bite %s.",
  N"Named turtle; teaches Bite %s and Shell Shield %s.",
} end
local LN = FLT.LNum or function(t) return t end
local ZN = FLT.ZoneName or function(z) return z end
local NM = FLT.Name or function(n) return n end -- beast names in the client's language (6.2.0 step 2b)
local EN = FLT.EnglishOf or function(w) return w end -- client word (German client) -> our English data name
local function tlist(list, sep) -- a list of data words, translated
  local out = {}
  for i, w in ipairs(list or {}) do out[i] = L[w] end
  return table.concat(out, sep or ", ")
end
-- a beast on the world map: the pin and, when known, the outline of its spawns (6.1.9, user 07.11.: "mehrere
-- Koordinaten ... zu einer Linie verbinden, um ein Gebiet abzudecken"; Data/HunterPetTames.lua PET_TAME_AREAS)
local function showBeast(b)
  local a = b.npcID and FLT.PET_TAME_AREAS and FLT.PET_TAME_AREAS[b.npcID]
  FLT:ShowOnMap({ mapID = b.mapID, x = b.x, y = b.y, zone = b.zone, name = b.name, area = (a and a[1] == b.mapID) and a[2] or nil })
end
local dataIcon = {}
local function icon(map, name)
  return "Interface\\Icons\\" .. (dataIcon[name] or map[name] or "INV_Misc_QuestionMark")
end
local function indexIcons()
  for _, f in ipairs(FLT.PET_FAMILIES or {}) do if f.icon then dataIcon[f.name] = f.icon end end
  for _, a in ipairs(FLT.PET_ABILITIES or {}) do if a.icon then dataIcon[a.name] = a.icon end end
end

-- Round portrait look (like the boss portraits): circular alpha mask, with
-- SetPortraitToTexture as fallback on clients without mask textures.
local function makeRound(parentFrame, tex, path)
  if tex.AddMaskTexture and parentFrame.CreateMaskTexture then
    FLT.SetTex(tex, path)
    local mask = parentFrame:CreateMaskTexture()
    FLT.SetTex(mask, "Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(tex)
    tex:AddMaskTexture(mask)
  elseif SetPortraitToTexture then
    SetPortraitToTexture(tex, path)
  else
    FLT.SetTex(tex, path)
  end
end

local GOLD = {1, 0.82, 0.20}
local LIST_W, ROW_W = 302, 298 -- ht7: the list is narrower (the modes are a side list now)

-- Known pet abilities ---------------------------------------------------------
-- Hunters keep every pet ability rank they have learned; it is listed in the
-- Beast Training window. We read that window when it opens, plus the active
-- pet's spellbook, and store the highest known rank per ability per character
-- (OneForAllCharDB.petAbilities[ability] = { [rank] = true, ... }: every rank on its own - learning rank 4 does not teach
-- ranks 1-3; 6.2.11, user 17.11. Up to 6.2.10 a number = the highest rank, read as "only that rank".)
local petUI -- set by the panel; refreshed after a scan

local function knownTable()
  if type(OneForAllCharDB) ~= "table" then return nil end
  OneForAllCharDB.petAbilities = OneForAllCharDB.petAbilities or {}
  return OneForAllCharDB.petAbilities
end

local function rankSet(v) -- a stored entry as { [rank] = true } (an old number = only that rank)
  if type(v) == "table" then return v end
  if type(v) == "number" and v > 0 then return { [v] = true } end
end
local function rankNumber(sub)
  return tonumber(type(sub) == "string" and sub:match("(%d+)") or nil) or 1
end

-- One spell ID per pet ability (all ranks share the name), from the Forever client (wago SkillLineAbility, the
-- hunter "Pet - <family>" skill lines, 1.60.1). The client names the spell in its own language, so this maps the
-- word back to our English name also for languages we have no translation for (Discord andrei_al 09.11.: Claw
-- rank 4 not seen on a Russian client).
local PET_SPELL = {
  ["Arcane Resistance"] = 24493, Bite = 17253, Charge = 7371, Claw = 16827, Cower = 1742, Dash = 23099,
  ["Demoralizing Screech"] = 24423, Dismember = 1264758, Dive = 23145, ["Dust Cloud"] = 1265899,
  ["Fire Resistance"] = 23992, ["Frost Resistance"] = 24446, ["Furious Howl"] = 24597, ["Great Stamina"] = 4187,
  Growl = 2649, ["Lava Breath"] = 444678, ["Lightning Breath"] = 24844, ["Mine!"] = 1265054, ["Natural Armor"] = 24545,
  ["Nature Resistance"] = 24492, Pinch = 1264735, Prowl = 24450, ["Savage Rend"] = 1265065, ["Scorpid Poison"] = 24583,
  ["Shadow Resistance"] = 24488, ["Shell Shield"] = 26064, Swipe = 1264494, ["Tendon Rip"] = 1265038,
  Thunderstomp = 26090, ["Trickster's Dance"] = 1310612, Web = 1265843,
}
FLT.PET_ABILITY_SPELL = PET_SPELL -- (for the tests)
local byClient -- the client's ability name -> English, made when first needed
local function abilityEN(name)
  local en = EN(name) -- the German client names the ability in German
  if PET_SPELL[en] then return en end
  if not byClient then
    byClient = {}
    for e, id in pairs(PET_SPELL) do
      local n
      pcall(function() n = (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)) or (GetSpellInfo and GetSpellInfo(id)) end)
      if type(n) == "string" and n ~= "" then byClient[n] = e end
    end
    -- ranks an older version stored under the client's own word: move them to the English name
    local t, move = knownTable(), nil
    for k, r in pairs(t or {}) do
      if byClient[k] and byClient[k] ~= k then move = move or {}; move[k] = r end
    end
    for k, r in pairs(move or {}) do
      local e = byClient[k]
      if t[e] == nil then t[e] = r end
      t[k] = nil
    end
  end
  return byClient[name] or en
end

-- the highest known rank (0 = none)
function FLT:GetKnownPetRank(name)
  local set, best = rankSet(knownTable() and knownTable()[name]), 0
  for r in pairs(set or {}) do if r > best then best = r end end
  return best
end
function FLT:HasPetRank(name, rank)
  local set = rankSet(knownTable() and knownTable()[name])
  return set and set[rank or 1] and true or false
end
function FLT:CountPetRanks(name)
  local n = 0
  for _ in pairs(rankSet(knownTable() and knownTable()[name]) or {}) do n = n + 1 end
  return n
end

local function scanBeastTraining()
  if not (GetNumCrafts and GetCraftInfo) then return end
  local line = GetCraftDisplaySkillLine and GetCraftDisplaySkillLine()
  -- the window's name in the client's language: the Beast Training spell (5149) names it (6.2.0)
  local own
  pcall(function() own = (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(5149)) or (GetSpellInfo and GetSpellInfo(5149)) end)
  if line and line ~= "Beast Training" and line ~= (BEAST_TRAINING or "") and line ~= own then return end
  -- each rank on its own. 6.2.12-beta23 (Discord Oleum 18.11.: "learned all the skills up to Rank 4, but the addon still shows
  -- that I only have Bite Rank 3"): the window only lists what fits the CURRENT pet (family, level, what it knows), so its
  -- ranks are ADDED to the stored ones - 6.2.11 replaced them and lost the rest. Only an old number (up to 6.2.10, from the
  -- pet's spellbook - maybe never learned) is still replaced.
  local changed, t, seen = false, knownTable(), {}
  for i = 1, GetNumCrafts() or 0 do
    local name, sub, kind = GetCraftInfo(i)
    if name and kind ~= "header" and name ~= "" then
      local en = abilityEN(name)
      seen[en] = seen[en] or {}; seen[en][rankNumber(sub)] = true
    end
  end
  for en, set in pairs(seen) do
    if t then
      local old = type(t[en]) == "table" and t[en] or nil
      if not old then t[en] = set; changed = true
      else for r in pairs(set) do if not old[r] then old[r] = true; changed = true end end end
    end
  end
  if knownTable() then OneForAllCharDB.petAbilitiesScanned = true end
  if petUI and petUI.refreshKnown then petUI.refreshKnown() end
  return changed
end

-- Pet spellbook (for the teacher alert: abilities the active pet has): the Forever client uses the modern C_SpellBook API (new
-- spellbook with search box); older clients have the global functions.
local function petSpellCount()
  if C_SpellBook and C_SpellBook.HasPetSpells then
    local ok, n = pcall(C_SpellBook.HasPetSpells)
    if ok and n then return n end
  end
  if HasPetSpells then local ok, n = pcall(HasPetSpells); if ok then return n end end
  return nil
end

local function petSpellName(i)
  if C_SpellBook then
    local bank = (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Pet) or 1
    if C_SpellBook.GetSpellBookItemName then
      local ok, name, sub = pcall(C_SpellBook.GetSpellBookItemName, i, bank)
      if ok and name then return name, sub end
    end
    if C_SpellBook.GetSpellBookItemInfo then
      local ok, info = pcall(C_SpellBook.GetSpellBookItemInfo, i, bank)
      if ok and type(info) == "table" and info.name then return info.name, info.subName end
    end
  end
  if GetSpellBookItemName then
    local ok, name, sub = pcall(GetSpellBookItemName, i, BOOKTYPE_PET or "pet")
    if ok and name then return name, sub end
  end
  if GetSpellName then
    local ok, name, sub = pcall(GetSpellName, i, BOOKTYPE_PET or "pet")
    if ok and name then return name, sub end
  end
end

-- a rank learned right now (6.2.12-beta23, Discord Xynum / Kiske 19.11.: tamed, used, but not shown): the game's message "You have
-- learned a new ability: Swipe (Rank 3)." (and the pet's "has learned" when it is taught) - no window needed. Patterns from the
-- client's own texts, so every language works; only names of pet abilities count.
-- beta26 (tester Deaders 19.11.: "[Demoralizing Screech]" not registered at all - the message has no rank and the client gives
-- no rank subtext): the Beast Training spell IDs of every rank (Data/HunterPetSpells.lua, from the client) tell ability and rank
local function addKnownRank(en, r)
  local t = knownTable()
  if not (t and en and r and PET_SPELL[en]) then return false end
  local set = type(t[en]) == "table" and t[en] or {}
  if set[r] then return false end
  set[r] = true; t[en] = set
  return true
end
local function notePetSpell(sid)
  local e = sid and FLT.PET_TEACH_SPELLS and FLT.PET_TEACH_SPELLS[sid]
  if not e then return false end
  if addKnownRank(e[1], e[2]) and petUI and petUI.refreshKnown then petUI.refreshKnown() end
  return true
end
-- every rank the hunter knows, straight from the game (IsPlayerSpell on those IDs) - only ever adds; ignored when the answer
-- is "yes" for nearly everything (then the function does not know these spells)
local function scanKnownSpells()
  local T = FLT.PET_TEACH_SPELLS
  if not (T and IsPlayerSpell) then return end
  local hits, all = {}, 0
  for sid, e in pairs(T) do
    all = all + 1
    local ok, known = pcall(IsPlayerSpell, sid)
    if ok and known and not FLT.IsSecret(known) then hits[#hits + 1] = e end
  end
  if all == 0 or #hits > all * 0.9 then return end
  local changed = false
  for _, e in ipairs(hits) do if addKnownRank(e[1], e[2]) then changed = true end end
  if changed and petUI and petUI.refreshKnown then petUI.refreshKnown() end
end
FLT._petScanKnownSpells = scanKnownSpells -- tests
local scanPending
local function scanKnownSoon()
  if scanPending or not C_Timer then return end
  scanPending = true
  C_Timer.After(1, function() scanPending = nil; scanKnownSpells() end)
end
local learnPatterns
local function noteLearnMessage(msg)
  if type(msg) ~= "string" or FLT.IsSecret(msg) then return end
  if not learnPatterns then
    learnPatterns = {}
    for _, g in ipairs({ "ERR_LEARN_ABILITY_S", "ERR_LEARN_SPELL_S", "ERR_PET_LEARN_ABILITY_S", "ERR_PET_LEARN_SPELL_S" }) do
      local f = _G[g]
      if type(f) == "string" and f:find("%s", 1, true) then
        learnPatterns[#learnPatterns + 1] = "^" .. f:gsub("[%(%)%.%[%]%*%+%-%?%^%$]", "%%%0"):gsub("%%s", "(.+)") .. "$"
      end
    end
  end
  for _, pat in ipairs(learnPatterns) do
    local what = msg:match(pat)
    if what then
      local sid = tonumber(what:match("|Hspell:(%d+)"))
      if notePetSpell(sid) then return end
      what = what:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H[^|]*|h", ""):gsub("|h", "")
      local name, sub = what:match("^%[?(.-)%]?%s*%((.-)%)%]?$")
      name = name or what:match("^%[?(.-)%]?$")
      local en = name and abilityEN(name)
      local t = knownTable()
      if en and PET_SPELL[en] and t then
        -- beta25 (tester Deaders 19.11.: the Forever client says "You have learned a new spell: [Charge]." - no rank, the old
        -- code took rank 1 although a Goretusk teaches rank 2): the rank from the text, else from the linked spell's subtext
        -- ("Rank 2"), else rank 1 only for an ability with one rank - otherwise nothing (Beast Training reads it later)
        local r = sub and sub:match("%d") and rankNumber(sub)
        if not r and sid then
          local st = C_Spell and C_Spell.GetSpellSubtext and C_Spell.GetSpellSubtext(sid)
          if not st and GetSpellSubtext then st = GetSpellSubtext(sid) end
          if type(st) == "string" and not FLT.IsSecret(st) and st:match("%d") then r = rankNumber(st) end
        end
        if not r then
          local n = 0
          for _, a in ipairs(FLT.PET_ABILITIES or {}) do if a.name == en then n = #(a.ranks or {}) end end
          if n <= 1 then r = 1 end
        end
        if not r then return end
        local set = type(t[en]) == "table" and t[en] or {}
        if not set[r] then set[r] = true; t[en] = set; if petUI and petUI.refreshKnown then petUI.refreshKnown() end end
      end
      return
    end
  end
end
FLT._petLearnMessage = noteLearnMessage -- tests
-- right-click on a rank in the Hunter Pets tab (6.2.12-beta23): mark it learned / not learned yourself (ranks learned before
-- 6.2.11 that Beast Training never lists for a higher pet)
function FLT:TogglePetRank(name, rank)
  local t = knownTable()
  if not (t and name and rank) then return end
  local set = rankSet(t[name]) or {}
  if set[rank] then set[rank] = nil else set[rank] = true end
  t[name] = next(set) and set or nil
  if petUI and petUI.refreshKnown then petUI.refreshKnown() end
end

-- The pet's spellbook is not read for known ranks any more (6.2.11, Discord jontasson 16.11.): a freshly tamed pet lists its abilities
-- there before the hunter has learned them (the pet has to use them first), so only Beast Training counts.
FLT.ScanPetAbilities = function() scanBeastTraining() end

-- Stabled pets are only readable while the stable master window is open, so
-- the last seen list is stored per character (OneForAllCharDB.stablePets).
local FAMILY_ALIAS_GLOBAL = { ["Owl"] = "Bird of Prey", ["Eule"] = "Bird of Prey" }
local function scanStable()
  if type(OneForAllCharDB) ~= "table" then return end
  local list = {}
  local function add(name, level, family)
    if name and family then list[#list + 1] = { name = name, level = level, family = FAMILY_ALIAS_GLOBAL[family] or EN(family) } end
  end
  if C_StableInfo and C_StableInfo.GetStablePetInfo then
    for i = 1, 10 do
      local ok, info = pcall(C_StableInfo.GetStablePetInfo, i)
      if ok and type(info) == "table" then add(info.name, info.level, info.familyName or info.family) end
    end
  elseif GetStablePetInfo then
    local slots = (GetNumStableSlots and GetNumStableSlots()) or 2
    for i = 1, math.max(slots, 2) do
      local ok, _, name, level, family = pcall(GetStablePetInfo, i)
      if ok then add(name, level, family) end
    end
  else
    return
  end
  OneForAllCharDB.stablePets = list
  if petUI and petUI.refreshKnown then petUI.refreshKnown() end
end

function FLT:GetStabledPets()
  return type(OneForAllCharDB) == "table" and OneForAllCharDB.stablePets or {}
end

-- Nearby teacher alert ---------------------------------------------------------
-- When a tameable beast shows up (nameplate, target or mouseover) that teaches
-- an ability rank higher than you know, and that ability can be learned by the
-- family of your active pet or a stabled pet, show an alert.
local teacherIndex
local alerted = {}
local ALERT_REPEAT = 900 -- seconds before the same beast may alert again

function FLT:IsPetTeachAlertsEnabled()
  return not (type(OneForAllDB) == "table" and OneForAllDB.petTeachAlerts == false)
end
function FLT:SetPetTeachAlertsEnabled(v)
  if type(OneForAllDB) == "table" then OneForAllDB.petTeachAlerts = v and true or false end
end

-- Abilities that never trigger the alert (OneForAllDB.petAlertIgnore).
-- Cower is hardly ever trained, so it is ignored by default.
local DEFAULT_IGNORE = { ["Cower"] = true }
local function ignoreTable()
  if type(OneForAllDB) ~= "table" then return DEFAULT_IGNORE end
  if not OneForAllDB.petAlertIgnore then
    OneForAllDB.petAlertIgnore = {}
    for k in pairs(DEFAULT_IGNORE) do OneForAllDB.petAlertIgnore[k] = true end
  end
  return OneForAllDB.petAlertIgnore
end
function FLT:IsPetAlertIgnored(name) return ignoreTable()[name] and true or false end
function FLT:SetPetAlertIgnored(name, ignored)
  ignoreTable()[name] = ignored and true or nil
  if petUI and petUI.refreshKnown then petUI.refreshKnown() end
end

local function buildTeacherIndex()
  teacherIndex = {}
  for _, a in ipairs(FLT.PET_ABILITIES or {}) do
    for _, r in ipairs(a.ranks or {}) do
      for _, b in ipairs(r.learnFrom or {}) do
        if b.npcID then
          teacherIndex[b.npcID] = teacherIndex[b.npcID] or {}
          table.insert(teacherIndex[b.npcID], { ability = a, rank = r, beast = b })
        end
      end
    end
  end
end

local function myPetFamilies()
  local fams = {}
  if UnitExists and UnitExists("pet") and UnitCreatureFamily then
    local fam = UnitCreatureFamily("pet")
    if fam then fam = FAMILY_ALIAS_GLOBAL[fam] or EN(fam); fams[fam] = (UnitName and UnitName("pet")) or L["your pet"] end
  end
  for _, sp in ipairs(FLT:GetStabledPets()) do
    if sp.family and not fams[sp.family] then fams[sp.family] = (sp.name or "?") .. ", " .. L["stable"] end
  end
  return fams
end

local function abilityFits(a, fams)
  local out = {}
  for _, fam in ipairs(a.families or {}) do
    if fam == "All families" then
      for f, who in pairs(fams) do out[#out + 1] = L[f] .. " (" .. who .. ")" end
      return out
    elseif fams[fam] then
      out[#out + 1] = L[fam] .. " (" .. fams[fam] .. ")"
    end
  end
  return out
end

local function npcIDFromGUID(guid)
  -- GUIDs can be secret (e.g. nameplates in dungeons, Discord 05.11.: Hall of Thanes): nothing to read then
  if type(guid) ~= "string" or FLT.IsSecret(guid) then return nil end
  local kind, _, _, _, _, id = strsplit("-", guid)
  if kind ~= "Creature" then return nil end
  return tonumber(id)
end

local snoozeUntil = 0

-- The level-10 taming quest gives a "Taming Rod" and a temporary pet that
-- knows nothing yet, so every teacher would trigger a popup. Stay quiet while
-- a rod is in the bags (and below level 10, before any pet is possible).
local TAMING_RODS = { [15908]=true, [15911]=true, [15913]=true, [15914]=true, [15915]=true, [15916]=true,
  [15917]=true, [15919]=true, [15920]=true, [15921]=true, [15922]=true, [15923]=true }
local rodCheckAt, rodCached = -10, false
local function hasTamingRod()
  local now = GetTime and GetTime() or 0
  if now - rodCheckAt < 3 then return rodCached end
  rodCheckAt = now
  local numSlots = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
  local itemLink = (C_Container and C_Container.GetContainerItemLink) or GetContainerItemLink
  local found = false
  if type(numSlots) == "function" and type(itemLink) == "function" then
    for bag = 0, 4 do
      local ok, n = pcall(numSlots, bag)
      for slot = 1, (ok and tonumber(n) or 0) do
        local ok2, link = pcall(itemLink, bag, slot)
        if ok2 and type(link) == "string" then
          local id = tonumber(link:match("item:(%d+)"))
          if (id and TAMING_RODS[id]) or link:find("%[Taming Rod%]") then found = true; break end
        end
      end
      if found then break end
    end
  end
  rodCached = found
  return found
end

-- A freshly tamed pet already knows its abilities; the hunter learns them only
-- after the pet has used them a few times. Stay quiet for abilities the
-- active pet has, and for more beasts of the kind that was just tamed.
local lastTamedNpc
local function activePetRank(abilityName)
  local n = petSpellCount()
  if not n or n == 0 then return nil end
  for i = 1, n do
    local name, sub = petSpellName(i)
    if name == abilityName then return rankNumber(sub) end
  end
  return nil
end

-- Hunters get their first pet at level 10 (after the taming quest).
local function canHavePet()
  local lvl = UnitLevel and UnitLevel("player")
  return not (lvl and lvl > 0 and lvl < 10)
end

local function checkTeacher(unit)
  if not FLT:IsPetTeachAlertsEnabled() or not FLT.ShowAlert then return end
  if (GetTime and GetTime() or 0) < snoozeUntil then return end
  if not canHavePet() or hasTamingRod() then return end
  if IsInInstance and IsInInstance() then return end -- no pet teachers in dungeons
  if not (UnitExists and UnitExists(unit)) or (UnitIsDead and UnitIsDead(unit)) then return end
  local npcID = npcIDFromGUID(UnitGUID and UnitGUID(unit))
  if not npcID then return end
  if not teacherIndex then buildTeacherIndex() end
  local entries = teacherIndex[npcID]
  if not entries then return end
  local now = GetTime and GetTime() or 0
  if alerted[npcID] and now - alerted[npcID] < ALERT_REPEAT then return end
  -- You can only tame beasts up to your own level.
  local ul, pl = UnitLevel and UnitLevel(unit), UnitLevel and UnitLevel("player")
  if ul and pl and ul > 0 and ul > pl then return end
  local fams = myPetFamilies()
  if not next(fams) then return end
  local best
  -- a rank above the highest known; with the switch also a missing lower one (6.2.11, user 17.11., off by default)
  local lower = FLT.QoL and FLT.QoL.Get("petAlertLower")
  for _, e in ipairs(entries) do
    local rk, name = e.rank.rank or 1, e.ability.name
    local known = FLT:GetKnownPetRank(name)
    if (rk > known or (lower and not FLT:HasPetRank(name, rk))) and not FLT:IsPetAlertIgnored(name) then
      local fits = abilityFits(e.ability, fams)
      if #fits > 0 and (not best or rk > best.e.rank.rank) then best = { e = e, known = known, fits = fits } end
    end
  end
  if not best then return end
  if lastTamedNpc == npcID and UnitExists and UnitExists("pet") then return end
  local petRank, brk = activePetRank(best.e.ability.name), best.e.rank.rank or 1
  -- the active pet already has it (a higher rank on the pet does not teach a lower one)
  if petRank and (petRank == brk or (brk > best.known and petRank >= brk)) then return end
  alerted[npcID] = now
  local e = best.e
  local guid = UnitGUID and UnitGUID(unit)
  local beastName = (UnitName and UnitName(unit)) or e.beast.name
  FLT:ShowAlert({
    eyebrow = L["PET ABILITY NEARBY"],
    icon = "Interface\\Icons\\" .. (e.ability.icon or "INV_Misc_QuestionMark"),
    title = string.format(L["%s teaches %s %d"], (UnitName and UnitName(unit)) or e.beast.name or "?", L[e.ability.name], e.rank.rank or 1),
    where = string.format(L["You know %s. For: %s"],
      best.known > 0 and string.format(L["rank %s"], best.known) or L["no rank yet"], table.concat(best.fits, ", ")),
    buttons = {
      { text = L["Target"], keepOpen = true, secureMacro = "/targetexact " .. (beastName or "") },
      { text = L["Snooze 15 min"], onClick = function()
        snoozeUntil = (GetTime and GetTime() or 0) + 900
        if FLT.Msg then FLT.Msg(L["Pet ability alerts paused for 15 minutes."]) end
      end },
      { text = string.format(L["Ignore %s"], L[e.ability.name]), onClick = function()
        FLT:SetPetAlertIgnored(e.ability.name, true)
        if FLT.Msg then FLT.Msg(string.format(L["%s no longer triggers pet alerts. Re-enable it in Hunter Pets > Abilities."], L[e.ability.name])) end
      end },
    },
  })
end

do
  local ev = CreateFrame("Frame")
  ev:RegisterEvent("PLAYER_LOGIN")
  ev:SetScript("OnEvent", function(self, event, arg1, arg2, arg3)
    if event == "PLAYER_LOGIN" then
      local _, cls = UnitClass("player")
      if cls ~= "HUNTER" then self:UnregisterAllEvents(); return end
      pcall(self.RegisterUnitEvent or self.RegisterEvent, self, "UNIT_SPELLCAST_START", "player")
      for _, e in ipairs({"CRAFT_SHOW", "CRAFT_UPDATE", "UNIT_PET", "PET_STABLE_SHOW", "PET_STABLE_UPDATE", "NAME_PLATE_UNIT_ADDED", "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT", "CHAT_MSG_SYSTEM",
        "LEARNED_SPELL_IN_TAB", "LEARNED_SPELL_IN_SKILL_LINE", "SPELLS_CHANGED"}) do pcall(self.RegisterEvent, self, e) end
      if C_Timer then C_Timer.After(3, scanKnownSpells) end -- beta26: every known rank at login
    elseif event == "LEARNED_SPELL_IN_TAB" or event == "LEARNED_SPELL_IN_SKILL_LINE" then
      if not notePetSpell(arg1) then scanKnownSoon() end
    elseif event == "SPELLS_CHANGED" then -- (debounced: one scan a second at most)
      scanKnownSoon()
    elseif event == "CHAT_MSG_SYSTEM" then -- (hunters only; a short match per system message)
      noteLearnMessage(arg1)
    elseif event == "CRAFT_SHOW" or event == "CRAFT_UPDATE" then
      scanBeastTraining()
    elseif event == "PET_STABLE_SHOW" or event == "PET_STABLE_UPDATE" then
      scanStable()
    elseif event == "UNIT_SPELLCAST_START" then
      local spellID = arg3
      if FLT.IsSecret(spellID) then return end
      local name = GetSpellInfo and spellID and GetSpellInfo(spellID)
      if spellID == 1515 or name == "Tame Beast" then lastTamedNpc = npcIDFromGUID(UnitGUID and UnitGUID("target")) end
    elseif event == "NAME_PLATE_UNIT_ADDED" then
      checkTeacher(arg1)
    elseif event == "PLAYER_TARGET_CHANGED" then
      checkTeacher("target")
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
      checkTeacher("mouseover")
    else -- UNIT_PET: the active pet's family is marked
      if petUI and petUI.refreshKnown then petUI.refreshKnown() end
    end
  end)
end

local function createPetsPanel(parent)
  local panel = CreateFrame("Frame", nil, parent)
  UI.PlacePanel(panel, parent)
  UI.TitleBand(panel, { emblem = UI.ASSET_ROOT .. "emblem_pets", art = UI.ASSET_ROOT .. "pets_banner",
    title = L["Hunter Pets"], subtitle = L["Pet families, abilities with every rank and where to learn them, and notable rare tames."], fadeRight = 120 })

  -- ht7 (user 30.10.): the three modes as a side list like the other tabs (emblem and name on top)
  local modeButtons = {}
  local modes = { {key="families", label=N"Families", icon="Interface\\Icons\\Ability_Hunter_BeastTaming"},
    {key="abilities", label=N"Abilities", icon="Interface\\Icons\\Ability_Hunter_BeastTraining"},
    {key="rares", label=N"Rare Tames", icon="Interface\\Icons\\INV_Misc_Head_Tiger_01"} }
  local nav, navY = UI.SideNav(panel, -74, "emblem_pets", L["Hunter Pets"]) -- ht8: the same side list in every tab
  for _, m in ipairs(modes) do
    local b; b, navY = UI.NavEntry(nav, navY, L[m.label], m.icon)
    modeButtons[m.key] = b
  end

  local body = CreateFrame("Frame", nil, panel)
  body:SetPoint("TOPLEFT", 182, -74); body:SetPoint("BOTTOMRIGHT", -8, 4)
  -- head like Quality of Life (user 31.10.): icon, mode name, one line, a search over all three modes
  local runSearch -- below
  local head = UI.PageHeader(body, { placeholder = L["Search families, abilities, beasts..."], onSearch = function(t) if runSearch then runSearch(t) end end })
  local MODE_HEAD = {
    families = { "Interface\\Icons\\Ability_Hunter_BeastTaming", N"Families", N"Diet, role and abilities of every pet family, and where to tame one." },
    abilities = { "Interface\\Icons\\Ability_Hunter_BeastTraining", N"Abilities", N"Every rank of the pet abilities and the beasts that teach them." },
    rares = { "Interface\\Icons\\INV_Misc_Head_Tiger_01", N"Rare Tames", N"Notable rare beasts worth taming and where to find them." },
  }
  local function place(view) view:SetPoint("TOPLEFT", 0, -60); view:SetPoint("BOTTOMRIGHT") end -- below the head

  local function text(parentFrame, template, w)
    local f = FLT.NewFS(parentFrame, nil, "OVERLAY", template or "GameFontHighlight")
    if w then f:SetWidth(w); f:SetJustifyH("LEFT") end
    return f
  end

  -- A "where" line with a Map button for beasts that have coordinates.
  local function beastRow(parentFrame, b, y, width)
    local row = CreateFrame("Frame", nil, parentFrame); row:SetSize(width, 24); row:SetPoint("TOPLEFT", 0, y)
    local t = text(row, "GameFontHighlightSmall", width - 70); t:SetPoint("LEFT", 6, 0)
    t:SetText(string.format("%s  |cff9d9d9d(%s)|r  -  %s", NM(b.name) or "?", b.level or "?", ZN(b.zone) or "?"))
    if b.mapID and b.x and b.y then
      local mb = UI.GoldButton(row, L["Map"], 64, 20, UI.ASSET_ROOT .. "icon_map", 11); mb:SetPoint("RIGHT", -4, 0)
      mb:SetScript("OnClick", function() showBeast(b) end)
    end
    return row
  end

  -- Master/detail view: a list on the left, a scrollable detail pane right.
  local function masterDetail(listItems, buildDetail)
    local view = CreateFrame("Frame", nil, body); place(view)
    local left = CreateFrame("Frame", nil, view); left:SetPoint("TOPLEFT"); left:SetPoint("BOTTOMLEFT"); left:SetWidth(340)
    UI.Column(left, 4) -- ht3: no frame, a line to the right
    local lsf = FLT.SkinBlizz(CreateFrame("ScrollFrame", nil, left, "UIPanelScrollFrameTemplate")); lsf:SetPoint("TOPLEFT", 10, -10); lsf:SetPoint("BOTTOMRIGHT", -28, 8)
    local lchild = CreateFrame("Frame", nil, lsf); lchild:SetSize(LIST_W, 1); lsf:SetScrollChild(lchild)
    UI.AutoHideScrollBar(lsf)

    local right = CreateFrame("Frame", nil, view); right:SetPoint("TOPLEFT", 348, 0); right:SetPoint("BOTTOMRIGHT")

    local rows, panes = {}, {}
    local function select(i)
      for j, r in ipairs(rows) do
        r.card:SetSelected(j == i)
        if j == i then r.label:SetTextColor(FLT.SkinC(unpack(GOLD))) else r.label:SetTextColor(FLT.SkinC(0.92, 0.90, 0.84)) end
      end
      for _, p in pairs(panes) do p:Hide() end
      if not panes[i] then
        local sf = FLT.SkinBlizz(CreateFrame("ScrollFrame", nil, right, "UIPanelScrollFrameTemplate")); sf:SetPoint("TOPLEFT", 14, -12); sf:SetPoint("BOTTOMRIGHT", -28, 10)
        local child = CreateFrame("Frame", nil, sf); child:SetSize(430, 1); sf:SetScrollChild(child)
        UI.AutoHideScrollBar(sf)
        local h = buildDetail(child, listItems[i])
        if h then child:SetHeight(math.max(1, h)) end
        sf.child = child
        panes[i] = sf
      end
      panes[i]:Show()
      if panes[i].child.refresh then panes[i].child.refresh() end
      view.selected = i
    end
    local y = -2
    for i, item in ipairs(listItems) do
      local b = CreateFrame("Button", nil, lchild); b:SetSize(ROW_W, 34); b:SetPoint("TOPLEFT", 0, y); y = y - 37
      local card = UI.CardRow(b)
      local ic = b:CreateTexture(nil, "ARTWORK"); ic:SetSize(26, 26); ic:SetPoint("LEFT", 6, 0); FLT.SetTex(ic, item.icon)
      local label = text(b, "GameFontHighlight", 160); label:SetPoint("LEFT", 40, 0); label:SetText(L[item.label])
      local sub = text(b, "GameFontDisableSmall", 110); sub:SetPoint("RIGHT", -8, 0); sub:SetJustifyH("RIGHT"); sub:SetText(item.sub or "")
      b:SetScript("OnClick", function() select(i) end)
      rows[i] = {card=card, label=label, sub=sub, button=b}
    end
    lchild:SetHeight(math.max(1, -y + 2))
    view.select = select
    view.focus = function(i) -- from the search: select and scroll the row into view
      select(i)
      lsf:SetVerticalScroll(math.max(0, math.min(lsf:GetVerticalScrollRange() or 0, (i - 1) * 37 - 120)))
    end
    view.rows, view.items = rows, listItems
    view.refreshCurrent = function() local p = view.selected and panes[view.selected]; if p and p.child.refresh then p.child.refresh() end end
    select(1)
    return view
  end

  local views, current = {}, nil
  local abilityIndex = {}

  local function heading(child, s, y)
    local h = text(child, "GameFontNormal"); h:SetPoint("TOPLEFT", 0, y); h:SetText(s); h:SetTextColor(FLT.SkinC(unpack(GOLD)))
    return y - 20
  end
  local function para(child, s, y, template, r, g, b)
    local p = text(child, template or "GameFontHighlightSmall", 420); p:SetPoint("TOPLEFT", 0, y); p:SetText(s)
    if r then p:SetTextColor(FLT.SkinC(r, g, b)) end
    return y - math.max(16, (p:GetStringHeight() or 14) + 4)
  end

  local showMode -- forward

  -- Families -----------------------------------------------------------------
  -- The hunter's active pet (family name as the client reports it).
  local FAMILY_ALIAS = { ["Owl"] = "Bird of Prey", ["Eule"] = "Bird of Prey" }
  local function activePet()
    if not (UnitExists and UnitExists("pet") and UnitCreatureFamily) then return nil end
    local fam = UnitCreatureFamily("pet")
    if not fam then return nil end
    return FAMILY_ALIAS[fam] or EN(fam), UnitName and UnitName("pet"), UnitLevel and UnitLevel("pet")
  end

  -- All known beasts of a family: the hand-picked list plus every beast that
  -- teaches an ability rank, de-duplicated and sorted by level.
  local TAME_PREVIEW = 4
  local function levelMid(lv)
    local a, b = tostring(lv or ""):match("(%d+)%s*%-%s*(%d+)")
    if a then return (tonumber(a) + tonumber(b)) / 2 end
    return tonumber(tostring(lv or ""):match("(%d+)")) or 0
  end
  local tameCache = {}
  local function familyTames(name)
    if tameCache[name] then return tameCache[name] end
    local list, seen = {}, {}
    local function add(b)
      local key = b.npcID or b.name
      if key and not seen[key] then seen[key] = true; list[#list + 1] = b end
    end
    for _, f in ipairs(FLT.PET_FAMILIES or {}) do
      if f.name == name then for _, b in ipairs(f.tames or {}) do add(b) end end
    end
    -- 6.1.9: every other tameable beast Petopia lists (Data/HunterPetTames.lua, e.g. the Zephras Isle beasts)
    for _, b in ipairs(FLT.PET_TAMES_EXTRA and FLT.PET_TAMES_EXTRA[name] or {}) do add(b) end
    for _, a in ipairs(FLT.PET_ABILITIES or {}) do
      for _, rk in ipairs(a.ranks or {}) do
        for _, b in ipairs(rk.learnFrom or {}) do if b.family == name then add(b) end end
      end
    end
    table.sort(list, function(x, y)
      local lx, ly = levelMid(x.level), levelMid(y.level)
      if lx ~= ly then return lx < ly end
      return (x.name or "") < (y.name or "")
    end)
    tameCache[name] = list
    return list
  end
  -- The n beasts closest to the player's level, shown in level order.
  local function nearestTames(list, n)
    if #list <= n then return list end
    local me = (UnitLevel and UnitLevel("player")) or 1
    local idx = {}
    for i = 1, #list do idx[i] = i end
    table.sort(idx, function(i, j)
      local di, dj = math.abs(levelMid(list[i].level) - me), math.abs(levelMid(list[j].level) - me)
      if di ~= dj then return di < dj end
      return i < j
    end)
    local pick = {}
    for k = 1, n do pick[k] = idx[k] end
    table.sort(pick)
    local out = {}
    for k, i in ipairs(pick) do out[k] = list[i] end
    return out
  end

  local function buildFamilies()
    local items = {}
    for _, f in ipairs(FLT.PET_FAMILIES or {}) do
      items[#items + 1] = { label=f.name, icon=icon(FAMILY_ICON, f.name), sub=tlist(f.diet), data=f }
    end
    -- framed sub-box with a small-caps title (optional icon)
    local function box(child, x, y, w, h, title, iconPath)
      local b = CreateFrame("Frame", nil, child); b:SetPoint("TOPLEFT", x, y); b:SetSize(w, h)
      UI.FramedPanel(b)
      local tx = 12
      if iconPath then
        local ic = b:CreateTexture(nil, "ARTWORK"); ic:SetSize(18, 18); ic:SetPoint("TOPLEFT", 10, -8); FLT.SetTex(ic, iconPath); tx = 34
      end
      local t = UI.SmallCaps(b, L[title], 15, 11, GOLD); t:SetPoint("TOPLEFT", tx, -9)
      return b
    end
    local MOD_ICONS = { health = "Interface\\Icons\\Spell_Holy_Heal", armor = "Interface\\Icons\\INV_Shield_06", damage = "Interface\\Icons\\INV_Sword_04" }
    local W = 430 -- ht7: was 532 (narrower detail pane)

    local view = masterDetail(items, function(child, item)
      local f = item.data
      child:SetWidth(W)
      -- Header: big portrait ring, name, ornate divider, diet / role / trait.
      -- portrait in the round gold ring
      local ring = CreateFrame("Frame", nil, child); ring:SetSize(108, 108); ring:SetPoint("TOPLEFT", -2, 2)
      local pic = ring:CreateTexture(nil, "ARTWORK"); pic:SetPoint("TOPLEFT", 14, -14); pic:SetPoint("BOTTOMRIGHT", -14, 14)
      FLT.SetTex(pic, icon(FAMILY_ICON, f.name))
      if pic.AddMaskTexture and ring.CreateMaskTexture then
        local m = ring:CreateMaskTexture(); FLT.SetTex(m, "Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE"); m:SetAllPoints(pic); pic:AddMaskTexture(m)
        pic:SetTexCoord(0.07, 0.93, 0.07, 0.93)
      end
      local ringTex = ring:CreateTexture(nil, "OVERLAY"); ringTex:SetAllPoints(); FLT.SetTex(ringTex, UI.ASSET_ROOT .. "frame_ring")
      local t = text(child, "GameFontNormalLarge"); t:SetPoint("TOPLEFT", 118, -6); t:SetText(L[f.name]); t:SetTextColor(FLT.SkinC(unpack(GOLD)))
      do local font, _, flags = t:GetFont(); if font then t:SetFont(font, 26, flags) end end
      local petTag = text(child, "GameFontHighlightSmall", 260); petTag:SetPoint("LEFT", t, "RIGHT", 14, -2); petTag:SetTextColor(FLT.SkinC(0.35, 1, 0.45))
      local dv = child:CreateTexture(nil, "ARTWORK"); FLT.SetTex(dv, UI.ASSET_ROOT .. "divider_ornate"); dv:SetSize(W - 112, 16); dv:SetPoint("TOPLEFT", 112, -36)

      local role = f.role
      local trait = f.note and f.note:gsub("^Role:%s*%a+%.%s*", "") or ""
      -- the "not confirmed" remark belongs to "Where to tame", not to the trait
      trait = trait:gsub("%s*Tameable beasts not confirmed yet in Forever%.?", "")
      if trait:match("^Stat modifiers") then trait = "" end
      do local ab = trait:match("^Only family with (.+)%.$"); if ab then trait = string.format(L["Only family with %s."], L[ab]) else trait = LN(trait) end end
      local facts = {
        { "Interface\\Icons\\INV_Misc_Food_14", L["Diet"], tlist(f.diet) },
        role and { "Interface\\Icons\\Ability_DualWield", L["Role"], L[role] } or nil,
        { "Interface\\Icons\\Ability_Hunter_BeastTaming", L["Special trait"], trait ~= "" and trait or ("|cff9d9d9d" .. L["None"] .. "|r") },
      }
      local fy = -56
      for i = 1, 3 do
        local fact = facts[i]
        if fact then
          local ic = child:CreateTexture(nil, "ARTWORK"); ic:SetSize(16, 16); ic:SetPoint("TOPLEFT", 120, fy); FLT.SetTex(ic, fact[1]); ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
          local l = text(child, "GameFontNormal"); l:SetPoint("LEFT", ic, "RIGHT", 8, 0); l:SetText(fact[2] .. ":"); l:SetTextColor(FLT.SkinC(unpack(GOLD)))
          local v = text(child, "GameFontHighlight", W - 230); v:SetPoint("LEFT", l, "RIGHT", 6, 0); v:SetText(fact[3]); v:SetWordWrap(false)
          fy = fy - 20
        end
      end
      local y = math.min(-112, fy - 8)

      child.refresh = function()
        local fam, pname, plevel = activePet()
        local parts = {}
        if fam == f.name then
          parts[#parts + 1] = string.format(L["Your pet: %s"], pname or "?") .. (plevel and plevel > 0 and (", " .. string.format(L["level %s"], plevel)) or "")
        end
        for _, sp in ipairs(FLT:GetStabledPets()) do
          if sp.family == f.name then
            parts[#parts + 1] = "|cff7fbfff" .. string.format(L["In stable: %s"], sp.name or "?") .. (sp.level and (", " .. string.format(L["level %s"], sp.level)) or "") .. "|r"
          end
        end
        petTag:SetText(table.concat(parts, "   "))
      end
      child.refresh()

      -- Modifiers (left) and family abilities (right), side by side.
      local nAb = #(f.abilities or {})
      local bw = math.floor((W - 8) / 2)
      local bh = math.max(34 + 3 * 34 + 6, 34 + nAb * 28 + 6)
      local mb = box(child, 0, y, bw, bh, N"Modifiers")
      local my = -32
      for _, key in ipairs({ "health", "armor", "damage" }) do
        local val = f.modifiers and f.modifiers[key]
        local r = CreateFrame("Frame", nil, mb); r:SetPoint("TOPLEFT", 8, my); r:SetSize(bw - 16, 30); my = my - 34
        UI.Card(r, r, 4, {0.30, 0.27, 0.22, 0.9}, {0.06, 0.062, 0.072, 0.96}, "BACKGROUND", 2)
        local ic = r:CreateTexture(nil, "ARTWORK"); ic:SetSize(22, 22); ic:SetPoint("LEFT", 5, 0); FLT.SetTex(ic, MOD_ICONS[key]); ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        local l = text(r, "GameFontHighlight"); l:SetPoint("LEFT", 36, 0); l:SetText(L[key:sub(1, 1):upper() .. key:sub(2)])
        local v = text(r, "GameFontHighlight"); v:SetPoint("RIGHT", -12, 0); v:SetText(val and ("x" .. val) or "-")
        local n = tonumber(val)
        if n and n > 1.001 then v:SetTextColor(FLT.SkinC(0.45, 1, 0.45)) elseif n and n < 0.999 then v:SetTextColor(FLT.SkinC(1, 0.45, 0.40)) else v:SetTextColor(FLT.SkinC(0.95, 0.93, 0.88)) end
      end
      local ab = box(child, bw + 8, y, bw, bh, N"Family abilities")
      local ay = -32
      for _, name in ipairs(f.abilities or {}) do
        local b = CreateFrame("Button", nil, ab); b:SetSize(bw - 16, 26); b:SetPoint("TOPLEFT", 8, ay); ay = ay - 28
        local ic = b:CreateTexture(nil, "ARTWORK"); ic:SetSize(22, 22); ic:SetPoint("LEFT", 3, 0); FLT.SetTex(ic, icon(ABILITY_ICON, name))
        local l = text(b, "GameFontHighlight", bw - 60); l:SetPoint("LEFT", 34, 0); l:SetText(L[name])
        local sep = makeTexture(b, "BORDER", 0.72, 0.50, 0.12, 0.18); sep:SetPoint("BOTTOMLEFT", 30, -1); sep:SetPoint("BOTTOMRIGHT", 0, -1); sep:SetHeight(1)
        local hi = makeTexture(b, "HIGHLIGHT", 0.90, 0.66, 0.22, 0.10); hi:SetPoint("TOPLEFT", 1, -1); hi:SetPoint("BOTTOMRIGHT", -1, 1)
        UI.HoverEdge(b)
        b:SetScript("OnClick", function() showMode("abilities", abilityIndex[name]) end)
        b:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:AddLine(L[name], 1, 0.82, 0); GameTooltip:AddLine(L["Click to open the ability"], 0.8, 0.8, 0.8); GameTooltip:Show() end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
      end
      y = y - bh - 10

      -- Where to tame: the 4 beasts closest to your level; "Show all" folds
      -- out every known beast of the family (merged from the ability ranks).
      local tames = familyTames(f.name)
      local tb = box(child, 0, y, W, 40, N"Where to tame", "Interface\\Icons\\Ability_Hunter_BeastTaming")
      local tameTop = y
      local showAll = false
      local tameRows = {}
      local toggle
      if #tames > TAME_PREVIEW then
        toggle = UI.GoldButton(tb, "", 110, 20, nil, 11); toggle:SetPoint("TOPRIGHT", -8, -7)
        toggle:SetScript("OnClick", function() showAll = not showAll; child.fillTames() end)
      end
      local none
      child.fillTames = function()
        for _, r in ipairs(tameRows) do r:Hide() end
        local list = showAll and tames or nearestTames(tames, TAME_PREVIEW)
        local ty = -32
        if #list == 0 then
          if not none then none = text(tb, "GameFontDisableSmall", W - 30); none:SetPoint("TOPLEFT", 14, ty - 8); none:SetText(L["No tameable beasts confirmed in Forever yet."]) end
          ty = ty - 32
        end
        for i, b in ipairs(list) do
          local r = tameRows[i]
          if not r then
            r = CreateFrame("Button", nil, tb); r:SetSize(W - 16, 30)
            UI.CardRow(r)
            r.n = text(r, "GameFontHighlight", 200); r.n:SetPoint("LEFT", 12, 0); r.n:SetWordWrap(false)
            r.z = text(r, "GameFontHighlightSmall", 120); r.z:SetPoint("LEFT", 214, 0); r.z:SetTextColor(FLT.SkinC(0.84, 0.81, 0.74)); r.z:SetWordWrap(false)
            r.m = UI.GoldButton(r, L["Map"], 64, 20, UI.ASSET_ROOT .. "icon_map", 11); r.m:SetPoint("RIGHT", -6, 0)
            r.m:SetScript("OnClick", function() local d = r.data; if d then showBeast(d) end end)
            tameRows[i] = r
          end
          r.data = b
          r:ClearAllPoints(); r:SetPoint("TOPLEFT", 8, ty); ty = ty - 32
          r.n:SetText(string.format("%s  |cff9d9d9d(%s)|r", NM(b.name) or "?", b.level or "?"))
          r.z:SetText(ZN(b.zone) or "?")
          if b.mapID and b.x and b.y then r.m:Show() else r.m:Hide() end
          r:Show()
        end
        if toggle then toggle:SetLabel(showAll and L["Show less"] or string.format(L["Show all (%d)"], #tames)) end
        local th = -ty + 6
        tb:SetHeight(th)
        child:SetHeight(math.max(1, -(tameTop - th - 6) + 4))
      end
      child.fillTames()
      local oldRefresh = child.refresh
      child.refresh = function() oldRefresh(); if not showAll then child.fillTames() end end
      local th = tb:GetHeight()
      y = y - th - 6
      return -y + 4
    end)
    view.markPet = function()
      local fam = activePet()
      local found
      for k, it in ipairs(view.items) do
        local r = view.rows[k]
        if r then
          local mine = fam and it.data.name == fam
          local stabled = 0
          for _, sp in ipairs(FLT:GetStabledPets()) do if sp.family == it.data.name then stabled = stabled + 1 end end
          if mine then found = k end
          if not r.petMark then
            r.petMark = makeTexture(r.button, "ARTWORK", 0.35, 1, 0.45, 0.95)
            r.petMark:SetPoint("TOPLEFT", 2, -4); r.petMark:SetPoint("BOTTOMLEFT", 2, 4); r.petMark:SetWidth(3)
          end
          if mine then
            r.petMark:SetColorTexture(FLT.SkinC(0.35, 1, 0.45, 0.95)); r.petMark:Show()
            r.sub:SetText("|cff59ff73" .. L["Your pet"] .. "|r" .. (stabled > 0 and ("\n|cff7fbfff" .. L["In stable"] .. "|r") or ""))
          elseif stabled > 0 then
            r.petMark:SetColorTexture(FLT.SkinC(0.50, 0.75, 1, 0.95)); r.petMark:Show()
            r.sub:SetText("|cff7fbfff" .. L["In stable"] .. (stabled > 1 and (" (" .. stabled .. ")") or "") .. "|r")
          else
            r.petMark:Hide(); r.sub:SetText(it.sub or "")
          end
        end
      end
      view.refreshCurrent()
      return found
    end
    view.markPet()
    return view
  end

  -- Abilities ----------------------------------------------------------------
  local function buildAbilities()
    local items = {}
    -- Only abilities learned from tameable beasts; Pet Trainer skills
    -- (resistances, Great Stamina, ...) are listed on each family instead.
    for _, a in ipairs(FLT.PET_ABILITIES or {}) do
      if a.source ~= "trainer" then
      items[#items + 1] = { label=L[a.name], icon=icon(ABILITY_ICON, a.name), sub=(a.source == "trainer") and L["Pet Trainer"] or string.format(L["%d ranks"], #(a.ranks or {})), data=a }
      abilityIndex[a.name] = #items
      end
    end
    local function subText(a)
      if a.source == "trainer" then
        local k = FLT:GetKnownPetRank(a.name)
        return k > 0 and ("|cff59ff73" .. string.format(L["Rank %s"], k) .. "|r  " .. L["Pet Trainer"]) or L["Pet Trainer"]
      end
      local k = FLT:CountPetRanks(a.name)
      local mute = FLT:IsPetAlertIgnored(a.name) and ("  |cff808080" .. L["(no alert)"] .. "|r") or ""
      if k > 0 then return "|cff59ff73" .. string.format(L["%d/%d learned"], math.min(k, #(a.ranks or {})), #(a.ranks or {})) .. "|r" .. mute end
      return string.format(L["%d ranks"], #(a.ranks or {})) .. mute
    end
    for _, it in ipairs(items) do it.sub = subText(it.data) end

    local W = 430 -- ht7: was 532 (narrower detail pane)
    local PAW = UI.ASSET_ROOT .. "emblem_pets"
    local view = masterDetail(items, function(child, item)
      local a = item.data
      child:SetWidth(W)
      local blocks, open = {}, {}
      -- Header: ability icon in the square gold frame, name and effect.
      -- slim metal frame (same style as the talent buttons), soft gold glow
      local fr = CreateFrame("Frame", nil, child); fr:SetSize(76, 76); fr:SetPoint("TOPLEFT", 6, -6)
      local glow = fr:CreateTexture(nil, "BACKGROUND"); FLT.SetTex(glow, UI.ASSET_ROOT .. "talent_glow"); glow:SetPoint("TOPLEFT", -14, 14); glow:SetPoint("BOTTOMRIGHT", 14, -14); glow:SetVertexColor(FLT.SkinC(1, 0.78, 0.30, 0.45))
      local pic = fr:CreateTexture(nil, "ARTWORK"); pic:SetPoint("TOPLEFT", 4, -4); pic:SetPoint("BOTTOMRIGHT", -4, 4)
      pic:SetTexCoord(0.07, 0.93, 0.07, 0.93); FLT.SetTex(pic, icon(ABILITY_ICON, a.name))
      if pic.AddMaskTexture and fr.CreateMaskTexture then
        local m = fr:CreateMaskTexture(); FLT.SetTex(m, UI.ASSET_ROOT .. "talent_icon_mask2", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE"); m:SetAllPoints(pic); pic:AddMaskTexture(m)
      end
      local frame = fr:CreateTexture(nil, "OVERLAY"); frame:SetAllPoints(); FLT.SetTex(frame, UI.ASSET_ROOT .. "talent_frame"); frame:SetVertexColor(FLT.SkinC(0.98, 0.76, 0.30, 1))
      local t = text(child, "GameFontNormalLarge"); t:SetPoint("TOPLEFT", 100, -8); t:SetText(L[a.name]); t:SetTextColor(FLT.SkinC(unpack(GOLD)))
      do local font, _, flags = t:GetFont(); if font then t:SetFont(font, 24, flags) end end
      local eff = text(child, "GameFontHighlight", W - 110); eff:SetPoint("TOPLEFT", 101, -38); eff:SetText(LN(a.effect or "")); eff:SetTextColor(FLT.SkinC(0.92, 0.90, 0.84))
      local alertCB = FLT.SkinBlizz(CreateFrame("CheckButton", nil, child, "UICheckButtonTemplate"))
      alertCB:SetSize(22, 22); alertCB:SetPoint("TOPRIGHT", -2, -4)
      local alertLbl = text(child, "GameFontHighlightSmall"); alertLbl:SetPoint("RIGHT", alertCB, "LEFT", -2, 0); alertLbl:SetText(L["Alert for this ability"])
      -- beta26 (tester Deaders 19.11.: "Demoralizing Screech" ran under "Alert for this ability"): a long name gets a smaller
      -- font (down to 16), then it is cut at the label
      do
        local room = W - 100 - (alertLbl:GetStringWidth() or 110) - 34
        local font, size, flags = t:GetFont()
        while font and size and size > 16 and (t:GetStringWidth() or 0) > room do size = size - 1; t:SetFont(font, size, flags) end
        if (t:GetStringWidth() or 0) > room then t:SetWidth(room); t:SetWordWrap(false) end
      end
      alertCB:SetScript("OnClick", function(self) FLT:SetPetAlertIgnored(a.name, not self:GetChecked()) end)
      alertCB:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT"); GameTooltip:AddLine(L["Pet ability alert"], 1, 0.82, 0)
        GameTooltip:AddLine(L["Untick to never get a popup for beasts teaching this ability."], 1, 1, 1, true); GameTooltip:Show()
      end)
      alertCB:SetScript("OnLeave", function() GameTooltip:Hide() end)

      -- divider next to the icon, under the effect text; families box below in full width
      local effH = math.max(14, eff:GetStringHeight() or 14)
      local dvY = math.min(-60, -38 - effH - 4)
      local dv = child:CreateTexture(nil, "ARTWORK"); FLT.SetTex(dv, UI.ASSET_ROOT .. "divider_ornate"); dv:SetSize(W - 100, 16); dv:SetPoint("TOPLEFT", 96, dvY)
      local fy = math.min(-94, dvY - 20)
      local fam = CreateFrame("Frame", nil, child); fam:SetPoint("TOPLEFT", 0, fy); fam:SetWidth(W)
      UI.FramedPanel(fam)
      local paw = fam:CreateTexture(nil, "ARTWORK"); paw:SetSize(34, 34); paw:SetPoint("TOPLEFT", 8, -8); FLT.SetTex(paw, PAW)
      local ft = UI.SmallCaps(fam, L["Supported Families"], 14, 10, GOLD); ft:SetPoint("TOPLEFT", 50, -9)
      local fl = text(fam, "GameFontHighlightSmall", W - 62); fl:SetPoint("TOPLEFT", 50, -28)
      fl:SetText((a.families and #a.families > 0) and tlist(a.families) or "-"); fl:SetTextColor(FLT.SkinC(0.85, 0.83, 0.77))
      local famH = math.max(50, 28 + math.max(14, fl:GetStringHeight() or 14) + 10)
      fam:SetHeight(famH)
      local headBottom = fy - famH
      local ranksTitle = UI.SmallCaps(child, L["Ranks"], 16, 12, GOLD); ranksTitle:SetPoint("TOPLEFT", 2, headBottom - 12)
      local introTop = headBottom - 36

      local intro = {}
      local function addIntro(str, r, g, b)
        local p = text(child, "GameFontHighlightSmall", W - 10); p:SetText(str)
        if r then p:SetTextColor(FLT.SkinC(r, g, b)) end
        intro[#intro + 1] = p
      end
      if a.source == "trainer" then addIntro(L["Learned from any Pet Trainer."], 0.65, 0.85, 1) end
      local noneKnown = a.source ~= "trainer" and #(a.ranks or {}) > 0
      for _, r in ipairs(a.ranks or {}) do if #(r.learnFrom or {}) > 0 then noneKnown = false end end
      if noneKnown then addIntro(L["New in WoW Forever: no beast that teaches this ability is known yet."], 0.65, 0.85, 1) end
      local scanHint = text(child, "GameFontDisableSmall", W - 10)
      scanHint:SetText(L["Green = rank you know. A rank counts once the game says \"You have learned a new ability\" - your pet has to use it first, taming alone is not enough. Opening Beast Training (spellbook) reads your ranks too. Right-click a rank to mark it yourself."])

      -- One card per rank: header line, effect, and the teaching beasts (fold out).
      for ri, r in ipairs(a.ranks or {}) do
        local hasBeasts = a.source ~= "trainer" and #(r.learnFrom or {}) > 0
        local card = CreateFrame("Frame", nil, child); card:SetWidth(W)
        local bg = UI.Card(card, card, 5, {0.42, 0.33, 0.18, 0.95}, {0.060, 0.062, 0.074, 0.97}, "BACKGROUND", 0)
        local hdr = CreateFrame("Button", nil, card); hdr:SetPoint("TOPLEFT", 0, 0); hdr:SetPoint("TOPRIGHT", 0, 0); hdr:SetHeight(30)
        local hhi = makeTexture(hdr, "HIGHLIGHT", 0.90, 0.66, 0.22, 0.08); hhi:SetPoint("TOPLEFT", 2, -2); hhi:SetPoint("BOTTOMRIGHT", -2, 0)
        local tog = hdr:CreateTexture(nil, "OVERLAY"); tog:SetSize(14, 14); tog:SetPoint("LEFT", 10, 0); FLT.SetTex(tog, UI.ASSET_ROOT .. "chevron")
        local label = text(hdr, "GameFontNormal", 340); label:SetPoint("LEFT", 32, 0)
        do local font, _, flags = label:GetFont(); if font then label:SetFont(font, 14, flags) end end
        label:SetText(string.format(L["Rank %d  |cffe0dccf-  pet level %s, %s TP|r"], r.rank, tostring(r.level or "?"), tostring(r.tp or "?")))
        local right = text(hdr, "GameFontHighlightSmall", 150); right:SetPoint("RIGHT", -12, 0); right:SetJustifyH("RIGHT")
        local rpaw = hdr:CreateTexture(nil, "ARTWORK"); rpaw:SetSize(18, 18); FLT.SetTex(rpaw, PAW)
        local body = CreateFrame("Frame", nil, card); body:SetPoint("TOPLEFT", 0, -30); body:SetPoint("TOPRIGHT", 0, -30); body:SetHeight(1)
        local by = 0
        if r.desc and r.desc ~= "" then
          local d = text(body, "GameFontHighlightSmall", W - 40); d:SetPoint("TOPLEFT", 32, by); d:SetText(LN(r.desc)); d:SetTextColor(FLT.SkinC(0.86, 0.84, 0.78))
          by = by - math.max(16, (d:GetStringHeight() or 14) + 6)
        end
        local beastsTop = by
        body.beasts = {}
        if hasBeasts then
          for _, b in ipairs(r.learnFrom) do
            local row = beastRow(body, b, by, W - 40); row:SetPoint("TOPLEFT", 26, by); by = by - 26
            body.beasts[#body.beasts + 1] = row
          end
        elseif a.source ~= "trainer" and not noneKnown then
          local d = text(body, "GameFontDisableSmall", W - 40); d:SetPoint("TOPLEFT", 32, by); d:SetText(L["No beast known that teaches this rank."]); by = by - 18
        end
        body.fullH, body.descH = -by + 6, -beastsTop + 6
        hdr:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        hdr:SetScript("OnEnter", function(self)
          GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:AddLine(L["Right-click: mark as learned or not learned"], 0.85, 0.85, 0.85); GameTooltip:Show()
        end)
        hdr:SetScript("OnLeave", function() GameTooltip:Hide() end)
        hdr:SetScript("OnClick", function(_, button)
          if button == "RightButton" then FLT:TogglePetRank(a.name, r.rank or ri); return end
          if not hasBeasts then return end
          open[ri] = not open[ri]
          child.relayout()
        end)
        blocks[ri] = { card = card, hdr = hdr, bg = bg, tog = tog, label = label, right = right, paw = rpaw, body = body, rank = r, hasBeasts = hasBeasts }
      end

      child.relayout = function()
        local y = introTop
        for _, p in ipairs(intro) do
          p:ClearAllPoints(); p:SetPoint("TOPLEFT", 2, y)
          y = y - math.max(16, (p:GetStringHeight() or 14) + 4)
        end
        if scanHint:IsShown() then
          scanHint:ClearAllPoints(); scanHint:SetPoint("TOPLEFT", 2, y)
          y = y - math.max(16, (scanHint:GetStringHeight() or 14) + 8)
        end
        for ri, bl in ipairs(blocks) do
          local expanded = open[ri] or not bl.hasBeasts
          bl.tog:SetShown(bl.hasBeasts)
          if open[ri] then bl.tog:SetTexCoord(0, 0.5, 0, 1) else bl.tog:SetTexCoord(0.5, 1, 0, 1) end
          for _, row in ipairs(bl.body.beasts) do if expanded then row:Show() else row:Hide() end end
          local h = expanded and bl.body.fullH or (bl.body.descH > 6 and bl.body.descH or 4)
          bl.body:SetHeight(math.max(1, h))
          bl.card:ClearAllPoints(); bl.card:SetPoint("TOPLEFT", 0, y); bl.card:SetHeight(30 + h)
          y = y - (30 + h) - 6
        end
        child:SetHeight(math.max(1, -y + 10))
      end

      child.refresh = function()
        alertCB:SetChecked(not FLT:IsPetAlertIgnored(a.name))
        if a.source == "trainer" then scanHint:Hide() else scanHint:Show() end
        for _, bl in ipairs(blocks) do
          local learned = FLT:HasPetRank(a.name, bl.rank.rank or 1)
          bl.paw:ClearAllPoints()
          if learned then
            bl.bg:SetFill(0.05, 0.15, 0.07, 0.95); bl.bg:SetBorder(0.30, 0.55, 0.30, 0.9); bl.label:SetTextColor(FLT.SkinC(0.35, 1, 0.45))
            bl.right:SetText("|cff59ff73" .. L["Learned"] .. "|r"); bl.paw:Hide()
          else
            bl.bg:SetFill(0.060, 0.062, 0.074, 0.97); bl.bg:SetBorder(0.42, 0.33, 0.18, 0.95); bl.label:SetTextColor(FLT.SkinC(unpack(GOLD)))
            if bl.hasBeasts then
              bl.right:SetText(string.format(L["%d beasts"], #bl.rank.learnFrom)); bl.right:SetTextColor(FLT.SkinC(0.86, 0.84, 0.78))
              bl.paw:SetPoint("RIGHT", bl.right, "RIGHT", -(bl.right:GetStringWidth() or 50) - 6, 0); bl.paw:Show()
            else
              bl.right:SetText(""); bl.paw:Hide()
            end
          end
        end
        child.relayout()
      end
      child.refresh()
      return nil
    end)

    view.refreshKnown = function()
      for i, it in ipairs(view.items) do
        it.sub = subText(it.data)
        if view.rows[i] and view.rows[i].sub then view.rows[i].sub:SetText(it.sub) end
      end
      view.refreshCurrent()
    end
    return view
  end

  -- Rare tames ---------------------------------------------------------------
  local function buildRares()
    local view = CreateFrame("Frame", nil, body); place(view)
    local sf = FLT.SkinBlizz(CreateFrame("ScrollFrame", nil, view, "UIPanelScrollFrameTemplate")); sf:SetPoint("TOPLEFT", 12, -10); sf:SetPoint("BOTTOMRIGHT", -30, 10)
    local child = CreateFrame("Frame", nil, sf); child:SetSize(770, 1); sf:SetScrollChild(child)
    UI.AutoHideScrollBar(sf)
    local y = -2
    local cards = {}
    for i, r in ipairs(FLT.PET_RARES or {}) do
      local row = CreateFrame("Button", nil, child); row:SetSize(770, 44); row:SetPoint("TOPLEFT", 0, y); y = y - 47
      cards[i] = UI.CardRow(row)
      local ic = row:CreateTexture(nil, "ARTWORK"); ic:SetSize(28, 28); ic:SetPoint("LEFT", 8, 0); FLT.SetTex(ic, icon(FAMILY_ICON, r.family))
      local n = text(row, "GameFontNormal", 300); n:SetPoint("TOPLEFT", 44, -6)
      n:SetText(string.format("%s  |cffbbbbbb%s, %s%s|r", NM(r.name) or "?", r.family and L[r.family] or "?", string.format(L["level %s"], r.level or "?"), r.speed and (", " .. string.format(L["speed %s"], r.speed)) or ""))
      local w = text(row, "GameFontHighlightSmall", 440); w:SetPoint("TOPLEFT", 44, -25); w:SetText(LN(r.why or "")); w:SetWordWrap(false)
      local z = text(row, "GameFontHighlightSmall", 190); z:SetPoint("RIGHT", -96, 0); z:SetJustifyH("RIGHT"); z:SetText(ZN(r.zone) or ""); z:SetWordWrap(false)
      -- full text in the tooltip (the description is cut to one line)
      row:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR"); GameTooltip:AddLine(NM(r.name) or "?", 1, 0.82, 0)
        GameTooltip:AddLine(string.format("%s, %s%s", r.family and L[r.family] or "?", string.format(L["level %s"], r.level or "?"), r.speed and (", " .. string.format(L["attack speed %s"], r.speed)) or ""), 0.9, 0.9, 0.9)
        if r.why and r.why ~= "" then GameTooltip:AddLine(LN(r.why), 1, 1, 1, true) end
        if r.zone then GameTooltip:AddLine(ZN(r.zone), 0.65, 0.85, 1) end
        GameTooltip:Show()
      end)
      row:SetScript("OnLeave", function() GameTooltip:Hide() end)
      if r.mapID and r.x and r.y then
        local mb = UI.GoldButton(row, L["Map"], 74, 22, UI.ASSET_ROOT .. "icon_map", 12); mb:SetPoint("RIGHT", -10, 0)
        mb:SetScript("OnClick", function() showBeast(r) end)
      end
    end
    child:SetHeight(math.max(1, -y + 4))
    view.focus = function(i) -- from the search: mark the row and scroll to it
      for j, c in ipairs(cards) do c:SetSelected(j == i) end
      sf:SetVerticalScroll(math.max(0, math.min(sf:GetVerticalScrollRange() or 0, (i - 1) * 47 - 120)))
    end
    return view
  end

  local searchIndex, searchView -- the search (below)
  local builders = { families=buildFamilies, abilities=buildAbilities, rares=buildRares }
  showMode = function(key, selectIndex)
    if searchView and searchView:IsShown() then head.box:SetText(""); head.box:ClearFocus() end -- a mode button ends the search
    -- Abilities must exist before a family links to one.
    if key == "families" and not views.abilities then views.abilities = buildAbilities(); views.abilities:Hide() end
    for k, v in pairs(views) do if k ~= key then v:Hide() end end
    views[key] = views[key] or builders[key]()
    views[key]:Show()
    if selectIndex and views[key].select then views[key].select(selectIndex) end
    for k, b in pairs(modeButtons) do b:SetActive(k == key) end
    do local mh = MODE_HEAD[key]; head:Set(mh[1], L[mh[2]], L[mh[3]]) end
    current = key
  end

  -- Search over all three modes (user 31.10.): one result list; a click opens the entry in its mode.
  -- The index is built on the first search only.
  local KIND = { families = N"Family", abilities = N"Ability", rares = N"Rare tame" }
  local function buildIndex()
    searchIndex = {}
    local function add(kind, key, label, ic, parts) searchIndex[#searchIndex + 1] = { kind = kind, key = key, label = label, icon = ic, find = table.concat(parts, " "):lower() } end
    for i, f in ipairs(FLT.PET_FAMILIES or {}) do
      local parts = { f.name or "", L[f.name or ""], table.concat(f.diet or {}, " "), tlist(f.diet, " "), table.concat(f.abilities or {}, " "), tlist(f.abilities, " ") }
      for _, b in ipairs(f.tames or {}) do parts[#parts + 1] = (b.name or "") .. " " .. (b.zone or "") end
      for _, b in ipairs(FLT.PET_TAMES_EXTRA and FLT.PET_TAMES_EXTRA[f.name] or {}) do parts[#parts + 1] = (b.name or "") .. " " .. (b.zone or "") end
      add("families", i, L[f.name], icon(FAMILY_ICON, f.name), parts)
    end
    for _, a in ipairs(FLT.PET_ABILITIES or {}) do
      if a.source ~= "trainer" then
        local parts = { a.name or "", L[a.name or ""], a.effect or "" }
        for _, rk in ipairs(a.ranks or {}) do
          for _, b in ipairs(rk.learnFrom or {}) do parts[#parts + 1] = (b.name or "") .. " " .. (b.zone or "") end
        end
        add("abilities", a.name, L[a.name], icon(ABILITY_ICON, a.name), parts)
      end
    end
    for i, r in ipairs(FLT.PET_RARES or {}) do
      add("rares", i, r.name, icon(FAMILY_ICON, r.family), { r.name or "", NM(r.name or ""), r.family or "", L[r.family or ""], r.zone or "", r.why or "" })
    end
  end
  local function openHit(hit)
    head.box:SetText(""); head.box:ClearFocus()
    showMode(hit.kind)
    local v = views[hit.kind]
    local i = hit.kind == "abilities" and abilityIndex[hit.key] or hit.key
    if v and v.focus and i then v.focus(i) end
  end
  runSearch = function(t)
    if not current then return end
    if t == "" then
      if searchView then searchView:Hide() end
      views[current]:Show(); do local mh = MODE_HEAD[current]; head:Set(mh[1], L[mh[2]], L[mh[3]]) end; modeButtons[current]:SetActive(true)
      return
    end
    if not searchIndex then buildIndex() end
    if not searchView then
      searchView = CreateFrame("Frame", nil, body); place(searchView)
      local sf = FLT.SkinBlizz(CreateFrame("ScrollFrame", nil, searchView, "UIPanelScrollFrameTemplate")); sf:SetPoint("TOPLEFT", 12, -10); sf:SetPoint("BOTTOMRIGHT", -30, 10)
      local child = CreateFrame("Frame", nil, sf); child:SetSize(770, 1); sf:SetScrollChild(child)
      UI.AutoHideScrollBar(sf)
      searchView.child, searchView.sf, searchView.rows = child, sf, {}
      searchView.none = text(child, "GameFontDisable"); searchView.none:SetPoint("TOPLEFT", 12, -12); searchView.none:SetText(L["Nothing found."])
    end
    for _, v in pairs(views) do v:Hide() end
    for _, b in pairs(modeButtons) do b:SetActive(false) end
    local rows, n, y = searchView.rows, 0, -2
    for _, hit in ipairs(searchIndex) do
      if hit.find:find(t, 1, true) then
        n = n + 1
        local r = rows[n]
        if not r then
          r = CreateFrame("Button", nil, searchView.child); r:SetSize(770, 34)
          UI.CardRow(r)
          r.ic = r:CreateTexture(nil, "ARTWORK"); r.ic:SetSize(26, 26); r.ic:SetPoint("LEFT", 6, 0)
          r.label = text(r, "GameFontHighlight", 400); r.label:SetPoint("LEFT", 40, 0)
          r.kind = text(r, "GameFontDisableSmall", 160); r.kind:SetPoint("RIGHT", -10, 0); r.kind:SetJustifyH("RIGHT")
          r:SetScript("OnClick", function(self) openHit(self.hit) end)
          rows[n] = r
        end
        r.hit = hit; FLT.SetTex(r.ic, hit.icon); r.label:SetText(hit.label or "?"); r.kind:SetText(L[KIND[hit.kind]])
        r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, y); r:Show(); y = y - 37
      end
    end
    for i = n + 1, #rows do rows[i]:Hide() end
    searchView.none:SetShown(n == 0)
    searchView.child:SetHeight(math.max(1, -y + 4)); searchView.sf:SetVerticalScroll(0)
    searchView:Show()
    head:Set("Interface\\Icons\\INV_Misc_Spyglass_02", L["Search"], n == 1 and L["1 match in families, abilities and rare tames."] or string.format(L["%d matches in families, abilities and rare tames."], n))
  end
  for k, b in pairs(modeButtons) do b:SetScript("OnClick", function() showMode(k) end) end

  petUI = { refreshKnown = function()
    if views.abilities and views.abilities.refreshKnown then views.abilities.refreshKnown() end
    if views.families and views.families.markPet then views.families.markPet() end
  end }
  panel:SetScript("OnShow", function()
    if not current then
      indexIcons(); showMode("families")
      -- Start on the family of the active pet.
      local idx = views.families and views.families.markPet and views.families.markPet()
      if idx then views.families.select(idx) end
    end
    petUI.refreshKnown()
  end)
  panel:Hide()
  return panel
end

UI.RegisterPanel({ key="pets", label=N"Hunter Pets", order=7, tabWidth=122, create=createPetsPanel })
