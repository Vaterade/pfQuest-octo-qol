-- Continent pins: pfQuest's pins on the continent and world maps, which it
-- only draws on zone maps. Ported from the pfQuest-octo pack's
-- pfQuest-worldmap.lua (Shadowtoots' module for pfQuest-turtle).
--
-- That version placed pins with hand-written world boundaries for the 47
-- original zones, so no Turtle zone showed; drew its own copies of
-- pfQuest's pins; resized every world map pin, zone maps included, to the
-- continent size; and redrew everything every 0.15 seconds while the map was
-- open. This one reads where each zone sits on its continent from ClassicAPI,
-- builds and styles the pins with pfQuest's own functions, and redraws when
-- the map or the pins change. Its four quest filter settings (chickens,
-- Felwood flowers, PvP, cloth donations) were never applied by that pack, so
-- they are left out.

local QoL = pfQuestOctoQoL
if not QoL.enabled or not (C_Map and C_Map.GetMapInfo and C_Map.GetMapRectOnMap) then return end

local MAX_PINS = 2000
local ZONE_MAP = 3   -- Enum.UIMapType

-- The world view has no coordinate rect, so its two continents are placed by
-- hand, as { width, height, left, top } fractions of the map, by continent index.
local WORLD_VIEW_LAYOUT = {
  [1] = { 0.85, 0.82, -0.20, 0.06 }, -- Kalimdor, left
  [2] = { 0.85, 0.82, 0.35, 0.06 },  -- Eastern Kingdoms, right
}
local CONTINENT_LAYOUT = { 1, 1, 0, 0 }

-- tracking pins worth showing on a continent; the rest would bury it
local UTILITY_TRACKS = {
  "TRACK_FLIGHT", "TRACK_AUCTIONEER", "TRACK_BANKER", "TRACK_BATTLEMASTER",
  "TRACK_INNKEEPER", "TRACK_MAILBOX", "TRACK_STABLEMASTER",
  "TRACK_SPIRITHEALER", "TRACK_MEETINGSTONE",
}

QoL.AddConfig({
  { text = "|cff33ffccContinent Map|r", type = "header" },
  { text = "Display Continent Pins", default = "1", type = "checkbox", config = "continentPins" },
  { text = "Require Ctrl+Click for Pin Interaction", default = "0", type = "checkbox", config = "continentClickThrough" },
  { text = "Continent Node Size", default = "12", type = "text", config = "continentNodeSize" },
  { text = "Continent Utility Node Size", default = "14", type = "text", config = "continentUtilityNodeSize" },
})
QoL.SetDefaults({ continentPins = "1", continentClickThrough = "0", continentNodeSize = "12", continentUtilityNodeSize = "14" })

local pins = {}
local shownPins = 0

local function Enabled()
  return pfQuest_config and pfQuest_config["continentPins"] == "1"
end

local function Number(key, default)
  return tonumber(pfQuest_config and pfQuest_config[key]) or default
end

-- AreaTable zone id -> { continent map id, minX, maxX, minY, maxY } of the
-- zone on its continent, or false when the client can't place it
local zoneRects = {}

local function ZoneRect(zone)
  if zoneRects[zone] == nil then
    local info = C_Map.GetMapInfo(zone)
    local continent = info and info.mapType == ZONE_MAP and info.parentMapID
    local minX, maxX, minY, maxY
    if continent then
      minX, maxX, minY, maxY = C_Map.GetMapRectOnMap(zone, continent)
    end
    zoneRects[zone] = minX and { continent, minX, maxX, minY, maxY } or false
  end
  return zoneRects[zone]
end

-- continent index (as in GetMapZones) -> its map id, found through its zones
local continentIDs = {}

local function ContinentMapID(index)
  if continentIDs[index] == nil then
    continentIDs[index] = false
    for _, name in ipairs({ GetMapZones(index) }) do
      local zone = pfMap:GetMapIDByName(name)
      local rect = zone and ZoneRect(zone)
      if rect then
        continentIDs[index] = rect[1]
        break
      end
    end
  end
  return continentIDs[index]
end

local function IsUtility(addon)
  for _, track in ipairs(UTILITY_TRACKS) do
    if string.find(addon, track, 1, true) then return true end
  end
  return false
end

-- nil to leave a node off the continent, otherwise whether it's a utility pin
local function Wanted(node, level)
  local utility = false
  for _, data in pairs(node) do
    if data.addon and string.find(data.addon, "TRACK_", 1, true) then
      if not IsUtility(data.addon) then return nil end
      utility = true
    else
      local complete = data.texture and string.find(data.texture, "complete", 1, true)
      local qlvl = tonumber(data.qlvl) or tonumber(data.lvl) or 0
      local min = tonumber(data.min) or 0
      if not complete then
        if pfQuest_config["showlowlevel"] == "0" and qlvl > 0 and qlvl <= QoL.GrayLevel(level) then return nil end
        if pfQuest_config["showlowlevel"] == "0" and min <= 1 and qlvl <= QoL.GrayLevel(level) then return nil end
        if min > level + (pfQuest_config["showhighlevel"] == "1" and 3 or 0) then return nil end
      end
    end
  end
  return utility
end

-- pfQuest sizes a pin for the map's zoom; keep that, at the continent size
local function SizePin(pin)
  pfMap:ResizeNode(pin)
  local base = pin.utility and Number("continentUtilityNodeSize", 14) or Number("continentNodeSize", 12)
  local default = (pin.cluster or pin.layer == 4) and 18 or 14
  pin.defsize = base * pin.defsize / default
  pin:SetWidth(pin.defsize)
  pin:SetHeight(pin.defsize)
end

local function ApplyMouse(pin)
  pin:EnableMouse(pfQuest_config["continentClickThrough"] ~= "1" or IsControlKeyDown() and true or false)
end

local function HidePins(from)
  for i = from, shownPins do
    pins[i]:Hide()
  end
  shownPins = math.min(shownPins, from - 1)
end

local function Draw()
  local continent, zone = GetCurrentMapContinent(), GetCurrentMapZone()
  if not Enabled() or not WorldMapFrame:IsShown() or zone ~= 0 or continent < 0 then
    HidePins(1)
    return
  end

  local views = continent == 0 and { 1, 2 } or { continent }
  local width, height = WorldMapButton:GetWidth(), WorldMapButton:GetHeight()
  local level = UnitLevel("player")
  local placed = {}
  local count = 0

  for _, index in ipairs(views) do
    local layout = continent == 0 and WORLD_VIEW_LAYOUT[index] or CONTINENT_LAYOUT
    local continentID = layout and ContinentMapID(index)
    if continentID then
      for _, maps in pairs(pfMap.nodes) do
        for zoneID, nodes in pairs(maps) do
          local rect = ZoneRect(zoneID)
          if rect and rect[1] == continentID then
            for coords, node in pairs(nodes) do
              local utility
              if count < MAX_PINS then utility = Wanted(node, level) end
              if utility ~= nil then
                local _, _, x, y = string.find(coords, "(.*)|(.*)")
                local cx = rect[2] + (rect[3] - rect[2]) * tonumber(x) / 100
                local cy = rect[4] + (rect[5] - rect[4]) * tonumber(y) / 100
                -- the same pin from a city and the zone around it lands on one spot
                local key = next(node) .. ":" .. floor(cx * 1000) .. ":" .. floor(cy * 1000)
                if cx >= 0 and cx <= 1 and cy >= 0 and cy <= 1 and not placed[key] then
                  placed[key] = true
                  count = count + 1
                  local pin = pins[count]
                  if not pin then
                    pin = pfMap:BuildNode("pfQuestOctoContinentPin" .. count, WorldMapButton)
                    pins[count] = pin
                  end
                  pin.utility = utility
                  pfMap:UpdateNode(pin, node)
                  SizePin(pin)
                  ApplyMouse(pin)
                  pin:ClearAllPoints()
                  pin:SetPoint("CENTER", WorldMapButton, "TOPLEFT",
                    (layout[3] + layout[1] * cx) * width, -(layout[4] + layout[2] * cy) * height)
                  pin:Show()
                end
              end
            end
          end
        end
      end
    end
  end

  if count < shownPins then
    HidePins(count + 1)
  end
  shownPins = count
end

local drawSoon = QoL.Debounce(0.1, Draw)

local events = CreateFrame("Frame")
events:RegisterEvent("WORLD_MAP_UPDATE")
events:RegisterEvent("MODIFIER_STATE_CHANGED")
events:SetScript("OnEvent", function()
  if event == "MODIFIER_STATE_CHANGED" then
    for i = 1, shownPins do ApplyMouse(pins[i]) end
  elseif GetCurrentMapZone() ~= 0 then
    -- leaving the continent: pfQuest draws the zone's pins, ours go now
    HidePins(1)
  else
    drawSoon()
  end
end)

-- pins added or removed while a continent is showing
local UpdateNodes = pfMap.UpdateNodes
pfMap.UpdateNodes = function(self)
  UpdateNodes(self)
  if GetCurrentMapZone() == 0 then drawSoon() end
end

-- pfQuest resizes its own pins when the map is zoomed
local ResizeNodes = pfMap.ResizeNodes
pfMap.ResizeNodes = function(self)
  ResizeNodes(self)
  for i = 1, shownPins do SizePin(pins[i]) end
end

WorldMapFrame:HookScript("OnShow", drawSoon)
if pfQuestConfig then
  pfQuestConfig:HookScript("OnHide", drawSoon)
end

SLASH_PFQUESTOCTOMAP1 = "/pfqmap"
SlashCmdList["PFQUESTOCTOMAP"] = function(msg)
  local _, _, cmd, value = string.find(string.lower(msg or ""), "^(%S*)%s*(%S*)")
  if (cmd == "on" or cmd == "off") then
    pfQuest_config["continentPins"] = cmd == "on" and "1" or "0"
    QoL.Print("Continent pins " .. cmd .. ".")
  elseif cmd == "ctrl" and (value == "on" or value == "off") then
    pfQuest_config["continentClickThrough"] = value == "on" and "1" or "0"
    QoL.Print("Continent pins " .. (value == "on" and "need Ctrl to hover or click." or "respond to the mouse."))
  elseif (cmd == "size" or cmd == "utilitysize") and tonumber(value) then
    pfQuest_config[cmd == "size" and "continentNodeSize" or "continentUtilityNodeSize"] = value
    QoL.Print("Continent " .. (cmd == "size" and "pin" or "utility pin") .. " size " .. value .. ".")
  else
    QoL.Print(string.format("Continent pins %s, %d shown. /pfqmap on | off | ctrl on|off | size <n> | utilitysize <n>",
      Enabled() and "on" or "off", shownPins))
    return
  end
  Draw()
end
