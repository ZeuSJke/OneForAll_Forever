OneForAll
=========

Standalone WoW Forever companion addon: dungeons (bosses, loot, quests),
armory (item sets, reputation rewards), Library Books tracker, Merchant's Favor recipes, camping buffs, hunter pets
and an in-addon talent planner. No other addons are required.

Commands
--------
/oneforall or /ofa       Open/close the addon
/oneforall debug         Show unverified Library Book quest flags
/oneforall bank          Explain bank scanning
/oneforall profdata      Show embedded profession-data status
/oneforall portraits     Show which source each boss portrait came from
/oneforall craft         Open/close the Crafting List
/oneforall setup         Open the welcome setup again
/oneforall dmap         Open the dungeon map like M does in a dungeon (for testing)
/oneforall where         Print the current map and coordinates (to report wrong map pins)
/oneforall reset         Reset manual Library Book marks
/oneforall tabs reset    Show the default tabs again for this character
/oneforall share test    Preview the quest share popup without a group
/oneforall share         Open the quest share popup (inside a dungeon, in a group)
/oneforall channel      State of the recipe channel with other OneForAll users
/oneforall bug          Show the link for bug reports and ideas
/oneforall rolltest     Show the loot roll window with an example item
/oneforall questtest    Open the quest log at a quest with a gear reward
/oneforall cheapest     Show the cheapest item in your bags
/oneforall buttons      List the minimap buttons the button collector holds
/oneforall trainer      Show what the last class trainer visit read
/oneforall gv           How the Gear Value of the item under the mouse comes about (or /ofa gv [item link])
/oneforall errors       Show errors OneForAll caught (for bug reports); "errors clear" empties the list
/oneforall mem          Show how much memory OneForAll uses right now
/oneforall thanks       Show the last buffs seen by "Thanks for buffs"
/oneforall talentdump    Save all talent IDs to the SavedVariables (for the addon author)
/oneforall scale [n]     Set the window size (60-140 or 0.6-1.4); without a value: reset to 100 %

License
-------
Copyright (C) 2026 Smoergi

This program is free software: you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or (at your option) any later
version. It is distributed WITHOUT ANY WARRANTY; see LICENSE.txt for details.

Third-party data attribution is in THIRD_PARTY_LICENSES.txt.
Dungeon data sources are listed in DUNGEON_DATA_SOURCES.txt.


Code layout
-----------
Data files       Data.lua, ExtraData.lua, ProfessionData.lua, DungeonData.lua
Dungeons         Data/Dungeons/<Name>.lua - one file per dungeon (quests, bosses, loot);
                 Data/DungeonQuestChains.lua - prerequisite chains (optional = true marks
                 lead-ins that do not block); DungeonData.lua - entrance, territory,
                 level sorting. New dungeon: add a file, list it in OneForAll.toc,
                 add its META entry in DungeonData.lua and its art in UI/Dungeons.lua.
Logic            Core.lua (events, bags/bank, slash commands), ProfessionRuntime.lua,
                 Map.lua (world-map pin), Proximity.lua (nearby book alerts), Minimap.lua
UI/Widgets.lua   Shared buttons/textures/banners + panel registry
UI/MainFrame.lua Main window and tab bar
UI/<Tab>.lua     One file per tab: General, Dungeons (+ DungeonHelpers, DungeonPortraits),
                 Books, Professions
Talents          TalentData.lua (layouts of all 9 classes), TalentSpellIDs.lua (spell ID ->
                 talent name; regenerate from /ofa talentdump after a talent patch), TalentPlanner.lua (the tab), TalentLayoutFallback.lua
                 (only used if the client talents cannot be matched to TalentData.lua)
New tab: create a file, call FLT.UI.RegisterPanel{key=, label=, order=, tabWidth=, create=}
and add the file to OneForAll.toc before UI\MainFrame.lua.


Changelog (newest first)
========================

6.2.13 - BiS List, Cheap Upgrades, new stat weights and many fixes
==================================================================
Armory
- New tab "BiS List" in the Gear Planner: the WoW Forever "Pre Raid" BiS lists of wowtbc.gg for every class and spec - pick a
  class and a spec (yours at first), the items per slot with their sources, the BiS pick marked. More lists will follow.
- New tab "Cheap Upgrades": Bind on Equip gear from the auction house that improves your gear, up to a highest price you set
  (silver or gold), best gain first; per slot or "All slots", with the level, armor and weapon filters. Gear that needs a
  profession skill only shows when you have it. The search box moved one row down; the warning sign next to the tabs is gone.
- New button "Cheap Upgrade Scan" on the Buy page of the auction house: scans the whole auction house (once every 15 minutes)
  and keeps the cheapest price of every Bind on Equip piece of gear - items with a random bonus ("of the Eagle") each with
  their own price and stats. A chat line when it is done; Cheap Upgrades show how old the last scan is. Without a scan the
  prices come from Auctionator. Switch: Quality of Life > Loot & Vendors.
- Gear Value: new stat weights from Geared Forever by fistedwaffles05 (built for WoW Forever, GPL-3) for every class, spec and
  level; Haste, Expertise and Spell Penetration count now (also in the own weights editor). A worn item without value is no
  longer "slot empty".
- Quality of Life: "Gear Value shows" - Whole gear (as before), Item against item, or Both ("65% (overall 6%)").

Quality of Life
- New entry "Miscellaneous" with "Skip the talk at service NPCs" (vendor, bank, trainer, flight master, auctioneer, stable
  master, guild bank, tabard vendor, battlemaster - "All" at the top; all off at first; also found by searching "gossip"),
  flight times, camera zoom, hiding error messages, thanking for buffs and all chat options (the "Chat" entry is gone).
- Move Blizzard windows: a window whose saved place is off the screen is put back onto it; the full screen world map stays in
  the middle.
- Quicker loot: no longer loops with full bags (the game froze or disconnected while the loot window stayed open), and works
  with the auto loot key set to "None". The Bags full helper no longer moves on every check, and loot worth exactly as much
  as the cheapest item in your bags is no longer offered for a swap (thanks to emzime for finding the loop).
- Buff reminder: the buff list is per character now. Sell junk also sells from the reagent bag.
- With Leatrix Plus the OneForAll button follows the logo color. Only this version's new options keep a yellow "!".

Dungeons & quests
- Dungeon maps for The Drowned City, Blackmaw Hold, Alcaz Prison, Shaper's Terrace and Krol'dok Stronghold (from Forever
  Simple World Map by Tarolg, with his agreement), the entrances of Alcaz Prison, The Drowned City and Krol'dok Stronghold,
  and the Sunken Temple statues numbered 1-6 in the order they must be used. Krol'dok Stronghold's entrance moved to the
  real spot (Riverglades 37.5, 39.0).
- Quest data from the newest QuestieDB: about 130 new quests on the world map, corrected quest givers and quest item drops;
  quests the game no longer offers are left out; Image of Archmage Modera for both factions.
- Sunken Temple: the Alliance quest chain for Alliance characters; Scarlet Monastery Library: "In the Name of the Light";
  Friend of the Library shows the giver of your faction. "Share all Quests" shares one quest per click.
- Map Landmarks: 7 more ley lines from players' reports.

Professions & books
- Skill-Up Helper / Profit: no reagents from vendors with a limited stock (WoW Forever's vendor data), a vendor only when it
  is not dearer than the auction house, the 1 hour transmutes count as cooldowns; the price note no longer lies under the
  column heads.
- A profession you dropped or changed is forgotten again.
- Library Books: books marked by hand count in the set totals; two Eastern Plaguelands locations corrected.

6.2.12 - Guild Games, Skill-Up buy or craft, hunter pet ranks from the game and many fixes
==========================================================================================
Special thanks to Deaders for testing this version, and to Gälda, Ritter Roulade and Deaders for testing the Guild Games.
- New: Guild Games - Death Roll, High / Low and Tic Tac Toe with your guild members in their own window, open tables to join,
  optional gold stakes (only written down - you trade the gold yourselves) and your own history. Switch it on in Quality of
  Life > Guild > "Play with Guildies" (off by default); the "Start" button below it, the info bar element "Guild Games",
  /ofa play or a key binding open the window. Players who go offline leave the table; a new dealer takes over.
- Skill-Up guide: new section "Buy ready-made or craft" - bolts, leather, bars and other intermediates bought finished
  instead of crafted, with the cost difference; a click switches. "Send to Auctionator" also takes the materials under
  "Farm or find". The "Open guide" button is green.
- Skill-Up Helper and Profit: new switch "Don't use own materials" (off by default) - nothing from your bags, bank or other
  characters is used, every material is bought or farmed. Profit says why when nothing is found.
- Hunter Pets: every rank is read straight from the game (also at login) and recognised from the "You have learned"
  message, without the Beast Training window; ranks are no longer lost when Beast Training is opened with another pet;
  right-click a rank to mark it yourself.
- Quality of Life > World Map: "Low level quests (grey)" (off by default) and "Hide walking routes" of quest givers.
- Quality of Life > Loot & Vendors: choose the "Junk list key" (Alt + right-click stays the default).
- Resize Blizzard windows: hold Ctrl and the right mouse button (a plain right-click no longer starts resizing).
- Info bar: "Remove a character from the gold list" for deleted characters; the gold of your characters is saved as soon
  as it changes.
- Gear Planner: no suggestions from raids that are not open in WoW Forever (Ahn'Qiraj, Naxxramas, Blackwing Lair, Molten
  Core, Zul'Gurub) or crafts that need them; Onyxia's Lair, Hyjal Summit and Barrow Deeps from 9 December 2026. Quest chains
  (e.g. the Heroism set) only show the steps of your faction and class.
- Dungeons: every dungeon quest checked against the quest database (quests that do not belong removed, names and levels
  corrected); Dalaran's open-city quests removed; Stratholme's Dead Man's Plea chain fits your faction and class;
  Krol'dok Stronghold: Eye of Mugg chain, quest givers, notes and a Key page for the Krol'dok Compound Key.
- Drop chances: about 250 more, measured in WoW Forever; 77 wrong boss loot entries removed.
- Map Landmarks: ley lines / Elemental Convergences only at confirmed spots again (far fewer pins).
- Map: zone transition signs can be clicked again with the mouse while a controller is plugged in.
- Disenchant value: right under Auctionator's Auction line without moving other tooltip lines (ItemTree), and shown on
  every item tooltip again.
- Fixes: the first open of the window and M in a dungeon no longer stop half way in combat; unlearned professions no longer
  stay learned and the professions overview updates right away; quest marks no longer error with BlizzThreatPlates;
  the Guild Games "Start" button is greyed out while switched off; quest data updated.

6.2.11 - Quest mark position by dragging, black logo, more Forever quest data and many fixes
============================================================================================
- Quest marks on nameplates: the position drop-down is replaced by a sample nameplate in Quality of Life > Quests -
  drag the sword / bag anywhere around it, also below the plate; "Reset" puts it back. The progress text sits on the
  outer side. Works with the game's nameplates and with nameplate addons like Platynator and Plater (the mark sits at
  their health bar, at a normal size). No more "Can't measure restricted regions" errors.
- Quest marks on nameplates: also on the mobs of the new WoW Forever quests (about 770 more mobs).
- Quality of Life > Interface > Minimap: new logo color "Black" and a "Logo size" slider (60 - 150 %) for the OneForAll
  minimap button and the collector button.
- Gear Planner: about 330 more quest rewards of the new WoW Forever quests. Two different quests with the same name show
  their quest giver, e.g. "Khan Jehn (Orgrul)" and "Khan Jehn (Nerlokh)" (Discord).
- Gear Planner: suggestions no longer go missing after a /reload or while your worn gear is still loading - before, items
  the game had not loaded yet were judged "no upgrade" until gear or spec changed (dungeon items gone) (Discord).
- Hunter pets: every ability rank counts on its own - knowing Claw 4 no longer marks Claw 1-3 as learned, and an ability
  counts only once Beast Training lists it, not when you tame the beast. The Pet Trainer list shows a missing lower rank.
  New option "Also lower ranks" in Popups & Alerts: the pet ability alert also for a lower rank (off by default) (Discord).
- Hunter pets: the "pet ability nearby" alert can be closed in combat again and no longer covers group invites (Discord).
- Check low spell ranks: also spells bound in the game's Click Casting, shown with "(Click Casting)" (Discord).
- Quest XP on the experience bar: works with Bartender4 and uses the bar that is shown (Discord).
- Minimap button collector: buttons like WIM's that put themselves back on the minimap stay in the bar (Discord).
- Scarlet Monastery: reopening the window inside a wing keeps the wing you looked at (Discord).
- Dungeons & Raids: German, French, Spanish and Portuguese clients show the wing again (Scarlet Monastery, Dire Maul,
  Blackrock Spire); a boss's note line sits right of the portrait (Discord).
- Removed what is not in WoW Forever: The Heart of the Void, Goblin Lockpicks, Alonso's Dragonslayer quests, Hammer of
  the Righteous at the class trainer (Discord).
- Hide error messages stays on even when the game or another addon turns the messages back on (Discord).
- Quest sharing: no blocked action in combat (Discord).
- Map Landmarks: Skyborne Ley Lines and Elemental Convergences from SLLCM 1.3.0 plus players' reports.
- Quest data from the newest QuestieDB.

6.2.10 - New dungeon pictures, armor / weapon type filter, Armory performance and many fixes
===========================================================================================
- Turn in quests automatically: safer with reward choices - it waits a moment, checks the number of choices again and
  in the quest log, and leaves the quest to you on any doubt (Discord).
- Dungeons & Raids: new dungeon pictures from the game's own loading screens - in the list (full row height, soft edges),
  in the header and as the colour of the detail background. Scarlet Monastery wings, Upper Blackrock Spire and Dire Maul
  East / North have their own pictures; the raids too (Barrow Deeps with a new picture, Hyjal Summit with the game's
  loading screen). The addon got about 20 MB smaller (the old pictures are gone).
- Dungeons & Raids: boss loot and quest rewards show the green arrow on items that are an upgrade for you (like the
  bags and the quest window).
- Gear Planner filter menu: "Armor type" and "Weapon type" are always there and open their own list to the right.
  Weapon type has One-Hand, Two-Hand and Ranged (a click switches all of them, the mouse on them shows each type) and
  Shields (Discord).
- Info bar: the clock shows 12 or 24 hours like the game's clock ("24-hour mode" at the minimap clock).
- Map Landmarks: the flight masters of the Riverglades are on the map (Discord).
- Dungeons & Raids: Blackfathom Deeps lists the warlock quest "The Orb of Soran'ruk" too; "A Dynamite Plan" asks for
  Rough Dynamite, not Coarse Dynamite (Discord).
- Skill-Up Helper (Alchemy): the Discolored Healing Potions - Lesser at 85, Major at 270; the Minor and Major ones are
  taught by the Odd Child / Apothecary Renferrel too (Discord).
- Quest loot sparkles: switching it off sets the game's loot glow back to off, so quest givers stop glowing (after a
  restart); the option tells that NPCs glow too while it is on (Discord).
