-- Party quest progress: party members send each other their objective counts,
-- and the tooltips of mobs, objects and pfQuest's map pins list everyone's.
-- Ported from the pfQuest-octo pack (Shadowtoots' module for pfQuest-turtle).
-- The messages are unchanged ("pfqo" / "PFQO_SYNC"), so party members still on
-- that pack see your progress and you see theirs.
--
-- Message format, one addon message of at most 250 characters:
--   V1<type><targetId>Q<questId>:<current>:<total>:<objective>;...
--     type U: a unit to kill or talk to, targetId the unit
--     type I: an item to collect, targetId the item
--     type O: an object to use, targetId the object
--   REMOVEQ:<questId>:<title>   the quest left the sender's log
--   PFQO_SYNC "1"               asks everyone to send all of theirs

local QoL = pfQuestOctoQoL
if not QoL.enabled then return end

local PREFIX = "pfqo"
local SYNC_PREFIX = "PFQO_SYNC"
local MAX_MESSAGE = 250

local partyQuestData = {}   -- sender -> target name -> list of { quest, objective, current, total }
local lastSent = {}         -- entries already sent, so only changes go out
local lastQuests = {}       -- quest ID -> title, as last sent

QoL.AddConfig({
  { text = "|cff33ffccParty|r", type = "header" },
  { text = "Show Party Quest Progress on Tooltips", default = "1", type = "checkbox", config = "showPartyProgress" },
})
QoL.SetDefaults({ showPartyProgress = "1" })

local function Enabled()
  return pfQuest_config and pfQuest_config["showPartyProgress"] == "1"
end

local function InParty()
  return GetNumPartyMembers() > 0
end

local function Store(sender, name, title, objective, current, total)
  partyQuestData[sender] = partyQuestData[sender] or {}
  local targets = partyQuestData[sender]
  targets[name] = targets[name] or {}
  for _, d in ipairs(targets[name]) do
    if d.quest == title then
      d.objective, d.current, d.total = objective, current, total
      return
    end
  end
  table.insert(targets[name], { quest = title, objective = objective, current = current, total = total })
end

-- forget players who left the party
local function CleanupPartyData()
  local valid = { [UnitName("player")] = true }
  for i = 1, GetNumPartyMembers() do
    local name = UnitName("party" .. i)
    if name then valid[name] = true end
  end
  for player in pairs(partyQuestData) do
    if not valid[player] then
      partyQuestData[player] = nil
    end
  end
end

local function Send(force)
  if not Enabled() or not InParty() then return end

  local quests = QoL.ScanQuestLog()

  for questId, title in pairs(lastQuests) do
    if not quests[questId] then
      SendAddonMessage(PREFIX, string.format("REMOVEQ:%d:%s", questId, title), "PARTY")
    end
  end
  lastQuests = {}
  for questId, quest in pairs(quests) do
    lastQuests[questId] = quest.title
  end

  -- units by themselves; items once per objective, whichever mob or object
  -- holds them, since the receiver looks those up from the item
  local entries, items = {}, {}
  for _, list in pairs(QoL.BuildTargets(quests)) do
    for _, e in ipairs(list) do
      if e.targetType == "U" then
        table.insert(entries, { "U", e.targetId, e })
      elseif not items[e.questId .. ":" .. e.objective] then
        items[e.questId .. ":" .. e.objective] = true
        table.insert(entries, { "I", e.itemId, e })
      end
    end
  end

  local lines, sent = {}, {}
  for _, entry in ipairs(entries) do
    local targetType, targetId, e = entry[1], entry[2], entry[3]
    local objective = string.gsub(e.objective, "[:;]", "")
    local line = string.format("%s%dQ%d:%d:%d:%s;", targetType, targetId, e.questId, e.current, e.total, objective)
    if not sent[line] then
      sent[line] = true
      if force or not lastSent[line] then
        table.insert(lines, line)
      end
    end
  end
  lastSent = sent

  local message = "V1"
  for _, line in ipairs(lines) do
    if string.len(message) + string.len(line) > MAX_MESSAGE then
      SendAddonMessage(PREFIX, message, "PARTY")
      message = "V1"
    end
    message = message .. line
  end
  if message ~= "V1" then
    SendAddonMessage(PREFIX, message, "PARTY")
  end
end

local function Receive(sender, message)
  local _, _, removeId, removeTitle = string.find(message, "^REMOVEQ:(%d+):(.+)$")
  if removeId then
    for name, list in pairs(partyQuestData[sender] or {}) do
      for i = table.getn(list), 1, -1 do
        if list[i].quest == removeTitle then
          table.remove(list, i)
        end
      end
      if table.getn(list) == 0 then
        partyQuestData[sender][name] = nil
      end
    end
    return
  end

  if string.sub(message, 1, 2) ~= "V1" then return end

  for line in string.gfind(string.sub(message, 3), "[^;]+") do
    local _, _, targetType, targetId, questId, current, total, objective =
      string.find(line, "^([UIO])(%d+)Q(%d+):(%d+):(%d+):(.*)$")
    local quest = targetType and QoL.Loc("quests", tonumber(questId))
    local title = quest and quest["T"]

    if title then
      targetId, current, total = tonumber(targetId), tonumber(current), tonumber(total)
      if objective == "" then objective = "Quest Objective" end

      if targetType == "I" then
        local item = pfDB["items"]["data"][targetId]
        if item then
          for unitId in pairs(item["U"] or {}) do
            local name = QoL.Loc("units", unitId)
            if name then Store(sender, name, title, objective, current, total) end
          end
          for objectId in pairs(item["O"] or {}) do
            local name = QoL.Loc("objects", objectId)
            if name then Store(sender, name, title, objective, current, total) end
          end
        end
      else
        local name = QoL.Loc(targetType == "U" and "units" or "objects", targetId)
        if name then Store(sender, name, title, objective, current, total) end
      end
    end
  end
end

local function ClassColor(player)
  local unit = player == UnitName("player") and "player"
  if not unit then
    for i = 1, GetNumPartyMembers() do
      if UnitName("party" .. i) == player then
        unit = "party" .. i
        break
      end
    end
  end
  local _, class = unit and UnitClass(unit)
  local color = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
  if color then
    return color.r, color.g, color.b
  end
  return 1, 1, 1
end

-- quest title -> list of { player, objective, current, total } for one target
local function QuestGroups(name)
  local groups = {}
  for player, targets in pairs(partyQuestData) do
    for _, d in ipairs(targets[name] or {}) do
      groups[d.quest] = groups[d.quest] or {}
      table.insert(groups[d.quest], { player = player, objective = d.objective, current = d.current, total = d.total })
    end
  end
  return groups
end

local function HasPartyData(name)
  if not name then return false end
  for _, targets in pairs(partyQuestData) do
    if targets[name] then return true end
  end
  return false
end

local function InQuestLog(title)
  for i = 1, GetNumQuestLogEntries() do
    if pfQuestCompat.GetQuestLogTitle(i) == title then
      return true
    end
  end
  return false
end

-- skipHeader(title) is true for quests whose title pfQuest already added
local function AddPartyLines(tooltip, name, skipHeader)
  tooltip:AddLine(" ")
  for title, lines in pairs(QuestGroups(name)) do
    if not (skipHeader and skipHeader(title)) then
      tooltip:AddLine("|cff555555[|cffffcc00!|cff555555]|r " .. title, 1, 1, 0)
    end
    for _, line in ipairs(lines) do
      -- red at none done, through yellow, to green when done
      local perc = line.current / line.total
      local r, g = 1, 1
      if perc <= 0.5 then g = perc * 2 else r = 2 - perc * 2 end
      local cr, cg, cb = ClassColor(line.player)
      local player = string.format("|cff%02x%02x%02x%s|r", cr * 255, cg * 255, cb * 255, line.player)
      tooltip:AddLine(string.format("|cffaaaaaa- |r%s: %s (%d/%d)", player, line.objective, line.current, line.total), r, g, 0)
    end
  end
  tooltip:AddLine(" ")
end

-- mob and object tooltips
local watcher = CreateFrame("Frame", nil, GameTooltip)
watcher:SetScript("OnShow", function()
  local name = UnitName("mouseover")
  if not name or UnitIsPlayer("mouseover") or not Enabled() or not HasPartyData(name) then return end
  AddPartyLines(GameTooltip, name, InQuestLog)
  GameTooltip:Show()
end)

-- pfQuest's map pins. pfQuest calls pfMap:ShowTooltip each time, so wrapping
-- the function covers pins created before this loaded.
local ShowTooltip = pfMap.ShowTooltip
pfMap.ShowTooltip = function(self, meta, tooltip)
  tooltip = tooltip or GameTooltip
  if not Enabled() or UnitExists("mouseover") then
    return ShowTooltip(self, meta, tooltip)
  end

  local key = meta.spawn or meta.title
  local first = GameTooltipTextLeft1 and GameTooltipTextLeft1:GetText()
  local match = HasPartyData(key) and key or HasPartyData(first) and first
  if not match then
    return ShowTooltip(self, meta, tooltip)
  end

  -- leave out pfQuest's own lines for the quest: ours list everyone, you
  -- included. pcall so the quest is put back on the pin even if that fails.
  local quest = meta["quest"]
  meta["quest"] = nil
  pcall(ShowTooltip, self, meta, tooltip)
  meta["quest"] = quest
  AddPartyLines(tooltip, match)
  tooltip:Show()
end

local sendSoon = QoL.Debounce(0.5, function() Send() end)

local function SyncParty()
  CleanupPartyData()
  if InParty() and Enabled() then
    SendAddonMessage(SYNC_PREFIX, "1", "PARTY")
    Send(true)
  else
    lastSent, lastQuests = {}, {}
  end
end

local events = CreateFrame("Frame")
events:RegisterEvent("CHAT_MSG_ADDON")
events:RegisterEvent("PARTY_MEMBERS_CHANGED")
events:RegisterEvent("QUEST_LOG_UPDATE")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function()
  if event == "CHAT_MSG_ADDON" then
    if arg1 == PREFIX then
      Receive(arg4, arg2)
    elseif arg1 == SYNC_PREFIX and arg4 ~= UnitName("player") then
      Send(true)
    end
  elseif event == "QUEST_LOG_UPDATE" then
    if InParty() then sendSoon() end
  else
    SyncParty()
  end
end)

