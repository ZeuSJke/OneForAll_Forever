local _, FLT = ...

-- Dungeon keys: what a dungeon needs to be entered (required) or which
-- optional shortcut keys it has. Quest steps and NPC positions from QuestieDB
-- Forever; item IDs from the Forever item data. Checked October 2026.
FLT.DUNGEON_KEYS = {
  ["Scarlet Monastery: Armory"] = {
    {
      item = 7146,
      name = "The Scarlet Key",
      required = true,
      summary = "Opens the doors of the Armory and the Cathedral. Anyone in the group who has it can open them.",
      steps = {
        { name = "Clear the Library", pickup = "Scarlet Monastery: Library, Tirisfal Glades", objective = "Fight through Scarlet Monastery: Library to Arcanist Doan." },
        { name = "Open Doan's Strongbox", pickup = "Behind Arcanist Doan, inside the Library", objective = "Loot The Scarlet Key from the strongbox behind Arcanist Doan. It stays in your keyring." },
      },
    },
  },
  ["Scarlet Monastery: Cathedral"] = {
    {
      item = 7146,
      name = "The Scarlet Key",
      required = true,
      summary = "Opens the doors of the Armory and the Cathedral. Anyone in the group who has it can open them.",
      steps = {
        { name = "Clear the Library", pickup = "Scarlet Monastery: Library, Tirisfal Glades", objective = "Fight through Scarlet Monastery: Library to Arcanist Doan." },
        { name = "Open Doan's Strongbox", pickup = "Behind Arcanist Doan, inside the Library", objective = "Loot The Scarlet Key from the strongbox behind Arcanist Doan. It stays in your keyring." },
      },
    },
  },
  ["Scholomance"] = {
    {
      item = 13704,
      name = "Skeleton Key",
      required = true,
      summary = "Opens the gate of Scholomance in Caer Darrow. Made by Krinkle Goodsteel in Gadgetzan from Imbued Skeletal Fragments; the last step is a quest for your faction.",
      steps = {
        { quest = 5066, name = "A Call to Arms: The Plaguelands!", level = 50, requires = 50, faction = "Alliance", pickup = "Crier Goodman, Stormwind City (56.4, 74.1)", objective = "Seek out Commander Ashlam Valorfist. His base camp is located at Chillwind Camp, north of the Alterac Mountains.", turnin = "Commander Ashlam Valorfist, Western Plaguelands (42.7, 84.0)", map = {mapID=1453, x=56.4, y=74.1} },
        { quest = 5092, name = "Clear the Way", level = 52, requires = 50, faction = "Alliance", pickup = "Commander Ashlam Valorfist, Western Plaguelands (42.7, 84.0)", objective = "Kill 10 Skeletal Flayers and 10 Slavering Ghouls in Sorrow Hill.  Return to Commander Ashlam Valorfist at Chillwind Camp, Western Plaguelands.", turnin = "Commander Ashlam Valorfist, Western Plaguelands (42.7, 84.0)", map = {mapID=1422, x=42.7, y=84.0} },
        { quest = 5097, name = "All Along the Watchtowers", level = 56, requires = 50, faction = "Alliance", pickup = "Commander Ashlam Valorfist, Western Plaguelands (42.7, 84.0)", objective = "Using the Beacon Torch, mark each tower in Andorhal; you will need to stand in the doorway of the tower to successfully mark it.  Once all four towers are marked, return the Beacon Torch to Commander Ashlam Valorfist in Chillwind Camp, Western Plaguelands.", turnin = "Commander Ashlam Valorfist, Western Plaguelands (42.7, 84.0)", map = {mapID=1422, x=42.7, y=84.0} },
        { quest = 5533, name = "Scholomance", level = 55, requires = 55, faction = "Alliance", pickup = "Commander Ashlam Valorfist, Western Plaguelands (42.7, 84.0)", objective = "Speak with Alchemist Arbington at Chillwind Point, Western Plaguelands.", turnin = "Alchemist Arbington, Western Plaguelands (42.7, 83.8)", map = {mapID=1422, x=42.7, y=84.0} },
        { quest = 5537, name = "Skeletal Fragments", level = 57, requires = 55, faction = "Alliance", pickup = "Alchemist Arbington, Western Plaguelands (42.7, 83.8)", objective = "Bring 15 Skeletal Fragments to Alchemist Arbington at Chillwind Point, Western Plaguelands.", turnin = "Alchemist Arbington, Western Plaguelands (42.7, 83.8)", map = {mapID=1422, x=42.7, y=83.8} },
        { quest = 5538, name = "Mold Rhymes With...", level = 57, requires = 55, faction = "Alliance", pickup = "Alchemist Arbington, Western Plaguelands (42.7, 83.8)", objective = "Bring the Imbued Skeletal Fragments and 15 gold coins to Krinkle Goodsteel in Gadgetzan.", turnin = "Krinkle Goodsteel, Tanaris (51.5, 28.8)", map = {mapID=1422, x=42.7, y=83.8} },
        { quest = 5801, name = "Fire Plume Forged", level = 57, requires = 55, faction = "Alliance", pickup = "Krinkle Goodsteel, Tanaris (51.5, 28.8)", objective = "Take the Skeleton Key Mold and 2 Thorium Bars to the top of Fire Plume Ridge in Un'Goro Crater. Use the Skeleton Key Mold by the lava lake to forge the Unfinished Skeleton Key.  Bring the Unfinished Skeleton Key to Alchemist Arbington at Chillwind Point, Western Plaguelands.", turnin = "Alchemist Arbington, Western Plaguelands (42.7, 83.8)", map = {mapID=1446, x=51.5, y=28.8} },
        { quest = 5803, name = "Araj's Scarab", level = 60, requires = 55, faction = "Alliance", pickup = "Alchemist Arbington, Western Plaguelands (42.7, 83.8)", objective = "Destroy Araj the Summoner and bring Araj's Scarab to Alchemist Arbington at Chillwind Point, Western Plaguelands.", turnin = "Alchemist Arbington, Western Plaguelands (42.7, 83.8)", map = {mapID=1422, x=42.7, y=83.8} },
        { quest = 5505, name = "The Key to Scholomance", level = 60, requires = 55, faction = "Alliance", pickup = "Alchemist Arbington, Western Plaguelands (42.7, 83.8)", turnin = "Alchemist Arbington, Western Plaguelands (42.7, 83.8)", map = {mapID=1422, x=42.7, y=83.8} },
        { quest = 5093, name = "A Call to Arms: The Plaguelands!", level = 50, requires = 50, faction = "Horde", pickup = "Warcaller Gorlach, Orgrimmar (37.6, 75.4)", objective = "Seek out High Executor Derrington. His base camp is located at the Bulwark, east of Tirisfal Glade and the Undercity.", turnin = "High Executor Derrington, Tirisfal Glades (83.1, 68.9)", map = {mapID=1454, x=37.6, y=75.4} },
        { quest = 5096, name = "Scarlet Diversions", level = 53, requires = 50, faction = "Horde", pickup = "High Executor Derrington, Tirisfal Glades (83.1, 68.9)", objective = "Proceed to the Scarlet Crusade's base camp between Felstone Field and Dalson's Tears and destroy their command tent.  Place the Scourge banner at the camp, and then return to High Executor Derrington at the Bulwark, Western Plaguelands.", turnin = "High Executor Derrington, Tirisfal Glades (83.1, 68.9)", map = {mapID=1420, x=83.1, y=68.9} },
        { quest = 5098, name = "All Along the Watchtowers", level = 56, requires = 50, faction = "Horde", pickup = "High Executor Derrington, Tirisfal Glades (83.1, 68.9)", objective = "Using the Beacon Torch, mark each tower in Andorhal; you will need to stand in the doorway of the tower to successfully mark it.  Once all four towers are marked, return the Beacon Torch to High Executor Derrington at the Bulwark, Western Plaguelands.", turnin = "High Executor Derrington, Tirisfal Glades (83.1, 68.9)", map = {mapID=1420, x=83.1, y=68.9} },
        { quest = 838, name = "Scholomance", level = 55, requires = 55, faction = "Horde", pickup = "High Executor Derrington, Tirisfal Glades (83.1, 68.9)", objective = "Speak with Apothecary Dithers at the Bulwark, Western Plaguelands.", turnin = "Apothecary Dithers, Tirisfal Glades (83.3, 69.2)", map = {mapID=1420, x=83.1, y=68.9} },
        { quest = 964, name = "Skeletal Fragments", level = 57, requires = 55, faction = "Horde", pickup = "Apothecary Dithers, Tirisfal Glades (83.3, 69.2)", objective = "Bring 15 Skeletal Fragments to Apothecary Dithers at the Bulwark, Western Plaguelands.", turnin = "Apothecary Dithers, Tirisfal Glades (83.3, 69.2)", map = {mapID=1420, x=83.3, y=69.2} },
        { quest = 5514, name = "Mold Rhymes With...", level = 57, requires = 55, faction = "Horde", pickup = "Apothecary Dithers, Tirisfal Glades (83.3, 69.2)", objective = "Bring the Imbued Skeletal Fragments and 15 gold coins to Krinkle Goodsteel in Gadgetzan.", turnin = "Krinkle Goodsteel, Tanaris (51.5, 28.8)", map = {mapID=1420, x=83.3, y=69.2} },
        { quest = 5802, name = "Fire Plume Forged", level = 57, requires = 55, faction = "Horde", pickup = "Krinkle Goodsteel, Tanaris (51.5, 28.8)", objective = "Take the Skeleton Key Mold and 2 Thorium Bars to the top of Fire Plume Ridge in Un'Goro Crater. Use the Skeleton Key Mold by the lava lake to forge the Unfinished Skeleton Key.  Bring the Unfinished Skeleton Key to Apothecary Dithers at the Bulwark, Western Plaguelands.", turnin = "Apothecary Dithers, Tirisfal Glades (83.3, 69.2)", map = {mapID=1446, x=51.5, y=28.8} },
        { quest = 5804, name = "Araj's Scarab", level = 60, requires = 55, faction = "Horde", pickup = "Apothecary Dithers, Tirisfal Glades (83.3, 69.2)", objective = "Destroy Araj the Summoner and bring Araj's Scarab to Apothecary Dithers at the Bulwark, Western Plaguelands.", turnin = "Apothecary Dithers, Tirisfal Glades (83.3, 69.2)", map = {mapID=1420, x=83.3, y=69.2} },
        { quest = 5511, name = "The Key to Scholomance", level = 60, requires = 55, faction = "Horde", pickup = "High Executor Derrington, Tirisfal Glades (83.1, 68.9)", turnin = "High Executor Derrington, Tirisfal Glades (83.1, 68.9)", map = {mapID=1420, x=83.1, y=68.9} },
      },
    },
  },
  ["Upper Blackrock Spire"] = {
    {
      item = 12344,
      name = "Seal of Ascension",
      required = true,
      summary = "Opens the door to Upper Blackrock Spire. Collect the Unadorned Seal and three gemstones in Lower Blackrock Spire, then forge the seal at the dragon in Dustwallow Marsh.",
      steps = {
        { quest = 4742, name = "Seal of Ascension", level = 60, requires = 57, pickup = "Vaelan, inside Lower Blackrock Spire", objective = "Find the three gemstones of command: The Gemstone of Smolderthorn, Gemstone of Spirestone, and Gemstone of Bloodaxe. Return them, along with the Unadorned Seal of Ascension, to Vaelan.  The Generals, as told to you by Vaelan, are: War Master Voone of the Smolderthorn; Highlord Omokk of the Spirestone; and Overlord Wyrmthalak of the Bloodaxe.", turnin = "Vaelan, inside Lower Blackrock Spire" },
        { quest = 4743, name = "Seal of Ascension", level = 60, requires = 57, pickup = "Vaelan, inside Lower Blackrock Spire", objective = "Travel to the Wyrmbog in Dustwallow Marsh. Find the ancient drake, Emberstrife and beat him without mercy until his will is broken.  It is at that moment which you must place the Unforged Seal of Ascension before the great beast. You must then be quick to use the Orb of Draconic Energy on his weakened form and claim dominion over his mental faculties. Control the beast and force the Flames of the Black Dragonflight upon the Unforged Seal of Ascension!", turnin = "Vaelan, inside Lower Blackrock Spire" },
      },
    },
  },
  ["Dire Maul: West"] = {
    {
      item = 18249,
      name = "Crescent Key",
      required = true,
      summary = "Opens the doors of Dire Maul West and North (also the Gordok side door). One key holder in the group is enough.",
      steps = {
        { name = "Go to Dire Maul East", pickup = "Dire Maul, Feralas (59.2, 45.1)", objective = "Enter Dire Maul East through the Broken Commons; Pusillin waits near the entrance.", map = {mapID=1444, x=59.2, y=45.1} },
        { name = "Chase Pusillin", pickup = "Inside Dire Maul East", objective = "Talk to Pusillin and chase the imp through Warpwood Quarter until he fights; he drops the Crescent Key." },
      },
    },
  },
  ["Dire Maul: North"] = {
    {
      item = 18249,
      name = "Crescent Key",
      required = true,
      summary = "Opens the doors of Dire Maul West and North (also the Gordok side door). One key holder in the group is enough.",
      steps = {
        { name = "Go to Dire Maul East", pickup = "Dire Maul, Feralas (59.2, 45.1)", objective = "Enter Dire Maul East through the Broken Commons; Pusillin waits near the entrance.", map = {mapID=1444, x=59.2, y=45.1} },
        { name = "Chase Pusillin", pickup = "Inside Dire Maul East", objective = "Talk to Pusillin and chase the imp through Warpwood Quarter until he fights; he drops the Crescent Key." },
      },
    },
  },
  ["Blackrock Depths"] = {
    {
      item = 11000,
      name = "Shadowforge Key",
      required = false,
      summary = "Opens the Shadowforge gates in Blackrock Depths (a shortcut; without it the doors need a rogue or Seeping Flames).",
      steps = {
        { quest = 3801, name = "Dark Iron Legacy", level = 52, requires = 48, pickup = "Franclorn Forgewright, Blackrock Mountain (his ghost is only visible while you are dead)", objective = "Speak with Franclorn Forgewright if you are interested in obtaining a key to the city major.", turnin = "Franclorn Forgewright, inside Blackrock Depths" },
        { quest = 3802, name = "Dark Iron Legacy", level = 52, requires = 48, pickup = "Franclorn Forgewright, Blackrock Mountain (as a ghost)", objective = "Slay Fineous Darkvire and recover the great hammer, Ironfel. Take Ironfel to the Shrine of Thaurissan and place it on the statue of Franclorn Forgewright.", turnin = "Monument of Franclorn Forgewright, inside Blackrock Depths" },
      },
    },
    {
      item = 11140,
      name = "Prison Cell Key",
      required = false,
      summary = "Opens the prison cells in the Detention Block (Jail Break!).",
      steps = {
        { name = "High Interrogator Gerstahn", pickup = "Inside Blackrock Depths", objective = "Drops from High Interrogator Gerstahn in the Detention Block." },
      },
    },
  },
  ["Stratholme"] = {
    {
      item = 12382,
      name = "Key to the City",
      required = false,
      summary = "Opens the gates between the two halves of Stratholme. Both gates can be entered without it.",
      steps = {
        { name = "Magistrate Barthilas", pickup = "Inside Stratholme", objective = "Drops from Magistrate Barthilas behind the service gate." },
      },
    },
  },
  ["Gnomeregan"] = {
    {
      item = 6893,
      name = "Workshop Key",
      required = false,
      summary = "Opens the Workshop side entrance and doors inside Gnomeregan.",
      steps = {
        { name = "Electrocutioner 6000", pickup = "Inside Gnomeregan", objective = "Drops from Electrocutioner 6000." },
      },
    },
  },
  ["Maraudon"] = {
    {
      item = 17191,
      name = "Scepter of Celebras",
      required = false,
      summary = "Opens the portal from the Maraudon entrance straight to Princess Theradras' falls.",
      steps = {
        { quest = 7044, name = "Legends of Maraudon", level = 49, requires = 41, pickup = "Cavindra, Desolace (32.1, 64.0)", objective = "Recover the two parts of the Scepter of Celebras: the Celebrian Rod and the Celebrian Diamond.  Find a way to speak with Celebras.", turnin = "Celebras the Redeemed, inside Maraudon", map = {mapID=1443, x=32.1, y=64.0} },
        { quest = 7046, name = "The Scepter of Celebras", level = 49, requires = 41, pickup = "Celebras the Redeemed, inside Maraudon", objective = "Assist Celebras the Redeemed while he creates the Scepter of Celebras.  Speak with him when the ritual is complete.", turnin = "Celebras the Redeemed, inside Maraudon" },
      },
    },
  },
  -- Krol'dok Stronghold (6.2.12-beta25, tester Deaders 19.11.: "City of Dalaran has a separate button next to quests for the key.
  -- Krol'dok does not, it's listed as a regular quest"): the Krol'dok Compound Key from Key Ingredients - optional (the entrance
  -- is a cave west of the fortress gates, no key needed; warcrafttavern.com / magicgameworld.com). Quests, givers and positions
  -- from QuestieDB Forever (94973 / 94974 Horde, 94980 / 94981 Alliance); the Krol'dok Mould drops from Tunk inside.
  ["Krol'dok Stronghold"] = {
    {
      item = 267089,
      name = "Krol'dok Compound Key",
      summary = "Not needed to enter. Tunk drops the Krol'dok Mould inside the dungeon; a smith in Farholde Keep (Alliance) or Rog'mar (Horde) turns it into the key for 4 Thick Leather and 12 Iron Bars.",
      steps = {
        { quest = 94980, name = "Krol'dok Moulding", level = 41, requires = 38, faction = "Alliance", pickup = "Krol'dok Mould, dropped by Tunk inside Krol'dok Stronghold", objective = "Find someone in Farholde Keep who may know about the mould.", turnin = "Alphonse Dumas, Riverglades (64.4, 82.0)", map = {mapID=2548, x=64.4, y=82.0} },
        { quest = 94981, name = "Key Ingredients", level = 41, requires = 38, faction = "Alliance", pickup = "Alphonse Dumas, Riverglades (64.4, 82.0)", objective = "Bring 4 Thick Leather and 12 Iron Bars to Alphonse Dumas.", turnin = "Alphonse Dumas, Riverglades", map = {mapID=2548, x=64.4, y=82.0} },
        { quest = 94973, name = "Krol'dok Moulding", level = 41, requires = 38, faction = "Horde", pickup = "Krol'dok Mould, dropped by Tunk inside Krol'dok Stronghold", objective = "Find someone in Rog'mar who may know about the mould.", turnin = "Kreza Darkthorn, Riverglades (59.9, 46.0)", map = {mapID=2548, x=59.9, y=46.0} },
        { quest = 94974, name = "Key Ingredients", level = 41, requires = 38, faction = "Horde", pickup = "Kreza Darkthorn, Riverglades (59.9, 46.0)", objective = "Bring 4 Thick Leather and 12 Iron Bar to Kreza Darkthorn.", turnin = "Kreza Darkthorn, Riverglades", map = {mapID=2548, x=59.9, y=46.0} },
      },
    },
  },
  -- City of Dalaran (6.2.4, user 10.11.): quests, givers, items and spawns from QuestieDB Forever (Heart of Disruption
  -- gives item 277507 Dalaran Sewer Key on accepting, Key to the City needs item 279469 Grimy Key); names of the items
  -- from the Wowhead tooltip API; the footlocker at the Lordamere Internment Camp: 16.3, 89.3 (the user in the game, 10.11.).
  ["City of Dalaran"] = {
    {
      item = 277507,
      name = "Dalaran Sewer Key",
      required = true,
      summary = "Opens the sewer entrance into Dalaran by the Lordamere Lake. It comes with the quest Heart of Disruption from the Image of Archmage Modera; the Alliance gets there with one lead-in quest, the Horde with Magus Wordeen Voidglare's quests in Tarren Mill.",
      steps = {
        { quest = 92432, name = "An Alarming Request", level = 33, requires = 30, faction = "Alliance", pickup = "Emissary Jacques, Hillsbrad Foothills (48.3, 60.0)", objective = "Report to the Image of Archmage Modera near the City of Dalaran.", turnin = "Image of Archmage Modera, Alterac Mountains (14.3, 59.6)", map = {mapID=1424, x=48.3, y=60.0} },
        { quest = 92458, name = "Heart of Disruption", level = 33, requires = 24, faction = "Alliance", pickup = "Image of Archmage Modera, Alterac Mountains (14.3, 59.6)", objective = "Accept this quest: the Dalaran Sewer Key comes with it.", turnin = "Image of Archmage Modera, Alterac Mountains", map = {mapID=1416, x=14.3, y=59.6} },
        { quest = 544, name = "Prison Break In", level = 33, requires = 30, faction = "Horde", pickup = "Magus Wordeen Voidglare, Hillsbrad Foothills (61.6, 20.9)", objective = "Find the traitors and recover their artifacts, then return to Magus Voidglare in Tarren Mill.", turnin = "Magus Wordeen Voidglare, Hillsbrad Foothills (61.6, 20.9)", map = {mapID=1424, x=61.6, y=20.9} },
        { quest = 93680, name = "Key to the City", level = 33, requires = 30, faction = "Horde", pickup = "Magus Wordeen Voidglare, Hillsbrad Foothills (61.6, 20.9)", objective = "Loot the Grimy Key from a Warden's Footlocker upstairs in a house of the Lordamere Internment Camp (guarded by Warden Belamoore) and bring it to Magus Wordeen Voidglare in Tarren Mill.", turnin = "Magus Wordeen Voidglare, Hillsbrad Foothills (61.6, 20.9)", map = {mapID=1424, x=61.6, y=20.9},
          -- where the Grimy Key lies: the user stood on the footlocker (10.11.: 16.3, 89.3)
          loot = { name = "Grimy Key", item = 279469, place = "Warden's Footlocker, Alterac Mountains (16.3, 89.3)", map = {mapID=1416, x=16.3, y=89.3} } },
        { quest = 545, name = "Dalaran Patrols", level = 35, requires = 30, faction = "Horde", pickup = "Magus Wordeen Voidglare, Hillsbrad Foothills (61.6, 20.9)", objective = "Kill 6 Dalaran Summoners and 12 Elemental Slaves, then return to Magus Voidglare in Tarren Mill.", turnin = "Magus Wordeen Voidglare, Hillsbrad Foothills (61.6, 20.9)", map = {mapID=1424, x=61.6, y=20.9} },
        { quest = 92434, name = "Blood in the Streets", level = 34, requires = 30, faction = "Horde", pickup = "Magus Wordeen Voidglare, Hillsbrad Foothills (61.6, 20.9)", objective = "Find a way into Dalaran along the Lordamere Lake.", turnin = "Image of Archmage Modera, Alterac Mountains (14.3, 59.6)", map = {mapID=1424, x=61.6, y=20.9} },
        { quest = 96984, name = "Heart of Disruption", level = 33, requires = 24, faction = "Horde", pickup = "Image of Archmage Modera, Alterac Mountains (14.3, 59.6)", objective = "Accept this quest: the Dalaran Sewer Key comes with it.", turnin = "Magus Wordeen Voidglare, Hillsbrad Foothills", map = {mapID=1416, x=14.3, y=59.6} },
      },
    },
  },
}
