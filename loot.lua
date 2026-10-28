-- Rare loot panel: map pins of elites, rares and bosses show the mob's rank,
-- and Alt-Click opens a panel with what it drops, with drop chances. Ported
-- from the pfQuest-octo pack's pfQuest-lootpanel.lua and pfQuest-rareinfo.lua
-- (Shadowtoots' modules for pfQuest-turtle).
--
-- Changes from those: the item categories are read from ClassicAPI's class
-- IDs rather than English type names, items the client hasn't seen are asked
-- for so their icons fill in, a mob's drop list is kept for the session
-- instead of rebuilt every time the map opens, and only world map pins offer
-- the panel (it lives on the world map, so a minimap pin had nowhere to show it).

local QoL = pfQuestOctoQoL
if not QoL.enabled then return end

local GRID_COLUMNS = 6
local ICON_SIZE = 26
local ICON_PADDING = 6
local PANEL_MARGIN = 8
local MAX_ICONS = 18
local MIN_CONTENT_WIDTH = 120
local FALLBACK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
-- items or loot pools more mobs than this drop count as world drops
local WORLD_DROP_THRESHOLD = 200

-- ItemClass.dbc IDs
local CLASS_WEAPON, CLASS_ARMOR, CLASS_RECIPE, CLASS_QUEST = 2, 4, 9, 12

local RANK_INFO = {
  ["1"] = { text = "Elite",      r = 1, g = 0.5,  b = 0 },
  ["2"] = { text = "Rare Elite", r = 1, g = 0.42, b = 0.71 },
  ["3"] = { text = "Boss",       r = 1, g = 0,    b = 0 },
  ["4"] = { text = "Rare",       r = 1, g = 1,    b = 0 },
}

-- slash command name -> setting, label, default
local OPTIONS = {
  { "pooled",     "lootPanelShowReference",     "Include pooled loot", "1" },
  { "unknown",    "lootPanelShowUnknownChance", "Include unknown loot", "0" },
  { "worlddrops", "lootPanelHideWorldDrops",    "Hide World-Drop Items (200+ sources)", "0" },
  { "equip",      "lootPanelShowEquip",         "Show Armor/Weapons", "1" },
  { "quest",      "lootPanelShowQuestItems",    "Show Quest Items", "1" },
  { "starters",   "lootPanelShowQuestStarters", "Show Quest Starters", "1" },
  { "recipes",    "lootPanelShowRecipes",       "Show Recipes", "1" },
  { "grey",       "lootPanelShowGrey",          "Show Grey Items", "1" },
  { "white",      "lootPanelShowWhite",         "Show White Items", "1" },
}

do
  local entries = { { text = "|cff33ffccRare Loot Panel|r", type = "header" } }
  local defaults = {}
  for _, o in ipairs(OPTIONS) do
    table.insert(entries, { text = o[3], default = o[4], type = "checkbox", config = o[2] })
    defaults[o[2]] = o[4]
  end
  QoL.AddConfig(entries)
  QoL.SetDefaults(defaults)
end

local function Setting(key)
  return pfQuest_config and pfQuest_config[key] == "1"
end

local function UnitRank(unitid)
  local unit = unitid and pfDB["units"]["data"][unitid]
  return unit and unit["rnk"] and RANK_INFO[tostring(unit["rnk"])]
end

local function CountEntries(t)
  local n = 0
  for _ in pairs(t) do n = n + 1 end
  return n
end

-- unit id -> list of { item, chance, isRef, sourceCount }, highest chance
-- first. The database doesn't change, so a list is built once per session.
local dropsCache = {}

local function DropsForUnit(unitid)
  if dropsCache[unitid] then return dropsCache[unitid] end

  local refloot = pfDB["refloot"] and pfDB["refloot"]["data"] or {}
  local list = {}
  for itemid, item in pairs(pfDB["items"]["data"]) do
    if item["U"] and item["U"][unitid] then
      table.insert(list, { item = itemid, chance = item["U"][unitid] or 0, sourceCount = CountEntries(item["U"]) })
    elseif item["R"] then
      for ref, chance in pairs(item["R"]) do
        local units = refloot[ref] and refloot[ref]["U"]
        if units and units[unitid] then
          table.insert(list, { item = itemid, chance = chance or 0, isRef = true, sourceCount = CountEntries(units) })
          break
        end
      end
    end
  end

  table.sort(list, function(a, b) return a.chance > b.chance end)
  dropsCache[unitid] = list
  return list
end

local questStarters

local function IsQuestStarter(itemid)
  if not questStarters then
    questStarters = {}
    for _, quest in pairs(pfDB["quests"]["data"]) do
      for _, starter in pairs(quest["start"] and quest["start"]["I"] or {}) do
        questStarters[starter] = true
      end
    end
  end
  return questStarters[itemid]
end

-- ClassicAPI's class ID, or one from the English type name on an older ClassicAPI
local TYPE_CLASS = { Weapon = CLASS_WEAPON, Armor = CLASS_ARMOR, Recipe = CLASS_RECIPE, Quest = CLASS_QUEST }

local function ItemClass(itemid)
  if C_Item and C_Item.GetItemInfoInstant then
    local _, _, _, _, _, classID = C_Item.GetItemInfoInstant(itemid)
    return classID
  end
  local _, _, _, _, itemType = GetItemInfo(itemid)
  return itemType and TYPE_CLASS[itemType]
end

local function ItemIcon(itemid)
  if GetItemIcon then return GetItemIcon(itemid) end
  local _, _, _, _, _, _, _, _, texture = GetItemInfo(itemid)
  return texture
end

local function RequestItem(itemid)
  if C_Item and C_Item.RequestLoadItemDataByID then
    C_Item.RequestLoadItemDataByID(itemid)
  end
end

-- items the client hasn't cached have no class or quality yet and are shown
local function PassesCategoryFilters(itemid)
  local classID = ItemClass(itemid)
  local _, _, quality = GetItemInfo(itemid)

  if classID == CLASS_WEAPON or classID == CLASS_ARMOR then return Setting("lootPanelShowEquip") end
  if IsQuestStarter(itemid) then return Setting("lootPanelShowQuestStarters") end
  if classID == CLASS_QUEST then return Setting("lootPanelShowQuestItems") end
  if classID == CLASS_RECIPE then return Setting("lootPanelShowRecipes") end
  if quality == 0 then return Setting("lootPanelShowGrey") end
  if quality == 1 then return Setting("lootPanelShowWhite") end
  return true
end

local function VisibleDrops(unitid)
  local visible = {}
  for _, drop in ipairs(DropsForUnit(unitid)) do
    if (Setting("lootPanelShowReference") or not drop.isRef)
      and (Setting("lootPanelShowUnknownChance") or drop.chance > 0)
      and not (Setting("lootPanelHideWorldDrops") and drop.sourceCount > WORLD_DROP_THRESHOLD)
      and PassesCategoryFilters(drop.item)
    then
      table.insert(visible, drop)
    end
  end
  return visible
end

local function FormatChance(chance)
  if chance <= 0 or chance >= 1 then
    return string.format("%.0f%%", chance)
  end
  local oneDecimal = string.format("%.1f%%", chance)
  if oneDecimal == "0.0%" then
    return string.format("%.2f%%", chance)
  end
  return oneDecimal
end

local panel = CreateFrame("Frame", "pfQuestOctoLootPanel", WorldMapFrame)
-- one strata below TOOLTIP (but above DIALOG, which pfUI's map skin uses
-- heavily) so GameTooltip renders above this panel
panel:SetFrameStrata("FULLSCREEN_DIALOG")
panel:SetFrameLevel(200)
panel:SetClampedToScreen(true)
panel:Hide()
panel:SetMovable(true)
panel:EnableMouse(true)
panel:RegisterForDrag("LeftButton")
panel:SetScript("OnDragStart", function() this:StartMoving() end)
panel:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
panel:SetBackdrop({
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 16, edgeSize = 16,
  insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
panel:SetBackdropColor(0, 0, 0, 0.9)
panel:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)

local pinnedUnit

local function HidePanel()
  pinnedUnit = nil
  panel:Hide()
end

local closeButton = CreateFrame("Button", nil, panel)
closeButton:SetWidth(14)
closeButton:SetHeight(14)
closeButton:SetPoint("TOPRIGHT", -3, -3)
closeButton:SetFrameLevel(panel:GetFrameLevel() + 10)
closeButton.text = closeButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
closeButton.text:SetPoint("CENTER")
closeButton.text:SetText("x")
closeButton.text:SetTextColor(0.8, 0.3, 0.3)
closeButton:SetScript("OnEnter", function() closeButton.text:SetTextColor(1, 1, 1) end)
closeButton:SetScript("OnLeave", function() closeButton.text:SetTextColor(0.8, 0.3, 0.3) end)
closeButton:SetScript("OnClick", HidePanel)

panel.header = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
panel.header:SetPoint("TOPLEFT", panel, "TOPLEFT", PANEL_MARGIN, -PANEL_MARGIN)
panel.header:SetJustifyH("LEFT")

panel.noItems = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
panel.noItems:SetJustifyH("LEFT")
panel.noItems:SetText("No items linked to this NPC")
panel.noItems:Hide()

local buttons = {}

local function GetButton(index)
  if buttons[index] then return buttons[index] end

  local button = CreateFrame("Button", nil, panel)
  button:SetWidth(ICON_SIZE)
  button:SetHeight(ICON_SIZE)

  button.border = button:CreateTexture(nil, "BACKGROUND")
  button.border:SetPoint("TOPLEFT", -1, 1)
  button.border:SetPoint("BOTTOMRIGHT", 1, -1)
  button.border:SetTexture(1, 1, 1, 1)

  button.icon = button:CreateTexture(nil, "ARTWORK")
  button.icon:SetAllPoints(button)

  button.chanceText = button:CreateFontString(nil, "OVERLAY")
  button.chanceText:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
  button.chanceText:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 1, -1)
  button.chanceText:SetTextColor(1, 1, 0)

  button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

  button:SetScript("OnEnter", function()
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    local name, link = GetItemInfo(button.itemid)
    if not (link and pcall(GameTooltip.SetHyperlink, GameTooltip, link)) then
      GameTooltip:SetText(name or QoL.Loc("items", button.itemid) or ("Item #" .. button.itemid), 1, 1, 1)
      if not name then
        GameTooltip:AddLine("Item data unavailable", 0.6, 0.6, 0.6)
      end
    end
    if button.chance > 0 then
      GameTooltip:AddLine("Drop chance: " .. FormatChance(button.chance), 0.6, 0.9, 1)
    end
    GameTooltip:SetFrameLevel(panel:GetFrameLevel() + 10)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function() GameTooltip:Hide() end)

  buttons[index] = button
  return button
end

-- icon and quality border; false while the client doesn't know the item yet
local function ApplyItemVisuals(button)
  local _, _, quality = GetItemInfo(button.itemid)
  button.icon:SetTexture(ItemIcon(button.itemid) or FALLBACK_ICON)
  local c = quality and ITEM_QUALITY_COLORS[quality]
  if c then
    button.border:SetVertexColor(c.r, c.g, c.b, 1)
    return true
  end
  button.border:SetVertexColor(0.4, 0.4, 0.4, 1)
  return false
end

-- returns the grid's height, or nil when nothing is shown
local function PopulateGrid(drops, topOffset)
  local count = math.min(table.getn(drops), MAX_ICONS)

  for i = 1, count do
    local drop, button = drops[i], GetButton(i)
    button.itemid, button.chance = drop.item, drop.chance

    if drop.chance > 0 then
      local text = FormatChance(drop.chance)
      button.chanceText:SetText(text)
      button.chanceText:SetFont("Fonts\\FRIZQT__.TTF", string.len(text) >= 5 and 7 or 9, "OUTLINE")
      button.chanceText:Show()
    else
      button.chanceText:Hide()
    end

    button.pending = not ApplyItemVisuals(button)
    if button.pending then
      RequestItem(drop.item)
    end

    local col, row = math.mod(i - 1, GRID_COLUMNS), floor((i - 1) / GRID_COLUMNS)
    button:ClearAllPoints()
    button:SetPoint("TOPLEFT", panel, "TOPLEFT",
      PANEL_MARGIN + col * (ICON_SIZE + ICON_PADDING), -topOffset - row * (ICON_SIZE + ICON_PADDING))
    button:SetFrameLevel(panel:GetFrameLevel() + 1)
    button:Show()
  end

  for i = count + 1, table.getn(buttons) do
    buttons[i]:Hide()
  end

  if count == 0 then return nil end
  local rows = math.ceil(count / GRID_COLUMNS)
  return rows * ICON_SIZE + (rows - 1) * ICON_PADDING
end

local function ShowPanel(node)
  local unitid = node.spawnid
  if pinnedUnit == unitid and panel:IsShown() then
    HidePanel()
    return
  end

  local rank = UnitRank(unitid)
  local drops = VisibleDrops(unitid)
  local columns = math.min(math.min(table.getn(drops), MAX_ICONS), GRID_COLUMNS)
  local contentWidth = math.max(columns * ICON_SIZE + math.max(columns - 1, 0) * ICON_PADDING, MIN_CONTENT_WIDTH)

  panel.header:SetWidth(contentWidth)
  panel.header:SetText(table.concat({
    "|cff4dffcc" .. (node.spawn or UNKNOWN) .. "|r",
    pfQuest_Loc["Level"] .. ": " .. (node.level or UNKNOWN),
    pfQuest_Loc["Type"] .. ": " .. (node.spawntype or UNKNOWN),
    string.format("Rank: |cff%02x%02x%02x%s|r", floor(rank.r * 255), floor(rank.g * 255), floor(rank.b * 255), rank.text),
    pfQuest_Loc["Respawn"] .. ": " .. (node.respawn or UNKNOWN),
  }, "\n"))

  local headerHeight = panel.header:GetHeight() + 10
  local gridHeight = PopulateGrid(drops, headerHeight)
  if not gridHeight then
    panel.noItems:ClearAllPoints()
    panel.noItems:SetPoint("TOPLEFT", panel, "TOPLEFT", PANEL_MARGIN, -headerHeight)
    panel.noItems:SetWidth(contentWidth)
    panel.noItems:Show()
    gridHeight = panel.noItems:GetHeight()
  else
    panel.noItems:Hide()
  end

  pinnedUnit = unitid
  panel:SetWidth(contentWidth + PANEL_MARGIN * 2)
  panel:SetHeight(headerHeight + PANEL_MARGIN + gridHeight)
  panel:ClearAllPoints()
  panel:SetPoint("TOPLEFT", node, "BOTTOMLEFT", 0, -6)
  panel:Show()
end

-- fill in icons and borders as the server answers for uncached items
panel:SetScript("OnUpdate", function()
  this.elapsed = (this.elapsed or 0) + arg1
  if this.elapsed < 0.5 then return end
  this.elapsed = 0
  for _, button in ipairs(buttons) do
    if button.pending and button:IsShown() then
      button.pending = not ApplyItemVisuals(button)
    end
  end
end)

local mapWatcher = CreateFrame("Frame")
mapWatcher:RegisterEvent("WORLD_MAP_UPDATE")
mapWatcher:SetScript("OnEvent", HidePanel)
WorldMapFrame:HookScript("OnHide", HidePanel)

local function IsWorldMapPin(node)
  return node:GetParent() == WorldMapButton
end

-- Append to pfQuest's pin tooltip rather than copying it, so changes to
-- pfQuest's tooltip carry through. pfQuest gives each pin pfMap.NodeEnter
-- when it builds the pin, which happens after this loads.
local NodeEnter = pfMap.NodeEnter
pfMap.NodeEnter = function()
  NodeEnter()

  local rank = UnitRank(this.spawnid)
  if not rank then return end

  local tooltip = IsWorldMapPin(this) and WorldMapTooltip or GameTooltip
  tooltip:AddDoubleLine((pfQuest_Loc["Rank"] or "Rank") .. ":", rank.text, 0.8, 0.8, 0.8, rank.r, rank.g, rank.b)
  if IsWorldMapPin(this) and table.getn(VisibleDrops(this.spawnid)) > 0 then
    tooltip:AddLine("Alt-Click To Show Item Drops", 0.6, 0.6, 0.6)
  end
  -- pfQuest only calls Show() when its tooltip help is on, and the frame
  -- needs it to size to the lines above
  tooltip:Show()
end

-- pfQuest sets OnClick from pfMap.NodeClick each time it updates a pin. It
-- doesn't use Alt, so Alt-Click on a ranked mob is ours.
local NodeClick = pfMap.NodeClick
pfMap.NodeClick = function()
  if IsAltKeyDown() and IsWorldMapPin(this) and UnitRank(this.spawnid) then
    ShowPanel(this)
    return
  end
  NodeClick()
end

SLASH_PFQUESTOCTOLOOT1 = "/pfqloot"
SlashCmdList["PFQUESTOCTOLOOT"] = function(msg)
  local _, _, cmd, state = string.find(string.lower(msg or ""), "^(%S*)%s*(%S*)")
  for _, o in ipairs(OPTIONS) do
    if cmd == o[1] and (state == "on" or state == "off") then
      pfQuest_config[o[2]] = state == "on" and "1" or "0"
      QoL.Print(o[3] .. ": " .. state .. ".")
      return
    end
  end

  QoL.Print("Rare loot panel: Alt-Click an elite, rare or boss pin on the world map.")
  for _, o in ipairs(OPTIONS) do
    DEFAULT_CHAT_FRAME:AddMessage(string.format("  /pfqloot %s on | off  - %s (%s)", o[1], o[3], Setting(o[2]) and "on" or "off"))
  end
end
