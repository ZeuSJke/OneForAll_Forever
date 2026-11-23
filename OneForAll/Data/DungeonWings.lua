-- tools/dungeon-gen/wings.py (CMaNGOS classic-db creature spawns sorted into our Data/DungeonMaps.lua wing areas),
-- do not edit by hand. FLT.DUNGEON_WINGS[instance ID][npc ID] = the only wing (dungeon key) the creature lives in.
local _, FLT = ...
FLT.DUNGEON_WINGS = {
  [189] = { -- smarm, smcath, smgy, smlib
    -- smarm: Herod, Scarlet Soldier, Scarlet Evoker, Scarlet Guardsman, Scarlet Protector, Scarlet Conjuror
    [3975]="smarm", [4286]="smarm", [4289]="smarm", [4290]="smarm", [4292]="smarm", [4297]="smarm",
    -- smcath: Scarlet Commander Mograine, High Inquisitor Whitemane, Scarlet Sorcerer, Scarlet Wizard, Scarlet Centurion, Scarlet Champion, Scarlet Abbot, High Inquisitor Fairbanks
    [3976]="smcath", [3977]="smcath", [4294]="smcath", [4300]="smcath", [4301]="smcath", [4302]="smcath", [4303]="smcath", [4542]="smcath",
    -- smgy: Vorrel Sengutz, Interrogator Vishas, Scarlet Sentry, Scarlet Scryer, Scarlet Torturer, Unfettered Spirit, Bloodmage Thalnos, Anguished Dead, Haunting Phantasm, Suffering Victim
    [3981]="smgy", [3983]="smgy", [4283]="smgy", [4293]="smgy", [4306]="smgy", [4308]="smgy", [4543]="smgy", [6426]="smgy", [6427]="smgy", [6547]="smgy",
    -- smlib: Houndmaster Loksey, Scarlet Gallant, Scarlet Beastmaster, Scarlet Diviner, Scarlet Adept, Scarlet Tracking Hound, Arcanist Doan
    [3974]="smlib", [4287]="smlib", [4288]="smlib", [4291]="smlib", [4296]="smlib", [4304]="smlib", [6487]="smlib",
  },
  [229] = { -- lbrs, ubrs
    -- lbrs: Highlord Omokk, Spirestone Battle Mage, Spirestone Mystic, Spirestone Enforcer, Spirestone Reaver, Spirestone Ogre Magus, Spirestone Warlord, Spirestone Lord Magus, Spirestone Battle Lord, Spirestone Butcher, Shadow Hunter Vosh'gajin, War Master Voone, Smolderthorn Mystic, Smolderthorn Shadow Priest, Smolderthorn Headhunter, Firebrand Legionnaire, Firebrand Dreadweaver, Firebrand Pyromancer, Smolderthorn Shadow Hunter, Smolderthorn Witch Doctor, Smolderthorn Axe Thrower, Smolderthorn Berserker, Smolderthorn Seer, Overlord Wyrmthalak, Bloodaxe Veteran, Bannok Grimaxe, Bloodaxe Raider, Bloodaxe Evoker, Bloodaxe Worg, Spire Scorpid, Bloodaxe Warmonger, Bloodaxe Summoner, Ghok Bashguud, Quartermaster Zigris, Spire Scarab, Halycon, Bloodaxe Worg Pup, Bijou, Spire Spider, Spire Spiderling, Crystal Fang, Mother Smolderweb
    [9196]="lbrs", [9197]="lbrs", [9198]="lbrs", [9199]="lbrs", [9200]="lbrs", [9201]="lbrs", [9216]="lbrs", [9217]="lbrs", [9218]="lbrs", [9219]="lbrs",
    [9236]="lbrs", [9237]="lbrs", [9239]="lbrs", [9240]="lbrs", [9241]="lbrs", [9260]="lbrs", [9263]="lbrs", [9264]="lbrs", [9265]="lbrs", [9266]="lbrs",
    [9267]="lbrs", [9268]="lbrs", [9269]="lbrs", [9568]="lbrs", [9583]="lbrs", [9596]="lbrs", [9692]="lbrs", [9693]="lbrs", [9696]="lbrs", [9701]="lbrs",
    [9716]="lbrs", [9717]="lbrs", [9718]="lbrs", [9736]="lbrs", [10177]="lbrs", [10220]="lbrs", [10221]="lbrs", [10257]="lbrs", [10374]="lbrs", [10375]="lbrs",
    [10376]="lbrs", [10596]="lbrs",
    -- ubrs: Rage Talon Dragonspawn, Pyroguard Emberseer, Blackhand Dreadweaver, Blackhand Summoner, Blackhand Veteran, Rage Talon Flamescale, Scarshield Infiltrator, Blackhand Incarcerator, General Drakkisath, The Beast, Jed Runewatcher, Awbee, Blackhand Thug, Warosh, Chromatic Elite Guard, Goraluk Anvilcrack, Elder Stonefort
    [9096]="ubrs", [9816]="ubrs", [9817]="ubrs", [9818]="ubrs", [9819]="ubrs", [10083]="ubrs", [10299]="ubrs", [10316]="ubrs", [10363]="ubrs", [10430]="ubrs",
    [10509]="ubrs", [10740]="ubrs", [10762]="ubrs", [10799]="ubrs", [10814]="ubrs", [10899]="ubrs", [15560]="ubrs",
  },
  [429] = { -- dme, dmn, dmw
    -- dme: Wildspawn Rogue, Wildspawn Trickster, Wildspawn Hellcaller, Warpwood Guardian, Warpwood Stomper, Zevrim Thornhoof, Old Ironbark, Alzzin the Wildshaper, Fel Lash, Wildspawn Imp, Hydrospawn, Lethtendris, Pimgib, Pusillin
    [11452]="dme", [11453]="dme", [11457]="dme", [11461]="dme", [11465]="dme", [11490]="dme", [11491]="dme", [11492]="dme", [13197]="dme", [13276]="dme",
    [13280]="dme", [14327]="dme", [14349]="dme", [14354]="dme",
    -- dmn: Gordok Captain, Gordok Spirit, Gordok Warlock, Gordok Reaver, King Gordok, Gordok Mastiff, Carrion Swarmer, Guard Fengus, Stomper Kreeg, Guard Slip'kik, Cho'Rush the Observer, Captain Kromcrush, Guard Mol'dar, Knot Thimblejack, Wandering Eye of Kilrogg
    [11445]="dmn", [11446]="dmn", [11448]="dmn", [11450]="dmn", [11501]="dmn", [13036]="dmn", [13160]="dmn", [14321]="dmn", [14322]="dmn", [14323]="dmn",
    [14324]="dmn", [14325]="dmn", [14326]="dmn", [14338]="dmn", [14386]="dmn",
    -- dmw: Tsu'zee, Eldreth Seether, Eldreth Sorcerer, Eldreth Apparition, Eldreth Spirit, Eldreth Spectre, Eldreth Phantasm, Skeletal Highborne, Rotting Highborne, Prince Tortheldrin, Magister Kalendris, Illyanna Ravenoak, Tendris Warpwood, Immol'thar, Ferra, Lorekeeper Lydros, Shen'dralar Zealot, Shen'dralar Provisioner, Lorekeeper Javon, Lorekeeper Mykos, Lorekeeper Kildrath, Eldreth Darter, Revanchion, Falrin Treeshaper
    [11467]="dmw", [11469]="dmw", [11470]="dmw", [11471]="dmw", [11472]="dmw", [11473]="dmw", [11475]="dmw", [11476]="dmw", [11477]="dmw", [11486]="dmw",
    [11487]="dmw", [11488]="dmw", [11489]="dmw", [11496]="dmw", [14308]="dmw", [14368]="dmw", [14369]="dmw", [14371]="dmw", [14381]="dmw", [14382]="dmw",
    [14383]="dmw", [14398]="dmw", [14690]="dmw", [16032]="dmw",
  },
}
