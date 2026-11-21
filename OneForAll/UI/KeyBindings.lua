local _, FLT = ...
local L = FLT.L or setmetatable({}, { __index = function(_, k) return k end })

-- Key bindings (6.2.6, user 12.11.: "jeden hauptreiter als einzelnen keybind ... crafting list ... skill-up helper und
-- profit"): Options > Keybindings > OneForAll (Bindings.xml calls OneForAll_Binding(key)). A tab key opens the window on
-- that tab, or closes it when it already shows that tab. Names are set at login, when the language is known.
local UI = FLT.UI
local TABS = { dungeons = "Dungeons & Raids", armory = "Armory", professions = "Professions",
  qol = "Quality of Life", talents = "Talent Trees", books = "Library Books", pets = "Hunter Pets", settings = "Settings" }

local function openTab(key)
  if UI.IsWindowShown() and UI.ActiveTab() == key then FLT:ToggleUI(); return end
  FLT:OpenPanel(key)
end

-- Skill-Up Helper / Profit: open that page, or close the window when it already shows it
local function openSub(sub)
  if UI.IsWindowShown() and FLT.ProfessionSubShown and FLT.ProfessionSubShown(sub) then FLT:ToggleUI(); return end
  FLT:OpenPanel("professions"); if FLT.ShowProfessionSub then FLT.ShowProfessionSub(sub) end
end

local ACTIONS = {
  window = function() FLT:ToggleUI() end,
  craftlist = function() if FLT.CraftList and FLT.CraftList.Toggle then FLT.CraftList.Toggle() end end,
  guide = function() if FLT.SkillUp and FLT.SkillUp.ToggleLastGuide then FLT.SkillUp.ToggleLastGuide() end end,
  skillup = function() openSub("skillup") end,
  profit = function() openSub("profit") end,
  games = function() if FLT.GuildGames then FLT.GuildGames.Toggle() end end,
}
for key in pairs(TABS) do ACTIONS[key] = function() openTab(key) end end

function OneForAll_Binding(key)
  local f = ACTIONS[key]
  if f and FLT.SafeCall then FLT.SafeCall("Binding", f) elseif f then f() end
end

local function names()
  _G.BINDING_HEADER_ONEFORALL = "OneForAll"
  _G.BINDING_NAME_ONEFORALL_WINDOW = "OneForAll"
  for key, label in pairs(TABS) do _G["BINDING_NAME_ONEFORALL_TAB_" .. key:upper()] = L[label] end
  _G.BINDING_NAME_ONEFORALL_CRAFTLIST = L["Crafting List"]
  _G.BINDING_NAME_ONEFORALL_SKILLUP = L["Skill-Up Helper"]
  _G.BINDING_NAME_ONEFORALL_GUIDE = L["Skill-Up Helper"] .. ": " .. L["Open guide"]
  _G.BINDING_NAME_ONEFORALL_PROFIT = L["Profit"]
  _G.BINDING_NAME_ONEFORALL_GAMES = L["Guild Games"]
end
names()
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(self) self:UnregisterAllEvents(); names() end)
