-- Quest automation: accept quests and turn in finished ones when you talk to
-- an NPC. Hold Shift while talking to do it by hand. Off by default. Ported
-- from the pfQuest-octo pack's pfquest-questlog.lua (Shadowtoots' module for
-- pfQuest-turtle).
--
-- That version read gossip quest lists as (title, level, low-level) triples,
-- the layout of later clients; 1.12 gives (title, level) pairs, so it picked
-- the wrong quests and its low-level check read a title. It also opened the
-- first quest you had with an NPC whether finished or not, so talking to any
-- NPC with an unfinished quest of yours showed its progress page instead of
-- the gossip. This one reads gossip through ClassicAPI (quest IDs, levels,
-- whether each is finished), only opens finished quests, leaves turn-ins
-- that cost money to you, and stops instead of retrying a quest that failed.

local QoL = pfQuestOctoQoL
if not QoL.enabled or not C_GossipInfo then return end

-- the repeatable cloth donation turn-ins
local DONATION = "Additional Runecloth"
-- don't select the same quest again this soon, e.g. when accepting fails on a
-- full quest log and the gossip comes straight back
local RETRY_DELAY = 5

QoL.AddConfig({
  { text = "|cff33ffccQuest Automation|r", type = "header" },
  { text = "Automatically accept and complete quests", default = "0", type = "checkbox", config = "autoQuests" },
  { text = "Skip accepting low level quests", default = "1", type = "checkbox", config = "autoQuestsSkipLowLevel" },
  { text = "Automate runecloth donations", default = "0", type = "checkbox", config = "automateRuneclothDonations" },
})
QoL.SetDefaults({ autoQuests = "0", autoQuestsSkipLowLevel = "1", automateRuneclothDonations = "0" })

local function Setting(key)
  return pfQuest_config and pfQuest_config[key] == "1"
end

local function IsLowLevel(level)
  return Setting("autoQuestsSkipLowLevel") and level and level > 0 and level <= QoL.GrayLevel(UnitLevel("player"))
end

local function Wanted(title)
  return Setting("automateRuneclothDonations") or not string.find(title, DONATION, 1, true)
end

local selected = {}   -- quest key -> when it was last selected

local function Select(key, fn, arg)
  local last = selected[key]
  if last and GetTime() - last < RETRY_DELAY then return false end
  selected[key] = GetTime()
  fn(arg)
  return true
end

-- quest-log state for a greeting NPC, which doesn't say which are finished
local function LogQuestComplete(title)
  for index = 1, GetNumQuestLogEntries() do
    local logTitle, _, _, header, _, complete = pfQuestCompat.GetQuestLogTitle(index)
    if logTitle == title and not header then
      return complete == 1 or GetNumQuestLeaderBoards(index) == 0
    end
  end
  return false
end

-- the level pfQuest's database has for a quest title, for greeting NPCs
local function DatabaseLevel(title)
  for id in pairs(pfDatabase:GetIDByName(title, "quests") or {}) do
    local data = pfDB["quests"]["data"][id]
    if data and data["lvl"] then return data["lvl"] end
  end
end

local function OnGossip()
  for _, q in ipairs(C_GossipInfo.GetActiveQuests()) do
    if q.isComplete and Wanted(q.title)
      and Select("active:" .. q.questID, C_GossipInfo.SelectActiveQuest, q.questID) then
      return
    end
  end
  for _, q in ipairs(C_GossipInfo.GetAvailableQuests()) do
    if not IsLowLevel(q.questLevel) and Wanted(q.title)
      and Select("available:" .. q.questID, C_GossipInfo.SelectAvailableQuest, q.questID) then
      return
    end
  end
end

local function OnGreeting()
  for i = 1, GetNumActiveQuests() do
    local title = GetActiveTitle(i)
    if title and LogQuestComplete(title) and Wanted(title)
      and Select("active:" .. title, SelectActiveQuest, i) then
      return
    end
  end
  for i = 1, GetNumAvailableQuests() do
    local title = GetAvailableTitle(i)
    if title and not IsLowLevel(DatabaseLevel(title)) and Wanted(title)
      and Select("available:" .. title, SelectAvailableQuest, i) then
      return
    end
  end
end

local events = CreateFrame("Frame")
events:RegisterEvent("GOSSIP_SHOW")
events:RegisterEvent("QUEST_GREETING")
events:RegisterEvent("QUEST_DETAIL")
events:RegisterEvent("QUEST_PROGRESS")
events:RegisterEvent("QUEST_COMPLETE")
events:SetScript("OnEvent", function()
  if not Setting("autoQuests") or IsShiftKeyDown() then return end

  if event == "GOSSIP_SHOW" then
    OnGossip()
  elseif event == "QUEST_GREETING" then
    OnGreeting()
  elseif event == "QUEST_DETAIL" then
    AcceptQuest()
  elseif event == "QUEST_PROGRESS" then
    -- quests that take money are yours to hand in
    if IsQuestCompletable() and (GetQuestMoneyToGet() or 0) == 0 then
      CompleteQuest()
    end
  elseif event == "QUEST_COMPLETE" then
    -- a reward to choose is yours to choose
    local choices = GetNumQuestChoices()
    if choices == 0 then
      GetQuestReward()
    elseif choices == 1 then
      GetQuestReward(1)
    end
  end
end)

local commands = { lowlevel = "autoQuestsSkipLowLevel", runecloth = "automateRuneclothDonations" }

SLASH_PFQUESTOCTOAUTO1 = "/pfqauto"
SlashCmdList["PFQUESTOCTOAUTO"] = function(msg)
  local _, _, cmd, state = string.find(string.lower(msg or ""), "^(%S*)%s*(%S*)")
  if cmd == "on" or cmd == "off" then
    pfQuest_config["autoQuests"] = cmd == "on" and "1" or "0"
    QoL.Print("Quest automation " .. cmd .. ". Hold Shift while talking to an NPC to skip it.")
  elseif commands[cmd] and (state == "on" or state == "off") then
    pfQuest_config[commands[cmd]] = state == "on" and "1" or "0"
    QoL.Print((cmd == "lowlevel" and "Skipping low level quests " or "Runecloth donations ") .. state .. ".")
  else
    QoL.Print(string.format("Quest automation %s, skip low level %s, runecloth donations %s.",
      Setting("autoQuests") and "on" or "off",
      Setting("autoQuestsSkipLowLevel") and "on" or "off",
      Setting("automateRuneclothDonations") and "on" or "off"))
    DEFAULT_CHAT_FRAME:AddMessage("/pfqauto on | off,  /pfqauto lowlevel on | off,  /pfqauto runecloth on | off")
  end
end
