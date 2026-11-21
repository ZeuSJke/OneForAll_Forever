local _, FLT = ...

-- Blackmaw Hold: location and story (Blizzard at BlizzCon via foreverchanges.pro); October 2026.
-- Bosses from the Forever client (DungeonEncounter, wago.tools 1.60.1.70862), NPC IDs and item IDs from Wowhead Forever,
-- loot from wowtbc.gg (08.11.2026, still being discovered); tools/dungeon-check.
-- 13.11.2026 (6.2.7-beta6): boss names, NPC IDs, portraits (displayID), creature types and loot from the Wowhead Forever NPC pages
-- (tools/dungeon-check/apply_wowhead.py); boss levels are known nowhere yet - learned in game when a boss is targeted.
FLT.DUNGEON_REGISTRY["Blackmaw Hold"] = {
    level = "55-60",
    location = "Behind the Furbolg gate, Azshara",
    description = "New Forever dungeon: a great furbolg city behind the gates of northern Azshara, whose people fight the corruption spreading through it. Its tunnels lead toward the Barrow Deeps raid. Its loot is still being discovered.",
    icon = "Interface\\Icons\\INV_Misc_Pelt_Bear_03",
    quests = {
        {
            level = 55,
            id = 92343,
            name = "Get to the Roots of It",
            requires = 45,
            faction = "Horde",
            pickup = "Nara Wildmane, Thunder Bluff (75.7, 31.6)",
            objective = "Gather 10 Nordrassil Root Caps inside Blackmaw Hold for Nara Wildmane in Thunder Bluff.",
            turnin = "Nara Wildmane, Thunder Bluff",
            rewardItems = {
            },
        },
        {
            level = 55,
            id = 92344,
            name = "Get to the Roots of It",
            requires = 45,
            faction = "Alliance",
            pickup = "Mathrengyl Bearwalker, Darnassus (35.4, 8.4)",
            objective = "Gather 10 Nordrassil Root Caps inside Blackmaw Hold for Mathrengyl Bearwalker in Darnassus.",
            turnin = "Mathrengyl Bearwalker, Darnassus",
            rewardItems = {
            },
        },
        {
            level = 59,
            id = 97173,
            name = "Blackmaw Magic",
            requires = 52,
            faction = "Alliance",
            objective = "Recover a Blackmaw Ritual Totem from Blackmaw Hold.",
            rewardItems = {
            },
        },
        {
            level = 59,
            id = 97198,
            name = "Blackmaw Magic",
            requires = 52,
            faction = "Horde",
            objective = "Recover a Blackmaw Ritual Totem from Blackmaw Hold.",
            rewardItems = {
            },
        },
        {
            level = 58,
            id = 92069,
            name = "Claws That Rend, Tusks that Gore",
            faction = "Both",
            pickup = "Ogtinc, Azshara (42.4, 42.6)",
            objective = "Bring the Claws of the Great Bear and the Tusks of the Unbroken to Ogtinc, in Azshara.",
            turnin = "Ogtinc, Azshara",
            rewardChoice = true,
            rewardItems = {
                {260213, "Great Bear Claw", 2},
                {260214, "Staff of Wild Beasts", 2},
                {260215, "Wild Malleus", 2},
            },
            note = "Still being discovered: who gives this quest and its rewards are not known yet.",
        },
        {
            level = 55,
            id = 92070,
            name = "A Lost Memento",
            faction = "Both",
            pickup = "Feathered Charm Necklace, dropped by Legashi Satyr",
            objective = "Find the owner of the Feathered Charm Necklace.",
            turnin = "Unele, Azshara (43.0, 18.2)",
            rewardChoice = true,
            rewardItems = {
                {279893, "Nama's Cherished Necklace", 2},
            },
        },
        {
            level = 55,
            id = 92066,
            name = "The Twin Bears",
            requires = 55,
            faction = "Both",
            pickup = "Lorekeeper Nok, Azshara (41.4, 20.0)",
            objective = "Find the Totem of Ursoc and the Totem of Ursol inside Blackmaw Hold. Then, return them to Lorekeeper Nok at Ursolan.",
            turnin = "Lorekeeper Nok, Azshara (41.4, 20.0)",
            rewardChoice = true,
            rewardItems = {
                {279891, "Guidance of Ursoc", 2},
                {279892, "Wisdom of Ursol", 2},
            },
        },
        {
            level = 60,
            id = 97327,
            name = "Blackmaw Pouches",
            requires = 60,
            faction = "Both",
            pickup = "Ekkal, Azshara (42.0, 38.9)",
            objective = "Enter Blackmaw Hold and recover 5 Blackmaw Pouches for Ekkal at the Ruins of Eldarath in Azshara.",
            turnin = "Ekkal, Azshara",
            rewardItems = {
            },
        },
        {
            level = 58,
            id = 99187,
            name = "The Reliquary of Tyr",
            requires = 50,
            faction = "Horde",
            class = "PALADIN",
            objective = "Travel to Blackmaw Hold in Kalimdor, and recover the Reliquary of Tyr.",
            rewardItems = {{286408, "Sword of Mourning", 3}},
        },
    },
    bosses = {
        {
            name = "Withermaw",
            npcID = 247195,
            displayID = 140708,
            loot = {
                {280062, "Cloak of the Fleshborer", "Back", 3},
                {280063, "Bloodfur Bulwark", "Off Hand, Shield", 3},
                {280064, "Withering Grips", "Hands, Leather", 3},
            },
        },
        {
            name = "Impaan the Imprisoner",
            npcID = 247206,
            displayID = 130432,
            loot = {
                {280056, "Flameslash Crescent", "Two-Hand, Axe", 3},
                {280057, "Robes of Dark Summons", "Chest, Cloth", 3},
                {280058, "Impish Chain Hood", "Head, Mail", 3},
            },
        },
        {
            name = "Elder Shaman Bloodmane",
            npcID = 247209,
            displayID = 130440,
            loot = {
                {280068, "Bloody Claws of Attack", "One-Hand, Fist Weapon", 3},
                {280070, "Veilpiercer Girdle", "Waist, Leather", 3},
                {280069, "Shamanic Wristguards", "Wrist, Mail", 3},
            },
        },
        {
            name = "Bonesnout the Unbroken",
            npcID = 247198,
            displayID = 130427,
            loot = {
                {280059, "Tuskblade Halberd", "Two-Hand, Polearm", 3},
                {280060, "Lucky Shovelnose Tuft", "Trinket", 3},
                {280061, "Spike Crested Bracers", "Wrist, Plate", 3},
            },
        },
        {
            name = "Varrox Bleakhoof",
            npcID = 247234,
            displayID = 130447,
            loot = {
                {280074, "Scalding Flamehoof", "Trinket", 3},
                {280075, "Bleak Eye Shoulderplates", "Shoulder, Plate", 3},
                {280076, "Horns of Varrox", "Head, Leather", 3},
            },
        },
        {
            name = "Blackmaw Behemoth",
            npcID = 247207,
            displayID = 130436,
            loot = {
                {280065, "Behemoth Bones", "Trinket", 3},
                {280066, "Trousers of the Ebon Giant", "Legs, Cloth", 3},
                {280067, "Blackmaw Chain Belt", "Waist, Mail", 3},
            },
        },
        {
            name = "Unbound Spirit",
            npcID = 247231,
            displayID = 131644,
            loot = {
                {280071, "Flamebreak Talisman", "Trinket", 3},
                {280072, "Cowl of Dark Ambition", "Head, Cloth", 3},
                {280073, "Burnished Pridescales", "Chest, Plate", 3},
            },
        },
        {
            name = "Moontouched Wanderer",
            npcID = 269104,
            displayID = 12235,
            rare = true,
            loot = {
                {280079, "Lunarlight Robe", "Chest, Leather", 3},
                {280080, "Claymore of Two Moons", "Two-Hand, Sword", 3},
            },
        },
        {
            -- rare elite (Wowhead Forever NPC 269111, 13.11.2026)
            name = "Gortek the Apprentice",
            npcID = 269111,
            displayID = 145808,
            rare = true,
            loot = {
                {280077, "Fist of Revelation", "One-Hand, Fist Weapon", 3},
            },
        },
        {
            -- rare elite (Wowhead Forever NPC 250034, 13.11.2026)
            name = "Tunnelweb Matriarch",
            npcID = 250034,
            displayID = 2424,
            rare = true,
            loot = {
                {280085, "Tunnelweb Pincer", "One-Hand, Dagger", 3},
                {280086, "Octofinger Gauntlets", "Hands, Plate", 3},
            },
        },
    },
    -- trash: blue bind-on-equip drops of the dungeon's enemies - Wowhead Forever, one item ID block per new dungeon
    -- (several confirmed by "Dropped by" a mob of this dungeon), 13.11.2026
    trashLoot = {
        {287028, "Tormented Cuffs", "Wrist, Cloth", 3},
        {287029, "Nature Guardian's Legguards", "Legs, Leather", 3},
        {287030, "Blackmaw Bindings", "Wrist, Mail", 3},
        {287031, "Spearfisher's Waders", "Legs, Mail", 3},
        {287032, "Den Champion's Binding", "Waist, Plate", 3}, -- Dropped by: Legashi Slayer
        {287033, "Furbolg Berserker's Boots", "Feet, Plate", 3}, -- Dropped by: Blackmaw Devotee
        {287034, "Grove Subjugator's Blade", "One-Hand, Dagger", 3}, -- Dropped by: Swarming Imp
        {287035, "Demon Worshipper's Necklace", "Neck", 3},
        {287036, "Satyr's Touch", "Ranged, Wand", 3},
    },
}