- Move Blizzard windows: the Cooldown Settings window can be moved (Discord).
- With a controller connected: clicking a zone transition sign on the world map no longer switches the map, and "Open in
  quest log" only selects the quest (you open the log yourself) - both broke the pad controls until /reload (Discord).
- Class trainer window (druid): the Bear Form quest is no longer listed again once Dire Bear Form is learned (Discord).
- Dungeons & Raids: inside Scarlet Monastery the tab opens the wing you are in, not always the Graveyard (English
  clients; the wing is told by the place name on the minimap; Discord).
- Tooltips of players, enemies and NPCs in the world fade out at once again when the mouse leaves them - our extra
  lines (target, NPC quests) kept them up for 2 seconds and more (Discord).
- Bags full helper: drag it anywhere (the place is kept), Esc closes it, and a Soul Shard from Drain Soul no longer
  opens it (Discord).
- Info bar: with the combined bag, Gold and Free bag slots open the bags through the game's backpack button - with a
  controller the pad controls no longer break until /reload (Discord).
- Dungeon quests: "Rumi of Gnomeregan: The Collected Works" (a Library Book) is no longer listed under Gnomeregan (Discord).
- Dungeon quests: Razorfen Downs lists "An Unholy Alliance" once (the Small Scroll step belongs to Razorfen Kraul and is
  shown in the quest chain).
- Move Blizzard windows: inspecting a player from the right-click menu no longer breaks right-clicking names and chat
  links until /reload (since 6.2.9; Discord). Windows that load later are set up a moment after loading, and only the
  world map passes the mouse hover on to other addons' text under its title bar.
- Crafting List: adding recipes while the list already has some asks whether to clear it first ("Clear list" / "Keep
  and add" / Cancel). Profit asks every time; the "+ List" button of a recipe asks once until the list is empty again.
- Crafting List: materials a vendor sells have a map button to the nearest vendor of your faction who sells them, and a
  "Send to Auctionator" button puts the missing materials into Auctionator as a shopping list (vendor items left out).
- Guild members on the world map: dots on top of each other share one tooltip with every name, level and class.
- Gear Planner: an item's upgrade judgement is kept until your gear, talents or level change, and items the server never
  answers stop being asked for - fewer spikes with many armor types and "All slots" (Discord).
- Gear Planner: "All slots" with a wide level range (or "All") no longer lags without end. Items the game does not have
  yet are loaded in small batches, items the server does not know are left out, and the Armory redraws less often while
  items arrive (Discord).

6.2.9 - Trainer window, map and Skill-Up fixes
==============================================
- Class trainer window: rank 1 of many spells (Swipe, Faerie Fire, Rake, Shred, Thorns ...) was listed at the level and
  with the fee of the highest rank, and lower ranks seemed to be missing (since 6.2.8; Discord). Every rank keeps its own
  level and fee again; the fees saved by 6.2.8 are dropped once and read again at the next trainer visit.
- Move Blizzard windows: other addons' text at the top of the map (Leatrix Plus' Wowhead link) can be hovered and copied
  again; dragging the map by its title bar still works (Discord).
- Skill-Up guide: Forever's own recipes are only planned when it is known who teaches them, or a trainer offered them
  to you. The Discolored Healing Potions point to the Odd Child (Westfall) / Apothecary Renferrel (Silverpine Forest)
  instead of your alchemy trainer, who does not teach them (Discord).

