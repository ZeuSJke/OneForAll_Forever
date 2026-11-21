local _, FLT = ...

-- Shaper's Terrace: location and story (Blizzard at BlizzCon via foreverchanges.pro); October 2026.
-- Bosses from the Forever client (DungeonEncounter, wago.tools 1.60.1.70862), NPC IDs and item IDs from Wowhead Forever,
-- loot from wowtbc.gg (08.11.2026, still being discovered); tools/dungeon-check.
-- 13.11.2026 (6.2.7-beta6): boss names, NPC IDs, portraits (displayID), creature types and loot from the Wowhead Forever NPC pages
-- (tools/dungeon-check/apply_wowhead.py); boss levels are known nowhere yet - learned in game when a boss is targeted.
FLT.DUNGEON_REGISTRY["Shaper's Terrace"] = {
    level = "58-60",
    location = "Un'Goro Crater",
    description = "New Forever dungeon: titan terraces, power crystals and ancient wildlife in the hills of Un'Goro Crater. Its loot is still being discovered.",
    icon = "Interface\\Icons\\INV_Misc_Gem_Crystal_02",
    quests = {
        {
            level = 60,
            id = 95928,
            name = "Crystalline Elements",
            requires = 55,
            faction = "Horde",
            pickup = "Mayena Earthseeker, Mulgore (33.6, 21.2)",
            objective = "Bring Mayena Earthseeker a Moist Crystal, a Charged Crystal, a Noxious Crystal and a Fiery Crystal from Shaper's Terrace.",
            turnin = "Mayena Earthseeker, Mulgore",
            rewardChoice = true,
            rewardItems = {
                {279904, "Crystalline Pauldrons", 3},
                {279906, "Potent Treads", 3},
            },
        },
        {
            level = 60,
            id = 95790,
            name = "Digestible Research",
            requires = 55,
            faction = "Alliance",
            objective = "Collect 15 Partially Digested Journal Pages from the Shaper's Terrace.",
            turnin = "Curator Thorius, Ironforge (71.4, 16.2)",
            rewardChoice = true,
            rewardItems = {
                {279931, "Lost Researcher's Hood", 3},
                {279901, "Expeditionary Legplates", 3},
            },
        },
        {
            level = 60,
            id = 95924,
            name = "Panic at the Digsite",
            requires = 55,
            faction = "Alliance",
            pickup = "Curator Thorius, Ironforge (71.5, 15.7)",
            objective = "Slay 6 Ravasaur Matriarchs, 9 Ironhide Ravasaurs and Venomridge in Shaper's Terrace.",
            rewardChoice = true,
            rewardItems = {
                {279903, "Diemetradon Scale Spaulders", 3},
                {279905, "Ravasaur Hide Footpads", 3},
            },
        },
        {
            level = 60,
            id = 95925,
            name = "Mapping the Way Forward",
            requires = 55,
            faction = "Alliance",
            pickup = "Curator Thorius, Ironforge (71.5, 15.7)",
            objective = "Find Interesting Landmarks in Shaper's Terrace and fill out the explorer's map at each.",
            rewardChoice = true,
            rewardItems = {
                {279908, "Crystal-Infused Cleaver", 3},
                {279910, "Beastslayer's Trident", 3},
                {279912, "Faintly Glowing Orb", 3},
            },
        },
        {
            level = 60,
            id = 95926,
            name = "The Dark Crystal",
            requires = 55,
            faction = "Horde",
            pickup = "Master Apothecary Faranell, Undercity (48.8, 69.3)",
            objective = "Gather a colorless Drained Crystal Fragment near the Achromatic Crystal in the Shaper's Terrace.",
            rewardChoice = true,
            rewardItems = {
                {279908, "Crystal-Infused Cleaver", 3},
                {279910, "Beastslayer's Trident", 3},
                {279912, "Faintly Glowing Orb", 3},
            },
        },
        {
            level = 60,
            id = 97049,
            name = "Essence of Seeping Slimes",
            requires = 55,
            faction = "Horde",
            pickup = "Chemist Fuely, Undercity (47.5, 73.3)",
            objective = "Gather 8 Seeping Slime Essence in the Shaper's Terrace.",
            turnin = "Chemist Fuely, Undercity",
            rewardChoice = true,
            rewardItems = {
                {279932, "Slime-Resistant Shroud", 3},
                {279902, "Reinforced Muck Protectors", 3},
            },
        },
    },
    bosses = {
        {
            name = "Titanosaur",
            npcID = 253201,
            displayID = 142989,
            loot = {
                {280009, "Titanosaur Scale Pendant", "Neck", 3},
                {280010, "Gargantuan Wristguards", "Wrist, Plate", 3},
            },
        },
        {
            name = "Ravasaur Hunters",
            npcID = 261811, -- Tor'Rel, the one of the pair Wowhead lists drops for (Izha'Rel 253218)
            displayID = 143039,
            aliases = {"Izha'Rel and Tor'Rel", "Tor'Rel", "Izha'Rel"},
            loot = {
                {280012, "Talon of Tor'Rel", "One-Hand, Sword", 3},
                {280013, "Frostfang Mail Vest", "Chest, Mail", 3},
                {280014, "Raptorscale Bulwark", "Off Hand, Shield", 3},
            },
        },
        {
            name = "Thunderhoof",
            npcID = 261812,
            displayID = 144514,
            loot = {
                {280018, "Hammer of Thundering Hooves", "Two-Hand, Mace", 3},
                {280019, "Dinofrill Casque", "Head, Mail", 3},
                {280020, "Deep Jungle Rifle", "Ranged, Gun", 3},
            },
        },
        {
            name = "Venomridge",
            npcID = 261813,
            displayID = 144511,
            loot = {
                {280015, "Venomvessel Ring", "Finger", 3},
                {280016, "Spiderchitin Wrap", "Chest, Leather", 3},
                {280017, "Octoclaw Chain Boots", "Feet, Mail", 3},
            },
        },
        {
            name = "Direhorn Matriarch",
            npcID = 262127,
            displayID = 144515,
            loot = {
                {280021, "Tooth of the Matriarch", "One-Hand, Dagger", 3},
                {280022, "Scaleguard Scimitar", "One-Hand, Sword", 3},
                {280045, "Regal Direhorn Drape", "Back", 3},
            },
        },
        {
            name = "Cinder",
            npcID = 261974,
            displayID = 143035,
            loot = {
                {280028, "Heartflame Gauntlets", "Hands, Plate", 3},
                {280029, "Cinderedge Crescent", "One-Hand, Axe", 3},
            },
        },
        {
            name = "King Op",
            npcID = 261993,
            displayID = 143129,
            rare = true,
            loot = {},
        },
        {
            name = "Snowtalon",
            npcID = 262297,
            displayID = 143122,
            loot = {
                {280026, "Albinofur Grips", "Hands, Mail", 3},
                {280027, "Crownroar Chestplate", "Chest, Plate", 3},
            },
        },
        {
            name = "Bolt",
            npcID = 262081,
            displayID = 143063,
            loot = {
                {280031, "Sparklance Wand", "Ranged, Wand", 3},
                {280032, "Bolt's Charged Eyeball", "Trinket", 3},
            },
        },
        {
            name = "Vitrix",
            npcID = 272561,
            displayID = 147098,
            loot = {
                {280026, "Albinofur Grips", "Hands, Mail", 3},
                {280027, "Crownroar Chestplate", "Chest, Plate", 3},
                {280032, "Bolt's Charged Eyeball", "Trinket", 3},
            },
        },
        {
            name = "Nanaya",
            npcID = 261809,
            displayID = 143832,
            loot = {
                {280023, "Nanaya's Control Spire", "Two-Hand, Staff", 3},
                {280024, "Legplates of Reinforced Crystal", "Legs, Plate", 3},
                {280025, "Leggings of Curation", "Legs, Cloth", 3},
            },
        },
    },
    -- trash: blue bind-on-equip drops of the dungeon's enemies - Wowhead Forever, one item ID block per new dungeon
    -- (several confirmed by "Dropped by" a mob of this dungeon), 13.11.2026
    trashLoot = {
        {287037, "Shaper's Robe", "Chest, Cloth", 3},
        {287038, "Naturopathy Footpads", "Feet, Cloth", 3},
        {287039, "Tattered Explorer's Cuffs", "Wrist, Leather", 3},
        {287040, "Dinosaur Hide Belt", "Waist, Leather", 3},
        {287041, "Time-Forgotten Bindings", "Wrist, Mail", 3},
        {287042, "Pauldrons of the Stone Guardian", "Shoulder, Plate", 3},
        {287043, "Predaceous Band", "Finger", 3},
        {287044, "Predator's Shroud", "Back", 3},
        {287045, "Ancient Mattock", "One-Hand, Axe", 3}, -- Dropped by: Ravasaur Juvenile
        {287046, "Pylon Poker", "Two-Hand, Staff", 3},
    },
}
