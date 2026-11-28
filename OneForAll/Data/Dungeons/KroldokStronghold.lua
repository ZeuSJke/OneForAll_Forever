local _, FLT = ...

-- Krol'dok Stronghold: location and story (Blizzard at BlizzCon / PAX Australia via foreverchanges.pro); October 2026.
-- Bosses from the Forever client (DungeonEncounter, wago.tools 1.60.1.70862), NPC IDs and item IDs from Wowhead Forever,
-- loot from wowtbc.gg (08.11.2026, still being discovered); tools/dungeon-check.
-- 13.11.2026 (6.2.7-beta6): boss names, NPC IDs, portraits (displayID), creature types and loot from the Wowhead Forever NPC pages
-- (tools/dungeon-check/apply_wowhead.py); boss levels are known nowhere yet - learned in game when a boss is targeted.
FLT.DUNGEON_REGISTRY["Krol'dok Stronghold"] = {
    level = "40-47",
    location = "Riverglades",
    description = "New Forever dungeon: a Twilight's Hammer ogre fortress on a hill in the Riverglades. The ogres raid nearby settlements and take prisoners. Its loot is still being discovered.",
    icon = "Interface\\Icons\\INV_Misc_Bone_OrcSkull_01",
    quests = {
        -- (Key Ingredients 94974 / 94981: on the Key page since 6.2.12-beta25, Data/DungeonKeys.lua)
        {
            level = 42,
            id = 94975,
            liveXPFallback = 8200,
            name = "A Token of Vengeance",
            requires = 38,
            faction = "Horde",
            pickup = "Da'grosh, inside Krol'dok Stronghold",
            objective = "Collect 15 Cultist Ears from the Twilight's Hammer in Krol'dok Stronghold.",
            turnin = "Da'grosh, inside Krol'dok Stronghold",
            rewardItems = {
                {267090, "Semblance of Twilight", 2},
            },
            rewardSummary = "8,200 XP",
        },
        {
            level = 42,
            id = 94983,
            liveXPFallback = 10200,
            name = "Twilight Mementos",
            requires = 38,
            faction = "Alliance",
            pickup = "Sergeant Riftan, Riverglades (30.7, 49.1)",
            objective = "Collect 8 Cultist Bangles from the Twilight's Hammer in Krol'dok Stronghold.",
            turnin = "Sergeant Riftan, Riverglades",
            note = "The part inside the dungeon. Its reward comes two steps later with Curios of Curiosity (Lingering Essence, then Curios of Curiosity - both outside).",
            rewardItems = {
            },
            rewardSummary = "10,200 XP · +150 Brotherhood of the Horse",
        },
        {
            level = 42,
            id = 94998,
            liveXPFallback = 3450,
            name = "Curios of Curiosity",
            requires = 38,
            faction = "Alliance",
            pickup = "Ashe Amberhall, Riverglades (66.8, 81.1)",
            objective = "Bring the Satchel of Mementos to Melanie Sable.",
            turnin = "Melanie Sable, Riverglades",
            rewardChoice = true,
            note = "No dungeon objective: the last step after Twilight Mementos, done outside in Farholde Keep - it gives that chain's reward.",
            rewardItems = {
                {279850, "Curio-Adorned Necklace", 3},
            },
            rewardSummary = "3,450 XP · 55s · +100 Brotherhood of the Horse",
        },
        {
            level = 44,
            id = 94972,
            liveXPFallback = 11050,
            name = "Tome of Twilight",
            requires = 39,
            faction = "Horde",
            pickup = "Tran'gul, Riverglades (59.4, 44.2)",
            objective = "Recover the Tome of Twilight from Krol'dok Stronghold.",
            turnin = "Tran'gul, Riverglades",
            rewardChoice = true,
            rewardItems = {
                {279859, "Indoctrinated Choker", 2},
                {279860, "Convert's Bindings", 2},
            },
            rewardSummary = "11,050 XP",
        },
        {
            level = 44,
            id = 94984,
            liveXPFallback = 11050,
            name = "Tome of Twilight",
            requires = 39,
            faction = "Alliance",
            pickup = "Ashe Amberhall, Riverglades (66.8, 81.1)",
            objective = "Kill Nar'gurk within Krol'dok Stronghold and recover any valuable information.",
            turnin = "Ashe Amberhall, Riverglades",
            rewardChoice = true,
            rewardItems = {
                {279854, "Twilight Initiate's Belt", 2},
                {279855, "Torn Cultist Cloak", 2},
            },
            rewardSummary = "11,050 XP · +150 Brotherhood of the Horse",
        },
        {
            level = 45,
            id = 94968,
            liveXPFallback = 11500,
            name = "Eye of Mugg",
            requires = 40,
            faction = "Horde",
            pickup = "Krom'rosh, Riverglades (59.4, 45.6)",
            objective = "Infiltrate Krol'dok Stronghold and return to Krom'rosh with proof of their leader's demise.",
            turnin = "Krom'rosh, Riverglades",
            rewardChoice = true,
            rewardItems = {
                {279852, "Rock on Stick", 3},
                {279480, "Bigger Rock on Bigger Stick", 3},
                {279853, "Stick No Rock", 3},
            },
            rewardSummary = "11,500 XP · 1g 30s",
        },
        {
            level = 45,
            id = 94982,
            liveXPFallback = 11500,
            name = "Eye of Mugg",
            requires = 40,
            faction = "Alliance",
            pickup = "Demar Brant, Riverglades (66.7, 81.0)",
            objective = "Infiltrate Krol'dok Stronghold and return to Commander Brant with proof of their leader's demise.",
            turnin = "Demar Brant, Riverglades",
            rewardChoice = true,
            rewardItems = {
                {279852, "Rock on Stick", 3},
                {279853, "Stick No Rock", 3},
                {279480, "Bigger Rock on Bigger Stick", 3},
            },
            rewardSummary = "11,500 XP · 1g 30s · +150 Brotherhood of the Horse",
        },
        {
            level = 45,
            id = 96771,
            liveXPFallback = 11500,
            name = "Vengeance of the Highborne",
            requires = 37,
            faction = "Alliance",
            objective = "Travel to Krol'dok Stronghold and slay Zalfan Moonshadow.",
            rewardItems = {
            },
            rewardSummary = "11,500 XP · 65s · +150 Brotherhood of the Horse · +250 Kirin Tor",
        },
    },
    bosses = {
        {
            name = "Slavecrusher Grox",
            npcID = 258966,
            displayID = 141217,
            loot = {
                {273101, "Blueprint: Expert Campfire", "Blueprint", 2}, -- Dungeon Journal (user 25.11.2026)
                {274996, "Resistance Breaker Spaulder", "Shoulder, Mail", 3},
                {274995, "Slavecrusher Scepter", "One-Hand, Mace", 3},
                {274997, "Chain of Binding", "Waist, Mail", 3},
            },
        },
        {
            name = "Twilight Commander Zarmok",
            npcID = 258972,
            displayID = 141219,
            loot = {
                {274998, "Shadowlight Athame", "Main Hand, Dagger", 3},
                {274999, "Shadecaster's Leggings", "Legs, Cloth", 3},
                {275000, "Zarmok's Plated Signet", "Finger", 3},
            },
        },
        {
            name = "War Handler Ashka",
            npcID = 259281,
            fallbackIcon = "Interface\\Icons\\INV_Misc_Head_Orc_01", -- the client cannot draw its model (13.11.2026)
            aliases = {"Handler Ashka"},
            loot = {
                {275001, "Bloodied Gutslicer", "Two-Hand, Sword", 3},
                {275002, "War Handler's Gaze", "Head, Leather", 3},
                {275003, "Worgbinder's Treads", "Feet, Plate", 3},
            },
        },
        {
            name = "Nar'gurk",
            npcID = 258964,
            displayID = 141215,
            loot = {
                {275004, "Chain of the Corruptor", "Neck", 3},
                {275005, "Krol'dok Warplate Chest", "Chest, Plate", 3},
                {275006, "Krol'dok Warplate Helmet", "Head, Plate", 3},
            },
        },
        {
            name = "Overlord Mugg",
            npcID = 258968,
            fallbackIcon = "Interface\\Icons\\INV_Misc_Bone_OrcSkull_01", -- the client cannot draw its model (13.11.2026)
            aliases = {"Overseer Mugg"},
            loot = {
                {275009, "Emblem of Slamming", "Trinket", 3},
                {275007, "Mugg's Jabber", "One-Hand, Fist Weapon", 3},
                {275008, "Mugg's Crosser", "One-Hand, Fist Weapon", 3},
                {275010, "Strongly Scented Hood", "Head, Cloth", 3},
            },
        },
        {
            name = "Bossman Toof",
            npcID = 264773,
            displayID = 14424,
            loot = {
                {286429, "Big-Belly Belt", "Waist, Cloth", 3},
                {286428, "Band of Bossman", "Finger", 3},
                {286430, "Toofbreaker", "One-Hand, Mace", 3},
            },
        },
        {
            -- rare elite (Wowhead Forever NPC 262716: drops 279857 / 279863, item level 43; in Krol'dok per the user's source)
            name = "Kroog",
            npcID = 262716,
            displayID = 17273,
            rare = true,
            loot = {
                {279857, "Kroog's Backscratcher", "One-Hand, Dagger", 3},
                {279863, "Black Horn Necklace", "Neck", 3},
            },
        },
    },
    -- trash: blue bind-on-equip drops of the dungeon's enemies - Wowhead Forever, one item ID block per new dungeon
    -- (several confirmed by "Dropped by" a mob of this dungeon), 13.11.2026
    trashLoot = {
        {287007, "Stretched Footpads", "Feet, Cloth", 3},
        {287008, "Ogre Magi's Mantle", "Shoulder, Cloth", 3},
        {287009, "Twilight Enforcer's Legs", "Legs, Leather", 3},
        {287010, "Outrider's Gloves", "Hands, Leather", 3}, -- Dropped by: Twilight Outrider
        {287011, "Guise of Battle", "Head, Mail", 3},
        {287012, "Krol'dok Warplate Gauntlets", "Hands, Plate", 3},
        {287013, "Krol'dok Warplate Legplates", "Legs, Plate", 3},
        {287014, "Krol'dok Warplate Pauldrons", "Shoulder, Plate", 3},
        {287015, "Supreme Smasher", "Two-Hand, Mace", 3},
        {287016, "Shadow-Seer Orb", "Held In Off-Hand", 3},
    },
}
