-- Announce quest objective progress to your party: "Finished [Harpy Feather]
-- for [Gather Feathers]." and, if turned on, every step on the way there.
-- Ported from the pfQuest-octo pack's pfQuest-announce.lua (Shadowtoots'
-- module for pfQuest-turtle).
--
-- The old version found the quest by selecting each entry in your quest log
-- in turn, matched objective names by substring, could link an item from
-- whichever quest happened to be selected, and announced "N/M" messages that
-- belonged to no quest. This one reads the log without selecting anything,
-- takes the quest and item IDs from ClassicAPI, and only announces objectives
-- of quests in your log.

local QoL = pfQuestOctoQoL
if not QoL.enabled then return end

-- give the item time to reach the client's cache, so it can be linked
local ANNOUNCE_DELAY = 0.3

QoL.AddConfig({
  { text = "|cff33ffccAnnounce|r", type = "header" },
  { text = "Announce Finished Quest Objectives", default = "0", type = "checkbox", config = "announceFinished" },
  { text = "Announce Remaining Quest Objectives", default = "0", type = "checkbox", config = "announceRemaining" },
  { text = "Show Item Link in Finished Announcement", default = "1", type = "checkbox", config = "announceShowItem" },
})
QoL.SetDefaults({ announceFinished = "0", announceRemaining = "0", announceShowItem = "1" })

local lastCounts = {}   -- "questId:objective" -> count last announced
local announced = {}    -- "questId:objective" -> finished was already announced

local function Setting(key)
  return pfQuest_config and pfQuest_config[key] == "1"
end

-- the item an objective asks for, from the database, for when the game
-- hasn't cached the quest yet and can't say
local function DatabaseItem(questId, objective)
  local data = questId and pfDB["quests"]["data"][questId]
  for _, itemId in pairs(data and data["obj"] and data["obj"]["I"] or {}) do
    local name = QoL.Loc("items", itemId)
    if name and string.find(objective, name, 1, true) then
      return itemId
    end
  end
end

-- the quest-log entry with this objective: title, quest ID, and the item ID
-- when it's an item to collect
local function FindObjective(objective)
  for index = 1, GetNumQuestLogEntries() do
    local title, _, _, header = pfQuestCompat.GetQuestLogTitle(index)
    if title and not header then
      for i = 1, GetNumQuestLeaderBoards(index) do
        local text, kind = GetQuestLogLeaderBoard(i, index)
        if text and QoL.ParseObjective(text) == objective then
          local questId = C_QuestLog.GetQuestIDForLogIndex(index)
          local itemId
          if kind == "item" then
            itemId = GetQuestLogLeaderBoardID and GetQuestLogLeaderBoardID(i, index)
            itemId = itemId or DatabaseItem(questId, objective)
          end
          return title, questId, itemId
        end
      end
    end
  end
end

local function QuestLink(questId, title)
  local data = questId and pfDB["quests"]["data"][questId]
  if not data or not data["lvl"] or pfQuest_config["questlinks"] ~= "1" then
    return "[" .. title .. "]"
  end
  return "|cffffff00|Hquest:" .. questId .. ":" .. data["lvl"] .. "|h[" .. title .. "]|h|r"
end

local function ItemLink(itemId)
  local name, link, quality = GetItemInfo(itemId)
  name = name or QoL.Loc("items", itemId)
  if not name then return nil end
  local color = "|cffffffff"
  local q = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
  if q then
    color = string.format("|cff%02x%02x%02x", math.ceil(q.r * 255), math.ceil(q.g * 255), math.ceil(q.b * 255))
  end
  return color .. "|H" .. (link or "item:" .. itemId .. pfQuestCompat.itemsuffix) .. "|h[" .. name .. "]|h|r"
end

local pending = {}
local delay = CreateFrame("Frame")
delay:SetScript("OnUpdate", function()
  for i = table.getn(pending), 1, -1 do
    local entry = pending[i]
    entry.timer = entry.timer - arg1
    if entry.timer <= 0 then
      table.remove(pending, i)
      entry.fn()
    end
  end
end)

local function Later(fn)
  table.insert(pending, { timer = ANNOUNCE_DELAY, fn = fn })
end

-- message is the objective popup, e.g. "Harpy Feather: 3/8"; with preview
-- set the announcement goes to your chat frame instead of the party
local function OnObjectiveUpdate(message, preview)
  if not preview and GetNumPartyMembers() == 0 then return end

  local objective, current, total = QoL.ParseObjective(message)
  if not objective then return end

  local title, questId, itemId = FindObjective(objective)
  if not title then
    if preview then QoL.Print("No quest in your log has the objective '" .. objective .. "'.") end
    return
  end

  local key = (questId or title) .. ":" .. objective
  if not preview and lastCounts[key] == current then return end
  lastCounts[key] = current

  local left = total - current
  local finishing = false
  if left < 1 then
    if Setting("announceFinished") and (preview or not announced[key]) then
      announced[key] = true
      finishing = true
    end
  else
    announced[key] = nil
  end
  if not finishing and not (left >= 1 and Setting("announceRemaining")) then return end

  Later(function()
    local quest = QuestLink(questId, title)
    local item = itemId and ItemLink(itemId)
    local text
    if finishing then
      local what = Setting("announceShowItem") and item or objective
      text = "Finished " .. what .. " for " .. quest .. "."
    else
      text = (item or objective) .. " for " .. quest .. " (" .. left .. " left)"
    end

    if preview then
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc[Announce preview]|r " .. text)
    else
      SendChatMessage(text, "PARTY")
    end
  end)
end

local events = CreateFrame("Frame")
events:RegisterEvent("UI_INFO_MESSAGE")
events:SetScript("OnEvent", function()
  if arg1 then OnObjectiveUpdate(arg1) end
end)

local commands = { finished = "announceFinished", remaining = "announceRemaining", item = "announceShowItem" }

SLASH_PFQUESTOCTOANNOUNCE1 = "/pfqannounce"
SlashCmdList["PFQUESTOCTOANNOUNCE"] = function(msg)
  local _, _, cmd, value = string.find(msg or "", "^(%S*)%s*(.-)$")
  cmd = string.lower(cmd or "")
  local state = string.lower(value or "")

  if commands[cmd] and (state == "on" or state == "off") then
    pfQuest_config[commands[cmd]] = state == "on" and "1" or "0"
    QoL.Print("Announce " .. cmd .. " " .. state .. ".")
  elseif cmd == "test" and value ~= "" then
    OnObjectiveUpdate(value, true)
  else
    QoL.Print(string.format("Announce finished %s, remaining %s, item links %s.",
      Setting("announceFinished") and "on" or "off",
      Setting("announceRemaining") and "on" or "off",
      Setting("announceShowItem") and "on" or "off"))
    DEFAULT_CHAT_FRAME:AddMessage("/pfqannounce finished | remaining | item  on | off")
    DEFAULT_CHAT_FRAME:AddMessage("/pfqannounce test <objective>: <n>/<m>  - shows what would be sent, in your chat only")
  end
end
