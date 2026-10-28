-- Quest icons on nameplates: a sword on a mob your quests need, a bag on one
-- that drops an item they need. Ported from the pfQuest-octo pack (Shadowtoots'
-- module for pfQuest-turtle). That version found plates by watching
-- WorldFrame's children and recognising their border texture, which pfUI and
-- other nameplate addons remove; this one is told about plates by ClassicAPI's
-- NAME_PLATE_UNIT_ADDED / NAME_PLATE_UNIT_REMOVED.

local QoL = pfQuestOctoQoL
if not QoL.enabled or not C_NamePlate then return end

local ICON_SIZE = 16
local SWORD_ICON = QoL.path .. "img\\slay"
local BAG_ICON = QoL.path .. "img\\loot"

local icons = {}            -- unit name -> icon texture
local iconFrames = {}       -- nameplate frame -> icon frame on it
local unusedIconFrames = {}

QoL.AddConfig({
  { text = "|cff33ffccNameplates|r", type = "header" },
  { text = "Show Quest Icons on Nameplates", default = "1", type = "checkbox", config = "nameplatesEnabled" },
  { text = "Icon Scale", default = "1", type = "text", config = "nameplateScale" },
  { text = "Icon X Position", default = "-20", type = "text", config = "nameplateX" },
  { text = "Icon Y Position", default = "-8", type = "text", config = "nameplateY" },
})
QoL.SetDefaults({ nameplatesEnabled = "1", nameplateScale = "1", nameplateX = "-20", nameplateY = "-8" })

local function Enabled()
  return pfQuest_config and pfQuest_config["nameplatesEnabled"] == "1"
end

local function Setting(key, default)
  return tonumber(pfQuest_config and pfQuest_config[key]) or default
end

local function Rescan()
  icons = {}
  for name, entries in pairs(QoL.BuildTargets(QoL.ScanQuestLog())) do
    for _, e in ipairs(entries) do
      if e.current < e.total then
        if e.targetType == "U" then
          icons[name] = SWORD_ICON
        elseif e.targetType == "I" and not icons[name] then
          icons[name] = BAG_ICON
        end
      end
    end
  end
end

local function PlaceIcon(frame)
  local size = ICON_SIZE * Setting("nameplateScale", 1)
  frame:SetWidth(size)
  frame:SetHeight(size)
  frame:ClearAllPoints()
  frame:SetPoint("LEFT", frame:GetParent(), "LEFT", Setting("nameplateX", -20), Setting("nameplateY", -8))
end

local function ShowIcon(plate, texture)
  local frame = iconFrames[plate]
  if not frame then
    frame = tremove(unusedIconFrames)
    if not frame then
      frame = CreateFrame("Frame")
      frame.icon = frame:CreateTexture(nil, "ARTWORK")
      frame.icon:SetAllPoints(frame)
      frame:EnableMouse(false)
    end
    frame:SetParent(plate)
    frame:SetFrameStrata("HIGH")
    frame:SetFrameLevel(plate:GetFrameLevel() + 5)
    PlaceIcon(frame)
    iconFrames[plate] = frame
  end
  frame.icon:SetTexture(texture)
  frame:Show()
end

local function HideIcon(plate)
  local frame = iconFrames[plate]
  if not frame then return end
  frame:Hide()
  tinsert(unusedIconFrames, frame)
  iconFrames[plate] = nil
end

local function UpdatePlate(unit)
  local plate = C_NamePlate.GetNamePlateForUnit(unit)
  if not plate then return end
  local texture = Enabled() and not UnitIsPlayer(unit) and icons[UnitName(unit)]
  if texture then
    ShowIcon(plate, texture)
  else
    HideIcon(plate)
  end
end

local function UpdateAll()
  if not Enabled() then
    for plate in pairs(iconFrames) do
      HideIcon(plate)
    end
    return
  end
  for i = 1, 40 do
    local unit = "nameplate" .. i
    if UnitExists(unit) then
      UpdatePlate(unit)
    end
  end
end

local function Refresh()
  Rescan()
  UpdateAll()
end

local rescanSoon = QoL.Debounce(0.5, Refresh)

local events = CreateFrame("Frame")
events:RegisterEvent("NAME_PLATE_UNIT_ADDED")
events:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
events:RegisterEvent("QUEST_LOG_UPDATE")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function()
  if event == "NAME_PLATE_UNIT_ADDED" then
    UpdatePlate(arg1)
  elseif event == "NAME_PLATE_UNIT_REMOVED" then
    -- the token still names the leaving unit during this event
    local plate = C_NamePlate.GetNamePlateForUnit(arg1)
    if plate then HideIcon(plate) end
  else
    rescanSoon()
  end
end)

-- settings take effect when pfQuest's settings window closes
if pfQuestConfig then
  pfQuestConfig:HookScript("OnHide", function()
    for _, frame in pairs(iconFrames) do
      PlaceIcon(frame)
    end
    UpdateAll()
  end)
end

SLASH_PFQUESTOCTONP1 = "/pfqnp"
SlashCmdList["PFQUESTOCTONP"] = function(msg)
  local _, _, cmd, value = string.find(msg or "", "^(%S*)%s*(.-)$")
  cmd = string.lower(cmd or "")

  if cmd == "on" or cmd == "off" then
    pfQuest_config["nameplatesEnabled"] = cmd == "on" and "1" or "0"
    UpdateAll()
    QoL.Print("Nameplate icons " .. (cmd == "on" and "enabled" or "disabled") .. ".")
  elseif (cmd == "scale" or cmd == "x" or cmd == "y") and tonumber(value) then
    local key = cmd == "scale" and "nameplateScale" or cmd == "x" and "nameplateX" or "nameplateY"
    pfQuest_config[key] = value
    for _, frame in pairs(iconFrames) do
      PlaceIcon(frame)
    end
    QoL.Print("Icon " .. cmd .. " set to " .. value .. ".")
  elseif cmd == "debug" then
    QoL.Print("Nameplate icons " .. (Enabled() and "enabled" or "disabled") .. ".")
    local count = 0
    for name, icon in pairs(icons) do
      count = count + 1
      DEFAULT_CHAT_FRAME:AddMessage("  " .. name .. " - " .. (icon == SWORD_ICON and "kill" or "loot"))
    end
    local shown = 0
    for _ in pairs(iconFrames) do shown = shown + 1 end
    DEFAULT_CHAT_FRAME:AddMessage(count .. " quest targets, " .. shown .. " icons showing.")
  elseif cmd == "scan" then
    Refresh()
    QoL.Print("Rescanned the quest log.")
  else
    QoL.Print("/pfqnp on | off | scale <n> | x <n> | y <n> | debug | scan")
  end
end
