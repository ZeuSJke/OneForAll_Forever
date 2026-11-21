local _, FLT = ...
-- What disenchanting gives, by quality and item level (6.2.6-beta33, user 12.11.: "disenchant value" in the tooltip).
-- Written by us from the well-known Classic disenchant chances (green: mostly dust from armor, mostly essences from
-- weapons, rarely a shard; blue: a shard; purple: shards or a Nexus Crystal). An estimate - WoW Forever may differ.
-- FLT.DISENCHANT[quality] = list of { highest item level, armor = parts, weapon = parts (nil = as armor) },
-- parts = { { itemID, chance, min, max }, ... }
local DUST = { 10940, 10940, 10940, 11083, 11083, 11137, 11137, 11176, 11176, 16204, 16204 }
local ESS = { 10938, 10939, 10998, 11082, 11134, 11135, 11174, 11175, 16202, 16203, 16203 }
local SHARD = { nil, 10978, 10978, 11084, 11138, 11139, 11177, 11178, 14343, 14344, 14344 }
local DMIN = { 1, 2, 4, 1, 2, 1, 2, 1, 2, 1, 2 }
local DMAX = { 2, 3, 6, 2, 5, 2, 5, 2, 5, 2, 5 }
local EMIN = { 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2 }
local EMAX = { 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 3 }
local TOP = { 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 999 }
local green = {}
for i, top in ipairs(TOP) do
  local s = SHARD[i]
  local dA, eA = s and 0.75 or 0.8, 0.2
  local dW, eW = 0.2, s and 0.75 or 0.8
  local armor = { { DUST[i], dA, DMIN[i], DMAX[i] }, { ESS[i], eA, EMIN[i], EMAX[i] } }
  local weapon = { { DUST[i], dW, DMIN[i], DMAX[i] }, { ESS[i], eW, EMIN[i], EMAX[i] } }
  if s then armor[3] = { s, 0.05, 1, 1 }; weapon[3] = { s, 0.05, 1, 1 } end
  green[i] = { top, armor = armor, weapon = weapon }
end
FLT.DISENCHANT = {
  [2] = green,
  [3] = {
    { 25, armor = { { 10978, 1, 1, 1 } } }, { 30, armor = { { 11084, 1, 1, 1 } } },
    { 35, armor = { { 11138, 1, 1, 1 } } }, { 40, armor = { { 11139, 1, 1, 1 } } },
    { 45, armor = { { 11177, 1, 1, 1 } } }, { 50, armor = { { 11178, 1, 1, 1 } } },
    { 55, armor = { { 14343, 1, 1, 1 } } }, { 999, armor = { { 14344, 0.995, 1, 1 }, { 20725, 0.005, 1, 1 } } },
  },
  [4] = {
    { 45, armor = { { 11177, 1, 2, 4 } } }, { 50, armor = { { 11178, 1, 2, 4 } } },
    { 55, armor = { { 14344, 1, 2, 4 } } }, { 60, armor = { { 20725, 1, 1, 1 } } },
    { 999, armor = { { 20725, 1, 1, 2 } } },
  },
}
