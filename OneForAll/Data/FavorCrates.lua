local _, FLT = ...
-- tools/favor-crates/crates.py - generated, do not edit by hand. Waylaid Crates: item, tier (1-4), gathered (g) or
-- crafted (c), Merchant's Favor (players' reports, Artisan expected), bundles = { { material item, count } } (any ONE
-- bundle fills the crate; Wowhead Forever tooltips).
FLT.FAVOR_CRATES = {
  { id = 248682, tier = 1, kind = "g", favor = 5, bundles = { {2447, 20}, {765, 20}, {2449, 10}, {785, 10}, {2450, 10}, } }, -- Waylaid Crate: Apprentice Herbs
  { id = 248683, tier = 1, kind = "g", favor = 5, bundles = { {2770, 20}, {2771, 20}, } }, -- Waylaid Crate: Apprentice Ore
  { id = 248684, tier = 1, kind = "g", favor = 5, bundles = { {2589, 40}, {2318, 20}, } }, -- Waylaid Crate: Apprentice Textiles
  { id = 248685, tier = 1, kind = "g", favor = 5, bundles = { {10940, 20}, {10939, 4}, {10978, 6}, {11084, 2}, } }, -- Waylaid Crate: Apprentice Curiosities
  { id = 248686, tier = 2, kind = "g", favor = 10, bundles = { {3820, 10}, {2453, 10}, {3355, 10}, {3369, 10}, {3356, 10}, } }, -- Waylaid Crate: Journeyman Herbs
  { id = 248687, tier = 2, kind = "g", favor = 10, bundles = { {2775, 10}, {2772, 20}, } }, -- Waylaid Crate: Journeyman Ore
  { id = 248688, tier = 2, kind = "g", favor = 10, bundles = { {2592, 20}, {4306, 40}, {2319, 20}, } }, -- Waylaid Crate: Journeyman Textiles
  { id = 248689, tier = 2, kind = "g", favor = 10, bundles = { {11083, 20}, {11082, 4}, {11138, 6}, {11139, 2}, } }, -- Waylaid Crate: Journeyman Curiosities
  { id = 248690, tier = 3, kind = "g", favor = 15, bundles = { {3357, 20}, {3818, 10}, {3821, 10}, {3358, 10}, } }, -- Waylaid Crate: Earthly Expert Herbs
  { id = 248691, tier = 3, kind = "g", favor = 15, bundles = { {3819, 10}, {4625, 10}, {8831, 20}, {8836, 10}, } }, -- Waylaid Crate: Flowering Expert Herbs
  { id = 248692, tier = 3, kind = "g", favor = 15, bundles = { {2776, 10}, {3858, 20}, } }, -- Waylaid Crate: Expert Ore
  { id = 248693, tier = 3, kind = "g", favor = 15, bundles = { {4338, 40}, {4234, 20}, } }, -- Waylaid Crate: Expert Textiles
  { id = 248694, tier = 3, kind = "g", favor = 15, bundles = { {11137, 20}, {11135, 4}, {11177, 6}, {11178, 2}, } }, -- Waylaid Crate: Expert Curiosities
  { id = 248695, tier = 4, kind = "g", favor = 20, bundles = { {13464, 10}, {8838, 20}, {8839, 10}, {8845, 10}, {8846, 10}, } }, -- Waylaid Crate: Earthly Artisan Herbs
  { id = 248696, tier = 4, kind = "g", favor = 20, bundles = { {13463, 20}, {13465, 20}, {13466, 20}, {13467, 20}, } }, -- Waylaid Crate: Flowering Artisan Herbs
  { id = 248697, tier = 4, kind = "g", favor = 20, bundles = { {7911, 10}, {10620, 20}, {11099, 20}, } }, -- Waylaid Crate: Artisan Ore
  { id = 248698, tier = 4, kind = "g", favor = 20, bundles = { {14047, 40}, {4304, 20}, {8170, 20}, } }, -- Waylaid Crate: Artisan Textiles
  { id = 248699, tier = 4, kind = "g", favor = 20, bundles = { {11176, 20}, {11175, 4}, {14343, 6}, {14344, 2}, } }, -- Waylaid Crate: Artisan Curiosities
  { id = 248702, tier = 1, kind = "c", favor = 10, bundles = { {4231, 2}, {2996, 20}, } }, -- Waylaid Crate: Apprentice Fabrics
  { id = 248703, tier = 1, kind = "c", favor = 10, bundles = { {2840, 20}, {3576, 20}, {2841, 10}, } }, -- Waylaid Crate: Apprentice Ingots
  { id = 248704, tier = 1, kind = "c", favor = 10, bundles = { {4359, 16}, {4361, 16}, {4363, 4}, } }, -- Waylaid Crate: Apprentice Parts
  { id = 248705, tier = 2, kind = "c", favor = 20, bundles = { {2997, 6}, {4305, 10}, {4233, 2}, } }, -- Waylaid Crate: Journeyman Fabrics
  { id = 248706, tier = 2, kind = "c", favor = 20, bundles = { {2842, 10}, {3575, 20}, } }, -- Waylaid Crate: Journeyman Ingots
  { id = 248707, tier = 2, kind = "c", favor = 20, bundles = { {4371, 8}, {4375, 7}, {4382, 4}, {10558, 45}, } }, -- Waylaid Crate: Journeyman Parts
  { id = 248708, tier = 3, kind = "c", favor = 30, bundles = { {4339, 8}, {4236, 2}, } }, -- Waylaid Crate: Expert Fabrics
  { id = 248709, tier = 3, kind = "c", favor = 30, bundles = { {3860, 20}, {3859, 15}, {3577, 10}, } }, -- Waylaid Crate: Expert Ingots
  { id = 248710, tier = 3, kind = "c", favor = 30, bundles = { {4387, 8}, {10559, 5}, {10560, 12}, {10561, 5}, } }, -- Waylaid Crate: Expert Parts
  { id = 248711, tier = 4, kind = "c", favor = 40, bundles = { {14048, 8}, {8172, 2}, } }, -- Waylaid Crate: Artisan Fabrics
  { id = 248712, tier = 4, kind = "c", favor = 40, bundles = { {11371, 2}, {6037, 10}, {12359, 20}, } }, -- Waylaid Crate: Artisan Ingots
  { id = 248713, tier = 4, kind = "c", favor = 40, bundles = { {15994, 5}, {18631, 5}, {16000, 2}, } }, -- Waylaid Crate: Artisan Parts
}
