local _, FLT = ...

-- Skill-Up Helper (6.2.6, user 12.11.2026; Tailoring pilot, all crafting professions since beta15): the cheapest way
-- from the current skill to a target.
-- Prices: Auctionator's public API (if installed), vendor prices (seen at a merchant > Data/ProfessionFees.lua from the
-- client), trainer fees (seen at the trainer > CMaNGOS data). Materials you have (bags, bank, other characters - the
-- Crafting List's stock) count as free (user's choice 1). Resale value is shown, never counted (choice 2).
-- The plan picks per skill point the recipe with the lowest expected cost (chance per craft: orange 1, then falling
-- to 0 at grey), one-time costs (recipe, fee) included, by dynamic programming over the skill points. Buffer: the
-- number of crafts that reaches the target in 9 of 10 cases (normal approximation of the sum of geometric draws),
-- spread over the steps by their variance - orange steps get none.
-- Lean: nothing runs until a plan is asked for; merchant prices are read once per MERCHANT_SHOW (only items of the
-- planned professions).

local SU = {}
FLT.SkillUp = SU
SU.PROFS = { Alchemy = true, Blacksmithing = true, Enchanting = true, Engineering = true, Leatherworking = true,
  Tailoring = true, Cooking = true, ["First Aid"] = true }
SU.Z90 = 1.2816 -- one-sided 90 %
local CALLER = "OneForAll"
local GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local GetItemCount = GetItemCount or (C_Item and C_Item.GetItemCount)

-- Prices ---------------------------------------------------------------------------------------------------------
local function atr() local a = type(Auctionator) == "table" and Auctionator.API and Auctionator.API.v1; return type(a) == "table" and a or nil end
function SU.HasAuctionator() local a = atr(); return a and type(a.GetAuctionPriceByItemID) == "function" or false end
local function call(fn, ...) if type(fn) ~= "function" then return nil end local ok, v = pcall(fn, ...); if ok then return v end end
function SU.AHPrice(id) local a = atr(); local p = a and call(a.GetAuctionPriceByItemID, CALLER, id); return type(p) == "number" and p > 0 and p or nil end
function SU.AHAge(id) local a = atr(); local d = a and call(a.GetAuctionAgeByItemID, CALLER, id); return type(d) == "number" and d or nil end
local function seenDB(key) return type(OneForAllDB) == "table" and type(OneForAllDB[key]) == "table" and OneForAllDB[key] or nil end
function SU.VendorPrice(id)
  local seen = seenDB("merchantPrices")
  if seen and seen[id] then return seen[id] end
  return FLT.VENDOR_PRICES and FLT.VENDOR_PRICES[id] or nil
end
-- 6.2.13-beta3 (Discord Graham / gieq 20.11.: Peacebloom at 42c, Kingsblood at Maria Lumere - those vendors have 2-3 in stock;
-- user 20.11.: "die haendler mit begrenzter stueckzahl ... nicht erscheinen lassen"): a reagent every vendor has only in a
-- limited stock (Data/ProfessionFees.lua VENDOR_LIMITED, or seen so at a merchant) is never planned from a vendor;
-- merchantLimited[id] = true (only seen limited) / "u" (a merchant without a limit was seen - wins)
function SU.VendorLimited(id)
  local seen = seenDB("merchantLimited")
  local s = seen and seen[id]
  if s ~= nil then return s == true end
  return FLT.VENDOR_LIMITED and FLT.VENDOR_LIMITED[id] or false
end
local function vendorSells(id)
  return ((FLT.VENDOR_REAGENTS and FLT.VENDOR_REAGENTS[id]) or (FLT.VENDOR_PRICES and FLT.VENDOR_PRICES[id])) and not SU.VendorLimited(id)
end
-- price to buy one: the cheaper of vendor and auction house, else a rough guess (4x the vendor sell price).
-- 6.2.13-beta2 (Discord _emgi 19.11.: the guide sent him to a vendor for 63 Lesser Magic Essence at 8s - the vendor has one
-- in stock, the auction house sells it for 1s 91c): the vendor only wins when it is not dearer than the auction house
-- (vendors with a limited stock are not known from the data)
function SU.BuyPrice(id)
  local v = vendorSells(id) and SU.VendorPrice(id) or nil
  local p = SU.AHPrice(id)
  if v and (not p or v <= p) then return v, "vendor" end
  if p then return p, "ah" end
  local sell = GetItemInfo and select(11, GetItemInfo(id))
  if type(sell) == "number" and sell > 0 then return sell * 4, "guess" end
  return nil, "none"
end
-- fee of a trainer recipe (seen at a trainer > data); second value: only specialization trainers teach it (data)
function SU.Fee(prof, spell)
  local f = FLT.PROFESSION_FEES and FLT.PROFESSION_FEES[prof]
  f = f and f.fees and f.fees[spell]
  local spec = f and f[3] and true or false
  local seen = seenDB("trainerFees"); seen = seen and seen[prof]
  if seen and seen[spell] then return seen[spell], false end -- a trainer offered it to this character
  return f and f[1] or nil, spec
end

-- the switch "Without other characters' materials" (6.2.7, Discord 13.11.: twinks may need their materials themselves),
-- shared by the Skill-Up Helper and Profit; off = they count
function SU.NoAlts() local d = type(OneForAllDB) == "table" and OneForAllDB.skillUp; return d and d.noAlts == true or false end
-- what you have of an item (bags, bank, other characters of the realm / faction unless SU.NoAlts)
function SU.Have(id)
  local CL = FLT.CraftList
  if CL and CL.Stock then return (CL.Stock(id, SU.NoAlts())) or 0 end
  return GetItemCount and GetItemCount(id, true) or 0