6.2.8 - Dungeon quest chains and rewards, Brazilian Portuguese
==============================================================
- Dungeon quests: every dungeon quest checked against QuestieDB and Wowhead Forever. 48 missing quest chains and
  pre-quests (The Drowned City, Alcaz Prison, Krol'dok Stronghold, Blackmaw Hold, Ruins of Lordaeron ...), 33 missing
  quests (among them all new WoW Forever ones of the old dungeons) and the rewards of all dungeon quests (about 80 quests
  corrected: rewards of another quest, new Forever choices, missing rewards). Items given on top of the chosen reward
  show under "You will also receive:". The chain steps show quest giver, turn-in (with map buttons), level and objective.
- Dungeon quests: "Unavailable" only when you cannot take a quest (level, faction, race, class); a chain not started yet
  shows "Available | Chain", a started one "Chain started" and the step you are at. The Drowned City lists its quests like
  in the game (pre-quests only as chain steps).
- Boss loot: the new WoW Forever drops of all dungeons (53 items, e.g. Herod's Band of Crimson Light), new bosses Ruuzlu
  (Zul'Farrak), Malor the Zealous, Crimson Hammersmith, Black Guard Swordsmith and Ezra Grimm (Stratholme), trash drops of
  Ruins of Lordaeron.
- Armory > Quests (Cozy Sleeping Bag and the other chains): steps show Done / In log / Ready to turn in like the dungeon
  quests; click a step for its start, turn-in (map buttons), level and objective; the map button points to the turn-in
  once the quest is in your log.
- Shaman class quests: the Air Totem row has the whole Call of Air chain with the "Chain" button.
- Gear Planner: dungeon quest rewards count from the level you can take the quest at (Wingblade was missing from 1 - 20);
  Greatstaff of the Necrokhans, the City of Dalaran and Library Books rewards are in it.
- Skill-Up guide: "Buy" in the vendor section while a merchant who sells it is open.
- Profit: Reset button; Frilled Lichen, Pristine Leather and Torbernite no longer count as vendor items (only a black
  market NPC lists them), so Cerulean Dye no longer shows a huge profit.
- Trainers: no more freeze when buying at a trainer; the trainer is read once per visit.
- Nameplate quest marks: on plates with the level above the bar the mark sits right of the bar.
- New language: Brazilian Portuguese (translation by ValadaresX), with quest and NPC names in a Brazilian client.

6.2.7 - New Forever dungeons filled in, Buy at the merchant, Tooltip at the mouse
==================================================================================
- New Forever dungeons: boss loot for Blackmaw Hold, Shaper's Terrace, Krol'dok Stronghold and Alcaz Prison (about 70 items
  with the boss that drops them), boss names as in the game, boss levels, portraits (an icon where the game cannot draw the
  model) and creature types, drop chances for Krol'dok Stronghold and Alcaz Prison, new bosses and rares (Zarla Ober, Umbra,
  "Pyromancer" Braxton, Kroog, Gortek the Apprentice, Tunnelweb Matriarch, Ravasaur Hunters), their trash drops (56 blue
  items), 17 more dungeon quests and map buttons for all their entrances. No more "Partial data" warning on them.
- Dungeons: a boss level and type learned by targeting the boss show at once and win over the stored ones; arrow buttons
  next to "Dungeons" switch to the previous / next dungeon of the list.
- Dungeon quests: "Starts at" and "Turn in" have a Map button wherever the place is known; an NPC or a drop inside the
  dungeon points to its entrance. Also for the key / attunement steps.
- Crafting List: with a merchant open who sells a missing material, a "Buy" button buys exactly what is missing. Next to a
  material not (all) in your bags it says where it is - "(12 in bank)", "(5 on <character>)".
- Skill-Up Helper and Profit: the bank and your other characters count; new switch "Without other characters' materials"
  (off by default). Skill-Up Helper: tidier header, item names that were not loaded yet are filled in, the "Materials"
  rows sit at the left edge. "Send to Auctionator" waits for item names instead of dropping them.
- Bank: read on every change while it is open and once more when you close it.
- Tailoring: the coloured bags need one bolt more in WoW Forever (Green Silk Pack 5 Bolts of Silk Cloth ...); when the
  profession window shows other materials than OneForAll's data, the window's amounts are used everywhere.
- New Quality of Life option "Tooltip at the mouse" (off by default): six positions around the mouse, separate switches to
  keep the usual place in dungeons and raids and on battlegrounds.
- Nearby Library Book alerts: new switch "Not while flying" (off by default). Library Books info window: the librarians on
  their own rows with crest, place and a Map button.
- Quests on NPCs (tooltip): dungeon and raid quests show "D" / "R" and the dungeon's name.
- Talent planner: ranks come from the talent data, not from the client (Marksmanship "Improved Stings" has 3 ranks).

6.2.6 - Skill-Up Helper, Profit, new stat weights
=================================================
- New: Skill-Up Helper (Professions > every crafting profession, also Cooking and First Aid): the cheapest way from your
  skill to a target - auction house prices from Auctionator (if installed), vendor prices and trainer fees; materials you
  have (bags, bank, other characters) count as free. A big progress bar, the costs as tiles, when Auctionator last scanned,
  the steps with ranks to train, tools (runed rods, Blacksmith Hammer, Arclight Spanner ...) and intermediates to make
  first; patterns from vendors and the auction house are planned by default. The plan keeps its recipes after buying,
  relogging or a reload; "Recalculate" works it out again.
- Skill-Up guide window: walks you through it step by step (auction house, vendors, trainer, materials, crafts) and sends
  the shopping list to Auctionator. "Craft" / "Craft all" in the current step, a small progress bar and your chance of a
  skill point per craft, right-click marks a step done, finished shopping sections get a green check, materials say where
  they are when not in your bags and shrink while you craft, "Learn at the trainer" names the recipe and the nearest
  trainer who really teaches it, pattern steps name the pattern. Alt-right-click on the minimap button opens the last guide.
- New: Profit (Professions > a profession > "Profit"): recipes that sell for more than their materials cost (Auctionator
  prices, after the 5% cut), only known recipes by default; filters for learn level and least profit; select recipes with
  a craft count and see the gold to invest and the profit; send the materials to Auctionator (what is in your bags is left
  out, cheaper raw materials when making a material yourself costs less) or put them on the Crafting List; right-click
  opens the recipe.
- Gear Planner / item Value: new stat weights based on SimGear Forever by Frostmil (simulated per spec and level), with
  OneForAll's own changes for leveling: Intellect and Spirit for casters and healers, Stamina, mana and health per 5 sec.,
  healers' crit, Protection Paladin block value, Bear Stamina, smooth values from 50 to 60, no wand DPS for classes without
  one. Weapon speed counts per spec (Cat and Bear: weapon DPS only, their speed is fixed by the form). Your own custom
  weights stay as they are.
- New Quality of Life option "Disenchant value" (Tooltips, off by default): what green, blue and purple weapons and armor
  are worth disenchanted, at Auctionator prices (only with Auctionator).
- Key bindings in their own "OneForAll" section (Options > Keybindings): the window, each main tab, the Skill-Up Helper,
  the last Skill-Up guide, Profit and the Crafting List; pressing the key again closes the window.
- Hide chat also hides the "Social" friends button next to the chat.
- Professions: the Crafting List button moved into All recipes / Favorites; trainer fees are read and remembered; recipe
  vendors and mobs have their map button again (many had no position); clicking a crafted item in the Gear Planner or the
  dungeon loot opens its recipe even with a recipe filter set.
- Crafting List / Skill-Up Helper: the reagent bag counts as bags (it was read as bank and counted twice), the bank is no
  longer counted twice, characters with the same first name no longer take over each other's bank; Darkmoon Faire items
  no longer count as vendor materials.
- Dungeons: quests only some races can take show as unavailable for the others (Compendium of the Fallen); The Eye of
  Bhossca and The Horn of Xelthos track the right quest step; an unavailable quest says why (faction, class, level or which
  chain step comes first); coordinates only next to a Map button; Gnomeregan teleporter note fixed.
- Library Books: the third reward tier is at 25 books (level 35); a book marked by hand counts as turned in.
- Move Blizzard windows: the loot window stays at the mouse with "Open loot window at mouse".
- Square minimap: the round ring no longer comes back (thanks to ProEvilz).
- Loot feed: money lines without the coin icon in front.
- Quest XP on the experience bar: the mark stays inside the bar and has the fill's height and pointed end.
- Noteworthy changes for 6.2.6 (shown once, bigger window): Skill-Up Helper, Profit, new stat weights.
- Data update: QuestieDB (Forever NPC / quest fixes, quest icons, reagent sources, hunter pet spawns, names).

6.2.5 - Special Quests, movable info bar, Gear Planner values
=============================================================
- Armory: new list "Special Quests" - quest chains with an unusual reward, for now the Cozy Sleeping Bag (both
  factions, the first steps on your faction's side of the map) and Wolfsbane for Horde paladins: rewards, every step
  with its quest giver and a map button, and a check for the quests you have done. More to come.
- Gear Planner / item tooltips: the Upgrade / Downgrade % is now of your whole gear's Value, not of the replaced item
  (a weak worn item made every small gain look huge, e.g. "+68%" for a slightly better dagger). With one decimal.
- One-handers for dual wield: the item goes to the hand where it gains the most Value (before: the most % of that
  slot, so a strong main hand was often compared with the weak off hand).
- Protection warriors and paladins no longer get two-handers suggested while wearing a one-hander and a shield.
- Assassination rogues level on Gear Judge's dagger curve (it was the general rogue curve).
- Custom weights: weapon DPS and speed per hand (main hand, off hand, ranged / wand), health, health per 5 sec. and
  mana are in the editor now - before, hidden values from the copied spec counted and the shown "Weapon DPS" did
  nothing on melee weapons. Only what the editor shows counts; a negative weapon speed = faster weapons are better.
  Older custom weights keep their melee DPS.
- /ofa gv: shows how the Gear Value of the item under the mouse comes about (weights, worn Value per slot, the
  replaced item, change, whole gear, result). Also /ofa gv with a shift-clicked item link.
- Info bar: Shift-drag moves it along the screen edge; drop it in the lower half of the screen and it sits at the bottom
  (upside down, it slides in from below). Right-click menu: "At the bottom of the screen" and "Back to the middle";
  Quality of Life > Interface > Info bar: "Bar position" Reset puts it back at the top middle.
- Info bar gold: alts no longer show 0 gold (the money read at logout was 0).
- Characters with the same first name (WoW Forever surnames) are no longer mixed up: the gold list of the info bar,
  "Twinks:" in recipe tooltips and the alt stock of the Crafting List keep them apart (with the class after the name).
  Each character shows up again after its next login.
- Guild members on the map: guild members who share their position with the addon OpenMap show too (OpenMap
  compatibility, thanks to CaptainBritish).
- Class trainer list: many spells were missing because the game has their learn level in another field - Dash (druid),
  Redemption and Turn Undead (paladin), the Shaman weapon imbues, Water Breathing / Walking, Far Sight, Astral Recall,
  Unending Breath, Eye of Kilrogg, Sense Demons, Detect Invisibility, Shadow Ward (warlock), Scare Beast, Eagle Eye,
  Beast Lore, Aspect of the Beast, Call / Dismiss / Feed Pet (hunter) and more.
- Druids can use polearms in WoW Forever (from level 20), rogues one-handed axes: the Armory offers them now.
- Hunter Pets: Furious Howl ranks show the right attack power (13 / 31-38 / 68 / 84).
- Auto turn-in / accept leaves repeatable quests alone (Mangletooth's Blood Shard quests were turned in again and again).
- Minimap button collector: TomTom's waypoint pins stay on the minimap.
- With Leatrix Plus the OneForAll minimap button is a LibDBIcon button, so Leatrix's button bag can take it.
- Short green stats: also "Block Value" (capital letters), threat (+1% Threat) and feral attack power lines.
- Data: game client 1.60.1.70888 (new enchants, trainer spells), QuestieDB update (quest givers and turn-ins, the new
  Riverglades profession trainers), talents of 10 Nov.

6.2.4 - All dungeon quests, Dalaran Sewer Key, Map buttons
===========================================================
- Dungeons & Raids: 70 missing dungeon quests added with their prerequisite chains - City of Dalaran now has its 4
  quests per faction with the quest chain before them, the new Forever dungeons (Krol'dok Stronghold, Blackmaw Hold,
  The Drowned City, Alcaz Prison, Shaper's Terrace) got their quests, plus the Dire Maul books and librams, Sunken
  Temple class quests and more.
- City of Dalaran: new key page "Dalaran Sewer Key" - it comes with Heart of Disruption from the Image of Archmage
  Modera; the Alliance lead-in and the Horde quests in Tarren Mill, with the Grimy Key as a loot line with its own
  Map button.
- Every quest and chain step whose start has coordinates has a Map button (also in Riverglades, Silithus, Mount Hyjal,
  Zephras Isle, Deadwind Pass, Shen'dralas); missing quest givers and coordinates filled in from QuestieDB.
- Quest list: quests for other classes are hidden; the new eye button shows them all. Class quests show the class
  name in your language.
- Key / attunement pages: the steps look like the dungeon quest list (done = green row, in log = green text), the
  step page shows the status with the quest log scroll, the key box only on the key itself.
- Razorfen Kraul: "An Unholy Alliance" is the Small Scroll step; the follow-up (Ambassador Malcin) is only in Razorfen
  Downs - it showed "In log" in Razorfen Kraul after both were done.
- Quest list header: the share and eye buttons sit side by side and on one line with the faction buttons.

6.2.3 - Gear Planner "All slots", dungeon quests on the map, symbols
======================================================================
- Gear Planner, Suggested: new button "All slots" - the 3 best upgrades of every slot at once, grouped under small
  slot headings (also in the Wishlist's "All slots"). A click on a slot shows that slot again.
- Gear Planner filter: new section "Armor type" with the armor your class can wear. By default the types you can wear
  now; mail / plate can be picked before level 40 and are on by default from level 40.
- World map quest marks: dungeon and raid quests show "[D35]" / "[R60]" and the dungeon's short name in the tooltip,
  and the "!" / "?" gets a small dungeon (or raid) swirl. Shift-click opens the quest in Dungeons & Raids.
- World map: our quest "!" / "?" no longer catch clicks - they go to the map below (zoom into a zone, Blizzard's quest
  icons); the tooltip still shows on mouseover. They are always drawn above book and dungeon entrance icons.
- Symbols instead of coloured dots, easier to tell apart with colour weakness: Professions (check = you, guild flag =
  guild, also in the boss loot's recipe drops), Library Books (check, bag, bank, pencil, "!", ring) and the guild
  flag on a dungeon entrance while a guild member is inside (was a green dot).
- "Craft" (recipe view, Crafting List) selects the chosen recipe in the profession window, also in WoW Forever's new
  profession window (Enchanting); before, it opened on the first recipe.
- Quest XP on the experience bar also works while a reputation is tracked (Discord report by sparklebeard).
- Hunter Pets: learned ability ranks are recognised on client languages without a OneForAll translation, e.g. Russian
  (Discord report by andrei_al).
- Gear Value: a one-hand weapon is compared with each hand as that hand values it; the off hand uses its own weapon
  speed weight (Discord report by Jax).
- Data update: QuestieDB (Forever NPC and quest fixes), Sharpie's Gear Judge 3.3.2 weights.

6.2.2 - Info bar, guild members on the map
==========================================
- New Quality of Life option "Info bar" (Interface, off): a band at the top middle of the screen, empty at first -
  right-click it to add what you want: gold (with your other characters), free bag slots, durability, experience,
  location with coordinates, clock, FPS and latency, new trainer spells, Library Books, hearthstone (use it with a
  click), class reagent (hunters: all arrows / bullets, with the icon of your ammo), guild and friends online, mail,
  the Value spec, OneForAll tabs and the game's windows (Character, Spellbook, Talents, Map / Quests, Looking for
  Group, Calendar, Legacy, Shop, Guild, Friends). Drag elements to change the order; pin it or let it fold up to a
  small tab; size, "Stay open" time, background colour, opacity and a "Default" button.
- New: guild members who also use OneForAll show on the world map (zone and continent, class colour; tooltip with
  name, level, class, zone). Inside a dungeon they show as a green dot on its entrance with "Guild members inside:".
  Members in your group get no dot. One switch for both ways in the new Quality of Life category "Guild": switched
  off, your position is not sent and you see nobody.
- Noteworthy changes popup for 6.2.2 (shown once), with a picture of the info bar.
- Class trainer window (hunters): new mode "Pet training" - the ranks the pet trainers teach by level with training
  points and costs, and the pet trainers of your faction with a Map button.
- Trainer list: mage Comprehend Scroll; rogue poisons with their levels; learned trap ranks no longer show as missing;
  Teleports / Portals of the other faction are no longer listed; spells of the other side are marked when you look at
  another class; the shaman's Totemic Projection has its new name.
- Tooltips: the quests you can take or turn in at an NPC (Quality of Life > Tooltips > "Quests on NPCs", on; off
  while Questie is loaded).
- Gear Value / Gear Planner: item set bonuses count (a second tooltip line shows the change with the set bonus);
  items with a random suffix get their arrow in Baganator and the loot roll window; dungeon quest rewards show the
  dungeon swirl (a click opens the quest) and are suggested for both factions; stat weights from Sharpie's Gear
  Judge 3.3.0.
- Professions: the search also finds recipes by their materials ("coarse thread").
- Buff reminder: a click always buffs you, also with a friendly target; a buff that missed you brings its card back;
  Find Herbs / Minerals / Treasure are suggested; warlock Spellstones and Firestones can be added.
- Dungeons: level ranges as the game's Looking For Group list shows them; quests of dungeons in the other faction's
  territory are shown right and a quest in your log always counts; new quest colours (teal = chain started, green =
  in your log); The Drowned City loot; Blackmaw Hold lists the Moontouched Wanderer; odd boss notes removed; Trouble
  in the Deeps no longer listed for Blackfathom Deeps.
- Check low spell ranks: action bars 6, 7 and 8 are checked too.
- Quest XP on the experience bar: new switch "Only tracked quests" (off).
- Nearby Library Book alerts: "Snooze 30 min" button.
- Bag bar: a quiver / ammo pouch shows all your arrows / bullets instead of the game's "*" (Quality of Life >
  Interface > "All ammo on the quiver", on for hunters).
- Quality of Life and Settings are locked in combat and free again after the fight (avoids errors from Blizzard
  windows locked in combat).
- Move windows: a window opens right at its saved place; windows are kept on the screen only while you drag them, and
  a window another addon hides (TSM's crafting and vendor view) is left alone; the Legacy window can be moved.
- Quest data updated (QuestieDB).

6.2.1 - New dungeons, leaner sparkles
=====================================
- New dungeons: Alcaz Prison, Blackmaw Hold, Krol'dok Stronghold and Shaper's Terrace show their bosses; The Drowned
  City gets its Primeval Elemental. First loot of the new dungeons (City of Dalaran checked against Wowhead Forever,
  with Forever drop chances and two blueprints). They no longer say "Not open on the beta yet".
- Blackfathom Deeps: the dungeon map shows the right picture in every room (Forever Simple World Map by Tarolg, with
  his agreement).
- Quest loot sparkles: only switch on the game's loot glow - your outline settings (Self Highlight around your character)
  stay as they are. Players who had it on get their old outline settings back once.
- Sparkle on herbs & ore: "Enable Interact Key" and the interact icons on objects are switched on only when you switch the
  option on - no longer forced again after loading screens or setting changes. Icons on NPCs and above nodes stay your
  choice. Fewer game settings written (none at logout), and the node's nameplate closes when combat starts.
- Buff reminder: a watched buff that ran out while you were logged out shows its card right after the login (only buffs
  this character had before).
- Gear Planner / item Value: stat weights updated to Sharpie's Gear Judge 3.2.13 (Forever) - new level 60 weights and
  leveling curves for every class. The top of the background picture fades into the dark, so name, level and spec are
  readable on every picture.
- Professions: recipes checked against the WoW Forever recipe data of wowtbc.gg - 7 new Enchanting recipes, Goblin
  Mining Helmet, corrected skill colours, reagents, recipe items and many missing learn levels. "All recipes" and
  "Crate rewards" no longer say "(beta)". New recipe filter "Not learned": the recipes this character does not know yet.
- Dungeon quests: the "Notes" are translated (German, French, Spanish).
- Dungeon loot: items the server does not send yet say so after a second.
- Quest data updated (QuestieDB: Silverpine and Priest quest fixes).

6.2.0 - OneForAll speaks German, French and Spanish
====================================================
- Languages: Settings > General > Language - English (default), Deutsch, Français, Español, in every game client
  (a Mexican Spanish client uses Español). In a game client of the same language the names of quests, NPCs, bosses,
  objects, items, zones and dungeons come in that language too (from the game and from QuestieDB).
- Professions: a filter (funnel) next to the recipe search - all recipes, my recipes, guild, mine or guild.
- Dungeon quests: quests in your log with every objective done show "Ready to turn in" (the row green up to the
  middle); in a quest chain the quest of the page turns green when done; long titles stay on one line.
- Dungeon loot: the wishlist star sits at the right edge, the drop chance left of it.
- Quest XP on the experience bar: the tooltip lists every finished quest with its XP.
- Buff reminder: no cards while you are dead or a ghost; watched buffs keep their spell / item ID, so they still work
  after switching the game client to another language.
- Minimap: "Move the minimap" is gone - it fought with the game's Edit Mode (the minimap jumped back and could lock).
  Move it with Game Menu > Edit Mode; if you had moved it with OneForAll, it is back at the top right once.
- Bug button and settings footer: our Discord only (CurseForge comments are closed).
- Data: quests from the newest QuestieDB (07.11.); class quest chains start with their lead-in quests again; 8 dungeon
  quests no longer show for both factions (Excavation Site, Hall of Thanes, Dalaran); Arcane mages level with arcane
  spell damage weighted in the Gear Planner.
- Quest loot sparkles: the option says that the outline around players and targets goes off while it is on.
- Layout: buttons, side lists and table heads make room for longer texts.
- The "New" marks of the 6.1 versions are gone.

6.1.9 - Class trainer fix, all tameable beasts, minimap position, quest icons
============================================================================
- Class trainer (book button in the spellbook): lower ranks of spells you know
  (e.g. Battle Shout rank 1 after learning rank 2) no longer show as not learned -
  the current client no longer names ranks in the spellbook. Mage: Clearcasting
  (the Arcane Concentration effect) is no longer listed as a trainer spell.
- Hunter Pets, Where to tame: every tameable beast of each family, about 300 more,
  including Zephras Isle (Ursera, Vuldren, Galestrider, Shriekling, Prideclaw,
  Windsong Crawler and the rare ones). The map button shows the area where a beast
  spawns. "8 Elite" / "10 Rare". Source: wow-petopia.com/forever and QuestieDB.
- Move the minimap: the minimap no longer jumps back to its default place now and
  then (the game re-placed it).
- World map quest icons: "Quest givers (!)" and "Turn-ins (?)" can be switched on
  and off on their own (both on), also in the map button's list - for when the
  game's own ? already shows.
- Dungeon quests: a completed quest has a light green row and a bright green name
  (no check mark), a quest in your log the darker green; the selected quest gets a
  gold frame.
- Quest data from the QuestieDB update of 07.11. (quest icons, rewards, class
  quests, quest items on nameplates, trainer and vendor spots); trainer data of
  client build 1.60.1.70862 (Divine Grace, Confounding Flash, Contingency Plan and
  Dark Sacrifice learned from a quest; enchant learn levels).

6.1.8 - Herb & ore sparkle fix, recipe fixes, more movable windows
=================================================================
- Professions, recipe sources: vendors and mobs with an apostrophe in their name
  (Hula'mahi, Rin'wosho the Trader, the Mosh'Ogg ogres ...) showed a line of raw
  data instead of their name, zone and faction (GitHub #45, thanks Checkov23).
- Professions, "Sold by": vendors of both factions (e.g. Kzixx in Duskwood) were
  hidden for everyone since 6.1.4.
- Sparkle on herbs & ore works again for players without a controller: since
  6.1.6 it left the game's "Enable Interact Key" off, and without it the game
  finds no herbs or ore. It is switched on again while the sparkle is on and
  given back when you switch the sparkle off.
- Move / Resize Blizzard windows: also the Social (friends) window, the Calendar
  and the Shop.
- Professions: about 390 recipes that showed "?" as learn level now have one
  (from public recipe lists); the level read at the trainer still replaces it.
- Professions: the favorite star scrolls with the recipe instead of staying on
  top of the boxes, and the "learn levels unknown" note is no longer cut off.

6.1.7 - Hotfix
==============
- World map: with Remove Fog our icons (quest "!" and "?", flight masters, zone
  transitions ...) no longer vanish under the uncovered parts of the map - they
  lay below the map's own layer since 6.1.6.

6.1.6 - More reagent sources, more quest icons, bug fixes
==========================================================
Professions
- Reagent sources also for the reagents that had none: smelted bars ("Smelted
  with Mining from"), leather and scales ("Skinned from"), fish ("Fished in" with
  the best zones), enchanting materials ("Disenchanting items of item level
  ..."), raid materials and containers like clams (data from the WoW Forever
  item pages of Wowhead). Mobs, vendors and objects inside a dungeon or raid show
  too, their map button points to its entrance.
- Profession trainer: no more "Missing on/off parameter in
  SetTrainerServiceTypeFilter" error when you open it, and the learn levels of
  recipes are read again.
- Nearest trainers: the new junior gathering trainers of WoW Forever (e.g.
  Fanorran Stilloak in Teldrassil) and other trainers that were missing.
World map and quests
- Quest data read through QuestieDB itself, with every one of its corrections:
  about 370 more WoW Forever quests show their "!" at the right giver,
  repeatable quests no longer do, Children's Week quests only belong to the
  event, quest givers of one faction no longer show an icon in the other
  faction's lands; Map Landmarks, Gear Planner quest rewards, class quests and
  vendor reagents updated too.
- Library Book quests show their "!" at the librarian only while you carry the
  book (Friend of the Library: any book) - the new quest data listed them for
  everyone.
- Class quests the quest data had for every class (e.g. the priest quest Divine
  Grace for a paladin, GitHub #41) show only for their class - each one checked
  against Wowhead.
- Quest icons let clicks through, so the game's own "?" of a finished quest
  below ours opens the quest again (GitHub #38).
- Ruins of Lordaeron: The Wrath of Rath'mael now needs Rear Guard Patrol and The
  New Plague needs A Recipe For Death first, as on the live servers.
- Dungeon quests: a quest log button next to "In log" in the quest details and on
  each step of a quest chain that is in your log; the selected quest in the list
  keeps its colour (green = in your log, white = not taken) - the yellow looked
  like a higher-level quest.
Bug fixes
- Message history (arrow up in the chat box): commands like /focus or /target
  are no longer brought back - a recalled command counted as addon code and the
  game blocked it ("OneForAll tried to call the protected function FocusUnit()").
- World map: opening it in combat no longer gives "OneForAll tried to call the
  protected function Button:SetPassThroughButtons()".
- Sparkle on herbs & ore no longer switches the game's "Enable Interact Key" on -
  it stays as you set it. With a controller connected the sparkle changes no game
  settings (it caused "SetPreferredGamepadInteractTarget() blocked" errors), and
  "Move / Resize Blizzard windows" leave the bags alone (the controller's cursor
  jumped between the bag slots).
- Bags full helper: no more blinking when you right-click an open corpse again,
  it stays in the loot mode when the loot opens again, keeps the item you browsed
  to while it is still in your bags and no longer reaches off the screen.
- Gear Planner Value: "spell hit" and "spell crit" on an item count like hit and
  crit (WoW Forever has one of each) - they counted far too little for melee,
  e.g. for an Enhancement Shaman.
- No more login note asking you to /leave the old OFAShare channels - the game
  keeps them and /leave does nothing; they are harmless.

6.1.5 - Reagent sources, flight times, recipe learn levels, gear value fixes
============================================================================
Professions
- Click a reagent in the recipe details to see where to get it: made with a
  profession, the nearest vendors of your side, gathered from herbs, ore veins
  or fishing schools, or the nearest mobs that drop it ("Show all" for more),
  each with a map button that outlines the area where it spawns (data from
  QuestieDB).
- Recipe learn levels are read when you visit a profession trainer (also for
  recipes you know) and shown from then on; "?" where it is not known yet, with
  a quiet note how many are still unknown.
- Crafting List: "Craft" makes all of them (not more than your materials allow),
  every craft takes one off the list, no more "Cannot anchor protected frames"
  error, and the button text fits.
Flights (Quality of Life > World Map, both on)
- "Open flight map at once" at a flight master (not when it has quests for you,
  Shift talks normally).
- "Flight times": the time in the flight map tooltip and a small movable window
  with the time left while you fly. The times come from the flight paths in the
  game data and get more exact with every flight; works in every client language.
Gear Value
- Random bonus items ("... of the Bear") are valued with their bonus stats in
  your bags too - they always showed as a downgrade.
- With a two-hander in your hands shields, held items and off-hand weapons no
  longer show as an upgrade for an empty slot.
- Spell power no longer counts twice for healers.
Buff reminder
- Shaman weapon imbues (Flametongue, Frostbrand, Rockbiter, Windfury Weapon) work,
  in every client language; the card comes as soon as the imbue is gone.
- Buffs that are no spell of yours (Well Fed, flasks) show their real icon.
Other
- Accept quests automatically: grey quests are left for you to take by hand.
- Hunter Pets: no more "secret string" errors in dungeons.
- Yellow "!" marks on the new options and features of 6.1.4 and 6.1.5.

6.1.4 - Buff reminder snooze and glow, recipe channel off, quest and vendor fixes
==================================================================================
Buff reminder
- Snooze: right-click a card (or "Zz" on it with the new option "Snooze
  button") and that buff stays quiet until you cast it again - e.g. Battle Shout
  while you fish.
- New option "Flash cards" (on): the game's proc glow around the icon, so you
  notice the card.
- The buffs you have right now are offered first when you add a buff.
- Combat: the card comes when a buff runs low also while the game hides your
  buffs (OneForAll goes by the time the buff had, or by its duration when you
  cast it right before the fight, e.g. a Seal); a buff you cast again removes
  its card at once; no false "run out" for buffs whose time is not known (thanks
  to MartinDoyleUK, PR #36).
Recipes
- Recipes of other OneForAll users: the game disables chat channels once many
  players are in them (OFAShare2, then OFAShare3), so this search is gone - no
  channel, no "Search" button, no "Share recipes" switch. Recipes of your guild
  members are shared as before. If OFAShare channels are still in your channel
  list, OneForAll shows the /leave commands at login.
- "Sold by" shows only vendors of your faction (and neutral ones).
Other
- Turn in quests automatically: quests that take battleground marks (Warsong
  Gulch, Arathi Basin, Alterac Valley) are not turned in by themselves.
- Bags full helper: items can be destroyed in combat too.
- Dungeon maps: a "World map" button switches to the game's world map (handy when
  M opens the dungeon map). /ofa dmap opens the dungeon map for testing.
- Quality of Life: the sub-options of Buff reminder and Map Landmarks sit two in
  a row.
- Move Blizzard windows: no more "AddOn tried to call a protected function" when
  the spellbook is first opened in combat; it becomes movable after the fight.

6.1.3 - Too many channels, buff reminder in combat, quest icon fixes
===================================================================
- 6.1.2 could join up to ten OneForAll channels (OFAShare3 to OFAShare12) when
  the game refused the recipe channel, e.g. for low characters, and then showed
  "You can only be in 20 channels at a time". Now OneForAll uses only OFAShare3.
  The game does not let addons leave channels, so OneForAll tells you the
  /leave commands for the extra ones. When the game refuses the channel, the
  recipe search says so and nothing else is joined.
- Buff reminder: a buff no longer counts as run out in combat just because the
  game hides it or stops listing it (e.g. after another buff or debuff came up);
  it reads your buffs one by one and goes by the time the buff had left.
- Quest icons: the WoW Forever class quests Glyphic Parchment (Orc mage),
  Tainted Tablet (Troll warlock) and Hallowed Memorandum (Gnome priest) showed
  for every class of that race; "The New Horde" no longer shows at Eitrigg in
  Orgrimmar (he does not give it there).
- The main window shows the OneForAll version at the bottom right.
- Talent data of 04.11. (talentsforever), checked against the live client.

6.1.2 - Recipe search works on the live servers
================================================
- The live servers disabled the hidden recipe channel and refused all messages
  there, so the recipe search found nobody and said "Many searches right now".
  OneForAll now uses a new channel, joins it as a normal (hidden) channel and
  moves on to the next one when the game refuses or disables it. Then it says
  so instead of "Many searches". Version checks use the same channel.
- /ofa channel shows the last message the game refused.

6.1.1 - Launch talents, quest icons on the continent map
==========================================================
- Talent Trees: every talent is placed where your game client has it, and talents
  the planner's data does not know are shown too. (The launch client still had
  the old Rogue, Shaman and Warrior trees, so some talents were missing.)
- Trainer data of the launch build: Righteous Fury from level 10, Death Mark
  (Rogue), Lacerate ranks for Druids, Holy Shield and Explosive Trap ranks;
  removed spells are gone (Blessing of Light, Salvation, Lava Burst, Binding
  Heal, Frost Blast, Revoke).
- World Map > Quest icons "Also on the continent map" (on): the ! and ? of every
  zone also when you zoom out to the continent (Quality of Life and the map
  button).
- Quest icons no longer show quests more than 10 levels above you (level 60
  book, Legacy and event quests showed for low characters).
- The route of a walking quest giver shows the giver's tooltip and is slightly
  highlighted when you move the mouse over it.

6.1.0 - Recipe search, launch talents, wishlist tools
======================================================
Ready for the WoW Forever launch: a recipe search that stays fast with many
players, the talent trees of the launch patch and handy wishlist tools.
Recipes of other OneForAll users
- New "Search" button in Professions > All recipes: asks the other OneForAll
  users who know the recipe (a new hidden channel). Only a few of them answer,
  so the channel stays quiet and fast however many players use OneForAll.
  Players in your zone are found first. Shows "Searching", the players with
  level, class and zone, and "Search again" (after 30 seconds, with a countdown).
- Players found before show up at once while they are online (blue check in the
  list). Recipe lists are no longer sent to the channel; the online status is
  sent less often when many players are online. Guild sharing stays as it was,
  and a guild list now replaces the stored one only when it arrived complete.
- "Share recipes with other OneForAll users" moved from Settings to Quality of
  Life > Social. /ofa channel shows more numbers.
- Note: 6.0 and 6.1 users no longer see each other's recipes - please update.
Talents
- Talent trees of the launch patch (talentsforever.com, 03.11.): Rogue, Warrior,
  Shaman (e.g. Call of Thunder instead of Lava Burst), Paladin, Druid, Mage,
  Priest and Hunter. Trainer and quest data refreshed. Old Paladin and Warrior
  build links no longer fit and are refused.
Gear Planner
- Item tooltips show "OFA (star) Wishlist" for items on your wishlist.
- Wishlist: "Clear wishlist" with "Clear all" and "Clear smart" (only items that
  are no upgrade any more), both ask first; "All slots" shows the whole wishlist.
Quality of Life
- Buff reminder: weapon items are suggested from 2 letters on, also when none is
  in your bags (sharpening stones, weightstones, oils; poisons for rogues); a
  note that any buff name can be added; "sec" next to the seconds. Blessing of
  Light and Salvation removed from the Paladin presets.
- Sell junk checks each item again right before it is sold.
- Option tooltips open below the option and only over its name and text;
  drop-down menus grow with their longest entry.
Other
- The main window banner fades out softly on the left, without a line under it.
- Fixes: special bags in the bag helper, hunter options in the welcome setup,
  item quality in the Crafting List, wand check in the enchant score.

6.0.3 - Buff reminder update and quest fixes
==============================================
A bigger buff reminder, quest marks for loot quests and many small fixes.
Buff reminder
- Size slider and a Test button (shows the reminder for 10 seconds to place it).
- "Show icon only": the icon with the time left and a bar as wide as the icon.
- No frame around the cards any more.
- Works in combat too (the icon can only be clicked out of combat); a buff you
  cast again in combat removes its card at once.
- Weapon oils, sharpening stones and poisons: type the item's name and pick
  "(main hand)" or "(off hand)"; time left and charges, a click uses the item.
- Suggestions for items in your bags; flasks: use the buff's name.
Quests
- Quest marks on nameplates also show mobs that drop quest items (bag mark).
- New option (on): a gold coin on the quest reward with the best sell price.
- Gear Planner and class quests use quest data with all QuestieDB corrections
  for WoW Forever (right faction for some druid quests, fixed pre-quests).
World map
- Icons that sit on a dungeon entrance (like a Library Book) move next to it.
- Flight masters use the game's own icon.
- The OneForAll map marker (e.g. from Library Books) can be removed by a click.
Quality of Life
- Preview pictures for 14 more options; tooltips in one fixed column.
- Move Blizzard windows: also the AddOns, Options, Customer Support and Game
  Menu windows.

6.0.2 - Quests on the world map
=================================
Quest icons, level ranges and zone transitions on the world map, quick quest
sharing in dungeons and a smarter Gear Planner.
World map
- Quest icons (on by default, Quality of Life > World Map > Quests): a yellow !
  at quest givers with quests for your level, a ? where you turn in finished
  quests. The tooltip lists the quests with their level and the levels in which
  they still give experience, e.g. "[8] Practical Prey (5-13)". Walking quest
  givers show their route. Hidden while Questie is loaded.
- The zone's level range at the top right of the map and behind the zone name
  when you hover a zone on the continent map (on by default).
- Map Landmarks: zone transitions - a signpost where a road leads into the next
  zone; the tooltip names it, a click shows it (places from Carbonite, GPL).
  Calmer icon sizes; dungeon and raid entrances always on top.
- A OneForAll button at the top left of the map (below other addons' buttons
  like RareScanner) with all World Map switches in a small list.
- Remove Fog: a slider for how visible the unexplored parts are (0-100 %).
Dungeons & quests
- Dungeons & Raids > Quests: "Share all Quests" shares, one after the other,
  the quests of that dungeon a group member is missing and can take - also
  outside the dungeon.
- Quality of Life > Quests: "Quest marks on nameplates" (off by default) - a
  sword on mobs you must kill, a bag on mobs that drop a quest item, with your
  progress (3/10); position left, top left, top, top right or right (default).
  Works in every game language; not inside dungeons yet.
Gear Planner
- Source filter right of "All", several sources at once, new source "Crafted";
  crafted Bind on Pickup items only for your own professions.
- Crafted items show their profession; a click opens the recipe.
- Quest rewards count from the level you can take the quest at; items without
  a required level are listed again; the list title shows the sources on mouseover.
Talent Trees
- Import: buttons for talentsforever.com and wowforevertalents.com put the link
  into the field, selected, so Ctrl+C copies it; the field empties afterwards.
More
- Tooltips: new option to hide the blue "You haven't collected this appearance"
  line (off by default).
- Quality of Life: the option rows are a little closer together.
- Welcome setup: resize Blizzard windows, short green stats and quest marks
  can be switched on there too.
- Noteworthy changes updated (/ofa news or Settings > Window).
- Resize Blizzard windows: the "%" display no longer stays on screen.

6.0.1 - A new look, profiles and buff reminders
================================================
A new look for the whole window and a set of new helpers.

New look
- A banner with the logo across the top, the tabs below it in a browser style;
  the Settings tab is a gear at the right end.
- Every tab has the same list on the left with its emblem on top; no more boxes
  around the parts of a page, fine lines between them instead. Switches instead
  of checkboxes, thin scroll bars, thinner lines; popups get the window's frame.
- Quality of Life, Dungeons & Raids and Hunter Pets have a head with a search.
  Dungeons: names, zones and bosses. Hunter Pets: one search over families,
  abilities and rare tames.
- Talent Trees: larger trees, the preset actions (save, reset, import, export)
  in the list on the left.
- Map buttons in lists are a small map symbol now; the dungeon / raid page keeps
  a real "Map" button.
- Quality of Life: Chat has its own entry in the list.
- Welcome setup: gold arrows on Back / Next. Lists you can remove entries from
  (watched buffs, kept low ranks) show a red cross.
- Logo color: new "Bronze", picked by clicking the logos. The card logo of the
  minimap button collector no longer has dark corners.

Profiles (Settings > Profiles)
- A profile holds the Settings and Quality of Life options and the shown tabs
  with their order; every character picks its own (new characters: Default).
  New, Copy, Rename, Delete, Export / Import as text, or Send to a player who
  has "Receive" switched on (off by default; they are asked first).
- After the update every character starts on "Default". The shown tabs were
  saved per character before and are part of the profile now.

Quality of Life
- Buff reminder (off by default): add your own buffs with a time in seconds;
  a small card shows when one runs low or out - click its icon to cast it
  again. Up to 4 cards, off in combat, "Sleep in cities" keeps it quiet in the
  capitals. Name suggestions while typing.
- Chat > Message history (on by default): arrow up / down in the chat box
  brings back your last 5 messages.
- Short green stats (off by default): long "Equip:" lines become "+1% Hit",
  "+9 Spell Healing" and so on.
- Hide error messages (off by default): no red "Out of range" messages; full
  bags, a full quest log and not enough money are still shown.
- Resize Blizzard windows (off by default): right mouse button + drag; also the
  Looking For Group window can now be moved and resized.
- Arrow color by armor type (off by default): a yellow arrow for upgrades in a
  lighter armor type than your class's best.
- Map Landmarks: Skyborne ley lines and elemental convergences on the world
  map (on for Skyborne, locations from "Skyborne Leyline & Convergence Marker"
  by tr0tsky, MIT).
- "Compare items only with Shift" is now "Disable automatic compare tooltip".

Professions & Armory
- Skill-up chance in % on yellow and green recipes; known recipes show how many
  you can make with the reagents in your bags, e.g. "Copper Rod (2)".
- Gear Planner: the picture of your race behind your character; your own gear
  no longer shows a comparison with itself.
- Dungeon / raid page: a real "Map" button next to Bosses & Loot.

Fixes
- The window could not be closed in combat after a recipe with a Craft button
  was shown.

6.0.0 - Ready for the launch of WoW Forever
==========================================
A fresh start: a welcome setup for everyone, a new logo, one look and many new
helpers. The yellow "!" marks are gone; new things start clean from here.

Welcome & look
- A welcome setup, shown once to everyone: a few pages to switch on Quality of
  Life helpers right away (or skip it). "Recommended settings" switches on what
  OneForAll suggests. /ofa setup or Settings > Window opens it again.
- New logo: the minimap button is a round gold "1", the minimap button
  collector a gold card. Quality of Life > Minimap > "Logo color" picks
  turquoise (default), red, blue, green or violet.
- One look for everyone: the skins are gone, OneForAll always uses the gold
  modern style (an old skin choice is simply ignored).
- New Discord button in the title bar (and in the bug report window). The
  window height grip sits on the bottom edge of the window.

Talent Trees
- Import builds from talentsforever.com and wowforevertalents.com links, or
  from an OneForAll build string; Export shows your build as a short text.
- The game's own tree pictures behind the talents, more room between the
  talents, and talents without a point turn grey when all 51 are spent.

Trainer window (spellbook tab)
- Opens from a tab in the spellbook, like the spellbook's own tabs.
- Weapon skills: what a class can learn and the weapon masters of your faction.
- Class quests: the important quests of your class (pets, totems, forms,
  stances, class items) with your progress, a Chain button and Map pins, for
  the quest givers of your home city.

Professions
- Crafting List: plan what to craft with "+ List"; its own window shows the
  materials against your bags, bank and your other characters, breaks down
  what you can craft yourself and lists what you still need. "Craft" buttons,
  tooltips ("Crafting List: N more needed"), /ofa craft.
- Recipes in framed boxes, a "Craft" button for recipes you can craft.
- Nearest trainers knows the trainers on Zephras Isle.

Gear Planner
- Your own stat weights ("Edit custom weights..." in the spec list).
- A source filter: Bind on Equip, quest rewards, dungeon or raid drops.

Quality of Life
- Own junk list: Alt+right-click an item in your bags; "Sell junk" sells it,
  and it gets a junk coin in the game's bags and in Baganator (also when
  another addon such as RestedXP is Baganator's junk source).
- Hide chat: a button at the chat (on), a key (Key Bindings > OneForAll) and
  "Hide chat after" a quiet time (Never by default).
- Sparkle on herbs & ore (off by default; adapted from Lueur by Armytille, MIT).
- Minimap: square minimap, move the minimap (Shift-drag), hide the OneForAll
  button; the collector also takes MapUtils / D4Lib buttons.
- Move Blizzard windows also moves the newer windows of WoW Forever (world map,
  professions, spellbook, Combined Backpack ...), by their title bar.
- The tooltip of an option shows next to its name.

World Map
- Map Landmarks: Library Books on the map, the Deeprun Tram, the new boats of
  WoW Forever and the airships from Valanaar, with new icons.

Dungeons & Raids
- Plain list headers for quests and keys / attunements, like the boss list.

Fixes
- No more "blocked action" errors in combat from the profession window or the
  craft buttons; many smaller fixes.

5.7.2 - Item compare fixes
------------------------------------------------------------
- Upgrade / downgrade arrows compare the items' own stats only: an enchant on
  the worn item no longer counts.
- Items for other classes only ("Classes: Warlock") no longer get an arrow.

5.7.1 - Remove Fog, AddOns list
------------------------------------------------------------
- Quality of Life > World Map: new option "Remove Fog" (on by default) shows
  the parts of a zone you have not explored yet.
- OneForAll is in the game's AddOns list at the minimap too (handy with ElvUI
  or a hidden minimap button).

5.7.0 - New Quality of Life layout, enchants in the gear planner, set buttons
------------------------------------------------------------
- Quality of Life: groups on the left like Armory and Professions, one group
  at a time with a short description under every option, and a search over
  all settings. "Popups & Alerts" moved here from Settings (with Durability
  warning), "Dungeon map on M" moved to World Map, Quest XP to Quests.
- New option "Brighter colors" (Unit Frames, on): class-colored health bars
  use a plain bright bar instead of the game's dark art.
- Spellbook (P): a book button opens the trainer window (next spells and
  ranks for your class) next to it; it closes with the spellbook. Switch in
  Quality of Life > Spells (on).
- Gear Planner: a small field next to every item that can be enchanted or
  improved (enchants, armor kits, spurs, shield spikes, counterweights,
  scopes, arcanums, shoulder enchants) shows what is on it; a click lists what
  fits, best for your spec first, with where to get it, who knows the recipe,
  a button to the recipe in Professions and the wishlist star.
- Armory: Raid, Dungeon, PvP and Crafted Sets have buttons for their main sets
  and an "Other Sets" list for the rest; sets sorted with the highest level
  first.
- Professions: the Merchant's Favor button shows your Favor (the second box
  is gone); jumping to a recipe scrolls to it also the first time.
- Settings: "Window" moved to the right column.
- Quest sharing no longer posts an emote (option removed).
- New installs also start with Farther camera zoom and Move Blizzard windows.
- New "Noteworthy changes" popup; the "!" marks of 5.6 are gone, new ones
  show what is new in 5.7.

5.6.7 - Gear value fix, wishlist stars in the Armory, new client data
------------------------------------------------------------
- Gear Value: worn items with a random bonus ("of the Eagle" and the like)
  now count with their bonus stats, so items are no longer shown as huge
  upgrades over them. "(replaces ...)" is shown for upgrades only.
- Armory: item sets and reputation rewards have the wishlist star too (far
  right, like everywhere else).
- Armory, Professions and Talent Trees: the left side panel keeps its size in
  a taller window, and the talent points bar stays right under the trees.
- Trainer window: spell list from the new client build (new spells like
  Frost Blast and Arcane Wrath, new ranks, changed levels).
- Talent planner: Mage talents updated to the hotfix of October 20; spell IDs
  of the new talents, so non-English clients match them too.
- Hall of Thanes: boss levels (16).

5.6.6 - Upgrade arrows on quest rewards
------------------------------------------------------------
- Quest rewards: a green arrow on reward and choice items that are an
  upgrade, at the quest giver and in the quest log.
- /ofa questtest opens the quest log at one of your quests with a gear
  reward to check it.

5.6.5 - Upgrade marks and spec choice
------------------------------------------------------------
- Loot roll window: a gold star on wishlist items, a green arrow on upgrades.
- Bags (the game's bags and Baganator): a green arrow on items that are an
  upgrade you can wear now.
- Gear Planner: pick the spec the upgrades are calculated for (default: your
  active spec); druids can also pick Feral (Bear).
- /ofa rolltest shows the loot roll window with an example item.

5.6.4 - Gear Value fixes
------------------------------------------------------------
- Gear Value: spell damage of one school (shadow, fire, frost ...) now
  counts for the specs that use it; staffs and daggers of casters no longer
  count their weapon damage like a wand.
- Rings, trinkets and dual-wield weapons: the tooltip names the worn item
  the upgrade replaces (the weaker of the two).
- Gear Planner: legendary and other quest items in their quality color,
  shorter "lvl 13", the map icon without a frame, "Reset" in the corner.
- Armory > Reputation: click a standing band to fold its rewards.
- Recipes of other OneForAll users: a zone in another client language is no
  longer shown for players inside a dungeon.

5.6.3 - Gear Planner
------------------------------------------------------------
- Armory: new Gear Planner as the first page (the Overview is gone). Your
  character on the left (mouse wheel zooms, drag turns it, right-click an
  item to try it on); click a slot to see upgrades for it from dungeon loot,
  quest rewards of all quests, set pieces, reputation gear and crafted
  items - only what your class and faction can use, in a level range you
  choose ("My lvl" / "All").
- Every item shows how much better it is than what you wear, in %, for
  your talent spec (stat weights from Sharpie's Gear Judge). Item tooltips
  show it too: "OFA" with a green arrow "Upgrade: 30%" or a red arrow
  "Downgrade: 12%" (Quality of Life > Tooltips > Gear Value).
- Wishlist: the star on items in the Gear Planner and in Dungeons & Raids
  (loot and quest rewards). Search over all items.
- Quest rewards are marked with a yellow "!"; the map button shows the quest
  giver, "Chain" opens the whole quest chain (green = done, yellow = in your
  quest log). The dungeon swirl opens the boss that drops an item.
- Recipes of other OneForAll users: players show up right after login and
  stay after a /reload, new players are asked for their recipes directly,
  the channel join and throttled messages are retried, and dropped
  professions disappear. The hidden channel moves to the end of your channel
  list, so /1 is General again. /ofa channel shows the state.
- Fixed: opening another player's profession from a chat link no longer
  marks those recipes as known by you.
- Dungeon maps: the entrance is shown as the dungeon (or raid) swirl.
- Map Landmarks: icons stay above other addons' map icons.
- "Thank players who buff you" thanks after 1 second instead of 3.

5.6.2 - Map Landmarks, talents of the October 15 patch
------------------------------------------------------------
- Fixed: OneForAll wiped the data of "Forever Companion: Discovery Journal"
  when both were installed (same saved variable names from OneForAll's old
  name). OneForAll now saves under its own names; your settings are moved
  over automatically.
- New Quality of Life option "Map Landmarks" (on): icons on the world map for
  dungeon and raid entrances, flight masters, zeppelins and ships with their
  destinations. Click an entrance to open that dungeon in OneForAll,
  Shift-click for a map pin. Each part can be switched off.
- Talent planner updated to the October 15 beta patch (Priest, Shaman, Mage,
  Warlock, Warrior, Druid). Renamed talents are still found.
- "Thank players who buff you" works again: the player who buffed you is
  found even if he is not your target. Only buffs longer than 2 minutes,
  3 seconds later, not in combat and not after a loading screen.
- New install: the most useful Quality of Life helpers start switched on.
  Existing settings are not changed.
- Boss levels and boss/entrance positions on the maps of Ruins of Lordaeron,
  Excavation Site (now level 26-31), City of Dalaran and Hall of Thanes.
- Bug report window: GitHub or CurseForge, with your version, class, level and
  the last errors ready to copy.
- Less work in the background (animations only while something moves, bag
  changes redraw only the open tab), unused graphics removed.
- The minimap button collector is 10 % smaller.
- Noteworthy changes now cover all 5.6 versions and only appear when you come
  from a version before 5.6. The yellow "!" for new options sits left of the
  checkbox and stays for all 5.6 versions.

5.6.1 - Modern skins and low spell ranks
------------------------------------------------------------
- Two new skins: Gold Modern and Dark Silver Modern, with plain frames,
  dividers, buttons and boss rings with rounded corners. The brush button in
  the title bar opens a list of all four skins (also in Settings > Skin).
  This version switches everyone once to Gold Modern - pick another skin any
  time.
- Modern skins: Window opacity in Settings > Window (70-100 %, starts at
  95 %). Only the backgrounds fade, text and pictures stay solid.
- Dark Silver is a little brighter.
- New Quality of Life option "Check low spell ranks" (on): finds spells on
  your action bars that use a lower rank than one you already know and puts
  the highest rank there with one click. After a trainer visit it waits
  until you close the trainer. "Keep" leaves a rank you use on purpose alone.
- Class trainer window: shows everything your class can still learn up to
  level 60. The level bars no longer show an arrow.
- All popups share one look with the addon's own close button; the library
  books popup can be moved.
- A small click sound when you switch tabs.

5.6.0 - Armory and dungeon maps
------------------------------------------------------------
- New Armory tab (replaces General): raid, dungeon, PvP, crafted and world
  sets with class filter, owned pieces (bags, bank, equipped), set bonuses,
  required level and where each piece drops ("Show" opens the boss in
  Dungeons & Raids). Sets that are not in WoW Forever yet are marked. PvP
  includes the rank 14 weapons.
- Reputation rewards of every faction grouped by standing, with your standing
  and the vendor on the map.
- Dungeon maps for all dungeons and raids: boss portraits (click for the
  loot), entrance, zoom and drag. Inside a dungeon the world map key (M) opens
  its map (Settings > Dungeons | Raids). Map layout from Forever Simple World
  Map by Tarolg.
- New tab order (Armory, Dungeons & Raids, Professions, Quality of Life,
  Talent Trees, Library Books, Hunter Pets); the window opens on the tab you
  used last.
- New banners for Armory and Talent Trees.

5.5.1 - combat errors fixed
------------------------------------------------------------
- Fixed Lua errors in combat when nameplates are shown ("secret" values in
  boss portraits and class colours). Class colours no longer touch nameplate
  health bars.
- Event handlers are protected: if something goes wrong, the error is caught
  instead of popping up again and again. /ofa errors lists the caught errors
  (with version and client language) for bug reports.

5.5.0 - raids, trainer spells, minimap buttons
------------------------------------------------------------
- Dungeons & Raids (tab renamed): new Raids view with Barrow Deeps, Hyjal
  Summit and Onyxia's Lair, grouped by size (10 / 20 / 40 players), with
  bosses, known loot, quests and the Onyxia attunement for both factions.
- Key / Attunement tab: switch between Alliance and Horde steps.
- Talent Trees: trainer button (top left) opens the class trainer window:
  spells and ranks you do not know yet for your level and the next levels,
  costs from your trainer visits, quest-taught spells marked, every other
  class selectable.
- Professions overview: Nearest trainers for every profession with a Map
  button; smaller tiles.
- Quality of Life: Collect minimap buttons (bar behind a movable OneForAll
  button, opening to any side, preview picture); the bags full helper's
  "never suggest" list can be edited; new options marked with a yellow "!".
- Thank players who buff you: tooltip explains that friendly nameplates help.
- The minimap button sits on the edge of the minimap again.
- Settings tab scrolls on small windows; scroll bars of Quality of Life and
  Settings sit inside the window; the window is placed on whole pixels.
- Noteworthy changes popup for 5.5.0. New commands: /ofa buttons, /ofa trainer.

5.4.4 - dungeon data from own sources
------------------------------------------------------------
- The first 14 dungeons (Hall of Thanes to Scarlet Monastery: Library) were
  rebuilt from the same sources as all other dungeons: boss and trash loot,
  quest rewards, XP and reputation, quest chains, map pins and entrances.
  Some loot tables are larger now; a few quest values (e.g. XP) follow the
  current Forever beta data.
- Follow-up rewards are shown again (e.g. Hidden Enemies, The Glowing Shard),
  quest items and bags are back in the boss loot.
- DUNGEON_DATA_SOURCES.txt rewritten.

5.4.3 - bug report button
------------------------------------------------------------
- New bug report button in the title bar (next to the skin switch) and
  /ofa bug: shows the link to the issue page on GitHub to copy, together with
  your addon version, class and level.
- Quality of Life tab has its own banner.
- Shorter tooltip for "Compare items only with Shift".

5.4.2 - tooltips, talents and dungeon texts
------------------------------------------------------------
- Quality of Life: new option "Compare items only with Shift" (Tooltips).
  It switches the game setting alwaysCompareItems (on = 0, off = 1).
- Boss loot: the item tooltip opens next to the item name instead of next
  to the drop chance and no longer jumps to the edge of the screen.
- Talents: the rank number (e.g. 2/3) stays readable on mouseover.
- Recipe sharing: when turned off, you do not see other users' recipes
  either; the setting text and the legend say so.
- Dungeons: the first 14 dungeons (Hall of Thanes to Scarlet Monastery:
  Library) got new descriptions, quest notes and boss notes. Quest givers,
  turn-ins and objectives come from the same data as all other dungeons.
  Quest start map pins of these dungeons updated.
- Boss portraits: simpler lookup. A portrait comes from the dungeon data or
  is learned when you target the boss once.
- OneForAll is now licensed under the GPL-3.0 (see LICENSE.txt).

5.4.1 - quest and boss details
------------------------------------------------------------
- Quest details redesigned: chips for level, faction, class and status;
  label rows (starts at with map button, turn in, dungeon, status); framed
  boxes for objective, quest chain, notes and rewards. Same layout in the
  Key tab.
- Boss header shows "Level | creature type | rank" (Elite, Rare, Summoned)
  instead of the loot count. Missing types are learned when you target the
  boss.
- Quality of Life: the right column is flush with the title band.

5.4.0 - all dungeons
------------------------------------------------------------
- Dungeons: all Classic dungeons up to Stratholme now have quests, quest
  chains, quest start map pins, boss loot and trash loot: Scarlet Monastery
  Armory and Cathedral, Razorfen Downs, Uldaman, Zul'Farrak, Maraudon, the
  Sunken Temple, Blackrock Depths, Lower and Upper Blackrock Spire, Dire Maul
  East / West / North, Scholomance and Stratholme.
- New Forever dungeons: The Drowned City (bosses and three Horde quests),
  Krol'dok Stronghold, Alcaz Prison, Blackmaw Hold and Shaper's Terrace
  (location and story; bosses, quests and loot follow once they are known).
- Pictures for all new dungeons; boss portraits work without seeing the
  boss first.
- Boss loot shows the Classic drop chance (Forever can differ).
- Dungeon keys: "Key" column in the dungeon list (green check / red cross)
  and a "Key" tab with every step, its status and a map button (Scarlet
  Monastery, Scholomance, Upper Blackrock Spire, Dire Maul; shortcut keys
  for Blackrock Depths, Stratholme, Gnomeregan and Maraudon).
- Item tooltips: items the beta server does not send yet show name, quality
  and slot instead of "Retrieving item information".
- Boss list without the picture behind the "Bosses" heading.
- Settings: tabs can be moved left / right (per character, "Reset order");
  Dungeon list section rearranged; new option "Highest levels first".
- Quality of Life: preview pictures for Quest loot sparkles, Bags full
  helper and Quest XP on the experience bar (spyglass button).
- Less memory: tabs are built when first opened, dungeon data is no longer
  kept twice, the nearby Library Book check and the quest XP bar create far
  less garbage. New command /ofa mem.
- Map: Hillsbrad Foothills, Un'Goro Crater and Moonglade added.

5.3.0 - bags full helper
------------------------------------------------------------
- New Quality of Life option: Bags full helper - when loot does not fit, it
  shows what you would destroy and what you get, side by side; one click
  destroys the cheapest item and loots (also for quest objects and herbs
  without a loot window). Browse the cheapest items, "never suggest" button,
  /ofa cheapest. Quest items, library books, recipes, set pieces, profession
  tools and items without value are never suggested; items better than grey
  need a second click; loot worth less than everything in your bags shows
  "Not worth picking up".
- New Quality of Life option: Quest loot sparkles.
- Social: own switches for group invites, keyword invites and duels; while
  off, OneForAll does nothing with them.
- Quality of Life tab in three columns (shorter page); the right column is
  no longer cut off.

5.2.0 - Quality of Life
------------------------------------------------------------
- New Quality of Life tab; every helper is off until you switch it on and
  Shift pauses the automations:
  - Loot & vendors: auto loot (game setting), quicker loot, auto repair,
    sell junk.
  - Loot feed: looted items and money float up next to your character
    (minimum quality, money on/off, movable, test button).
  - Quests: accept and turn in automatically (reward choices stay manual).
  - Social: group invites and keyword invites (no one / friends / guild /
    friends & guild / everyone), duel filter, thanks for buffs
    (/ofa thanks shows the last buffs).
  - Tooltips: boss drops, who knows a recipe (you, your other characters,
    guild), the target of players.
  - Interface: farther camera zoom, free bag slots on the backpack, quest XP
    on the experience bar, durability warning, movable Blizzard windows, chat
    font size, copy chat button.
  - Unit frames: class colours for players, raid frame class colours and
    power bars (game settings).
- Professions: favourite recipes (star) and a Favorites list.
- Hunter Pets: no ability popup when your active pet already has the ability.
- Scroll bars hide when there is nothing to scroll.
- Money is shown as gold / silver / copper.

5.1.3 - Dark Silver
------------------------------------------------------------
- The Silver skin is now called Dark Silver.

5.1.2 - silver polish
------------------------------------------------------------
- Silver skin is a bit darker; scroll bars, check boxes, the search box,
  the window title and the resize grip are silver too.
- Sun / moon button next to the close button switches the skin.
- Library Books keep their coloured status markers in the Silver skin.
- Quest rewards without a slot line are centred; shorter profession cards
  ("13 known").

5.1.1 - skin switch fix
------------------------------------------------------------
- Switching the skin no longer causes a "protected function" error; the
  Reload button now reloads the interface.
- General: module cards without the Open button (click the card).

5.1.0 - silver skin
------------------------------------------------------------
- New Silver skin (Settings > Skin): grey frames, buttons and highlights,
  slightly dimmed pictures. Switching reloads the interface.
- Hunter Pets: "Where to tame" shows the 4 beasts closest to your level;
  "Show all" lists every known beast of the family.
- Hunter Pets: no pet ability popups during the taming quest (Taming Rod in
  your bags) or before level 10.
- Dungeons: "-" instead of "0 / 0" when no quest applies to you.
- Mage Scrolls removed completely.

5.0.0 - new look
------------------------------------------------------------
- New design for every tab: ornate gold window frame, title bands with
  emblems and banner art, new buttons and tabs, framed panels, rounded rows
  with gold hover and selection, ornate dividers, small-caps headers.
- New panorama artwork for all 14 dungeons (thumbnails, detail header and
  boss backdrops) and new boss portrait frames.
- Dungeons: sortable list, level bracket bands, faction crests, boss level
  always shown ("?" until a Forever-only boss has been targeted once),
  recipe drops start collapsed.
- Library Books: set bands with per-set counter, gem status markers,
  rewards popup with correct item colours.
- Professions: faster recipe list, search with clear button, gem markers,
  rounded guild / player boxes, Merchant's Favor amount in the navigation.
- Talent Trees: two presets per class with Save and Reset (with
  confirmation), class crests, new talent buttons.
- Hunter Pets: new family page (portrait, diet, role, special trait,
  modifiers, abilities, where to tame) and new ability page.
- General and Settings redesigned; "Only dungeons for my level" and
  "Nearby book alerts" are in the Settings.
- The window stays above other addons' frames; popups show above it.
- Mage Scrolls tab removed for now.

4.19.0 - new dungeons and recipe drops
------------------------------------------------------------
- New dungeons: Razorfen Kraul and Scarlet Monastery: Library (bosses, loot,
  quests, quest chains and map buttons).
- Dungeon loot: bosses list the recipes they can drop, with the yellow / green
  / blue checks; click a recipe to open it in Professions (can be turned off
  in the Settings).
- All recipes: about 600 more recipes now show where they drop or who sells
  them.
- New version notice: a short yellow note in the chat when another OneForAll
  user has a newer version (can be turned off in the Settings).
- The two welcome lines at login are gone.

4.18.6 - zone language
------------------------------------------------------------
- All recipes: the zone of other OneForAll users is shown in your own client
  language (players need 4.18.6 or newer).

4.18.5 - required level
------------------------------------------------------------
- All recipes: the character level needed to use the crafted item is shown
  ("L51" in the list, "Requires level 51" in the details; red if too low).

4.18.4 - rarity bar
------------------------------------------------------------
- All recipes: a coloured bar on each row shows the rarity of the crafted item.

4.18.3 - player line
------------------------------------------------------------
- All recipes: players are shown as "Name, lvl 23 Priest - Zone".

4.18.2 - level and class
------------------------------------------------------------
- All recipes: level and class are shown next to guild members and other
  OneForAll users who know a recipe (other users need 4.18.2 or newer).

4.18.1 - fix known recipes
------------------------------------------------------------
- All recipes: recipes you have not learned yet were sometimes marked as known
  (yellow check). Only learned recipes count now; wrong entries are removed
  automatically. /ofa profscan shows more details.
- All recipes: the list no longer jumps back to the top while you scroll
  (e.g. after a skill-up).

4.18.0 - professions & more
------------------------------------------------------------
- Professions: "All recipes" for every profession (where to learn, skill
  levels, reagents, sources with map buttons), who knows a recipe (guild /
  other OneForAll users online, with zone and Whisper), new Overview and
  Merchant's Favor pages, camping object icons.
- Hunter Pets tab available for every class.
- Shift-click links items and recipes in chat.
- Redesigned Settings page with banner; "Noteworthy changes" popup.
- Many fixes and layout improvements (see the beta entries below).

4.18.0-beta27 - settings banner
------------------------------------------------------------
- Settings: new banner artwork, slightly more compact layout.

4.18.0-beta26 - settings layout
------------------------------------------------------------
- Settings page redesigned: tidy sections with icons and a short description
  under every option; new "Noteworthy changes" button.

4.18.0-beta25 - own character without guild
------------------------------------------------------------
- All recipes: your current character is no longer listed under other
  OneForAll users when it is not in a guild.

4.18.0-beta24 - Hunter Pets for everyone
------------------------------------------------------------
- The Hunter Pets tab is shown for every class (can still be hidden in the
  settings); the pet ability alert stays hunter-only.
- Noteworthy changes: "Open Hunter Pets" for every class.

4.18.0-beta23 - popup text
------------------------------------------------------------
- Noteworthy changes: shorter text.

4.18.0-beta22 - popup for all classes
------------------------------------------------------------
- Noteworthy changes: the Hunter Pets part is shown to every class (marked
  "Hunters only"); the Open button only for hunters.

4.18.0-beta21 - noteworthy changes popup
------------------------------------------------------------
- New "Noteworthy changes" popup after logging in with a new version (once per
  account); /ofa news shows it again.

4.18.0-beta20 - Merchant's Favor page
------------------------------------------------------------
- Professions: Merchant's Favor has its own page in the left menu (your
  Favor, Favor recipes per profession, how to earn Favor). Inside a profession
  the Merchant's Favor tab shows its recipes directly.

4.18.0-beta19 - characters with the same first name
------------------------------------------------------------
- All recipes: characters are told apart by their full name (first name and
  surname from the guild roster), so your own characters that share a first
  name show up with their own recipes (green check).

4.18.0-beta18 - alts fix
------------------------------------------------------------
- All recipes: recipes of your other characters in the guild show the green
  check again (guild names with a surname are matched correctly).

4.18.0-beta17 - not learned professions
------------------------------------------------------------
- All recipes: professions your character has not learned say so; the
  "open your profession window" hint only shows for learned professions.

4.18.0-beta16 - header tweak
------------------------------------------------------------
- All recipes: the "open your profession window" hint sits under the legend.

4.18.0-beta15 - all professions
------------------------------------------------------------
- All recipes now for every profession: Alchemy, Blacksmithing, Enchanting
  (incl. enchants), Engineering, Leatherworking, Tailoring, Cooking and
  First Aid (new in the menu).
- Profession icon next to the recipe list title.
- Overview: "Others" heading; left menu icons no longer overlap the text.

4.18.0-beta14 - professions overview
------------------------------------------------------------
- Professions: new Overview start page with your professions (skill and known
  recipes) and tiles for all professions, Camping Buffs and Merchant's Favor.
- Profession icons in the left menu; Camping Buffs moved to the bottom.
- Camping Buffs: item icons for every camping object (shift-click links it).

4.18.0-beta13 - blue check online only
------------------------------------------------------------
- All recipes: the blue check only shows while another OneForAll user who
  knows the recipe is online; the legend says so.

4.18.0-beta12 - online players
------------------------------------------------------------
- All recipes: other OneForAll users are only listed while they are online.
  "Show offline" only applies to guild members.

4.18.0-beta11 - legend
------------------------------------------------------------
- All recipes: small legend for the check colours; the lists of guild members
  and other players who know a recipe are highlighted.

4.18.0-beta10 - layout tweaks
------------------------------------------------------------
- All recipes: sorted by level from top to bottom; more space above the list
  of players who know a recipe.
- Professions: shorter header; the Merchant's Favor amount is shown in the
  Merchant's Favor tab.
- Settings: dungeon level brackets listed one per row.

4.18.0-beta9 - recipe checks, Favor tabs
------------------------------------------------------------
- All recipes: the yellow / green / blue checks are shown side by side.
- "Show offline" moved next to the list of players who know a recipe.
- Your own character is recognised more reliably (no longer listed).
- Professions: "Merchant's Favor" now holds two tabs, Recipes and Guide.

4.18.0-beta8 - show offline
------------------------------------------------------------
- All recipes: your own character is no longer listed under guild members.
- New "Show offline" option (off by default) to also list guild members and
  players who are offline.

4.18.0-beta7 - who knows a recipe
------------------------------------------------------------
- All recipes: checks show who knows a recipe - yellow = you, green = a guild
  member, blue = another OneForAll user. Recipes are shared over the guild
  channel and a hidden chat channel (can be turned off in the settings). Your
  own characters in the same guild count too. The recipe details list who
  knows it, with their current zone (and whether they are in a raid or
  dungeon) and a Whisper button.
- Removed the "Learnable now" filter.

4.18.0-beta5 - fixes
------------------------------------------------------------
- Fixed a Lua error when shift-clicking items into the chat.
- Item info (names, links, reagent counts) now also works with the newer item
  API of the client.
- All recipes only shows faction-specific recipes (e.g. Faction Banner) for
  your own faction.

4.18.0-beta4 - recipe detection, chat link fix
------------------------------------------------------------
- All recipes: known recipes and skill are now read from the new profession
  window and profession book. /ofa profscan shows what was found.
- Shift-click links now always use the game's own item link, so the message
  is actually sent.

4.18.0-beta3 - Tailoring, chat links
------------------------------------------------------------
- All recipes now also for Tailoring.
- Shift-click links items in chat: dungeon loot, quest rewards, book rewards,
  recipes and reagents.

4.18.0-beta2 - professions menu
------------------------------------------------------------
- Professions: left menu only has Camping Buffs and the professions. Inside a
  profession: "All recipes", "Merchant's Favor" and "Favor guide".
- The selected menu entry and sub-page are clearly highlighted.
- All recipes: reagent names shown; "Learned from" says Vendor (with faction),
  World drop / Drop, Quest reward or Merchant's Favor.

4.18.0-beta1 - all recipes (Alchemy)
------------------------------------------------------------
- Professions: new "All recipes (beta)" section, starting with Alchemy. Every
  recipe from the WoW Forever client data (not only Merchant's Favor): skill
  colors for your current skill, reagents with how many you have, where the
  recipe comes from (trainer, vendor, drop, quest, Favor) with Map buttons.
  Filters All / Missing / Learnable now and a search box. Known recipes are
  read when you open your profession window.

4.17.7 - fix
------------------------------------------------------------
- Fixed a Lua error when a pet ability alert appeared.

4.17.6 - target button
------------------------------------------------------------
- Pet ability alert: "Mark" (raid marking is protected on this client and caused
  an error) is replaced by "Target", which targets the beast. Not available
  while in combat.

4.17.5 - pet alert buttons
------------------------------------------------------------
- Pet ability alert: "Mark" puts a skull on the beast, "Snooze 15 min" pauses
  pet alerts, "Ignore <ability>" excludes the ability. No map/dismiss buttons
  (close with the X).
- Alerts stay open for 20 seconds before closing automatically.

4.17.4 - portrait frames
------------------------------------------------------------
- Boss portraits get a gold frame that runs into a point at the bottom right
  (like the player frame); the large portrait shows the boss level in a badge.
- Hunter Pets: round gold ring for families, action-bar style rounded icon frame for abilities.

4.17.3 - pet alert exceptions
------------------------------------------------------------
- Pet ability alerts: abilities can be excluded. Untick "Alert for this ability"
  in Hunter Pets > Abilities, or click "Ignore <ability>" on the alert itself.
  Cower is excluded by default. Excluded abilities show "(no alert)" in the list.

4.17.2 - round pet portraits
------------------------------------------------------------
- Hunter Pets: the large family and ability portraits are round, like the boss
  portraits.

4.17.1 - layout polish
------------------------------------------------------------
- Boss list: the level line lines up exactly under the boss name.
- Hunter Pets: families and abilities show a large portrait/icon with the name
  next to it.

4.17.0 - dungeon quality of life
------------------------------------------------------------
- Opening the window inside a dungeon jumps straight to that dungeon's bosses
  and loot.
- Boss level shown below the boss name and in the boss header. Levels of
  Forever-only bosses are learned when you target or mouse over them.
- Boss portraits that the game resolved once are saved, so they no longer
  disappear in later sessions.

4.16.4 - abilities list
------------------------------------------------------------
- Hunter Pets > Abilities only lists abilities learned from tameable beasts.
  Pet Trainer skills (Growl, resistances, Great Stamina, ...) are shown on
  each family instead.

4.16.3 - logo centered
------------------------------------------------------------
- Minimap logo: the "1" is now exactly centered.

4.16.2 - bolder logo
------------------------------------------------------------
- Minimap logo: thicker "1" that stays readable at minimap size.

4.16.1 - new logo, settings groups
------------------------------------------------------------
- New minimap button logo (golden "1"); also used as the icon in the addon list.
- Settings: popups and alerts have their own "Popups & alerts" group.

4.16.0 - pet ability alerts
------------------------------------------------------------
- Hunter: alert when a beast nearby (nameplate, target or mouseover) teaches a
  higher ability rank than you know, for an ability your active or stabled pet's
  family can learn. Same popup style as the library book alerts, with a Map
  button. Toggle: Settings > General > "Pet ability alerts (Hunter)".

4.15.0 - your pets
------------------------------------------------------------
- Hunter Pets: the family of your active pet is marked green ("Your pet") and
  selected when you open the tab; the detail view shows its name and level.
- Stabled pets are marked blue ("In stable"). The list is updated whenever you
  open the stable master window.

4.14.2 - pet ability scan fix
------------------------------------------------------------
- Hunter Pets: known ranks are read from the pet spellbook with the client's
  modern spellbook API, so your pet's abilities are marked green. Also scanned
  when you open the tab. /ofa petscan prints what was found.

4.14.1 - quest share fix
------------------------------------------------------------
- Fixed: the quest share window kept reopening in dungeons and ignored the
  "open automatically" setting. It now opens automatically at most once per
  dungeon visit (and again only when a new member joins), never when the option
  is off, and stays closed after you close it. /ofa share still opens it.
- Group members only send their quest status when it actually changes.

4.14.0 - known pet abilities
------------------------------------------------------------
- Hunter Pets: OneForAll reads your known pet ability ranks from the Beast
  Training window (open it once) and from your pet's spellbook. Learned ranks
  are green; knowing a higher rank also marks all lower ranks. The ability list
  shows e.g. "3/8 learned".
- Abilities: each rank is a row you can click to fold out the beasts that teach
  it, instead of one long list.

4.13.2 - fix
------------------------------------------------------------
- Fixed a Lua error when scaling the window with the corner grip.

4.13.1 - clickable section headers
------------------------------------------------------------
- Dungeons (level brackets) and Library Books (sets): click anywhere on the
  header bar to collapse or expand it, not only on the +/- button.

4.13.0 - adjustable window height
------------------------------------------------------------
- New grip in the middle of the bottom edge: drag it to make the window taller
  (lists and detail panes show more rows). The corner grip still scales the
  whole window. The height is saved; /ofa scale resets size, height and position.

4.12.7 - compact quest details
------------------------------------------------------------
- Quest details hide the "Prerequisite" and "Turn in" lines when there is no
  information (the quest chain already shows required steps).

4.12.6 - reward layout
------------------------------------------------------------
- Follow-up rewards and the XP/reputation line under quest rewards are
  left-aligned like the other rewards (they were centered).

4.12.5 - steady tooltip position
------------------------------------------------------------
- Item tooltips open right after the item name (or left of the row if there is
  no room), no matter where the mouse enters the row.

4.12.4 - comparison tooltips
------------------------------------------------------------
- The game's "Equipped" comparison tooltips stay on the same side as the loot
  tooltip (right of the mouse, or left if there is no room), so they no longer
  cover the loot list.

4.12.3 - tooltip position
------------------------------------------------------------
- Item tooltips (boss loot, trash, quest rewards) open next to the mouse instead
  of at the far right edge of the row.

4.12.2 - pet ability fixes
------------------------------------------------------------
- Hunter Pets: Forever-only abilities without a known teaching beast show one
  note instead of repeating it for every rank.
- Fixed missing closing bracket on dungeon beasts, e.g. "Scarlet Monastery (Dungeon)".

4.12.1 - quest chain progress
------------------------------------------------------------
- Dungeon quest list: a quest counts as "In log" while you are on an earlier
  step of its chain and shows the step, e.g. "Chain 1/3".
- Quest chain: the last row is labelled "Dungeon quest" instead of "Current".

4.12.0 - Forever loot, Dalaran quests and Forever pets
------------------------------------------------------------
- Dungeon loot updated from wowtbc.gg (Forever loot tables): The Stockade bosses
  now have their real Forever drops instead of "world drops only"; more drops for
  Excavation Site, Blackfathom Deeps, Shadowfang Keep and Gnomeregan; trash loot
  lists for Stockade, BFD, SFK, Deadmines, Gnomeregan and SM Graveyard; event
  bosses Sever (SFK) and Scorn (SM Graveyard).
- City of Dalaran: 5 quests (A Green Sample, Power Overwhelming, The Grave Knight,
  Source of Power, Opportunistic Education); "Mana Elemental" is Arcanic Enigma.
- New quests: Baron Aquanis (BFD, Horde), In Nightmares (WC, both factions),
  The Test of Righteousness (Paladin, DM/SFK/BFD).
- Class-only dungeon quests (e.g. The Orb of Soran'ruk) are only counted for
  that class.
- Hunter Pets: data switched to WoW Forever (wow-petopia.com/forever). New family
  abilities (e.g. Dismember, Savage Rend, Web, Swipe, Pinch), Demoralizing
  Screech replaces Screech, new trainer passives Faster/Slower Attack, Owls are
  now Birds of Prey, Core Hounds and Foxes added. Every rank shows its effect.
- Dungeons: quests in shared-name chains (e.g. Hidden Enemies) are matched by
  quest ID, so the wrong chain step no longer shows as "In log"; the quest chain
  marks the step you currently have.

4.11.0 - level-30 beta update
------------------------------------------------------------
- Excavation Site: 14 quests (Alliance and Horde, incl. chains and rewards) and
  the first recorded boss drops. Some quest givers are not on Wowhead yet.
- Library Books: the rewards window shows all three reward tiers with the real
  items and tooltips (10 books: necklace, 20: ring, new third tier: bow / shield /
  off-hand). Values updated to the current beta (weaker necklaces, ilvl 35 rings).
- Professions: Merchant's Favor overview redesigned - steps, trade hub and the
  crate reward table fit on one page without the small scroll box.

4.10.5 - talent update (beta build 70170)
------------------------------------------------------------
- Talent trees updated to beta build 1.60.1.70170:
  Druid Feral: new Shifting Power and Improved Shifting Power, King of the Jungle
  removed, Shredding Attacks and Predatory Instincts moved.
  Mage: Hot Streak renamed to Heating Up. Warlock: Soul Harvesting renamed to Soul Harvest.

4.10.4 - Hunter Pets banner
------------------------------------------------------------
- The Hunter Pets tab has its own banner.

4.10.3 - map pin
------------------------------------------------------------
- Map pin is now the plain gold variant and a bit smaller.

4.10.2 - title and map pin
------------------------------------------------------------
- Window title shows "made by Smoergi".
- New, simpler map pin (dark with gold rim) that matches the addon style.

4.10.1 - quest share test
------------------------------------------------------------
- /ofa share test opens the quest share popup with two made-up group members,
  outside a group too. Share only shows a local preview of the emote and fakes
  the replies; nothing is shared or posted.

4.10.0 - Settings tab
------------------------------------------------------------
- New Settings tab (gear icon, far left; the window still opens on General):
  shown tabs, dungeon level brackets to show/hide, welcome message, nearby book
  alerts, quest share popup and emote, window reset.
- Welcome message now also invites feedback on CurseForge; can be turned off.
- Tab checkboxes moved from the General tab to Settings.

4.9.0 - Hunter Pets tab
------------------------------------------------------------
- New tab "Hunter Pets" (shown by default on hunters):
  Families - diet, stat modifiers, learnable abilities and where to tame them;
  Abilities - every rank with pet level, training points and beasts that teach
  it (Map button); Rare Tames - notable rare/unique-looking pets.
- Data: Classic pet rules (no Forever pet changes known so far), compiled from
  wow-petopia.com/classic and Wowhead Classic, spawn points from QuestieDB.

4.8.0 - choose your tabs
------------------------------------------------------------
- Every module has a "Show tab" checkbox (now in the Settings tab). The choice is saved per
  character; hidden tabs disappear from the tab bar.
- Mage Scrolls is shown by default only on mages. /ofa tabs reset restores the
  defaults.

4.7.0 - quest sharing in dungeons
------------------------------------------------------------
- Inside a dungeon, a popup lists your shareable quests of that dungeon that a
  group member does not have yet and can take (level/faction checked). One click
  shares the quest and posts an emote, e.g.
  "Kaelin shares the quest "Crime and Punishment" with Anna (OneForAll addon)".
- The game's replies (accepted, already completed, not eligible, too far ...)
  are shown in the popup; players who completed a quest are not offered again.
- Group members with OneForAll exchange which dungeon quests they completed.
- /ofa share opens the popup manually; /ofa share off|on and
  /ofa share emote off|on change the settings (also as checkboxes in the popup).

4.6.3 - boss list width
------------------------------------------------------------
- Boss list now has the same width as the quest list, so switching between
  Bosses & Loot and Quests keeps the layout steady.

4.6.2 - dungeon art and boss list
------------------------------------------------------------
- Simpler thumbnails for Excavation Site, City of Dalaran, Gnomeregan and
  SM: Graveyard (closer to the style of the original dungeon images).
- Wider boss list in the dungeon view.

4.6.1 - talent tooltips
------------------------------------------------------------
- Talent tooltips show the description on the first hover: if the client has
  not loaded the talent's spell data yet, it is loaded and the tooltip redrawn.

4.6.0 - language-independent talent planner
------------------------------------------------------------
- Talent planner matches client talents by spell ID (new TalentSpellIDs.lua,
  read from build 70124 with /ofa talentdump) and only falls back to names.
  It now uses the fixed layouts on German, French, Spanish and other clients too.
- All 466 reference talents of the 9 classes were confirmed against the client.

4.5.1 - talent dump
------------------------------------------------------------
- New command /ofa talentdump: saves node, entry and spell IDs of all talents of
  all classes (preparation for a language-independent talent planner).

4.5.0 - scalable window
------------------------------------------------------------
- The main window can be resized with the grip in the bottom-right corner
  (60-140 %). Size and position are remembered; /ofa scale resets them,
  /ofa scale 80 sets a size directly.
- Four Forever enchanting recipes now require skill 300 (Classic cap).

4.4.1 - dungeon list polish
------------------------------------------------------------
- Zone column and dungeon header show only the zone; coordinates are left to
  the Map button.
- Boss loot tooltips refresh automatically once the client has loaded the item
  (no more stuck "Retrieving item information").
- Stockade bosses without own loot say so; Kam's Walking Stick added.
- City of Dalaran bosses use fixed model IDs for their portraits.

4.4.0 - dungeons up to level 38
------------------------------------------------------------
- New dungeons: The Stockade, Gnomeregan, Scarlet Monastery: Graveyard (Forever
  quests and boss loot from Wowhead Forever), Excavation Site: Wetlands and City of
  Dalaran (boss lists only - loot and quests are not published yet).
- Dungeon list is grouped into collapsible level brackets like Library Books,
  with an "Only dungeons for my level" filter and level colors for your character.
- Level ranges now use the WoW Forever recommended ranges for all dungeons.
- Quest chains: optional lead-in quests are shown as "Optional" and no longer
  block a quest. Fixed Researching the Corruption, Returning the Lost Satchel,
  Allegiance to the Old Gods and Destruction in Deadmines (which blocked itself).
- Gnomeregan Horde quests count for Horde characters.
- Dungeon data split into one file per dungeon.

4.3.1 - talent data, per-character books, map pin check
------------------------------------------------------------
- Talent planner: all 9 classes now use fixed layouts from talentsforever.com
  (build 1.60.1.70009) for tree, row, column and prerequisites instead of guessing
  them from client coordinates. The client still provides icons, tooltips and IDs.
  If client talents are missing from the data, the footer says so; if nothing
  matches (e.g. a localized client), the old estimated layout is used.
- Talent planner: same-row prerequisites are drawn correctly; trees that use only
  three columns are centered; connection lines are reused instead of recreated.
- Library Books: turn-ins, manual marks and the bank scan are now stored per
  character. Existing turn-ins/marks move to the first character that logs in;
  the bank status of each character is rebuilt on its next bank visit.
- Minimap button uses the standard LibDBIcon size, matching other buttons.
- Talent trees: equal horizontal and vertical spacing; class list moved down.
- Removed the caption text from all banners and the profession-data status line.
- Map pins: all dungeon quest starts re-checked against Wowhead (Wilder
  Thistlenettle and Shoni used retail coordinates, "The Glowing Shard" pointed to
  Thunder Bluff, several small corrections); added Destruction in Deadmines.
  Ruins of Lordaeron entrance now uses the Undercity map.
- New command /ofa where.

4.2.0 - UI split into modules
-----------------------------
- The 2,400-line UI.lua is split into one file per tab under UI/ plus shared
  widgets and the main window. No visible changes in game.
- Tabs register themselves; the tab bar is built from that registry.

4.1.2 - code cleanup / bug fixes
--------------------------------
- Fixed: Redridge Mountains was shown as "Contested" (territory table held a map ID).
- Fixed: the golden world-map pin stayed visible when browsing to another zone.
  It is now only shown on the map it was placed on.
- Fixed: the "Quests x / y" column in the dungeon list was only calculated once
  per session. It now updates whenever the list is shown; quest states in the
  dungeon detail view also refresh when the window is reopened.
- Fixed: Blackfathom Deeps "Map" button on non-English clients (added explicit
  map IDs for Ashenvale and other starting zones/cities instead of relying on
  English zone-name matching).
- Performance: UI rows are now created once and reused. Previously every click
  in Dungeons, Professions and Camping Buffs created a new set of frames that
  WoW can never free, so memory kept growing the longer the window was used.
- Performance: the window no longer refreshes itself on bag updates while closed.
- Talent planner: plans are now saved per class (SavedVariables) and survive
  /reload and logout. Removed a duplicate preview call per click.
- Removed dead code: merchant recipe scanning (all 310 recipes ship with
  embedded IDs), unused helper functions and variables.

3.2.0 - Talent Trees data note
------------------------------
Tree structure, row gating and prerequisite behavior are cross-checked against talentsforever.com, whose published JSON is sourced from the WoW Forever beta client. Live client APIs remain the primary runtime source for talent icons and tooltips.

3.1.3
-----
- Reworked Talent Tree buttons to use a Blizzard-style Quickslot frame with rounded/dark corners, inset icons and a subtle shadow/depth effect.
- Increased talent icon breathing room while preserving the four-column planner layout.
- Updated prerequisite connection placement for the new button geometry.
- Fixed the Hunter tree splitter to prefer client-provided tree/subtree membership instead of incorrectly treating local talent X coordinates as three specialization columns.
- Added safer fallback grouping when a class exposes more than three client tree groups.

3.1.2
-----
- Talent rows now unlock in 5-point steps and unavailable talents are visibly greyed out.
- Planner level now follows spent talent points: first point = level 10, up to level 60 at 51 points.
- Added visible prerequisite connection lines using the live client talent graph; linked talents require their prerequisite at full rank.
- Prevented point removal when it would invalidate a lower-row or dependent talent.
- Centered the per-tree point summary in the footer, moved the Left + / Right - hint to the right edge, and removed the redundant Total value.

3.1.1
-----
- Enlarged and rebuilt the golden world-map marker and removed the old glow layer that could render as a dark edge.
- Reworked Talent Trees into a compact four-column grid per specialization to reduce excess spacing.
- Added collision handling for malformed/duplicate client talent coordinates, including Hunter/Priest fallbacks.
- Fixed planner interaction so left-click adds ranks and right-click removes ranks without depending on the client accepting a synthetic preview loadout.
- Replaced the stretched Quickslot overlay with clean 1px borders and cropped talent textures to remove the inner dark rectangle effect.
- Kept the planner-only safety model: no real character talents are changed.

2.9.0 - visual preview
----------------------
- Bundled lightweight dungeon artwork thumbnails for the starter-dungeon list and detail headers.
- Decorative beta-content art strip on the General page.
- Profession icons in Camping Buffs headers.
All bundled artwork is stored locally in OneForAll/Assets; no external addon is required.

2.8.4 - dungeon quality pass
----------------------------
- Rebuilt the embedded dungeon boss/loot and quest/reward data.
- Boss loot and quest rewards now use explicit item IDs wherever provided by that data set.
- Dungeon overview now mirrors Library Books: Dungeon, Level, Territory, Zone / Coordinates, Quests, Actions.
- Quest list owns its own scroll position; selecting a quest no longer jumps the list to the top.
- Quest details now include objective, turn-in, notes, item rewards and follow-up reward items when present.

2.7.0
-----
Completed the starter-dungeon boss loot tables used by the Dungeon browser.

Highlights:
- Ragefire Chasm: completed Taragaman and Jergosh loot sets.
- The Deadmines: completed the main boss loot sets, split Sneed and Sneed's Shredder, and added Miner Johnson.
- Wailing Caverns: completed the listed boss and rare loot sets.
- Shadowfang Keep: completed the main boss loot sets and added Deathsworn Captain.
- Blackfathom Deeps: completed the listed boss loot sets and added Lorgus Jett.
- Boss detail pane now shows the number of known loot items for the selected boss.

Dungeon data is beta information and can change during WoW Forever testing.

Version 2.7.0 data/UI follow-up
-------------------------------
- Re-audited starter-dungeon boss loot against current Forever beta/community records.
- Corrected Wailing Caverns and Blackfathom Deeps loot counts where older rows were incomplete or over-inclusive.
- Dungeon quest rewards now use the actual item-quality color reported by the client instead of a hard-coded green label.
- Mage Comprehension scroll hover text now uses the native item tooltip where possible and appends requirements and deciphering guidance.
- Added a Camping Buffs page under Professions with profession-related camping objects, skill requirements, effects and reagents.
- The General page always shows the current addon version from the TOC metadata.


2.7.0 highlights:
- Dungeon overview now uses a compact Library Books-style table with Map buttons.
- Dungeon quests can be filtered by Alliance or Horde and use a boss-style master/detail layout.
- Expanded current-known boss loot and quest rewards.
- Mage scroll tooltips explain Comprehension and deciphering.
- Camping Buffs include gathering and secondary professions such as Fishing and First Aid.

2.5.1
-----
Added a Dungeons tab focused on the early Forever beta dungeon bracket.
Included: The Hall of Thanes, Ragefire Chasm, Ruins of Lordaeron, The Deadmines,
Wailing Caverns, Shadowfang Keep and Blackfathom Deeps.

Each dungeon has:
- level range and faction/area context
- boss list
- current-known / beta loot list
- quest list with required level, faction/class restrictions, pickup location,
  prerequisites and notable rewards where verified
- automatic highlight when a listed quest is currently in your quest log

Dungeon and loot data is beta information and may change during WoW Forever testing.

2.4.0
-----
- Library Books tracker with bag/bank state, confirmed turn-ins, map markers and nearby alerts.
- Mage Comprehension scroll overview.
- Merchant's Favor overview and profession recipe browser with embedded WoW Forever
  recipe IDs, craft spell IDs, crafted item IDs, reagent IDs and enchant metadata.
