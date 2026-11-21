local _, FLT = ...
local L = FLT.L or setmetatable({}, { __index = function(_, k) return k end }) -- (tests without Locales)
local function N(s) return s end -- marks an English text translated where it is shown (tools/locale/extract.py)
-- names / data texts in the chosen language (Locales/Locale.lua; plain in tests without Locales)
local function ZN(z) return FLT.ZoneName and FLT.ZoneName(z) or z end
local function LN(t) return FLT.LNum and FLT.LNum(t) or t end
local function IN(id, name) if FLT.ItemName then return FLT.ItemName(id, name) end return name end
-- Item API: newer clients only have these under C_Item.
local GetItemInfo = GetItemInfo or (C_Item and C_Item.GetItemInfo)
local GetItemSpell = GetItemSpell or (C_Item and C_Item.GetItemSpell)
local UI = FLT.UI
local makeTexture, makeButton, addDivider = UI.makeTexture, UI.makeButton, UI.addDivider

local PROFESSION_ICONS = {
  Alchemy="Interface\\Icons\\Trade_Alchemy",
  Blacksmithing="Interface\\Icons\\Trade_BlackSmithing",
  Enchanting="Interface\\Icons\\Trade_Engraving",
  Engineering="Interface\\Icons\\Trade_Engineering",
  Leatherworking="Interface\\Icons\\Trade_LeatherWorking",
  Tailoring="Interface\\Icons\\Trade_Tailoring",
  Cooking="Interface\\Icons\\INV_Misc_Food_15",
  Fishing="Interface\\Icons\\Trade_Fishing",
  Herbalism="Interface\\Icons\\Spell_Nature_NatureTouchGrow",
  Mining="Interface\\Icons\\Trade_Mining",
  Skinning="Interface\\Icons\\INV_Misc_Pelt_Wolf_01",
  ["First Aid"]="Interface\\Icons\\Spell_Holy_SealOfSacrifice",
}
FLT.PROFESSION_ICONS = PROFESSION_ICONS
local function _texts() return -- data texts shown with L[...] / FLT.LNum (ExtraData.lua: crates, camping objects; 6.2.0)
  N"First delivery quest", N"Apprentice (white)", N"Apprentice (green)", N"Journeyman (white)", N"Journeyman (green)", N"Expert", N"Artisan", N"One-time introductory reward reported by testers.", N"Sealed Apprentice Crate.", N"Higher-quality Apprentice crate.", N"Sealed Journeyman Crate.", N"Higher-quality Journeyman crate.", N"Reward values are still being verified in beta.", N"Mana regeneration for resting players; exclusive with Blessing of Wisdom.", N"Creates certain reagents and includes the Mana Well benefit.", N"Enables recipes requiring an Alchemy Laboratory and includes the Mana Well benefit.", N"Strength buff for resting players; exclusive with Strength of Earth Totem.", N"Usable campsite anvil plus the Sharpening Wheel benefit.", N"Enables recipes requiring a Forge and includes the Sharpening Wheel benefit.", N"Armor, all-stats and resistance style camping buff; exclusive with Mark of the Wild.", N"More efficient disenchanting utility plus the Enchanted Lute benefit.", N"Enables recipes requiring an Arcane Forge plus the Enchanted Lute benefit.", N"Lets nearby players purchase common reagents.", N"Reagent vendor and gear repairs; upgrades the Reagent Bot.", N"Enables recipes requiring an Anarchist's Workbench.", N"Intellect buff for resting players.", N"Grows herbs from planted seeds and includes the Incense Candle benefit.", N"Multiplies/combines seeds into rarer tiers and includes the Intellect benefit.", N"Increases rested experience up to 5% of a level for resting players.", N"Creates certain reagents and includes the Camp Tent benefit.", N"Enables recipes requiring a Sewing Machine and includes the Camp Tent benefit.", N"Melee Attack Power buff for resting players; exclusive with Blessing of Might.", N"Spawns a common mining node over time and includes the Lodestone benefit.", N"Enables recipes requiring a Foundry and includes the Lodestone benefit.", N"2% increased critical strike chance with attacks and spells; exclusive with Moonkin Aura.", N"Lets players gain Track Beasts and includes the Camp Chair crit benefit.", N"Contains a trap and includes the Camp Chair crit benefit.", N"Spirit buff for same-faction resting players; exclusive with Divine Spirit. The exact amount scales by level in current beta tooltips.", N"Creates certain reagents and includes the Faction Banner benefit.", N"Enables recipes requiring a Loom and includes the Faction Banner benefit.", N"Allows cooking and up to 3 additional camp features; nearby players gain camp benefits after resting/crafting for 1 minute.", N"Allows cooking and up to 5 additional camp features.", N"Provides Stamina-boosting food at the campsite.", N"Allows cooking and up to 10 additional camp features.", N"Required for the most advanced Cooking recipes.", N"Provides a Stamina-style camp buff.", N"Camping utility for healing potions and antivenom; exact beta behavior is still being documented.", N"Advanced campsite healing/poultice utility; exact beta behavior is still being documented.", N"8% increased stats for resting players; exclusive with Blessing of Kings.", N"Catch uncommon fish for 1 hour, provides Fishing Skill lures, and includes the Fish Bowl benefit.", N"Catch rare fish for 1 hour, provides Fishing Skill lures, and includes the Fish Bowl benefit.", N"Basic Campfire", N"Journeyman Campfire", N"Expert Campfire", N"Loot a Waylaid Crate while questing (system starts around level 10).", N"Right-click it to reveal the shipment type and its acceptable material bundles.", N"Fill ONE complete bundle from the list; you do not need every listed option.", N"Turn the sealed crate in at your faction's supply representative.", N"Spend Merchant's Favor at the profession quartermasters on new recipes.", N"West of the Crossroads", N"%s Favor", N"%s Favor + %s SP", N"Varies"
end
-- "Peacebloom x1, Empty Vial x1" in the client's language: item IDs from the recipe reagents (6.2.0)
local reagIDs
local function reagPart(part)
  local lead, name, count = part:match("^(%s*)(.-)( x%d+)$")
  local id = name and reagIDs[name]
  return id and (lead .. (IN(id, name) or name) .. count) or part
end
local function reagText(s)
  if type(s) ~= "string" or not (FLT.ClientTexts and FLT.ClientTexts()) then return s end
  if not reagIDs then
    reagIDs = {}
    for _, list in pairs(FLT.PROFESSION_RECIPES or {}) do
      for _, r in ipairs(list) do for _, g in ipairs(r.r or {}) do if g[3] then reagIDs[g[3]] = g[1] end end end
    end
  end
  return (s:gsub("[^,]+", reagPart))
end


