-- pfQuest's settings window, with this addon's settings in it and laid out in
-- three balanced columns. Ported from the pfQuest-octo pack's pfQuest-config.lua.
--
-- That module replaced pfQuest's window builder with its own copy, which has
-- no sliders (brues-code's pfQuest uses one for Arrow Scale) and would drift
-- from pfQuest's. This one keeps pfQuest's builder and only moves the entries
-- it built into columns afterwards.

local QoL = pfQuestOctoQoL
if not QoL.enabled or not pfQuestConfig or not pfQuestConfig.CreateConfigEntries then return end

local NUM_COLUMNS = 3
local COLUMN_GAP = 20
local MARGIN_X, MARGIN_TOP, MARGIN_BOTTOM = 10, 40, 60

-- pfQuest names the frame for each entry with a type pfQuestConfig1,
-- pfQuestConfig2, ... in pairs() order of pfQuest_defconfig, so walking the
-- table the same way pairs each entry with its frame
local function Entries()
  local list, count = {}, 0
  for _, data in pairs(pfQuest_defconfig) do
    if data.type then
      count = count + 1
      local frame = getglobal("pfQuestConfig" .. count)
      if not frame then return nil end
      table.insert(list, { frame = frame, data = data })
    end
  end
  return list
end

-- Sections (a header and what follows it) go into the column with the fewest
-- rows so far, biggest first, then keep their original order in each column.
local function Columns(entries)
  local sections, current = {}, nil
  for _, entry in ipairs(entries) do
    if entry.data.type == "header" or not current then
      current = { entries = {}, index = table.getn(sections) + 1 }
      table.insert(sections, current)
    end
    table.insert(current.entries, entry)
  end

  local bySize = {}
  for _, s in ipairs(sections) do table.insert(bySize, s) end
  table.sort(bySize, function(a, b) return table.getn(a.entries) > table.getn(b.entries) end)

  local columns, rows = {}, {}
  for c = 1, NUM_COLUMNS do columns[c], rows[c] = {}, 0 end
  for _, s in ipairs(bySize) do
    local best = 1
    for c = 2, NUM_COLUMNS do
      if rows[c] < rows[best] then best = c end
    end
    -- a blank row between sections
    rows[best] = rows[best] + (rows[best] > 0 and 1 or 0) + table.getn(s.entries)
    table.insert(columns[best], s)
  end
  for c = 1, NUM_COLUMNS do
    table.sort(columns[c], function(a, b) return a.index < b.index end)
  end
  -- and the columns in the order of their first section, so pfQuest's own lead
  table.sort(columns, function(a, b)
    return (a[1] and a[1].index or math.huge) < (b[1] and b[1].index or math.huge)
  end)
  return columns
end

local function Layout()
  local entries = Entries()
  if not entries or table.getn(entries) == 0 then return end

  local width, height = entries[1].frame:GetWidth(), entries[1].frame:GetHeight()
  local used, maxRows = 0, 0
  for c, sections in ipairs(Columns(entries)) do
    local row = 0
    for _, s in ipairs(sections) do
      if row > 0 then row = row + 1 end
      for _, entry in ipairs(s.entries) do
        row = row + 1
        entry.frame:ClearAllPoints()
        entry.frame:SetPoint("TOPLEFT", pfQuestConfig, "TOPLEFT",
          MARGIN_X + (c - 1) * (width + COLUMN_GAP), -MARGIN_TOP - (row - 1) * height)
      end
    end
    if row > 0 then used = c end
    maxRows = math.max(maxRows, row)
  end

  local frameWidth = used * width + (used - 1) * COLUMN_GAP + 2 * MARGIN_X
  local frameHeight = maxRows * height + MARGIN_TOP + MARGIN_BOTTOM
  pfQuestConfig:SetWidth(frameWidth)
  pfQuestConfig:SetHeight(frameHeight)

  -- shrink to fit the screen when there are many settings
  local scale = math.min(1, UIParent:GetHeight() * 0.95 / frameHeight, UIParent:GetWidth() * 0.95 / frameWidth)
  pfQuestConfig:SetScale(scale)
end

local CreateConfigEntries = pfQuestConfig.CreateConfigEntries
pfQuestConfig.CreateConfigEntries = function(self, config)
  CreateConfigEntries(self, config)
  Layout()
end

-- If pfQuest built its window before this addon added its settings, build it
-- again now that every module has. The old entry frames are hidden; the
-- rebuilt ones take over their names.
local login = CreateFrame("Frame")
login:RegisterEvent("PLAYER_LOGIN")
login:SetScript("OnEvent", function()
  if QoL.configBuiltEarly then
    local i = 1
    while getglobal("pfQuestConfig" .. i) do
      getglobal("pfQuestConfig" .. i):Hide()
      i = i + 1
    end
    pfQuestConfig:CreateConfigEntries(pfQuest_defconfig)
  else
    Layout()
  end
end)
