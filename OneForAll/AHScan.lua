local _, FLT = ...

-- "Cheap Upgrade Scan" (6.2.13-beta19, user 21.11.2026): a button in the auction house that reads Blizzard's full scan
-- (C_AuctionHouse.ReplicateItems - allowed once every 15 minutes, for all addons together) and keeps the cheapest
-- buyout of every Bind on Equip piece of gear of Data/BoeItems.lua - items with a random bonus ("of the Eagle") once
-- per bonus, which Auctionator cannot (it keeps one price per item ID, tested at the AH 21.11.). Used by Armory > Gear
-- Planner > Cheap Upgrades. A full scan another addon started (Auctionator's "Full Scan") is read along.
-- QoL "ahScan" (on, user 21.11.): off = no button and nothing read. Lean: nothing runs outside the auction house; the
-- scan is read in parts of 1000 auctions per frame. Saved per auction house: OneForAllDB.ahScan[realm-faction] =
-- { t = time, fixed = { [item ID] = copper }, var = { ["item:ID:...bonus"] = copper } }

local AS = {}
FLT.AHScan = AS
local L = FLT.L or setmetatable({}, { __index = function(_, k) return k end }) -- (tests without Locales)
local COOLDOWN, BATCH = 900, 1000
AS.gen = 0 -- grows with every finished scan (the Armory rebuilds its list)

local function on() return not (FLT.QoL and FLT.QoL.Get) or FLT.QoL.Get("ahScan") ~= false end
local function realmKey()
  local r = (GetNormalizedRealmName and GetNormalizedRealmName()) or (GetRealmName and GetRealmName()) or ""
  return (r ~= "" and r or "?") .. "-" .. ((UnitFactionGroup and UnitFactionGroup("player")) or "?")
end
local function store(create)
  if type(OneForAllDB) ~= "table" then return nil end
  if create then OneForAllDB.ahScan = OneForAllDB.ahScan or {} end
  return type(OneForAllDB.ahScan) == "table" and OneForAllDB.ahScan[realmKey()] or nil
end
function AS.Data() return store() end

-- the BoE item IDs (fixed stats / random bonus), built once when first needed
local fixedSet, randSet
local function sets()
  if fixedSet then return end
  fixedSet, randSet = {}, {}
  local t = FLT.BOE_ITEMS or {}
  for i = 1, #t - 1, 2 do fixedSet[t[i]] = true end
  t = FLT.BOE_RANDOM or {}
  for i = 1, #t - 1, 2 do randSet[t[i]] = true end
end
AS._sets = function() sets(); return fixedSet, randSet end -- tests

-- one key per bonus: the item string without enchant, gems, unique ID, level and spec, and without what follows the
-- bonus IDs (the level it dropped at ...): "item:15373::::::0:::::0:2:1234:5678"
function AS.Variant(link)
  local s = type(link) == "string" and link:match("item:[%-%d:]+")
  if not s then return nil end
  local f, n = {}, 0
  for v in (s .. ":"):gmatch("([^:]*):") do n = n + 1; f[n] = v end
  local id = tonumber(f[2])
  if not id then return nil end
  local nb = tonumber(f[14]) or 0
  local out = { "item", f[2], "", "", "", "", "", f[8] or "", "", "", "", f[12] or "", f[13] or "", tostring(nb) }
  for i = 1, nb do out[#out + 1] = f[14 + i] or "" end
  return table.concat(out, ":"), id
end

-- prices of the last scan here: fixed[id] and the bonus variants of an item ID
function AS.Price(id) local d = store(); return d and d.fixed and d.fixed[id] or nil end
function AS.Variants(id)
  local d = store()
  if not (d and d.var) then return nil end
  if AS.byIdGen ~= AS.gen or AS.byIdKey ~= realmKey() then
    AS.byId, AS.byIdGen, AS.byIdKey = {}, AS.gen, realmKey()
    for key, p in pairs(d.var) do
      local vid = tonumber(key:match("^item:(%d+)"))
      if vid then local t = AS.byId[vid] or {}; t[#t + 1] = { link = key, p = p }; AS.byId[vid] = t end
    end
  end
  return AS.byId[id]
end
function AS.Age() local d = store(); return d and d.t and (time() - d.t) or nil end
function AS.CooldownLeft()
  local last = type(OneForAllDB) == "table" and OneForAllDB.ahScanLast or 0
  return math.max(0, COOLDOWN - (time() - last))
end

-- reading the scan --------------------------------------------------------------------------------------------------
local btn, state, token, progress, lastDone = nil, "idle", 0, 0, -100
local updateButton
local function readScan()
  local A = C_AuctionHouse
  if not (A and A.GetNumReplicateItems and A.GetReplicateItemInfo) then return end
  sets()
  token = token + 1
  local my, total, fixed, var, pending = token, A.GetNumReplicateItems() or 0, {}, {}, {}
  local me = UnitName and UnitName("player")
  state, progress = "reading", 0; updateButton()
  local function add(t, key, p) if not t[key] or p < t[key] then t[key] = p end end
  local function finish()
    if my ~= token then return end
    -- an empty list (the auction house closed, or nothing came) keeps the old prices
    if total > 0 and type(OneForAllDB) == "table" then
      OneForAllDB.ahScan = OneForAllDB.ahScan or {}
      OneForAllDB.ahScan[realmKey()] = { t = time(), fixed = fixed, var = var }
      AS.gen = AS.gen + 1
      -- a short line in the chat when it is done (user 21.11.)
      if FLT.Msg then FLT.Msg(string.format(L["Cheap Upgrade Scan complete: %d items scanned."], total)) end
    end
    state, lastDone = "idle", GetTime(); updateButton()
  end
  local function retry(n)
    if my ~= token then return end
    local left = {}
    for _, p in ipairs(pending) do
      local link = A.GetReplicateItemLink and A.GetReplicateItemLink(p[1])
      local key = link and AS.Variant(link)
      if key then add(var, key, p[2]) else left[#left + 1] = p end
    end
    pending = left
    if #pending > 0 and n < 3 and C_Timer then C_Timer.After(2, function() retry(n + 1) end) else finish() end
  end
  local function part(first)
    if my ~= token then return end
    local last = math.min(first + BATCH, total) - 1
    for i = first, last do
      -- name, texture, count, quality, usable, level, levelType, minBid, minIncrement, buyout, bid, highBidder,
      -- bidder, owner, ownerFull, saleStatus, itemID, hasAllInfo
      local _, _, count, _, _, _, _, _, _, buyout, _, _, _, owner, _, _, id, hasAll = A.GetReplicateItemInfo(i)
      if id and buyout and buyout > 0 and (count or 1) <= 1 and owner ~= me then
        if fixedSet[id] then add(fixed, id, buyout)
        elseif randSet[id] then
          local link = hasAll and A.GetReplicateItemLink and A.GetReplicateItemLink(i)
          local key = link and AS.Variant(link)
          if key then add(var, key, buyout)
          else
            pending[#pending + 1] = { i, buyout }
            if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
          end
        end
      end
    end
    progress = total > 0 and math.floor((last + 1) / total * 100) or 100; updateButton()
    if last + 1 < total and C_Timer then C_Timer.After(0, function() part(last + 1) end)
    elseif #pending > 0 and C_Timer then C_Timer.After(1, function() retry(1) end)
    else finish() end
  end
  part(0)
end
AS._read = readScan -- tests

local ev = CreateFrame("Frame")
local function start()
  if state ~= "idle" or not (C_AuctionHouse and C_AuctionHouse.ReplicateItems) then return end
  if type(OneForAllDB) == "table" then OneForAllDB.ahScanLast = time() end
  state = "waiting"; updateButton()
  C_AuctionHouse.ReplicateItems()
  -- no answer (another addon's scan is less than 15 minutes old): read what the client has, if anything
  local my = token
  if C_Timer then C_Timer.After(15, function()
    if state ~= "waiting" or my ~= token then return end
    if (C_AuctionHouse.GetNumReplicateItems() or 0) > 0 then readScan()
    else state = "idle"; updateButton(); if FLT.Msg then FLT.Msg(L["The auction house allows a full scan only every 15 minutes - try again later."]) end end
  end) end
end
AS.Start = start

-- the button: left of the favorites star in the search bar ---------------------------------------------------------
-- "12 Min." / "3 Hr." in the client's language (the game's own SecondsToTime)
local function fmtAge(s)
  s = math.max(60, s)
  local t = SecondsToTime and SecondsToTime(s, true, false, 1)
  if type(t) == "string" and t ~= "" then return t end
  return string.format("%d min", math.floor(s / 60))
end
AS.FormatAge = fmtAge
updateButton = function()
  if not btn then return end
  local label = btn._label
  if state == "reading" then label:SetText(string.format(L["Scan %d%%"], progress))
  elseif state == "waiting" then label:SetText(L["Scan..."])
  else label:SetText(L["Cheap Upgrade Scan"]) end
  if btn.SetLook then btn:SetLook(state == "idle" and AS.CooldownLeft() == 0) end
end
local function tooltip(self)
  GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
  GameTooltip:AddLine(L["Cheap Upgrade Scan"])
  GameTooltip:AddLine(L["Reads the whole auction house and keeps the cheapest price of every Bind on Equip piece of gear - items with a random bonus (\"of the Eagle\", \"of the Bear\" ...) each with their own price. Auctionator keeps only one price per item, whatever its bonus."], 1, 1, 1, true)
  GameTooltip:AddLine(L["The prices are used by Armory > Gear Planner > Cheap Upgrades."], 1, 1, 1, true)
  GameTooltip:AddLine(L["Blizzard allows a full scan only once every 15 minutes, for all addons together. A full scan of another addon is read along."], 0.7, 0.7, 0.7, true)
  local age = AS.Age()
  GameTooltip:AddLine(age and string.format(L["Last scan here: %s ago"], fmtAge(age)) or L["No scan here yet."], 1, 0.82, 0)
  local left = AS.CooldownLeft()
  if left > 0 then GameTooltip:AddLine(string.format(L["Ready again in about %s."], fmtAge(left)), 1, 0.5, 0.3) end
  GameTooltip:AddLine(L["Can be switched off: Quality of Life > Loot & Vendors."], 0.5, 0.5, 0.5, true)
  GameTooltip:Show()
end
local function makeButton()
  local ah = AuctionHouseFrame
  if btn or type(ah) ~= "table" or not (FLT.UI and FLT.UI.GoldButton) then return end
  -- "Cheap Upgrade Scan" (6.2.13-beta21, user 21.11.: the name says what it is for): a bit smaller text so it still fits
  -- between the portrait and the star
  -- on the search bar of the Buy page, so it is only shown there (user 21.11.: it stood on Sell and Auctionator's pages too)
  local bar = type(ah.SearchBar) == "table" and ah.SearchBar.GetFrameLevel and ah.SearchBar or ah
  btn = FLT.UI.GoldButton(bar, L["Cheap Upgrade Scan"], 118, 22, nil, 10)
  local star = bar ~= ah and bar.FavoritesSearchButton
  if star then btn:SetPoint("RIGHT", star, "LEFT", -6, 0) else btn:SetPoint("TOPLEFT", ah, "TOPLEFT", 52, -43) end
  btn:SetFrameLevel((bar:GetFrameLevel() or 1) + 10)
  btn:SetScript("OnClick", function(self) if AS.CooldownLeft() == 0 then start() end; tooltip(self) end)
  btn:SetScript("OnEnter", tooltip)
  btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

ev:RegisterEvent("AUCTION_HOUSE_SHOW")
ev:RegisterEvent("AUCTION_HOUSE_CLOSED")
ev:SetScript("OnEvent", function(_, e)
  if e == "AUCTION_HOUSE_SHOW" then
    if not on() then if btn then btn:Hide() end return end
    FLT.SafeCall("AHScan", makeButton)
    if btn then btn:Show(); updateButton() end
    ev:RegisterEvent("REPLICATE_ITEM_LIST_UPDATE")
  elseif e == "AUCTION_HOUSE_CLOSED" then
    ev:UnregisterEvent("REPLICATE_ITEM_LIST_UPDATE")
    if state ~= "idle" then token = token + 1; state = "idle"; updateButton() end
  elseif e == "REPLICATE_ITEM_LIST_UPDATE" then
    -- ours or another addon's full scan: read once (the event can come more than once), the 15 minutes start now
    if state == "reading" or (state == "idle" and GetTime() - lastDone < 10) then return end
    if state == "idle" and type(OneForAllDB) == "table" then OneForAllDB.ahScanLast = time() end
    FLT.SafeCall("AHScan", readScan)
  end
end)
