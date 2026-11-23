local _, FLT = ...
local function N(s) return s end -- marks an English text translated where it is shown (tools/locale/extract.py)
local L = FLT.L or setmetatable({}, { __index = function(_, k) return k end }) -- (tests without Locales)
local unpack = unpack or table.unpack
-- names from our data in the client's language (6.2.0 step 2b, Locales/Locale.lua; plain in tests without Locales)
local function NM(s) return FLT.Name and FLT.Name(s) or s end
local function PT(s) return FLT.PlaceText and FLT.PlaceText(s) or s end
local function DN(s) return FLT.DungeonName and FLT.DungeonName(s) or s end
local function _place() return N"inside %s" end -- shown by FLT.PlaceText (Locales/Locale.lua)
local UI = FLT.UI
local makeTexture, makeButton = UI.makeTexture, UI.makeButton
local LAYOUT = UI.LAYOUT
local ASSET_ROOT = UI.ASSET_ROOT
local H = UI.DungeonHelpers
local QUEST_STATUS_LABELS = H.QUEST_STATUS_LABELS
local getDungeonQuestStatus = H.getDungeonQuestStatus
local getQuestLogInfo = H.getQuestLogInfo
local questLogButton = H.questLogButton
local getChainProgress = H.getChainProgress
local getUnavailableReason = H.getUnavailableReason
-- a place text without its "(x, y)": coordinates are shown only next to a Map button (6.2.6, user 11.11.)
local function noCoords(s) return type(s) == "string" and (s:gsub("%s*%(%-?[%d%.]+, %-?[%d%.]+%)", "")) or s end
-- why a dungeon quest is unavailable, as text (nil = no known reason)
local function unavailableText(q)
  local kind, a, b = getUnavailableReason(q)
  if kind == "side" then return string.format(L["%s only"], L[a]) end
  if kind == "class" then
    return string.format(L["%s only"], (type(LOCALIZED_CLASS_NAMES_MALE) == "table" and LOCALIZED_CLASS_NAMES_MALE[a]) or (a:sub(1,1)..a:sub(2):lower()))
  end
  if kind == "race" then return string.format(L["%s only"], a) end
  if kind == "level" then return string.format(L["Requires level %d (you are level %d)"], a, b) end
  if kind == "step" then
    local t = string.format(L["First: %s"], NM(a.name) or (L["Quest"].." "..tostring(a.id)))
    local detail = a.id and FLT.QUEST_PREREQ_DETAILS and FLT.QUEST_PREREQ_DETAILS[a.id]
    if detail and detail.pickup then t = t.."\n"..string.format(L["Start: %s"], PT(noCoords(detail.pickup))) end
    return t
  end
end
local dungeonSideColor = H.dungeonSideColor
local normalizeDungeonItem = H.normalizeDungeonItem
local colorDungeonItemText = H.colorDungeonItemText
local tryShowItemTooltip = H.tryShowItemTooltip
local handleDungeonItemClick = H.handleDungeonItemClick
local dungeonItemIcon = H.dungeonItemIcon
local setBossPortrait = UI.setBossPortrait

-- own pictures (thumbnail, "_bg", "_hdr") for a dungeon without an entry in Data/DungeonLoadscreens.lua - none since
-- 6.2.10-beta17 (all dungeons and raids use the loading screens or our ls_*.tga there); kept for a new dungeon
local DUNGEON_ART = {
}

-- Collapsible level brackets for the browse list (grouped by minimum level).
local BRACKETS = {
  { id="10", label=N"Levels 10 - 19", min=0,  max=19 },
  { id="20", label=N"Levels 20 - 29", min=20, max=29 },
  { id="30", label=N"Levels 30 - 39", min=30, max=39 },
  { id="40", label=N"Levels 40 - 49", min=40, max=49 },
  { id="50", label=N"Levels 50 - 60", min=50, max=99 },
}

UI.DUNGEON_BRACKETS = BRACKETS
-- Raids view: one band per raid size (green / blue / purple like item quality)
local RAID_BRACKETS = {
  { id="r10", label=N"10 Players", size=10, color={0.30,0.95,0.40} },
  { id="r20", label=N"20 Players", size=20, color={0.30,0.62,1.00} },
  { id="r40", label=N"40 Players", size=40, color={0.76,0.42,1.00} },
}
local function raidColor(size)
  for _,br in ipairs(RAID_BRACKETS) do if br.size==size then return unpack(br.color) end end
  return 0.85,0.82,0.74
end

local function playerLevel()
  return (UnitLevel and tonumber(UnitLevel("player"))) or 1
end

-- green = fits your level, yellow = slightly below, orange/red = too low,
-- grey = outleveled.
local function levelColor(d)
  local pl=playerLevel()
  local lo=d.minLevel or 0
  local hi=d.maxLevel or lo
  if pl>hi then return 0.55,0.55,0.55 end
  if pl>=lo then return 0.25,1.00,0.35 end
  if pl>=lo-3 then return 1.00,0.82,0.10 end
  if pl>=lo-6 then return 1.00,0.50,0.15 end
  return 1.00,0.20,0.20
end

local function fitsPlayer(d)
  local pl=playerLevel()
  local lo=d.minLevel or 0
  local hi=d.maxLevel or lo
  return pl>=lo-3 and pl<=hi+2
end


local function dungeonArt(key) return DUNGEON_ART[key] end

-- Dungeon keys (Data\DungeonKeys.lua): do we carry the key item?
local function hasKeyItem(itemID)
  if not itemID then return false end
  local count
  if GetItemCount then
    local ok, n = pcall(GetItemCount, itemID, true)
    if ok then count = n end
  end
  if (not count or count == 0) and C_Item and C_Item.GetItemCount then
    local ok, n = pcall(C_Item.GetItemCount, itemID, true)
    if ok then count = n end
  end
  return (count or 0) > 0
end
local function dungeonKeys(d) return d and FLT.DUNGEON_KEYS and FLT.DUNGEON_KEYS[d.name] end
-- Status of the keys needed to enter: nil = none needed, true = all carried.
local function requiredKeyStatus(d)
  local keys = dungeonKeys(d); if not keys then return nil end
  local any, all = false, true
  for _, k in ipairs(keys) do
    if k.required then any = true; if not hasKeyItem(k.item) then all = false end end
  end
  if not any then return nil end
  return all
end
local KEY_ICON_YES = "Interface\\RaidFrame\\ReadyCheck-Ready"
local KEY_ICON_NO = "Interface\\RaidFrame\\ReadyCheck-NotReady"

-- Accent colour per dungeon art (computed from the thumbnail: its bright,
-- saturated pixels) - used for small details on the detail page.
local ART_ACCENT = {
}
local function dungeonAccent(key)
  -- ls6: the main colour of the loading screen picture (Data/DungeonLoadscreens.lua, entries 10-12)
  local e=FLT.DUNGEON_LOADSCREENS and FLT.DUNGEON_LOADSCREENS[key]
  if e and e[12] then return e[10],e[11],e[12] end
  local path=DUNGEON_ART[key]
  local base=path and path:match("([%w_]+)$")
  local c=base and ART_ACCENT[base]
  if c then return c[1],c[2],c[3] end
  return 0.85,0.65,0.28
end
-- blurred backdrops made from the thumbnails: "_bg" fades out downwards,
-- "_band" fades in from the left
local function dungeonBackdrop(key,kind)
  local path=DUNGEON_ART[key]
  return path and (path.."_"..kind) or nil
end
-- Loading screen test (user 16.11.2026, test version only): the dungeon pictures come from the game's own loading
-- screens (Data/DungeonLoadscreens.lua, FileDataID + the picture inside the file); w / h = the place it fills,
-- focus = where the cut sits vertically (0 top .. 1 bottom). Dungeons without a loading screen keep their own art.
-- e[7], e[8], e[9]: focus x / y and zoom of the entry (wings of one instance show different parts of one picture)
local function loadscreenCrop(key,aspect,focus)
  local e=FLT.DUNGEON_LOADSCREENS and FLT.DUNGEON_LOADSCREENS[key]
  if not e then return nil end
  local fid,u0,u1,v0,v1,a=e[1],e[2],e[3],e[4],e[5],e[6]
  local fx,fy,z=e[7] or 0.5,focus or e[8] or 0.5,e[9] or 1
  if z<1 then -- the used part: z of the width and height, around the focus, inside the picture
    local w,h=(u1-u0)*z,(v1-v0)*z
    local cu=math.max(u0+w/2,math.min(u1-w/2,u0+(u1-u0)*fx))
    local cv=math.max(v0+h/2,math.min(v1-h/2,v0+(v1-v0)*fy))
    u0,u1,v0,v1,fx,fy=cu-w/2,cu+w/2,cv-h/2,cv+h/2,0.5,0.5
  end
  if aspect>=a then
    local dv=(v1-v0)*a/aspect
    local t=math.max(v0,math.min(v1-dv,v0+(v1-v0)*fy-dv/2))
    return fid,u0,u1,t,t+dv
  end
  local du=(u1-u0)*aspect/a
  local c=math.max(u0+du/2,math.min(u1-du/2,u0+(u1-u0)*fx))
  return fid,c-du/2,c+du/2,v0,v1
end
local function setLoadscreen(tex,key,w,h,focus)
  local fid,l,r,t,b=loadscreenCrop(key,w/h,focus)
  if not fid then return false end
  tex:SetTexture(fid); tex:SetTexCoord(l,r,t,b)
  return true
end
-- a fade made with the texture's own alpha (no extra picture); false when the client cannot do it
local function alphaFade(tex,orient,a1,a2)
  if tex.SetGradient and CreateColor and pcall(tex.SetGradient,tex,orient,CreateColor(1,1,1,a1),CreateColor(1,1,1,a2)) then return true end
  if tex.SetGradientAlpha then tex:SetGradientAlpha(orient,1,1,1,a1,1,1,1,a2); return true end
  return false
end
UI.SetDungeonPicture,UI.AlphaFade=setLoadscreen,alphaFade -- also for the dungeon tracker's background (6.2.14)


