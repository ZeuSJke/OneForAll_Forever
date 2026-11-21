local _, FLT = ...

-- The Drowned City: quests (wowforevertalents.com beta quest cache), boss names and NPC IDs (Wowhead Forever database via foreverchanges.pro); October 2026.
-- Loot (09.11.2026): boss loot lists of wowtbc.gg, item IDs and the dropping boss checked on Wowhead Forever (search, built-in browser).
-- 13.11.2026: Viscera Spaulders 274607 (Deathless Marrow) and Ritual-Binder's Gloves 274610 (Min'loth) confirmed on Wowhead
-- Forever; Umbra (rare elite) added from its Wowhead NPC page. Linken's Boots of Iron 271718 (wowtbc.gg: Min'loth) has no boss
-- on Wowhead - left out.
FLT.DUNGEON_REGISTRY["The Drowned City"] = {
    level = "35-42",
    location = "Gillijim's Isle, off the coast of Stranglethorn Vale",
    description = "New Forever dungeon: I'lalai, a lost troll city that has risen from the sea. Naga, risen trolls and stranded pirates fight over its ruins. Its loot is still being discovered: what players have recorded so far is listed.",
    icon = "Interface\\Icons\\INV_Misc_Idol_03",
    quests = {
        {
            level = 40,
            id = 96078,
            name = "A Tale Spun Around the Fire",
            requires = 30,
            faction = "Horde",
            objective = "Take the tablet etchings to Master Gadrin in Sen'jin Village in Durotar.",
            turnin = "Master Gadrin, Durotar",
            rewardChoice = true,
            rewardItems = {
                {279885, "Ceremonial Mallet", 3},
                {279886, "Sacrificial Sword", 3},
                {279887, "I'lalai Flayer", 3},
            },
            rewardAlso = {
                {270312, "Translated Tale of I'lalai", 1},
                {270313, "Tale of I'lalai in Zandali", 1},
            },
            rewardSummary = "35s",
        },
        {
            id = 95776,
            liveXPFallback = 3550,
            name = "The Only Good Brinescale...",
            level = 38,
            requires = 30,
            faction = "Horde",
            pickup = "Commander Aggro'gosh, Stranglethorn Vale (32.2, 28.9)",
            objective = "Slay Var'Taka in the Drowned City.",
            turnin = "Commander Aggro'gosh, Stranglethorn Vale",
            rewardItems = {{279888, "Tidesoaked Leggings", 2}, {279889, "Naga Priestess's Mantle", 2}},
            rewardChoice = true,
            rewardSummary = "1g 30s",
            note = "The quest text mentions Kin'weelay, the troll scholar at Grom'gol Base Camp.",
        },
        {
            id = 96774,
            liveXPFallback = 3900,
            name = "Ancient Gurubashi Idol",
            level = 40,
            requires = 30,
            faction = "Horde",
            pickup = "Mazu'kon, Mulgore (32.4, 20.4)",
            objective = "Recover an Ancient Gurubashi Idol from the Drowned City.",
            turnin = "Mazu'kon, Mulgore",
            rewardSummary = "1g",
            note = "The idol is carried by the strongest priest in the city.",
        },
        {
            level = 40,
            id = 95789,
            name = "Shady Saltseers",
            requires = 34,
            faction = "Both",
            pickup = "Krazek, Stranglethorn Vale (26.9, 77.2)",
            objective = "Collect 10 Voodoo Infused Artifacts from Saltseer pirates in the Drowned City.",
            rewardChoice = true,
            rewardItems = {
                {279882, "Rusted Troll War Belt", 2},
                {279930, "Saltseer's Helm", 2},
            },
        },
        {
            level = 40,
            id = 95791,
            name = "The Saltseer Captain",
            requires = 34,
            faction = "Both",
            pickup = "Krazek, Stranglethorn Vale (26.9, 77.2)",
            objective = "Slay 3 Saltseer Coroners and Captain Dreadrise in the Drowned City.",
            turnin = "Krazek, Stranglethorn Vale",
            rewardChoice = true,
            rewardItems = {
                {279883, "Mutinous Cuffs", 2},
                {279884, "South Seas Shroud", 2},
            },
        },
        {
            level = 40,
            id = 95798,
            name = "The Web of Magic",
            requires = 30,
            faction = "Alliance",
            pickup = "Abra Cadabra, Alterac Mountains (12.1, 70.3)",
            objective = "Bring the I'lalai Fetish to Abra Cadabra in Dalaran.",
            turnin = "Abra Cadabra, Alterac Mountains",
            rewardChoice = true,
            rewardItems = {
                {279879, "Rune-Etched Epaulets", 3},
                {279878, "Apprentice Sorcerer's Slacks", 3},
            },
        },
        {
            level = 40,
            id = 95799,
            name = "Findings for the Explorer's League",
            requires = 30,
            faction = "Alliance",
            pickup = "Historian Karnik, Ironforge (77.5, 11.8)",
            objective = "Bring Loremaster Dibbs' I'lalai Translations to Historian Karnik in Ironforge.",
            turnin = "Historian Karnik, Ironforge",
            rewardChoice = true,
            rewardItems = {
                {279880, "Ancient Voodoo Pouch", 3},
                {279881, "Intrepid Explorer's Chainmail", 3},
            },
            rewardAlso = {
                {272124, "Translated Tale of I'lalai", 1},
            },
        },
        {
            level = 40,
            id = 97130,
            name = "Ancient Gurubashi Secrets",
            requires = 34,
            faction = "Alliance",
            pickup = "Archmage Timear, Alterac Mountains (16.2, 71.7)",
            objective = "Recover an Ancient Gurubashi Idol from the Drowned City.",
            rewardItems = {
            },
        },
    },
    bosses = {
        {
            name = "Zul'Alai",
            npcID = 270882,
            displayID = 144475,
            loot = {
                {274598, "Bloodslash Axe", "One-Hand, Axe", 3},
                {274599, "Oathbound Bracers", "Wrist, Leather", 3},
                {274600, "Berserker Shackles", "Wrist, Mail", 3},
            },
        },
        {
            name = "Var'Taka",
            npcID = 270883,
            displayID = 144487,
            loot = {
                {274601, "Harpoon of Command", "Two-Hand, Polearm", 3},
                {274602, "Brinebelly Leggings", "Legs, Leather", 3},
                {274613, "Priestess Cloak", "Back", 3},
            },
        },
        {
            name = "Captain Dreadrise",
            npcID = 270884,
            displayID = 142144,
            loot = {
                {274603, "Dreadfrost Saber", "Main Hand, Sword", 3},
                {274604, "Frosty Blunderbuss", "Ranged, Gun", 3},
                {274605, "Briny Sash", "Waist, Cloth", 3},
            },
        },
        {
            name = "Deathless Marrow",
            npcID = 270885,
            displayID = 142245,
            loot = {
                {274607, "Viscera Spaulders", "Shoulder, Mail", 3},
                {274606, "Bloodspine Staff", "Two-Hand, Staff", 3},
                {274614, "Knucklebone Ring", "Finger", 3},
            },
        },
        {
            name = "Gill",
            npcID = 270888,
            displayID = 144023,
            rare = true,
            loot = {
                {286646, "Gill's Gills", "Trinket", 3},
                {286649, "Tidebound Dagger", "Main Hand, Dagger", 3},
            },
        },
        {
            name = "Primeval Elemental",
            npcID = 270887,
            displayID = 129945,
            loot = {
                {274611, "Robe of the Drowned", "Chest, Cloth", 3},
                {274612, "Waterlogged Burial Shroud", "Back", 3},
                {274615, "Heart of the Primeval", "Trinket", 3},
            },
        },
        {
            name = "Min'loth the Serpent",
            npcID = 270886,
            displayID = 142286,
            loot = {
                {274610, "Ritual-Binder's Gloves", "Hands, Leather", 3},
                {274608, "Maw of Min'loth", "Off Hand, Shield", 3},
                {274609, "Serpentbane Crown", "Head, Mail", 3},
            },
        },
        {
            name = "Zin'aka",
            npcID = 263742,
            displayID = 143835,
            loot = {},
        },
        {
            name = "Umbra",
            npcID = 264172,
            fallbackIcon = "Interface\\Icons\\Spell_Shadow_Shadowform", -- the client cannot draw its model (13.11.2026)
            rare = true,
            loot = {
                {286658, "Umbral Scaled Belt", "Waist, Mail", 3},
                {286662, "Deep-Dweller's Grips", "Hands, Cloth", 3},
            },
        },
        {
            -- rare elite (Wowhead Forever NPC 260468, items 286650 / 286651 "Dropped by" on Wowhead, 13.11.2026)
            name = "\"Pyromancer\" Braxton",
            npcID = 260468,
            displayID = 142457,
            rare = true,
            loot = {
                {286650, "Pyromancer's Baton", "One-Hand, Mace", 3},
                {286651, "Flamestarter's Signet", "Finger", 3},
            },
        },
    },
    -- trash: blue bind-on-equip drops of the dungeon's enemies - Wowhead Forever, one item ID block per new dungeon
    -- (several confirmed by "Dropped by" a mob of this dungeon), 13.11.2026
    trashLoot = {
        {271718, "Linken's Boots of Iron", "Feet, Mail", 3}, -- Wowhead Forever zone drops 13.11.2026
        {286997, "Depth-Risen Leggings", "Legs, Cloth", 3},
        {286998, "Deep Flora Bindings", "Wrist, Cloth", 3},
        {286999, "Deathcrawler's Chest", "Chest, Leather", 3},
        {287000, "Skin-Flayed Footguards", "Feet, Leather", 3},
        {287001, "Waterlogged Shoulderpads", "Shoulder, Leather", 3},
        {287002, "Risen Sentry's Links", "Legs, Mail", 3}, -- Dropped by: Risen Sentry
        {287003, "Corroded Handguards", "Hands, Mail", 3},
        {287004, "Touch of the Depths", "Ranged, Wand", 3},
        {287005, "Sword of Dismemberment", "Two-Hand, Sword", 3},
        {287006, "Resurged Axe", "One-Hand, Axe", 3},
    },
}
