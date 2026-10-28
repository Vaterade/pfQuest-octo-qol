-- Shared by the modules: which units and objects the quests in your log point
-- at, keyed by name. Quest IDs come from ClassicAPI, so this reads only the
-- quests you have rather than matching titles across the whole database.

pfQuestOctoQoL = {}
local QoL = pfQuestOctoQoL

QoL.path = "Interface\\AddOns\\pfQuest-octo-qol\\"
QoL.enabled = C_QuestLog and C_QuestLog.GetQuestIDForLogIndex and true or false

function QoL.Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpfQuest Octo QoL:|r " .. msg)
end

if not QoL.enabled then
  QoL.Print("ClassicAPI is not loaded, so nameplate icons and party progress are off.")
end

-- the localized name of a unit, object, item or quest entry
function QoL.Loc(db, id)
  local loc = pfDB[db] and pfDB[db]["loc"]
  return loc and loc[id]
end

-- "Defias Bandit slain: 3/10" -> "Defias Bandit slain", 3, 10
function QoL.ParseObjective(text)
  local _, _, name, current, total = string.find(text, "(.*):%s*(%d+)%s*/%s*(%d+)")
  if not name then
    return nil
  end
  name = string.gsub(name, "^%s*(.-)%s*$", "%1")
  return name, tonumber(current), tonumber(total)
end

-- Every quest in the log, keyed by quest ID:
-- { title = ..., objectives = { { objective = ..., current = n, total = n }, ... } }
function QoL.ScanQuestLog()
  local quests = {}
  for index = 1, GetNumQuestLogEntries() do
    local title, _, _, header = pfQuestCompat.GetQuestLogTitle(index)
    local questId = C_QuestLog.GetQuestIDForLogIndex(index)
    if title and not header and questId and questId > 0 then
      local objectives = {}
      for i = 1, GetNumQuestLeaderBoards(index) do
        local text = GetQuestLogLeaderBoard(i, index)
        local name, current, total
        if text then
          name, current, total = QoL.ParseObjective(text)
        end
        if name then
          table.insert(objectives, { objective = name, current = current, total = total })
        end
      end
      quests[questId] = { title = title, objectives = objectives }
    end
  end
  return quests
end

-- the database entries for a quest in the log: its own ID, or, when the
-- database has the quest under another ID, every quest with that title
local function DatabaseQuests(questId, title)
  if pfDB["quests"]["data"][questId] then
    return { [questId] = true }
  end
  return pfDatabase:GetIDByName(title, "quests") or {}
end

-- What each name in the world means for your quests:
-- targets[name] = list of { quest, questId, objective, current, total, targetType, targetId, itemId }
-- targetType "U" is a unit you need to kill or talk to, "I" a unit that drops
-- an item you need, "O" an object that holds one.
function QoL.BuildTargets(quests)
  local targets = {}

  local function add(name, entry)
    targets[name] = targets[name] or {}
    table.insert(targets[name], entry)
  end

  for logQuestId, quest in pairs(quests) do
    for questId in pairs(DatabaseQuests(logQuestId, quest.title)) do
      local data = pfDB["quests"]["data"][questId]
      local obj = data and data["obj"]
      if obj then
        for _, o in ipairs(quest.objectives) do
          local function entry(targetType, targetId, itemId)
            return {
              quest = quest.title, questId = questId, objective = o.objective,
              current = o.current, total = o.total,
              targetType = targetType, targetId = targetId, itemId = itemId,
            }
          end

          if obj["U"] then
            local base = string.gsub(string.gsub(o.objective, " slain$", ""), " killed$", "")
            for _, unitId in pairs(obj["U"]) do
              local name = QoL.Loc("units", unitId)
              if name and (base == name or string.find(o.objective, name, 1, true)) then
                add(name, entry("U", unitId))
              end
            end
          end

          if obj["I"] then
            for _, itemId in pairs(obj["I"]) do
              local itemName = QoL.Loc("items", itemId)
              local item = pfDB["items"]["data"][itemId]
              if itemName and item and string.find(o.objective, itemName, 1, true) then
                for unitId in pairs(item["U"] or {}) do
                  local name = QoL.Loc("units", unitId)
                  if name then add(name, entry("I", unitId, itemId)) end
                end
                for objectId in pairs(item["O"] or {}) do
                  local name = QoL.Loc("objects", objectId)
                  if name then add(name, entry("O", objectId, itemId)) end
                end
              end
            end
          end
        end
      end
    end
  end

  return targets
end

-- quests at or below this level are grey (no experience) at the given level
function QoL.GrayLevel(level)
  if level <= 5 then return 0 end
  if level <= 49 then return level - floor(level / 10) - 5 end
  if level == 50 then return 40 end
  if level <= 59 then return level - floor(level / 5) - 1 end
  return level - 9
end

-- Returns a function that runs fn once calls to it have stopped for delay
-- seconds. A login fires one QUEST_LOG_UPDATE per quest log entry, and
-- rescanning on each of them froze the client in the old modules.
function QoL.Debounce(delay, fn)
  local frame = CreateFrame("Frame")
  local elapsed
  frame:SetScript("OnUpdate", function()
    if not elapsed then return end
    elapsed = elapsed + arg1
    if elapsed >= delay then
      elapsed = nil
      fn()
    end
  end)
  return function() elapsed = 0 end
end

-- Add entries to pfQuest's settings window. pfQuest builds the window from
-- pfQuest_defconfig as soon as it loads, which can be before this addon does
-- (its first entry is then already the global frame pfQuestConfig1);
-- settings.lua rebuilds it after login in that case.
function QoL.AddConfig(entries)
  if pfQuestConfig1 then
    QoL.configBuiltEarly = true
  end
  for _, e in ipairs(entries) do
    table.insert(pfQuest_defconfig, e)
  end
end

-- fill in defaults once pfQuest_config (saved per character) has loaded
function QoL.SetDefaults(defaults)
  local frame = CreateFrame("Frame")
  frame:RegisterEvent("VARIABLES_LOADED")
  frame:SetScript("OnEvent", function()
    pfQuest_config = pfQuest_config or {}
    for key, value in pairs(defaults) do
      if pfQuest_config[key] == nil then
        pfQuest_config[key] = value
      end
    end
  end)
end
