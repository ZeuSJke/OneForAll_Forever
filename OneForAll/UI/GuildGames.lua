local _, FLT = ...
FLT.DOT = FLT.DOT or "·" -- separator dot (Locales/Locale.lua; another one on Russian clients)
-- a readable text from the game or nil (FLT.Str in Core.lua; the same here for the mock tests, no extra local)
FLT.Str = FLT.Str or function(v) if type(v) ~= "string" or (issecretvalue and issecretvalue(v)) then return nil end return v end
local L = FLT.L or setmetatable({}, { __index = function(_, k) return k end })
local function N(s) return s end

-- Guild Games (since 6.2.12-beta4, built on branch claude/guild-games; user 14.11.2026: "ein feature einbauen um mit gildenleuten spielen zu koennen";
-- kept out of the normal releases until the user says so).
-- * Only for the guild, only for members who switched "Play with Guildies" on (QoL > Guild, off by default).
-- * /ofa play, the info bar element "Guild Games" or the key binding open the window.
-- * The host opens a room for one game, invites guild members (they get a small popup: accept / decline) and starts it.
-- * Games: Death Roll, High / Low (both with the game's own /roll) and Tic Tac Toe (two players, more watch).
-- * Gold stakes are only written down: the addon cannot move gold, the players trade it themselves.
-- * No leaderboard (removed in gg18, user 14.11.: "ich wuerde leaderboard entfernen"); every player keeps own statistics
--   (My History).
-- Protocol (addon prefix OFAGG, fields split by a tab, first field the message type):
--   GUILD   HI <ver> | BYE | TBL / TBLX (open tables) | TQ
--   WHISPER HERE | INV <room> <game> <stake> | ACC <room> | DEC <room> <reason> | ST <room> <state> |
--           ACT <room> <action> <args> | LEAVE <room> | CLOSE <room>
-- The host keeps the room and decides everything (rolls are checked against the expected range); the others only send
-- their actions. Lean: no events at all while the switch is off; CHAT_MSG_SYSTEM only while an own roll is pending.

local UI = FLT.UI
local GG = {}
FLT.GuildGames = GG

local PREFIX, VER = "OFAGG", "1"
local GAMES = {
  { key = "deathroll", name = N"Death Roll", icon = "Interface\\Icons\\INV_Misc_Bone_HumanSkull_01", max = 10,
    desc = N"Take turns rolling. The first roll goes from 1 to 1000, every next one from 1 to the last result. Whoever rolls a 1 loses.\nStake: the loser pays it to the winner (with more than two players: to the one who rolled before)." },
  { key = "highlow", name = N"High / Low", icon = "Interface\\Buttons\\UI-GroupLoot-Dice-Up", max = 10,
    desc = N"Everyone rolls once. The highest roll wins, the lowest loses; ties roll again.\nStake: everyone rolls from 1 to the stake, the lowest pays the highest the difference (without a stake: 1 to 100, points only)." },
  { key = "ttt", name = N"Tic Tac Toe", icon = "Interface\\Icons\\INV_Misc_Note_02", max = 2,
    desc = N"Two players, three in a row wins. More invited players watch.\nStake: the loser pays it to the winner; a draw pays nothing." },
}
local GAME = {}; for _, g in ipairs(GAMES) do GAME[g.key] = g end
local TURN_TIME = 90       -- seconds for a roll or a move, then the player gives up
local INVITE_TIME = 30     -- the invite popup closes itself

-- ---------------------------------------------------------------- helpers
local function on() return FLT.QoL and FLT.QoL.Get and FLT.QoL.Get("guildGames") end
-- One spelling for every name: "Name-Realm" with the character name only (gg1, user 14.11.: he showed up as a second player
-- and could invite himself - the names of one character came in two spellings; a display name with a second word, e.g. a
-- surname, is cut to the first word). Every key, compare and whisper target goes through full().
-- 6.2.11-gg25 (user 17.11.: no invite popup at the other player, he did not see the table): the surname STAYS. On Forever
-- characters share a first name ("Knikin Granitfaust"); a whisper to "Knikin-Realm" never reached him. Our own full name
-- (UnitName gives the first name only) comes from the guild roster by GUID or from the echo of our own HI (it carries our GUID).
-- gg26 (user 17.11. 22:48, /ofa play debug): NO realm. Forever delivers guild senders without one ("Knikin Granitfaust"), and
-- every client's own realm name differs (CAMWOWEU4Realm5PvE / CAMWOWEU5Realm5PvE) - adding ours made the whisper target wrong.
-- The name as the server gives it, a realm part (roster) taken off: "First Surname".
local function full(name)
  if not name or name == "" then return nil end
  local base = (name:match("^(.-)%-[^%-]+$") or name):gsub("^%s+", ""):gsub("%s+$", "")
  return base ~= "" and base or nil
end
local myFull -- our own full name, learned (roster GUID / echo of HI)
local function me()
  if myFull then return myFull end
  local f = type(OneForAllCharDB) == "table" and OneForAllCharDB.fullName -- with surname (Professions guild sharing)
  return full(f or (UnitName and UnitName("player")))
end
local debugOn -- /ofa play debug: every message sent and received in the chat
local function short(name) return name and name:match("^([^%s%-]+)") or "?" end
local function guild() return IsInGuild and IsInGuild() and GetGuildInfo and GetGuildInfo("player") or nil end
local function busy()
  if UnitAffectingCombat and UnitAffectingCombat("player") then return "combat" end
  local inst, kind -- not "a, b = f and f()": the "and" keeps one value (kind was always nil; gg31)
  if IsInInstance then inst, kind = IsInInstance() end
  if inst and (kind == "party" or kind == "raid" or kind == "pvp" or kind == "arena") then return "instance" end
end
local bots      -- test bots (/ofa play bots): full name -> true, nil when off
local botMsg     -- set below: a bot answers what the host whispers to it
local function send(msg, channel, target)
  if channel == "WHISPER" and bots and bots[target] then botMsg(msg, target); return end
  if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then return end
  if channel == "WHISPER" and target == me() then GG.Receive(msg, me(), "WHISPER"); return end
  local ok, res = pcall(C_ChatInfo.SendAddonMessage, PREFIX, msg, channel, target)
  if debugOn and FLT.Msg then FLT.Msg("GG > " .. channel .. (target and (" " .. target) or "") .. ": " .. msg:gsub("\t", " ") .. "  [" .. tostring(ok and res) .. "]") end
end
local function pack(...) local t = { ... }; for i = 1, select("#", ...) do t[i] = tostring(t[i] == nil and "" or t[i]) end; return table.concat(t, "\t") end
-- what the others need for the portrait on the table (gg4): race, sex, class, level
local function myInfo()
  -- select(2, ...): "local _, race = UnitRace and UnitRace(...)" keeps ONE value (the "and" cuts the list) - race and class
  -- were always empty and every portrait a question mark (gg31, user 17.11. 23:17)
  local race = UnitRace and select(2, UnitRace("player"))
  local class = UnitClass and select(2, UnitClass("player"))
  -- the GUID last (gg25): our own HI coming back tells us our full name; older versions ignore the extra field
  return race or "", UnitSex and UnitSex("player") or 2, class or "", UnitLevel and UnitLevel("player") or 0, UnitGUID and UnitGUID("player") or ""
end
local function db()
  if type(OneForAllDB) ~= "table" then return {} end
  local d = OneForAllDB.guildGames
  if not d then d = {}; OneForAllDB.guildGames = d end
  if (d.v or 1) < 2 then -- gg15: results and statistics count copper instead of gold (silver stakes)
    for _, games in pairs(d.stats or {}) do for _, e in pairs(games) do e.gw = (e.gw or 0) * 10000; e.gl = (e.gl or 0) * 10000 end end
    d.v = 2
  end
  d.results = nil -- the leaderboard's log (until gg17)
  return d
end
-- stakes are whole gold or whole silver coins (gg15, user 14.11.: "eher um silber ... auch um silber spielen"):
-- room.unit "g" | "s"; stake, pay and High / Low ranges count in that coin, lists and statistics in copper
local UNIT = { g = 10000, s = 100 }
local function coins(n, u)
  n = tonumber(n) or 0
  return n > 0 and (n .. "|TInterface\\MoneyFrame\\UI-" .. (u == "s" and "Silver" or "Gold") .. "Icon:0|t") or ""
end
local function copperOf(n, u) return (tonumber(n) or 0) * (UNIT[u] or UNIT.g) end

-- ---------------------------------------------------------------- guild roster and who plays
local members = {}   -- full name -> true (guild roster, online or not)
local players = {}   -- full name -> time we last heard of them (switch on and online)
local rosterPending
local function readRoster()
  rosterPending = nil
  wipe(members)
  local offline = room and {} or nil
  local n = GetNumGuildMembers and GetNumGuildMembers() or 0
  local myGUID = UnitGUID and UnitGUID("player")
  for i = 1, n do
    local name, _, _, _, _, _, _, _, online, _, _, _, _, _, _, _, guid = GetGuildRosterInfo(i)
    name = full(name)
    if name then
      members[name] = true; if not online then players[name] = nil; if offline then offline[name] = true end end
      if guid and myGUID and guid == myGUID then myFull = name end
    end
  end
  if FLT.InfoBar and FLT.InfoBar.Refresh then FLT.InfoBar.Refresh("games") end
  if offline and GG._checkOffline then GG._checkOffline(offline) end
  if GG.window and GG.window:IsShown() then GG.Refresh() end
end
local function inGuild(name) return name == me() or members[name] or (bots and bots[name]) end

-- ---------------------------------------------------------------- gold owed (gg6)
-- User 14.11.: "eine spalte mit zu zahlenden betraegen ... kann das addon erkennen wer wem gold gibt? und das automatisch zu
-- pflegen? ... eine eigene liste wer mir noch gold schuldet oder wem ich noch gold schulde". Every client keeps its own
-- list: OneForAllDB.guildGames.debts[guild][short name] = copper, > 0 = they owe me, < 0 = I owe them. A finished game I
-- played in adds to it; a trade with that player takes gold off it (what I get from someone who owes me, what I give to
-- someone I owe - never past zero, so other trades do not count); "Settled" clears an entry by hand.
local sessionPays = {} -- the payments of the games in the room I am in: { from, to, copper }
local function debts()
  local g = guild(); if not g then return {} end
  local d = db(); d.debts = d.debts or {}
  d.debts[g] = d.debts[g] or {}
  return d.debts[g]
end
function GG.Debts()
  local out = {}
  for name, c in pairs(debts()) do if c ~= 0 then out[#out + 1] = { name = name, copper = c } end end
  table.sort(out, function(a, b) return math.abs(a.copper) > math.abs(b.copper) end)
  return out
end
function GG.Settle(name) debts()[name] = nil; if GG.Refresh then GG.Refresh() end end
-- copper as gold / silver / copper with the coin icons (gg19: the fallback showed "0g" for silver stakes - the Forever
-- client has no GetCoinTextureString)
local COIN = { "|TInterface\\MoneyFrame\\UI-GoldIcon:0|t", "|TInterface\\MoneyFrame\\UI-SilverIcon:0|t",
  "|TInterface\\MoneyFrame\\UI-CopperIcon:0|t" }
local function money(c)
  c = math.abs(math.floor(c or 0))
  local g, sv, co = math.floor(c / 10000), math.floor(c % 10000 / 100), c % 100
  local t = {}
  if g > 0 then t[#t + 1] = g .. COIN[1] end
  if sv > 0 then t[#t + 1] = sv .. COIN[2] end
  if co > 0 or #t == 0 then t[#t + 1] = co .. COIN[3] end
  return table.concat(t, " ")
end
-- a finished game: write down what the loser pays (only my own part goes into my list)
-- my own statistics (gg14, user 14.11.: "My History ... wieviel ich verloren und gewonnen habe und die differenz"):
-- per character and game { w, l, d (draws), gw, gl (copper won / lost) }
local function myStats()
  local d = db(); d.stats = d.stats or {}
  local k = me() or "?"
  d.stats[k] = d.stats[k] or {}
  return d.stats[k]
end
local function countGame(r)
  local g = GAME[r.game]; if not g then return end
  local mine, idx = short(me()), nil
  for i, p in ipairs(r.players) do if i <= g.max and short(p) == mine then idx = i end end
  if not idx then return end -- watching
  local st = myStats(); st[r.game] = st[r.game] or { w = 0, l = 0, d = 0, gw = 0, gl = 0 }
  local e, pay = st[r.game], copperOf(r.pay, r.unit)
  if r.win == idx then e.w = e.w + 1; e.gw = e.gw + pay
  elseif r.lose == idx then e.l = e.l + 1; e.gl = e.gl + pay
  elseif (r.win or 0) == 0 and (r.lose or 0) == 0 then e.d = e.d + 1 end
end
function GG.Stats() return myStats() end
function GG.ResetStats() local d = db(); if d.stats then d.stats[me() or "?"] = nil end; GG.Refresh() end

local function settleGame(r)
  countGame(r)
  local w, l = r.players[r.win], r.players[r.lose]
  if not (w and l) or (r.pay or 0) <= 0 then return end
  w, l = short(w), short(l)
  local c = copperOf(r.pay, r.unit)
  table.insert(sessionPays, 1, { from = l, to = w, copper = c })
  local mine, d = short(me()), debts()
  if w == mine then d[l] = (d[l] or 0) + c
  elseif l == mine then d[w] = (d[w] or 0) - c end
end
-- trades: who, what I give, what I get - applied when the game says the trade is complete
local trade = {}
local function tradeEvent(event, a, b)
  if event == "TRADE_SHOW" then
    trade = { who = UnitName and FLT.Str(UnitName("NPC")) }
  elseif event == "TRADE_MONEY_CHANGED" or event == "TRADE_ACCEPT_UPDATE" then
    trade.give = GetPlayerTradeMoney and GetPlayerTradeMoney() or 0
    trade.get = GetTargetTradeMoney and GetTargetTradeMoney() or 0
    trade.who = trade.who or (UnitName and FLT.Str(UnitName("NPC")))
  elseif event == "UI_INFO_MESSAGE" then
    local msgText = FLT.Str(b) or FLT.Str(a)
    if msgText ~= (ERR_TRADE_COMPLETE or "Trade complete.") or not trade.who then return end
    local name, d = short(trade.who), debts()
    local c = d[name] or 0
    if c > 0 and (trade.get or 0) > 0 then c = math.max(0, c - trade.get) end
    if c < 0 and (trade.give or 0) > 0 then c = math.min(0, c + trade.give) end
    if c ~= (d[name] or 0) then
      d[name] = c ~= 0 and c or nil
      if FLT.Msg then FLT.Msg(c == 0 and string.format(L["Guild Games: all settled with %s."], name)
        or string.format(c > 0 and L["Guild Games: %s still owes you %s."] or L["Guild Games: you still owe %s %s."], name, money(c))) end
      if GG.Refresh then GG.Refresh() end
    end
    trade = {}
  elseif event == "TRADE_CLOSED" then
    -- the completion message comes right after the close; keep the numbers for a moment
    C_Timer.After(1, function() if trade.closedAt then trade = {} end end); trade.closedAt = true
  end
end

-- ---------------------------------------------------------------- rooms
-- room (the same table on every member, the host's is the truth):
--   id, game, stake, host (full), players { full names } (the first max ones play), phase "lobby" | "play" | "done",
--   turn (index into players), cur (Death Roll: highest roll now), rolls { [i] = n } (High / Low), board (9 chars),
--   win / lose (indexes), pay (gold), ev (last event, for the log)
local room          -- the room we are in (host or member)
-- open tables of other guild members (gg11, user 14.11.: "ein Punkt Open Table wo bereits geoeffnete Spiele angezeigt
-- werden, wo ich dazu schalten kann"): host full name -> { id, game, stake, n, phase }. Hosts announce their table in the
-- guild when it changes (TBL, debounced) and when it closes (TBLX); opening the window asks for them (TQ, max every 10 s)
local tables = {}
local tableSig, tableTimer, lastTQ
local pendingInvite -- { host, room, game, stake, time }
local turnTimer, pendingRoll
local counter = 0

local function isHost() return room and room.host == me() end
-- a seat goes away: the result's seat numbers follow (gg13; before, a player leaving after the end moved the "won" mark)
local function dropSeat(i)
  table.remove(room.players, i)
  if room.win == i then room.win = 0 elseif (room.win or 0) > i then room.win = room.win - 1 end
  if room.lose == i then room.lose = 0 elseif (room.lose or 0) > i then room.lose = room.lose - 1 end
  if room.rolls and i <= #room.rolls then table.remove(room.rolls, i) end
end
local function playing() if not room then return {} end; local t = {}; for i = 1, math.min(#room.players, GAME[room.game].max) do t[i] = room.players[i] end; return t end
local function myIndex() if not room then return nil end; local m = short(me()); for i, p in ipairs(room.players) do if short(p) == m then return i end end end

local log = {}
local function addLog(text) log[#log + 1] = text; if #log > 40 then table.remove(log, 1) end end

-- one line for an event, the same text on every member
local function eventText(ev)
  if not ev or ev == "" then return nil end
  local k, a, b, c = strsplit(":", ev)
  if k == "r" then return string.format(L["%s rolls %s (1-%s)"], a, b, c)
  elseif k == "m" then return string.format(L["%s takes field %s"], a, b)
  elseif k == "tie" then return L["A tie - the tied players roll again."]
  elseif k == "out" then return string.format(L["%s gave up (no answer in time)."], a)
  elseif k == "left" then return string.format(L["%s left the table."], a)
  elseif k == "join" then return string.format(L["%s joined."], a)
  elseif k == "host" then return string.format(L["%s is the new host."], a)
  elseif k == "stake" then return string.format(L["The host changed the stake to %s."], coins(a, b))
  elseif k == "start" then return L["The game starts."] end
end

-- state string: field=value pairs split by ";", lists by ","
local function serialize(r)
  -- short names: ten full names would not fit into one addon message (255 bytes); the members only show them
  local p = {}; for i, n in ipairs(r.players) do p[i] = short(n) end
  local rolls = {}; for i = 1, #r.players do rolls[i] = r.rolls and r.rolls[i] or "" end
  return table.concat({ "g=" .. r.game, "s=" .. (r.stake or 0), "u=" .. (r.unit or "g"), "h=" .. r.host, "p=" .. table.concat(p, ","), "ph=" .. r.phase,
    "t=" .. (r.turn or 0), "c=" .. (r.cur or 0), "r=" .. table.concat(rolls, ","), "b=" .. (r.board or ""),
    "w=" .. (r.win or 0), "l=" .. (r.lose or 0), "pay=" .. (r.pay or 0), "ev=" .. (r.ev or ""),
    "wt=" .. table.concat((function() local t = {}; for i, n in ipairs(r.waiting or {}) do t[i] = short(n) end; return t end)(), ",") }, ";")
end
local function deserialize(id, s)
  local r = { id = id }
  for kv in s:gmatch("[^;]+") do
    local k, v = kv:match("^(%w+)=(.*)$")
    if k then r[k] = v end
  end
  local out = { id = id, game = r.g, stake = tonumber(r.s) or 0, unit = r.u == "s" and "s" or "g", host = r.h, players = {}, phase = r.ph, turn = tonumber(r.t) or 0,
    cur = tonumber(r.c) or 0, rolls = {}, board = r.b or "", win = tonumber(r.w) or 0, lose = tonumber(r.l) or 0,
    pay = tonumber(r.pay) or 0, ev = r.ev }
  for n in (r.p or ""):gmatch("[^,]+") do out.players[#out.players + 1] = n end
  out.waiting = {}; for n in (r.wt or ""):gmatch("[^,]+") do out.waiting[#out.waiting + 1] = n end
  local i = 0
  for v in ((r.r or "") .. ","):gmatch("([^,]*),") do i = i + 1; out.rolls[i] = tonumber(v) end
  return out
end

local function announceTable(to)
  if not (room and isHost()) then return end
  send(pack("TBL", room.id, room.game, room.stake or 0, #room.players + #(room.waiting or {}), room.phase, room.unit or "g"), to and "WHISPER" or "GUILD", to)
end
local function tableChanged()
  if not (room and isHost()) then return end
  local sig = room.id .. room.game .. (room.stake or 0) .. (room.unit or "g") .. (#room.players + #(room.waiting or {})) .. room.phase
  if sig == tableSig or tableTimer then return end
  tableTimer = true
  C_Timer.After(1, function()
    tableTimer = nil
    if not (room and isHost()) then return end
    tableSig = room.id .. room.game .. (room.stake or 0) .. (room.unit or "g") .. (#room.players + #(room.waiting or {})) .. room.phase
    announceTable()
  end)
end

local function broadcast()
  if not isHost() then return end
  tableChanged()
  local st = serialize(room)
  for _, p in ipairs(room.players) do if p ~= me() then send(pack("ST", room.id, st), "WHISPER", p) end end
  for _, p in ipairs(room.waiting or {}) do send(pack("ST", room.id, st), "WHISPER", p) end
  local t = eventText(room.ev); if t then addLog(t) end
  room.ev = nil
  GG.Refresh()
end

local function stopTurnTimer() if turnTimer then turnTimer:Cancel(); turnTimer = nil end end
local finish
local function startTurnTimer()
  stopTurnTimer()
  if not isHost() or room.phase ~= "play" then return end
  local rid, who = room.id, room.turn
  turnTimer = C_Timer.NewTimer(TURN_TIME, function()
    turnTimer = nil
    if not (room and room.id == rid and room.phase == "play") then return end
    if room.game == "highlow" then -- everyone who has not rolled gives up: lowest
      for i = 1, #playing() do if not room.rolls[i] then room.ev = "out:" .. short(room.players[i]); room.rolls[i] = 0 end end
      finish("highlow")
    elseif room.turn == who then
      room.ev = "out:" .. short(room.players[who])
      local pl = playing()
      if #pl == 2 then finish(room.game, who % 2 + 1, who) else finish(room.game, (who - 2) % #pl + 1, who) end
    end
  end)
end

-- host: the game is over (winner / loser indexes; High / Low works them out itself)
finish = function(game, w, l)
  stopTurnTimer()
  if game == "highlow" and w and l then
    -- someone left the running game (gg27, user 17.11. 22:55: "Leave" gave "attempt to compare nil with number" - the
    -- players without a roll had no number): the one who left loses the whole stake, no roll-off
    room.pay = room.stake or 0
  elseif game == "highlow" then
    local pl, hi, lo = playing(), nil, nil
    local function val(i) return room.rolls[i] or 0 end -- no roll (time ran out) = lowest
    for i = 1, #pl do
      if not hi or val(i) > val(hi) then hi = i end
      if not lo or val(i) < val(lo) then lo = i end
    end
    -- ties at the top or the bottom roll again
    local tie = false
    for i = 1, #pl do
      if i ~= hi and val(i) == val(hi) then tie = true end
      if i ~= lo and val(i) == val(lo) then tie = true end
    end
    if tie and #pl > 1 then
      local top, bot = val(hi), val(lo)
      for i = 1, #pl do if val(i) == top or val(i) == bot then room.rolls[i] = nil end end
      room.ev = "tie"; broadcast(); startTurnTimer(); return
    end
    w, l = hi, lo
    room.pay = (room.stake or 0) > 0 and (val(hi) - val(lo)) or 0
  else
    room.pay = room.stake or 0
  end
  room.win, room.lose, room.phase = w or 0, l or 0, "done"
  settleGame(room)
  broadcast()
end

local function newRoom(game, stake, unit)
  wipe(sessionPays)
  counter = counter + 1
  room = { id = short(me()) .. time() .. counter, game = game, stake = math.max(0, math.floor(tonumber(stake) or 0)), unit = unit == "s" and "s" or "g",
    host = me(), players = { me() }, phase = "lobby", turn = 0, cur = 0, rolls = {}, board = "" }
  wipe(log)
  tableSig = nil; tableChanged()
  GG.Refresh()
end

-- the host changes the stake between games (gg8, user 14.11.: "das gold innerhalb einer runde anzupassen durch den
-- host"); not while a game runs, High / Low rolls up to the stake
function GG.SetStake(v, unit)
  if not (room and isHost()) or room.phase == "play" then return end
  v = math.max(0, math.floor(tonumber(v) or 0)); unit = unit or room.unit or "g"
  if v == (room.stake or 0) and unit == (room.unit or "g") then return end
  room.stake, room.unit = v, unit; room.ev = "stake:" .. v .. ":" .. unit
  broadcast()
end

local function startGame()
  if not isHost() or room.phase == "play" then return end
  -- who was invited during a game sits down now (gg7, user 14.11.: "es sollte immer moeglich sein, noch mehrere spieler
  -- einzuladen")
  for _, p in ipairs(room.waiting or {}) do room.players[#room.players + 1] = p end
  room.waiting = {}
  if #room.players < 2 then return end
  room.phase, room.turn, room.rolls, room.win, room.lose, room.pay = "play", 1, {}, 0, 0, 0
  room.cur = room.game == "deathroll" and 1000 or 0
  room.board = room.game == "ttt" and "---------" or ""
  room.ev = "start"
  broadcast(); startTurnTimer()
end

-- the next host when the host leaves (gg13, user 14.11.: "host sollte an einen anderen spieler uebergeben, wenn dieser
-- das spiel verlaesst"): the first other player at the table, else the first one waiting; never a test bot
local function successor()
  if not room then return nil end
  for _, p in ipairs(room.players) do if short(p) ~= short(room.host) and not (bots and bots[p]) then return p end end
  for _, p in ipairs(room.waiting or {}) do if not (bots and bots[p]) then return p end end
end
-- the host hands the table over: a running game is lost (like leaving), then the new host gets the state
local function handOver(nh)
  local m = me()
  if room.phase == "play" then
    local pl = playing()
    for i, p in ipairs(pl) do
      if p == m then room.ev = "left:" .. short(m); finish(room.game, #pl == 2 and (i % 2 + 1) or ((i - 2) % #pl + 1), i); break end
    end
  end
  for i = #room.players, 1, -1 do local p = room.players[i]; if p == m or (bots and bots[p]) then dropSeat(i) end end
  for i = #(room.waiting or {}), 1, -1 do if bots and bots[room.waiting[i]] then table.remove(room.waiting, i) end end
  room.host = nh; room.invited = nil; room.ev = "host:" .. short(nh)
  local st = serialize(room)
  for _, p in ipairs(room.players) do send(pack("ST", room.id, st), "WHISPER", p) end
  for _, p in ipairs(room.waiting or {}) do send(pack("ST", room.id, st), "WHISPER", p) end
  send(pack("TBLX", room.id), "GUILD"); tableSig = nil
end
-- we are the new host: names in the state are short, the host works with full names
-- a short name back to the full one with the surname (gg25): the players we heard from first, then the roster
local function resolve(n)
  if n == short(me()) then return me() end
  for name in pairs(players) do if short(name) == n then return name end end
  for name in pairs(members) do if short(name) == n then return name end end
  return full(n)
end
local function becomeHost()
  for i, p in ipairs(room.players) do room.players[i] = resolve(p) end
  for i, p in ipairs(room.waiting or {}) do room.waiting[i] = resolve(p) end
  room.host = me(); room.invited = {}
  tableSig = nil; tableChanged()
end

local function closeRoom(silent)
  stopTurnTimer(); pendingRoll = nil
  local nh = room and isHost() and not silent and successor()
  if nh then handOver(nh)
  elseif room then
    if isHost() then
      for _, p in ipairs(room.players) do if p ~= me() then send(pack("CLOSE", room.id), "WHISPER", p) end end
      for _, p in ipairs(room.waiting or {}) do send(pack("CLOSE", room.id), "WHISPER", p) end
      send(pack("TBLX", room.id), "GUILD"); tableSig = nil
    elseif not silent then send(pack("LEAVE", room.id), "WHISPER", room.host) end
  end
  room = nil
  wipe(log)
  GG.Refresh()
end

-- ---------------------------------------------------------------- actions (host checks them)
local function applyAction(from, action, a, b, c)
  if not (room and isHost() and room.phase == "play") then return end
  local idx; for i, p in ipairs(playing()) do if p == from then idx = i end end
  if not idx then return end
  if room.game == "deathroll" and action == "roll" then
    local v, lo, hi = tonumber(a), tonumber(b), tonumber(c)
    if idx ~= room.turn or lo ~= 1 or hi ~= room.cur or not v or v < 1 or v > hi then return end
    room.ev = "r:" .. short(from) .. ":" .. v .. ":" .. hi
    room.rolls[idx] = v -- the chip in front of the seat (gg4)
    local pl = playing()
    if v == 1 then
      local prev = (idx - 2) % #pl + 1
      finish("deathroll", #pl == 2 and (idx % 2 + 1) or prev, idx)
    else
      room.cur = v; room.turn = idx % #pl + 1
      broadcast(); startTurnTimer()
    end
  elseif room.game == "highlow" and action == "roll" then
    local v, lo, hi = tonumber(a), tonumber(b), tonumber(c)
    local max = (room.stake or 0) > 0 and room.stake or 100
    if room.rolls[idx] or lo ~= 1 or hi ~= max or not v or v < 1 or v > hi then return end
    room.rolls[idx] = v
    room.ev = "r:" .. short(from) .. ":" .. v .. ":" .. hi
    local all = true; for i = 1, #playing() do if not room.rolls[i] then all = false end end
    if all then finish("highlow") else broadcast() end
  elseif room.game == "ttt" and action == "move" then
    local f = tonumber(a)
    if idx ~= room.turn or not f or f < 1 or f > 9 or room.board:sub(f, f) ~= "-" then return end
    local mark = idx == 1 and "X" or "O"
    room.board = room.board:sub(1, f - 1) .. mark .. room.board:sub(f + 1)
    room.ev = "m:" .. short(from) .. ":" .. f
    local B = room.board
    for _, l3 in ipairs({ { 1, 2, 3 }, { 4, 5, 6 }, { 7, 8, 9 }, { 1, 4, 7 }, { 2, 5, 8 }, { 3, 6, 9 }, { 1, 5, 9 }, { 3, 5, 7 } }) do
      if B:sub(l3[1], l3[1]) == mark and B:sub(l3[2], l3[2]) == mark and B:sub(l3[3], l3[3]) == mark then
        finish("ttt", idx, idx % 2 + 1); return
      end
    end
    if not B:find("-", 1, true) then finish("ttt", 0, 0); return end -- draw
    room.turn = idx % 2 + 1
    broadcast(); startTurnTimer()
  end
end

local function act(action, ...)
  if not room then return end
  if isHost() then applyAction(me(), action, ...) else send(pack("ACT", room.id, action, ...), "WHISPER", room.host) end
end

function GG.Move(i) if room and room.game == "ttt" and room.phase == "play" then act("move", i) end end

-- own /roll: RandomRoll, then read the result from the system message
local rollEvents = CreateFrame("Frame")
local rollPattern, rollOrder
-- the game's roll text as a pattern. German and other clients number the fields ("%1$s würfelt. Ergebnis: %2$d (%3$d-%4$d)",
-- gg25: "invalid capture index" at Knikin, his rolls never counted); rollOrder[k] = which field the k-th capture is
local function makePattern()
  local s = RANDOM_ROLL_RESULT or "%s rolls %d (%d-%d)"
  local function esc(x) return (x:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%0")) end
  local parts, order, last = {}, {}, 1
  for st, pos, kind, en in s:gmatch("()%%(%d*)%$?([sd])()") do
    parts[#parts + 1] = esc(s:sub(last, st - 1))
    order[#order + 1] = tonumber(pos) or (#order + 1)
    parts[#parts + 1] = kind == "s" and "(.+)" or "(%d+)"
    last = en
  end
  parts[#parts + 1] = esc(s:sub(last))
  return "^" .. table.concat(parts) .. "$", order
end
-- who, value, low, high from a roll line (nil when it is no roll)
function GG.ParseRoll(text)
  if not rollPattern then rollPattern, rollOrder = makePattern() end
  local c = { text:match(rollPattern) }
  if not c[1] then return nil end
  local f = {}
  for k, v in ipairs(c) do f[rollOrder[k] or k] = v end
  return f[1], f[2], f[3], f[4]
end
rollEvents:SetScript("OnEvent", function(_, _, text)
  text = FLT.Str(text)
  if not (pendingRoll and text) then return end
  local who, v, lo, hi = GG.ParseRoll(text)
  if not who or short(who) ~= short(me()) then return end
  v, lo, hi = tonumber(v), tonumber(lo), tonumber(hi)
  if lo ~= 1 or hi ~= pendingRoll then return end
  pendingRoll = nil
  rollEvents:UnregisterEvent("CHAT_MSG_SYSTEM")
  act("roll", v, lo, hi)
end)
function GG.Roll()
  if not (room and room.phase == "play") or pendingRoll then return end
  local max = room.game == "deathroll" and room.cur or ((room.stake or 0) > 0 and room.stake or 100)
  if not max or max < 1 then return end
  pendingRoll = max
  rollEvents:RegisterEvent("CHAT_MSG_SYSTEM")
  C_Timer.After(10, function() if pendingRoll == max then pendingRoll = nil; rollEvents:UnregisterEvent("CHAT_MSG_SYSTEM") end end)
  RandomRoll(1, max)
end

-- ---------------------------------------------------------------- invites
local popup
-- sit down at a table: the host takes us by ACC (into the next game when one runs)
local function joinTable(id, host, game, stake, unit)
  if room then closeRoom() end
  send(pack("ACC", id), "WHISPER", host)
  room = { id = id, game = game, stake = stake, unit = unit, host = host, players = { host, me() }, phase = "lobby",
    turn = 0, cur = 0, rolls = {}, board = "" }
  wipe(log); wipe(sessionPays)
end
function GG.Join(host)
  local tb = tables[host]
  if not tb or room then return end
  if tb.bot then if FLT.Msg then FLT.Msg(L["Test table: bots do not host tables, nothing happens."]) end; return end
  joinTable(tb.id, host, tb.game, tb.stake, tb.unit)
  GG.view = tb.game
  GG.Refresh()
end

local snoozeUntil -- no invites until then (the invite's "Snooze 30 min", gg7)
function GG.SnoozeLeft() return snoozeUntil and math.max(0, math.ceil((snoozeUntil - GetTime()) / 60)) or 0 end
local function showInvite(inv)
  if not popup then
    local f = CreateFrame("Frame", "OneForAllGuildGamesInvite", UIParent)
    f:SetSize(400, 120); f:SetPoint("TOP", 0, -140); f:SetFrameStrata("FULLSCREEN_DIALOG"); f:EnableMouse(true)
    f:SetMovable(true); f:RegisterForDrag("LeftButton"); f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
    UI.FramedPanel(f)
    for _, t in ipairs(UI.OrnateFrame(f, f, 16, 3, "OVERLAY", 4)) do t:SetVertexColor(FLT.SkinC(1, 1, 1, 1)) end
    f.title = FLT.NewFS(f, nil, "OVERLAY", "GameFontNormal"); f.title:SetPoint("TOP", 0, -14); f.title:SetText(L["Guild Games"])
    f.title:SetTextColor(FLT.TextC(unpack(UI.GOLD)))
    f.text = FLT.NewFS(f, nil, "OVERLAY", "GameFontHighlight"); f.text:SetPoint("TOP", 0, -36); f.text:SetWidth(360); f.text:SetJustifyH("CENTER")
    f.no = UI.GoldButton(f, L["Decline"], 112, 24, nil, 13); f.no:SetPoint("BOTTOM", 0, 14)
    f.yes = UI.GoldButton(f, L["Accept"], 112, 24, nil, 13); f.yes:SetPoint("RIGHT", f.no, "LEFT", -8, 0)
    f.snooze = UI.GoldButton(f, L["Snooze 30 min"], 112, 24, nil, 12); f.snooze:SetPoint("LEFT", f.no, "RIGHT", 8, 0)
    f.snooze:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_BOTTOM"); GameTooltip:AddLine(L["Snooze 30 min"], 1, 0.82, 0)
      GameTooltip:AddLine(L["Declines this invite and every other one for 30 minutes. Reopening the Guild Games window ends it."], 1, 1, 1, true)
      GameTooltip:Show()
    end)
    f.snooze:SetScript("OnLeave", function() GameTooltip:Hide() end)
    popup = f
  end
  local f = popup
  local g = GAME[inv.game]
  f.text:SetText(string.format(L["%s invites you to %s."], short(inv.host), L[g.name]) ..
    ((inv.stake or 0) > 0 and ("\n" .. string.format(L["Stake: %s"], coins(inv.stake, inv.unit))) or ""))
  f:SetHeight(math.max(110, (f.text:GetStringHeight() or 14) + 80))
  if inv.test then -- /ofa play invite: only shows the window
    local function done(text) f:Hide(); pendingInvite = nil; if FLT.Msg then FLT.Msg(text) end end
    f.yes:SetScript("OnClick", function() done(L["Test invite: accepted (nothing happens)."]) end)
    f.no:SetScript("OnClick", function() done(L["Test invite: declined."]) end)
    f.snooze:SetScript("OnClick", function() done(L["Test invite: snoozed (nothing paused)."]) end)
    f:Show(); return
  end
  f.snooze:SetScript("OnClick", function()
    f:Hide()
    snoozeUntil = GetTime() + 1800
    if pendingInvite == inv then pendingInvite = nil; send(pack("DEC", inv.room, "snooze"), "WHISPER", inv.host) end
    if FLT.Msg then FLT.Msg(L["Guild Games: no invites for 30 minutes."]) end
  end)
  f.yes:SetScript("OnClick", function()
    f:Hide()
    if pendingInvite ~= inv then return end
    pendingInvite = nil
    joinTable(inv.room, inv.host, inv.game, inv.stake, inv.unit)
    GG.Open()
  end)
  f.no:SetScript("OnClick", function()
    f:Hide()
    if pendingInvite == inv then pendingInvite = nil; send(pack("DEC", inv.room, "no"), "WHISPER", inv.host) end
  end)
  f:Show()
  if PlaySound and SOUNDKIT and SOUNDKIT.IG_PLAYER_INVITE then pcall(PlaySound, SOUNDKIT.IG_PLAYER_INVITE) end
  C_Timer.After(INVITE_TIME, function()
    if pendingInvite == inv then pendingInvite = nil; f:Hide(); send(pack("DEC", inv.room, "timeout"), "WHISPER", inv.host) end
  end)
end

function GG.ToggleDebug()
  debugOn = not debugOn
  if FLT.Msg then FLT.Msg("Guild Games debug " .. (debugOn and "on" or "off") .. " - me: " .. tostring(me())) end
end
function GG.TestInvite()
  local inv = { host = "Botilda", room = "test", game = "deathroll", stake = 50, unit = "s", test = true }
  pendingInvite = inv
  showInvite(inv)
end

local lastInvite = {}
function GG.Invite(name)
  if not (room and isHost()) then return end
  for _, p in ipairs(room.players) do if p == name then return end end
  for _, p in ipairs(room.waiting or {}) do if p == name then return end end
  if lastInvite[name] and GetTime() - lastInvite[name] < 10 then return end -- no invite spam
  lastInvite[name] = GetTime()
  room.invited = room.invited or {}; room.invited[name] = "wait"
  send(pack("INV", room.id, room.game, room.stake or 0, room.unit or "g"), "WHISPER", name)
  GG.Refresh()
end

-- open tables of the others (gg35, user 17.11. 23:51: "(1)" behind "Guild Games" in the info bar, nothing at 0)
function GG.OpenTables()
  local n = 0
  for host in pairs(tables) do if host ~= me() and players[host] then n = n + 1 end end
  return n
end
local function tablesChanged()
  if FLT.InfoBar and FLT.InfoBar.Refresh then FLT.InfoBar.Refresh("games") end
  if GG.window and GG.window:IsShown() then GG.Refresh() end
end

-- ---------------------------------------------------------------- receiving
function GG.Receive(msg, sender, channel)
  if not on() then return end
  if debugOn and FLT.Msg then FLT.Msg("GG < " .. tostring(channel) .. " " .. tostring(sender) .. ": " .. tostring(msg):gsub("\t", " ")) end
  sender = full(sender)
  if not sender then return end
  local t = { strsplit("\t", msg) }
  local kind = t[1]
  -- our own HI / HERE (it carries our GUID): learn our full name with the surname, never list ourselves (gg25)
  local g = (kind == "HI" and t[7]) or (kind == "HERE" and t[6]) or nil
  if g and g ~= "" and UnitGUID and g == UnitGUID("player") then
    if myFull ~= sender then myFull = sender; players[sender] = nil; if GG.window and GG.window:IsShown() then GG.Refresh() end end
    return
  end
  if not inGuild(sender) then return end
  if kind == "HI" then
    players[sender] = { t = GetTime(), race = t[3], sex = t[4], class = t[5], level = t[6] }
    if sender ~= me() then send(pack("HERE", myInfo()), "WHISPER", sender) end
    tablesChanged() -- his table (heard before) counts now
  elseif kind == "HERE" then
    players[sender] = { t = GetTime(), race = t[2], sex = t[3], class = t[4], level = t[5] }
    tablesChanged()
  elseif kind == "TBL" then
    if sender ~= me() and GAME[t[3] or ""] then
      tables[sender] = { id = t[2], game = t[3], stake = tonumber(t[4]) or 0, n = tonumber(t[5]) or 1, phase = t[6], unit = t[7] == "s" and "s" or "g" }
      tablesChanged()
    end
  elseif kind == "TBLX" then
    if tables[sender] and tables[sender].id == t[2] then tables[sender] = nil; tablesChanged() end
  elseif kind == "TQ" then
    if sender ~= me() then announceTable(sender) end
  elseif kind == "BYE" then
    GG.Gone(sender)
  elseif kind == "INV" then
    local inv = { host = sender, room = t[2], game = t[3], stake = tonumber(t[4]) or 0, unit = t[5] == "s" and "s" or "g" }
    if not GAME[inv.game] then return end
    local why = (snoozeUntil and GetTime() < snoozeUntil and "snooze") or busy() or (pendingInvite and "busy") or (room and room.phase == "play" and "busy") or nil
    if why then send(pack("DEC", inv.room, why), "WHISPER", sender); return end
    pendingInvite = inv
    showInvite(inv)
  elseif kind == "ACC" then
    if not (room and isHost() and room.id == t[2]) then
      send(pack("CLOSE", t[2]), "WHISPER", sender)
      return
    end
    for _, p in ipairs(room.players) do if p == sender then return end end
    for _, p in ipairs(room.waiting or {}) do if p == sender then return end end
    if room.phase == "play" then room.waiting = room.waiting or {}; table.insert(room.waiting, sender)
    else room.players[#room.players + 1] = sender end
    if room.invited then room.invited[sender] = nil end
    room.ev = "join:" .. short(sender)
    broadcast()
  elseif kind == "DEC" then
    if room and isHost() and room.id == t[2] then
      room.invited = room.invited or {}; room.invited[sender] = t[3] or "no"
      GG.Refresh()
    end
  elseif kind == "ST" then
    if not (room and room.id == t[2]) then return end
    local r = deserialize(t[2], t[3] or "")
    -- from the host, or from the player who took over after the host logged out (gg13)
    local fromNext = full(r.host) == sender and room.hostGone
    if room.host ~= sender and not fromNext then return end
    local text = eventText(r.ev); if text then addLog(text) end
    if r.phase == "done" and room.phase ~= "done" then settleGame(r) end
    -- players arrive as full names from the host
    room.game, room.stake, room.players, room.phase, room.turn, room.cur = r.game, r.stake, r.players, r.phase, r.turn, r.cur
    room.unit = r.unit
    room.rolls, room.board, room.win, room.lose, room.pay, room.waiting = r.rolls, r.board, r.win, r.lose, r.pay, r.waiting
    room.hostGone = nil
    if r.host and full(r.host) ~= room.host then
      room.host = full(r.host)
      if room.host == me() then becomeHost() end
    end
    local waits = false; for _, n in ipairs(r.waiting) do if n == short(me()) then waits = true end end
    if not myIndex() and not waits then room = nil end -- we were removed
    GG.Refresh()
  elseif kind == "ACT" then
    if room and isHost() and room.id == t[2] then applyAction(sender, t[3], t[4], t[5], t[6]) end
  elseif kind == "LEAVE" then
    if room and isHost() and room.id == t[2] then
      for i, p in ipairs(room.players) do
        if p == sender then
          if room.phase == "play" and i <= #playing() then
            room.ev = "left:" .. short(p); local pl = playing()
            finish(room.game, #pl == 2 and (i % 2 + 1) or ((i - 2) % #pl + 1), i)
          end
          dropSeat(i); room.ev = "left:" .. short(p); broadcast(); break
        end
      end
      for i, p in ipairs(room.waiting or {}) do
        if p == sender then table.remove(room.waiting, i); room.ev = "left:" .. short(p); broadcast(); break end
      end
    end
  elseif kind == "CLOSE" then
    if room and room.id == t[2] and room.host == sender then
      room = nil; addLog(L["The host closed the table."]); GG.Refresh()
    end
  end
end

-- a player left the game world (BYE, or - 6.2.12-beta14, user 18.11.: "wenn ein spieler offline geht und dealer ist, sollte
-- der dealer jemand anderes werden. ausserdem sollte der offline spieler vom tisch bereinigt werden" - the guild roster or the
-- "has gone offline" message says so, for a logout without BYE: disconnect, crash): the host takes him off the table (a
-- running game counts as lost for him); when he was the host, the next player takes the table over
function GG.Gone(name)
  if not name or name == me() then return end
  players[name] = nil; if tables[name] then tables[name] = nil; tablesChanged() end
  if room and isHost() then
    local changed
    for i, p in ipairs(room.players) do
      if p == name then
        if room.phase == "play" and i <= #playing() then
          room.ev = "out:" .. short(p); local pl = playing()
          finish(room.game, #pl == 2 and (i % 2 + 1) or ((i - 2) % #pl + 1), i)
        end
        dropSeat(i); changed = true; break
      end
    end
    for i, p in ipairs(room.waiting or {}) do if p == name then table.remove(room.waiting, i); changed = true; break end end
    if changed then room.ev = "out:" .. short(name); broadcast() end
  elseif room and room.host == name then
    -- the members keep the players' first names only (serialize), so the seat is found by that
    for i, p in ipairs(room.players) do if short(p) == short(name) then dropSeat(i); break end end
    local nh = successor()
    if nh and short(nh) == short(me()) then
      becomeHost()
      if room.phase == "play" then room.phase, room.win, room.lose, room.pay = "done", 0, 0, 0 end -- no result
      room.ev = "host:" .. short(me())
      broadcast()
    elseif nh then room.hostGone = true
    else closeRoom(true) end
  end
  if GG.window and GG.window:IsShown() then GG.Refresh() end
end
-- the roster says who is offline: somebody at our table among them is gone (only while we sit at a table)
local function checkOffline(offline)
  if not room then return end
  local list = {}
  -- full names with the surname (on WoW Forever characters share first names)
  for _, p in ipairs(room.players) do if p ~= me() and offline[p] then list[#list + 1] = p end end
  for _, p in ipairs(room.waiting or {}) do if offline[p] then list[#list + 1] = p end end
  if room.host ~= me() and offline[room.host] then list[#list + 1] = room.host end
  for _, p in ipairs(list) do GG.Gone(p) end
end
GG._checkOffline = checkOffline -- tests
-- while we sit at a table the roster is asked for every 30 s (the client does not keep it fresh on its own), so a player who
-- went offline without a BYE leaves the table within about half a minute; nothing runs without a table
local pinging
local function rosterPing()
  if not room then pinging = nil; return end
  if C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster() end
  C_Timer.After(30, rosterPing)
end
function GG.EnsurePing()
  if room and not pinging and C_Timer and C_Timer.After then pinging = true; C_Timer.After(30, rosterPing) end
end

-- ---------------------------------------------------------------- events (only while the switch is on)
local ev = CreateFrame("Frame")
local registered
ev:SetScript("OnEvent", function(_, event, a, b, c, d)
  if event == "CHAT_MSG_ADDON" then
    if FLT.IsSecret and FLT.IsSecret(a, b, c, d) then return end
    if a == PREFIX then GG.Receive(b, d, c) end
  elseif event == "GUILD_ROSTER_UPDATE" then
    if not rosterPending then rosterPending = true; C_Timer.After(2, readRoster) end
  elseif event == "PLAYER_LOGOUT" then
    if room then closeRoom() end
  else
    tradeEvent(event, a, b)
  end
end)
local function hello()
  if not (on() and guild()) then return end
  send(pack("HI", VER, myInfo()), "GUILD")
  send(pack("TQ"), "GUILD") -- the open tables for the info bar count (gg35)
end
function GG.Apply()
  if on() then
    if not registered then
      registered = true
      if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX) end
      ev:RegisterEvent("CHAT_MSG_ADDON"); ev:RegisterEvent("GUILD_ROSTER_UPDATE"); ev:RegisterEvent("PLAYER_LOGOUT")
      for _, e in ipairs({ "TRADE_SHOW", "TRADE_MONEY_CHANGED", "TRADE_ACCEPT_UPDATE", "TRADE_CLOSED", "UI_INFO_MESSAGE" }) do pcall(ev.RegisterEvent, ev, e) end
      if C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster() end
      readRoster()
      C_Timer.After(3, hello)
    end
  elseif registered then
    registered = nil
    if room then closeRoom() end
    if guild() then send("BYE", "GUILD") end
    ev:UnregisterAllEvents()
    wipe(players)
    if GG.window then GG.window:Hide() end
  end
end
local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self)
  self:UnregisterAllEvents()
  if FLT.QoL and FLT.QoL.On then FLT.QoL.On("guildGames", function() GG.Apply() end) end
  GG.Apply()
end)

-- ---------------------------------------------------------------- window
-- gg4 (user 14.11.: "an einem spieltisch spielen ... teilnehmer mit ihrem character icon ... jeder spieler hat seinen platz.
-- plaetze dynamisch ... die wuerfelanzeigen vor einem ... und in einer liste wie jetzt"): the room is a table - a green
-- felt oval with every player's portrait on a seat around it (spread evenly, you at the bottom), the roll / mark / result
-- on a chip in front of the seat, the game in the middle; the log under the table.
local W, H = 780, 640
local LEFT = 168
local RW = W - LEFT - 30          -- width of the right part
-- without a room the window is small (gg10, user 14.11.: "viel kleiner startet wenn man noch in keinem raum ist. nur so
-- viel platz wie noetig"); the height follows the page
local CW = 530 -- gg13 (user 14.11.: "noch kleiner ... von der breite her")
local CRW = CW - LEFT - 30
local TH = 330                    -- table height
-- Tic Tac Toe marks from the client: the raid target cross and circle (gg12, user 14.11.: "schoenere X und O direkt aus
-- client")
local MARK = { X = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_7", O = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_2" }
-- wood behind the whole window (gg12, user 14.11.: "bretter holz optik"); a tiling 256 texture of the Forever client
-- (FileDataID 939610, checked on wago.tools product wowf; it shows in the game, user's screenshot 14.11.)
local WOOD = "Interface\\Garrison\\GarrisonUIBackground"
local DICE = "Interface\\Buttons\\UI-GroupLoot-Dice-Up" -- the loot roll die (gg5, user 14.11.: "wuerfelsymbol waere besser")
local function text(parent, font, w, color)
  local fs = FLT.NewFS(parent, nil, "OVERLAY", font or "GameFontHighlight")
  if w then fs:SetWidth(w) end
  fs:SetJustifyH("LEFT")
  if color then fs:SetTextColor(FLT.TextC(unpack(color))) end
  return fs
end
local GREY, WHITE = { 0.62, 0.60, 0.56 }, { 0.92, 0.90, 0.86 }

-- portrait of a seat: you = your portrait; a group member = theirs; anyone else = race icon, else class icon
local portraitSaid = {} -- /ofa play debug: race / class of each portrait once
local FACES = { "raceicon128-%s-%s", "raceicon-sd-%s-%s", "raceicon-sd-%s-%s-brn", "raceicon128-%s-%s-c60" } -- (gg32)
-- the class circles (Interface\\TargetingFrame\\UI-Classes-Circles), the same coordinates as the game's CLASS_ICON_TCOORDS
local CLASS_CIRCLES = {
  WARRIOR = { 0, 0.25, 0, 0.25 }, MAGE = { 0.25, 0.49609375, 0, 0.25 }, ROGUE = { 0.49609375, 0.7421875, 0, 0.25 },
  DRUID = { 0.7421875, 0.98828125, 0, 0.25 }, HUNTER = { 0, 0.25, 0.25, 0.5 }, SHAMAN = { 0.25, 0.49609375, 0.25, 0.5 },
  PRIEST = { 0.49609375, 0.7421875, 0.25, 0.5 }, WARLOCK = { 0.7421875, 0.98828125, 0.25, 0.5 }, PALADIN = { 0, 0.25, 0.5, 0.75 },
}
local RACE_ATLAS = { Scourge = "undead", NightElf = "nightelf", BloodElf = "bloodelf", HighmountainTauren = "highmountain" }
local function unitFor(name)
  if UnitName and UnitName("player") == name then return "player" end
  local n = IsInRaid and IsInRaid() and 40 or 4
  local kind = IsInRaid and IsInRaid() and "raid" or "party"
  for i = 1, n do local u = kind .. i; if UnitName and FLT.Str(UnitName(u)) == name then return u end end
  -- gg32 (user 17.11. 23:25: "es wird nicht das tatsaechliche gesicht uebertragen"): the real face also when he is our
  -- target, under the mouse, our focus or has a nameplate near us (only players; names can be secret on plates)
  local function is(u)
    if not (UnitExists and UnitExists(u) and UnitIsPlayer and UnitIsPlayer(u)) then return false end
    local un = UnitName(u)
    return not (FLT.IsSecret and FLT.IsSecret(un)) and un == name
  end
  for _, u in ipairs({ "target", "mouseover", "focus" }) do if is(u) then return u end end
  if C_NamePlate and C_NamePlate.GetNamePlates then
    for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
      local u = plate.namePlateUnitToken
      if u and is(u) then return u end
    end
  end
end
local function infoFor(name)
  for key, info in pairs(players) do if short(key) == name and type(info) == "table" then return info end end
end
local function setPortrait(tex, name)
  local u = unitFor(name)
  if u and SetPortraitTexture then tex:SetTexCoord(0, 1, 0, 1); SetPortraitTexture(tex, u); tex.ofaReal = name; return end
  -- gg36 (user 17.11. 23:54: "das bild sobald es einmal gesehen wurde zu speichern"): a real face drawn once (group, target,
  -- nearby) stays while this seat shows the same player - the game keeps the drawn picture in the texture. It cannot be
  -- saved past a /reload: the face is drawn live from the unit, there is no file
  if tex.ofaReal == name then return end
  tex.ofaReal = nil
  tex:SetTexCoord(0, 1, 0, 1)
  local info = infoFor(name) or {}
  -- gg30 (user 17.11. 23:12: still "?" although level and class arrive): the client's atlas query may know none of them -
  -- set the atlas and check that it took; last the class circles with our own coordinates (CLASS_ICON_TCOORDS may be missing)
  local function atlas(a)
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(a) then tex:SetAtlas(a); return true end
    if tex.SetAtlas and tex.GetAtlas and pcall(tex.SetAtlas, tex, a) and tex:GetAtlas() == a then return true end
  end
  local how = "?"
  if info.race and info.race ~= "" then
    local r = RACE_ATLAS[info.race] or info.race:lower()
    local g = tonumber(info.sex) == 3 and "female" or "male"
    -- gg32 (user 17.11. 23:27: three male orc warriors looked the same): the client has up to three faces per race and sex
    -- (raceicon128, the "sd" drawing, Orc also "-brn"); every player gets one of them by his name - always the same for him.
    -- The new Forever races end in "-c60" (raceicon128-skyborne-male-c60; gg27)
    local faces = {}
    if C_Texture and C_Texture.GetAtlasInfo then
      for _, fmt in ipairs(FACES) do
        local at = string.format(fmt, r, g)
        if C_Texture.GetAtlasInfo(at) then faces[#faces + 1] = at end
      end
    end
    if #faces > 0 then
      local h = 0; for i = 1, #name do h = (h * 31 + name:byte(i)) % 1000003 end
      local at = faces[h % #faces + 1]; tex:SetAtlas(at); how = at
    else
      for _, fmt in ipairs({ "raceicon128-%s-%s", "raceicon128-%s-%s-c60", "raceicon-%s-%s", "raceicon-%s-%s-c60" }) do
        local at = string.format(fmt, r, g)
        if atlas(at) then how = at; break end
      end
    end
  end
  if how == "?" and info.class and info.class ~= "" and atlas("classicon-" .. info.class:lower()) then how = "classicon" end
  if debugOn and FLT.Msg and not portraitSaid[name] then
    portraitSaid[name] = true
    FLT.Msg("GG portrait " .. tostring(name) .. ": race=" .. tostring(info.race) .. " sex=" .. tostring(info.sex) .. " class=" .. tostring(info.class) .. " -> " .. how)
  end
  if how ~= "?" then return end
  local tc = info.class and ((CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[info.class]) or CLASS_CIRCLES[info.class])
  if tc then tex:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles"); tex:SetTexCoord(unpack(tc)); return end
  tex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
end
-- the class token of a seat (gg32): ours, a unit's, else what the player sent
local function classFor(name)
  local u = unitFor(name)
  if u and UnitClass then local _, c = UnitClass(u); if c and not (FLT.IsSecret and FLT.IsSecret(c)) then return c end end
  local info = infoFor(name); return info and info.class ~= "" and info.class or nil
end
local function levelFor(name)
  if UnitName and UnitName("player") == name then return UnitLevel and UnitLevel("player") end
  local u = unitFor(name); if u and UnitLevel then local lv = UnitLevel(u); if not (FLT.IsSecret and FLT.IsSecret(lv)) then return lv end end
  local info = infoFor(name); return info and tonumber(info.level)
end

local navRows, pool, cells, seats = {}, {}, {}, {}
local statCells, resetArmed = {}, nil -- My History (gg14)
local chipGeo = {} -- seat -> { x, y, w } of its chip on the table (gg23)
local inviteOff = 0 -- first row of the invite list (mouse wheel, gg16)
local function create()
  local f = CreateFrame("Frame", "OneForAllGuildGames", UIParent)
  f:SetSize(W, H); f:SetFrameStrata("FULLSCREEN"); f:SetClampedToScreen(true)
  f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
  local pos = db().pos
  if type(pos) == "table" then f:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) else f:SetPoint("CENTER", 0, 40) end
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local l, t = self:GetLeft(), self:GetTop()
    if l and t then self:ClearAllPoints(); self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l, t); db().pos = { "TOPLEFT", "BOTTOMLEFT", l, t } end
  end)
  UI.FramedPanel(f)
  local wood = f:CreateTexture(nil, "BACKGROUND", nil, 1); wood:SetPoint("TOPLEFT", 5, -5); wood:SetPoint("BOTTOMRIGHT", -5, 5)
  wood:SetTexture(WOOD, "REPEAT", "REPEAT"); wood:SetHorizTile(true); wood:SetVertTile(true)
  wood:SetVertexColor(0.62, 0.55, 0.50); UI.MarkBG(wood)
  for _, t in ipairs(UI.OrnateFrame(f, f, 16, 3, "OVERLAY", 4)) do t:SetVertexColor(FLT.SkinC(1, 1, 1, 1)) end
  local close = UI.CloseButton(f); close:SetPoint("TOPRIGHT", -12, -12)
  local title = text(f, "GameFontNormalLarge", nil, UI.GOLD); title:SetPoint("TOPLEFT", 18, -15); title:SetText(L["Guild Games"])
  f.sub = text(f, "GameFontHighlightSmall", W - 220, GREY); f.sub:SetPoint("LEFT", title, "RIGHT", 12, -1)
  -- thanks at the bottom left edge, like "made by Smoergi" in the main window (gg34, user 17.11. 23:33)
  f.thanks = FLT.NewFS(f, nil, "OVERLAY", "GameFontDisableSmall"); f.thanks:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 22, 4)
  f.thanks:SetText(string.format(L["Special thanks to %s"], "Ritter Roulade"))
  -- side list: the games and the leaderboard
  local y = -52
  local function navRow(key, label, icon)
    local b = CreateFrame("Button", nil, f); b:SetSize(LEFT - 24, 30); b:SetPoint("TOPLEFT", 14, y); y = y - 34
    b.card = UI.CardRow(b)
    b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetSize(20, 20); b.icon:SetPoint("LEFT", 6, 0); b.icon:SetTexture(icon)
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b.label = text(b, "GameFontHighlight", LEFT - 60); b.label:SetPoint("LEFT", 32, 0); b.label:SetText(label)
    b:SetScript("OnClick", function() GG.view = key; GG.Refresh() end)
    b.live = b:CreateTexture(nil, "OVERLAY"); b.live:SetSize(16, 16); b.live:SetPoint("RIGHT", -8, 0); b.live:SetTexture(DICE); b.live:Hide()
    navRows[key] = b
  end
  for _, g in ipairs(GAMES) do navRow(g.key, L[g.name], g.icon) end
  y = y - 8
  navRow("tables", L["Open tables"], "Interface\\Icons\\INV_Misc_GroupNeedMore")
  navRows.tables.count = text(navRows.tables, "GameFontDisableSmall", 40); navRows.tables.count:SetPoint("RIGHT", -8, 0); navRows.tables.count:SetJustifyH("RIGHT")
  navRow("debts", L["My History"], "Interface\\Icons\\INV_Misc_Coin_02")
  navRows.debts.count = text(navRows.debts, "GameFontDisableSmall", 40); navRows.debts.count:SetPoint("RIGHT", -8, 0); navRows.debts.count:SetJustifyH("RIGHT")
  f.navBottom = y -- the host's invite list starts below (gg20)
  local line = f:CreateTexture(nil, "ARTWORK"); line:SetColorTexture(FLT.SkinC(0.55, 0.45, 0.28, 0.35)); line:SetWidth(1)
  line:SetPoint("TOPLEFT", LEFT, -48); line:SetPoint("BOTTOMLEFT", LEFT, 16)
  -- right side
  local R = CreateFrame("Frame", nil, f); R:SetPoint("TOPLEFT", LEFT + 14, -50); R:SetPoint("BOTTOMRIGHT", -16, 16)
  f.R = R
  f.head = text(R, "GameFontNormal", nil, UI.GOLD); f.head:SetPoint("TOPLEFT", 0, 0)
  do local font, _, flags = f.head:GetFont(); if font then f.head:SetFont(font, 15, flags) end end
  f.desc = text(R, "GameFontHighlightSmall", RW - 10, WHITE); f.desc:SetPoint("TOPLEFT", 0, -24); f.desc:SetWordWrap(true)
  -- the table: the user's picture (gg9, made with GPT from our prompt; tools/art/gg_table.py)
  local tbl = CreateFrame("Frame", nil, R); tbl:SetSize(RW, TH); tbl:SetPoint("TOPLEFT", 0, -26)
  local top = tbl:CreateTexture(nil, "BACKGROUND"); top:SetSize(470, 235); top:SetPoint("CENTER", 0, -4)
  FLT.SetTex(top, UI.ASSET_ROOT .. "gg_table")
  f.tbl = tbl
  -- who pays whom after a game for gold (gg10): an arrow from the loser to the winner, the gold on it
  if tbl.CreateLine then
    -- on a layer above the Tic Tac Toe board and the chips (gg12, user 14.11.: "das sollte drueber liegen")
    local layer = CreateFrame("Frame", nil, tbl); layer:SetAllPoints(tbl); layer:SetFrameLevel(tbl:GetFrameLevel() + 20)
    f.payLayer = layer
    -- gg13 (user 14.11.: "gibts den in schoener?"): a bevelled gold shaft and head (tools/art/gg_arrowhead.py) and a gold
    -- coin that travels along it (an animation group, no OnUpdate; it only plays while the arrow is shown)
    f.payLine = layer:CreateLine(nil, "ARTWORK", nil, 2); f.payLine:SetThickness(14); f.payLine:SetTexture(UI.ASSET_ROOT .. "gg_arrowshaft")
    f.payHead = layer:CreateTexture(nil, "ARTWORK", nil, 3); f.payHead:SetSize(34, 34); FLT.SetTex(f.payHead, UI.ASSET_ROOT .. "gg_arrowhead")
    f.payCoin = layer:CreateTexture(nil, "ARTWORK", nil, 4); f.payCoin:SetSize(14, 14); f.payCoin:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
    local ag = f.payCoin:CreateAnimationGroup(); ag:SetLooping("REPEAT")
    f.payMove = ag:CreateAnimation("Translation"); f.payMove:SetDuration(1.6); f.payMove:SetSmoothing("IN_OUT"); f.payMove:SetOrder(1)
    local fin = ag:CreateAnimation("Alpha"); fin:SetFromAlpha(0); fin:SetToAlpha(1); fin:SetDuration(0.3); fin:SetOrder(1)
    local fout = ag:CreateAnimation("Alpha"); fout:SetFromAlpha(1); fout:SetToAlpha(0); fout:SetDuration(0.3); fout:SetStartDelay(1.3); fout:SetOrder(1)
    f.payAnim = ag
    f.payChip = CreateFrame("Frame", nil, layer); f.payChip:SetSize(60, 22); f.payChip:SetFrameLevel(tbl:GetFrameLevel() + 22)
    f.payChip.card = UI.CardRow(f.payChip, { 0.05, 0.05, 0.06, 0.95 }, { 1, 0.82, 0.31, 1 })
    f.payChip.t = text(f.payChip, "GameFontNormal", 80); f.payChip.t:SetJustifyH("CENTER"); f.payChip.t:SetPoint("CENTER")
  end
  f.big = text(tbl, "GameFontNormalHuge", 240, UI.GOLD); f.big:SetJustifyH("CENTER"); f.big:SetPoint("CENTER", 0, 24)
  f.roll = UI.GoldButton(tbl, L["Roll"], 120, 28, DICE, 14); f.roll:SetPoint("CENTER", 0, -14)
  f.roll:SetScript("OnClick", GG.Roll)
  f.center = text(tbl, "GameFontHighlightSmall", 230, WHITE); f.center:SetJustifyH("CENTER"); f.center:SetPoint("CENTER", 0, -14)
  -- tic tac toe board in the middle of the table
  for i = 1, 9 do
    local c = CreateFrame("Button", nil, tbl); c:SetSize(38, 38)
    c.card = UI.CardRow(c)
    c.mark = c:CreateTexture(nil, "OVERLAY"); c.mark:SetSize(28, 28); c.mark:SetPoint("CENTER")
    c:SetPoint("CENTER", tbl, "CENTER", ((i - 1) % 3 - 1) * 41, (1 - math.floor((i - 1) / 3)) * 41)
    c:SetScript("OnClick", function() GG.Move(i) end)
    cells[i] = c
  end
  f.status = text(R, "GameFontNormal", RW); f.status:SetJustifyH("CENTER"); f.status:SetPoint("TOP", tbl, "BOTTOM", 0, -2)
  -- under the table: log on the left, invites on the right, buttons bottom right
  local low = -26 - TH - 30
  f.logTitle = text(R, "GameFontNormalSmall", nil, UI.GOLD); f.logTitle:SetText(L["Log"]); f.logTitle:SetPoint("TOPLEFT", 0, low)
  f.log = text(R, "GameFontHighlightSmall", RW / 2 - 20, GREY); f.log:SetJustifyV("TOP"); f.log:SetWordWrap(true)
  f.log:SetPoint("TOPLEFT", 0, low - 16)
  f.paysTitle = text(R, "GameFontNormalSmall", nil, UI.GOLD); f.paysTitle:SetText(L["To pay"]); f.paysTitle:SetPoint("TOPLEFT", RW / 2, low)
  f.pays = text(R, "GameFontHighlightSmall", RW / 2 - 10, GREY); f.pays:SetJustifyV("TOP"); f.pays:SetWordWrap(true)
  f.pays:SetPoint("TOPLEFT", RW / 2, low - 16)
  f.inviteTitle = text(R, "GameFontNormalSmall", nil, UI.GOLD); f.inviteTitle:SetText(L["Invite guild members"])
  f.balTitle = text(R, "GameFontNormalSmall", nil, UI.GOLD); f.balTitle:SetText(L["Table balance"])
  f.inviteSearch = FLT.SkinBlizz(CreateFrame("EditBox", nil, f, "InputBoxTemplate")); f.inviteSearch:SetSize(130, 20)
  f.inviteSearch:SetAutoFocus(false); f.inviteSearch:SetMaxLetters(24)
  f.inviteSearch.hint = text(f.inviteSearch, "GameFontDisableSmall", 120); f.inviteSearch.hint:SetPoint("LEFT", 4, 0)
  f.inviteSearch.hint:SetText(L["Search"])
  f.inviteSearch:SetScript("OnTextChanged", function() inviteOff = 0; GG.Refresh() end)
  f.inviteSearch:SetScript("OnEditFocusGained", function(self) self.hint:Hide() end)
  f.inviteSearch:SetScript("OnEditFocusLost", function() GG.Refresh() end)
  f.inviteSearch:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  f.inviteSearch:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
  f.bal = text(R, "GameFontHighlightSmall", 180, GREY); f.bal:SetJustifyV("TOP"); f.bal:SetWordWrap(true)
  f.inviteTitle:SetPoint("TOPLEFT", RW / 2, low)
  f.empty = text(R, "GameFontDisableSmall", RW / 2 - 10)
  f.inviteMore = text(R, "GameFontDisableSmall", 200)
  f.inviteWheel = CreateFrame("Frame", nil, R); f.inviteWheel:EnableMouseWheel(true)
  f.inviteWheel:SetScript("OnMouseWheel", function(_, delta) inviteOff = math.max(0, inviteOff - delta); GG.Refresh() end)
  f.lowY = low
  -- stake box + create (no room yet)
  f.stakeLabel = text(R, "GameFontNormalSmall", nil, UI.GOLD); f.stakeLabel:SetText(L["Stake"])
  f.stake = FLT.SkinBlizz(CreateFrame("EditBox", nil, R, "InputBoxTemplate")); f.stake:SetSize(70, 20); f.stake:SetAutoFocus(false)
  f.stake:SetNumeric(true); f.stake:SetMaxLetters(6)
  f.stake:SetScript("OnEnterPressed", function(self) self:ClearFocus(); if room then GG.SetStake(self:GetText(), GG.unit) end end)
  f.stake:SetPoint("LEFT", f.stakeLabel, "RIGHT", 10, 0)
  -- gold or silver (gg15): one button that switches the coin
  f.unit = UI.GoldButton(R, L["Gold"], 74, 20, nil, 11); f.unit:SetPoint("LEFT", f.stake, "RIGHT", 6, 0)
  f.unit:SetScript("OnClick", function()
    local cur = (room and isHost()) and (room.unit or "g") or GG.unit
    GG.unit = cur == "s" and "g" or "s"; db().unit = GG.unit
    if room and isHost() and room.phase ~= "play" then GG.SetStake(f.stake:GetText(), GG.unit) else GG.Refresh() end
  end)
  -- My History (gg14): reset my statistics, a second click within 4 s confirms
  f.resetStats = UI.GoldButton(R, L["Reset statistics"], 150, 22, nil, 11)
  f.resetStats:SetScript("OnClick", function()
    if resetArmed then resetArmed = nil; GG.ResetStats(); return end
    resetArmed = true; GG.Refresh()
    C_Timer.After(4, function() if resetArmed then resetArmed = nil; GG.Refresh() end end)
  end)
  f.histTitle = text(R, "GameFontNormalSmall", nil, UI.GOLD)
  f.create = UI.GoldButton(R, L["Open a table"], 130, 24, nil, 12)
  f.create:SetScript("OnClick", function() newRoom(GG.view, f.stake:GetText(), GG.unit); f.stake:ClearFocus() end)
  f.setStake = UI.GoldButton(R, L["Change"], 70, 20, nil, 11)
  f.setStake:SetScript("OnClick", function() f.stake:ClearFocus(); GG.SetStake(f.stake:GetText(), GG.unit) end)
  f.setStake:SetPoint("LEFT", f.unit, "RIGHT", 6, 0)
  -- room buttons (bottom right)
  f.start = UI.GoldButton(R, L["Start"], 104, 24, nil, 12); f.start:SetScript("OnClick", startGame)
  f.again = UI.GoldButton(R, L["Play again"], 104, 24, nil, 12); f.again:SetScript("OnClick", startGame)
  f.leave = UI.GoldButton(R, L["Leave"], 104, 24, nil, 12); f.leave:SetScript("OnClick", function() closeRoom() end)
  f.leave:SetPoint("BOTTOMRIGHT", 0, 0)
  f.start:SetPoint("RIGHT", f.leave, "LEFT", -8, 0); f.again:SetPoint("RIGHT", f.leave, "LEFT", -8, 0)
  if UISpecialFrames then table.insert(UISpecialFrames, "OneForAllGuildGames") end
  f:Hide()
  GG.window = f
end

local function row(i)
  local r = pool[i]
  if r then return r end
  local f = GG.window
  r = CreateFrame("Button", nil, f.R); r:SetSize(230, 24)
  r.card = UI.CardRow(r)
  r.name = text(r, "GameFontHighlightSmall", 150); r.name:SetPoint("LEFT", 8, 0)
  r.right = text(r, "GameFontHighlightSmall", 90); r.right:SetPoint("RIGHT", -8, 0); r.right:SetJustifyH("RIGHT")
  r.btn = UI.GoldButton(r, L["Invite"], 64, 18, nil, 10); r.btn:SetPoint("RIGHT", -4, 0)
  pool[i] = r
  return r
end

-- one seat: portrait with level badge, name under it, a glow while it is this player's turn, the chip in front
local function seat(i)
  local s = seats[i]
  if s then return s end
  local tbl = GG.window.tbl
  s = CreateFrame("Frame", nil, tbl); s:SetSize(90, 84)
  -- whose turn: a pulsing gold ring around the portrait (gg14, user 14.11.: the old glow was "kaum sichtbar")
  s.glow = s:CreateTexture(nil, "BACKGROUND"); s.glow:SetSize(92, 92); s.glow:SetPoint("CENTER", s, "TOP", 0, -30)
  FLT.SetTex(s.glow, UI.ASSET_ROOT .. "gg_turnglow"); s.glow:SetBlendMode("ADD")
  local pulse = s.glow:CreateAnimationGroup(); pulse:SetLooping("BOUNCE")
  local pa = pulse:CreateAnimation("Alpha"); pa:SetFromAlpha(0.9); pa:SetToAlpha(0.4); pa:SetDuration(0.8); pa:SetSmoothing("IN_OUT")
  s.pulse = pulse
  s.pic = UI.CreateBossFrame(s, 60, true); s.pic:SetPoint("TOP", 0, 0)
  s.name = text(s, "GameFontHighlightSmall", 100); s.name:SetJustifyH("CENTER"); s.name:SetPoint("TOP", s.pic, "BOTTOM", 0, -1)
  s.crown = s:CreateTexture(nil, "OVERLAY", nil, 7); s.crown:SetSize(22, 22); s.crown:SetPoint("BOTTOM", s.pic, "TOP", 0, -8)
  s.crown:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon"); s.crown:Hide()
  s.tag = text(s, "GameFontDisableSmall", 100); s.tag:SetJustifyH("CENTER"); s.tag:SetPoint("TOP", s.name, "BOTTOM", 0, 0)
  local chip = CreateFrame("Frame", nil, tbl); chip:SetSize(54, 24)
  chip:SetFrameLevel(tbl:GetFrameLevel() + 10) -- above the pay arrow of the dice games (gg23)
  chip.card = UI.CardRow(chip, { 0.05, 0.05, 0.06, 0.92 }, { 0.70, 0.56, 0.30, 0.95 })
  chip.t = text(chip, "GameFontNormal", 54); chip.t:SetJustifyH("CENTER"); chip.t:SetPoint("CENTER")
  s.chip = chip
  seats[i] = s
  return s
end

-- the seats around the table: evenly spread on an oval, the own seat at the bottom
local function layoutSeats()
  local f = GG.window
  local list = room.players
  local n = #list
  local mine = myIndex() or 1
  local cx, cy, rx, ry = RW / 2, TH / 2 - 6, RW / 2 - 50, TH / 2 - 56
  local pl = #playing()
  for i = 1, math.max(n, #seats) do
    local s = seats[i]
    if i > n then chipGeo[i] = nil; if s then s:Hide(); s.chip:Hide() end
    else
      s = seat(i)
      local a = math.pi / 2 + 2 * math.pi * (i - mine) / n
      local sx, sy = cx + rx * math.cos(a), cy + ry * math.sin(a)
      -- many players: smaller seats so they still fit around the table (gg16)
      local sc = n > 10 and 0.7 or n > 7 and 0.84 or 1
      s:SetScale(sc)
      s:ClearAllPoints(); s:SetPoint("TOP", f.tbl, "TOPLEFT", sx / sc, -(sy - 32 * sc) / sc); s:Show()
      local name = short(list[i])
      setPortrait(s.pic.portrait, name)
      local lv = levelFor(name); s.pic:SetLevel(lv and lv > 0 and tostring(lv) or nil)
      s.name:SetText(name)
      -- the name in the class colour (gg32; the class icon beside the portrait came out again in gg35, user 17.11. 23:52)
      local cls = classFor(name)
      local cc = cls and RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls]
      if cc then s.name:SetTextColor(cc.r, cc.g, cc.b) else s.name:SetTextColor(FLT.TextC(unpack(i == mine and UI.GOLD or WHITE))) end
      local tag = ""
      s.crown:SetShown(short(list[i]) == short(room.host)) -- the host's crown (gg13)
      if i > pl then tag = L["(watching)"] end
      s.tag:SetText(tag)
      s:SetAlpha(i > pl and 0.6 or 1)
      local turn = room.phase == "play" and i <= pl and
        ((room.game == "highlow" and not room.rolls[i]) or (room.game ~= "highlow" and room.turn == i))
      s.glow:SetShown(turn and true or false)
      if turn then if not s.pulse:IsPlaying() then s.pulse:Play() end else s.pulse:Stop() end
      -- chip in front of the seat (towards the middle)
      local chipText
      if room.game == "ttt" and i <= 2 then chipText = "|T" .. (i == 1 and MARK.X or MARK.O) .. ":16:16:0:0|t" end
      if room.game ~= "ttt" and room.phase ~= "lobby" and room.rolls[i] then chipText = "|T" .. DICE .. ":14:14:0:0|t " .. room.rolls[i] end
      if room.phase == "done" then
        if room.win == i then chipText = "|cff66ff77" .. (chipText and chipText .. " " or "") .. L["won"] .. "|r"
        elseif room.lose == i then chipText = "|cffff6655" .. (chipText and chipText .. " " or "") .. L["lost"] .. "|r" end
      end
      local chip = s.chip
      s.ax, s.ay, s.sc = sx, sy - 2, sc -- the portrait's middle: the arrow runs portrait to portrait (gg21)
      chipGeo[i] = nil
      if chipText and i <= pl then
        chip.t:SetText(chipText)
        local w = math.max(40, (chip.t:GetStringWidth() or 30) + 16); chip:SetWidth(w); chip.t:SetWidth(w)
        chip:ClearAllPoints()
        if room.game == "ttt" then -- next to the seat, the board fills the middle (gg5: the chips lay on the board)
          chip:SetPoint("LEFT", f.tbl, "TOPLEFT", sx + 40, -sy)
          chipGeo[i] = { sx + 40 + w / 2, sy }
        else -- in front of the seat; seats in the upper half have their name under the portrait, so a bit further in
          local k = sy < cy and 0.42 or 0.56
          chipGeo[i] = { cx + (sx - cx) * k, cy + (sy - cy) * k }
          chip:SetPoint("CENTER", f.tbl, "TOPLEFT", chipGeo[i][1], -chipGeo[i][2])
        end
        chipGeo[i][3] = w -- the pay amount keeps away from it
        chip:Show()
      else chip:Hide() end
    end
  end
end

local function drawPay()
  local f = GG.window
  if not f.payLine then return end
  local a, b = seats[room.lose], seats[room.win]
  local show = room.phase == "done" and (room.pay or 0) > 0 and a and b and a:IsShown() and b:IsShown() and a.ax and b.ax
  for _, w in ipairs({ f.payLine, f.payHead, f.payCoin, f.payChip }) do w:SetShown(show and true or false) end
  if not show then f.payAnim:Stop(); f.payKey = nil; return end
  local dx, dy = b.ax - a.ax, b.ay - a.ay
  local len = math.sqrt(dx * dx + dy * dy); if len < 1 then len = 1 end
  local ux, uy = dx / len, dy / len
  local gap = 40 * (a.sc or 1) -- stop at the portrait's ring
  local x1, y1 = a.ax + ux * gap, a.ay + uy * gap
  local tx, ty = b.ax - ux * gap, b.ay - uy * gap   -- the tip
  local hx, hy = tx - ux * 15, ty - uy * 15         -- the head's middle (its tip is 15 px ahead)
  f.payLine:SetStartPoint("TOPLEFT", f.tbl, x1, -y1); f.payLine:SetEndPoint("TOPLEFT", f.tbl, hx, -hy)
  f.payHead:ClearAllPoints(); f.payHead:SetPoint("CENTER", f.tbl, "TOPLEFT", hx, -hy)
  f.payHead:SetRotation(math.atan2(-uy, ux)) -- screen y grows downwards here
  local key = math.floor(x1) .. ":" .. math.floor(y1) .. ":" .. math.floor(hx) .. ":" .. math.floor(hy)
  if key ~= f.payKey then
    f.payKey = key
    f.payAnim:Stop()
    f.payCoin:ClearAllPoints(); f.payCoin:SetPoint("CENTER", f.tbl, "TOPLEFT", x1, -y1)
    f.payMove:SetOffset(hx - x1, -(hy - y1))
    f.payAnim:Play()
  end
  -- gg23 (user 14.11.: "damit die werte nicht vom pfeil ueberdeckt werden"): in the dice games the arrow runs under the
  -- chips; Tic Tac Toe keeps it above its board. The amount takes the first spot along the arrow that is free of chips.
  f.payLayer:SetFrameLevel(f.tbl:GetFrameLevel() + (room.game == "ttt" and 20 or 5))
  f.payChip.t:SetText(coins(room.pay, room.unit))
  local w = (f.payChip.t:GetStringWidth() or 40) + 18; f.payChip:SetWidth(w)
  local px, py = (x1 + hx) / 2, (y1 + hy) / 2
  for _, t in ipairs({ 0.5, 0.38, 0.62, 0.28, 0.72, 0.2, 0.8 }) do
    local qx, qy = x1 + (hx - x1) * t, y1 + (hy - y1) * t
    local free = true
    for i = 1, #room.players do
      local g = chipGeo[i]
      if g and math.abs(g[1] - qx) < (g[3] + w) / 2 + 4 and math.abs(g[2] - qy) < 28 then free = false; break end
    end
    if free then px, py = qx, qy; break end
  end
  f.payChip:ClearAllPoints(); f.payChip:SetPoint("CENTER", f.tbl, "TOPLEFT", px, -py)
end

-- "your turn" while the window is closed (gg33, user 17.11. 23:30: "wenn das fenster geschlossen ist ... ein kleines popup
-- 'you need to roll' ... mit einem klick auf ok dass das fenster auf geht"): once per turn, gone when the turn passes or the
-- window opens; X closes it for this turn
local turnPopup, turnSaid
local function myTurn()
  if not (room and room.phase == "play") then return false end
  local mine = myIndex()
  if not mine or mine > #playing() then return false end
  if room.game == "highlow" then return not room.rolls[mine] end
  return room.turn == mine
end
local function checkTurn()
  local shown = GG.window and GG.window:IsShown()
  if shown or not myTurn() then
    if turnPopup then turnPopup:Hide() end
    if not myTurn() then turnSaid = nil end
    return
  end
  local key = room.id .. ":" .. room.game .. ":" .. (room.turn or 0) .. ":" .. (room.board or "") .. ":" .. (room.cur or 0)
  if turnSaid == key then return end
  turnSaid = key
  if not turnPopup then
    local f = CreateFrame("Frame", "OneForAllGuildGamesTurn", UIParent)
    f:SetSize(300, 104); f:SetPoint("TOP", 0, -180); f:SetFrameStrata("DIALOG"); f:EnableMouse(true)
    f:SetMovable(true); f:RegisterForDrag("LeftButton"); f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
    UI.FramedPanel(f)
    for _, t in ipairs(UI.OrnateFrame(f, f, 16, 3, "OVERLAY", 4)) do t:SetVertexColor(FLT.SkinC(1, 1, 1, 1)) end
    local close = UI.CloseButton(f); close:SetPoint("TOPRIGHT", -8, -8); close:SetScript("OnClick", function() f:Hide() end)
    f.title = FLT.NewFS(f, nil, "OVERLAY", "GameFontNormal"); f.title:SetPoint("TOP", 0, -14); f.title:SetText(L["Guild Games"])
    f.title:SetTextColor(FLT.TextC(unpack(UI.GOLD)))
    f.text = FLT.NewFS(f, nil, "OVERLAY", "GameFontHighlight"); f.text:SetPoint("TOP", 0, -36); f.text:SetWidth(270); f.text:SetJustifyH("CENTER")
    f.ok = UI.GoldButton(f, L["OK"], 100, 24, nil, 13); f.ok:SetPoint("BOTTOM", 0, 14)
    f.ok:SetScript("OnClick", function() f:Hide(); GG.Open() end)
    turnPopup = f
  end
  local g = GAME[room.game]
  turnPopup.text:SetText(string.format(room.game == "ttt" and L["Your move in %s!"] or L["Your roll in %s!"], L[g.name]))
  turnPopup:Show()
  if PlaySound and SOUNDKIT and SOUNDKIT.READY_CHECK then pcall(PlaySound, SOUNDKIT.READY_CHECK) end
end
GG.CheckTurn = checkTurn -- tests
function GG.TurnPopup() return turnPopup end -- tests

function GG.Refresh()
  local f = GG.window
  checkTurn()
  GG.EnsurePing() -- at a table: the roster is asked for now and then (offline players leave it, beta14)
  if not (f and f:IsShown()) then return end
  local R = f.R
  GG.view = GG.view or (room and room.game) or "deathroll"
  if room then GG.view = (GG.view == "debts" or GG.view == "tables") and GG.view or room.game end
  for key, b in pairs(navRows) do
    b.card:SetSelected(key == GG.view)
    -- the running game stays marked while another page is open (gg8): green name, dice on the right
    local live = room and room.game == key
    b.live:SetShown(live and true or false)
    b.label:SetTextColor(FLT.TextC(unpack(live and { 0.40, 1, 0.47 } or WHITE)))
  end
  -- hide everything, show what this view needs
  GG.unit = GG.unit or db().unit or "g"
  do
    local u = (room and isHost()) and (room.unit or "g") or GG.unit
    f.unit:SetLabel("|TInterface\\MoneyFrame\\UI-" .. (u == "s" and "SilverIcon" or "GoldIcon") .. ":0|t " .. (u == "s" and L["Silver"] or L["Gold"]))
  end
  for _, w in ipairs({ f.desc, f.status, f.stakeLabel, f.stake, f.unit, f.setStake, f.create, f.start, f.leave, f.again, f.roll, f.big, f.center,
    f.logTitle, f.log, f.inviteTitle, f.empty, f.tbl, f.paysTitle, f.pays, f.resetStats, f.histTitle, f.inviteMore, f.inviteWheel, f.balTitle, f.bal }) do w:Hide() end
  -- the search box is only hidden when it is not needed: Hide() would take the focus while typing (gg22)
  if not (room and isHost() and GG.view == room.game) then f.inviteSearch:Hide() end
  for _, r in pairs(statCells) do for _, c in pairs(r) do c:Hide() end end
  do local n2 = #GG.Debts(); navRows.debts.count:SetText(n2 > 0 and tostring(n2) or "") end
  do
    local n3 = 0; for host in pairs(tables) do if players[host] then n3 = n3 + 1 else tables[host] = nil end end
    navRows.tables.count:SetText(n3 > 0 and tostring(n3) or "")
  end
  for _, c in ipairs(cells) do c:Hide() end
  -- rows are reused by every page: their button back to enabled (gg29, user 17.11. 23:05: "Open tables" disables "Join"
  -- while you sit at a table - row 1 then stayed disabled as "Settled" in My History)
  for _, r in pairs(pool) do r:Hide(); r.btn:Enable() end -- pairs: the pool has gaps (list rows 1.., invites 21..)
  local n = 0; for name in pairs(players) do if name ~= me() then n = n + 1 end end
  f.sub:SetText(guild() and string.format(L["%d guild members can play"], n) or L["Not in a guild."])
  local function place(w, x, y) w:ClearAllPoints(); w:SetPoint("TOPLEFT", R, "TOPLEFT", x, y); w:Show() end
  local rw = room and RW or CRW
  -- the height a page without a room needs: its content (y = lowest point under R's top), at least the side list
  local function fit(y) f:SetSize(CW, math.max(262, 50 - y + 22)) end
  if room then f:SetSize(W, H) end

  if GG.view == "tables" then
    f.head:SetText(L["Open tables"])
    local list = {}; for host, tb in pairs(tables) do list[#list + 1] = { host = host, tb = tb } end
    table.sort(list, function(a, b) return a.host < b.host end)
    local y = -26
    if #list == 0 then f.empty:SetWidth(rw - 10); f.empty:SetText(L["No open tables in your guild right now."]); place(f.empty, 0, y); y = y - 24 end
    for i, e in ipairs(list) do
      if i > 12 then break end
      local tb, g = e.tb, GAME[e.tb.game]
      local r = row(i); r:SetSize(rw - 10, 50); r.card:SetSelected(false); r:SetScript("OnClick", nil)
      r.name:SetWidth(rw - 120); r.name:SetTextColor(FLT.TextC(unpack(WHITE))); r.right:SetText("")
      r.name:SetText(L[g.name] .. ((tb.stake or 0) > 0 and ("  " .. FLT.DOT .. "  " .. coins(tb.stake, tb.unit)) or "") .. "\n|cff9d9d9d" ..
        string.format(L["%s's table, %d seated"], short(e.host), tb.n) .. "\n" ..
        (tb.phase == "play" and L["Game running"] or L["Waiting for players"]) .. "|r")
      r.btn:SetLabel(L["Join"]); r.btn:SetWidth(80); r.btn:Show()
      if room then r.btn:Disable() else r.btn:Enable() end
      r.btn:SetScript("OnClick", function() GG.Join(e.host) end)
      place(r, 0, y); y = y - 53
    end
    if room and #list > 0 then
      f.status:SetText(L["Leave your table first to join another one."])
      f.status:ClearAllPoints(); f.status:SetPoint("TOPLEFT", R, "TOPLEFT", 0, y - 4); f.status:SetJustifyH("LEFT"); f.status:SetWidth(rw); f.status:Show()
      y = y - 24
    end
    if not room then fit(y) end
    return
  end

  if GG.view == "debts" then -- My History: my statistics, then the gold that is still open
    f.head:SetText(L["My History"])
    -- statistics table: game | won-lost | gold won | gold lost | difference
    -- gg17: the last column is wider ("Difference" was cut and wrapped one line down)
    local cols = { { 0, 92, "LEFT" }, { 92, 52, "RIGHT" }, { 148, 56, "RIGHT" }, { 208, 56, "RIGHT" }, { 266, 66, "RIGHT" } }
        local function cell(r, c, txt, color)
      statCells[r] = statCells[r] or {}
      local fs = statCells[r][c]
      if not fs then
        fs = text(R, r == 1 and "GameFontNormalSmall" or "GameFontHighlightSmall", cols[c][2]); fs:SetJustifyH(cols[c][3])
        fs:SetWordWrap(false)
        statCells[r][c] = fs
      end
      fs:SetText(txt); fs:SetTextColor(FLT.TextC(unpack(color or WHITE)))
      return fs
    end
    local function g0(n) return n ~= 0 and money(n) or "0" end
    local y = -28
    local hdr = { L["Game"], L["Won-Lost"], L["Gold won"], L["Gold lost"], L["Difference"] }
    for c = 1, 5 do place(cell(1, c, hdr[c], UI.GOLD), cols[c][1], y) end
    y = y - 18
    local st, tot = myStats(), { w = 0, l = 0, gw = 0, gl = 0 }
    local GREEN, RED = { 0.40, 0.94, 0.50 }, { 1, 0.45, 0.38 }
    for i, g in ipairs(GAMES) do
      local e = st[g.key] or { w = 0, l = 0, gw = 0, gl = 0 }
      tot.w, tot.l, tot.gw, tot.gl = tot.w + e.w, tot.l + e.l, tot.gw + e.gw, tot.gl + e.gl
      local net = e.gw - e.gl
      place(cell(i + 1, 1, L[g.name]), cols[1][1], y); place(cell(i + 1, 2, e.w .. " - " .. e.l), cols[2][1], y)
      place(cell(i + 1, 3, g0(e.gw)), cols[3][1], y); place(cell(i + 1, 4, g0(e.gl)), cols[4][1], y)
      place(cell(i + 1, 5, (net > 0 and "+" or net < 0 and "-" or "") .. g0(net), net > 0 and GREEN or net < 0 and RED or WHITE), cols[5][1], y)
      y = y - 17
    end
    local net, tr = tot.gw - tot.gl, #GAMES + 2
    place(cell(tr, 1, L["Total"], UI.GOLD), cols[1][1], y - 2); place(cell(tr, 2, tot.w .. " - " .. tot.l, UI.GOLD), cols[2][1], y - 2)
    place(cell(tr, 3, g0(tot.gw), UI.GOLD), cols[3][1], y - 2); place(cell(tr, 4, g0(tot.gl), UI.GOLD), cols[4][1], y - 2)
    place(cell(tr, 5, (net > 0 and "+" or net < 0 and "-" or "") .. g0(net), net > 0 and GREEN or net < 0 and RED or UI.GOLD), cols[5][1], y - 2)
    y = y - 24
    f.resetStats:SetLabel(resetArmed and L["Click again to reset"] or L["Reset statistics"]); place(f.resetStats, 0, y)
    y = y - 36
    -- the gold still open
    f.histTitle:SetText(L["Open payments"]); place(f.histTitle, 0, y); y = y - 18
    local list = GG.Debts()
    f.empty:SetText(#list == 0 and L["Nobody owes you gold and you owe nobody."] or
      L["From games you played. A trade with that player takes the gold off by itself; \"Settled\" clears an entry by hand."])
    f.empty:SetWidth(rw - 10); place(f.empty, 0, y)
    local sumIn, sumOut = 0, 0
    y = y - math.max(16, f.empty:GetStringHeight() or 16) - 8
    for i, e in ipairs(list) do
      if i > 14 then break end
      local r = row(i); r:SetSize(rw - 10, 26); r.card:SetSelected(false); r:SetScript("OnClick", nil)
      if e.copper > 0 then sumIn = sumIn + e.copper; r.name:SetText(string.format(L["%s owes you %s"], e.name, money(e.copper))); r.name:SetTextColor(FLT.TextC(0.40, 0.94, 0.50))
      else sumOut = sumOut - e.copper; r.name:SetText(string.format(L["You owe %s %s"], e.name, money(e.copper))); r.name:SetTextColor(FLT.TextC(1, 0.45, 0.38)) end
      r.name:SetWidth(rw - 120); r.right:SetText("")
      r.btn:SetLabel(L["Settled"]); r.btn:SetWidth(80); r.btn:Show()
      r.btn:SetScript("OnClick", function() GG.Settle(e.name) end)
      place(r, 0, y); y = y - 29
    end
    if #list > 0 then
      f.status:SetText(string.format(L["Owed to you: %s   You owe: %s"], money(sumIn), money(sumOut)))
      f.status:ClearAllPoints(); f.status:SetPoint("TOPLEFT", R, "TOPLEFT", 0, y - 8); f.status:SetJustifyH("LEFT"); f.status:SetWidth(rw); f.status:Show()
      y = y - 30
    end
    if not room then fit(y) end
    return
  end
  f.status:ClearAllPoints(); f.status:SetPoint("TOP", f.tbl, "BOTTOM", 0, -2); f.status:SetJustifyH("CENTER"); f.status:SetWidth(RW)

  local g = GAME[GG.view]
  if not room then -- a game picked, no room yet
    f.head:SetText(L[g.name])
    f.desc:SetWidth(rw - 10); f.desc:SetText(L[g.desc]); f.desc:Show()
    local y = -24 - (f.desc:GetStringHeight() or 40) - 18
    place(f.stakeLabel, 0, y - 4); f.stake:Show(); f.unit:Show()
    place(f.create, 0, y - 34)
    if not guild() then f.create:Disable() else f.create:Enable() end
    fit(y - 34 - 24)
    return
  end

  local pl = playing()
  local mine = myIndex()
  if isHost() and room.phase ~= "play" then -- stake box top right (gg8)
    place(f.stakeLabel, RW - 280, -2); f.stake:Show(); f.unit:Show(); f.setStake:Show()
    if not f.stake:HasFocus() then f.stake:SetText(tostring(room.stake or 0)) end
  end
  f.head:SetText(L[g.name] .. ((room.stake or 0) > 0 and ("  " .. FLT.DOT .. "  " .. string.format(L["Stake: %s"], coins(room.stake, room.unit))) or ""))
  f.tbl:Show()
  layoutSeats()
  drawPay()

  -- the middle of the table
  if room.phase == "lobby" then
    f.center:SetText(isHost() and (#room.players < 2 and L["Invite guild members to the table."] or L["Start when everyone is seated."])
      or L["Waiting for the host to start ..."])
    f.center:Show()
  elseif room.game == "ttt" then
    for i, c in ipairs(cells) do
      local m = room.board:sub(i, i)
      if MARK[m] then c.mark:SetTexture(MARK[m]); c.mark:Show() else c.mark:Hide() end
      c:Show()
      if room.phase == "play" and mine == room.turn and m == "-" then c:Enable() else c:Disable() end
    end
  else
    local max = room.game == "deathroll" and room.cur or ((room.stake or 0) > 0 and room.stake or 100)
    if room.phase == "play" then f.big:SetText("1 - " .. max); f.big:Show() end
    local myTurn = room.phase == "play" and mine and mine <= #pl and
      ((room.game == "deathroll" and room.turn == mine) or (room.game == "highlow" and not room.rolls[mine]))
    if myTurn then f.roll:Show(); if pendingRoll then f.roll:Disable() else f.roll:Enable() end end
  end

  -- status under the table
  local status
  if room.phase == "lobby" then status = nil
  elseif room.phase == "play" then
    local who = room.players[room.turn]
    if room.game == "highlow" then status = mine and mine <= #pl and not room.rolls[mine] and L["Your roll!"] or L["Waiting for the others to roll ..."]
    elseif room.turn == mine then status = room.game == "ttt" and L["Your move!"] or L["Your roll!"]
    else status = string.format(L["Waiting for %s ..."], short(who)) end
  else
    local w, l = room.players[room.win], room.players[room.lose]
    if w then
      status = string.format(L["%s wins!"], short(w)) ..
        ((l and (room.pay or 0) > 0) and ("   " .. string.format(L["%s pays %s %s."], short(l), short(w), coins(room.pay, room.unit))) or "")
    elseif (room.win or 0) == 0 and (room.lose or 0) == 0 then status = L["A draw."] end
  end
  if room.waiting and #room.waiting > 0 then
    local names = {}; for i, n in ipairs(room.waiting) do names[i] = short(n) end
    status = (status and (status .. "\n") or "") .. "|cff9d9d9d" .. string.format(L["Next game: %s"], table.concat(names, ", ")) .. "|r"
  end
  if status then f.status:SetText(status); f.status:Show() end

  -- under the table: log | to pay | balance of this table (gg20); the host's invite list sits in the side list
  local low = f.lowY
  local host = isHost()
  local colW = math.floor(RW / 3)
  f.log:SetWidth(colW - 14); f.pays:SetWidth(colW - 10)
  f.paysTitle:ClearAllPoints(); f.paysTitle:SetPoint("TOPLEFT", R, "TOPLEFT", colW, low)
  f.pays:ClearAllPoints(); f.pays:SetPoint("TOPLEFT", R, "TOPLEFT", colW, low - 16)
  f.logTitle:Show()
  local first = math.max(1, #log - 7)
  f.log:SetText(#log > 0 and table.concat(log, "\n", first, #log) or "-"); f.log:Show()
  do
    f.paysTitle:Show()
    local lines, mine = {}, short(me())
    for i, p in ipairs(sessionPays) do
      if i > 8 then break end
      local open = ""
      if p.from == mine or p.to == mine then
        local other = p.from == mine and p.to or p.from
        local c = debts()[other] or 0
        local stillOpen = (p.to == mine and c > 0) or (p.from == mine and c < 0)
        open = stillOpen and ("  |cffff9944" .. L["open"] .. "|r") or ("  |cff66ff77" .. L["paid"] .. "|r")
      end
      lines[#lines + 1] = p.from .. "  >  " .. p.to .. "   " .. money(p.copper) .. open
    end
    f.pays:SetText(#lines > 0 and table.concat(lines, "\n") or "-"); f.pays:Show()
  end
  do -- balance: what everyone won or lost at this table so far (gg20, user 14.11.: "bei gewonnen gruen, bei minusbetraegen rot")
    local net, names = {}, {}
    for _, p in ipairs(sessionPays) do
      if not net[p.to] then net[p.to] = 0; names[#names + 1] = p.to end
      if not net[p.from] then net[p.from] = 0; names[#names + 1] = p.from end
      net[p.to] = net[p.to] + p.copper; net[p.from] = net[p.from] - p.copper
    end
    table.sort(names, function(a, b) if net[a] ~= net[b] then return net[a] > net[b] end; return a < b end)
    local lines = {}
    for _, n in ipairs(names) do
      local c = net[n]
      if c ~= 0 and #lines < 9 then
        lines[#lines + 1] = n .. "   " .. (c > 0 and "|cff66ff77+" or "|cffff6655-") .. money(c) .. "|r"
      end
    end
    f.balTitle:ClearAllPoints(); f.balTitle:SetPoint("TOPLEFT", R, "TOPLEFT", 2 * colW, low); f.balTitle:Show()
    f.bal:SetWidth(colW - 6); f.bal:ClearAllPoints(); f.bal:SetPoint("TOPLEFT", R, "TOPLEFT", 2 * colW, low - 16)
    f.bal:SetText(#lines > 0 and table.concat(lines, "\n") or "-"); f.bal:Show()
  end
  if host then
    local LW = LEFT - 24
    local top = f.navBottom - 26
    f.inviteTitle:ClearAllPoints(); f.inviteTitle:SetPoint("TOPLEFT", f, "TOPLEFT", 16, top); f.inviteTitle:SetWidth(LW); f.inviteTitle:Show()
    -- a small name search (gg21, user 14.11.: "noch eine kleine suche um nach namen zu suchen")
    f.inviteSearch:ClearAllPoints(); f.inviteSearch:SetPoint("TOPLEFT", f, "TOPLEFT", 20, top - 18); f.inviteSearch:SetWidth(LW - 8)
    if not f.inviteSearch:IsShown() then f.inviteSearch:Show() end
    local q = (f.inviteSearch:GetText() or ""):lower()
    f.inviteSearch.hint:SetShown(q == "" and not f.inviteSearch:HasFocus())
    top = top - 26
    local yy, k, list = top - 20, 0, {}
    local fit = math.max(3, math.floor((H - 22 + (top - 20)) / 27)) -- rows down to the window's bottom
    for name in pairs(players) do
      local inRoom = false; for _, p in ipairs(room.players) do if short(p) == short(name) then inRoom = true end end
      for _, p in ipairs(room.waiting or {}) do if short(p) == short(name) then inRoom = true end end
      if not inRoom and name ~= me() and (q == "" or short(name):lower():find(q, 1, true)) then list[#list + 1] = name end
    end
    table.sort(list)
    -- a long list scrolls with the mouse wheel (gg16); the last line then says how many are left below / above
    if #list > fit then fit = fit - 1 end
    inviteOff = math.max(0, math.min(inviteOff, #list - fit))
    f.inviteWheel:ClearAllPoints(); f.inviteWheel:SetPoint("TOPLEFT", f, "TOPLEFT", 14, top - 18)
    f.inviteWheel:SetSize(LW, (fit + 1) * 27); f.inviteWheel:Show()
    for j = inviteOff + 1, #list do
      local name = list[j]
      k = k + 1; if k > fit then break end
      local r = row(20 + k); r:SetSize(LW, 24); r.right:SetText(""); r.card:SetSelected(false); r:SetScript("OnClick", nil)
      local st = room.invited and room.invited[name]
      r.name:SetWidth(LW - 66); r.name:SetTextColor(FLT.TextC(unpack(WHITE)))
      r.name:SetText(short(name) .. (st == "wait" and ("  |cff9d9d9d" .. L["invited"] .. "|r") or
        (st == "combat" or st == "instance" or st == "busy") and ("  |cffff6655" .. L["busy"] .. "|r") or
        st == "snooze" and ("  |cffff6655" .. L["snoozed"] .. "|r") or
        (st == "no" or st == "timeout") and ("  |cffff6655" .. L["declined"] .. "|r") or ""))
      r.btn:SetLabel(L["Invite"]); r.btn:SetWidth(56); r.btn:Show(); r.btn:SetScript("OnClick", function() GG.Invite(name) end)
      r:ClearAllPoints(); r:SetPoint("TOPLEFT", f, "TOPLEFT", 14, yy); r:Show(); yy = yy - 27
    end
    if #list > fit then
      local below, above = #list - inviteOff - fit, inviteOff
      f.inviteMore:SetText(string.format(L["%d more - scroll with the mouse wheel"], below > 0 and below or above))
      f.inviteMore:SetWidth(LW - 4); f.inviteMore:ClearAllPoints(); f.inviteMore:SetPoint("TOPLEFT", f, "TOPLEFT", 18, yy - 4); f.inviteMore:Show()
    end
    if k == 0 then
      f.empty:SetWidth(LW - 4); f.empty:SetText(L["Nobody from your guild is online with \"Play with Guildies\" switched on."])
      f.empty:ClearAllPoints(); f.empty:SetPoint("TOPLEFT", f, "TOPLEFT", 18, top - 20); f.empty:Show()
    end
  end
  -- buttons bottom right
  f.leave:Show(); f.leave:SetLabel((isHost() and not successor()) and L["Close table"] or L["Leave"])
  if isHost() and room.phase == "lobby" then f.start:Show(); if #room.players >= 2 then f.start:Enable() else f.start:Disable() end end
  if isHost() and room.phase == "done" then f.again:Show() end
end

-- ---------------------------------------------------------------- test bots (gg3, user 14.11.: "virtuelle spieler ...
-- die ich einladen kann? bots also? zum testen"). /ofa play bots switches three bots on / off. They show up in the invite
-- list, accept after a second and play by themselves (random rolls / free fields, no real /roll). Only on the host's
-- client, nothing goes to the guild.
-- gg16 (user 14.11.: "15 bots hinzufuegen, damit man sehen kann wie es aussieht mit mehreren spielern")
local BOT_NAMES = { "Botrolf", "Botilda", "Botmund", "Botgar", "Botrun", "Botwen", "Botrik",
  "Botalia", "Botzug", "Botfrieda", "Botkin", "Botmira", "Botgrim", "Botsha", "Botlo" }
local BOT_LOOKS = { { "Orc", 2, "WARRIOR", 38 }, { "Human", 3, "PRIEST", 36 }, { "Dwarf", 2, "HUNTER", 40 },
  { "Tauren", 2, "DRUID", 33 }, { "Scourge", 2, "ROGUE", 29 }, { "NightElf", 3, "DRUID", 41 }, { "Gnome", 2, "MAGE", 25 },
  { "Human", 3, "PALADIN", 37 }, { "Troll", 2, "SHAMAN", 31 }, { "Dwarf", 3, "PRIEST", 22 }, { "Gnome", 2, "WARLOCK", 34 },
  { "NightElf", 3, "HUNTER", 39 }, { "Orc", 2, "WARLOCK", 27 }, { "Troll", 3, "MAGE", 35 }, { "Scourge", 3, "PRIEST", 30 } }
botMsg = function(msg, bot)
  local t = { strsplit("\t", msg) }
  local function answer(text, delay) C_Timer.After(delay or (0.8 + math.random()), function() if bots and bots[bot] then GG.Receive(text, bot, "WHISPER") end end) end
  if t[1] == "INV" then answer(pack("ACC", t[2]))
  elseif t[1] == "ST" then
    local r = deserialize(t[2], t[3] or "")
    if r.phase ~= "play" then return end
    local idx; for i, p in ipairs(r.players) do if short(p) == short(bot) then idx = i end end
    if not idx or idx > (GAME[r.game] and GAME[r.game].max or 0) then return end
    if r.game == "deathroll" and r.turn == idx and r.cur > 0 then
      answer(pack("ACT", t[2], "roll", math.random(1, r.cur), 1, r.cur))
    elseif r.game == "highlow" and not r.rolls[idx] then
      local max = (r.stake or 0) > 0 and r.stake or 100
      answer(pack("ACT", t[2], "roll", math.random(1, max), 1, max))
    elseif r.game == "ttt" and r.turn == idx then
      local free = {}; for i = 1, 9 do if r.board:sub(i, i) == "-" then free[#free + 1] = i end end
      if #free > 0 then answer(pack("ACT", t[2], "move", free[math.random(#free)])) end
    end
  end
end
function GG.ToggleBots()
  if bots then
    for name in pairs(bots) do players[name] = nil; tables[name] = nil end
    bots = nil
  else
    bots = {}
    local look = BOT_LOOKS
    for i, name in ipairs(BOT_NAMES) do
      bots[name] = true
      players[name] = { t = GetTime(), race = look[i][1], sex = look[i][2], class = look[i][3], level = look[i][4] }
    end
    -- a pretend open table so the list can be looked at (gg11)
    tables["Botilda"] = { id = "bottable", game = "highlow", stake = 20, n = 2, phase = "lobby", bot = true }
  end
  if FLT.Msg then FLT.Msg(bots and string.format(L["Guild Games: %d test bots are there to invite."], #BOT_NAMES) or L["Guild Games: test bots gone."]) end
  GG.Refresh()
  return bots ~= nil
end

function GG.Open()
  if not on() then
    if FLT.Msg then FLT.Msg(L["Switch on \"Play with Guildies\" in Quality of Life > Guild first."]) end
    return
  end
  if snoozeUntil then -- opening the window ends a snooze
    snoozeUntil = nil
    if FLT.Msg then FLT.Msg(L["Guild Games: invites are possible again."]) end
  end
  if not lastTQ or GetTime() - lastTQ > 10 then lastTQ = GetTime(); send(pack("TQ"), "GUILD") end
  if not GG.window then create() end
  GG.window:Show(); GG.Refresh()
  if turnPopup then turnPopup:Hide() end
end
function GG.Toggle()
  if GG.window and GG.window:IsShown() then GG.window:Hide() else GG.Open() end
end
function GG.IsShown() return GG.window and GG.window:IsShown() end
function GG.Room() return room end -- tests
function GG.Me() return me() end -- tests (gg25)
function GG.Players() return players end
function GG.Tables() return tables end
function GG.PendingInvite() return pendingInvite end
function GG.QueryTables() send(pack("TQ"), "GUILD") end
function GG.SetPortrait(tex, name) setPortrait(tex, name) end -- tests (gg27)
