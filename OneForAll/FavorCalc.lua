local _, FLT = ...

-- Merchant's Favor calculator (6.2.18-beta16, user 27.11.2026: "einen gewuenschten Favor Wert eintragen ... anhand eines scans
-- ermittelt was der guenstigste weg dahin ist"): which Waylaid Crates (Data/FavorCrates.lua) to buy and fill with which bundle so
-- a wanted amount of Merchant's Favor costs the least gold. Prices: the cheapest listings of our auction house scan (AHScan.lua,
-- with their stack sizes, so buying more walks up the price list) - else Auctionator's price per item (no amounts). Crates and
-- materials in your bags and bank are used first and cost nothing (switch OneForAllDB.favorCalcNoOwn).
-- Greedy: one crate at a time, always the one with the lowest gold per Favor for its next copy (with its cheapest bundle).
-- Runs only on a click (no events, nothing in the background).

local FC = {}
FLT.FavorCalc = FC
local MAX_FAVOR = 6000 -- the dearest reward (Reins of the Pack Kodo) costs 6000

-- price source per item: our listings, or Auctionator's single price (unlimited), or nil
local function auctionatorPrice(id)
  local api = type(Auctionator) == "table" and Auctionator.API and Auctionator.API.v1
  if not (api and api.GetAuctionPriceByItemID) then return nil end
  local ok, p = pcall(api.GetAuctionPriceByItemID, "OneForAll", id)
  return ok and type(p) == "number" and p > 0 and p or nil
end

-- the cost of the next n units after `taken` units were already bought; nil when the market has not enough
local function buyCost(src, taken, n)
  if n <= 0 then return 0 end
  if src.flat then return src.flat * n end
  local list, skip, cost = src.list, taken, 0
  for i = 1, #list - 1, 2 do
    local p, c = list[i], list[i + 1]
    if skip >= c then skip = skip - c
    else
      local can = c - skip; skip = 0
      local k = math.min(can, n)
      cost = cost + k * p; n = n - k
      if n == 0 then return cost end
    end
  end
  return nil
end
FC._buyCost = buyCost -- tests

-- the one-time quest "Shipping Label": the first crate you ever hand in brings 50 Favor more (Alliance 98247, Horde 98248)
FC.LABEL_FAVOR = 50
function FC.LabelOpen()
  local done = C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted
  if not done then return false end
  return not (done(98247) or done(98248))
end

