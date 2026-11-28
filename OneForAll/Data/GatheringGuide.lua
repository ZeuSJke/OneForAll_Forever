local _, FLT = ...
-- Leveling guide of the gathering professions, Fishing (with Cooking along) and Lockpicking for Professions > Skill-Up
-- Helper (UI/GatherUI.lua; 6.2.18-beta13, user 27.11.2026: "der skill up helfer soll anzeigen wo man verschiedene raenge
-- skillen kann"). Written by hand: the facts (which herb / ore / fish / mob / lockbox, which zone, which skill range)
-- follow the WoW Forever leveling guides of wow-professions.com (user 27.11.2026: "als quelle kannst du ... hernehmen";
-- not named in the addon as the user wished); the texts are our own. Node skills: the classic gathering rules.
--   nodes = { { item, skill needed } }   what you can gather and from which skill (herbs, ores)
--   steps = { { from, to, items = { item IDs }, mobs = { names }, lv = "mob levels", objs = { names },
--              A = { zones }, H = { zones }, B = { zones for both }, note = text, lure = item,
--              cook = { { recipe spell, cooking from, cooking to, about how many, extra text } },
--              keep = { [fish item] = about how many to keep for Cooking }, npcs = { NPC IDs with a map button
--              (FLT.PROFESSION_RANK_NPCS: book / quest / recipe NPCs named in the note) } } }
--   smelt = { { from, to, bar item, how many } }  (Mining)
-- Names (mobs, objects) and zones are translated where shown (Locales/Names_*.lua, FLT.ZoneName); notes go through L[].
local function N(s) return s end

FLT.GATHER_PROFS = { "Herbalism", "Mining", "Skinning", "Fishing", "Lockpicking" }

FLT.GATHER_GUIDE = {
  Herbalism = {
    rule = N"Find Herbs shows herbs on your minimap - switch it on in the spellbook; it ends when you die.",
    nodes = {
      {2447, 1}, {765, 1}, {2449, 15}, {785, 50}, {2450, 70}, {3820, 85}, {2453, 100}, {3355, 115}, {3369, 120},
      {3356, 125}, {3357, 150}, {3818, 160}, {3821, 170}, {3358, 185}, {3819, 195}, {4625, 205}, {8831, 210},
      {8836, 220}, {8838, 230}, {8839, 235}, {8845, 245}, {8846, 250}, {13464, 260}, {13463, 270}, {13465, 280},
      {13466, 285}, {13467, 290}, {13468, 300},
    },
    steps = {
      { 1, 70, items = {2447, 765, 2449}, A = {"Elwynn Forest", "Dun Morogh", "Teldrassil", "Zephras Isle"},
        H = {"Durotar", "Mulgore", "Tirisfal Glades", "Zephras Isle"}, note = N"Herbs come back fast in the starting zones - pick what you pass." },
      { 70, 115, items = {785, 2450, 3820}, A = {"Loch Modan", "Darkshore"}, H = {"Silverpine Forest"},
        note = N"Darkshore has the most herbs; small loops are enough." },
      { 115, 170, items = {2453, 3355, 3820, 3356, 3357}, B = {"Hillsbrad Foothills", "Stonetalon Mountains"} },
      { 170, 205, items = {3356, 3357, 3818, 3821, 3358}, B = {"Stranglethorn Vale", "Arathi Highlands"} },
      { 205, 230, items = {8831, 4625}, B = {"Tanaris", "Searing Gorge"},
        note = N"Learn Artisan at 200 before you go - neither zone has a trainer." },
      { 230, 270, items = {8838, 8831, 8845, 13464}, B = {"The Hinterlands"}, note = N"Ghost Mushrooms grow in caves and need 245." },
      { 270, 300, items = {8838, 8846, 13464, 13463, 13465, 13466}, B = {"Felwood"} },
    },
  },
  Mining = {
    tool = 2901,
    rule = N"Find Minerals shows ore veins on your minimap - switch it on in the spellbook; it ends when you die.",
    nodes = {
      {2770, 1}, {2771, 65}, {3340, 65}, {2775, 75}, {4278, 75}, {2772, 125}, {5833, 150}, {2776, 155}, {3858, 175},
      {7911, 230}, {11370, 230}, {10620, 245},
    },
    steps = {
      { 1, 65, items = {2770}, A = {"Elwynn Forest", "Dun Morogh", "Zephras Isle"}, H = {"Durotar", "Mulgore", "Tirisfal Glades", "Zephras Isle"},
        note = N"Smelt your copper at the next forge after every lap - smelting gives points too." },
      { 65, 125, items = {2771, 2775, 2770, 3340}, A = {"Wetlands", "Westfall"}, H = {"Silverpine Forest", "Hillsbrad Foothills", "The Barrens"},
        B = {"Ashenvale", "Stonetalon Mountains"}, note = N"Make your Bronze Bars before you leave: Bronze gives points only up to about 105." },
      { 125, 175, items = {2772, 2776}, B = {"Thousand Needles", "Riverglades", "Arathi Highlands", "Desolace"},
        note = N"Riverglades is full of Iron Deposits; leave its caves to higher levels." },
      { 175, 245, items = {3858, 7911}, B = {"The Hinterlands", "Tanaris"}, note = N"Some caves there hold level 60 elites." },
      { 245, 275, items = {3858, 10620}, B = {"Un'Goro Crater", "Felwood", "Blasted Lands"} },
      { 275, 300, items = {10620}, B = {"Un'Goro Crater", "Eastern Plaguelands", "Winterspring", "Burning Steppes"},
        note = N"Rich Thorium Veins need 275." },
    },
    smelt = { {1, 65, 2840, 140}, {65, 75, 3576, 70}, {75, 105, 2841, 70}, {105, 120, 2842, 43}, {125, 138, 3575, 20}, {155, 175, 3577, 25} },
    smeltNote = N"From 138 to 155 no smelting gives points - mine Iron there.",
  },
  Skinning = {
    tool = 7005,
    rule = N"You can skin a beast up to level 10 from the start; then you need 10 skill per level up to level 20 and five times its level after that.",
    steps = {
      { 1, 75, items = {2934, 2318}, lv = "1-10", A = {"Elwynn Forest", "Dun Morogh", "Teldrassil", "Zephras Isle"},
        H = {"Durotar", "Mulgore", "Tirisfal Glades", "Zephras Isle"}, note = N"Every beast of the starting zones counts up to 75." },
      { 75, 130, items = {2318, 2319}, mobs = {"Sunscale Scytheclaw", "Zhevra Charger", "Ornery Plainstrider", "Elder Mountain Boar", "Black Bear Patriarch", "Loch Crocolisk"},
        lv = "14-18", B = {"The Barrens", "Loch Modan"}, note = N"The raptor camp west of Northwatch Hold respawns fast and carries you to 150." },
      { 130, 150, items = {2319}, mobs = {"Mottled Scytheclaw", "Mottled Razormaw"}, lv = "25-27", B = {"Wetlands"} },
      { 150, 160, items = {2319, 4234}, mobs = {"Vicious Gray Bear", "Starving Mountain Lion"}, lv = "22-24", B = {"Hillsbrad Foothills"} },
      { 160, 225, items = {4234}, mobs = {"Cave Yeti", "Ferocious Yeti", "Nightbane Worgen", "Nightbane Shadow Weaver", "Nightbane Dark Runner"},
        lv = "26-32", B = {"Hillsbrad Foothills", "Duskwood"}, note = N"The yetis in the Hillsbrad cave respawn quickly - you can stay inside." },
      { 225, 280, items = {4304}, mobs = {"Feral Scar Yeti", "Enraged Feral Scar", "Hulking Feral Scar"}, lv = "43-46", B = {"Feralas"},
        note = N"Learn Artisan at 200; the Hulking Feral Scars need 230." },
      { 280, 300, items = {8170}, mobs = {"Diemetradon", "Pterrordax", "Elder Diemetradon", "Frenzied Pterrordax"}, lv = "50-55", B = {"Un'Goro Crater"} },
    },
  },
  Fishing = {
    tool = 6256,
    rule = N"The fish you catch level Cooking too - every step shows what to cook with it.",
    steps = {
      { 1, 75, items = {6291, 6289, 6303}, keep = { [6291] = 45, [6289] = 30, [6303] = 70 }, lure = 6529, A = {"Elwynn Forest", "Dun Morogh", "Teldrassil", "Zephras Isle"},
        H = {"Durotar", "Mulgore", "Tirisfal Glades", "Zephras Isle"}, note = N"Any lake or river of a starting zone. Keep the fish for Cooking." },
      { 75, 130, items = {6291, 6289, 6308}, keep = { [6291] = 20, [6289] = 60, [6308] = 30 }, lure = 6530, A = {"Stormwind City", "Ironforge", "Darnassus"},
        H = {"Orgrimmar", "Thunder Bluff", "Undercity"}, B = {"The Barrens", "Loch Modan", "Darkshore", "Westfall", "Silverpine Forest"},
        note = N"Learn Journeyman Fishing at 50 (level 10) at your fishing trainer.", cook = { {7751, 1, 50, 45}, {7752, 1, 50, 70}, {7753, 50, 100, 30} } },
      { 130, 205, items = {6289, 6308}, keep = { [6289] = 95, [6308] = 145 }, lure = 6530, B = {"Stonetalon Mountains", "Ashenvale"},
        npcs = {2626, 3955, 12033},
        note = N"Expert Fishing (from 125, level 20) is a book from Old Man Heming in Booty Bay. Read the Expert Cookbook at Cooking 125.",
        cook = { {7755, 100, 175, 145} } },
      { 205, 255, items = {8365, 6308}, lure = 6530, B = {"Dustwallow Marsh"}, npcs = {12919, 8125, 2664},
        note = N"Fish the swamp water, not the sea. At 225 Nat Pagle in Dustwallow Marsh gives the Artisan quest; the Artisan Cooking quest is in Gadgetzan.",
        cook = { {7755, 150, 175}, {20916, 175, 250} } },
      { 255, 300, items = {13758, 13759}, lure = 6532, B = {"Feralas", "Tanaris", "The Hinterlands", "Felwood", "Un'Goro Crater", "Western Plaguelands"},
        note = N"Use Bright Baubles or most fish get away. Nightfin Snappers do not bite between 12:00 and 18:00 (game time).",
        npcs = {8137}, cook = { {18241, 250, 285}, {18243, 285, 300, nil, N"+1 Refreshing Spring Water each"} } },
    },
  },
  Lockpicking = {
    rule = N"Your Lockpicking can be at most five times your level.",
    steps = {
      { 1, 100, objs = {"Buccaneer's Strongbox", "Practice Lockbox"}, B = {"The Barrens", "Redridge Mountains"},
        note = N"The strongboxes on the ship near Ratchet respawn in seconds; the chest at the bottom spawns a strong enemy." },
      { 100, 150, objs = {"Waterlogged Footlocker"}, B = {"Ashenvale"}, note = N"Zoram Strand: footlockers on the shore, the ones in the water from 110." },
      { 150, 225, objs = {"Battered Footlocker", "Dented Footlocker"}, B = {"Badlands"}, note = N"Angor Fortress: upstairs first, downstairs from 175." },
      { 225, 300, objs = {"Dented Footlocker"}, B = {"Searing Gorge", "Tanaris"}, note = N"The Slag Pit in Searing Gorge, or Lost Rigger Cove in Tanaris." },
    },
  },
}
