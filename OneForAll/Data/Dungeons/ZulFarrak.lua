local _, FLT = ...

-- Zul'Farrak: quests (QuestieDB Forever), boss loot (wowtbc.gg, foreverchanges.pro for the event bosses), trash loot (foreverchanges.pro); October 2026.
FLT.DUNGEON_REGISTRY["Zul'Farrak"] = {
    level = "44-54",
    location = "Tanaris",
    description = "The sun-baked capital of the Sandfury trolls in northern Tanaris. Chief Ukorz Sandscalp rules from the city, and Gahz'rilla sleeps in its sacred pool.",
    icon = "Interface\\Icons\\INV_Misc_Head_Troll_01",
    quests = {
        {
            id = 2936,
            liveXPFallback = 9700,
            name = "The Spider God",
            level = 45,
            requires = 40,
            faction = "Horde",
            pickup = "Master Gadrin, Durotar (56.0, 74.7)",
            objective = "Read from the Tablet of Theka to learn the name of the Witherbark spider god, then return to Master Gadrin.",
            turnin = "Master Gadrin, Durotar",
            rewardSummary = "9,700 XP · +150 Darkspear Trolls",
        },
        {
            id = 2991,
            liveXPFallback = 10500,
            name = "Nekrum's Medallion",
            level = 47,
            requires = 40,
            faction = "Alliance",
            pickup = "Thadius Grimshade, Blasted Lands (66.9, 19.5)",
            objective = "Bring Nekrum's Medallion to Thadius Grimshade in the Blasted Lands.",
            turnin = "Thadius Grimshade, Blasted Lands",
            note = "Nekrum Gutchewer joins the fight on the temple stairs, after Sergeant Bly's group frees the prisoners.",
            rewardSummary = "10,500 XP · 70s",
        },
        {
            id = 2768,
            liveXPFallback = 12600,
            name = "Divino-matic Rod",
            level = 47,
            requires = 40,
            pickup = "Chief Engineer Bilgewhizzle, Tanaris (52.5, 28.5)",
            objective = "Bring the Divino-matic Rod to Chief Engineer Bilgewhizzle in Gadgetzan.",
            turnin = "Chief Engineer Bilgewhizzle, Tanaris",
            rewardChoice = true,
            rewardItems = {
                {9533, "Masons Fraternity Ring", 3},
                {9534, "Engineer's Guild Headpiece", 3},
                {270099, "Magister Cowl", 3},
            },
            rewardSummary = "12,600 XP · +200 Gadgetzan",
        },
        {
            id = 2865,
            liveXPFallback = 7800,
            name = "Scarab Shells",
            level = 45,
            requires = 40,
            pickup = "Tran'rek, Tanaris (51.6, 26.8)",
            objective = "Bring 5 Uncracked Scarab Shells to Tran'rek in Gadgetzan.",
            turnin = "Tran'rek, Tanaris",
            rewardSummary = "7,800 XP · 65s",
        },
        {
            id = 3042,
            liveXPFallback = 7800,
            name = "Troll Temper",
            level = 45,
            requires = 40,
            pickup = "Trenton Lighthammer, Tanaris (51.4, 28.8)",
            objective = "Bring 20 Vials of Troll Temper to Trenton Lighthammer in Gadgetzan.",
            turnin = "Trenton Lighthammer, Tanaris",
            rewardSummary = "7,800 XP · 1g 95s",
        },
        {
            id = 2846,
            liveXPFallback = 12100,
            name = "Tiara of the Deep",
            level = 46,
            requires = 40,
            pickup = "Tabetha, Dustwallow Marsh (46.1, 57.1)",
            objective = "Bring the Tiara of the Deep to Tabetha in Dustwallow Marsh.",
            turnin = "Tabetha, Dustwallow Marsh",
            rewardChoice = true,
            rewardItems = {
                {9531, "Gemshale Pauldrons", 2},
                {270098, "Dank Shoulderpads", 2},
            },
            rewardAlso = {
                {9527, "Spellshifter Rod", 2},
            },
            rewardSummary = "12,100 XP · 65s",
        },
        {
            id = 2770,
            liveXPFallback = 14200,
            name = "Gahz'rilla",
            level = 50,
            requires = 40,
            pickup = "Wizzle Brassbolts, Thousand Needles (78.1, 77.1)",
            objective = "Bring Gahz'rilla's Electrified Scale to Wizzle Brassbolts in the Shimmering Flats.",
            turnin = "Wizzle Brassbolts, Thousand Needles",
            rewardItems = {{11122, "Carrot on a Stick", 2}},
            note = "Someone in the group needs the Mallet of Zul'Farrak to summon Gahz'rilla at the pool. It is made from the Sacred Mallet (Qiaga the Keeper, The Hinterlands) at the altar of Jintha'Alor.",
            rewardSummary = "14,200 XP · 75s",
        },
        {
            id = 3527,
            liveXPFallback = 10500,
            name = "The Prophecy of Mosh'aru",
            level = 47,
            requires = 40,
            pickup = "Yeh'kinya, Tanaris (67.0, 22.4)",
            objective = "Bring the First and Second Mosh'aru Tablets to Yeh'kinya in Tanaris.",
            turnin = "Yeh'kinya, Tanaris",
            rewardSummary = "10,500 XP",
        },
        {
            level = 46,
            id = 2769,
            liveXPFallback = 410,
            name = "The Brassbolts Brothers",
            requires = 40,
            faction = "Alliance",
            pickup = "Klockmort Spannerspan, Ironforge (67.9, 46.1)",
            objective = "Speak with Wizzle Brassbolts in the Shimmering Flats.",
            turnin = "Wizzle Brassbolts, Thousand Needles",
            rewardItems = {
            },
            rewardSummary = "410 XP",
        },
        {
            level = 46,
            id = 2861,
            liveXPFallback = 410,
            name = "Tabetha's Task",
            requires = 40,
            faction = "Both",
            pickup = "Anastasia Hartwell, Undercity (85.1, 10.0)",
            objective = "Speak with Tabetha in Dustwallow Marsh.",
            turnin = "Tabetha, Dustwallow Marsh",
            rewardItems = {
            },
            rewardSummary = "410 XP",
        },
        {
            level = 50,
            id = 80411,
            liveXPFallback = 4700,
            name = "The Talisman of Kazdor",
            requires = 45,
            faction = "Both",
            class = "ROGUE",
            pickup = "Fahrad, Alterac Mountains (84.5, 80.3)",
            objective = "Find The Talisman of Kazdor inside of Zul'Farrak. Then, bring it to Fahrad at Ravenholdt Manor. You must complete the job alone.",
            turnin = "Fahrad, Alterac Mountains",
            rewardItems = {
            },
            rewardSummary = "4,700 XP · 1g 4s 12c",
        },
        {
            level = 46,
            id = 96770,
            liveXPFallback = 10100,
            name = "The Witch Doctor's Head",
            requires = 39,
            faction = "Alliance",
            pickup = "Archmage Lan'dalock, Alterac Mountains (15.3, 73.9)",
            objective = "Slay Witch Doctor Zum'rah and bring Zum'rah's Head to Archmage Lan'dalock in Dalaran.",
            turnin = "Archmage Lan'dalock, Alterac Mountains",
            rewardItems = {
            },
            rewardSummary = "10,100 XP · 1g 30s · +300 Kirin Tor",
        },
        {
            level = 46,
            id = 96775,
            liveXPFallback = 10100,
            name = "Zum'rah's Head",
            requires = 42,
            faction = "Horde",
            pickup = "Mazu'kon, Mulgore (32.5, 20.7)",
            objective = "Slay Witch Doctor Zum'rah and bring Zum'rah's Head to Mazu'kon in Mulgore.",
            turnin = "Mazu'kon, Mulgore",
            rewardItems = {
            },
            rewardSummary = "10,100 XP · 65s · +150 Darkspear Trolls · +300 Earthen Ring",
        },
        {
            level = 45,
            id = 82084,
            liveXPFallback = 3900,
            name = "A Lesson in Literacy",
            requires = 42,
            faction = "Both",
            class = "MAGE",
            pickup = "Owen Thadd, Undercity (73.4, 33.0)",
            objective = "Track down and collect the spellbook materials requested by the librarian.",
            turnin = "Owen Thadd, Undercity",
            rewardItems = {
            },
            rewardSummary = "3,900 XP",
        },
    },
    bosses = {
        {
            name = "Antu'sul",
            npcID = 8127,
            displayID = 7353,
            loot = {
                {9484, "Spellshock Leggings", "Legs, Cloth", 3}, -- Dungeon Journal (user 25.11.2026)
                {9379, "Sang'thraze the Deflector", "One-Hand, Sword", 3},
                {9639, "The Hand of Antu'sul", "Main Hand, Mace", 3},
                {9640, "Vice Grips", "Hands, Plate", 3},
                {9641, "Lifeblood Amulet", "Neck", 3},
            },
        },
        {
            name = "Theka the Martyr",
            npcID = 7272,
            displayID = 6696,
            loot = {
                {274641, "Theka's Last Breath", "Trinket", 3}, -- Dungeon Journal (user 25.11.2026)
                {274639, "Sacrificial Chain Vest", "Chest, Mail", 3}, -- Dungeon Journal (user 25.11.2026)
                {274638, "Sandfury Pauldrons", "Shoulder, Mail", 3}, -- Dungeon Journal (user 25.11.2026)
            },
        },
        {
            name = "Witch Doctor Zum'rah",
            npcID = 7271,
            displayID = 6434,
            loot = {
                {18082, "Zum'rah's Vexing Cane", "Two-Hand, Staff", 3},
                {18083, "Jumanza Grips", "Hands, Cloth", 3},
                {274642, "Blood Ritual Ring", "Finger", 3},
            },
        },
        {
            name = "Nekrum Gutchewer",
            npcID = 7796,
            displayID = 6690,
            loot = {
                {274644, "Undying Headdress", "Head, Mail", 3}, -- Dungeon Journal (user 25.11.2026)
                {274645, "Desert Ziggurat Drape", "Back", 3}, -- Dungeon Journal (user 25.11.2026)
                {274643, "Gutcutter Hatchet", "Thrown", 3}, -- Dungeon Journal (user 25.11.2026)
            },
        },
        {
            -- fights with Nekrum Gutchewer; Wowhead Forever zone drops 13.11.2026
            name = "Ruuzlu",
            npcID = 7797,
            displayID = 6687, -- CMaNGOS classic-db creature_template (user 23.11.2026)
            loot = {
                {9511, "Bloodletter Scalpel", "One-Hand, Sword", 3}, -- Dungeon Journal (user 25.11.2026)
                {274654, "Sandfury Guillotine", "Two-Hand, Axe", 3},
                {274655, "Peacekeeper Wand", "Ranged, Wand", 3},
            },
        },
        {
            name = "Shadowpriest Sezz'ziz",
            npcID = 7275,
            displayID = 6441,
            loot = {
                {9470, "Bad Mojo Mask", "Head, Cloth", 3},
                {9473, "Jinxed Hoodoo Skin", "Chest, Leather", 3},
                {9474, "Jinxed Hoodoo Kilt", "Legs, Leather", 3},
                {9475, "Diabolic Skiver", "Two-Hand, Polearm", 3},
            },
        },
        {
            name = "Sergeant Bly",
            npcID = 7604,
            displayID = 6433,
            -- only fights when you talk to him after the stairs event, and he has no boss encounter the tracker could hear
            -- (6.2.17-beta14, Discord djmarscomet 25.11.: "Counts dungeon as not finished")
            optional = true,
            description = "Fights you on the temple stairs after the prisoner event.",
            loot = {
                {5616, "Gutwrencher", "One-Hand, Dagger", 3},
                {274646, "Arch of the Covenant", "Ranged, Bow", 3},
                {274647, "Farraki Kris", "Main Hand, Dagger", 3},
                {274648, "The Desert Rose", "Trinket", 3},
            },
        },
        {
            name = "Hydromancer Velratha",
            npcID = 7795,
            displayID = 6685,
            loot = {
                {274653, "Deep Ritual Girdle", "Waist, Mail", 3}, -- Dungeon Journal (user 25.11.2026)
                {274651, "Zealot Plate", "Chest, Plate", 3}, -- Dungeon Journal (user 25.11.2026)
                {274652, "Wall of Water", "Off Hand, Shield", 3}, -- Dungeon Journal (user 25.11.2026)
            },
        },
        {
            name = "Gahz'rilla",
            npcID = 7273,
            displayID = 7271,
            description = "Summoned at the pool with the Mallet of Zul'Farrak.",
            loot = {
                {9467, "Gahz'rilla Fang", "One-Hand, Dagger", 3},
                {9469, "Gahz'rilla Scale Armor", "Chest, Mail", 3},
                {274657, "Hydra Leather Legs", "Legs, Leather", 3},
            },
        },
        {
            name = "Chief Ukorz Sandscalp",
            npcID = 7267,
            displayID = 6439,
            loot = {
                {9476, "Big Bad Pauldrons", "Shoulder, Plate", 3},
                {9477, "The Chief's Enforcer", "Two-Hand, Staff", 3},
                {9478, "Ripsaw", "Main Hand, Axe", 3},
                {9479, "Embrace of the Lycan", "Head, Leather", 3},
                {11086, "Jang'thraze the Protector", "Main Hand, Sword", 3},
            },
        },
        -- Sandfury Executioner (7274) is no boss here: only an elite with the cage key (user 23.11.2026, like other journals)
        {
            name = "Zerillis",
            npcID = 10082,
            displayID = 9293,
            rare = true,
            loot = {
                {12470, "Sandstalker Ankleguards", "Feet, Leather", 3},
                {274658, "Dune Hacker", "Main Hand, Axe", 3},
            },
        },
        {
            name = "Sandarr Dunereaver",
            npcID = 10080,
            displayID = 9291,
            rare = true,
            loot = {
                {274660, "Sandarr's Shoulders", "Shoulder, Mail", 3}, -- Dungeon Journal (user 25.11.2026)
                {274659, "Bloodsand Belt", "Waist, Plate", 3}, -- Dungeon Journal (user 25.11.2026)
            },
        },
        {
            name = "Dustwraith",
            npcID = 10081,
            displayID = 9292,
            rare = true,
            loot = {
                {12471, "Desertwalker Cane", "Held In Off-Hand", 3},
                {12469, "Mutilator", "Two-Hand, Sword", 3},
            },
        },
    },
    trashLoot = {
        {9512, "Blackmetal Cape", "Back", 3},
        {9484, "Spellshock Leggings", "Legs, Cloth", 3},
        {862, "Runed Ring", "Finger", 3},
        {6440, "Brainlash", "Finger", 3},
        {9483, "Flaming Incinerator", "Ranged, Wand", 3},
        {2040, "Troll Protector", "Off Hand, Shield", 3},
        {9511, "Bloodletter Scalpel", "One-Hand, Sword", 3},
        {9481, "The Minotaur", "Two-Hand, Axe", 3},
        {9480, "Eyegouger", "Two-Hand, Polearm", 3},
        {9482, "Witch Doctor's Cane", "Two-Hand, Staff", 3},
    },
}
