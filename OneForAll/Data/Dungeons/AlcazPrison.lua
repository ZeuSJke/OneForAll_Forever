local _, FLT = ...

-- Alcaz Prison: location and story (Blizzard at BlizzCon via foreverchanges.pro); October 2026.
-- Bosses from the Forever client (DungeonEncounter, wago.tools 1.60.1.70862), NPC IDs and item IDs from Wowhead Forever,
-- loot from wowtbc.gg (08.11.2026, still being discovered); tools/dungeon-check.
-- 13.11.2026 (6.2.7-beta6): boss names, NPC IDs, portraits (displayID), creature types and loot from the Wowhead Forever NPC pages
-- (tools/dungeon-check/apply_wowhead.py); boss levels are known nowhere yet - learned in game when a boss is targeted.
FLT.DUNGEON_REGISTRY["Alcaz Prison"] = {
    level = "48-55",
    location = "Alcaz Island, Dustwallow Marsh",
    description = "New Forever dungeon: a Defias prison on Alcaz Island where nobles were held for ransom, and rumour says Varian Wrynn was one of them. Now the Defias fight the naga inside. Its loot is still being discovered.",
    icon = "Interface\\Icons\\Spell_Frost_ChainsOfIce",
    quests = {
        {
            level = 53,
            id = 96772,
            name = "The Dragon's Journal",
            requires = 46,
            faction = "Alliance",
            pickup = "Archmage Lan'dalock, Alterac Mountains (15.9, 73.1)",
            objective = "Recover Zarla's Journal from the depths of Alcaz Prison.",
            rewardItems = {
            },
        },
        {
            level = 53,
            id = 95262,
            name = "The Secret Prison",
            requires = 48,
            faction = "Alliance",
            pickup = "Sully McCleary, Dustwallow Marsh (63.5, 42.3)",
            objective = "Enter Alcaz Prison and learn what became of the King of Stormwind.",
            rewardItems = {
            },
        },
        {
            level = 53,
            id = 95309,
            name = "No Orc Left Behind",
            requires = 48,
            faction = "Horde",
            pickup = "Sergeant Ulka, Dustwallow Marsh (70.3, 18.9)",
            objective = "Enter the Alcaz Prison and find Commander Folkar.",
            rewardItems = {
            },
        },
        {
            level = 53,
            id = 95454,
            name = "The Honor of the Kor'kron",
            requires = 48,
            faction = "Horde",
            objective = "Look for King Varian Wrynn in Alcaz Prison.",
            rewardItems = {
            },
        },
        {
            level = 53,
            id = 96332,
            name = "A Little Payback",
            requires = 48,
            faction = "Horde",
            pickup = "Sergeant Ulka, Dustwallow Marsh (70.3, 18.9)",
            objective = "Enter the Alcaz Prison and slay 15 Strashasz Soldiers, 8 Strashaz Enchantresses, and bring the head of Tidemistress Ca'zass to Sergeant Ulka.",
            turnin = "Sergeant Ulka, Dustwallow Marsh",
            rewardChoice = true,
            rewardItems = {
                {279824, "Kor'kron Battle Gauntlets", 2},
                {279826, "Marshdweller's Pants", 2},
                {279829, "Naga Scale Spaulders", 2},
            },
        },
        {
            level = 53,
            id = 96334,
            name = "Blood Red Bandanas",
            requires = 48,
            faction = "Horde",
            pickup = "Sergeant Ulka, Dustwallow Marsh (70.3, 18.9)",
            objective = "Enter Alcaz Prison and collect 8 Blood Red Bandanas from the human guards there.",
            turnin = "Eitrigg, Orgrimmar",
            rewardChoice = true,
            rewardItems = {
                {279448, "Bloodsplattered Bandana", 2},
                {279473, "Makeshift Belt", 2},
            },
        },
        {
            level = 53,
            id = 96335,
            name = "The Man in the Iron Chains",
            requires = 53,
            faction = "Both",
            objective = "Recover the Alcaz Shackle Key from The Questioner in Alcaz Prison.",
            rewardItems = {
            },
        },
        {
            level = 53,
            id = 96381,
            name = "A Bit of Wet Work",
            requires = 48,
            faction = "Alliance",
            pickup = "Sully McCleary, Dustwallow Marsh (63.5, 42.3)",
            objective = "Enter the Alcaz Prison and slay 15  Strashasz Soldiers, 8 Strashaz Enchantresses, and bring the head of Tidemistress Ca'zass to Sully McCleary.",
            turnin = "Sully McCleary, Dustwallow Marsh",
            rewardChoice = true,
            rewardItems = {
                {279825, "Theramore Defender's Gauntlets", 2},
                {279826, "Marshdweller's Pants", 2},
                {279829, "Naga Scale Spaulders", 2},
            },
        },
    },
    bosses = {
        {
            name = "Overseer Wrex",
            npcID = 255391,
            displayID = 7914,
            loot = {
                {276734, "Wrex's Pinky Ring", "Finger", 3},
                {276732, "Alcaz Willcrusher", "Two-Hand, Mace", 3},
                {276733, "Grips of Control", "Hands, Plate", 3},
            },
        },
        {
            name = "Tidemistress Ca'zass",
            npcID = 255997,
            displayID = 4973,
            loot = {
                {276737, "Cloak of the Tidemistress", "Back", 3},
                {276735, "Tidesong Wand", "Ranged, Wand", 3},
                {276736, "Seascale Bracers", "Wrist, Mail", 3},
            },
        },
        {
            name = "Katerina the Cleaner",
            npcID = 257016,
            displayID = 2317,
            loot = {
                {276740, "Sentimental Locket", "Neck", 3},
                {276738, "Katerina's Shanker", "One-Hand, Dagger", 3},
                {276739, "Cutthroat Chestguard", "Chest, Mail", 3},
            },
        },
        {
            name = "The Questioner",
            npcID = 256236,
            displayID = 140092,
            loot = {
                {276742, "Girdle of Extracted Answers", "Waist, Plate", 3},
                {276741, "Defias Enforcer's Shoulderpads", "Shoulder, Leather", 3},
                {276743, "Fingerbreaker Stamp", "Trinket", 3},
            },
        },
        {
            name = "Blazeroar",
            npcID = 255702,
            displayID = 6374,
            loot = {
                {276744, "Zarla's Snack Pouch", "Trinket", 3},
                {276745, "Beastbond Robe", "Chest, Cloth", 3},
                {276746, "Defias Enforcer's Legguards", "Legs, Leather", 3},
            },
        },
        {
            name = "Zarla Ober",
            npcID = 255707,
            displayID = 139053,
            loot = {},
        },
    },
    -- trash: blue bind-on-equip drops of the dungeon's enemies - Wowhead Forever, one item ID block per new dungeon
    -- (several confirmed by "Dropped by" a mob of this dungeon), 13.11.2026
    trashLoot = {
        {287017, "Chaplain's Mitre", "Head, Cloth", 3}, -- Dropped by: Slavering Hound
        {287018, "Compound Gloves", "Hands, Cloth", 3},
        {287019, "Defias Enforcer's Mask", "Head, Leather", 3},
        {287020, "Defias Enforcer's Chest", "Chest, Leather", 3},
        {287021, "Defias Enforcer's Prowlers", "Feet, Leather", 3},
        {287022, "Spaulders of Containment", "Shoulder, Mail", 3},
        {287023, "Iron-Wrought Cuffs", "Wrist, Plate", 3},
        {287024, "Mark of Captivity", "Neck", 3},
        {287025, "Enchantresses' Spire", "Two-Hand, Staff", 3}, -- Dropped by: Strashaz Enchantress
        {287026, "Escape Plan", "Ranged, Gun", 3},
    },
}