local function createDungeonPanel(parent)
  local panel=CreateFrame("Frame",nil,parent)
  UI.PlacePanel(panel,parent)

  local browse=CreateFrame("Frame",nil,panel); browse:SetAllPoints()
  local detail=CreateFrame("Frame",nil,panel); detail:SetAllPoints(); detail:Hide()
  local browseBanner=nil -- the banner art lives in the title band now
  local detailBanner=nil -- no banner on the detail page (the header has its own picture)

  local Card, OrnateFrame = UI.Card, UI.OrnateFrame
  -- everything ends exactly below the banner's right edge
  -- ht8 (user 30.10.): the list sits right of a side list like every tab: 174 narrower, starting at 182
  local FULL_W=UI.CONTENT_W
  local ROW_W=UI.CONTENT_W-174
  local GOLD={1,0.82,0.20}
  local HEAD_GOLD={0.90,0.74,0.42}

  -- "Small caps": first letter of every word larger, the rest in capitals.
  local function smallCaps(parent,text,big,small,color,template) return UI.SmallCaps(parent,text,big,small,color,template) end

  -- Ornate gold frame around the banner.
  if browseBanner then OrnateFrame(browseBanner, browseBanner, 12, 3, "OVERLAY", 2) end

  -- Title band, split in two: Dungeons (left) | Raids (right). The open half is
  -- bright with a gold frame, the other one is dimmed.
  -- The banner art fades out to the left behind the emblem and the title.
  local band=CreateFrame("Frame",nil,browse); band:SetPoint("TOPLEFT",8,-8); band:SetSize(ROW_W,58); band:Hide() -- ht8: the side list switches
  local bandBg=makeTexture(band,"BACKGROUND",0.045,0.045,0.058,0.96); bandBg:SetPoint("TOPLEFT",2,-2); bandBg:SetPoint("BOTTOMRIGHT",-2,2)
  local bandHalves={}
  local function makeHalf(kind,x,w,art,emblemTex,emblemSize,title,sub)
    local h=CreateFrame("Button",nil,band); h:SetPoint("TOPLEFT",x,0); h:SetSize(w,58)
    local a=h:CreateTexture(nil,"BORDER",nil,0); a:SetPoint("TOPLEFT",2,-2); a:SetPoint("BOTTOMRIGHT",-2,2)
    FLT.SetTex(a, ASSET_ROOT..art); a:SetTexCoord(0,1,0.0625,0.9375)
    local sh=UI.UnmarkBG(makeTexture(h,"BORDER",0.045,0.045,0.058,0.88)); sh:SetDrawLayer("BORDER",1); sh:SetPoint("TOPLEFT",2,-2); sh:SetPoint("BOTTOMLEFT",2,2); sh:SetWidth(120)
    local fade=h:CreateTexture(nil,"BORDER",nil,1); FLT.SetTex(fade, ASSET_ROOT.."shade_lr"); fade:SetVertexColor(FLT.SkinC(0.18,0.18,0.23))
    fade:SetPoint("TOPLEFT",sh,"TOPRIGHT"); fade:SetPoint("BOTTOMLEFT",sh,"BOTTOMRIGHT"); fade:SetWidth(240)
    local dim=h:CreateTexture(nil,"ARTWORK",nil,0); dim:SetPoint("TOPLEFT",2,-2); dim:SetPoint("BOTTOMRIGHT",-2,2); dim:SetColorTexture(0,0,0,0.62)
    local em=h:CreateTexture(nil,"ARTWORK",nil,2); em:SetSize(emblemSize,emblemSize); em:SetPoint("CENTER",h,"LEFT",33,0)
    FLT.SetTex(em, ASSET_ROOT..emblemTex)
    local tt=smallCaps(h,L[title],19,15,GOLD,"GameFontNormalLarge"); tt:SetPoint("TOPLEFT",66,-9)
    local st=FLT.NewFS(h, nil,"OVERLAY","GameFontHighlightSmall"); st:SetPoint("TOPLEFT",67,-34); st:SetText(L[sub]); st:SetTextColor(FLT.TextC(0.80,0.77,0.70))
    local frameTex=OrnateFrame(h, h, 15, 2, "OVERLAY", 1) or {}
    local hi=makeTexture(h,"HIGHLIGHT",0.90,0.66,0.22,0.08); hi:SetPoint("TOPLEFT",2,-2); hi:SetPoint("BOTTOMRIGHT",-2,2)
    local half={button=h}
    function half:SetOpen(on)
      dim:SetShown(not on)
      for _,ft in ipairs(frameTex) do ft:SetAlpha(on and 1 or 0.25) end
      em:SetAlpha(on and 1 or 0.55); a:SetAlpha(on and 1 or 0.7)
      if on then tt:SetAlpha(1); st:SetAlpha(1) else tt:SetAlpha(0.55); st:SetAlpha(0.45) end
      if on then h:UnlockHighlight() end
    end
    h:SetScript("OnClick",function() if browse._setView then browse._setView(kind) end end)
    bandHalves[kind]=half
    return half
  end
  local HALF_W=math.floor(ROW_W/2)
  makeHalf("dungeons",0,HALF_W,"dungeons_split","emblem_dungeons",46,N"Dungeons",N"Bosses, loot, quests and keys of every dungeon.")
  makeHalf("raids",HALF_W,ROW_W-HALF_W,"raids_split","emblem_raids",54,N"Raids",N"Raids for 10, 20 and 40 players with attunements.")

  local fallbackSettings={}
  local function dungeonSettings()
    local db=OneForAllDB
    if type(db)~="table" then db=fallbackSettings end
    db.dungeonBrowse = db.dungeonBrowse or {}
    local cfg=db.dungeonBrowse
    cfg.collapsed = cfg.collapsed or {}
    return cfg
  end

  -- "Only my level" filter: the option lives in the Settings (Dungeon list);
  -- a hidden dummy keeps the old calls working.
  local fitCheck={SetChecked=function() end,SetScript=function() end}

  -- Column positions inside a row (rows sit BOX_PAD px inside their box).
  local SECTION_H, ROW_H, ROW_GAP, BOX_PAD = 32, 46, 0, 0
  local THUMB_W, THUMB_FADE, THUMB_FADE_L = 110, 34, 18 -- loading screen thumbnail: width, fading part right / left (ls4)
  local ROW_INNER = ROW_W - 2*BOX_PAD
  -- ht8: narrower columns, the faction crest right next to the level
  -- beta43 (user 07.11.: "Territory" ran into "Level" in English): level narrower, its head right-aligned into the free
  -- space of the name column; the territory column wider (crest a little to the left), zone unchanged
  local COL={ name=112, level=300, side=344, zone=420, key=572, quests=628, actions=712 }
  local COL_W={ name=180, level=44, side=76, zone=150, key=56, quests=76, actions=100 }

  -- Table header: small caps, separators, sort arrows (click to sort).
  local function plainHead(h) -- ht8: the column names on the page with a fine line under them
    local ln=h:CreateTexture(nil,"ARTWORK"); ln:SetColorTexture(0.50,0.38,0.19,0.6); ln:SetHeight(1)
    ln:SetPoint("BOTTOMLEFT",2,0); ln:SetPoint("BOTTOMRIGHT",-2,0)
  end
  local header=CreateFrame("Frame",nil,browse); header:SetPoint("TOPLEFT",182,-60); header:SetSize(ROW_W,24)
  plainHead(header)
  local sortButtons={}
  local SORT_TC={ none={0,0.25}, asc={0.25,0.5}, desc={0.5,0.75} }
  local function headerCol(text,x,w,justify,sortKey)
    x=x+BOX_PAD
    local b=CreateFrame("Button",nil,header); b:SetPoint("LEFT",x,0); b:SetSize(w,22)
    local arrowW=sortKey and 16 or 0
    local label=smallCaps(b,L[text],12,9,HEAD_GOLD)
    -- a longer name (French / Spanish, beta42): smaller letters before it runs into the next column (not for a
    -- right-aligned head: it has the free space on its left; English always fits at full size, beta43)
    local room=(justify=="RIGHT") and 999 or w-4
    if label:GetWidth()+arrowW>room then label:Hide(); label=smallCaps(b,L[text],11,8,HEAD_GOLD) end
    if label:GetWidth()+arrowW>room then label:Hide(); label=smallCaps(b,L[text],10,7,HEAD_GOLD) end
    if x>BOX_PAD+20 then
      local sep=makeTexture(header,"ARTWORK",0.72,0.50,0.12,0.25); sep:SetPoint("LEFT",x-2,0); sep:SetSize(1,12)
    end
    if justify=="RIGHT" then
      label:SetPoint("RIGHT",b,"RIGHT",-4-arrowW,0)
    elseif justify=="CENTER" then
      if label:GetWidth()+arrowW>w-4 then -- a longer (German) name: right-aligned, it reaches into the free space on the left
        label:SetPoint("RIGHT",b,"RIGHT",-2-arrowW,0)
      else
        label:SetPoint("LEFT",b,"CENTER",-math.floor((label:GetWidth()+arrowW)/2),0)
      end
    else
      label:SetPoint("LEFT",10,0)
    end
    if sortKey then
      local arrow=b:CreateTexture(nil,"OVERLAY"); arrow:SetSize(12,12); arrow:SetPoint("LEFT",label,"RIGHT",3,0)
      FLT.SetTex(arrow, ASSET_ROOT.."sort_arrows"); arrow:SetTexCoord(0,0.25,0,1)
      local hi=makeTexture(b,"HIGHLIGHT",0.85,0.62,0.20,0.10); hi:SetAllPoints()
      b.arrow=arrow; b.key=sortKey
      sortButtons[#sortButtons+1]=b
      b:SetScript("OnClick",function()
        local cfg=dungeonSettings()
        local s=cfg.sort
        -- ascending -> descending -> default order
        if not s or s.key~=sortKey then cfg.sort={key=sortKey}
        elseif not s.desc then s.desc=true
        else cfg.sort=nil end
        if browse._relayout then browse._relayout() end
      end)
      b:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_TOP"); GameTooltip:AddLine(string.format(L["Sort by %s"],L[text]),1,0.82,0)
        GameTooltip:AddLine(L["Click again to reverse, a third time for the default order."],1,1,1,true); GameTooltip:Show()
      end)
      b:SetScript("OnLeave",function() GameTooltip:Hide() end)
    end
    return b
  end
  headerCol(N"Dungeon",14,COL.level-14,"LEFT","name")
  headerCol(N"Level",COL.level,COL_W.level,"RIGHT","level")
  headerCol(N"Territory",COL.side,COL_W.side,"CENTER","side")
  headerCol(N"Zone",COL.zone,COL_W.zone,"LEFT","zone")
  headerCol(N"Key",COL.key,COL_W.key,"CENTER")
  headerCol(N"Quests",COL.quests,COL_W.quests,"CENTER","quests")
  headerCol(N"Actions",COL.actions,COL_W.actions,"CENTER")
  -- Raids view: own header (Size instead of Territory, Attunement instead of Key)
  local dungeonHeader=header
  header=CreateFrame("Frame",nil,browse); header:SetPoint("TOPLEFT",182,-60); header:SetSize(ROW_W,24); header:Hide()
  plainHead(header)
  headerCol(N"Raid",14,COL.level-14,"LEFT","name")
  headerCol(N"Level",COL.level,COL_W.level,"RIGHT","level")
  headerCol(N"Size",COL.side,COL_W.side,"CENTER","size")
  headerCol(N"Zone",COL.zone,COL_W.zone,"LEFT","zone")
  headerCol(N"Attunement",COL.key-8,COL_W.key+16,"CENTER")
  headerCol(N"Quests",COL.quests,COL_W.quests,"CENTER","quests")
  headerCol(N"Actions",COL.actions,COL_W.actions,"CENTER")
  local raidHeader=header
  header=dungeonHeader

  -- head like Quality of Life (user 31.10.): icon, Dungeons / Raids, one line, search (name, short name, zone, bosses)
  local searchText=""
  local VIEW_HEAD={
    dungeons={"Interface\\Icons\\INV_Misc_Bone_HumanSkull_01",N"Dungeons",N"Bosses, loot, quests and keys of every dungeon. Click one to open it."},
    raids={"Interface\\Icons\\INV_Misc_Head_Dragon_01",N"Raids",N"Raids for 10, 20 and 40 players with bosses, loot and attunements."},
  }
  local pageHead=UI.PageHeader(browse,{x=182,y=0,right=54,placeholder=L["Search name, zone or boss..."],
    onSearch=function(t) searchText=t; if browse._relayout then browse._relayout(true) end end})

  local sf=FLT.SkinBlizz(CreateFrame("ScrollFrame",nil,browse,"UIPanelScrollFrameTemplate"))
  sf:SetPoint("TOPLEFT",182,-90); sf:SetPoint("BOTTOMRIGHT",-8,4); UI.PlaceScrollBar(sf)
  local child=CreateFrame("Frame",nil,sf); child:SetSize(ROW_W,1); sf:SetScrollChild(child)

  local selectedDungeon=nil
  local mode="bosses"
  local renderKey
  local bossSelection={}
  local recipeSectionOpen={} -- "dungeonKey:bossIndex" -> false when collapsed
  local questSelection={}
  local questFactionFilter={}

  local function questProgressForPlayer(d)
    local counts = { completed=0, inlog=0, chain=0, ready=0, available=0, unavailable=0 }
    for _,q in ipairs(d.quests or {}) do
      local status = getDungeonQuestStatus(d, q)
      counts[status] = (counts[status] or 0) + 1
    end
    local relevant = counts.completed + counts.inlog + counts.chain + counts.ready + counts.available
    return counts.completed, relevant, counts
  end

  -- Level brackets: an ornate band with a landscape silhouette, then a framed
  -- box that holds the dungeon rows.
  local sections={}
  local function createSection(bracket, bi)
    local holder=CreateFrame("Button",nil,child); holder:SetSize(ROW_W,SECTION_H)
    local chevron,info
    do -- ht8: a quiet head instead of the landscape band; the rows without a box
      local title
      chevron,title,info=UI.QuietHead(holder,L[bracket.label])
      if bracket.color then title:SetTextColor(unpack(bracket.color)) end
    end
    if false then
    local base=makeTexture(holder,"BACKGROUND",0.05,0.05,0.065,0.98); base:SetPoint("TOPLEFT",2,-2); base:SetPoint("BOTTOMRIGHT",-2,2)
    local sil=holder:CreateTexture(nil,"BORDER"); sil:SetPoint("TOPLEFT",2,-2); sil:SetPoint("BOTTOMRIGHT",-2,2)
    local strip=(bi-1)%3
    FLT.SetTex(sil, ASSET_ROOT.."band_silhouettes"); sil:SetTexCoord(0,1,strip*0.25,strip*0.25+0.25); sil:SetAlpha(0.85)
    -- framed chevron box on the left
    local cbox=CreateFrame("Frame",nil,holder); cbox:SetSize(22,22); cbox:SetPoint("LEFT",12,0)
    Card(cbox,cbox,4,{0.80,0.60,0.24,0.95},{0.06,0.05,0.04,0.95},"BACKGROUND",0)
    chevron=cbox:CreateTexture(nil,"OVERLAY"); chevron:SetSize(15,15); chevron:SetPoint("CENTER",0,0)
    FLT.SetTex(chevron, ASSET_ROOT.."chevron")
    local title=FLT.NewFS(holder, nil,"OVERLAY","GameFontNormalLarge"); title:SetPoint("LEFT",46,0); title:SetText(L[bracket.label]); title:SetTextColor(FLT.TextC(unpack(GOLD)))
    if bracket.color then title:SetTextColor(unpack(bracket.color)) end
    do local font,_,flags=title:GetFont(); if font then title:SetFont(font,14,flags) end end
    info=FLT.NewFS(holder, nil,"OVERLAY","GameFontHighlightSmall"); info:SetPoint("RIGHT",-20,0); info:SetJustifyH("RIGHT"); info:SetTextColor(FLT.TextC(0.85,0.82,0.74))
    OrnateFrame(holder, holder, 13, 2, "OVERLAY", 1)
    local hhi=makeTexture(holder,"HIGHLIGHT",0.80,0.58,0.18,0.10); hhi:SetPoint("TOPLEFT",2,-2); hhi:SetPoint("BOTTOMRIGHT",-2,2)
    end

    local rowsBox=CreateFrame("Frame",nil,child); rowsBox:SetWidth(ROW_W)

    local section={bracket=bracket,header=holder,box=rowsBox,chevron=chevron,info=info,rows={}}
    holder:SetScript("OnClick",function()
      local cfg=dungeonSettings()
      cfg.collapsed[bracket.id]=not cfg.collapsed[bracket.id] or nil
      if browse._relayout then browse._relayout() end
    end)
    holder:SetScript("OnEnter",function(self)
      GameTooltip:SetOwner(self,"ANCHOR_CURSOR")
      GameTooltip:SetText(L[dungeonSettings().collapsed[bracket.id] and N"Expand" or N"Collapse"])
      GameTooltip:Show()
    end)
    holder:SetScript("OnLeave",function() GameTooltip:Hide() end)
    return section
  end
  local raidSections={}
  local function sectionFor(d)
    if d.raid then
      for bi,br in ipairs(RAID_BRACKETS) do
        if br.size==d.size then
          raidSections[bi]=raidSections[bi] or createSection(br, bi+1)
          return raidSections[bi]
        end
      end
      return nil
    end
    local lvl=d.minLevel or 0
    for bi,br in ipairs(BRACKETS) do
      if lvl>=br.min and lvl<=br.max then
        sections[bi]=sections[bi] or createSection(br, bi)
        return sections[bi]
      end
    end
  end

  -- faction crests (Assets\faction_crests: Alliance | Horde | Contested)
  -- faction / side words from the data, shown with L[...] (extract.py counts them here)
  local function _sides() return N"Alliance", N"Horde", N"Contested", N"Both", N"Neutral" end
  local CREST_TC={ Alliance={0,0.25}, Horde={0.25,0.5}, Contested={0.5,0.75} }
  local SIDE_INFO={
    Alliance=N"Alliance territory",
    Horde=N"Horde territory",
    Contested=N"Contested territory - open to both factions",
  }

  local ROW_BORDER={0.28,0.25,0.20,0.90}
  local ROW_BORDER_HI={0.86,0.66,0.26,1}

  local browseRows={}
  local browseOrder={}
  for di,d in ipairs(FLT.DUNGEONS or {}) do
    local dungeon=d
    local partial=d.dataStatus=="partial"
    local row=CreateFrame("Button",nil,child)
    row:SetSize(ROW_INNER,ROW_H)
    local card=UI.QuietRow(row) -- ht8: no frame, a fine line under the row

    -- thumbnail with rounded corners and a thin gold frame
    local art=row:CreateTexture(nil,"ARTWORK")
    local artPath=dungeonArt(d.key)
    local lsKey=FLT.DUNGEON_LOADSCREENS and FLT.DUNGEON_LOADSCREENS[d.key] and d.key
    -- loading screen (user 16.11.: "Rand aussen weg ... ganze Hoehe der Zeile"): the row's full height, no frame
    -- ls3 (user 16.11.: "einen kleinen Uebergang vom Bild" to the name): the last THUMB_FADE px are a second texture
    -- with the rest of the picture that fades out (its own alpha, so it works with the window opacity)
    local artFade,artFadeL
    if lsKey then
      -- ls4 (user 16.11.: "links am Bild auch noch einen Fade"): a third texture with the left edge, fading in
      artFadeL=row:CreateTexture(nil,"ARTWORK"); artFadeL:SetPoint("TOPLEFT",0,0); artFadeL:SetPoint("BOTTOMLEFT",0,1); artFadeL:SetWidth(THUMB_FADE_L)
      art:SetPoint("TOPLEFT",artFadeL,"TOPRIGHT"); art:SetPoint("BOTTOMLEFT",artFadeL,"BOTTOMRIGHT"); art:SetWidth(THUMB_W-THUMB_FADE-THUMB_FADE_L)
      artFade=row:CreateTexture(nil,"ARTWORK"); artFade:SetPoint("TOPLEFT",art,"TOPRIGHT"); artFade:SetPoint("BOTTOMLEFT",art,"BOTTOMRIGHT"); artFade:SetWidth(THUMB_FADE)
    else art:SetSize(96,36); art:SetPoint("LEFT",4,0) end
    -- loading screen: set only while the row is in view (each file is a few MB of video memory; loadVisibleArt)
    if lsKey then art:SetColorTexture(FLT.SkinC(0.10,0.08,0.05,1))
    elseif artPath then FLT.SetTex(art, artPath); art:SetTexCoord(0,1,0.1,0.9)
    else art:SetColorTexture(FLT.SkinC(0.10,0.08,0.05,1)) end
    if not lsKey and art.AddMaskTexture and row.CreateMaskTexture then
      local m=row:CreateMaskTexture()
      FLT.SetTex(m, ASSET_ROOT.."thumb_wide_mask","CLAMPTOBLACKADDITIVE","CLAMPTOBLACKADDITIVE"); m:SetAllPoints(art)
      art:AddMaskTexture(m)
    end
    -- ht9 (user 30.10.): the thinnest frame - a 1 px line round the picture
    if not lsKey then
      local afh=CreateFrame("Frame",nil,row); afh:SetPoint("TOPLEFT",art,"TOPLEFT",-1,1); afh:SetPoint("BOTTOMRIGHT",art,"BOTTOMRIGHT",1,-1)
      UI.RoundRect(row,afh,"OVERLAY",0,8,0,0.62,0.48,0.26,0.9,ASSET_ROOT.."window_ring")
    end

    local nm=FLT.NewFS(row, nil,"OVERLAY","GameFontNormal"); nm:SetPoint("LEFT",COL.name,0); nm:SetJustifyH("LEFT"); nm:SetWidth(COL_W.name+4); nm:SetWordWrap(false); nm:SetText(DN(d.name) ~= d.name and DN(d.name) or (d.short or d.name)); nm:SetTextColor(FLT.TextC(unpack(GOLD)))
    do local font,_,flags=nm:GetFont(); if font then nm:SetFont(font,14,flags) end end
    if nm.SetWordWrap then nm:SetWordWrap(false) end
    local nameW=nm:GetStringWidth() or 150
    local maxName=COL.level-COL.name-(d.betaNew and 44 or 6)-(partial and 20 or 0)
    if nameW>maxName then nm:SetWidth(maxName); nameW=maxName end
    local afterName=COL.name+nameW+8
    if partial then
      -- Incomplete data: small warning icon with a tooltip.
      local warn=CreateFrame("Frame",nil,row); warn:SetSize(16,16); warn:SetPoint("LEFT",afterName,0)
      local wt=warn:CreateTexture(nil,"OVERLAY"); wt:SetAllPoints(); FLT.SetTex(wt, "Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew")
      warn:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:AddLine(L["Partial data"],1,0.62,0.25)
        GameTooltip:AddLine(L[d.raid and N"Not open yet - bosses only, loot and quests are not known yet." or N"Bosses only - loot and quests are not recorded yet."],1,1,1,true); GameTooltip:Show()
      end)
      warn:SetScript("OnLeave",function() GameTooltip:Hide() end)
      afterName=afterName+20
    end
    if d.betaNew then
      local tag=FLT.NewFS(row, nil,"OVERLAY","GameFontDisableSmall"); tag:SetPoint("LEFT",afterName,0); tag:SetText(L["NEW"]); tag:SetTextColor(FLT.TextC(0.40,0.95,0.50))
    end

    local lv=FLT.NewFS(row, nil,"OVERLAY","GameFontHighlight"); lv:SetPoint("LEFT",COL.level,0); lv:SetWidth(COL_W.level); lv:SetJustifyH("CENTER"); lv:SetText(d.level)
    do local font,_,flags=lv:GetFont(); if font then lv:SetFont(font,12,flags) end end

    -- faction crest only (the name is in the tooltip)
    local sideName=d.territory or d.side or "Contested"
    local crestF=CreateFrame("Frame",nil,row); crestF:SetSize(28,28); crestF:SetPoint("CENTER",row,"LEFT",COL.side+COL_W.side/2,0)
    if d.raid then
      -- raids: group size in the colour of its band instead of the faction crest
      local sz=FLT.NewFS(crestF, nil,"OVERLAY","GameFontNormalLarge"); sz:SetPoint("CENTER"); sz:SetText(tostring(d.size or "?"))
      sz:SetTextColor(raidColor(d.size))
      crestF:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:AddLine(string.format(L["Raid for %s players"],tostring(d.size or "?")),raidColor(d.size))
        if d.raidStatus then GameTooltip:AddLine(d.raidStatus,1,1,1,true) end
        GameTooltip:Show()
      end)
    else
      local crest=crestF:CreateTexture(nil,"ARTWORK"); crest:SetAllPoints()
      local tc=CREST_TC[sideName] or CREST_TC.Contested
      FLT.SetTex(crest, ASSET_ROOT.."faction_crests"); crest:SetTexCoord(tc[1],tc[2],0,1)
      crestF:SetScript("OnEnter",function(self)
        local r,g,b=dungeonSideColor(sideName)
        GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:AddLine(L[sideName],r,g,b)
        GameTooltip:AddLine(SIDE_INFO[sideName] and L[SIDE_INFO[sideName]] or "",1,1,1,true); GameTooltip:Show()
      end)
    end
    crestF:SetScript("OnLeave",function() GameTooltip:Hide() end)

    -- Coordinates are left to the Map button; the column only names the zone.
    local zoneText=(FLT.ZoneName and FLT.ZoneName(d.mapZone or d.area) or d.mapZone or d.area or L["Unknown"])
    local ar=FLT.NewFS(row, nil,"OVERLAY","GameFontHighlight"); ar:SetPoint("LEFT",COL.zone+10,0); ar:SetWidth(COL_W.zone-14); ar:SetJustifyH("LEFT"); ar:SetText(zoneText); ar:SetTextColor(FLT.TextC(0.90,0.88,0.84))

    -- Key column: empty when the dungeon needs no key, otherwise a green
    -- check (key in your bags/keyring) or a red cross.
    local keyIcon=row:CreateTexture(nil,"OVERLAY"); keyIcon:SetSize(20,20); keyIcon:SetPoint("CENTER",row,"LEFT",COL.key+COL_W.key/2,0); keyIcon:Hide()
    local keyHover=CreateFrame("Frame",nil,row); keyHover:SetPoint("CENTER",keyIcon,"CENTER"); keyHover:SetSize(30,30)
    -- raids: "?" while the attunement is not known, "-" when none is needed
    local keyText
    if d.raid then
      keyText=FLT.NewFS(row, nil,"OVERLAY","GameFontHighlight"); keyText:SetPoint("CENTER",keyIcon,"CENTER")
      keyText:SetTextColor(0.70,0.68,0.62)
    end
    keyHover:SetScript("OnEnter",function(self)
      if d.raid and d.attunement=="unknown" then
        GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:SetText(L["Attunement"],1,0.82,0.20)
        GameTooltip:AddLine(L["Not known yet. It is filled in once Blizzard shows how you get in."],1,1,1,true); GameTooltip:Show(); return
      end
      local keys=dungeonKeys(d); if not keys or requiredKeyStatus(d)==nil then return end
      GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:SetText(L[d.raid and N"Attunement needed" or N"Key needed"],1,0.82,0.20)
      for _,k in ipairs(keys) do
        if k.required then
          local have=hasKeyItem(k.item)
          GameTooltip:AddDoubleLine(k.name,L[have and N"You have it" or N"Missing"],0.92,0.90,0.84,have and 0.3 or 1,have and 1 or 0.3,have and 0.4 or 0.3)
        end
      end
      GameTooltip:AddLine(L[d.raid and N"Open the raid and pick the Attunement tab for the steps." or N"Open the dungeon and pick the Key tab for the steps."],0.65,0.65,0.65,true)
      GameTooltip:Show()
    end)
    keyHover:SetScript("OnLeave",function() GameTooltip:Hide() end)

    local qc=FLT.NewFS(row, nil,"OVERLAY","GameFontHighlight"); qc:SetPoint("LEFT",COL.quests,0); qc:SetWidth(COL_W.quests); qc:SetJustifyH("CENTER"); qc:SetTextColor(FLT.TextC(0.95,0.93,0.88))
    local qhover=CreateFrame("Frame",nil,row); qhover:SetPoint("LEFT",COL.quests,0); qhover:SetSize(COL_W.quests,30)
    qhover:SetScript("OnEnter",function(self)
      GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
      GameTooltip:SetText(DN(d.name),1,0.82,0.20)
      if #(d.quests or {})==0 then
        local msg=d.raid and (partial and N"No quests have been recorded for this raid yet." or N"No raid quests recorded.")
          or (partial and N"No quests have been recorded for this dungeon yet." or N"No dungeon quests recorded.")
        GameTooltip:AddLine(L[msg],0.92,0.90,0.84,true)
      else
        local completedQuests,relevantQuests,questCounts=questProgressForPlayer(d)
        GameTooltip:AddLine(string.format(L["%d quests completed of %d currently relevant/available to your character."],completedQuests,relevantQuests),0.92,0.90,0.84,true)
        GameTooltip:AddLine(string.format(L["Completed: %d  |  In log: %d"],questCounts.completed,questCounts.inlog+(questCounts.ready or 0)),0.55,0.95,0.65,true)
        GameTooltip:AddLine(string.format(L["Available: %d  |  Unavailable: %d"],questCounts.available,questCounts.unavailable),0.80,0.80,0.76,true)
      end
      GameTooltip:Show()
    end)
    qhover:SetScript("OnLeave",function() GameTooltip:Hide() end)

    -- Map button (light gold plate with a map icon)
    local mapBtn=UI.GoldButton(row,L["Map"],74,22,ASSET_ROOT.."icon_map",12)
    mapBtn:SetPoint("CENTER",row,"LEFT",COL.actions+COL_W.actions/2,0)
    if d.mapZone and d.mapX and d.mapY then
      mapBtn:SetScript("OnClick",function() FLT:ShowOnMap({zone=d.mapZone,x=d.mapX,y=d.mapY,name=string.format(L["%s entrance"],DN(d.name))}) end)
      mapBtn:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
        GameTooltip:AddLine(L[d.raid and N"Raid entrance" or N"Dungeon entrance"],1,0.82,0)
        GameTooltip:AddLine((FLT.ZoneName and FLT.ZoneName(d.mapZone) or d.mapZone)..string.format(" (%.1f, %.1f)",d.mapX,d.mapY),1,1,1,true)
        if d.coordsUnverified then GameTooltip:AddLine(L["This entrance position has not been verified in game yet."],1,0.62,0.25,true) end
        GameTooltip:Show()
      end)
      mapBtn:SetScript("OnLeave",function() GameTooltip:Hide() end)
    else
      mapBtn:Disable(); mapBtn:SetLook(false)
    end

    row:SetScript("OnEnter",function() card:SetBorder(unpack(ROW_BORDER_HI)) end)
    row:SetScript("OnLeave",function() card:SetBorder(unpack(ROW_BORDER)) end)
    row:SetScript("OnClick",function()
      selectedDungeon=dungeon; mode="bosses"; browse:Hide(); detail:Show()
      bossSelection[dungeon.key]=bossSelection[dungeon.key] or 1
      questSelection[dungeon.key]=questSelection[dungeon.key] or 1
      if detail._render then detail._render() end
    end)
    local entry={dungeon=d,row=row,art=art,artFade=artFade,artFadeL=artFadeL,lsKey=lsKey,questText=qc,levelText=lv,keyIcon=keyIcon,keyText=keyText,order=di,openQuests=0,
      sortName=(d.short or d.name or ""):lower(),sortSide=sideName,sortZone=zoneText:lower()}
    do -- search text: names, zone and bosses (built once)
      local parts={d.name or "",DN(d.name or ""),d.short or "",zoneText,d.mapZone or ""}
      for _,b in ipairs(d.bosses or {}) do parts[#parts+1]=b.name or "" end
      entry.find=table.concat(parts," "):lower()
    end
    browseRows[#browseRows+1]=entry
    local sec=sectionFor(d)
    if sec then sec.rows[#sec.rows+1]=entry end
  end

  local emptyText=FLT.NewFS(child, nil,"OVERLAY","GameFontHighlight")
  emptyText:SetPoint("TOPLEFT",14,-14); emptyText:SetTextColor(FLT.TextC(0.78,0.75,0.68)); emptyText:Hide()

  local SORT_VALUE={
    name=function(e) return e.sortName end,
    level=function(e) return (e.dungeon.minLevel or 0)*100+(e.dungeon.maxLevel or e.dungeon.minLevel or 0) end,
    side=function(e) return e.sortSide end,
    zone=function(e) return e.sortZone end,
    quests=function(e) return e.openQuests end,
    size=function(e) return e.dungeon.size or 0 end,
  }
  local function sortEntries(list,s,highFirst)
    if not (s and SORT_VALUE[s.key]) then
      -- default order is by level; "Highest levels first" reverses it
      if highFirst then table.sort(list,function(a,b) return a.order>b.order end)
      else table.sort(list,function(a,b) return a.order<b.order end) end
      return
    end
    local val=SORT_VALUE[s.key]
    table.sort(list,function(a,b)
      local va,vb=val(a),val(b)
      if va==vb then return a.order<b.order end
      if s.desc then return va>vb end
      return va<vb
    end)
  end

  -- loading screen thumbnails only for the rows in view (+ one row above / below); all let go when the list closes
  local function loadVisibleArt()
    local top,bottom=sf:GetTop(),sf:GetBottom()
    if not top then return end
    for _,entry in ipairs(browseRows) do
      if entry.lsKey and not entry.artOn and entry.row:IsShown() then
        local rt,rb=entry.row:GetTop(),entry.row:GetBottom()
        if rt and rb and rb<top+ROW_H and rt>bottom-ROW_H then
          local fid,l,r,t,b=loadscreenCrop(entry.lsKey,THUMB_W/(ROW_H-1))
          if fid then
            local mid=l+(r-l)*(THUMB_W-THUMB_FADE)/THUMB_W
            local midL=l+(r-l)*THUMB_FADE_L/THUMB_W
            entry.artFadeL:SetTexture(fid); entry.artFadeL:SetTexCoord(l,midL,t,b)
            if not entry.artFadeL._ofaFade then entry.artFadeL._ofaFade=alphaFade(entry.artFadeL,"HORIZONTAL",0,1) end
            entry.artFadeL:Show()
            entry.art:SetTexture(fid); entry.art:SetTexCoord(midL,mid,t,b); entry.art:SetVertexColor(1,1,1,1)
            entry.artFade:SetTexture(fid); entry.artFade:SetTexCoord(mid,r,t,b)
            if not entry.artFade._ofaFade then entry.artFade._ofaFade=alphaFade(entry.artFade,"HORIZONTAL",1,0) end
            entry.artFade:Show(); entry.artOn=true
          end
        end
      end
    end
  end
  local artPending
  local function queueArt()
    if artPending then return end
    artPending=true
    C_Timer.After(0.05,function() artPending=nil; if browse:IsVisible() then loadVisibleArt() end end)
  end
  sf:HookScript("OnVerticalScroll",queueArt)
  browse:HookScript("OnHide",function()
    for _,entry in ipairs(browseRows) do
      if entry.artOn then
        entry.art:SetTexture(nil); entry.art:SetColorTexture(FLT.SkinC(0.10,0.08,0.05,1))
        entry.artFade:SetTexture(nil); entry.artFade:Hide(); entry.artFadeL:SetTexture(nil); entry.artFadeL:Hide(); entry.artOn=nil
      end
    end
  end)

  local function relayout(fromSearch)
    local cfg=dungeonSettings()
    local raids=cfg.view=="raids"
    local searching=searchText~=""
    if fromSearch then sf:SetVerticalScroll(0) end
    do local vh=VIEW_HEAD[raids and "raids" or "dungeons"]; pageHead:Set(vh[1],L[vh[2]],L[vh[3]]) end
    local onlyFit=cfg.onlyFit and true or false
    fitCheck:SetChecked(onlyFit)
    for kind,half in pairs(bandHalves) do half:SetOpen((kind=="raids")==raids) end
    dungeonHeader:SetShown(not raids); raidHeader:SetShown(raids)
    local s=cfg.sort
    for _,b in ipairs(sortButtons) do
      local state=(s and s.key==b.key) and (s.desc and "desc" or "asc") or "none"
      local tc=SORT_TC[state]; b.arrow:SetTexCoord(tc[1],tc[2],0,1)
    end
    -- the other view's bands and rows stay hidden
    local function hideAll(list)
      for _,sec in pairs(list) do
        sec.header:Hide(); sec.box:Hide()
        for _,entry in ipairs(sec.rows) do entry.row:Hide() end
      end
    end
    hideAll(raids and sections or raidSections)
    local y=-4
    local shownSections=0
    local highFirst=cfg.highFirst and true or false
    local brackets=raids and RAID_BRACKETS or BRACKETS
    local secs=raids and raidSections or sections
    wipe(browseOrder) -- the dungeons in the order the list shows them (< > on the detail page, 6.2.7-beta12)
    for step=1,#brackets do
      local bi=highFirst and (#brackets-step+1) or step
      local sec=secs[bi]
      if sec and not raids and not searching and cfg.hiddenBrackets and cfg.hiddenBrackets[sec.bracket.id] then
        sec.header:Hide(); sec.box:Hide()
        for _,entry in ipairs(sec.rows) do entry.row:Hide() end
        sec.y=nil; sec=nil
      end
      if sec then
        local visible={}
        for _,entry in ipairs(sec.rows) do
          if searching then
            if entry.find:find(searchText,1,true) then visible[#visible+1]=entry end -- search: every bracket, every level
          elseif raids or not onlyFit or fitsPlayer(entry.dungeon) then visible[#visible+1]=entry end
        end
        sortEntries(visible,s,highFirst)
        for _,entry in ipairs(visible) do browseOrder[#browseOrder+1]=entry.dungeon end
        for _,entry in ipairs(sec.rows) do entry.row:Hide() end
        if #visible==0 then
          sec.header:Hide(); sec.box:Hide(); sec.y=nil
        else
          shownSections=shownSections+1
          if shownSections>1 then y=y-10 end
          sec.header:ClearAllPoints(); sec.header:SetPoint("TOPLEFT",0,y); sec.header:Show(); sec.y=y; sec.count=#visible
          y=y-SECTION_H-3
          local collapsed=cfg.collapsed[sec.bracket.id] and not searching
          if collapsed then sec.chevron:SetTexCoord(0.5,1,0,1) else sec.chevron:SetTexCoord(0,0.5,0,1) end
          if raids then sec.info:SetText(#visible==1 and L["1 raid"] or string.format(L["%d raids"],#visible))
          else sec.info:SetText(#visible==1 and L["1 dungeon"] or string.format(L["%d dungeons"],#visible)) end
          if collapsed then
            sec.box:Hide()
          else
            local h=BOX_PAD*2+#visible*ROW_H+(#visible-1)*ROW_GAP
            sec.box:ClearAllPoints(); sec.box:SetPoint("TOPLEFT",0,y); sec.box:SetHeight(h); sec.box:Show()
            local ry=y-BOX_PAD
            for _,entry in ipairs(visible) do
              entry.row:ClearAllPoints(); entry.row:SetPoint("TOPLEFT",BOX_PAD,ry); entry.row:Show()
              ry=ry-ROW_H-ROW_GAP
            end
            y=y-h
          end
        end
      end
    end
    emptyText:SetText(searching and string.format(L["Nothing matches \"%s\"."],searchText) or L[raids and N"No raids to show." or N"No dungeons match your level. Untick \"Only dungeons for my level\" to see all."])
    emptyText:SetShown(shownSections==0)
    child:SetHeight(math.max(1,-y+10))
    if browse._paintNav then browse._paintNav() end
    if browse._histOn and browse._applyHistory then browse._applyHistory() end
    queueArt()
  end
  -- 6.2.14 (user 23.11.: "History" in the list left): the runs of this character (UI/RunHistory.lua) in place of the list
  local histPane
  local function applyHistory()
    local on=browse._histOn and true or false
    if on and not histPane and UI.CreateRunHistory then
      histPane=UI.CreateRunHistory(browse); histPane:SetPoint("TOPLEFT",182,0); histPane:SetPoint("BOTTOMRIGHT",-8,4)
    end
    if histPane then histPane:SetShown(on) end
    sf:SetShown(not on)
    for _,o in ipairs({pageHead.icon,pageHead.title,pageHead.sub,pageHead.box}) do o:SetShown(not on) end
    if on then dungeonHeader:Hide(); raidHeader:Hide() end
  end
  browse._applyHistory=applyHistory
  browse._showHistory=function()
    browse._histOn=true; applyHistory()
    if browse._paintNav then browse._paintNav() end
  end
  browse._setView=function(kind)
    local cfg=dungeonSettings()
    local v=(kind=="raids") and "raids" or nil
    if browse._histOn then browse._histOn=nil; applyHistory(); cfg.view=v; relayout(); return end
    if cfg.view==v then return end
    cfg.view=v
    if PlaySound and type(SOUNDKIT)=="table" and SOUNDKIT.IG_CHARACTER_INFO_TAB then pcall(PlaySound,SOUNDKIT.IG_CHARACTER_INFO_TAB) end
    sf:SetVerticalScroll(0)
    relayout()
  end
  browse._relayout=relayout

  -- ht8 (user 30.10.): the side list like every tab - Dungeons / Raids, then the level brackets to jump to
  do
    local nav,ny=UI.SideNav(browse,-8,"emblem_raids",L["Dungeons & Raids"]) -- ht10: the raids emblem (user 30.10.)
    local viewBtn={}
    -- ht9 (user 30.10.): client icons like in the other lists
    viewBtn.dungeons,ny=UI.NavEntry(nav,ny,L["Dungeons"],"Interface\\Icons\\INV_Misc_Bone_HumanSkull_01")
    viewBtn.raids,ny=UI.NavEntry(nav,ny,L["Raids"],"Interface\\Icons\\INV_Misc_Head_Dragon_01")
    for k,b in pairs(viewBtn) do b:SetScript("OnClick",function() browse._setView(k) end) end
    viewBtn.history,ny=UI.NavEntry(nav,ny,L["History"],"Interface\\Icons\\INV_Misc_Book_09")
    viewBtn.history:SetScript("OnClick",function() browse._showHistory() end)
    do local m=UI.NewMark(viewBtn.history,string.format(L["New in OneForAll %s."],"6.2.14")); m:SetPoint("RIGHT",-8,0) end -- TODO.md "Neu-Markierungen"
    ny=UI.NavSeparator(nav,ny)
    local jump={}
    for i=1,math.max(#BRACKETS,#RAID_BRACKETS) do
      local b; b,ny=UI.NavEntry(nav,ny,"")
      b.count=FLT.NewFS(b,nil,"OVERLAY","GameFontDisableSmall"); b.count:SetPoint("RIGHT",-5,0)
      do local font,_,flags=b.count:GetFont(); if font then b.count:SetFont(font,10,flags) end end
      b:SetScript("OnClick",function(self)
        local sec=self.sec; if not (sec and sec.y) then return end
        local range=sf:GetVerticalScrollRange() or 0
        sf:SetVerticalScroll(math.max(0,math.min(range,-sec.y-4)))
      end)
      jump[i]=b
    end
    browse._paintNav=function()
      local raids=dungeonSettings().view=="raids"
      local hist=browse._histOn and true or false
      viewBtn.dungeons:SetActive(not raids and not hist); viewBtn.raids:SetActive(raids and not hist); viewBtn.history:SetActive(hist)
      if hist then for i=1,#jump do jump[i]:Hide(); jump[i].sec=nil end; return end
      local brackets,secs=raids and RAID_BRACKETS or BRACKETS, raids and raidSections or sections
      local n=0
      for bi,br in ipairs(brackets) do
        local sec=secs[bi]
        if sec and sec.y then
          n=n+1; local b=jump[n]
          b._label:SetText(L[br.label]); b.count:SetText(tostring(sec.count or "")); b.sec=sec; b:Show()
        end
      end
      for i=n+1,#jump do jump[i]:Hide(); jump[i].sec=nil end
    end
  end
  UI.RefreshDungeonList=function() if browse:IsShown() then relayout() end end

  fitCheck:SetScript("OnClick",function(self)
    dungeonSettings().onlyFit=self:GetChecked() and true or nil
    relayout()
  end)

  local function refreshBrowse()
    for _,entry in ipairs(browseRows) do
      local d=entry.dungeon
      if #(d.quests or {})==0 then
        entry.questText:SetText("-"); entry.openQuests=-1
      else
        local completedQuests,relevantQuests=questProgressForPlayer(d)
        entry.questText:SetText(relevantQuests>0 and (completedQuests.." / "..relevantQuests) or "-")
        entry.openQuests=relevantQuests-completedQuests
      end
      entry.levelText:SetTextColor(FLT.TextC(levelColor(d)))
      local ks=requiredKeyStatus(d)
      if ks==nil then entry.keyIcon:Hide() else FLT.SetTex(entry.keyIcon, ks and KEY_ICON_YES or KEY_ICON_NO); entry.keyIcon:Show() end
      if entry.keyText then entry.keyText:SetText(ks~=nil and "" or (d.attunement=="unknown" and "?" or "-")) end
    end
    relayout()
  end
  browse:SetScript("OnShow",refreshBrowse)
  refreshBrowse()

  -- Detail header: back button, framed band with thumbnail, name, meta line
  -- and the Bosses & Loot / Quests switch.
  if detailBanner then OrnateFrame(detailBanner, detailBanner, 18, 4, "OVERLAY", 2) end
  local back=UI.GoldButton(detail,L["Dungeons"],112,24,ASSET_ROOT.."icon_back",12); back:SetPoint("TOPLEFT",8,-74)
  back:SetScript("OnClick",function() detail:Hide(); browse:Show() end)
  -- 6.2.7-beta12 (user 13.11.: "zwei button < und > wo man die dungeon durchschalten kann"): previous / next dungeon in
  -- the order of the list (its sorting and filters), round at the ends; the view (bosses / quests) stays
  local function neighbour(step)
    local list=browseOrder
    if #list==0 then list={}; for _,d in ipairs(FLT.DUNGEONS or {}) do if (not d.raid)==(not (selectedDungeon and selectedDungeon.raid)) then list[#list+1]=d end end end
    local n=#list; if n==0 or not selectedDungeon then return nil end
    local at=1; for i,d in ipairs(list) do if d==selectedDungeon then at=i break end end
    return list[(at-1+step)%n+1]
  end
  local function stepButton(step)
    -- the gold arrow of the "Dungeons" button (user 13.11.: "den < links neben Dungeons finde ich schoener"), mirrored for next
    local b=UI.GoldButton(detail,"",28,24,ASSET_ROOT.."icon_back",12)
    b.iconGap=0
    if b.icon then b.icon:ClearAllPoints(); b.icon:SetPoint("CENTER"); if step>0 then b.icon:SetTexCoord(1,0,0,1) end end
    b:SetScript("OnClick",function() local d=neighbour(step); if d and d~=selectedDungeon then UI.OpenDungeon(d,nil,(mode=="quests" and "quests") or nil) end end)
    b:SetScript("OnEnter",function(self)
      local d=neighbour(step); if not d then return end
      GameTooltip:SetOwner(self,"ANCHOR_BOTTOM"); GameTooltip:SetText(DN(d.name or "")); GameTooltip:Show()
    end)
    b:SetScript("OnLeave",function() GameTooltip:Hide() end)
    return b
  end
  local prevBtn=stepButton(-1); prevBtn:SetPoint("LEFT",back,"RIGHT",6,0)
  local nextBtn=stepButton(1); nextBtn:SetPoint("LEFT",prevBtn,"RIGHT",4,0)
  -- ht9 (user 30.10.): the band over the full width again (ht8 had made it as narrow as the list), a 1 px line
  local dband=CreateFrame("Frame",nil,detail); dband:SetPoint("TOPLEFT",8,-8); dband:SetSize(FULL_W,58)
  local dbandBg=makeTexture(dband,"BACKGROUND",0.045,0.045,0.058,0.96); dbandBg:SetPoint("TOPLEFT",1,-1); dbandBg:SetPoint("BOTTOMRIGHT",-1,1)
  UI.RoundRect(dband,dband,"OVERLAY",1,8,0,0.55,0.43,0.24,0.95,ASSET_ROOT.."window_ring")
  -- the buttons sit in the row under the band, right of "Dungeons" (they covered the line under the title)
  local brow=CreateFrame("Frame",nil,detail); brow:SetPoint("TOPLEFT",8,-73); brow:SetSize(FULL_W,26)
  -- dungeon picture fills the left part of the band (no own frame) and
  -- fades out to the right; the band's ornate frame lies on top
  local detailArt=dband:CreateTexture(nil,"BORDER"); detailArt:SetPoint("TOPLEFT",2,-2); detailArt:SetPoint("BOTTOMLEFT",2,2); detailArt:SetWidth(300); detailArt:Hide()
  local detailArtFrame={Show=function() end,Hide=function() end}
  local dtitle=FLT.NewFS(dband, nil,"OVERLAY","GameFontNormalLarge"); dtitle:SetPoint("TOPLEFT",196,-8); dtitle:SetTextColor(FLT.TextC(1,0.82,0.20))
  do local font,_,flags=dtitle:GetFont(); if font then dtitle:SetFont(font,21,flags) end end
  local dcrest=dband:CreateTexture(nil,"ARTWORK"); dcrest:SetSize(16,16); dcrest:SetPoint("TOPLEFT",194,-35); FLT.SetTex(dcrest, ASSET_ROOT.."faction_crests")
  local dmeta=FLT.NewFS(dband, nil,"OVERLAY","GameFontHighlightSmall"); dmeta:SetPoint("LEFT",dcrest,"RIGHT",5,0); dmeta:SetTextColor(FLT.TextC(0.78,0.75,0.68))
  local bossesBtn=UI.GoldButton(brow,L["Bosses & Loot"],126,26,nil,13); bossesBtn:SetPoint("RIGHT",-142,0)
  local questsBtn=UI.GoldButton(brow,L["Quests"],120,26,nil,13); questsBtn:SetPoint("RIGHT",-14,0)
  local keyBtn=UI.GoldButton(brow,L["Key"],110,26,nil,13); keyBtn:SetPoint("RIGHT",-14,0); keyBtn:Hide()
  local mapBtn=UI.GoldButton(brow,L["Map"],84,26,ASSET_ROOT.."icon_map",13,true); -- a real button here (user 31.10.)
  mapBtn:SetPoint("RIGHT",bossesBtn,"LEFT",-8,0); mapBtn:Hide() -- 8 px between all head buttons (user 31.10.)

  -- Rounded card background with an automatic border colour (lighter than
  -- the fill); keeps the SetColorTexture() calls of the list code working.
  -- Gold weighting: window frame strong, banner/header medium, panels dark
  -- bronze, single rows very subtle, the active selection strong gold.
  local ROW_EDGE={0.30,0.26,0.20,0.85}      -- subtle bronze-grey row border
  local ROW_EDGE_HOVER={0.52,0.40,0.22,0.95} -- warm bronze, clearly weaker than the gold selection
  local ROW_EDGE_ACTIVE={1.00,0.80,0.34,1}
  -- ht11 (user 30.10.): rows like the lists elsewhere - no frame, a fine line under the row, a faint hover; the
  -- selected row a dark warm plate with the short gold mark on the left (like the side lists)
  local function cardBg(owner,r,g,b,a,edge)
    local line=owner:CreateTexture(nil,"BORDER"); line:SetColorTexture(0.40,0.32,0.20,0.35); line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT",4,0); line:SetPoint("BOTTOMRIGHT",-4,0)
    local sel=UI.RoundRect(owner,owner,"BACKGROUND",1,6,0,0.21,0.15,0.08,0.95); sel:SetShown(false)
    local mark=UI.GlowLine(owner,"LEFT",0.85,5); mark:Hide()
    local hov=owner:CreateTexture(nil,"BACKGROUND",nil,2); hov:SetAllPoints(); hov:SetColorTexture(0.90,0.66,0.22,0.06); hov:Hide()
    local o={ active=false, hover=false }
    local fill, ring -- a status tint under the row (quest list: completed = light green, 6.1.9)
    local function apply()
      -- plateOff: the selection is a gold frame around the row without the fill, so the status colour stays visible
      -- (quest list, user 07.11.: "wie bei den Bossen mit dem Rahmen aussenrum ... die gelbe Fuellung bitte nicht")
      -- (and without the glow line on the left, beta5: "nur der Rahmen")
      sel:SetShown(o.active and not o.plateOff); mark:SetShown(o.active and not o.plateOff); hov:SetShown(o.hover and not o.active)
      if o.plateOff and o.active and not ring then ring=UI.RoundRect(owner,owner,"BORDER",1,6,0,0.86,0.66,0.30,0.95,ASSET_ROOT.."window_ring") end
      if ring then ring:SetShown(o.active and o.plateOff and true or false) end
    end
    -- a green that fades out by the middle of the row (quest ready to turn in, beta38, user 07.11.: "nur bis zur haelfte
    -- ... schoen faden und keine harte kante"). One rounded fill over the left half, all pieces the same texture
    -- (beta40: a separate plain gradient next to a rounded cap showed a seam): the left column solid, the middle
    -- pieces a horizontal gradient to nothing, the right column invisible
    local half
    -- every piece goes through the same gradient call (the left column from a3 to a3), so no seam can show
    local function fadeTex(t,r3,g3,b3,a3,e3)
      if not (t.SetGradient and CreateColor and pcall(t.SetGradient,t,"HORIZONTAL",CreateColor(r3,g3,b3,a3),CreateColor(r3,g3,b3,e3))) then
        if t.SetGradientAlpha then t:SetGradientAlpha("HORIZONTAL",r3,g3,b3,a3,r3,g3,b3,e3) else t:SetVertexColor(r3,g3,b3,(a3+e3)/2) end
      end
    end
    function o:SetHalfFill(r2,g2,b2,a2)
      if not r2 then if half then half:SetShown(false) end return end
      if not half then
        local anchor=CreateFrame("Frame",nil,owner); anchor:SetPoint("TOPLEFT"); anchor:SetPoint("BOTTOMLEFT")
        anchor:SetWidth(math.max(40,(owner:GetWidth() or 300)*0.55))
        half=UI.RoundRect(owner,anchor,"BACKGROUND",0,6,0,1,1,1,0)
      end
      local sr,sg,sb,sa=FLT.SkinC(r2,g2,b2,a2)
      local p=half.pieces -- tl, tr, bl, br, top, bot, left, right, middle
      for _,k in ipairs({1,3,7}) do fadeTex(p[k],sr,sg,sb,sa,sa) end
      for _,k in ipairs({2,4,8}) do fadeTex(p[k],sr,sg,sb,0,0) end
      for _,k in ipairs({5,6,9}) do fadeTex(p[k],sr,sg,sb,sa,0) end
      half:SetShown(true)
    end
    function o:SetFill(r2,g2,b2,a2)
      if not r2 then if fill then fill:SetShown(false) end return end
      if not fill then fill=UI.RoundRect(owner,owner,"BACKGROUND",0,6,0,r2,g2,b2,a2) end
      fill:SetColor(r2,g2,b2,a2); fill:SetShown(true)
    end
    -- the optional 5th value marks the active (selected) state
    function o:SetColorTexture(r2,g2,b2,a2,active) o.active=active and true or false; apply() end
    function o:Hover(on) o.hover=on and true or false; apply() end
    function o:SetAllPoints() end
    o:SetColorTexture(FLT.SkinC(r,g,b,a))
    -- Hover tint: wrap OnEnter/OnLeave so scripts set later keep the tint
    -- (a later SetScript would otherwise drop a HookScript).
    local origSet=owner.SetScript
    if origSet then
      local function wrap(name,fn)
        if name=="OnEnter" then return function(...) o:Hover(true); if fn then return fn(...) end end end
        if name=="OnLeave" then return function(...) o:Hover(false); if fn then return fn(...) end end end
        return fn
      end
      owner.SetScript=function(self,name,fn) return origSet(self,name,wrap(name,fn)) end
      owner:SetScript("OnEnter",nil); owner:SetScript("OnLeave",nil)
    end
    return o
  end
  -- dark panel with the ornate frame (boss / quest lists and their details)
  local function framedPanel(f,lineX)
    -- ht10 (user 30.10.): no boxes - the list and its details on the page, a fine line between them
    if lineX then
      local vl=f:CreateTexture(nil,"ARTWORK"); vl:SetColorTexture(0.50,0.38,0.19,0.55); vl:SetWidth(1)
      vl:SetPoint("TOPLEFT",f,"TOPRIGHT",lineX,0); vl:SetPoint("BOTTOMLEFT",f,"BOTTOMRIGHT",lineX,0)
    end
    if true then return end
    local bg=makeTexture(f,"BACKGROUND",0.040,0.040,0.050,0.95); bg:SetPoint("TOPLEFT",2,-2); bg:SetPoint("BOTTOMRIGHT",-2,2)
    -- subtle leather structure instead of flat black
    local lea=f:CreateTexture(nil,"BACKGROUND",nil,1); lea:SetPoint("TOPLEFT",2,-2); lea:SetPoint("BOTTOMRIGHT",-2,2)
    FLT.SetTex(lea, ASSET_ROOT.."leather"); lea:SetVertexColor(FLT.SkinC(0.55,0.50,0.46)); lea:SetAlpha(0.55)
    -- dark bronze instead of bright gold for the inner panels
    for _,t in ipairs(OrnateFrame(f, f, 12, 1, "OVERLAY", 3)) do t:SetVertexColor(FLT.SkinC(0.62,0.52,0.40,0.9)) end
  end

  -- Header band at the top of a list panel: the dungeon's art fades in from
  -- the right behind the title, closed by a line in the dungeon's accent.
  -- the header band of the left lists (bosses, quests, key / attunement): plain, no picture (bosses since 5.7.x,
  -- quests and key the same since 5.7.3, user 27.10.)
  local function listBand(f)
    local base=f:CreateTexture(nil,"BORDER",nil,0); base:SetPoint("TOPLEFT",4,-4); base:SetPoint("TOPRIGHT",-4,-4); base:SetHeight(36)
    base:SetColorTexture(FLT.SkinC(0.03,0.03,0.035,0.85))
    local lea=f:CreateTexture(nil,"BORDER",nil,2); lea:SetAllPoints(base); FLT.SetTex(lea, ASSET_ROOT.."leather"); lea:SetVertexColor(FLT.SkinC(0.5,0.45,0.4)); lea:SetAlpha(0.15)
    local line=f:CreateTexture(nil,"ARTWORK"); FLT.SetTex(line, ASSET_ROOT.."divider_ornate")
    line:SetPoint("LEFT",base,"BOTTOMLEFT",0,0); line:SetPoint("RIGHT",base,"BOTTOMRIGHT",0,0); line:SetHeight(16)
  end
  -- Atmospheric backdrop behind the detail header of the right panel.
  local function detailBackdrop(f,d,strength)
    local path=dungeonBackdrop(d.key,"bg")
    local lsKey=FLT.DUNGEON_LOADSCREENS and FLT.DUNGEON_LOADSCREENS[d.key] and d.key
    if path or lsKey then
      local art=f:CreateTexture(nil,"BORDER",nil,0); art:SetPoint("TOPLEFT",3,-3); art:SetPoint("TOPRIGHT",-3,-3); art:SetHeight(112)
      -- ls6 (user 16.11.: "die Hauptfarbe aus dem Dungeonbild ... einfarbig"): with a loading screen the background is
      -- the picture's main colour, fading out downwards (no second copy of the picture)
      if lsKey then
        local r,g,b=dungeonAccent(d.key)
        local top=0.42*((strength or 0.85)/0.85)
        art:SetColorTexture(1,1,1,1)
        if not (art.SetGradient and CreateColor and pcall(art.SetGradient,art,"VERTICAL",CreateColor(r,g,b,0),CreateColor(r,g,b,top))) then
          art:SetColorTexture(r,g,b,top*0.5)
        end
      else FLT.SetTex(art, path); art:SetAlpha(strength or 0.85) end
      -- painted look: leather grain over the blur, dark vignette behind the portrait
      local lea=f:CreateTexture(nil,"BORDER",nil,1); lea:SetAllPoints(art); FLT.SetTex(lea, ASSET_ROOT.."leather"); lea:SetVertexColor(FLT.SkinC(0.5,0.45,0.4)); lea:SetAlpha(0.15)
      local sh=f:CreateTexture(nil,"BORDER",nil,2); sh:SetPoint("TOPLEFT",art,"TOPLEFT"); sh:SetPoint("BOTTOMLEFT",art,"BOTTOMLEFT"); sh:SetWidth(260); FLT.SetTex(sh, ASSET_ROOT.."shade_lr")
    end
    local ar,ag,ab=dungeonAccent(d.key)
    local glow=f:CreateTexture(nil,"BORDER",nil,1); glow:SetPoint("TOPLEFT",3,-3); glow:SetPoint("TOPRIGHT",-3,-3); glow:SetHeight(2)
    glow:SetColorTexture(FLT.SkinC(ar,ag,ab,0.55))
  end

  -- Scroll bars sit inside their panel at the same height on both sides and
  -- only appear when there is something to scroll.
  local function tidyScroll(sf,panel)
    local bar=sf.ScrollBar
    if type(bar)~="table" or not bar.ClearAllPoints then return end
    if UI.SlimScrollBar then UI.SlimScrollBar(bar) end -- ht12: thin grey bar
    bar:ClearAllPoints()
    bar:SetPoint("TOPRIGHT",panel,"TOPRIGHT",-7,-66)
    bar:SetPoint("BOTTOMRIGHT",panel,"BOTTOMRIGHT",-7,24)
    sf.scrollBarHideable=true
    local function upd() bar:SetShown((sf:GetVerticalScrollRange() or 0)>0.5) end
    sf:HookScript("OnScrollRangeChanged",upd)
    sf:HookScript("OnShow",upd)
    if type(C_Timer)=="table" and C_Timer.After then C_Timer.After(0,upd) end
    upd()
  end

  -- Body is no longer one big ScrollFrame. Boss/quest lists own their scroll state,
  -- so selecting an entry never sends the entire dungeon page back to the top.
  local body=CreateFrame("Frame",nil,detail); body:SetPoint("TOPLEFT",8,-106); body:SetPoint("BOTTOMRIGHT",-8,4)
  -- Every dungeon/mode(/faction filter) combination gets its own view frame.
  -- A view is built on first use and afterwards only shown/hidden. WoW never
  -- frees frames, so the previous "destroy and rebuild on every click"
  -- approach leaked frames for as long as the UI was used.
  local views={}
  local currentView
  local function showView(key)
    for k,v in pairs(views) do if k~=key then v:Hide() end end
    local v=views[key]
    if v then v:Show() end
    return v
  end
  local function newView(key)
    local v=CreateFrame("Frame",nil,body); v:SetAllPoints()
    views[key]=v; currentView=v
    showView(key)
    return v
  end
  local function dynFrame(kind,parentFrame,template)
    return CreateFrame(kind,nil,parentFrame or currentView,template)
  end
  local function dynText(parentFrame,template)
    return FLT.NewFS(parentFrame, nil,"OVERLAY",template or "GameFontHighlight")
  end

  -- Item names/icons are colored from the client item cache. Cached panes
  -- re-apply them when shown again, because the data may have loaded since.
  local function refreshItemVisuals(list)
    for _,it in ipairs(list or {}) do
      colorDungeonItemText(it.text,it.rec,it.r,it.g,it.b)
      if it.rec.id and FLT.ItemName then it.text:SetText(FLT.ItemName(it.rec.id,it.rec.name)) end -- German once loaded
      if it.icon then FLT.SetTex(it.icon, dungeonItemIcon(it.rec)) end
      -- green arrow on upgrades (user 16.11.), like the bags and the game's quest rewards
      if it.icon and it.rec.id and FLT.GearMarks then FLT.GearMarks.IconArrow(it.icon, it.rec.id) end
    end
  end

  local function showLootTooltip(owner,item,label)
    local rec=normalizeDungeonItem(item)
    if tryShowItemTooltip(owner,rec) then return end
    H.anchorItemTooltip(owner)
    GameTooltip:AddLine(FLT.ItemName and FLT.ItemName(rec.id,rec.name) or rec.name or L["Unknown item"],1,0.82,0)
    if rec.slot then GameTooltip:AddLine(FLT.SlotText and FLT.SlotText(rec.slot) or rec.slot,0.70,0.82,1.00) end
    if rec.summary then GameTooltip:AddLine(rec.summary,0.85,0.85,0.85,true) end
    GameTooltip:AddLine(L[label or "Dungeon loot"],0.65,0.85,1)
    if rec.id then GameTooltip:AddLine(string.format(L["Item ID: %s"],tostring(rec.id)),0.55,0.55,0.55) end
    GameTooltip:AddLine(L["Current Forever beta data; stats and drop tables can change."],0.70,0.70,0.70,true)
    GameTooltip:Show()
  end


  local function renderBosses(d)
    local viewKey="bosses:"..d.key
    local view=showView(viewKey)
    if view then
      -- Portraits resolve asynchronously and may have failed earlier; ask
      -- again (resolved display IDs are cached, so this is cheap).
      for _,row in ipairs(view.rows) do
        if row.boss then setBossPortrait(row.icon,d,row.boss) end
      end
      view.select(bossSelection[d.key] or 1)
      return
    end
    view=newView(viewKey)

    local left=dynFrame("Frame"); left:SetPoint("TOPLEFT",0,0); left:SetPoint("BOTTOMLEFT",0,0); left:SetWidth(390)
    framedPanel(left,7)
    listBand(left)
    local lh=dynText(left,"GameFontNormalLarge"); lh:SetPoint("TOPLEFT",16,-14); lh:SetText(L["Bosses"].."  |  "..#(d.bosses or {})); lh:SetTextColor(FLT.TextC(1,0.82,0.20))

    local bsf=dynFrame("ScrollFrame",left,"UIPanelScrollFrameTemplate"); bsf:SetPoint("TOPLEFT",10,-50); bsf:SetPoint("BOTTOMRIGHT",-3,8); tidyScroll(bsf,left)
    local bchild=dynFrame("Frame",bsf); bchild:SetSize(LAYOUT.QUEST_LIST_WIDTH,1); bsf:SetScrollChild(bchild)
    local bosses=d.bosses or {}
    local trashLoot=d.trashLoot or {}
    local entryCount=#bosses + ((#trashLoot>0) and 1 or 0)
    local idx=bossSelection[d.key] or 1; if idx>entryCount then idx=1 end; if idx<1 then idx=1 end
    local by=-2
    local rows={}
    for i,boss in ipairs(bosses) do
      local bossName=boss.name or tostring(boss)
      local b=dynFrame("Button",bchild); b:SetSize(LAYOUT.QUEST_ROW_WIDTH,50); b:SetPoint("TOPLEFT",0,by); by=by-52
      local bg=cardBg(b,0.068,0.070,0.080,0.95)
      local hi=makeTexture(b,"HIGHLIGHT",0.62,0.44,0.16,0.045); hi:SetPoint("TOPLEFT",1,-1); hi:SetPoint("BOTTOMRIGHT",-1,1)
      local bframe=UI.CreateBossFrame(b,42,false,true); bframe:SetPoint("LEFT",5,1)
      local icon=bframe.portrait; setBossPortrait(icon,d,boss)
      -- Number and name are separate so the level line lines up exactly
      -- under the first letter of the boss name.
      local num=FLT.NewFS(b, nil,"OVERLAY","GameFontHighlight"); num:SetWidth(24); num:SetJustifyH("LEFT"); num:SetText(i..".")
      local t=FLT.NewFS(b, nil,"OVERLAY","GameFontHighlight"); t:SetWidth(250); t:SetJustifyH("LEFT"); t:SetText(NM(bossName))
      -- Forever-only bosses have no known level until you target them once
      local bossLevel=FLT.GetBossLevel and FLT:GetBossLevel(boss)
      num:SetPoint("TOPLEFT",50,-9); t:SetPoint("TOPLEFT",76,-9)
      local lv=FLT.NewFS(b, nil,"OVERLAY","GameFontDisableSmall"); lv:SetPoint("TOPLEFT",t,"BOTTOMLEFT",0,-3); lv:SetJustifyH("LEFT")
      lv:SetText(string.format(L["Level %s"],bossLevel or "?"))
      t.num=num
      -- small ornate corners mark the selected boss
      local orn=OrnateFrame(b,b,10,1,"OVERLAY",2); for _,o in ipairs(orn) do o:Hide() end
      rows[i]={button=b,bg=bg,text=t,icon=icon,boss=boss,orn=orn,lv=lv}
    end
    if #trashLoot>0 then
      local i=#bosses+1
      local b=dynFrame("Button",bchild); b:SetSize(LAYOUT.QUEST_ROW_WIDTH,50); b:SetPoint("TOPLEFT",0,by); by=by-52
      local bg=cardBg(b,0.060,0.072,0.066,0.95)
      local hi=makeTexture(b,"HIGHLIGHT",0.62,0.44,0.16,0.045); hi:SetPoint("TOPLEFT",1,-1); hi:SetPoint("BOTTOMRIGHT",-1,1)
      local tframe=UI.CreateRingFrame(b,40,"gold"); tframe:SetPoint("LEFT",6,0)
      local icon=tframe.portrait; FLT.SetTex(icon, "Interface\\Icons\\INV_Misc_Bag_10_Blue")
      local t=FLT.NewFS(b, nil,"OVERLAY","GameFontHighlight"); t:SetPoint("LEFT",50,0); t:SetWidth(270); t:SetJustifyH("LEFT"); t:SetText(L["Trash"])
      rows[i]={button=b,bg=bg,text=t,icon=icon,isTrash=true}
    end
    bchild:SetHeight(math.max(1,-by+2))

    local right=dynFrame("Frame"); right:SetPoint("TOPLEFT",405,0); right:SetPoint("BOTTOMRIGHT",0,0)
    framedPanel(right)
    detailBackdrop(right,d)

    -- One cached detail pane per boss entry.
    local detailPanes={}
    local host
    local function dframe(kind,parentFrame,template)
      return CreateFrame(kind,nil,parentFrame or host,template)
    end
    local function dtext(parentFrame,template)
      return FLT.NewFS(parentFrame, nil,"OVERLAY",template or "GameFontHighlight")
    end

    local function selectBoss(newIdx)
      local bosses=d.bosses or {}
      local trashLoot=d.trashLoot or {}
      local maxIdx=#bosses + ((#trashLoot>0) and 1 or 0)
      if maxIdx==0 then return end
      if newIdx<1 then newIdx=1 elseif newIdx>maxIdx then newIdx=maxIdx end
      bossSelection[d.key]=newIdx
      for i,row in ipairs(rows) do
        for _,o in ipairs(row.orn or {}) do o:SetShown(i==newIdx) end
        if i==newIdx then
          row.bg:SetColorTexture(FLT.SkinC(0.22,0.155,0.055,0.98,true))
          row.text:SetTextColor(FLT.TextC(1,0.82,0.20)); if row.text.num then row.text.num:SetTextColor(FLT.TextC(1,0.82,0.20)) end
        else
          if row.isTrash then row.bg:SetColorTexture(FLT.SkinC(0.060,0.072,0.066,0.95)) else row.bg:SetColorTexture(FLT.SkinC(0.068,0.070,0.080,0.95)) end
          row.text:SetTextColor(FLT.TextC(0.92,0.90,0.84)); if row.text.num then row.text.num:SetTextColor(FLT.TextC(0.92,0.90,0.84)) end
        end
      end

      for i,pane in pairs(detailPanes) do if i~=newIdx then pane:Hide() end end
      -- 6.2.7-beta7 (user 13.11.: a friend targeted the bosses and still saw "Level ?"): a pane built before the level /
      -- type was learned in game is built again, and the list row shows the learned level
      local rb=rows[newIdx] and rows[newIdx].boss
      if rb and rows[newIdx].lv and FLT.GetBossLevel then
        local lvNow=FLT:GetBossLevel(rb); if lvNow then rows[newIdx].lv:SetText(string.format(L["Level %s"],lvNow)) end
      end
      local stale=detailPanes[newIdx]
      if stale and stale.needsInfo and stale.boss and FLT.GetBossLevel and FLT:GetBossLevel(stale.boss) and FLT.GetBossType and FLT:GetBossType(stale.boss) then
        stale:Hide(); detailPanes[newIdx]=nil
      end
      if detailPanes[newIdx] then
        local pane=detailPanes[newIdx]
        pane:Show()
        if pane.boss then setBossPortrait(pane.portrait,d,pane.boss) end
        refreshItemVisuals(pane.items)
        return
      end
      host=CreateFrame("Frame",nil,right); host:SetAllPoints()
      host.items={}
      detailPanes[newIdx]=host

      local isTrash=(#trashLoot>0 and newIdx==#bosses+1)
      local boss=isTrash and nil or bosses[newIdx]
      local loot=isTrash and trashLoot or (boss and (boss.loot or (d.bossLoot and d.bossLoot[boss.name]) or {}) or {})
      local portrait
      if isTrash then
        portrait=UI.CreateRingFrame(host,72,"gold"); portrait:SetPoint("TOPLEFT",12,-10)
      else
        portrait=UI.CreateBossFrame(host,88,true); portrait:SetPoint("TOPLEFT",12,-8)
        portrait:SetLevel((FLT.GetBossLevel and FLT:GetBossLevel(boss)) or "?")
      end
      local portraitIcon=portrait.portrait
      if isTrash then FLT.SetTex(portraitIcon, "Interface\\Icons\\INV_Misc_Bag_10_Blue") else setBossPortrait(portraitIcon,d,boss) end
      host.portrait=portraitIcon; host.boss=boss or false
      local bn=dtext(host,"GameFontNormalLarge"); bn:SetPoint("TOPLEFT",112,-20); bn:SetWidth(410); bn:SetJustifyH("LEFT"); bn:SetText(isTrash and L["Trash"] or NM(boss.name or tostring(boss))); bn:SetTextColor(FLT.TextC(1,0.82,0.20))
      local sub=dtext(host,"GameFontHighlightSmall"); sub:SetPoint("TOPLEFT",113,-50); sub:SetTextColor(FLT.TextC(0.84,0.81,0.74)); local bossLevel=(not isTrash) and FLT.GetBossLevel and FLT:GetBossLevel(boss)
      if isTrash then
        sub:SetText(L["Rare and better drops from the dungeon's enemies"])
      else
        -- Level | creature type | rank (Elite, Rare in blue, Summoned)
        local parts={ string.format(L["Level %s"],bossLevel or "?") }
        local ctype=FLT.GetBossType and FLT:GetBossType(boss)
        if ctype then parts[#parts+1]=L[ctype] end
        local rank=FLT.GetBossRank and FLT:GetBossRank(boss)
        if rank=="Rare" then parts[#parts+1]="|cff4fa3ff"..L["Rare"].."|r" elseif rank then parts[#parts+1]=L[rank] end
        local t=table.concat(parts,"  |  ")
        if not bossLevel or not ctype then t=t.."  |cff8f8f8f"..L["(target the boss once to learn the rest)"].."|r"; host.needsInfo=true end
        sub:SetText(t)
      end
      if isTrash then
        -- 6.2.7-beta11: no extra line here - it ran into the header (user screenshot 13.11.); the subtitle says it
      elseif boss.description then
        -- right of the portrait, under the divider (Discord qithulien 16.11.: under the portrait it was covered by it)
        local desc=dtext(host,"GameFontHighlightSmall"); desc:SetPoint("TOPLEFT",113,-84); desc:SetWidth(405); desc:SetJustifyH("LEFT"); desc:SetText(boss.description)
        host.descH=desc.GetStringHeight and desc:GetStringHeight() or 12
      end

      -- thin decorative gold divider that closes the header
      -- ornate gold divider that closes the boss header
      local dv=host:CreateTexture(nil,"ARTWORK"); FLT.SetTex(dv, ASSET_ROOT.."divider_ornate")
      dv:SetPoint("TOPLEFT",108,-66); dv:SetPoint("TOPRIGHT",-24,-66); dv:SetHeight(20)
      local lsf=dframe("ScrollFrame",host,"UIPanelScrollFrameTemplate"); lsf:SetPoint("TOPLEFT",12,math.min(-106,-90-(host.descH or 0))); lsf:SetPoint("BOTTOMRIGHT",-2,8); tidyScroll(lsf,right)
      local lchild=dframe("Frame",lsf); lchild:SetSize(515,1); lsf:SetScrollChild(lchild)
      local ly=-2
      if #loot==0 then
        local none=dtext(lchild,"GameFontDisable"); none:SetPoint("TOPLEFT",8,ly-8); none:SetWidth(495); none:SetJustifyH("LEFT"); none:SetText(L[isTrash and N"No curated trash loot is present in the current embedded beta data set." or (d.dataStatus=="partial" and N"Loot for this new Forever dungeon has not been recorded yet. It will be added once drop data is available." or (boss and boss.worldDropsOnly and N"This boss has no boss-specific loot - it only drops random world items (the same as in Classic)." or N"No boss-specific loot is recorded for this boss in the current Forever data."))])
        ly=ly-44
      else
        for j,item in ipairs(loot) do
          local rec=normalizeDungeonItem(item)
          local row=dframe("Button",lchild); row:SetSize(510,48); row:SetPoint("TOPLEFT",0,ly); ly=ly-50
          local bg=cardBg(row,0.055,0.067,0.080,(j%2==0) and 0.96 or 0.88)
          local hi=makeTexture(row,"HIGHLIGHT",0.30,0.36,0.44,0.10); hi:SetPoint("TOPLEFT",1,-1); hi:SetPoint("BOTTOMRIGHT",-1,1)
          local ic=row:CreateTexture(nil,"ARTWORK"); ic:SetSize(30,30); ic:SetPoint("LEFT",9,0); FLT.SetTex(ic, dungeonItemIcon(rec))
          -- Classic drop chance on the right (Data\DungeonDropChance.lua)
          local chance,kills,scaled
          if FLT.GetDropChance then chance,kills,scaled=FLT.GetDropChance(d.name,isTrash and "Trash" or (boss and boss.name),rec.id) end
          local textW=340 -- same for every row, so the stars line up (user 07.11.)
          local nm=FLT.NewFS(row, nil,"OVERLAY","GameFontNormal"); nm:SetPoint("TOPLEFT",50,-8); nm:SetWidth(textW); nm:SetJustifyH("LEFT"); nm:SetText(FLT.ItemName and FLT.ItemName(rec.id,rec.name) or rec.name); colorDungeonItemText(nm,rec,0.55,0.78,1.00)
          host.items[#host.items+1]={text=nm,icon=ic,rec=rec,r=0.55,g=0.78,b=1.00}
          if rec.slot then local sl=FLT.NewFS(row, nil,"OVERLAY","GameFontDisableSmall"); sl:SetPoint("TOPLEFT",50,-27); sl:SetWidth(textW); sl:SetJustifyH("LEFT"); sl:SetText(FLT.SlotText and FLT.SlotText(rec.slot) or rec.slot) end
          if chance then
            local ch=FLT.NewFS(row, nil,"OVERLAY","GameFontHighlightSmall"); ch:SetPoint("RIGHT",-48,0); ch:SetJustifyH("RIGHT"); ch._ofaNoAnchor=true
            ch:SetText((chance<1 and string.format("%.2g",chance) or string.format("%d",math.floor(chance+0.5))).." %"); ch:SetTextColor(FLT.TextC(0.70,0.68,0.62))
            local chHover=CreateFrame("Frame",nil,row); chHover:SetPoint("RIGHT",-42,0); chHover:SetSize(52,30)
            chHover:SetScript("OnEnter",function(self)
              GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:AddLine(L["Drop chance"],1,0.82,0.20)
              -- measured in Forever (Wowhead Forever, 6.2.12-beta10) or the Classic chance
              if kills and kills>0 then GameTooltip:AddLine(string.format(L["Drop chance in WoW Forever, from %d kills on Wowhead."],kills),1,1,1,true)
              elseif kills then GameTooltip:AddLine(L["Drop chance in WoW Forever, from Wowhead."],1,1,1,true)
              else GameTooltip:AddLine(L["Classic drop chance - Forever can differ."],1,1,1,true) end
              if scaled then GameTooltip:AddLine(L["Wowhead counts more kills than drops for this boss: scaled so that its loot adds up to about one item per kill."],0.7,0.7,0.7,true) end
              GameTooltip:Show()
            end)
            chHover:SetScript("OnLeave",function() GameTooltip:Hide() end)
          end
          -- wishlist star for gear (Gear Planner, 5.6.3), at the right edge, the drop chance left of it (user 07.11.)
          if rec.id and UI.WishStar then local st=UI.WishStar(row); st:SetPoint("RIGHT",-12,0); st:SetItem(rec.id) end
          row:SetScript("OnEnter",function(self)
            showLootTooltip(self,rec,isTrash and N"Dungeon trash loot" or N"Dungeon loot")
            -- SetHyperlink may finish loading live Forever item data on first hover.
            -- Re-read the quality so the row immediately matches the native tooltip.
            colorDungeonItemText(nm,rec,0.55,0.78,1.00)
          end)
          row:SetScript("OnLeave",function() GameTooltip:Hide() end)
          row:RegisterForClicks("LeftButtonUp")
          row:SetScript("OnClick",function(_,button) handleDungeonItemClick(rec,button) end)
        end
      end

      -- Recipe drops of this boss (Forever's shared recipe pool), collapsible.
      local showRecipes = not (type(OneForAllDB)=="table" and OneForAllDB.dungeonRecipes==false)
      local recipes = (not isTrash) and boss and showRecipes and FLT.GetBossRecipes and FLT.GetBossRecipes(boss.npcID)
      if recipes and #recipes>0 then
        local sk=d.key..":"..newIdx
        local open=recipeSectionOpen[sk]==true -- collapsed by default
        ly=ly-8
        local hdr=dframe("Button",lchild); hdr:SetSize(510,30); hdr:SetPoint("TOPLEFT",0,ly); ly=ly-32
        -- ht11: a quiet group head (dark plate, thin line) instead of the gold box
        UI.MarkBG(UI.RoundRect(hdr,hdr,"BACKGROUND",0,7,1,0.075,0.068,0.058,0.96))
        UI.RoundRect(hdr,hdr,"BORDER",0,8,0,0.42,0.33,0.20,0.9,ASSET_ROOT.."window_ring")
        local hhi=makeTexture(hdr,"HIGHLIGHT",0.90,0.66,0.22,0.06); hhi:SetAllPoints()
        local hch=hdr:CreateTexture(nil,"OVERLAY"); hch:SetSize(14,14); hch:SetPoint("LEFT",10,0); FLT.SetTex(hch, ASSET_ROOT.."chevron")
        if open then hch:SetTexCoord(0,0.5,0,1) else hch:SetTexCoord(0.5,1,0,1) end
        local ht=FLT.NewFS(hdr, nil,"OVERLAY","GameFontNormal"); ht:SetPoint("LEFT",30,0)
        ht:SetText(string.format(L["Recipes (%d)"],#recipes)); ht:SetTextColor(FLT.TextC(1,0.82,0.20))
        local hn=FLT.NewFS(hdr, nil,"OVERLAY","GameFontDisableSmall"); hn:SetPoint("RIGHT",-10,0)
        hn:SetText(L["rare drops from a shared recipe pool"])
        -- rebuild exactly this pane (host is shared and may point elsewhere)
        local myPane=host
        hdr:SetScript("OnClick",function()
          recipeSectionOpen[sk]=not open
          myPane:Hide(); detailPanes[newIdx]=nil; selectBoss(newIdx)
        end)
        if open then
          for j,e in ipairs(recipes) do
            local r=e.r
            local rec={id=r.ri,name=r.rn or r.n}
            local row=dframe("Button",lchild); row:SetSize(510,40); row:SetPoint("TOPLEFT",0,ly); ly=ly-42
            local bg=cardBg(row,0.060,0.055,0.045,(j%2==0) and 0.96 or 0.88)
            local hi=makeTexture(row,"HIGHLIGHT",0.62,0.44,0.16,0.045); hi:SetPoint("TOPLEFT",1,-1); hi:SetPoint("BOTTOMRIGHT",-1,1)
            local ic=row:CreateTexture(nil,"ARTWORK"); ic:SetSize(26,26); ic:SetPoint("LEFT",11,0); FLT.SetTex(ic, dungeonItemIcon(rec))
            local pic=row:CreateTexture(nil,"OVERLAY"); pic:SetSize(14,14); pic:SetPoint("BOTTOMRIGHT",ic,"BOTTOMRIGHT",4,-4)
            FLT.SetTex(pic, FLT.PROFESSION_ICONS and FLT.PROFESSION_ICONS[e.prof] or "Interface\\Icons\\INV_Misc_Note_01")
            local nm=FLT.NewFS(row, nil,"OVERLAY","GameFontNormal"); nm:SetPoint("TOPLEFT",50,-5); nm:SetWidth(380); nm:SetJustifyH("LEFT"); nm:SetText(FLT.ItemName and FLT.ItemName(rec.id,rec.name) or rec.name); colorDungeonItemText(nm,rec,0.55,0.78,1.00)
            host.items[#host.items+1]={text=nm,icon=ic,rec=rec,r=0.55,g=0.78,b=1.00}
            local sl=FLT.NewFS(row, nil,"OVERLAY","GameFontDisableSmall"); sl:SetPoint("TOPLEFT",50,-23); sl:SetWidth(380); sl:SetJustifyH("LEFT")
            sl:SetText(L[e.prof]..((r.req or r.y) and ("  |  "..string.format(L["skill %s"],r.req or r.y)) or "").."  |  "..(r.n or ""))
            -- yellow = you, green = guild, blue = other OneForAll users online
            if FLT.RecipeKnowState then
              local k,gu,ot=FLT.RecipeKnowState(e.prof,r)
              local cx=-10
              local K=UI.KNOW_COLORS
              local M=UI.KNOW_MARKS
              for _,c in ipairs({{ot,K.other,M.other},{gu,K.guild,M.guild},{k,K.me,M.me}}) do
                if c[1] then
                  local t=UI.Mark(row,14,c[3],unpack(c[2])); t:SetPoint("RIGHT",cx,0)
                end
                cx=cx-16
              end
            end
            row:SetScript("OnEnter",function(self)
              showLootTooltip(self,rec,N"Recipe drop  -  click to open in Professions")
              colorDungeonItemText(nm,rec,0.55,0.78,1.00)
            end)
            row:SetScript("OnLeave",function() GameTooltip:Hide() end)
            row:RegisterForClicks("LeftButtonUp")
            row:SetScript("OnClick",function(_,button)
              if IsShiftKeyDown and IsShiftKeyDown() then handleDungeonItemClick(rec,button); return end
              if FLT.OpenPanel then FLT:OpenPanel("professions") end
              if UI.EnsurePanel then UI.EnsurePanel("professions") end; if FLT.ShowRecipeInProfessions then FLT.ShowRecipeInProfessions(e.prof,r.s) end
            end)
          end
        end
      end
      if FLT.GearMarks then for _,it in ipairs(host.items) do if it.rec.id then FLT.GearMarks.IconArrow(it.icon,it.rec.id) end end end
      lchild:SetHeight(math.max(1,-ly+2))
    end

    for i,row in ipairs(rows) do
      row.button:SetScript("OnClick",function() selectBoss(i) end)
    end
    view.select=selectBoss
    view.rows=rows
    selectBoss(idx)
  end


  -- Detail layout shared by the Quests and Key tabs: title, a row of small
  -- "chips" (level, faction, status ...), label rows and framed boxes.
  local CHIP_CREST={Alliance={0,0.25},Horde={0.25,0.5},Both={0.5,0.75}}
  local STATUS_COLOR={completed={0.40,0.94,0.50},inlog={1,0.82,0.20},chain={0.45,0.85,0.70},ready={1,0.82,0.20},available={0.92,0.90,0.84},unavailable={0.62,0.60,0.56},open={0.92,0.90,0.84}}
  local function makeChip(parent,text,color,crest)
    local f=CreateFrame("Frame",nil,parent); f:SetHeight(22)
    Card(f,f,4,{0.50,0.40,0.24,0.90},{0.055,0.055,0.065,0.96},"BACKGROUND",0)
    local ix=9
    if crest then
      local ic=f:CreateTexture(nil,"ARTWORK"); ic:SetSize(14,14); ic:SetPoint("LEFT",7,0)
      FLT.SetTex(ic, ASSET_ROOT.."faction_crests"); local tc=CHIP_CREST[crest] or CHIP_CREST.Both; ic:SetTexCoord(tc[1],tc[2],0,1)
      ix=25
    end
    local fs=FLT.NewFS(f,nil,"OVERLAY","GameFontHighlightSmall"); fs:SetPoint("LEFT",ix,0)
    function f:Set(t,c)
      fs:SetText(t or ""); local col=c or {0.92,0.90,0.84}; fs:SetTextColor(FLT.TextC(col[1],col[2],col[3]))
      f:SetWidth(ix+math.floor((fs:GetStringWidth() or 40)+0.5)+10)
    end
    f:Set(text,color)
    return f
  end
  -- places chips left to right; call again after a chip changed its width
  local function layoutChips(chips,x,y)
    for _,c in ipairs(chips) do c:ClearAllPoints(); c:SetPoint("TOPLEFT",x,y); x=x+(c:GetWidth() or 60)+6 end
  end
  local function infoRow(parent,y,label,text,valueW)
    local h=FLT.NewFS(parent,nil,"OVERLAY","GameFontNormalSmall"); h:SetPoint("TOPLEFT",10,y); h:SetWidth(86); h:SetJustifyH("LEFT"); h:SetText(L[label]); h:SetTextColor(FLT.TextC(1,0.82,0.20))
    local b=FLT.NewFS(parent,nil,"OVERLAY","GameFontHighlightSmall"); b:SetPoint("TOPLEFT",100,y); b:SetWidth(valueW or 330); b:SetJustifyH("LEFT"); b:SetText(text or L["Unknown"]); b:SetWordWrap(true)
    return y-math.max(16,b:GetStringHeight() or 16)-8, b
  end
  -- 6.2.7 (user 13.11.: "das muss alles gepflegt sein"): "Starts at" / "Turn in" with a Map button whenever the place is known;
  -- an NPC or drop inside the dungeon points to its entrance
  local function entranceLoc(d,text)
    if not (d and d.mapZone and d.mapX and d.mapY and type(text)=="string") then return nil end
    if not (text:find(" inside ",1,true) or text:find("dropped by ",1,true)) then return nil end
    return {zone=d.mapZone,x=d.mapX,y=d.mapY,label=string.format(L["%s entrance"],DN(d.name)),entrance=true}
  end
  local function placeRow(parent,y,label,text,loc)
    local yStart=y
    -- no text in our data but a known place (QuestieDB pin): its NPC and zone instead of "Unknown" (6.2.8, user screenshot 13.11.)
    local shown=text and PT(noCoords(text)) or (loc and not loc.entrance and loc.label) or L["Unknown"]
    local ny=infoRow(parent,y,label,shown,loc and 250 or 330)
    if loc then
      local b=UI.GoldButton(parent,L["Map"],62,20,ASSET_ROOT.."icon_map",11)
      b:SetPoint("TOPRIGHT",parent,"TOPLEFT",446,yStart+3)
      b:SetScript("OnClick",function() FLT:ShowOnMap(loc) end)
      b:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
        GameTooltip:SetText(L[label],1,0.82,0.20)
        if loc.entrance and text then GameTooltip:AddLine(PT(noCoords(text)),0.92,0.90,0.84,true) end
        GameTooltip:AddLine(loc.label or loc.name or "",0.92,0.90,0.84,true)
        GameTooltip:AddLine(L["Open the world map and mark this location with the golden OneForAll pin."],0.72,0.72,0.72,true)
        GameTooltip:Show()
      end)
      b:SetScript("OnLeave",function() GameTooltip:Hide() end)
    end
    return ny
  end
  local function who(text) return type(text)=="string" and text:match("^([^,]+),") or nil end
  -- start and turn-in place of a quest (or a key step): the text's coordinates, our checked starts, the pin data, the
  -- same NPC as the other end, else the dungeon entrance
  local function questPlaces(d,id,starts,turnin)
    local s=FLT.QuestLoc and FLT:QuestLoc(id,starts)
    if turnin=="" then turnin=nil end
    local e=FLT.QuestEndLoc and FLT:QuestEndLoc(id,turnin) or nil -- also without a text: the pin data (6.2.8)
    if turnin and who(turnin) and who(turnin)==who(starts) then e=e or s; s=s or e end
    return s or entranceLoc(d,starts), e or (turnin and entranceLoc(d,turnin)) or nil
  end
  -- framed box with a gold title; returns the box, the y where content starts
  -- and a function that closes the box at the given y (returns the next y)
  local function openBox(parent,y,title,width)
    local box=CreateFrame("Frame",nil,parent); box:SetPoint("TOPLEFT",8,y); box:SetWidth(width or 440)
    if box.SetFrameLevel and parent.GetFrameLevel then box:SetFrameLevel(parent:GetFrameLevel() or 1) end
    Card(box,box,5,{0.50,0.40,0.24,0.90},{0.050,0.048,0.055,0.92},"BACKGROUND",0)
    local t=FLT.NewFS(box,nil,"OVERLAY","GameFontNormal"); t:SetPoint("TOPLEFT",10,-7); t:SetText(L[title]); t:SetTextColor(FLT.TextC(1,0.82,0.20))
    local function close(endY) box:SetHeight(math.max(30,y-endY+6)); return endY-14 end
    return box,y-30,close
  end

  local function renderQuests(d)
    local allQuests=d.quests or {}
    local playerFaction=UnitFactionGroup("player")
    local filter=questFactionFilter[d.key] or playerFaction or "Alliance"
    if filter~="Alliance" and filter~="Horde" then filter="Alliance" end
    questFactionFilter[d.key]=filter

    -- quests of other classes are hidden unless the eye is open (6.2.4, user 10.11.: "quests die ich als priester gar nicht
    -- annehmen kann ... ausblenden"; a quest in the log always shows); the choice is kept per character
    local showAll=type(OneForAllCharDB)=="table" and OneForAllCharDB.dqShowAll or false
    local myClass=select(2,UnitClass("player"))
    local viewKey="quests:"..d.key..":"..filter..(showAll and ":all" or "")
    local view=showView(viewKey)
    if view then
      -- Quest states (completed / in log / level) can change while the view
      -- is cached, so re-evaluate them each time the view is shown.
      view.refresh()
      view.select(questSelection[d.key] or 1)
      return
    end
    view=newView(viewKey)

    local quests={}
    local hidden=0
    for _,q in ipairs(allQuests) do
      if q.side=="Both" or q.side=="Neutral" or q.side==filter then
        if showAll or not q.class or q.class==myClass or (q.id and C_QuestLog and C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(q.id)) then
          quests[#quests+1]=q
        else hidden=hidden+1 end
      end
    end
    local idx=questSelection[d.key] or 1; if idx>#quests then idx=1 end; if idx<1 then idx=1 end; questSelection[d.key]=idx

    local left=dynFrame("Frame"); left:SetPoint("TOPLEFT",0,0); left:SetPoint("BOTTOMLEFT",0,0); left:SetWidth(390)
    framedPanel(left,7)
    listBand(left)
    local lh=dynText(left,"GameFontNormalLarge"); lh:SetPoint("TOPLEFT",16,-14); lh:SetText(L["Quests"].." | "..#quests); lh:SetTextColor(FLT.TextC(1,0.82,0.20))
    local shareBtn
    -- "Share all Quests" right of the count (6.0.2, user 31.10.: own bent arrow, works anywhere in a group)
    do
      -- a button plate like the title bar buttons (bug, chat, close) with the share arrow (user 31.10.)
      -- 22 high and on the line of the faction buttons (6.2.4, user 10.11.: it sat higher than the others)
      local sh=UI.GoldButton(left,"",30,22,ASSET_ROOT.."icon_share",11); sh:SetPoint("TOPLEFT",left,"TOPLEFT",16+math.ceil(lh:GetStringWidth() or 90)+10,-10)
      shareBtn=sh
      sh.iconGap=0
      if sh.icon then sh.icon:ClearAllPoints(); sh.icon:SetSize(16,16); sh.icon:SetPoint("CENTER",0,0) end
      sh:SetScript("OnClick",function() if FLT.ShareAllQuests then FLT.ShareAllQuests(d) end end)
      sh:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:AddLine(L["Share all Quests"],1,0.82,0)
        local list,why
        if FLT.ShareAllPreview then list,why=FLT.ShareAllPreview(d) end
        if list then
          for _,c in ipairs(list) do GameTooltip:AddDoubleLine(NM(c.quest.name) or "?",table.concat(c.missing,", "),1,1,1,0.65,0.65,0.65) end
          GameTooltip:AddLine(L["Only quests your group members are missing and can take."],0.75,0.75,0.75,true)
        else
          GameTooltip:AddLine(why or "",1,1,1,true)
        end
        GameTooltip:Show()
      end)
      sh:SetScript("OnLeave",function() GameTooltip:Hide() end)
    end
    -- 80 wide (were 92), so the count, share and eye fit before them in every language (6.2.4)
    local allianceBtn=UI.GoldButton(left,L["Alliance"],80,22,nil,12); allianceBtn:SetPoint("TOPRIGHT",-98,-10)
    local hordeBtn=UI.GoldButton(left,L["Horde"],80,22,nil,12); hordeBtn:SetPoint("TOPRIGHT",-12,-10)
    do -- the eye: closed = quests of other classes hidden, open = all (Assets/eye.tga: open | closed)
      -- right of the share button (user 10.11.: with "16" quests the eye lay over it)
      local eye=UI.GoldButton(left,"",30,22,ASSET_ROOT.."eye",11); eye:SetPoint("LEFT",shareBtn,"RIGHT",6,0)
      eye.iconGap=0 -- no text: the plate centres the icon on every redraw (else it moved left after a click)
      if eye.icon then eye.icon:ClearAllPoints(); eye.icon:SetSize(18,18); eye.icon:SetPoint("CENTER",0,0); eye.icon:SetTexCoord(showAll and 0 or 0.5,showAll and 0.5 or 1,0,1) end
      eye:SetActive(showAll)
      eye:SetScript("OnClick",function()
        if type(OneForAllCharDB)=="table" then OneForAllCharDB.dqShowAll=not showAll or nil end
        questSelection[d.key]=1; GameTooltip:Hide(); renderQuests(d)
      end)
      eye:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
        GameTooltip:AddLine(showAll and L["Hide quests for other classes"] or L["Show all quests"],1,0.82,0)
        if hidden>0 then GameTooltip:AddLine(string.format(L["%d quests for other classes are hidden."],hidden),0.75,0.75,0.75,true) end
        GameTooltip:Show()
      end)
      eye:SetScript("OnLeave",function() GameTooltip:Hide() end)
    end
    allianceBtn:SetActive(filter=="Alliance"); hordeBtn:SetActive(filter=="Horde")
    allianceBtn:SetScript("OnClick",function() questFactionFilter[d.key]="Alliance"; questSelection[d.key]=1; renderQuests(d) end)
    hordeBtn:SetScript("OnClick",function() questFactionFilter[d.key]="Horde"; questSelection[d.key]=1; renderQuests(d) end)
    local legend=dynText(left,"GameFontDisableSmall"); legend:SetPoint("TOPLEFT",14,-48); legend:SetWidth(368); legend:SetJustifyH("LEFT"); legend:SetWordWrap(true); legend:SetText(string.format(L["Green = done   Half green = ready to turn in   Green text = in log   Teal = chain started   Dim = unavailable   %s + shared"],L[filter]))

    -- the list starts below the legend (2 lines in English; 3 in some languages since the teal line, 6.2.2)
    local listTop=math.max(78, 48+math.ceil(legend:GetStringHeight() or 26)+6)
    local qsf=dynFrame("ScrollFrame",left,"UIPanelScrollFrameTemplate"); qsf:SetPoint("TOPLEFT",10,-listTop); qsf:SetPoint("BOTTOMRIGHT",-3,8); tidyScroll(qsf,left)
    local qchild=dynFrame("Frame",qsf); qchild:SetSize(LAYOUT.QUEST_LIST_WIDTH,1); qsf:SetScrollChild(qchild)
    local qy=-2
    local rows={}
    for i,quest in ipairs(quests) do
      local row=dynFrame("Button",qchild); row:SetSize(LAYOUT.QUEST_ROW_WIDTH,40); row:SetPoint("TOPLEFT",0,qy); qy=qy-42
      local bg=cardBg(row,0.068,0.070,0.080,0.95); bg.plateOff=true
      local hi=makeTexture(row,"HIGHLIGHT",0.62,0.44,0.16,0.045); hi:SetPoint("TOPLEFT",1,-1); hi:SetPoint("BOTTOMRIGHT",-1,1)
      local qn=FLT.NewFS(row, nil,"OVERLAY","GameFontNormal")
      qn:SetWidth(295); qn:SetJustifyH("LEFT"); qn:SetWordWrap(false) -- one line (German titles ran into the meta line)
      qn:SetText(NM(quest.name))
      qn:SetPoint("TOPLEFT",12,-3)
      local meta=FLT.NewFS(row, nil,"OVERLAY","GameFontHighlightSmall"); meta:SetPoint("TOPLEFT",30,-21); meta:SetWidth(295); meta:SetJustifyH("LEFT")
      rows[i]={button=row,bg=bg,name=qn,meta=meta,quest=quest}
    end
    qchild:SetHeight(math.max(1,-qy+2))

    local function refreshRowStatus()
      for _,row in ipairs(rows) do
        local quest=row.quest
        local questStatus=getDungeonQuestStatus(d, quest)
        row.status=questStatus
        local req=quest.required or quest.level or "?"; local m=string.format(L["Req. %s"],tostring(req)).."  |  "..L[quest.side or "Both"]
        if quest.class then m=m.." / "..((type(LOCALIZED_CLASS_NAMES_MALE)=="table" and LOCALIZED_CLASS_NAMES_MALE[quest.class]) or quest.class) end -- the class name, not "PRIEST" (6.2.4)
        local stepIdx, stepTotal, stepInLog = getChainProgress(quest)
        m=m.."  |  "..((questStatus=="chain" and not stepInLog) and L["Chain started"] or L[QUEST_STATUS_LABELS[questStatus] or questStatus])
        if quest.id and FLT.QUEST_PREREQ_CHAINS and FLT.QUEST_PREREQ_CHAINS[quest.id] then
          if (questStatus=="inlog" or questStatus=="ready") and not stepIdx and stepTotal then stepIdx = stepTotal end
          m=m.."  |  "..(stepIdx and string.format(L["Chain %d/%d"],stepIdx,stepTotal) or L["Chain"])
        end
        row.meta:SetText(m)
      end
    end
    refreshRowStatus()

    local right=dynFrame("Frame"); right:SetPoint("TOPLEFT",405,0); right:SetPoint("BOTTOMRIGHT",0,0)
    framedPanel(right)
    detailBackdrop(right,d,0.45)
    if #quests==0 then
      local none=dynText(right,"GameFontDisable"); none:SetPoint("TOPLEFT",18,-18); none:SetWidth(460); none:SetJustifyH("LEFT")
      if #allQuests==0 then
        none:SetText(L[d.dataStatus=="partial" and N"No quests have been recorded for this new Forever dungeon yet." or N"No dungeon quests are recorded for this dungeon."])
      else
        none:SetText(string.format(L["No %s or shared quests are recorded for this dungeon. Switch the faction filter to see the other quests."],L[filter]))
      end
    end

    -- One cached detail pane per quest. pane.update() refreshes the parts that
    -- depend on live character state (status line, quest-chain progress).
    local detailPanes={}
    local host
    local function dframe(kind,parentFrame,template)
      return CreateFrame(kind,nil,parentFrame or host,template)
    end
    local function dtext(parentFrame,template)
      return FLT.NewFS(parentFrame, nil,"OVERLAY",template or "GameFontHighlight")
    end

    local function selectQuest(newIdx)
      if #quests==0 then return end
      if newIdx<1 then newIdx=1 elseif newIdx>#quests then newIdx=#quests end
      questSelection[d.key]=newIdx
      for i,row in ipairs(rows) do
        for _,o in ipairs(row.orn or {}) do o:SetShown(i==newIdx) end
        -- the name keeps its status colour when selected (6.1.6, Discord Stole Ton 06.11.: the yellow of the selected
        -- quest looked like a higher-level quest); the plate and the gold corners show the selection
        -- 6.1.9 (user 07.11.): completed = bright green on a light green row (no check mark any more), in the log =
        -- the darker green
        row.bg:SetFill(row.status == "completed" and 0.10 or nil, 0.34, 0.12, 0.42)
        row.bg:SetHalfFill(row.status == "ready" and 0.10 or nil, 0.34, 0.12, 0.42) -- ready: green to the middle
        -- 6.2.2 (user 08.11.): white = not taken, teal = chain started (an earlier step in the log), green text = the
        -- quest itself in the log; ready = green text + half green row, done = green text + green row
        if row.status == "chain" then
          row.bg:SetColorTexture(FLT.SkinC(0.068,0.070,0.080,0.95))
          row.name:SetTextColor(FLT.TextC(0.45,0.85,0.70))
        elseif row.status == "inlog" or row.status == "ready" or row.status == "completed" then
          row.bg:SetColorTexture(FLT.SkinC(0.068,0.070,0.080,0.95))
          row.name:SetTextColor(FLT.TextC(0.25,1,0.35))
        elseif row.status == "unavailable" or row.status == "missed" then
          row.bg:SetColorTexture(FLT.SkinC(0.07,0.06,0.05,0.72))
          row.name:SetTextColor(FLT.TextC(0.58,0.56,0.52))
        else
          row.bg:SetColorTexture(FLT.SkinC(0.068,0.070,0.080,0.95))
          row.name:SetTextColor(FLT.TextC(0.92,0.90,0.84))
        end
        if i==newIdx then row.bg:SetColorTexture(FLT.SkinC(0.22,0.155,0.055,0.98,true)) end
      end

      for i,pane in pairs(detailPanes) do if i~=newIdx then pane:Hide() end end
      if detailPanes[newIdx] then
        detailPanes[newIdx]:Show()
        detailPanes[newIdx].update()
        return
      end

      local q=quests[newIdx]
      if not q then return end
      host=CreateFrame("Frame",nil,right); host:SetAllPoints()
      host.items={}
      detailPanes[newIdx]=host
      local pane=host
      local chainRows={}

      local qn=dtext(host,"GameFontNormalLarge"); qn:SetPoint("TOPLEFT",18,-16); qn:SetWidth(475); qn:SetJustifyH("LEFT"); qn:SetText(NM(q.name)); qn:SetTextColor(FLT.TextC(1,0.82,0.20))
      -- chips: required level, faction, class, dungeon quest, status
      local chips={}
      chips[#chips+1]=makeChip(host,string.format(L["Req. %s"],tostring(q.required or q.level or "?")))
      chips[#chips+1]=makeChip(host,L[q.side or "Both"],nil,(q.side=="Alliance" or q.side=="Horde") and q.side or "Both")
      if q.class then chips[#chips+1]=makeChip(host,string.format(L["%s only"],(type(LOCALIZED_CLASS_NAMES_MALE)=="table" and LOCALIZED_CLASS_NAMES_MALE[q.class]) or (q.class:sub(1,1)..q.class:sub(2):lower())),{0.85,0.75,1.0}) end
      chips[#chips+1]=makeChip(host,L["Dungeon quest"])
      local statusChip=makeChip(host,"")
      chips[#chips+1]=statusChip
      layoutChips(chips,18,-44)
      local qdv=host:CreateTexture(nil,"ARTWORK"); FLT.SetTex(qdv, ASSET_ROOT.."divider_ornate"); qdv:SetPoint("TOPLEFT",14,-70); qdv:SetPoint("TOPRIGHT",-24,-70); qdv:SetHeight(18)

      local rsf=dframe("ScrollFrame",host,"UIPanelScrollFrameTemplate"); rsf:SetPoint("TOPLEFT",10,-92); rsf:SetPoint("BOTTOMRIGHT",-2,8); tidyScroll(rsf,right)
      local rchild=dframe("Frame",rsf); rchild:SetSize(LAYOUT.QUEST_DETAIL_CHILD_WIDTH,1); rsf:SetScrollChild(rchild)
      local ry=-4
      local statusValue
      do
        local sLoc,eLoc=questPlaces(d,q.id,q.starts,q.turnin)
        ry=placeRow(rchild,ry,N"Starts at",q.starts,sLoc)
        if (q.turnin and q.turnin~="") or eLoc then ry=placeRow(rchild,ry,N"Turn in",q.turnin~="" and q.turnin or nil,eLoc) end
      end
      ry=infoRow(rchild,ry,N"Dungeon",DN(d.name))
      ry,statusValue=infoRow(rchild,ry,N"Status","")
      -- why it is unavailable, under the status (6.2.6, user 11.11.); the pane is rebuilt when the reason changes
      local builtReason=getDungeonQuestStatus(d, q)=="unavailable" and unavailableText(q) or nil
      if builtReason then
        local rv; ry,rv=infoRow(rchild,ry,N"Reason",builtReason); rv:SetTextColor(FLT.TextC(0.80,0.74,0.62))
      end
      -- next to "In log": open the quest in the quest log (user 06.11.; chain quests have it per step below)
      local statusLog=questLogButton(rchild); statusLog:SetQuest(q.id,q.name)
      local chain=q.id and FLT.QUEST_PREREQ_CHAINS and FLT.QUEST_PREREQ_CHAINS[q.id]
      if q.prereq and q.prereq~="" and not (chain and #chain>0) then ry=infoRow(rchild,ry,N"Prerequisite",NM(q.prereq)) end
      local sdv=rchild:CreateTexture(nil,"ARTWORK"); FLT.SetTex(sdv, ASSET_ROOT.."divider_ornate"); sdv:SetPoint("TOPLEFT",4,ry+2); sdv:SetPoint("TOPRIGHT",rchild,"TOPLEFT",448,ry+2); sdv:SetHeight(14)
      ry=ry-16

      if q.objective then
        local box,cy,close=openBox(rchild,ry,N"Objective")
        local ob=FLT.NewFS(box,nil,"OVERLAY","GameFontHighlightSmall"); ob:SetPoint("TOPLEFT",10,-28); ob:SetWidth(420); ob:SetJustifyH("LEFT"); ob:SetText(NM(q.objective)); ob:SetWordWrap(true)
        ry=close(cy-math.max(14,ob:GetStringHeight() or 14))
      end

      if chain and #chain>0 then
        local box,cy,close=openBox(rchild,ry,N"Quest chain")
        ry=cy
        local steps={}
        local currentIncluded=false
        for _,step in ipairs(chain) do
          steps[#steps+1]=step
          if step.id==q.id then currentIncluded=true end
        end
        if not currentIncluded then steps[#steps+1]={id=q.id,name=q.name,current=true} end
        for ci,step in ipairs(steps) do
          local row=dframe("Button",rchild); row:SetSize(424,26); row:SetPoint("TOPLEFT",16,ry); ry=ry-28
          local isCurrent=step.id==q.id
          local bg=cardBg(row,0.055,0.067,0.080,0.82)
          local detail=step.id and FLT.QUEST_PREREQ_DETAILS and FLT.QUEST_PREREQ_DETAILS[step.id]
          local stepLoc=FLT.QuestLoc and FLT:QuestLoc(step.id,detail and detail.pickup or (isCurrent and q.starts) or nil)
          local nm=FLT.NewFS(row, nil,"OVERLAY","GameFontHighlightSmall"); nm:SetPoint("LEFT",8,0); nm:SetWidth(stepLoc and 214 or 280); nm:SetJustifyH("LEFT"); nm:SetText(tostring(ci)..".  "..(NM(step.name) or (L["Quest"].." "..tostring(step.id or "?"))))
          if stepLoc then
            local stepMapBtn=UI.GoldButton(row,L["Map"],54,18,ASSET_ROOT.."icon_map",11)
            stepMapBtn:SetPoint("RIGHT",-94,0)
            stepMapBtn:SetScript("OnClick",function() FLT:ShowOnMap(stepLoc) end)
            stepMapBtn:SetScript("OnEnter",function(self)
              GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
              GameTooltip:SetText(L["Quest start"],1,0.82,0.20)
              GameTooltip:AddLine(stepLoc.label or (NM(step.name) or L["Quest step"]),0.92,0.90,0.84,true)
              GameTooltip:AddLine(L["Open the world map and mark this pickup location with the golden OneForAll pin."],0.72,0.72,0.72,true)
              GameTooltip:Show()
            end)
            stepMapBtn:SetScript("OnLeave",function() GameTooltip:Hide() end)
          end
          local stp=FLT.NewFS(row, nil,"OVERLAY","GameFontDisableSmall"); stp:SetPoint("RIGHT",-8,0); stp:SetWidth(stepLoc and 82 or 110); stp:SetJustifyH("RIGHT")
          local stepLog=questLogButton(row); stepLog:SetPoint("RIGHT",stp,"RIGHT",-(stp:GetWidth()+4),0); stepLog:SetQuest(step.id,step.name)
          chainRows[#chainRows+1]={id=step.id,isCurrent=isCurrent,optional=step.optional,inside=(q.inside and q.inside==step.id) or false,bg=bg,name=nm,state=stp,logBtn=stepLog}
          row:SetScript("OnEnter",function(self)
            GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
            GameTooltip:SetText(NM(step.name) or (L["Quest"].." "..tostring(step.id or "?")),1,0.82,0.20)
            if detail then
              if detail.pickup then GameTooltip:AddLine(string.format(L["Start: %s"],PT(noCoords(detail.pickup))),0.92,0.90,0.84,true) end
              if detail.objective then GameTooltip:AddLine(NM(detail.objective),1,1,1,true) end
              if detail.turnin then GameTooltip:AddLine(string.format(L["Turn in: %s"],PT(noCoords(detail.turnin))),0.76,0.76,0.72,true) end
              if step.optional then GameTooltip:AddLine(L["Optional lead-in: not required to accept the quest."],0.62,0.60,0.56,true) end
            elseif isCurrent then
              GameTooltip:AddLine(q.objective and NM(q.objective) or L["The dungeon quest on this page"],0.92,0.90,0.84,true)
            end
            if stepLoc and stepLoc.label then GameTooltip:AddLine(string.format(L["Map: %s"],stepLoc.label),0.72,0.72,0.72,true) end
            GameTooltip:Show()
          end)
          row:SetScript("OnLeave",function() GameTooltip:Hide() end)
        end
        ry=close(ry+2)
      end

      if q.note then
        local box,cy,close=openBox(rchild,ry,N"Notes")
        local nt=FLT.NewFS(box,nil,"OVERLAY","GameFontHighlightSmall"); nt:SetPoint("TOPLEFT",10,-28); nt:SetWidth(420); nt:SetJustifyH("LEFT"); nt:SetText(L[q.note]); nt:SetWordWrap(true)
        ry=close(cy-math.max(14,nt:GetStringHeight() or 14))
      end

      local function rewardRows(list,label)
        for ri,rec in ipairs(list) do
          local reward=dframe("Button",rchild); reward:SetSize(424,48); reward:SetPoint("TOPLEFT",16,ry); ry=ry-50
          cardBg(reward,0.055,0.067,0.080,(ri%2==0) and 0.96 or 0.88)
          local rhi=makeTexture(reward,"HIGHLIGHT",0.22,0.34,0.46,0.20); rhi:SetAllPoints()
          local ric=reward:CreateTexture(nil,"ARTWORK"); ric:SetSize(32,32); ric:SetPoint("LEFT",9,0); FLT.SetTex(ric, dungeonItemIcon(rec))
          local rw=FLT.NewFS(reward, nil,"OVERLAY","GameFontHighlight"); rw:SetPoint(rec.slot and "TOPLEFT" or "LEFT",50,rec.slot and -7 or 0); rw:SetWidth(330); rw:SetJustifyH("LEFT"); rw:SetText(FLT.ItemName and FLT.ItemName(rec.id,rec.name) or rec.name)
          pane.items[#pane.items+1]={text=rw,icon=ric,rec=rec,r=0.92,g=0.90,b=0.84}
          if rec.slot then local sl=FLT.NewFS(reward, nil,"OVERLAY","GameFontDisableSmall"); sl:SetPoint("TOPLEFT",50,-27); sl:SetWidth(330); sl:SetJustifyH("LEFT"); sl:SetText(FLT.SlotText and FLT.SlotText(rec.slot) or rec.slot) end
          if rec.id and UI.WishStar then local st=UI.WishStar(reward); st:SetPoint("RIGHT",-12,0); st:SetItem(rec.id) end
          reward:SetScript("OnEnter",function(self) showLootTooltip(self,rec,label) end); reward:SetScript("OnLeave",function() GameTooltip:Hide() end)
          reward:RegisterForClicks("LeftButtonUp"); reward:SetScript("OnClick",function(_,button) handleDungeonItemClick(rec,button) end)
        end
      end
      do
        local rewards=q.rewards or {}
        local box,cy,close=openBox(rchild,ry,(q.rewardChoice and #rewards>1) and (L["Rewards"].."  |cff9d9d9d"..L["(choose one)"].."|r") or N"Rewards")
        ry=cy
        if #rewards==0 then
          local summary=FLT.NewFS(box,nil,"OVERLAY","GameFontHighlightSmall"); summary:SetPoint("TOPLEFT",10,-28); summary:SetWidth(420); summary:SetJustifyH("LEFT")
          summary:SetText(q.rewardSummary or L["No item reward is listed in the current beta data for this quest."]); summary:SetTextColor(FLT.TextC(0.80,0.78,0.72))
          ry=cy-math.max(14,summary:GetStringHeight() or 14)
        else
          rewardRows(rewards,N"Quest reward")
          if q.alsoRewards and #q.alsoRewards>0 then
            local al=dtext(rchild,"GameFontHighlightSmall"); al:SetPoint("TOPLEFT",18,ry-2); al:SetText(L["You will also receive:"]); al:SetTextColor(FLT.TextC(0.80,0.78,0.72)); ry=ry-20
            rewardRows(q.alsoRewards,N"Quest reward")
          end
          if q.rewardSummary then
            local sum=dtext(rchild,"GameFontHighlightSmall"); sum:SetPoint("TOPLEFT",18,ry-2); sum:SetWidth(420); sum:SetJustifyH("LEFT"); sum:SetText(q.rewardSummary); sum:SetTextColor(FLT.TextC(0.80,0.78,0.72)); ry=ry-20
          end
        end
        ry=close(ry)
      end
      if q.noteRewards and #q.noteRewards>0 then
        local box,cy,close=openBox(rchild,ry,N"Follow-up rewards")
        ry=cy; rewardRows(q.noteRewards,N"Follow-up quest reward"); ry=close(ry)
      end

      pane.update=function()
        local questStatus=getDungeonQuestStatus(d, q)
        local reason=questStatus=="unavailable" and unavailableText(q) or nil
        if reason~=builtReason then pane:Hide(); detailPanes[newIdx]=nil; if questSelection[d.key]==newIdx then selectQuest(newIdx) end; return end
        local stepIdx, stepTotal, stepInLog = getChainProgress(q)
        local statusLabel=(questStatus=="chain" and not stepInLog) and L["Chain started"] or L[QUEST_STATUS_LABELS[questStatus] or questStatus]
        local col=STATUS_COLOR[questStatus] or STATUS_COLOR.available
        statusChip:Set(statusLabel,col); layoutChips(chips,18,-44)

        if questStatus=="chain" and stepIdx then statusLabel=statusLabel.." - "..string.format(L["chain step %d of %d"],stepIdx,stepTotal) end
        statusValue:SetText(statusLabel); statusValue:SetTextColor(FLT.TextC(col[1],col[2],col[3]))
        local ownInLog=(questStatus=="inlog" or questStatus=="ready") and not stepIdx and getQuestLogInfo(q)
        statusLog:ClearAllPoints(); statusLog:SetPoint("LEFT",statusValue,"LEFT",(statusValue:GetStringWidth() or 40)+8,0)
        statusLog:SetShown(ownInLog and true or false)
        for _,cr in ipairs(chainRows) do
          local done=(cr.id and FLT:IsQuestDone(cr.id)) or false
          local inLog=(not done and cr.id and getQuestLogInfo({ id = cr.id })) or false
          -- done wins over "this page's quest" (user 07.11.: the last step stayed gold although done); the page's own
          -- quest keeps a brighter shade
          if cr.isCurrent and done then cr.bg:SetColorTexture(FLT.SkinC(0.05,0.24,0.08,0.95))
          elseif cr.isCurrent then cr.bg:SetColorTexture(FLT.SkinC(0.24,0.17,0.055,0.95))
          elseif done then cr.bg:SetColorTexture(FLT.SkinC(0.035,0.16,0.055,0.86))
          elseif inLog then cr.bg:SetColorTexture(FLT.SkinC(0.035,0.20,0.065,0.90))
          else cr.bg:SetColorTexture(FLT.SkinC(0.055,0.067,0.080,0.82)) end
          if cr.isCurrent and not done then cr.name:SetTextColor(FLT.TextC(1,0.82,0.20)) elseif done or inLog then cr.name:SetTextColor(FLT.TextC(0.35,1,0.45)) elseif cr.optional then cr.name:SetTextColor(FLT.TextC(0.62,0.60,0.56)) else cr.name:SetTextColor(FLT.TextC(0.90,0.88,0.82)) end
          local stateText = done and N"Done" or (inLog and N"In log" or (cr.optional and N"Optional" or N"Required"))
          -- q.inside (6.2.14, Discord 22.11.: The Drowned City): the step done in the dungeon is the "Dungeon quest", the listed
          -- quest only the turn-in with the rewards
          if (cr.inside or (cr.isCurrent and not q.inside)) and not done and not inLog then stateText = N"Dungeon quest" end
          cr.state:SetText(L[stateText])
          cr.logBtn:ClearAllPoints(); cr.logBtn:SetPoint("RIGHT",cr.state,"RIGHT",-((cr.state:GetStringWidth() or 30)+6),0)
          cr.logBtn:SetShown(inLog and true or false)
          if cr.isCurrent and not done then cr.state:SetTextColor(FLT.TextC(1,0.82,0.20)) elseif done or inLog then cr.state:SetTextColor(FLT.TextC(0.35,1,0.45)) else cr.state:SetTextColor(FLT.TextC(0.66,0.66,0.66)) end
        end
        refreshItemVisuals(pane.items)
      end
      rchild:SetHeight(math.max(1,-ry+8))
      pane.update()
    end

    for i,row in ipairs(rows) do row.button:SetScript("OnClick",function() selectQuest(i) end) end
    view.select=selectQuest
    view.refresh=refreshRowStatus
    selectQuest(idx)
  end


  -- Key tab: the keys a dungeon needs (or optional shortcut keys) and the
  -- steps to get them. Left: keys with their steps; right: step details.
  local keySelection={}
  local keyFactionFilter={}
  local function stepStatus(step)
    if step.quest then
      if FLT.IsQuestDone and FLT:IsQuestDone(step.quest) then return "completed" end
      local inLog,ready=getQuestLogInfo({id=step.quest,name=step.name})
      if inLog then return ready and "ready" or "inlog" end
    end
    return "open"
  end
  -- Map: the dungeon map (UI\DungeonMap.lua, data from Forever Simple World Map)
  local function renderMap(d)
    local viewKey="map:"..d.key
    local view=showView(viewKey)
    if view then if view.map then view.map.Refresh() end return end
    view=newView(viewKey)
    local m=UI.CreateDungeonMap(view); m:SetAllPoints()
    m:SetMap(FLT.DUNGEON_MAPS[d.name], d, function(i)
      bossSelection[d.key]=i; mode="bosses"; detail._render()
    end)
    view.map=m
  end

  function renderKey(d)
    local keys=dungeonKeys(d) or {}
    -- faction switch only when a key has faction specific steps
    local split=false
    for _,k in ipairs(keys) do for _,s in ipairs(k.steps or {}) do if s.faction then split=true end end end
    local faction=UnitFactionGroup and UnitFactionGroup("player") or nil
    if faction~="Alliance" and faction~="Horde" then faction=nil end
    if split then
      faction=keyFactionFilter[d.key] or faction or "Alliance"
      keyFactionFilter[d.key]=faction
    end
    local viewKey="key:"..d.key..":"..(faction or "-")
    local view=showView(viewKey)
    if view then view.refresh(); view.select(keySelection[d.key] or 1); return end
    view=newView(viewKey)

    local left=dynFrame("Frame"); left:SetPoint("TOPLEFT",0,0); left:SetPoint("BOTTOMLEFT",0,0); left:SetWidth(390)
    framedPanel(left,7)
    listBand(left)
    local lh=dynText(left,"GameFontNormalLarge"); lh:SetPoint("TOPLEFT",16,-14); lh:SetText(L[d.raid and N"Attunement" or N"Key"]); lh:SetTextColor(FLT.TextC(1,0.82,0.20))
    if split then
      local allianceBtn=UI.GoldButton(left,L["Alliance"],92,22,nil,12); allianceBtn:SetPoint("TOPRIGHT",-108,-10)
      local hordeBtn=UI.GoldButton(left,L["Horde"],92,22,nil,12); hordeBtn:SetPoint("TOPRIGHT",-12,-10)
      allianceBtn:SetActive(faction=="Alliance"); hordeBtn:SetActive(faction=="Horde")
      allianceBtn:SetScript("OnClick",function() keyFactionFilter[d.key]="Alliance"; keySelection[d.key]=1; renderKey(d) end)
      hordeBtn:SetScript("OnClick",function() keyFactionFilter[d.key]="Horde"; keySelection[d.key]=1; renderKey(d) end)
    end
    local legend=dynText(left,"GameFontDisableSmall"); legend:SetPoint("TOPLEFT",14,-48)
    legend:SetText(string.format(L["Steps for %s  |  green row = done, green text = in quest log"],faction and L[faction] or L["both factions"]))

    local ksf=dynFrame("ScrollFrame",left,"UIPanelScrollFrameTemplate"); ksf:SetPoint("TOPLEFT",10,-66); ksf:SetPoint("BOTTOMRIGHT",-3,8); tidyScroll(ksf,left)
    local kchild=dynFrame("Frame",ksf); kchild:SetSize(LAYOUT.QUEST_LIST_WIDTH,1); ksf:SetScrollChild(kchild)
    local ky=-2
    local entries={}   -- selectable rows: {key=k, step=s or nil}
    local keyRows={}
    for _,k in ipairs(keys) do
      -- key header row
      local row=dynFrame("Button",kchild); row:SetSize(LAYOUT.QUEST_ROW_WIDTH,44); row:SetPoint("TOPLEFT",0,ky); ky=ky-46
      local bg=cardBg(row,0.090,0.078,0.050,0.96)
      local ic=row:CreateTexture(nil,"ARTWORK"); ic:SetSize(30,30); ic:SetPoint("LEFT",8,0)
      FLT.SetTex(ic, dungeonItemIcon({id=k.item,name=k.name}))
      local nm=FLT.NewFS(row,nil,"OVERLAY","GameFontNormal"); nm:SetPoint("TOPLEFT",46,-6); nm:SetWidth(240); nm:SetJustifyH("LEFT"); nm:SetText(NM(k.name))
      local sub=FLT.NewFS(row,nil,"OVERLAY","GameFontHighlightSmall"); sub:SetPoint("TOPLEFT",46,-24); sub:SetWidth(240); sub:SetJustifyH("LEFT")
      local st=row:CreateTexture(nil,"OVERLAY"); st:SetSize(22,22); st:SetPoint("RIGHT",-12,0)
      keyRows[#keyRows+1]={sub=sub,st=st,key=k}
      entries[#entries+1]={button=row,bg=bg,name=nm,key=k}
      row:SetScript("OnEnter",function(self) H.tryShowItemTooltip(self,{id=k.item,name=k.name}) end)
      row:SetScript("OnLeave",function() GameTooltip:Hide() end)
      local n=0
      for _,step in ipairs(k.steps or {}) do
        if not step.faction or not faction or step.faction==faction then
          n=n+1
          local srow=dynFrame("Button",kchild); srow:SetSize(LAYOUT.QUEST_ROW_WIDTH-16,40); srow:SetPoint("TOPLEFT",16,ky); ky=ky-42
          local sbg=cardBg(srow,0.068,0.070,0.080,0.95); sbg.plateOff=true -- the quest list's look (6.2.4, user 10.11.)
          local hi=makeTexture(srow,"HIGHLIGHT",0.62,0.44,0.16,0.045); hi:SetPoint("TOPLEFT",1,-1); hi:SetPoint("BOTTOMRIGHT",-1,1)
          local num=FLT.NewFS(srow,nil,"OVERLAY","GameFontNormal"); num:SetPoint("TOPLEFT",8,-4); num:SetText(n..".")
          local sn=FLT.NewFS(srow,nil,"OVERLAY","GameFontNormal"); sn:SetPoint("TOPLEFT",30,-4); sn:SetWidth(280); sn:SetJustifyH("LEFT"); sn:SetText(NM(step.name))
          local sm=FLT.NewFS(srow,nil,"OVERLAY","GameFontHighlightSmall"); sm:SetPoint("TOPLEFT",30,-22); sm:SetWidth(280); sm:SetJustifyH("LEFT")
          entries[#entries+1]={button=srow,bg=sbg,name=sn,meta=sm,key=k,step=step}
        end
      end
      ky=ky-8
    end
    kchild:SetHeight(math.max(1,-ky+2))

    local function refresh()
      for _,r in ipairs(keyRows) do
        local have=hasKeyItem(r.key.item)
        FLT.SetTex(r.st, have and KEY_ICON_YES or KEY_ICON_NO)
        r.sub:SetText(L[r.key.required and N"Needed to enter" or N"Optional shortcut"].."  |  "..(have and ("|cff66f080"..L["You have it"].."|r") or ("|cffff5a4a"..L["Not in your bags"].."|r")))
      end
      for _,e in ipairs(entries) do
        if e.step then
          local s=stepStatus(e.step)
          e.status=s
          local m=e.step.quest and (e.step.level and string.format(L["Quest, level %s"],e.step.level) or L["Quest"]) or L["No quest"]
          if QUEST_STATUS_LABELS[s] then m=m.."  |  "..L[QUEST_STATUS_LABELS[s]] end
          e.meta:SetText(m)
        end
      end
    end
    refresh()

    local right=dynFrame("Frame"); right:SetPoint("TOPLEFT",405,0); right:SetPoint("BOTTOMRIGHT",0,0)
    framedPanel(right)
    detailBackdrop(right,d,0.45)
    local panes={}
    local function makePane(e)
      local host=dynFrame("Frame",right); host:SetPoint("TOPLEFT",0,0); host:SetPoint("BOTTOMRIGHT",0,0)
      local k=e.key
      local step=e.step
      local stepStatusRow
      local t=dynText(host,"GameFontNormalLarge"); t:SetPoint("TOPLEFT",18,-16); t:SetWidth(475); t:SetJustifyH("LEFT")
      t:SetText(NM(step and step.name or k.name)); t:SetTextColor(FLT.TextC(1,0.82,0.20))
      -- chips
      local chips={}
      local statusChip
      if step then
        if step.quest and step.requires then chips[#chips+1]=makeChip(host,string.format(L["Req. %s"],tostring(step.requires))) end
        if step.faction then chips[#chips+1]=makeChip(host,L[step.faction],nil,step.faction) end
        chips[#chips+1]=makeChip(host,L[step.quest and N"Quest" or N"No quest"])
        statusChip=makeChip(host,""); chips[#chips+1]=statusChip
      else
        chips[#chips+1]=makeChip(host,L[k.required and N"Needed to enter" or N"Optional shortcut"])
        statusChip=makeChip(host,""); chips[#chips+1]=statusChip
      end
      layoutChips(chips,18,-44)
      local dv=host:CreateTexture(nil,"ARTWORK"); FLT.SetTex(dv, ASSET_ROOT.."divider_ornate"); dv:SetPoint("TOPLEFT",14,-70); dv:SetPoint("TOPRIGHT",-24,-70); dv:SetHeight(18)

      local sf=dynFrame("ScrollFrame",host,"UIPanelScrollFrameTemplate"); sf:SetPoint("TOPLEFT",10,-92); sf:SetPoint("BOTTOMRIGHT",-2,8); tidyScroll(sf,right)
      local c=dynFrame("Frame",sf); c:SetSize(LAYOUT.QUEST_DETAIL_CHILD_WIDTH,1); sf:SetScrollChild(c)
      local y=-4
      if step then
        if step.pickup then
          local sLoc=step.map and {mapID=step.map.mapID,x=step.map.x,y=step.map.y,label=PT(noCoords(step.pickup))} or nil
          local s2,e2=questPlaces(d,step.quest,step.pickup,step.turnin)
          y=placeRow(c,y,N"Starts at",step.pickup,sLoc or s2)
          if step.turnin then y=placeRow(c,y,N"Turn in",step.turnin,e2) end
        elseif step.turnin then
          local _,e2=questPlaces(d,step.quest,nil,step.turnin)
          y=placeRow(c,y,N"Turn in",step.turnin,e2)
        end
        if step.loot then
          -- an item the step needs and where it lies, with its own Map button (6.2.4, user 10.11.: the Grimy Key in
          -- "Key to the City")
          local yStart=y
          y=infoRow(c,y,N"Loot",NM(step.loot.name)..": "..PT(step.loot.map and step.loot.place or noCoords(step.loot.place)),step.loot.map and 250 or 330)
          if step.loot.map then
            local lb=UI.GoldButton(c,L["Map"],62,20,ASSET_ROOT.."icon_map",11); lb:SetPoint("TOPRIGHT",c,"TOPLEFT",446,yStart+3)
            lb:SetScript("OnClick",function() FLT:ShowOnMap({mapID=step.loot.map.mapID,x=step.loot.map.x,y=step.loot.map.y,name=step.loot.name}) end)
          end
        end
        if step.level then y=infoRow(c,y,N"Quest level",tostring(step.level)) end
        if step.quest then
          -- status with the quest log scroll, like the dungeon quests (6.2.4, user 10.11.)
          local sv; y,sv=infoRow(c,y,N"Status","")
          local slog=questLogButton(c); slog:SetQuest(step.quest,step.name)
          stepStatusRow={value=sv,log=slog}
        end
        local sdv=c:CreateTexture(nil,"ARTWORK"); FLT.SetTex(sdv, ASSET_ROOT.."divider_ornate"); sdv:SetPoint("TOPLEFT",4,y+2); sdv:SetPoint("TOPRIGHT",c,"TOPLEFT",448,y+2); sdv:SetHeight(14)
        y=y-16
        if step.objective then
          local box,cy,close=openBox(c,y,N"Objective")
          local ob=FLT.NewFS(box,nil,"OVERLAY","GameFontHighlightSmall"); ob:SetPoint("TOPLEFT",10,-28); ob:SetWidth(420); ob:SetJustifyH("LEFT"); ob:SetText(NM(step.objective)); ob:SetWordWrap(true)
          y=close(cy-math.max(14,ob:GetStringHeight() or 14))
        end
      end
      -- key box: icon, name, whether you carry it, what it is for - only on the key's own page (6.2.4, user 10.11.:
      -- not on every step)
      local keyStatus
      if not step then
        local box,cy,close=openBox(c,y,d.raid and N"Attunement" or N"Key")
        local kic=box:CreateTexture(nil,"ARTWORK"); kic:SetSize(32,32); kic:SetPoint("TOPLEFT",10,-28)
        FLT.SetTex(kic, dungeonItemIcon({id=k.item,name=k.name}))
        local kn=FLT.NewFS(box,nil,"OVERLAY","GameFontHighlight"); kn:SetPoint("TOPLEFT",50,-29); kn:SetText(NM(k.name))
        keyStatus=FLT.NewFS(box,nil,"OVERLAY","GameFontHighlightSmall"); keyStatus:SetPoint("TOPLEFT",50,-47)
        local sum=FLT.NewFS(box,nil,"OVERLAY","GameFontHighlightSmall"); sum:SetPoint("TOPLEFT",10,-68); sum:SetWidth(420); sum:SetJustifyH("LEFT"); sum:SetText(k.summary or ""); sum:SetWordWrap(true)
        local hover=CreateFrame("Frame",nil,box); hover:SetPoint("TOPLEFT",8,-26); hover:SetSize(260,36)
        hover:SetScript("OnEnter",function(self) H.tryShowItemTooltip(self,{id=k.item,name=k.name}) end)
        hover:SetScript("OnLeave",function() GameTooltip:Hide() end)
        y=close(cy-38-math.max(14,sum:GetStringHeight() or 14))
      end
      if not step then
        local hint=dynText(c,"GameFontDisableSmall"); hint:SetPoint("TOPLEFT",10,y); hint:SetWidth(430); hint:SetJustifyH("LEFT")
        hint:SetText(L["Pick a step on the left for its details and map position."])
        y=y-20
      end
      c:SetHeight(math.max(1,-y+8))
      local pane={host=host}
      function pane.update()
        local have=hasKeyItem(k.item)
        if keyStatus then keyStatus:SetText(have and ("|cff66f080"..L["You have it"].."|r") or ("|cffff5a4a"..L["Not in your bags"].."|r")) end
        if step then
          local st=stepStatus(step)
          local label=L[QUEST_STATUS_LABELS[st] or N"Open"]
          local col=STATUS_COLOR[st] or STATUS_COLOR.open
          statusChip:Set(label,col)
          if stepStatusRow then
            local sv=stepStatusRow.value
            sv:SetText(label); sv:SetTextColor(FLT.TextC(col[1],col[2],col[3]))
            stepStatusRow.log:ClearAllPoints(); stepStatusRow.log:SetPoint("LEFT",sv,"LEFT",(sv:GetStringWidth() or 40)+8,0)
            stepStatusRow.log:SetShown(st=="inlog" or st=="ready")
          end
        else
          statusChip:Set(L[have and N"You have it" or N"Missing"],have and STATUS_COLOR.completed or {1,0.36,0.30})
        end
        layoutChips(chips,18,-44)
      end
      return pane
    end
    local function select(i)
      if #entries==0 then return end
      if i<1 or i>#entries then i=1 end
      keySelection[d.key]=i
      for j,e in ipairs(entries) do
        local on=(j==i)
        if e.step then
          -- the steps look like the dungeon quest list (6.2.4, user 10.11.: "genau so wie bei quests"): done = green
          -- row, ready = green to the middle, in the log = green text; the selection is the gold frame
          local s=e.status
          e.bg:SetFill(s=="completed" and 0.10 or nil,0.34,0.12,0.42)
          e.bg:SetHalfFill(s=="ready" and 0.10 or nil,0.34,0.12,0.42)
          e.bg:SetColorTexture(FLT.SkinC(0.068,0.070,0.080,0.95))
          if s=="completed" or s=="inlog" or s=="ready" then e.name:SetTextColor(FLT.TextC(0.25,1,0.35))
          else e.name:SetTextColor(FLT.TextC(0.92,0.90,0.84)) end
          if on then e.bg:SetColorTexture(FLT.SkinC(0.22,0.155,0.055,0.98,true)) end
        elseif on then e.bg:SetColorTexture(FLT.SkinC(0.22,0.155,0.055,0.98,true))
        else e.bg:SetColorTexture(FLT.SkinC(0.090,0.078,0.050,0.96)) end
      end
      for _,p in pairs(panes) do p.host:Hide() end
      local p=panes[i]; if not p then p=makePane(entries[i]); panes[i]=p end
      p.host:Show(); p.update()
    end
    for i,e in ipairs(entries) do
      local old=e.button:GetScript("OnClick")
      e.button:SetScript("OnClick",function() select(i) end)
    end
    view.refresh=function() refresh(); for _,p in pairs(panes) do p.update() end end
    view.select=select
    select(keySelection[d.key] or 1)
  end

  detail._render=function()
    local d=selectedDungeon; if not d then return end
    dtitle:SetText(DN(d.name))
    local ap=dungeonBackdrop(d.key,"hdr")
    if FLT.DUNGEON_LOADSCREENS and FLT.DUNGEON_LOADSCREENS[d.key] and setLoadscreen(detailArt,d.key,300,54) then
      -- loading screen: fades out to the right like the "_hdr" picture, so the title stays readable
      if not detailArt._ofaFade then detailArt._ofaFade=alphaFade(detailArt,"HORIZONTAL",1,0) end
      detailArt:Show(); detailArtFrame:Show()
    elseif ap then
      if detailArt._ofaFade then alphaFade(detailArt,"HORIZONTAL",1,1); detailArt._ofaFade=nil end
      FLT.SetTex(detailArt, ap); detailArt:SetTexCoord(0,1,0,1); detailArt:Show(); detailArtFrame:Show()
    else
      detailArt:Hide(); detailArtFrame:Hide()
    end
    local sideName=d.territory or d.side or "Contested"
    local ctc=({Alliance={0,0.25},Horde={0.25,0.5}})[sideName] or {0.5,0.75}
    dcrest:SetTexCoord(ctc[1],ctc[2],0,1)
    dcrest:SetShown(not d.raid)
    local sr,sg,sb=dungeonSideColor(d.territory or d.side)
    local zoneText=(FLT.ZoneName and FLT.ZoneName(d.mapZone or d.area) or d.mapZone or d.area or L["Unknown"])
    -- only level and faction are coloured; zone and separators stay neutral
    local function hex(r,g,b) return string.format("%02x%02x%02x",math.floor(r*255),math.floor(g*255),math.floor(b*255)) end
    local lr,lg,lb=levelColor(d)
    local sep="  |cff8a7a5a|||r  "
    if d.raid then
      local rr,rg,rb=raidColor(d.size)
      dmeta:SetText("|cff"..hex(lr,lg,lb)..string.format(L["LV %s"],tostring(d.level)).."|r"..sep.."|cff"..hex(rr,rg,rb)..string.format(L["%s players"],tostring(d.size or "?")).."|r"..sep.."|cffd9d4c7"..zoneText.."|r"..(d.raidStatus and (sep.."|cff66f080"..d.raidStatus.."|r") or ""))
    else
      dmeta:SetText("|cff"..hex(lr,lg,lb)..string.format(L["LV %s"],tostring(d.level)).."|r"..sep.."|cffd9d4c7"..zoneText.."|r"..sep.."|cff"..hex(sr,sg,sb)..L[sideName].."|r"..(d.betaNew and (sep.."|cff66f080"..L["New in Forever"].."|r") or ""))
    end
    back:SetLabel(L[d.raid and N"Raids" or N"Dungeons"])
    keyBtn:SetLabel(L[d.raid and N"Attunement" or N"Key"])
    dmeta:SetTextColor(FLT.TextC(0.85,0.83,0.78))
    local hasKeys=dungeonKeys(d)~=nil
    if not hasKeys and mode=="key" then mode="bosses" end
    keyBtn:SetShown(hasKeys)
    questsBtn:ClearAllPoints(); bossesBtn:ClearAllPoints()
    questsBtn:SetPoint("RIGHT",hasKeys and -132 or -14,0); bossesBtn:SetPoint("RIGHT",hasKeys and -260 or -142,0)
    local hasMap=FLT.DUNGEON_MAPS and FLT.DUNGEON_MAPS[d.name] and UI.CreateDungeonMap and true or false
    if not hasMap and mode=="map" then mode="bosses" end
    mapBtn:SetShown(hasMap)
    if mode=="quests" then renderQuests(d) elseif mode=="key" then renderKey(d) elseif mode=="map" then renderMap(d) else renderBosses(d) end
    questsBtn:SetActive(mode=="quests"); bossesBtn:SetActive(mode=="bosses"); keyBtn:SetActive(mode=="key"); mapBtn:SetActive(mode=="map")
  end
  -- Re-render (cheap: views are cached) whenever the detail page becomes
  -- visible again, so quest states are current after reopening the window.
  detail:SetScript("OnShow",function() if detail._render then detail._render() end end)
  bossesBtn:SetScript("OnClick",function() mode="bosses"; detail._render() end)
  questsBtn:SetScript("OnClick",function() mode="quests"; detail._render() end)
  keyBtn:SetScript("OnClick",function() mode="key"; detail._render() end)
  mapBtn:SetScript("OnClick",function() mode="map"; detail._render() end)

  -- Opens a dungeon's detail page directly (used when the window is opened
  -- inside that dungeon, and by the Armory's "Show" buttons).
  -- bossName (optional): select that boss ("trash mobs" = the trash loot entry).
  -- openMode (optional): "map" opens the dungeon map.
  -- questID (6.2.2, Gear Planner, user 09.11.): open the Quests view on that quest, in your faction's list
  UI.SelectedDungeon=function() return selectedDungeon end -- FLT.DungeonToOpen (QuestShare.lua)
  UI.OpenDungeon=function(target, bossName, openMode, questID)
    if not target then return end
    selectedDungeon=target; mode=openMode or "bosses"; browse:Hide(); detail:Show()
    if questID then
      local f=UnitFactionGroup and UnitFactionGroup("player"); if f~="Alliance" and f~="Horde" then f="Alliance" end
      questFactionFilter[target.key]=f
      local n=0
      for _,q in ipairs(target.quests or {}) do
        if q.side=="Both" or q.side=="Neutral" or q.side==f then n=n+1; if q.id==questID then questSelection[target.key]=n end end
      end
    end
    bossSelection[target.key]=bossSelection[target.key] or 1
    if bossName then
      local bosses=target.bosses or {}
      if bossName=="trash mobs" and #(target.trashLoot or {})>0 then bossSelection[target.key]=#bosses+1 end
      for i,b in ipairs(bosses) do if b.name==bossName then bossSelection[target.key]=i end end
    end
    questSelection[target.key]=questSelection[target.key] or 1
    if detail._render then detail._render() end
  end
  panel:Hide(); return panel
end


UI.RegisterPanel({ key="dungeons", label=N"Dungeons & Raids", order=2, tabWidth=160, create=createDungeonPanel })