SLASH_PFQUESTOCTOPARTY1 = "/pfqparty"
SLASH_PFQUESTOCTOPARTY2 = "/pfqd"
SlashCmdList["PFQUESTOCTOPARTY"] = function(msg)
  local _, _, cmd, value = string.find(msg or "", "^(%S*)%s*(.-)$")
  cmd = string.lower(cmd or "")

  if cmd == "on" or cmd == "off" then
    pfQuest_config["showPartyProgress"] = cmd == "on" and "1" or "0"
    SyncParty()
    QoL.Print("Party quest progress " .. (cmd == "on" and "enabled" or "disabled") .. ".")
  elseif cmd == "sync" then
    SyncParty()
    QoL.Print("Asked the party for their progress.")
  elseif cmd == "test" and value ~= "" then
    Store("TestBuddy", value, "Test Quest", "Kill " .. value, 3, 10)
    QoL.Print("Added fake progress from TestBuddy on '" .. value .. "'. Mouse over it, or its map pin.")
  else
    QoL.Print("Party quest progress " .. (Enabled() and "enabled" or "disabled") .. ", " .. GetNumPartyMembers() .. " party members.")
    for player, targets in pairs(partyQuestData) do
      DEFAULT_CHAT_FRAME:AddMessage("  " .. player .. ":")
      for name, list in pairs(targets) do
        for _, d in ipairs(list) do
          DEFAULT_CHAT_FRAME:AddMessage("    " .. name .. " - " .. d.quest .. ": " .. d.objective .. " (" .. d.current .. "/" .. d.total .. ")")
        end
      end
    end
    DEFAULT_CHAT_FRAME:AddMessage("/pfqparty on | off | sync | test <unit name>")
  end
end