-- the plan for `want` Favor. opts.own (default: OneForAllDB.favorCalcNoOwn ~= true) = use bags / bank first; opts.bonus = Favor
-- multiplier (Legacy "Performance Bonus" 3/3 = 1.15); opts.label = the first crate brings the Shipping Label's 50 Favor;
-- opts.only = only this crate (the comparison table).
-- Returns { favor, cost, crates = { { crate, n, own, cost, bundle = { item, count }, mats = cost } }, buy = { [item] = { n, cost, max } },
-- useOwn = { [item] = n }, source = "scan" | "auctionator" | nil, short = true when the market ran out before `want` }
function FC.Plan(want, opts)
  want = math.max(0, math.min(MAX_FAVOR, math.floor(tonumber(want) or 0)))
  opts = opts or {}
  local useOwn = opts.own
  if useOwn == nil then useOwn = not (type(OneForAllDB) == "table" and OneForAllDB.favorCalcNoOwn == true) end
  local AS = FLT.AHScan
  local hasScan = AS and AS.Data and AS.Data() and AS.Data().fav
  local source = hasScan and "scan" or nil
  local srcCache, own, ownUsed, bought = {}, {}, {}, {}
  local function src(id)
    local s = srcCache[id]
    if s == nil then
      local list = hasScan and AS.Listings(id)
      if list and #list >= 2 then s = { list = list }
      else
        local p = auctionatorPrice(id)
        if p then s = { flat = p }; source = source or "auctionator" else s = false end
      end
      srcCache[id] = s
    end
    return s or nil
  end
  local function ownLeft(id)
    if not useOwn then return 0 end
    local n = own[id]
    if n == nil then n = (GetItemCount and GetItemCount(id, true)) or 0; own[id] = n end
    return n - (ownUsed[id] or 0)
  end
  -- what the next n units of an item cost (own first); nil = not available
  local function need(id, n)
    local o = math.min(ownLeft(id), n)
    local rest = n - o
    if rest == 0 then return 0, o end
    local s = src(id)
    if not s then return nil end
    local c = buyCost(s, bought[id] or 0, rest)
    return c, o
  end
  local function take(id, n, o)
    ownUsed[id] = (ownUsed[id] or 0) + o
    bought[id] = (bought[id] or 0) + (n - o)
  end

  local plan = { favor = 0, cost = 0, crates = {}, buy = {}, useOwn = {}, source = source }
  local byKey = {}
  local crates = FLT.FAVOR_CRATES or {}
  local mult = tonumber(opts.bonus) or 1
  if opts.only then
    for _, c in ipairs(crates) do if c.id == opts.only then crates = { c }; break end end
    if crates == FLT.FAVOR_CRATES then crates = {} end
  end
  local label = opts.label and true or false
  while plan.favor < want do
    local best, bestPer, bestC, bestB, bestCrateCost, bestMat, bestCrateOwn
    for _, c in ipairs(crates) do
      local cc, co = need(c.id, 1)
      if cc and c.favor and c.favor > 0 then
        for bi, b in ipairs(c.bundles) do
          local mc = need(b[1], b[2])
          if mc then
            local per = (cc + mc) / (c.favor * mult)
            if not bestPer or per < bestPer then bestPer, bestC, bestB, bestCrateCost, bestMat, bestCrateOwn, best = per, c, bi, cc, mc, co, true end
          end
        end
      end
    end
    if not best then plan.short = true; break end
    local b = bestC.bundles[bestB]
    local _, mo = need(b[1], b[2])
    take(bestC.id, 1, bestCrateOwn)
    take(b[1], b[2], mo)
    local key = bestC.id .. ":" .. bestB
    local e = byKey[key]
    if not e then e = { crate = bestC, bundle = b, n = 0, own = 0, cost = 0, mats = 0 }; byKey[key] = e; plan.crates[#plan.crates + 1] = e end
    e.n = e.n + 1; e.own = e.own + bestCrateOwn; e.cost = e.cost + bestCrateCost; e.mats = e.mats + bestMat
    plan.favor = plan.favor + bestC.favor * mult
    if label then plan.favor = plan.favor + FC.LABEL_FAVOR; plan.label = true; label = false end
    plan.cost = plan.cost + bestCrateCost + bestMat
  end
  plan.source = source
  -- the shopping list: how many of each item to buy, what that costs and the highest unit price on the way
  for id, n in pairs(bought) do
    if n > 0 then
      local s = src(id)
      local cost = s and buyCost(s, 0, n) or 0
      local max
      if s and s.flat then max = s.flat
      elseif s then
        local left = n
        for i = 1, #s.list - 1, 2 do max = s.list[i]; left = left - s.list[i + 1]; if left <= 0 then break end end
      end
      plan.buy[id] = { n = n, cost = cost, max = max }
    end
  end
  for id, n in pairs(ownUsed) do if n > 0 then plan.useOwn[id] = n end end
  table.sort(plan.crates, function(a, b) return a.crate.id < b.crate.id end)
  plan.favor = math.floor(plan.favor + 0.5)
  return plan
end

-- every crate on its own for `want` Favor (the comparison table), cheapest per Favor first; crates without offers last
function FC.Compare(want, opts)
  local out = {}
  for _, c in ipairs(FLT.FAVOR_CRATES or {}) do
    local o = {}
    for k, v in pairs(opts or {}) do o[k] = v end
    o.only = c.id
    local p = FC.Plan(want, o)
    local n = 0
    for _, e in ipairs(p.crates) do n = n + e.n end
    out[#out + 1] = { crate = c, n = n, cost = p.cost, favor = p.favor, short = p.short,
      each = n > 0 and p.cost / n or nil, per = p.favor > 0 and p.cost / p.favor or nil }
  end
  table.sort(out, function(a, b)
    if (a.per ~= nil) ~= (b.per ~= nil) then return a.per ~= nil end
    if a.per and b.per and a.per ~= b.per then return a.per < b.per end
    return a.crate.id < b.crate.id
  end)
  return out
end

-- the shopping list as an Auctionator shopping list ("OneForAll Favor"); true when it was made
function FC.ToAuctionator(plan)
  local api = type(Auctionator) == "table" and Auctionator.API and Auctionator.API.v1
  if not (api and api.CreateShoppingList and api.ConvertToSearchString) or not plan then return false end
  local GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
  local terms = {}
  for id, b in pairs(plan.buy or {}) do
    local name = GetItemInfo and GetItemInfo(id)
    if name then
      local ok, term = pcall(api.ConvertToSearchString, "OneForAll", { searchString = name, isExact = true, quantity = b.n })
      if ok and term then terms[#terms + 1] = term end
    end
  end
  if #terms == 0 then return false end
  return pcall(api.CreateShoppingList, "OneForAll", "OneForAll Favor", terms) and true or false
end