end
-- the switch "Don't use own materials" (6.2.12-beta19, user 18.11.: "damit nichts aus der bank oder den eigenen taschen
-- verwendet wird", off by default): materials you have count as not there - the plan and the Profit shopping list buy or
-- farm everything. Tools (rods, hammers) are not used up and still count (SU.Have).
function SU.NoOwn() local d = type(OneForAllDB) == "table" and OneForAllDB.skillUp; return d and d.noOwn == true or false end
function SU.HaveMat(id)
  if SU.NoOwn() and not (FLT.TOOL_ITEMS and FLT.TOOL_ITEMS[id]) then return 0 end
  return SU.Have(id)
end

-- Recipes ----------------------------------------------------------------------------------------------------------
local function myFaction()
  local f = UnitFactionGroup and UnitFactionGroup("player")
  return f == "Alliance" and "A" or (f == "Horde" and "H" or nil)
end
-- chance for a skill point when crafting at skill s (orange 1, yellow ... green falling, grey 0)
function SU.Chance(r, s)
  local y, gr = r.y or r.req or 1, r.gr or 0
  if s < (r.req or r.y or 1) then return 0 end
  if s < y then return 1 end
  if s >= gr or gr <= y then return 0 end
  return (gr - s) / (gr - y)
end
-- a vendor of my faction sells the recipe item
local function myVendor(r, fac)
  local v = r.src and r.src.v
  if not v then return nil end
  for _, e in ipairs(v) do if not e.fac or not fac or e.fac == fac or e.fac == "AH" then return e end end
  return nil
end
-- the reputation a recipe item asks for (Data/ProfessionFees.lua: ItemSparse standing 4 friendly ... 7 exalted) is met
function SU.HasRep(item)
  local need = item and FLT.RECIPE_REP and FLT.RECIPE_REP[item]
  if not need then return true end
  local standing
  if GetFactionInfoByID then standing = select(3, GetFactionInfoByID(need[1])) end -- 1 hated ... 8 exalted
  if not standing and type(C_Reputation) == "table" and C_Reputation.GetFactionDataByID then
    local d = C_Reputation.GetFactionDataByID(need[1]); standing = d and d.reaction
  end
  return type(standing) == "number" and standing - 1 >= need[2] or false
end
-- how to get a recipe: cost (copper, 0 = free), kind ("known", "trainer", "vendor", "ah", "bag") or nil = not plannable
function SU.Acquire(prof, r, p, opts, fac)
  if r.side and fac and r.side ~= fac then return nil end
  if FLT.CRAFT_COOLDOWN and FLT.CRAFT_COOLDOWN[r.s] then return nil end -- Mooncloth & co.: days between crafts
  if (p.known and p.known[r.s]) or r.start then return 0, "known" end
  if r.ri and not SU.HasRep(r.ri) then return nil end
  local spec = r.ri and FLT.RECIPE_SPEC and FLT.RECIPE_SPEC[r.ri] -- Weaponsmith / Goblin ... patterns: only that specialization
  if spec and not ((IsPlayerSpell and IsPlayerSpell(spec)) or (IsSpellKnown and IsSpellKnown(spec))) then return nil end
  if r.ri and GetItemCount and (GetItemCount(r.ri, true) or 0) > 0 then return 0, "bag" end
  if not r.ri and not r.src then
    local fee, spec = SU.Fee(prof, r.s)
    if spec then return nil end -- specialization recipe (Goblin, Gnomish ...): planned only when already known
    -- no fee known: a Classic recipe no trainer teaches (quest / raid patterns), or one of Forever's own new recipes
    -- (spell IDs from 1000000). 6.2.9 (Discord Aginda 14.11.: the guide sent people to their alchemy trainer for the
    -- Discolored Healing Potions, which only the Odd Child / Apothecary Renferrel teach): a Forever recipe is planned
    -- only when we know who teaches it (Data/ProfessionFees.lua teach) or a trainer offered it to you (its fee is seen)
    if not fee and (r.s < 1000000 or not SU.RecipeTrainers(prof, r.s)) then return nil end
    return fee or 0, "trainer", fee == nil
  end
  if r.fav then return nil end -- Merchant's Favor: paid with Favor, not planned
  if opts.vendor == true and myVendor(r, fac) then
    local price = r.ri and SU.VendorPrice(r.ri)
    if price then return price, "vendor" end
  end
  if opts.ah and r.ri then
    local price = SU.AHPrice(r.ri)
    if price then return price, "ah" end
  end
  return nil
end

-- Ranks: { name, spell, cap, copper, req, level }
function SU.Ranks(prof) local f = FLT.PROFESSION_FEES and FLT.PROFESSION_FEES[prof]; return f and f.ranks or {} end
local function capFor(prof, p)
  if p.maxSkill and p.maxSkill > 0 then return p.maxSkill end
  local s = p.skill or 0
  for _, rk in ipairs(SU.Ranks(prof)) do if s < rk[3] then return rk[3] end end
  return 300
end

-- Plan -------------------------------------------------------------------------------------------------------------
-- unit cost of an item for the plan: owned share free (cover[id] 0..1), else the cheaper of buying and crafting it
local function makeCoster(prof, list, avail, cover)
  local byItem = {}
  for _, r in ipairs(list) do if r.i and avail[r] then byItem[r.i] = byItem[r.i] or r end end
  local memo, busy = {}, {}
  local function unit(id)
    if memo[id] then return memo[id] end
    local buy = SU.BuyPrice(id)
    local best = buy
    local mk = byItem[id]
    if mk and not busy[id] then
      busy[id] = true
      local c = 0
      for _, g in ipairs(mk.r or {}) do local u = unit(g[1]); if not u then c = nil; break end c = c + u * g[2] end
      busy[id] = nil
      if c then c = c / (mk.c or 1); if not best or c < best then best = c end end
    end
    best = best and best * (1 - (cover[id] or 0)) or nil
    memo[id] = best
    return best
  end
  local function craft(r)
    local c = 0
    for _, g in ipairs(r.r or {}) do local u = unit(g[1]); if not u then return nil end c = c + u * g[2] end
    return c
  end
  return craft, unit, byItem
end

-- Profit (6.2.6-beta28, user 12.11.: "ein weiterer Reiter ... Profit ... wo anhand des Herstellungspreises ein Profit
-- geholt werden kann indem man es im AH verkauft"): every recipe whose product has an auction house price; cost = the
-- materials at the cheaper of buying and crafting them (owned ones are not free here - they could be sold too), sale =
-- the AH price minus the 5 % auction house cut. onlyKnown: recipes this character knows (and intermediates it can make).
-- Returns a list sorted by profit: { r, cost, sale, profit, margin, guess } (guess: a material price is only estimated).
SU.AH_CUT = 0.05
function SU.Profit(prof, onlyKnown)
  local list = FLT.PROFESSION_RECIPES and FLT.PROFESSION_RECIPES[prof]
  if not list then return {} end
  local p = FLT.GetProfessionState and FLT.GetProfessionState(prof) or { known = {} }
  local fac = myFaction()
  local avail = {}
  for _, r in ipairs(list) do
    if not (r.side and fac and r.side ~= fac) and (not onlyKnown or r.start or (p.known and p.known[r.s])) then avail[r] = true end
  end
  local craft, unit, byItem = makeCoster(prof, list, avail, {})
  SU.profitCtx = { unit = unit, byItem = byItem }
  local out = {}
  -- why a list stays empty (6.2.12-beta17, user 18.11.: "im profit bei tailoring nichts drin? was mache ich gerade falsch?"):
  -- how many products have an AH price, and how many of those also a price for every material
  local stats = { checked = 0, priced = 0, costed = 0 }
  SU.profitStats = stats
  for r in pairs(avail) do
    stats.checked = stats.checked + 1
    local price = r.i and SU.AHPrice(r.i)
    if price then
      stats.priced = stats.priced + 1
      local cost = craft(r)
      if cost and cost > 0 then stats.costed = stats.costed + 1 end
      local sale0 = price * (r.c or 1) * (1 - SU.AH_CUT)
      if cost and cost > 0 and sale0 > cost then
        local sale = price * (r.c or 1) * (1 - SU.AH_CUT)
        local guess = false
        for _, g in ipairs(r.r or {}) do local _, src = SU.BuyPrice(g[1]); if src == "guess" or src == "none" then guess = true end end
        out[#out + 1] = { r = r, cost = cost, sale = sale, profit = sale - cost, margin = (sale - cost) / cost, guess = guess,
          known = (p.known and p.known[r.s]) or r.start or false }
      end
    end
  end
  table.sort(out, function(a, b) if a.profit ~= b.profit then return a.profit > b.profit end return a.r.s < b.r.s end)
  return out
end

-- What to buy for crafts of the Profit page (beta37, user 12.11.: "der hat jetzt direkt bolt of silk cloth gekauft. prueft
-- die funktion ob normales silk cloth guenstiger ist?"): the same choice as the profit cost - a material that is cheaper to
-- make (from the last SU.Profit search) is broken down into its own materials; the bags are taken off first, on every level.
-- picks = { { r = recipe, n = crafts }, ... }; returns { [itemID] = count } of the materials to get.
function SU.ProfitBuyList(picks)
  local ctx = SU.profitCtx or {}
  local unit, byItem = ctx.unit, ctx.byItem or {}
  local out, bags, busy = {}, {}, {}
  local function have(id)
    if not bags[id] then -- bags, bank and the other characters (6.2.7-beta2/4, user 13.11.: "twinks natuerlich auch")
      local CL = FLT.CraftList
      bags[id] = SU.NoOwn() and 0 or CL and CL.Stock and (CL.Stock(id, SU.NoAlts())) or (CL and CL.InBags and CL.InBags(id)) or 0
    end
    return bags[id]
  end
  local function need(id, n)
    local take = math.min(have(id), n)
    bags[id] = bags[id] - take; n = n - take
    if n <= 0 then return end
    local mk = byItem[id]
    if mk and unit and not busy[id] then
      local c = 0
      for _, g in ipairs(mk.r or {}) do local u = unit(g[1]); if not u then c = nil; break end c = c + u * g[2] end
      local buy = SU.BuyPrice(id)
      if c and (not buy or c / (mk.c or 1) < buy) then
        local crafts = math.ceil(n / (mk.c or 1))
        busy[id] = true
        for _, g in ipairs(mk.r or {}) do need(g[1], g[2] * crafts) end
        busy[id] = nil
        return
      end
    end
    out[id] = (out[id] or 0) + n
  end
  for _, pk in ipairs(picks) do for _, g in ipairs(pk.r.r or {}) do need(g[1], g[2] * pk.n) end end
  return out
end

-- the route of the last plan is kept per character and profession (beta18, user 12.11.: after buying or a /reload the
-- plan picked other recipes - 18 Vision Dust became 19 - "es sollten immer die gleichen angezeigt werden"). It is used
-- again (cut to the current skill) while target and switches are the same and every recipe of it can still be had;
-- opts.fresh (the "Recalculate" button) works it out anew with today's prices and stock.
local function routeDB()
  if type(OneForAllCharDB) ~= "table" then return nil end
  OneForAllCharDB.skillUpRoute = OneForAllCharDB.skillUpRoute or {}
  return OneForAllCharDB.skillUpRoute
end
local function keptRoute(prof, opts, from, to, avail, list)
  local db = routeDB(); local k = db and db[prof]
  if opts.fresh or type(k) ~= "table" or k.to ~= to or k.ah ~= (opts.ah and true or false) or k.vendor ~= (opts.vendor == true) then return nil end
  local bySpell = {}
  for _, r in ipairs(list) do bySpell[r.s] = r end
  local segs = {}
  for _, g in ipairs(k.segs or {}) do
    local r = bySpell[g[1]]
    if not (r and avail[r]) then return nil end
    if g[3] > from then
      local a = math.max(g[2], from)
      for x = a, g[3] - 1 do if SU.Chance(r, x) <= 0 then return nil end end -- grey or not yet learnable there
      segs[#segs + 1] = { r = r, a = a, b = g[3], a0 = g[2] } -- a0: where the step began (guide bar)
    end
  end
  if #segs == 0 or segs[1].a ~= from or segs[#segs].b ~= to then return nil end
  return segs
end
-- steps marked done by hand in the guide (right-click, beta19): OneForAllCharDB.skillUpDone[prof][key]; a new route
-- starts without them
function SU.StepDone(prof, key)
  local d = type(OneForAllCharDB) == "table" and OneForAllCharDB.skillUpDone
  return d and d[prof] and d[prof][key] and true or false
end
function SU.SetStepDone(prof, key, on)
  if type(OneForAllCharDB) ~= "table" then return end
  local d = OneForAllCharDB.skillUpDone or {}; OneForAllCharDB.skillUpDone = d
  d[prof] = d[prof] or {}
  d[prof][key] = on and true or nil
end
local function keepRoute(prof, opts, to, segs)
  local db = routeDB(); if not db then return end
  if type(OneForAllCharDB.skillUpDone) == "table" then OneForAllCharDB.skillUpDone[prof] = nil end
  local t = { to = to, ah = opts.ah and true or false, vendor = opts.vendor == true, segs = {} }
  for _, g in ipairs(segs) do t.segs[#t.segs + 1] = { g.r.s, g.a, g.b } end
  db[prof] = t
end

-- opts: { from, to, ah = bool, vendor = bool, fresh = bool }; returns plan or nil, reason
function SU.Plan(prof, opts)
  opts = opts or {}
  local list = FLT.PROFESSION_RECIPES and FLT.PROFESSION_RECIPES[prof]
  if not list then return nil, "noData" end
  local p = FLT.GetProfessionState and FLT.GetProfessionState(prof) or { known = {} }
  local from = math.floor(tonumber(opts.from) or p.skill or 1)
  local to = math.floor(tonumber(opts.to) or 300)
  if from < 1 then from = 1 end
  if to > 300 then to = 300 end
  if to <= from then return nil, "done" end
  local fac = myFaction()
  -- candidates and their one-time cost
  local avail, acqC, acqK, feeUnknown = {}, {}, {}, {}
  for _, r in ipairs(list) do
    local c, k, unknown = SU.Acquire(prof, r, p, opts, fac)
    if c then avail[r], acqC[r], acqK[r], feeUnknown[r] = true, c, k, unknown end
  end
  -- ranks to train on the way
  local cap, trainings = capFor(prof, p), {}
  for _, rk in ipairs(SU.Ranks(prof)) do
    if rk[3] > cap and rk[3] - 75 < to then -- the rank before it ends 75 points lower
      trainings[#trainings + 1] = { name = rk[1], cap = rk[3], cost = rk[4], req = rk[5], level = rk[6], book = rk.item, quest = rk.quest, at = math.max(from, rk[5]) }
    end
  end
  local function capAt(s) local c = cap; for _, t in ipairs(trainings) do if s >= t.at then c = t.cap end end return c end
  local ctx = { from = from, to = to, trainings = trainings, acqC = acqC, acqK = acqK, feeUnknown = feeUnknown, fac = fac, avail = avail, list = list }
  local kept = keptRoute(prof, opts, from, to, avail, list)
  if kept then local pl = SU.Build(prof, kept, ctx); pl.kept = true; return pl end
  -- owned materials: pass 1 prices everything; later passes make the owned share of what the last plan needs free
  local cover = {}
  local plan
  for pass = 1, 3 do
    local craftCost = makeCoster(prof, list, avail, cover)
    local cc = {}
    for r in pairs(avail) do cc[r] = craftCost(r) end
    -- DP: best[s] = cheapest way to reach skill s; cont[r] = cheapest way to reach s with r as the running recipe
    local best, from_, cont, contFrom = { [from] = 0 }, {}, {}, {}
    for s = from, to - 1 do
      local b = best[s]
      if not b then break end
      local nb, nr = nil, nil
      local okCap = s < capAt(s)
      for r in pairs(avail) do
        local ch = okCap and cc[r] and SU.Chance(r, s) or 0
        if ch > 0 then
          local startCost = b + acqC[r]
          local prev = cont[r]
          local base, how
          if prev and prev[s] and prev[s] <= startCost then base, how = prev[s], "c" else base, how = startCost, "s" end
          local v = base + cc[r] / ch
          prev = prev or {}; cont[r] = prev; prev[s + 1] = v
          local cf = contFrom[r] or {}; contFrom[r] = cf; cf[s + 1] = how
          if not nb or v < nb then nb, nr = v, r end
        end
      end
      best[s + 1], from_[s + 1] = nb, nr
    end
    if not best[to] then
      local reached = from
      for s = from, to do if best[s] then reached = s end end
      return nil, "stuck", reached
    end
    -- walk back: segments { r, a, b }
    local segs = {}
    local s, r = to, from_[to]
    while s > from do
      local b = s
      while s > from and contFrom[r][s] == "c" do s = s - 1 end
      s = s - 1 -- the start point of this segment
      table.insert(segs, 1, { r = r, a = s, b = b })
      if s > from then r = from_[s] end
    end
    -- merge neighbours with the same recipe
    local merged = {}
    for _, g in ipairs(segs) do
      local last = merged[#merged]
      if last and last.r == g.r and last.b == g.a then last.b = g.b else merged[#merged + 1] = g end
    end
    plan = merged
    -- demand per material of this plan -> cover for the next pass
    if pass < 3 then
      local demand = {}
      for _, g in ipairs(plan) do
        local n = 0
        for x = g.a, g.b - 1 do n = n + 1 / SU.Chance(g.r, x) end
        for _, rg in ipairs(g.r.r or {}) do demand[rg[1]] = (demand[rg[1]] or 0) + rg[2] * n end
      end
      local changed = false
      local newCover = {}
      for id, need in pairs(demand) do
        local have = SU.HaveMat(id)
        local c = need > 0 and math.min(1, have / need) or 0
        newCover[id] = c
        if math.abs(c - (cover[id] or 0)) > 0.05 then changed = true end
      end
      if not changed and pass > 1 then break end
      cover = newCover
    end
  end
  keepRoute(prof, opts, to, plan)
  return SU.Build(prof, plan, ctx)
end

-- crafts, buffer, materials and costs of the chosen segments
-- tools (beta21, user 12.11.: no Runed Golden Rod, the list could not go on - "wäre cool wenn der guide alles abdecken
-- wuerde"): Data/ProfessionTools.lua. An item fits a tool category of the same type when its mask covers the category's.
local function band(a, b) -- bit.band for small positive masks (the test runs without the bit library)
  local r, p = 0, 1
  while a > 0 and b > 0 do
    if a % 2 == 1 and b % 2 == 1 then r = r + p end
    a, b, p = math.floor(a / 2), math.floor(b / 2), p * 2
  end
  return r
end
function SU.ToolFits(item, cat)
  local ic = FLT.TOOL_ITEMS and FLT.TOOL_ITEMS[item]
  local a, b = ic and FLT.TOOL_CATS[ic], FLT.TOOL_CATS and FLT.TOOL_CATS[cat]
  return a and b and a[1] == b[1] and b[2] > 0 and band(a[2], b[2]) == b[2] or false
end
-- the tool item a recipe needs: one I own (or the plan makes) when there is one, else the exact one; nil = no tool
local function toolFor(r, got)
  local direct = FLT.RECIPE_TOOL_ITEMS and FLT.RECIPE_TOOL_ITEMS[r.s]
  if direct then return direct end
  local cat = FLT.RECIPE_TOOLS and FLT.RECIPE_TOOLS[r.s]
  if not cat then return nil end
  local owned, exact
  for item, c in pairs(FLT.TOOL_ITEMS or {}) do
    if SU.ToolFits(item, cat) then
      if got[item] then return item end
      if not owned and SU.Have(item) > 0 then owned = item end
    end
    if c == cat then exact = item end
  end
  return owned or exact
end

-- buy an intermediate ready-made or craft it (6.2.12-beta18): OneForAllCharDB.skillUpPrep[prof][itemID] = "buy" / "craft";
-- nil = the cheaper way
function SU.PrepChoice(prof, id)
  local d = type(OneForAllCharDB) == "table" and OneForAllCharDB.skillUpPrep
  return type(d) == "table" and type(d[prof]) == "table" and d[prof][id] or nil
end
function SU.SetPrepChoice(prof, id, v)
  if type(OneForAllCharDB) ~= "table" then return end
  local d = type(OneForAllCharDB.skillUpPrep) == "table" and OneForAllCharDB.skillUpPrep or {}; OneForAllCharDB.skillUpPrep = d
  d[prof] = type(d[prof]) == "table" and d[prof] or {}
  d[prof][id] = (v == "buy" or v == "craft") and v or nil
end

function SU.Build(prof, segs, ctx)
  local _, unit, byItem = makeCoster(prof, ctx.list, ctx.avail, {})
  -- beta22 (user 12.11.: "die runed golden rod bringt auf jeden fall einen skillpunkt"): a runed rod the plan must make
  -- (bind on pickup, not owned) is its own step of one craft right before the step that needs it; when it is orange
  -- there, its point counts and the next step starts one higher
  local made, rows = {}, {}
  for _, g in ipairs(segs) do
    local item = toolFor(g.r, made)
    local mk = item and byItem[item]
    if mk and not made[item] and FLT.TOOL_BOP and FLT.TOOL_BOP[item] and mk ~= g.r and SU.Have(item) <= 0 then
      made[item] = true
      local ch = SU.Chance(mk, g.a)
      if ch > 0 then
        local up = (ch >= 1 and g.b - g.a > 1) and 1 or 0
        rows[#rows + 1] = { r = mk, a = g.a, b = g.a + up, toolStep = item, chance = ch }
        g = { r = g.r, a = g.a + up, b = g.b, a0 = g.a0 }
      end
    end
    rows[#rows + 1] = g
  end
  local steps, totalV = {}, 0
  for _, g in ipairs(rows) do
    local e, v = 0, 0
    if g.toolStep then e = 1
    else for x = g.a, g.b - 1 do local ch = SU.Chance(g.r, x); e = e + 1 / ch; v = v + (1 - ch) / (ch * ch) end end
    steps[#steps + 1] = { r = g.r, from = g.a, to = g.b, start = g.a0 or g.a, expected = e, var = v, toolStep = g.toolStep }
    totalV = totalV + v
  end
  local buffer = SU.Z90 * math.sqrt(totalV)
  local pool, mats, shop = {}, {}, {}
  local function avail(id) if pool[id] == nil then pool[id] = SU.HaveMat(id) end return pool[id] end
  local plan = { prof = prof, from = ctx.from, to = ctx.to, steps = {}, shop = shop, mats = mats, cost = 0, recipeCost = 0,
    trainCost = 0, resale = 0, expected = 0, safe = 0, guessed = false, feeUnknown = false, learned = {}, choices = {} }
  local learned = plan.learned -- recipes learned on the way (once)
  local tools = {} -- tool items the plan already has (owned or made / bought once)
  local ensureTool
  -- materials of n crafts of r: from the pool (owned, made before), else crafted (when cheaper) or bought
  -- parent: the prep (intermediate craft) these materials are for (beta31: its reagents count only while it is not made)
  local function need(id, n, step, depth, parent)
    if n <= 0 then return end
    local m = mats[id] or { id = id, need = 0, have = 0, buy = 0, craft = 0 }; mats[id] = m
    m.need = m.need + n
    local take = math.min(avail(id), n); pool[id] = pool[id] - take; m.have = m.have + take
    local rest = n - take
    local use = parent and parent.use or step.use -- what this step takes from the bags (owned + bought, not crafted on the way; beta25)
    if rest <= 0 then use[id] = (use[id] or 0) + n; return end
    local mk = byItem[id]
    local buy, src = SU.BuyPrice(id)
    local mustMake = FLT.TOOL_BOP and FLT.TOOL_BOP[id] and mk and depth < 4 -- runed rods: bind on pickup, only made
    local craftC
    if mk and depth < 4 then
      craftC = 0
      for _, g in ipairs(mk.r or {}) do local u = unit(g[1]); if not u then craftC = nil; break end craftC = craftC + u * g[2] end
      if craftC then craftC = craftC / (mk.c or 1) end
    end
    local doCraft = mustMake or (craftC and (not buy or craftC < buy))
    -- 6.2.12-beta18 (user 18.11.: "eine auswahl ... die fertigen bolt of mageweave zu kaufen. mit der differenz wie viel es
    -- mehr kosten wuerde"): an intermediate that can be crafted and bought (auction house / vendor) is a choice - the cheaper
    -- way unless the player picked the other one (SU.PrepChoice); plan.choices lists them with both unit prices
    if craftC and buy and not mustMake and (src == "ah" or src == "vendor") then
      local pick = SU.PrepChoice(prof, id)
      if pick == "buy" then doCraft = false elseif pick == "craft" then doCraft = true end
      local ch = plan.choices[id] or { id = id, n = 0, craftU = craftC, buyU = buy, src = src }; plan.choices[id] = ch
      ch.n = ch.n + rest; ch.buying = not doCraft
    end
    if doCraft then
      -- beta31 (user 12.11.: "dann gilt das als ganzer Schritt"): the owned part is not a bag material any more, the prep
      -- counts all n it needs (total) against the bags (SU.PrepStatus)
      local crafts = math.ceil(rest / (mk.c or 1))
      m.craft = m.craft + rest
      local pr = { r = mk, n = crafts, item = id, total = n, out = mk.c or 1, use = {}, parent = parent }
      if ctx.acqK[mk] ~= "known" and not learned[mk] then -- an intermediate (bolt) whose recipe must be learned first
        learned[mk] = true
        pr.learn, pr.learnCost = ctx.acqK[mk], ctx.acqC[mk] or 0
        plan.recipeCost = plan.recipeCost + pr.learnCost; plan.cost = plan.cost + pr.learnCost; step.cost = step.cost + pr.learnCost
      end
      if ensureTool then ensureTool(mk, step, depth) end
      step.prep[#step.prep + 1] = pr
      for _, g in ipairs(mk.r or {}) do need(g[1], g[2] * crafts, step, depth + 1, pr) end
      local extra = crafts * (mk.c or 1) - rest
      if extra > 0 then pool[id] = (pool[id] or 0) + extra end
    else
      use[id] = (use[id] or 0) + n
      m.buy = m.buy + rest
      local sh = shop[id] or { id = id, n = 0, src = src, price = buy }; shop[id] = sh
      sh.n = sh.n + rest
      if buy then plan.cost = plan.cost + buy * rest; step.cost = step.cost + buy * rest end
      if src == "guess" or src == "none" then plan.guessed = true end
      step.buy[#step.buy + 1] = { id = id, n = rest, src = src, price = buy }
    end
  end
  -- the tool once: listed with the materials (owned) or crafted / bought like a reagent; a better rod also does
  ensureTool = function(r, step, depth)
    local item = toolFor(r, tools)
    if not item then return end
    if (depth or 0) == 0 then step.tool = item end
    if tools[item] then return end -- owned / made earlier in the plan
    tools[item] = true
    need(item, 1, step, (depth or 0) + 1)
  end
  local ti = 1
  local tr = ctx.trainings
  for _, st in ipairs(steps) do
    -- trainings due before this step
    while tr[ti] and tr[ti].at <= st.from do
      local t = tr[ti]
      plan.steps[#plan.steps + 1] = { kind = "train", rank = t.name, cap = t.cap, at = t.at, cost = t.cost, level = t.level, book = t.book, quest = t.quest }
      plan.trainCost = plan.trainCost + (t.cost or 0); plan.cost = plan.cost + (t.cost or 0)
      ti = ti + 1
    end
    local r = st.r
    local extra = totalV > 0 and buffer * st.var / totalV or 0
    local safe = st.toolStep and 1 or math.ceil(st.expected + extra - 1e-9)
    if st.toolStep then tools[st.toolStep] = true end -- the rod is made here (one craft is enough)
    local step = { kind = "craft", r = r, from = st.from, to = st.to, start = st.start, toolStep = st.toolStep, expected = st.expected, safe = safe, buy = {}, prep = {}, use = {}, cost = 0 }
    -- learning the recipe first (once)
    if not learned[r] and ctx.acqK[r] ~= "known" then
      learned[r] = true
      step.learn, step.learnCost = ctx.acqK[r], ctx.acqC[r]
      if ctx.feeUnknown[r] then plan.feeUnknown = true end
      plan.recipeCost = plan.recipeCost + (ctx.acqC[r] or 0); plan.cost = plan.cost + (ctx.acqC[r] or 0)
      step.cost = step.cost + (ctx.acqC[r] or 0)
    end
    ensureTool(r, step, 0)
    for _, g in ipairs(r.r or {}) do need(g[1], g[2] * safe, step, 0) end
    -- what comes out goes into the pool (bolts made for skill can feed later steps)
    if r.i then pool[r.i] = avail(r.i) + safe * (r.c or 1) end
    local ah = r.i and SU.AHPrice(r.i)
    step.resale = ah and ah * safe * (r.c or 1) or nil
    if step.resale then plan.resale = plan.resale + step.resale end
    plan.expected = plan.expected + st.expected
    plan.safe = plan.safe + safe
    plan.steps[#plan.steps + 1] = step
  end
  while tr[ti] do
    local t = tr[ti]
    if t.at < ctx.to then
      plan.steps[#plan.steps + 1] = { kind = "train", rank = t.name, cap = t.cap, at = t.at, cost = t.cost, level = t.level, book = t.book, quest = t.quest }
      plan.trainCost = plan.trainCost + (t.cost or 0); plan.cost = plan.cost + (t.cost or 0)
    end
    ti = ti + 1
  end
  -- buy lists: auction house / vendor / unknown
  plan.ah, plan.vendor, plan.other = {}, {}, {}
  for _, sh in pairs(shop) do
    local l = sh.src == "ah" and plan.ah or (sh.src == "vendor" and plan.vendor or plan.other)
    l[#l + 1] = sh
  end
  for _, l in ipairs({ plan.ah, plan.vendor, plan.other }) do table.sort(l, function(a, b) return a.id < b.id end) end
  return plan
end

-- beta25 (user 12.11.: "die anzeige materials dynamisch waechst bzw. abnimmt"): the materials still needed from the
-- current skill on - finished steps need nothing, the current one its share of the crafts still to do (expected crafts
-- from the skill to its end / expected crafts of the whole step), later ones all. A tool counts while a step needs it.
function SU.StepFinished(plan, prof, st, skill)
  if st.toolStep then return SU.Have(st.toolStep) > 0 or SU.StepDone(prof, "c:" .. st.r.s .. ":" .. st.to) end
  return skill >= st.to or SU.StepDone(prof, "c:" .. st.r.s .. ":" .. st.to)
end
-- the share of a step still to do at this skill (expected crafts from the skill to its end / expected crafts of the step)
function SU.StepFrac(st, skill)
  if st.toolStep or skill <= st.from or (st.expected or 0) <= 0 then return 1 end
  local rem = 0
  for x = skill, st.to - 1 do local c = SU.Chance(st.r, x); rem = rem + (c > 0 and 1 / c or 0) end
  return math.min(1, rem / st.expected)
end
local function inBags(id)
  local CL = FLT.CraftList
  if CL and CL.InBags then return CL.InBags(id) or 0 end
  return GetItemCount and GetItemCount(id) or 0
end
-- beta31 (user 12.11.: "First craft 7x Bolt of Silk Cloth" was not ticked after making 7, and the 33x two steps further
-- down should shrink with the bolts I have): every prep of the unfinished steps, in route order, takes what it needs
-- from the bags. out[pr] = { want = units needed now, have = from the bags, left = crafts still to do, key }. A prep of
-- the first open step found complete is latched (key "p:<spell>:<to>:<item>") so crafting the step itself (which uses the bolts up) does not
-- open it again; right-click opens it. Nested preps (bars for tubes) scale with their parent's crafts left.
function SU.PrepStatus(plan, prof, skill, out)
  out = out or {}
  local bag = {}
  local function b(id) if bag[id] == nil then bag[id] = inBags(id) end return bag[id] end
  local first = true -- only the preps of the first open step are latched (later ones still share the bags)
  for _, st in ipairs(plan.steps) do
    if st.kind == "craft" and st.prep then
      local fin = SU.StepFinished(plan, prof, st, skill)
      local latch = first and not fin
      if not fin then first = false end
      local frac = fin and 0 or SU.StepFrac(st, skill)
      if not fin then for id, n in pairs(st.use or {}) do bag[id] = b(id) - math.ceil(n * frac - 1e-6) end end
      for _, pr in ipairs(st.prep) do
        local s = out[pr] or {}; out[pr] = s
        s.key = "p:" .. st.r.s .. ":" .. st.to .. ":" .. tostring(pr.item)
        local par = pr.parent and out[pr.parent]
        local scale = par and (pr.parent.n > 0 and par.left / pr.parent.n or 0) or frac
        s.want = math.max(0, math.ceil(pr.total * scale - 1e-6))
        s.have = math.max(0, math.min(b(pr.item), s.want))
        bag[pr.item] = b(pr.item) - s.have
        s.left = math.ceil((s.want - s.have) / (pr.out or 1) - 1e-6)
        if fin then s.left = 0
        elseif SU.StepDone(prof, s.key) then s.left = 0
        elseif latch and s.left <= 0 and s.want > 0 then SU.SetStepDone(prof, s.key, true) end
        if s.left < 0 then s.left = 0 end
      end
    end
  end
  return out
end
function SU.RemainingMats(plan, prof, skill, out, prep)
  out = out or {}
  for k in pairs(out) do out[k] = nil end
  prep = prep or SU.PrepStatus(plan, prof, skill)
  local tool = FLT.TOOL_ITEMS
  local function add(use, f)
    for id, n in pairs(use) do
      if tool and tool[id] then out[id] = 1 else out[id] = (out[id] or 0) + n * f end
    end
  end
  for _, st in ipairs(plan.steps) do
    if st.kind == "craft" and st.use and not SU.StepFinished(plan, prof, st, skill) then
      add(st.use, SU.StepFrac(st, skill))
      -- the reagents of an intermediate only for the crafts of it still to do
      for _, pr in ipairs(st.prep or {}) do
        local s = prep[pr]
        if s and pr.n > 0 and s.left > 0 then add(pr.use, s.left / pr.n) end
      end
      if st.tool then out[st.tool] = 1 end
    end
  end
  for id, n in pairs(out) do out[id] = math.ceil(n - 1e-6); if out[id] <= 0 then out[id] = nil end end
  return out
end

-- the vendors of a recipe for my faction (for the map button)
function SU.RecipeVendors(r)
  local out, fac = {}, myFaction()
  for _, e in ipairs(r.src and r.src.v or {}) do if not e.fac or e.fac == fac or e.fac == "AH" then out[#out + 1] = e end end
  return out
end
-- the trainers of my faction who teach a recipe (Data/ProfessionFees.lua teach groups, 6.2.6-beta25); nil = no data
local teachIdx = {}
function SU.RecipeTrainers(prof, spell)
  local f = FLT.PROFESSION_FEES and FLT.PROFESSION_FEES[prof]
  if not (f and f.teach) then return nil end
  local idx = teachIdx[prof]
  if not idx then
    idx = {}
    for _, g in ipairs(f.teach) do for _, s in ipairs(g[2]) do idx[s] = g[1] end end
    teachIdx[prof] = idx
  end
  local ids = idx[spell]
  if not ids then return nil end
  local out, fac = {}, myFaction()
  for _, t in ipairs(FLT.PROFESSION_TRAINERS and FLT.PROFESSION_TRAINERS[prof] or {}) do
    if not fac or t[4] == "AH" or t[4] == fac then
      for _, id in ipairs(ids) do if id == t[1] then out[#out + 1] = t; break end end
    end
  end
  -- NPCs who are no profession trainers but teach some Forever recipes (Odd Child ..., 6.2.9)
  for _, id in ipairs(ids) do
    local t = FLT.PROFESSION_RANK_NPCS and FLT.PROFESSION_RANK_NPCS[id]
    if t and (not fac or t[4] == "AH" or t[4] == fac) then out[#out + 1] = t end
  end
  return #out > 0 and out or nil
end
-- the nearest trainer that teaches a rank (Data/ProfessionFees.lua trainers; NPCs without data by their title)
function SU.TrainersFor(prof, rankName)
  local f = FLT.PROFESSION_FEES and FLT.PROFESSION_FEES[prof]
  -- Cooking / First Aid Expert and Artisan: book vendors / quest givers (beta15)
  for _, rk in ipairs(f and f.ranks or {}) do
    if rk[1] == rankName and rk.npcs then
      local out, fac = {}, myFaction()
      for _, id in ipairs(rk.npcs) do
        local t = FLT.PROFESSION_RANK_NPCS and FLT.PROFESSION_RANK_NPCS[id]
        if t and (not fac or t[4] == "AH" or t[4] == fac) then out[#out + 1] = t end
      end
      return out
    end
  end
  local bit = ({ Apprentice = 1, Journeyman = 2, Expert = 4, Artisan = 8 })[rankName] or 1
  local out, fac = {}, myFaction()
  for _, t in ipairs(FLT.PROFESSION_TRAINERS and FLT.PROFESSION_TRAINERS[prof] or {}) do
    local side = t[4]
    if not fac or side == "AH" or side == fac then
      local m = f and f.trainers and f.trainers[t[1]]
      if not m then m = (t[3] or ""):find("Master") and 15 or 1 end -- Forever's own trainers: Apprentice only until seen
      if math.floor(m / bit) % 2 == 1 then out[#out + 1] = t end
    end
  end
  return out
end

-- Auctionator shopping list ("OneForAll Skill-Up"): exact searches with the amount
-- (plan.ah = { { id, n } }; the Profit page passes its own list and name, 6.2.6-beta28).
-- 6.2.7-beta3 (user 13.11.: "pruefen ob der skill up guide das richtig uebergibt"): Auctionator searches by name, and an
-- item the client has not loaded yet has none - it fell out of the list without a word. Missing names are requested and
-- the list is sent up to 2 s later; done(ok, missing) is called once at the end (missing = items still without a name).
local function itemNameOf(id)
  local CI = C_Item -- looked up live (the file-level GetItemInfo is fixed at load)
  local n = CI and CI.GetItemNameByID and call(CI.GetItemNameByID, id)
  if not n then n = call((CI and CI.GetItemInfo) or _G.GetItemInfo, id) end
  return n
end
function SU.SendToAuctionator(plan, listName, done, tries)
  local a = atr()
  if not (a and a.CreateShoppingList and a.ConvertToSearchString and plan) then if done then done(false, 0) end return false end
  tries = tries or 0
  local missing = 0
  for _, sh in ipairs(plan.ah or {}) do
    if not itemNameOf(sh.id) then
      missing = missing + 1
      if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, sh.id) end
    end
  end
  if missing > 0 and tries < 4 and C_Timer and C_Timer.After then
    C_Timer.After(0.5, function() SU.SendToAuctionator(plan, listName, done, tries + 1) end)
    return nil -- sent later
  end
  local terms = {}
  for _, sh in ipairs(plan.ah or {}) do
    local name = itemNameOf(sh.id)
    if name then
      local s = call(a.ConvertToSearchString, CALLER, { searchString = name, isExact = true, quantity = sh.n })
      if s then terms[#terms + 1] = s end
    end
  end
  local ok = #terms > 0 and pcall(a.CreateShoppingList, CALLER, listName or "OneForAll Skill-Up", terms) or false
  if done then done(ok, missing) end
  return ok
end

-- Merchant prices (only items of the planned professions; once per merchant visit) ---------------------------------
local wanted
local function wantedItems()
  if wanted then return wanted end
  wanted = {}
  for prof in pairs(SU.PROFS) do
    for _, r in ipairs(FLT.PROFESSION_RECIPES and FLT.PROFESSION_RECIPES[prof] or {}) do
      for _, g in ipairs(r.r or {}) do wanted[g[1]] = true end
      if r.ri then wanted[r.ri] = true end
    end
  end
  return wanted
end
function SU.ReadMerchant()
  if not (GetMerchantNumItems and GetMerchantItemInfo and type(OneForAllDB) == "table") then return end
  local w = wantedItems()
  for i = 1, GetMerchantNumItems() or 0 do
    local id = GetMerchantItemID and GetMerchantItemID(i)
    if not id and GetMerchantItemLink then local l = GetMerchantItemLink(i); id = l and tonumber(l:match("item:(%d+)")) end
    if id and w[id] then
      local _, _, price, qty, avail, _, _, extended = GetMerchantItemInfo(i)
      if type(avail) == "number" then -- -1 = no limit, else the stock left
        OneForAllDB.merchantLimited = OneForAllDB.merchantLimited or {}
        local ml = OneForAllDB.merchantLimited
        if avail < 0 then ml[id] = "u" elseif ml[id] ~= "u" then ml[id] = true end
      end
      if type(price) == "number" and price > 0 and not extended then
        OneForAllDB.merchantPrices = OneForAllDB.merchantPrices or {}
        OneForAllDB.merchantPrices[id] = math.floor(price / math.max(1, tonumber(qty) or 1) + 0.5)
      end
    end
  end
end
-- when the auction house was last scanned: our own note of Auctionator's database updates, and Auctionator's own scan
-- times (its saved state; read only)
function SU.LastScan()
  local t = type(OneForAllDB) == "table" and type(OneForAllDB.skillUp) == "table" and OneForAllDB.skillUp.lastAH or nil
  local st = type(Auctionator) == "table" and type(Auctionator.SavedState) == "table" and Auctionator.SavedState or nil
  if st then
    for _, k in ipairs({ "TimeOfLastGetAllScan", "TimeOfLastReplicateScan", "TimeOfLastBrowseScan" }) do
      local v = tonumber(st[k]); if v and (not t or v > t) then t = v end
    end
  end
  return t
end
local ev = CreateFrame("Frame")
pcall(ev.RegisterEvent, ev, "MERCHANT_SHOW")
pcall(ev.RegisterEvent, ev, "PLAYER_LOGIN")
ev:SetScript("OnEvent", function(_, event)
  if event == "MERCHANT_SHOW" then SU.ReadMerchant(); return end
  -- PLAYER_LOGIN: Auctionator is loaded by now; its database update (a scan or a search) is noted and the page refreshed
  local a = atr()
  if a and type(a.RegisterForDBUpdate) == "function" then
    pcall(a.RegisterForDBUpdate, CALLER, function()
      if type(OneForAllDB) == "table" then OneForAllDB.skillUp = OneForAllDB.skillUp or {}; OneForAllDB.skillUp.lastAH = time and time() or nil end
      if SU._onDB then SU._onDB() end
    end)
  end
end)
SU._reset = function() wanted = nil end -- tests