local function createProfessionPanel(parent)
  local panel=CreateFrame("Frame",nil,parent)
  UI.PlacePanel(panel,parent)
  local Card=UI.Card
  local band=UI.TitleBand(panel,{ emblem=UI.ASSET_ROOT.."emblem_professions", art=UI.ASSET_ROOT.."professions_banner",
    title=L["Professions"], subtitle=L["All recipes with sources and reagents, who knows them, Merchant's Favor and camping objects."], fadeRight=320 })

  local _, faction = UnitFactionGroup("player")
  faction = faction or "Horde"
  local hub=(FLT.TRADE_HUBS or {})[faction] or (FLT.TRADE_HUBS or {}).Horde

  local function vendorFor(profession)
    for _,v in ipairs(FLT.PROFESSION_VENDORS or {}) do
      if v.profession == profession then
        local name = faction=="Alliance" and v.alliance or v.horde
        local x = faction=="Alliance" and v.ax or v.hx
        local y = faction=="Alliance" and v.ay or v.hy
        return name or L["Profession quartermaster"], x, y
      end
    end
    return L["Profession quartermaster"]
  end

  local function countRecipes(profession)
    local n=0
    for _,r in ipairs(FLT.MERCHANT_RECIPES or {}) do if r.profession==profession then n=n+1 end end
    return n
  end

  local function getFavorAmount()
    if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
      local info=C_CurrencyInfo.GetCurrencyInfo(3402)
      if info and info.quantity then return info.quantity end
    end
    if GetCurrencyInfo then
      local ok, _, amount = pcall(GetCurrencyInfo, 3402)
      if ok and type(amount)=="number" then return amount end
    end
    return nil
  end

  local favorText -- created with the navigation (on the Merchant's Favor button)

  local function updateFavor()
    local amount=getFavorAmount()
    if not favorText then return end
    favorText:SetText(amount and tostring(amount) or "|cff9d9d9d-|r")
  end
  updateFavor()
  panel:SetScript("OnShow",function() updateFavor() end)


  local nav,navTop=UI.SideNav(panel,-74,"emblem_professions",L["Professions"]) -- ht8: the same side list in every tab

  local body=CreateFrame("Frame",nil,panel)
  body:SetPoint("TOPLEFT",182,-74); body:SetPoint("BOTTOMRIGHT",-8,4)

  -- Profession pages have a sub-navigation (All recipes / Merchant's Favor /
  -- Favor guide) above their content; Camping Buffs uses the full body.
  local subnav=CreateFrame("Frame",nil,body); subnav:SetPoint("TOPLEFT",0,0); subnav:SetPoint("TOPRIGHT",0,0); subnav:SetHeight(32); subnav:Hide()
  local content=CreateFrame("Frame",nil,body); content:SetPoint("TOPLEFT",0,-36); content:SetPoint("BOTTOMRIGHT",0,0)
  local overview=CreateFrame("Frame",nil,content); overview:SetAllPoints(); overview:Hide()
  local campingView=CreateFrame("Frame",nil,body); campingView:SetAllPoints(); campingView:Hide()
  local homeView=CreateFrame("Frame",nil,body); homeView:SetAllPoints(); homeView:Hide()
  local showHome, updateHome, showProfession, showCamping, showFavorPage -- forward
  local skillUpView -- the Skill-Up Helper page, made on first use
  local recipeView=CreateFrame("Frame",nil,content); recipeView:SetAllPoints(); recipeView:Hide()
  local allView=UI.CreateRecipeBrowser and UI.CreateRecipeBrowser(content)
  local navButtons={}

  local function paintActive(b, active) if b.SetActive then b:SetActive(active) end end
  local function setNavButtonState(key)
    for k,b in pairs(navButtons) do paintActive(b, k==key) end
  end

  -- Overview content -------------------------------------------------------
  local ovTitle=UI.SectionTitle(overview,L["How to get Merchant's Favor"],8,-3,-30)

  local ovIntro=FLT.NewFS(overview, nil,"OVERLAY","GameFontHighlightSmall")
  ovIntro:SetPoint("TOPLEFT",8,-31); ovIntro:SetWidth(790); ovIntro:SetJustifyH("LEFT")
  ovIntro:SetText(L["Waylaid Crates are world drops. Use a crate to reveal its shipment, provide one complete material bundle, then deliver the sealed crate to your faction's supply representative."])
  ovIntro:SetTextColor(FLT.SkinC(0.85,0.82,0.75))

  -- Two columns, no inner scrolling: steps + trade hub on the left, the
  -- crate reward table on the right.
  local stepsBox=CreateFrame("Frame",nil,overview); stepsBox:SetPoint("TOPLEFT",0,-72); stepsBox:SetSize(395,190)
  UI.FramedPanel(stepsBox)
  local sh=FLT.NewFS(stepsBox, nil,"OVERLAY","GameFontNormal"); sh:SetPoint("TOPLEFT",12,-10); sh:SetText(L["How it works"]); sh:SetTextColor(FLT.SkinC(1,0.82,0.20))
  local stepY=-34
  for i,step in ipairs(FLT.CRATE_STEPS or {}) do
    local num=FLT.NewFS(stepsBox, nil,"OVERLAY","GameFontNormal"); num:SetPoint("TOPLEFT",12,stepY); num:SetText(i.."."); num:SetTextColor(FLT.SkinC(1,0.76,0.20))
    local fs=FLT.NewFS(stepsBox, nil,"OVERLAY","GameFontHighlightSmall"); fs:SetPoint("TOPLEFT",34,stepY-1); fs:SetWidth(348); fs:SetJustifyH("LEFT"); fs:SetText(L[step])
    stepY=stepY-math.max(20,(fs:GetStringHeight() or 14)+8)
  end
  stepsBox:SetHeight(math.max(150,-stepY+8))

  local hubBox=CreateFrame("Frame",nil,overview); hubBox:SetPoint("TOPLEFT",stepsBox,"BOTTOMLEFT",0,-10); hubBox:SetSize(395,70)
  UI.FramedPanel(hubBox)
  local hf=FLT.NewFS(hubBox, nil,"OVERLAY","GameFontNormal"); hf:SetPoint("TOPLEFT",12,-10); hf:SetWidth(290); hf:SetJustifyH("LEFT"); hf:SetText((hub and hub.name or L["Trade hub"])); hf:SetTextColor(FLT.SkinC(1,0.82,0.20))
  local hw=FLT.NewFS(hubBox, nil,"OVERLAY","GameFontHighlightSmall"); hw:SetPoint("TOPLEFT",12,-32); hw:SetWidth(290); hw:SetJustifyH("LEFT")
  if hub then hw:SetText(string.format("%s, %s\n" .. L["Turn-in: %s"],L[hub.place or ""],ZN(hub.zone or ""),hub.handin and FLT.Name and FLT.Name(hub.handin) or hub.handin or L["supply representative"])) else hw:SetText(L["Location unavailable"]) end
  local hubMap=UI.GoldButton(hubBox,L["Map"],74,22,UI.ASSET_ROOT.."icon_map",12); hubMap:SetPoint("RIGHT",-12,0)
  if hub then hubMap:SetScript("OnClick",function() FLT:ShowOnMap({zone=hub.zone,x=hub.x,y=hub.y,name=hub.name}) end) else hubMap:Disable(); hubMap:SetLook(false) end

  local rewards=CreateFrame("Frame",nil,overview); rewards:SetPoint("TOPLEFT",407,-72); rewards:SetPoint("TOPRIGHT",-22,-72); rewards:SetHeight(330)
  UI.FramedPanel(rewards)
  local rewardsTitle=FLT.NewFS(rewards, nil,"OVERLAY","GameFontNormal")
  rewardsTitle:SetPoint("TOPLEFT",12,-10); rewardsTitle:SetText(L["Crate rewards"]); rewardsTitle:SetTextColor(FLT.SkinC(1,0.82,0.20))
  local rewardHead=CreateFrame("Frame",nil,rewards); rewardHead:SetPoint("TOPLEFT",0,-32); rewardHead:SetPoint("TOPRIGHT",0,-32); rewardHead:SetHeight(22)
  local rhbg=makeTexture(rewardHead,"BACKGROUND",0.075,0.062,0.040,0.96); rhbg:SetPoint("TOPLEFT",4,0); rhbg:SetPoint("BOTTOMRIGHT",-4,0)
  local headers={{12,N"Crate"},{214,N"Level"},{262,N"Reward"}}
  for _,h in ipairs(headers) do local f=FLT.NewFS(rewardHead, nil,"OVERLAY","GameFontNormalSmall"); f:SetPoint("LEFT",h[1],0); f:SetText(L[h[2]]); f:SetTextColor(FLT.SkinC(0.90,0.78,0.53)) end
  local ry=-56
  for i,g in ipairs(FLT.FAVOR_GUIDE or {}) do
    local row=CreateFrame("Button",nil,rewards); row:SetPoint("TOPLEFT",5,ry); row:SetPoint("TOPRIGHT",-5,ry); row:SetHeight(36); ry=ry-38
    UI.CardRow(row)
    local a=FLT.NewFS(row, nil,"OVERLAY","GameFontHighlightSmall"); a:SetPoint("TOPLEFT",12,-5); a:SetWidth(196); a:SetJustifyH("LEFT"); a:SetText(L[g.tier])
    local d=FLT.NewFS(row, nil,"OVERLAY","GameFontDisableSmall"); d:SetPoint("TOPLEFT",12,-20); d:SetWidth(196); d:SetJustifyH("LEFT"); d:SetWordWrap(false); d:SetText(g.note and L[g.note] or "")
    local b=FLT.NewFS(row, nil,"OVERLAY","GameFontHighlightSmall"); b:SetPoint("LEFT",214,0); b:SetWidth(44); b:SetJustifyH("LEFT"); b:SetText(g.level)
    local c=FLT.NewFS(row, nil,"OVERLAY","GameFontNormalSmall"); c:SetPoint("LEFT",262,0); c:SetPoint("RIGHT",-6,0); c:SetJustifyH("LEFT"); c:SetText(LN(g.reward)); c:SetTextColor(FLT.SkinC(1,0.82,0.20))
    row:EnableMouse(true)
    row:SetScript("OnEnter",function(self)
      GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:AddLine(L[g.tier],1,0.82,0)
      GameTooltip:AddLine(string.format(L["Reward: %s"], g.reward and LN(g.reward) or "?"),1,1,1); if g.note then GameTooltip:AddLine(L[g.note],0.8,0.8,0.8,true) end
      GameTooltip:Show()
    end)
    row:SetScript("OnLeave",function() GameTooltip:Hide() end)
  end
  rewards:SetHeight(-ry+8)
  local tip=FLT.NewFS(rewards, nil,"OVERLAY","GameFontDisableSmall")
  tip:SetPoint("TOPLEFT",rewards,"BOTTOMLEFT",4,-6); tip:SetWidth(400); tip:SetJustifyH("LEFT")
  tip:SetText(L["One complete bundle is enough to seal a crate. Beta values can still change."])



  -- Camping buffs / profession objects ------------------------------------
  local campTitle=UI.SectionTitle(campingView,L["Camping Buffs & Profession Objects"],8,-3,-24)
  local campIntro=FLT.NewFS(campingView, nil,"OVERLAY","GameFontHighlightSmall")
  campIntro:SetPoint("TOPLEFT",8,-31); campIntro:SetWidth(790); campIntro:SetJustifyH("LEFT")
  campIntro:SetText(L["Choose a profession below to expand its camping objects. Sit/rest at a campfire to receive applicable buffs. Camping features share a 60-minute cooldown and beta values can change."])
  campIntro:SetTextColor(FLT.SkinC(0.85,0.82,0.75))
  local csf=FLT.SkinBlizz(CreateFrame("ScrollFrame",nil,campingView,"UIPanelScrollFrameTemplate"))
  csf:SetPoint("TOPLEFT",0,-66); csf:SetPoint("BOTTOMRIGHT",-22,0)
  local cchild=CreateFrame("Frame",nil,csf); cchild:SetSize(780,1); csf:SetScrollChild(cchild)
  -- Headers and item rows are created once; expanding/collapsing only
  -- re-positions and shows/hides them.
  local campingGroups={}
  local layoutCamping

  for _,prof in ipairs(FLT.CAMPING_PROFESSIONS or {}) do
    local group={prof=prof, items={}}
    campingGroups[#campingGroups+1]=group

    local ph=CreateFrame("Button",nil,cchild); ph:SetSize(775,36)
    group.header=ph
    UI.CardRow(ph,{0.085,0.078,0.068,0.96},{0.42,0.34,0.20,0.95})
    local toggle=ph:CreateTexture(nil,"OVERLAY"); toggle:SetSize(14,14); toggle:SetPoint("LEFT",13,0); FLT.SetTex(toggle, UI.ASSET_ROOT.."chevron")
    group.toggle=toggle
    local picon=ph:CreateTexture(nil,"ARTWORK"); picon:SetSize(22,22); picon:SetPoint("LEFT",36,0)
    FLT.SetTex(picon, PROFESSION_ICONS[prof.profession] or "Interface\\Icons\\INV_Misc_QuestionMark")
    local pt=FLT.NewFS(ph, nil,"OVERLAY","GameFontNormal")
    pt:SetPoint("LEFT",66,0); pt:SetText(L[prof.profession]); pt:SetTextColor(FLT.SkinC(1,0.82,0.20))
    local count=FLT.NewFS(ph, nil,"OVERLAY","GameFontDisableSmall")
    count:SetPoint("RIGHT",-14,0); count:SetText(string.format(L["%d camping objects"], #(prof.items or {})))
    ph:SetScript("OnClick",function()
      local expanded=OneForAllDB.campingExpanded
      expanded[prof.profession]=not expanded[prof.profession] or nil
      layoutCamping()
    end)

    for ii,obj in ipairs(prof.items or {}) do
      local row=CreateFrame("Button",nil,cchild); row:SetSize(759,44)
      group.items[#group.items+1]=row
      UI.CardRow(row)
      local itemID = obj.id
      if obj.idA and faction=="Alliance" then itemID = obj.idA end
      local ic=row:CreateTexture(nil,"ARTWORK"); ic:SetSize(28,28); ic:SetPoint("TOPLEFT",34,-8)
      FLT.SetTex(ic, (itemID and C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(itemID)) or obj.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
      local nm=FLT.NewFS(row, nil,"OVERLAY","GameFontHighlight"); nm:SetPoint("TOPLEFT",70,-8); nm:SetWidth(170); nm:SetJustifyH("LEFT"); nm:SetText(itemID and IN(itemID, obj.name) or L[obj.name])
      if itemID then
        -- icons of items not cached yet arrive a moment later
        row:SetScript("OnShow",function() local t=C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(itemID); if t then FLT.SetTex(ic, t) end end)
        row:RegisterForClicks("LeftButtonUp")
        row:SetScript("OnClick",function(_,button)
          local H=UI.DungeonHelpers
          if H and H.handleDungeonItemClick then H.handleDungeonItemClick({id=itemID,name=obj.name},button) end
        end)
      end
      local sk=FLT.NewFS(row, nil,"OVERLAY","GameFontNormalSmall"); sk:SetPoint("TOPLEFT",245,-9); sk:SetWidth(72); sk:SetJustifyH("LEFT"); sk:SetText(string.format(L["Skill %s"], tostring(obj.skill or "?"))); sk:SetTextColor(FLT.SkinC(1,0.82,0.20))
      local ef=FLT.NewFS(row, nil,"OVERLAY","GameFontHighlightSmall"); ef:SetPoint("TOPLEFT",325,-8); ef:SetWidth(430); ef:SetJustifyH("LEFT"); ef:SetText(obj.effect and L[obj.effect] or "")
      row:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
        GameTooltip:AddLine(itemID and IN(itemID, obj.name) or L[obj.name],1,0.82,0)
        GameTooltip:AddDoubleLine(L[prof.profession],string.format(L["Requires skill %s"], tostring(obj.skill or "?")),0.65,0.85,1,1,1,1)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(obj.effect and L[obj.effect] or L["Camping feature"],0.25,1.0,0.25,true)
        if obj.reagents and obj.reagents~="" then
          GameTooltip:AddLine(" "); GameTooltip:AddLine(L["Reagents"],1,0.82,0.20); GameTooltip:AddLine(reagText(obj.reagents),0.85,0.85,0.85,true)
        end
        GameTooltip:AddLine(" "); GameTooltip:AddLine(L["All camping features share a 60-minute cooldown. Beta values may change."],0.68,0.68,0.68,true)
        GameTooltip:Show()
      end)
      row:SetScript("OnLeave",function() GameTooltip:Hide() end)
    end
  end

  layoutCamping=function()
    OneForAllDB.campingExpanded = OneForAllDB.campingExpanded or {}
    local cy=-2
    for _,group in ipairs(campingGroups) do
      local expanded=OneForAllDB.campingExpanded[group.prof.profession]==true
      group.header:ClearAllPoints(); group.header:SetPoint("TOPLEFT",0,cy); cy=cy-38
      if expanded then group.toggle:SetTexCoord(0,0.5,0,1) else group.toggle:SetTexCoord(0.5,1,0,1) end
      for _,row in ipairs(group.items) do
        if expanded then
          row:ClearAllPoints(); row:SetPoint("TOPLEFT",16,cy); cy=cy-47; row:Show()
        else
          row:Hide()
        end
      end
      if expanded then cy=cy-6 end
    end
    cchild:SetHeight(math.max(1,-cy+8))
  end

  layoutCamping()

  -- Recipe browser ---------------------------------------------------------
  local recipeTitle=FLT.NewFS(recipeView, nil,"OVERLAY","GameFontNormalLarge")
  recipeTitle:SetPoint("TOPLEFT",8,-3); recipeTitle:SetTextColor(FLT.SkinC(1,0.82,0.20))
  local rtDiv=recipeView:CreateTexture(nil,"ARTWORK"); FLT.SetTex(rtDiv, UI.ASSET_ROOT.."divider_ornate"); rtDiv:SetHeight(14)
  rtDiv:SetPoint("TOPLEFT",4,-48); rtDiv:SetPoint("TOPRIGHT",-24,-48)
  local recipeMeta=FLT.NewFS(recipeView, nil,"OVERLAY","GameFontHighlightSmall")
  recipeMeta:SetPoint("TOPLEFT",8,-31); recipeMeta:SetWidth(665); recipeMeta:SetJustifyH("LEFT"); recipeMeta:SetTextColor(FLT.SkinC(0.82,0.80,0.72))
  local vendorMap=UI.GoldButton(recipeView,L["Vendor"],94,24,UI.ASSET_ROOT.."icon_map",12); vendorMap:SetPoint("TOPRIGHT",-24,-6)
  local earnFavor=UI.GoldButton(recipeView,L["How to earn Favor"],150,24,"Interface\\Icons\\INV_Misc_Coin_02",12); earnFavor:SetPoint("RIGHT",vendorMap,"LEFT",-8,0)
  earnFavor:SetScript("OnClick",function() if showFavorPage then showFavorPage() end end)

  local rhead=UI.ColumnHeader(recipeView,{{x=6,w=500,text=L["Recipe"]},{x=532,w=80,text=L["Skill"]},{x=622,w=140,text=L["Cost"]}},780,-66)
  rhead:ClearAllPoints(); rhead:SetPoint("TOPLEFT",0,-66)

  local rsf=FLT.SkinBlizz(CreateFrame("ScrollFrame",nil,recipeView,"UIPanelScrollFrameTemplate"))
  rsf:SetPoint("TOPLEFT",0,-96); rsf:SetPoint("BOTTOMRIGHT",-22,0)
  local rchild=CreateFrame("Frame",nil,rsf); rchild:SetSize(780,1); rsf:SetScrollChild(rchild)
  local recipeRowsByProfession={}

  local function recipeFullName(recipe)
    return ((FLT.RECIPE_PREFIX or {})[recipe.profession] or "")..recipe.name
  end

  local STAT_LABELS = {
    ITEM_MOD_STRENGTH_SHORT=N"Strength", ITEM_MOD_AGILITY_SHORT=N"Agility", ITEM_MOD_STAMINA_SHORT=N"Stamina",
    ITEM_MOD_INTELLECT_SHORT=N"Intellect", ITEM_MOD_SPIRIT_SHORT=N"Spirit", ITEM_MOD_ARMOR_SHORT=N"Armor",
    ITEM_MOD_DEFENSE_SKILL_RATING_SHORT=N"Defense", ITEM_MOD_ATTACK_POWER_SHORT=N"Attack Power",
    ITEM_MOD_SPELL_POWER_SHORT=N"Spell Power", ITEM_MOD_HEALING_DONE_SHORT=N"Healing",
    ITEM_MOD_CRIT_RATING_SHORT=N"Critical Strike", ITEM_MOD_HIT_RATING_SHORT=N"Hit",
  }

  local function addRuntimeResultDetails(recipe)
    local added=false
    local info = FLT.CRAFTED_RESULT_INFO and FLT.CRAFTED_RESULT_INFO[recipe.name]
    local extra = FLT.PROFESSION_RESULT_INFO and FLT.PROFESSION_RESULT_INFO[recipe.name]

    if info then
      GameTooltip:AddLine(" ")
      GameTooltip:AddLine(L["Crafted result"],1,0.82,0.20)
      GameTooltip:AddLine(recipe.name,0.95,0.95,0.95)
      if info.level then GameTooltip:AddLine(string.format(L["Requires Level %s"], tostring(info.level)),1,1,1) end
      if info.effect then GameTooltip:AddLine(info.effect,0.25,1.00,0.25,true) end
      if info.reagents then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(string.format(L["Reagents: %s"], info.reagents),0.82,0.82,0.82,true)
      end
      return true
    end

    -- Ask the client for the crafted *result* by name.  This works immediately
    -- when the client has already
    -- loaded the item.  It lets us show exact item level / requirements / stats
    -- for Blacksmithing, Leatherworking, Tailoring and Engineering without
    -- duplicating Blizzard's item database.
    local resultName, resultLink, itemLevel, reqLevel, itemType, itemSubType, _
    if GetItemInfo then
      resultName, resultLink, _, itemLevel, reqLevel, itemType, itemSubType = GetItemInfo(recipe.name)
    end
    if resultName then
      GameTooltip:AddLine(" ")
      GameTooltip:AddLine(L["Crafted result"],1,0.82,0.20)
      GameTooltip:AddLine(resultName,0.95,0.95,0.95)
      if itemLevel and itemLevel > 0 then GameTooltip:AddLine(string.format(L["Item Level %s"], tostring(itemLevel)),1,0.82,0) end
      if reqLevel and reqLevel > 0 then GameTooltip:AddLine(string.format(L["Requires Level %s"], tostring(reqLevel)),1,1,1) end
      if itemType and itemType ~= "" then
        local kind=itemType
        if itemSubType and itemSubType ~= "" and itemSubType ~= itemType then kind=kind.." - "..itemSubType end
        GameTooltip:AddLine(kind,0.9,0.9,0.9)
      end
      if GetItemStats and resultLink then
        local stats=GetItemStats(resultLink) or {}
        local shown=0
        for key,value in pairs(stats) do
          if value and value ~= 0 and shown < 10 then
            local label=(type(_G[key])=="string" and _G[key]) or (STAT_LABELS[key] and L[STAT_LABELS[key]]) or key:gsub("^ITEM_MOD_",""):gsub("_SHORT$",""):gsub("_"," "):lower():gsub("^%l",string.upper)
            GameTooltip:AddDoubleLine(label,tostring(value),0.75,0.9,1,1,1,1)
            shown=shown+1
          end
        end
      end
      if GetItemSpell and resultLink then
        local _, spellID = GetItemSpell(resultLink)
        if spellID and GetSpellDescription then
          local d=GetSpellDescription(spellID)
          if d and d ~= "" then GameTooltip:AddLine(d,0.25,1.00,0.25,true) end
        end
      end
      added=true
    end

    -- Enchants and several profession objects are spells rather than normal
    -- inventory results.  Ask the client for the tradeskill spell and append its
    -- real description when available.
    local offline = FLT.GetOfflineProfessionResult and FLT:GetOfflineProfessionResult(recipe) or nil
    -- a crafted item: its spell only says "Creates ..." (in the client's language), the item tooltip shows more (6.2.0:
    -- by the crafted item, the English text alone missed other languages)
    local makesItem = offline and tonumber(offline.craftedItemID) and offline.craftedItemID > 0
    local spellID
    if GetSpellInfo then
      local _,_,_,_,_,_,sid = GetSpellInfo(recipe.name)
      spellID=sid
    end
    if spellID and GetSpellDescription then
      local d=GetSpellDescription(spellID)
      if d and d ~= "" and not makesItem and not d:find("Creates ") then
        if not added then
          GameTooltip:AddLine(" ")
          GameTooltip:AddLine(recipe.profession == "Enchanting" and L["Enchant effect"] or L["Crafted effect"],1,0.82,0.20)
        end
        GameTooltip:AddLine(d,0.25,1.00,0.25,true)
        added=true
      end
    end

    -- Embedded standalone profession data carries the authoritative craft
    -- spell ID.  Prefer the Forever client's real spell description when it is
    -- available; this is especially important for enchants, which often do not
    -- create a normal inventory item.
    if offline and offline.spellID then
      local d
      if C_Spell and C_Spell.GetSpellDescription then
        local ok, value = pcall(C_Spell.GetSpellDescription, offline.spellID)
        if ok then d = value end
      end
      if (not d or d == "") and GetSpellDescription then
        local ok, value = pcall(GetSpellDescription, offline.spellID)
        if ok then d = value end
      end
      if d and d ~= "" and not makesItem and not d:find("Creates ") then
        if not added then
          GameTooltip:AddLine(" ")
          GameTooltip:AddLine(recipe.profession == "Enchanting" and L["Enchant effect"] or L["Crafted effect"],1,0.82,0.20)
        end
        GameTooltip:AddLine(d,0.25,1.00,0.25,true)
        added=true
      end
    end
    if offline and not added and offline.effect and offline.effect ~= "" then
      GameTooltip:AddLine(" ")
      GameTooltip:AddLine(recipe.profession == "Enchanting" and L["Enchant effect"] or L["Crafted effect"],1,0.82,0.20)
      GameTooltip:AddLine(tostring(offline.effect),0.25,1.00,0.25,true)
      added=true
    end
    if offline and not added and offline.stats and next(offline.stats) then
      GameTooltip:AddLine(" ")
      GameTooltip:AddLine(recipe.profession == "Enchanting" and L["Enchant effect"] or L["Crafted stats"],1,0.82,0.20)
      for key,value in pairs(offline.stats) do
        local label=(type(_G[key])=="string" and _G[key]) or (STAT_LABELS[key] and L[STAT_LABELS[key]]) or tostring(key):gsub("^ITEM_MOD_",""):gsub("_SHORT$",""):gsub("_"," ")
        GameTooltip:AddDoubleLine(label,tostring(value),0.75,0.9,1,1,1,1)
      end
      added=true
    end

    if extra then
      if not added then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(extra.label or L["Crafted result"],1,0.82,0.20)
      end
      GameTooltip:AddLine(extra.effect,0.25,1.00,0.25,true)
      added=true
    end

    if not added then
      GameTooltip:AddLine(" ")
      GameTooltip:AddLine(L["Crafted result"],1,0.82,0.20)
      if recipe.profession == "Enchanting" and recipe.name:find("^Enchant ") then
        GameTooltip:AddLine(string.format(L["Applies %s. Exact effect text is loaded automatically when the Forever client exposes this enchant spell."], recipe.name),0.72,0.72,0.72,true)
      else
        GameTooltip:AddLine(recipe.name,0.95,0.95,0.95)
        GameTooltip:AddLine(L["Exact result stats/effect are loaded automatically from the client when the crafted result is available in the item cache."],0.72,0.72,0.72,true)
      end
    end
    return added
  end

  local function showRecipeTooltip(row, recipe, vendor)
    GameTooltip:SetOwner(row,"ANCHOR_RIGHT")
    local full=recipeFullName(recipe)

    -- Preferred path: OneForAll resolves the actual crafted result
    -- directly from WoW Forever's own item/tradeskill APIs. No external addon
    -- is required. If the item data is already available, show Blizzard's
    -- native tooltip; otherwise continue with our built-in fallback and retry
    -- the native tooltip once the client has had a moment to load the item.
    local offline = FLT.GetOfflineProfessionResult and FLT:GetOfflineProfessionResult(recipe) or nil
    if offline and offline.craftedItemID and GameTooltip.SetHyperlink then
      if FLT.RequestRecipeItemData then FLT:RequestRecipeItemData(offline.craftedItemID) end
      -- We already know the exact crafted item ID from the embedded Forever
      -- data, so ask Blizzard's tooltip directly instead of waiting for a name
      -- lookup to succeed first. The client will request the item data if it is
      -- not cached yet.
      local ok = pcall(GameTooltip.SetHyperlink, GameTooltip, "item:"..tostring(offline.craftedItemID))
      if ok then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["Recipe"],1,0.82,0.20)
        GameTooltip:AddLine(full,0.95,0.95,0.95,true)
        GameTooltip:AddDoubleLine(string.format(L["Requires %s"], L[tostring(recipe.profession)]), tostring(recipe.skill or "-"), 1,0.25,0.25, 1,1,1)
        GameTooltip:AddDoubleLine(L["Merchant's Favor"],tostring(recipe.cost),1,0.82,0.20,1,0.82,0.20)
        GameTooltip:AddLine(string.format(L["Sold by %s"], vendor or L["profession quartermaster"]),0.65,0.85,1)
        GameTooltip:Show()
        if C_Timer and C_Timer.After and GetItemInfo and not GetItemInfo(offline.craftedItemID) then
          C_Timer.After(0.35,function()
            if row and row.IsMouseOver and row:IsMouseOver() and GetItemInfo(offline.craftedItemID) then
              showRecipeTooltip(row,recipe,vendor)
            end
          end)
        end
        return
      end
    end
    local itemId = FLT.GetRecipeItemID and FLT:GetRecipeItemID(recipe) or nil
    local link = FLT.GetRecipeItemLink and FLT:GetRecipeItemLink(recipe) or nil

    -- Ask the client for native item data when we know the Forever item ID.
    -- The addon's own crafted-result data is appended in either case so the
    -- player can see what the resulting item actually does.
    if itemId and FLT.RequestRecipeItemData then FLT:RequestRecipeItemData(itemId) end

    local cachedName = nil
    if itemId and GetItemInfo then cachedName = GetItemInfo(itemId) end
    if link and cachedName and GameTooltip.SetHyperlink then
      GameTooltip:SetHyperlink(link)
      addRuntimeResultDetails(recipe)
      GameTooltip:AddLine(" ")
      GameTooltip:AddDoubleLine(L["Merchant's Favor"],tostring(recipe.cost),1,0.82,0.20,1,0.82,0.20)
      GameTooltip:AddLine(string.format(L["Sold by %s"], vendor or L["profession quartermaster"]),0.65,0.85,1)
    else
      GameTooltip:ClearLines()
      GameTooltip:AddLine(full,1,0.82,0)
      GameTooltip:AddLine(L["Binds when picked up"],1,1,1)
      GameTooltip:AddLine(string.format(L["Requires %s"], L[recipe.profession]).." ("..tostring(recipe.skill)..")",1,0.25,0.25)
      GameTooltip:AddLine(" ")
      if recipe.profession == "Enchanting" and recipe.name:find("^Enchant ") then
        GameTooltip:AddLine(string.format(L["Teaches you %s."], recipe.name),0.25,1.00,0.25,true)
      else
        GameTooltip:AddLine(string.format(L["Teaches you how to craft %s."], recipe.name),0.25,1.00,0.25,true)
      end
      addRuntimeResultDetails(recipe)
      GameTooltip:AddLine(" ")
      GameTooltip:AddDoubleLine(L["Cost"],recipe.cost.." "..L["Merchant's Favor"],0.80,0.80,0.80,1,0.82,0.20)
      GameTooltip:AddLine(string.format(L["Sold by %s"], vendor or L["profession quartermaster"]),0.65,0.85,1)
      if itemId then
        GameTooltip:AddLine(string.format(L["Item ID: %s"], tostring(itemId)),0.55,0.55,0.55)
      end
    end
    GameTooltip:Show()
  end


  -- WoW never frees frames, so recipe rows are created once per profession and
  -- afterwards only shown/hidden. (Previously every click created a new set.)
  local function buildRecipeRows(profession, vendor)
    local list={}
    local yoff=-2; local idx=0
    for _,recipe in ipairs(FLT.MERCHANT_RECIPES or {}) do
      if recipe.profession==profession then
        idx=idx+1
        local row=CreateFrame("Button",nil,rchild); row:SetSize(778,31); row:SetPoint("TOPLEFT",1,yoff); yoff=yoff-34
        UI.CardRow(row)
        local icon=row:CreateTexture(nil,"ARTWORK"); icon:SetSize(20,20); icon:SetPoint("LEFT",10,0); FLT.SetTex(icon, "Interface\\Icons\\INV_Misc_Note_01")
        local nm=FLT.NewFS(row, nil,"OVERLAY","GameFontHighlight"); nm:SetPoint("LEFT",40,0); nm:SetWidth(480); nm:SetJustifyH("LEFT"); nm:SetText(recipe.name)
        local sk=FLT.NewFS(row, nil,"OVERLAY","GameFontHighlightSmall"); sk:SetPoint("LEFT",540,0); sk:SetWidth(70); sk:SetJustifyH("LEFT"); sk:SetText(recipe.skill)
        local co=FLT.NewFS(row, nil,"OVERLAY","GameFontNormalSmall"); co:SetPoint("LEFT",630,0); co:SetWidth(125); co:SetJustifyH("LEFT"); co:SetText(recipe.cost.." Favor"); co:SetTextColor(FLT.SkinC(1,0.82,0.20))
        row:SetScript("OnEnter",function(self) showRecipeTooltip(self,recipe,vendor) end)
        row:SetScript("OnLeave",function() GameTooltip:Hide() end)
        list[#list+1]=row
      end
    end
    list.height=math.max(1,-yoff+8)
    return list
  end

  local function showFavorRecipes(profession)
    recipeView:Show()
    local vendor,x,y=vendorFor(profession)
    local count=countRecipes(profession)
    recipeTitle:SetText(L[profession].." - "..L["Merchant's Favor Recipes"])
    recipeMeta:SetText(string.format("%s  |  "..L["%d recipes"].."  |  %s",FLT.Name and FLT.Name(vendor) or vendor,count,hub and (L[hub.place]..", "..ZN(hub.zone)) or L["trade hub"]))
    vendorMap:SetScript("OnClick",nil)
    if x and y and hub then vendorMap:Enable(); vendorMap:SetLook(true); vendorMap:SetScript("OnClick",function() FLT:ShowOnMap({zone=hub.zone,x=x,y=y,name=vendor}) end) else vendorMap:Disable(); vendorMap:SetLook(false) end

    for key,list in pairs(recipeRowsByProfession) do
      if key~=profession then for _,row in ipairs(list) do row:Hide() end end
    end
    local list=recipeRowsByProfession[profession]
    if not list then list=buildRecipeRows(profession,vendor); recipeRowsByProfession[profession]=list end
    for _,row in ipairs(list) do row:Show() end
    rchild:SetHeight(list.height); rsf:SetVerticalScroll(0)
  end

  -- Overview (landing page) ------------------------------------------------
  -- Professions of the current character (crafting + gathering + secondary).
  local function playerProfessions()
    local out, seen = {}, {}
    local function add(name, rank, maxRank)
      name = FLT.ProfKey and FLT.ProfKey(name) or name -- the client names it in its language: our key (6.2.0)
      if name and PROFESSION_ICONS[name] and not seen[name] then seen[name]=true; out[#out+1]={name=name, rank=rank, max=maxRank} end
    end
    if GetProfessions and GetProfessionInfo then
      local list={GetProfessions()}
      for k=1,6 do
        if list[k] then local ok,name,_,rank,maxRank=pcall(GetProfessionInfo,list[k]); if ok then add(name,rank,maxRank) end end
      end
    end
    if GetNumSkillLines and GetSkillLineInfo then
      for i=1,GetNumSkillLines() or 0 do
        local name,isHeader,_,rank,_,_,maxRank=GetSkillLineInfo(i)
        if not isHeader then add(name,rank,maxRank) end
      end
    end
    if type(OneForAllCharDB)=="table" and type(OneForAllCharDB.professions)=="table" then
      for name,p in pairs(OneForAllCharDB.professions) do if p.skill then add(name,p.skill,p.maxSkill) end end
    end
    table.sort(out,function(a,b) return a.name<b.name end)
    return out
  end

  local homeIntro=FLT.NewFS(homeView, nil,"OVERLAY","GameFontHighlightSmall")
  homeIntro:SetPoint("TOPLEFT",8,-8); homeIntro:SetWidth(780); homeIntro:SetJustifyH("LEFT"); homeIntro:SetTextColor(FLT.SkinC(0.85,0.82,0.75))
  homeIntro:SetText(L["Pick a profession to browse all of its recipes (where to learn them, reagents, who in your guild knows them) or the Merchant's Favor recipes. Camping Buffs lists the campsite objects of every profession."])

  local function sectionTitle(text, y) return UI.SectionTitle(homeView,text,8,y,-22) end
  local function makeTile(w)
    local t=CreateFrame("Button",nil,homeView); t:SetSize(w,42)
    UI.CardRow(t)
    t.icon=t:CreateTexture(nil,"ARTWORK"); t.icon:SetSize(28,28); t.icon:SetPoint("LEFT",8,0)
    t.name=FLT.NewFS(t, nil,"OVERLAY","GameFontNormal"); t.name:SetPoint("TOPLEFT",44,-6); t.name:SetTextColor(FLT.SkinC(1,0.82,0.20))
    t.sub=FLT.NewFS(t, nil,"OVERLAY","GameFontHighlightSmall"); t.sub:SetPoint("TOPLEFT",44,-23); t.sub:SetWidth(w-50); t.sub:SetJustifyH("LEFT"); t.sub:SetWordWrap(false)
    return t
  end

  sectionTitle(L["Your professions"],-44)
  local ownTiles={}
  local ownNone=FLT.NewFS(homeView, nil,"OVERLAY","GameFontDisableSmall"); ownNone:SetPoint("TOPLEFT",10,-74)
  ownNone:SetText(L["No professions found yet - learn one at a trainer or open your profession window once."])
  local allTitle=sectionTitle(L["All professions"],-172)
  local allTiles, allOrder={}, {}
  for i,profession in ipairs(FLT.PROFESSION_ORDER or {}) do
    local t=makeTile(190); allOrder[i]=t
    FLT.SetTex(t.icon, PROFESSION_ICONS[profession]); t.name:SetText(L[profession])
    t:SetScript("OnClick",function() showProfession(profession) end)
    allTiles[profession]=t
  end
  local nRows=math.ceil(#(FLT.PROFESSION_ORDER or {})/4)
  local campTile=makeTile(250)
  local otherTitle=sectionTitle(L["Others"],-400)
  -- position the "All professions" block below the own professions
  -- Nearest trainers: for every profession the closest friendly trainer on your
  -- continent (QuestieDB Forever positions, Data\ProfessionTrainers.lua) with a Map button.
  local layoutTrainers
  local TRAINER_ORDER={N"Alchemy",N"Blacksmithing",N"Enchanting",N"Engineering",N"Leatherworking",N"Tailoring",N"Cooking",N"First Aid",N"Fishing",N"Herbalism",N"Mining",N"Skinning"}
  local trainerTitle=sectionTitle(L["Nearest trainers"],-520)
  local trainerBox=CreateFrame("Frame",nil,homeView); trainerBox:SetSize(784,4*24+12)
  UI.FramedPanel(trainerBox)
  -- thin gold lines between the three columns
  for k=1,2 do
    local ln=trainerBox:CreateTexture(nil,"ARTWORK"); ln:SetWidth(1)
    ln:SetPoint("TOP",trainerBox,"TOPLEFT",8+k*258-3,-8); ln:SetPoint("BOTTOM",trainerBox,"BOTTOMLEFT",8+k*258-3,8)
    ln:SetColorTexture(FLT.SkinC(0.72,0.55,0.25,0.45))
  end
  local trainerRows={}
  for i,prof in ipairs(TRAINER_ORDER) do
    local r=CreateFrame("Frame",nil,trainerBox); r:SetSize(254,22); r:EnableMouse(true)
    local hi=r:CreateTexture(nil,"HIGHLIGHT"); hi:SetAllPoints(); hi:SetColorTexture(FLT.SkinC(0.90,0.66,0.22,0.08))
    r.icon=r:CreateTexture(nil,"ARTWORK"); r.icon:SetSize(16,16); r.icon:SetPoint("LEFT",4,0); FLT.SetTex(r.icon, PROFESSION_ICONS[prof]); r.icon:SetTexCoord(0.08,0.92,0.08,0.92)
    r.name=FLT.NewFS(r,nil,"OVERLAY","GameFontNormalSmall"); r.name:SetPoint("LEFT",26,0); r.name:SetWidth(94); r.name:SetJustifyH("LEFT"); r.name:SetWordWrap(false)
    r.sub=FLT.NewFS(r,nil,"OVERLAY","GameFontHighlightSmall"); r.sub:SetPoint("LEFT",122,0); r.sub:SetWidth(106); r.sub:SetJustifyH("LEFT"); r.sub:SetWordWrap(false)
    r.sub:SetTextColor(0.80,0.78,0.72)
    r.map=CreateFrame("Button",nil,r); r.map:SetSize(18,18); r.map:SetPoint("RIGHT",-4,0)
    local mt=r.map:CreateTexture(nil,"ARTWORK"); mt:SetAllPoints(); FLT.SetTex(mt, UI.ASSET_ROOT.."icon_map"); r.map.tex=mt
    r.map:SetHighlightTexture(UI.ASSET_ROOT.."icon_map","ADD")
    function r.map:SetLook(on) mt:SetAlpha(on and 1 or 0.3) end
    r.prof=prof
    r:SetScript("OnEnter",function(self)
      GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:AddLine(string.format(L["%s trainer"], L[prof]),1,0.82,0)
      local tr=self.trainer
      if tr then
        GameTooltip:AddLine(tr[2].."  |cff9d9d9d<"..tr[3]..">|r",1,1,1)
        GameTooltip:AddLine(string.format("%s (%.1f, %.1f)",tr[8],tr[6],tr[7]),0.85,0.82,0.74)
        if self.dist then GameTooltip:AddLine(string.format(L["About %d yards away"],math.floor(self.dist/10+0.5)*10),0.7,0.7,0.7) end
      else
        GameTooltip:AddLine(L["No trainer known on this continent."],0.8,0.8,0.8,true)
      end
      GameTooltip:Show()
    end)
    r:SetScript("OnLeave",function() GameTooltip:Hide() end)
    trainerRows[i]=r
  end
  layoutTrainers=function(top)
    trainerTitle:ClearAllPoints(); trainerTitle:SetPoint("TOPLEFT",8,top)
    trainerBox:ClearAllPoints(); trainerBox:SetPoint("TOPLEFT",8,top-26)
    -- the navigation ends level with the trainer box on the overview (user 22.10.)
    nav:SetHeight(math.max(300, 26-top+trainerBox:GetHeight()))
    for i,r in ipairs(trainerRows) do r:ClearAllPoints(); r:SetPoint("TOPLEFT",8+((i-1)%3)*258,-6-math.floor((i-1)/3)*24) end
  end
  local worldCache={}
  local function worldPos(map,x,y)
    if not (C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D) then return nil end
    local ok,cont,pos=pcall(C_Map.GetWorldPosFromMapPos,map,CreateVector2D(x/100,y/100))
    if ok and cont and pos then return cont,pos.x,pos.y end
  end
  local function trainerWorld(tr)
    local c=worldCache[tr]
    if c==nil then local a,b,d=worldPos(tr[5],tr[6],tr[7]); c=a and {a,b,d} or false; worldCache[tr]=c end
    return c or nil
  end
  local function updateTrainers()
    local fac=UnitFactionGroup and UnitFactionGroup("player")
    local mine=(fac=="Alliance" and "A") or (fac=="Horde" and "H") or nil
    local pc,px,py
    if C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition then
      local map=C_Map.GetBestMapForUnit("player")
      local p=map and C_Map.GetPlayerMapPosition(map,"player")
      if p then local x,y=p.x or 0,p.y or 0; pc,px,py=worldPos(map,x*100,y*100) end
    end
    for _,r in ipairs(trainerRows) do
      local best,bestD
      for _,tr in ipairs(FLT.PROFESSION_TRAINERS and FLT.PROFESSION_TRAINERS[r.prof] or {}) do
        if not mine or tr[4]:find(mine,1,true) then
          local w=pc and trainerWorld(tr)
          if w and w[1]==pc then
            local d=math.sqrt((w[2]-px)^2+(w[3]-py)^2)
            if not bestD or d<bestD then best,bestD=tr,d end
          end
        end
      end
      r.trainer,r.dist=best,bestD
      r.name:SetText(L[r.prof])
      if best then
        r.sub:SetText(best[2]..", "..best[8]); r.map:Enable(); r.map:SetLook(true)
        r.map:SetScript("OnClick",function() FLT:ShowOnMap({mapID=best[5],x=best[6],y=best[7],name=best[2].." ("..L[r.prof]..")"}) end)
      else
        r.sub:SetText(L["none on this continent"]); r.map:Disable(); r.map:SetLook(false)
      end
    end
  end

  local function layoutAll(top)
    allTitle:ClearAllPoints(); allTitle:SetPoint("TOPLEFT",8,top)
    for i,t in ipairs(allOrder) do t:ClearAllPoints(); t:SetPoint("TOPLEFT",8+((i-1)%4)*198,top-28-math.floor((i-1)/4)*48) end
    local oy=top-28-nRows*48-4
    otherTitle:ClearAllPoints(); otherTitle:SetPoint("TOPLEFT",8,oy)
    campTile:ClearAllPoints(); campTile:SetPoint("TOPLEFT",8,oy-28)
    if layoutTrainers then layoutTrainers(oy-28-42-10) end
  end
  FLT.SetTex(campTile.icon, "Interface\\Icons\\Spell_Fire_Fire"); campTile.name:SetText(L["Camping Buffs"])
  campTile.sub:SetText(L["Campsite objects of every profession"])
  campTile:SetScript("OnClick",function() showCamping() end)
  local favorTile=makeTile(250); favorTile:SetPoint("LEFT",campTile,"RIGHT",12,0)
  FLT.SetTex(favorTile.icon, "Interface\\Icons\\INV_Misc_Coin_02"); favorTile.name:SetText(L["Merchant's Favor"])
  favorTile:SetScript("OnClick",function() showFavorPage() end)

  local function recipeSummary(profession)
    local list=FLT.PROFESSION_RECIPES and FLT.PROFESSION_RECIPES[profession]
    if not list then return nil end
    local p=FLT.GetProfessionState and FLT.GetProfessionState(profession)
    local known=0
    if p and p.known then for _,r in ipairs(list) do if p.known[r.s] then known=known+1 end end end
    return known, #list
  end

  updateHome=function()
    -- own professions
    local own=playerProfessions()
    for _,t in ipairs(ownTiles) do t:Hide() end
    for i,pr in ipairs(own) do
      if i>8 then break end
      local t=ownTiles[i]
      if not t then t=makeTile(190); ownTiles[i]=t end
      t:ClearAllPoints(); t:SetPoint("TOPLEFT",8+((i-1)%4)*198,-74-math.floor((i-1)/4)*48)
      FLT.SetTex(t.icon, PROFESSION_ICONS[pr.name]); t.name:SetText(L[pr.name])
      local sk=pr.rank and (pr.rank..(pr.max and ("/"..pr.max) or ""))
      local known,total=recipeSummary(pr.name)
      -- one sentence for the tile (beta6: German "Fertigkeit 32/75 | 5 bekannt" was cut off - the translation may drop words)
      local txt=(sk and known) and string.format(L["Skill %s  |cff9d9d9d|  %d known|r"], sk, known)
        or (sk and string.format(L["Skill %s"], sk)) or L["Skill unknown"]
      t.sub:SetText(txt)
      local name=pr.name
      local hasPage=false
      for _,o in ipairs(FLT.PROFESSION_ORDER or {}) do if o==name then hasPage=true end end
      t:SetScript("OnClick",function() if hasPage then showProfession(name) else showCamping() end end)
      t:Show()
    end
    ownNone:SetShown(#own==0)
    local ownRows=math.max(1,math.ceil(math.min(#own,8)/4))
    layoutAll(-74-ownRows*48-10)
    updateTrainers()
    -- all professions
    for profession,t in pairs(allTiles) do
      local known,total=recipeSummary(profession)
      local nFav=countRecipes(profession)
      if known then
        t.sub:SetText(string.format(L["%d recipes"], total).."  |cff9d9d9d|  "..string.format(L["%d known"], known).."|r")
      else
        t.sub:SetText(string.format(L["%d Merchant's Favor recipes"], nFav).."  |cff9d9d9d|  "..L["more soon"].."|r")
      end
    end
    local amount=getFavorAmount()
    favorTile.sub:SetText(amount and (string.format(L["You have %s Favor"], amount).."  |cff9d9d9d|  "..L["how to earn it"].."|r") or L["How to earn Favor"])
  end

  -- Sub-navigation inside a profession: "All recipes" | "Merchant's Favor".
  local currentProfession, currentSub = nil, nil
  local subButtons, subX = {}, 0
  for _,spec in ipairs({{"all",N"All recipes"},{"fav",N"Favorites"},{"skillup",N"Skill-Up Helper"},{"profit",N"Profit"},{"favor",N"Merchant's Favor"}}) do
    local b=UI.GoldButton(subnav,L[spec[2]],(spec[1]=="favor" or spec[1]=="skillup") and 150 or 120,26,nil,13); b:SetPoint("TOPLEFT",subX,-2); subX=subX+b:GetWidth()+6
    b:SetScript("OnClick",function()
      if currentProfession then showProfession(currentProfession, spec[1]) end
    end)
    subButtons[spec[1]]=b
  end
  -- 6.2.6: the Skill-Up Helper (UI/SkillUpUI.lua, logic SkillUp.lua) - new in this version (TODO.md "Neu-Markierungen")
  -- 6.2.6-beta28: the Profit page (UI/ProfitUI.lua) - new in this version; the Crafting List button moved into
  -- All recipes / Favorites (UI/ProfessionRecipes.lua, user 12.11.: "dort besser aufgehoben")
  local profitView -- made on first use

  -- Merchant's Favor page (own entry in the left menu) -----------------------
  local favorPage=CreateFrame("Frame",nil,body); favorPage:SetAllPoints(); favorPage:Hide()
  local fsf=FLT.SkinBlizz(CreateFrame("ScrollFrame",nil,favorPage,"UIPanelScrollFrameTemplate"))
  fsf:SetPoint("TOPLEFT",0,0); fsf:SetPoint("BOTTOMRIGHT",-4,0)
  local fchild=CreateFrame("Frame",nil,fsf); fchild:SetSize(790,1); fsf:SetScrollChild(fchild)
  local fpSub=UI.SectionTitle(fchild,L["Favor recipes by profession"],8,-6,-30)
  local favorTiles, nTiles = {}, 0
  for _,profession in ipairs(FLT.PROFESSION_ORDER or {}) do
    local n=countRecipes(profession)
    if n>0 then
      nTiles=nTiles+1
      local i=nTiles
      local t=CreateFrame("Button",nil,fchild); t:SetSize(190,48)
      t:SetPoint("TOPLEFT",8+((i-1)%4)*198,-36-math.floor((i-1)/4)*56)
      UI.CardRow(t)
      local ic=t:CreateTexture(nil,"ARTWORK"); ic:SetSize(32,32); ic:SetPoint("LEFT",10,0); FLT.SetTex(ic, PROFESSION_ICONS[profession])
      local nm=FLT.NewFS(t, nil,"OVERLAY","GameFontNormal"); nm:SetPoint("TOPLEFT",50,-8); nm:SetText(L[profession]); nm:SetTextColor(FLT.SkinC(1,0.82,0.20))
      local sb=FLT.NewFS(t, nil,"OVERLAY","GameFontHighlightSmall"); sb:SetPoint("TOPLEFT",50,-27); sb:SetText(string.format(L["%d Favor recipes"], n))
      t:SetScript("OnClick",function() showProfession(profession,"favor") end)
      favorTiles[#favorTiles+1]=t
    end
  end
  local guideTop=-36-math.ceil(nTiles/4)*56-14
  -- the guide (crate steps, trade hub, rewards) below the tiles
  overview:SetParent(fchild); overview:ClearAllPoints(); overview:SetPoint("TOPLEFT",0,guideTop); overview:SetSize(780,440); overview:Show()
  fchild:SetHeight(-guideTop+450)

  local function setContentTop(y) content:ClearAllPoints(); content:SetPoint("TOPLEFT",0,y); content:SetPoint("BOTTOMRIGHT",0,0) end
  local function hideViews()
    if allView then allView:Hide() end
    recipeView:Hide(); campingView:Hide(); homeView:Hide(); favorPage:Hide()
    if skillUpView then skillUpView:Hide() end
    if profitView then profitView:Hide() end
    nav:SetHeight(481)
  end
  showProfession=function(profession,sub)
    local hasAll=allView and FLT.PROFESSION_RECIPES and FLT.PROFESSION_RECIPES[profession]
    if sub=="guide" then sub="favor" end
    sub=sub or (currentProfession==profession and currentSub) or (hasAll and "all" or "favor")
    if (sub=="all" or sub=="fav") and not hasAll then sub="favor" end
    local hasSkillUp=FLT.SkillUp and FLT.SkillUp.PROFS[profession] and UI.CreateSkillUpPage and hasAll
    if (sub=="skillup" or sub=="profit") and not hasSkillUp then sub=hasAll and "all" or "favor" end
    currentProfession, currentSub = profession, sub
    hideViews(); subnav:Show(); setNavButtonState(profession)
    if hasAll then subButtons.all:Show(); subButtons.fav:Show() else subButtons.all:Hide(); subButtons.fav:Hide() end
    -- keep the visible sub buttons packed from the left
    local x=0
    subButtons.skillup:SetShown(hasSkillUp and true or false)
    subButtons.profit:SetShown(hasSkillUp and UI.CreateProfitPage and true or false)
    for _,k in ipairs({"all","fav","skillup","profit","favor"}) do
      local b=subButtons[k]
      if b:IsShown() then b:ClearAllPoints(); b:SetPoint("TOPLEFT",x,-2); x=x+b:GetWidth()+6 end
      paintActive(b, k==sub)
    end
    setContentTop(-36)
    if sub=="all" or sub=="fav" then allView:ShowProfession(profession, sub)
    elseif sub=="skillup" then
      if allView then allView:Hide() end
      skillUpView=skillUpView or UI.CreateSkillUpPage(content)
      skillUpView:ShowProfession(profession)
    elseif sub=="profit" then
      if allView then allView:Hide() end
      profitView=profitView or UI.CreateProfitPage(content)
      profitView:ShowProfession(profession)
    else showFavorRecipes(profession) end
  end

  -- Key bindings (6.2.6, user 12.11.): open the Skill-Up Helper / Profit of the profession shown last, else of the last
  -- Skill-Up guide, else the first own crafting profession; without one the professions home page
  FLT.ShowProfessionSub = function(sub)
    local SUx = FLT.SkillUp
    local ok = function(p) return p and SUx and SUx.PROFS[p] end
    local prof = ok(currentProfession) and currentProfession
    local last = type(OneForAllCharDB) == "table" and OneForAllCharDB.skillUpLast
    if not prof and type(last) == "table" and ok(last.prof) then prof = last.prof end
    if not prof then
      local own = type(OneForAllCharDB) == "table" and OneForAllCharDB.professions or {}
      for _, p in ipairs(FLT.PROFESSION_ORDER or {}) do
        if ok(p) and type(own[p]) == "table" and (tonumber(own[p].skill) or 0) > 0 then prof = p; break end
      end
    end
    if prof then showProfession(prof, sub) else showHome() end
  end

  -- is that page on screen right now? (the key then closes the window again, user 12.11.)
  FLT.ProfessionSubShown = function(sub)
    local v = (sub == "skillup" and skillUpView) or (sub == "profit" and profitView)
    return currentSub == sub and v and v:IsVisible() and true or false
  end

  -- Jump straight to a recipe (dungeon loot -> Professions tab).
  FLT.ShowRecipeInProfessions = function(profession, spell)
    if not allView then return end
    showProfession(profession, "all")
    if allView.SelectRecipe then allView:SelectRecipe(profession, spell) end
  end

  showFavorPage=function()
    hideViews(); subnav:Hide(); favorPage:Show(); setNavButtonState("favor"); updateFavor()
    fsf:SetVerticalScroll(0)
  end

  showCamping=function()
    hideViews(); subnav:Hide(); campingView:Show(); setNavButtonState("camping")
  end
  showHome=function()
    hideViews(); subnav:Hide(); homeView:Show(); setNavButtonState("home"); updateHome()
  end
  -- 6.2.12-beta25 (tester Deaders 19.11.: a profession learned / unlearned showed only after switching pages): the overview
  -- follows SKILL_LINES_CHANGED while it is visible (next frame, after ProfessionRecipes has read the skill lines)
  do
    local ev=CreateFrame("Frame"); ev:RegisterEvent("SKILL_LINES_CHANGED")
    ev:SetScript("OnEvent",function()
      if homeView:IsVisible() and C_Timer then C_Timer.After(0,function() if homeView:IsVisible() then updateHome() end end) end
    end)
  end

  -- Left navigation: Overview, the professions, Camping Buffs (last).
  -- (5.7.0: the separate Merchant's Favor box at the bottom is gone, its button shows the amount, user 22.10.)
  local navY=navTop
  local homeButton; homeButton,navY=UI.NavEntry(nav,navY,L["Overview"],"Interface\\Icons\\INV_Misc_Book_09")
  homeButton:SetScript("OnClick",function() showHome() end); navButtons.home=homeButton
  navY=UI.NavSeparator(nav,navY)
  for _,profession in ipairs(FLT.PROFESSION_ORDER or {}) do
    local b; b,navY=UI.NavEntry(nav,navY,L[profession],PROFESSION_ICONS[profession] or "Interface\\Icons\\INV_Misc_QuestionMark")
    b:SetScript("OnClick",function() showProfession(profession) end)
    navButtons[profession]=b
  end
  navY=UI.NavSeparator(nav,navY)
  local campingButton; campingButton,navY=UI.NavEntry(nav,navY,L["Camping Buffs"],"Interface\\Icons\\Spell_Fire_Fire")
  campingButton:SetScript("OnClick",showCamping); navButtons.camping=campingButton
  -- ht8: one line like the other entries, your Merchant's Favor as the count on the right (like the QoL counts)
  local favorButton; favorButton,navY=UI.NavEntry(nav,navY,L["Merchant's Favor"],"Interface\\Icons\\INV_Misc_Coin_02")
  favorText=FLT.NewFS(favorButton, nil,"OVERLAY","GameFontDisableSmall"); favorText:SetPoint("RIGHT",-5,0)
  do local font,_,flags=favorText:GetFont(); if font then favorText:SetFont(font,10,flags) end end
  favorButton:SetScript("OnClick",function() showFavorPage() end); navButtons.favor=favorButton

  updateFavor()
  showHome()
  panel:Hide(); return panel
end


UI.RegisterPanel({ key="professions", label=N"Professions", order=3, tabWidth=132, create=createProfessionPanel })
