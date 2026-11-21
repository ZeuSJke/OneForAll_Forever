local _, FLT = ...

-- Hand-made additions to Data/DungeonMaps.lua (that file is generated; these stay when it is built again).
-- Read off another addon's map pictures in the user's screenshots (user 20.11.2026 23:45: "vielleicht kannst du mit den bildern
-- was anfangen und den eingang oder einen boss noch eintragen"): only the positions (game facts anyone can see in the game),
-- converted to our canvas yards by fitting its map onto ours with the bosses both show (Alcaz Prison about 2 yards, Sunken
-- Temple about 8, The Drowned City and Krol'dok about 60 - that map is drawn by hand). A position seen in the game wins.
-- entrance = { u, v }; marks = { { text, u, v, title, tip } } - a plain number on the map (no symbol), title / tip are English
-- texts translated where shown.
local function N(t) return t end -- (marks an English text for tools/locale/extract.py)
local EXTRA = {
  ["Alcaz Prison"] = { entrance = { 14218.6, 25863.7 } },
  ["The Drowned City"] = { entrance = { 14886.1, 30352 } },
  ["Krol'dok Stronghold"] = { entrance = { 20696, 24736.5 } },
  -- the six Atal'ai statues around Atal'alarion's pit, in the order they must be used (1 south, 2 north, 3 south-west,
  -- 4 south-east, 5 north-west, 6 north-east)
  ["The Temple of Atal'Hakkar"] = { marks = {
    { "1", 16971.1, 17586.8 }, { "2", 16961.7, 17459.9 }, { "3", 16915.7, 17560 },
    { "4", 17022, 17552.1 }, { "5", 16911.2, 17498.8 }, { "6", 17017.4, 17491 },
    title = N"Atal'ai statue %s", tip = N"Use the six statues in this order (1 to 6) to summon Atal'alarion." } },
}
for name, e in pairs(EXTRA) do
  local m = FLT.DUNGEON_MAPS and FLT.DUNGEON_MAPS[name]
  if m then
    if e.entrance and not m.entrance then m.entrance = e.entrance end
    if e.marks then m.marks = e.marks end
  end
end
