-- Survival trees: the trees Survival cuts wood from, tracked on the map the
-- way pfQuest tracks herbs and ore. Turtle's Survival is a gathering skill
-- (skill line 142); the client's LockType.dbc lists it as "Survival", whose
-- objects are "Trees" and whose action is "Cut Wood".
--
-- pfQuest checks skill levels only for its own herb, ore, rare and chest
-- lists, and treats any other list's values as faction letters, so every
-- tree is listed for both factions and this module picks which trees go in
-- the list instead.

local QoL = pfQuestOctoQoL
if not QoL.enabled then return end

local SURVIVAL = 142   -- SkillLine.dbc
local TRACK = "trees"
local ICON = "Interface\\Icons\\Trade_Survival"
-- like pfQuest's "auto" herbs and ore: trees up to 100 skill below yours
local AUTO_RANGE = 100

-- Object ID -> Survival skill needed. The client lists six Survival locks
-- (5, 125, 175, 225, 250, 270), but which tree has which lock is server data.
-- These follow the trees' zones; Dead, Tropical and Star Wood are a guess.
local TREES = {}
local function Tier(first, last, skill)
  for id = first, last do TREES[id] = skill end
end
Tier(2020267, 2020281, 5)    -- Simple Wood Tree, one per starting zone
TREES[2020301] = 5           -- Simple Wood Tree (Thalassian Highlands)
Tier(2020282, 2020287, 125)  -- Bright Wood
Tier(2020288, 2020297, 175)  -- Shade Wood Tree
TREES[2020309] = 175         -- Shade Wood Tree (Feralas)
TREES[2020300] = 225         -- Dead Wood Tree (Felwood)
TREES[2020298] = 250         -- Tropical Wood Tree (Moonwhisper Coast)
TREES[2020299] = 270         -- Star Wood Tree (Moonwhisper Coast)

QoL.AddConfig({
  { text = "|cff33ffccSurvival Trees|r", type = "header" },
  { text = "Track Survival Trees", default = "0", type = "checkbox", config = "survivalTrees" },
  { text = "Only Trees Within Your Survival Skill", default = "1", type = "checkbox", config = "survivalTreesAuto" },
})
QoL.SetDefaults({ survivalTrees = "0", survivalTreesAuto = "1" })

local function Setting(key)
  return pfQuest_config and pfQuest_config[key] == "1"
end

local function SurvivalSkill()
  return pfDatabase:GetPlayerSkill(SURVIVAL) or 0
end

-- the trees in pfQuest's database within min..max skill, as a pfQuest meta list
local function List(min, max)
  local list = {}
  for id, skill in pairs(TREES) do
    if pfDB["objects"]["data"][id] and skill >= min and skill <= max then
      list[-id] = "AH"
    end
  end
  return list
end

-- the skill range to show, nil when tracking is off
local function Range()
  if not Setting("survivalTrees") then return nil end
  if not Setting("survivalTreesAuto") then return 0, 1000 end
  local skill = SurvivalSkill()
  return math.max(skill - AUTO_RANGE, 0), skill
end

-- the skill levels whose trees are on the map, e.g. "5,125"; a skill-up only
-- retracks the 2,000-odd pins when it adds or drops one
local tracked

local function Tiers(min, max)
  local tiers = {}
  for _, skill in ipairs({ 5, 125, 175, 225, 250, 270 }) do
    if skill >= min and skill <= max then table.insert(tiers, skill) end
  end
  return table.concat(tiers, ",")
end

-- returns whether any trees are now tracked
local function Track(force)
  local min, max = Range()
  local key = min and Tiers(min, max) or "off"
  if not force and key == tracked then return key ~= "off" and key ~= "" end
  tracked = key

  if not min then
    pfDatabase:TrackMeta(TRACK, nil)
    return false
  end

  pfDB["meta"][TRACK] = List(min, max)
  if not next(pfDB["meta"][TRACK]) then
    pfDatabase:TrackMeta(TRACK, nil)
    return false
  end
  pfDatabase:TrackMeta(TRACK, {})
  return true
end

-- pfQuest replays saved tracking at login from pfDB["meta"], so the list has
-- to exist from the start; Track() narrows it once the skill is known
pfDB["meta"][TRACK] = List(0, 1000)
for id in pairs(TREES) do
  local name = QoL.Loc("objects", id)
  if name then pfDatabase.icons[name] = ICON end
end

-- tiers only change at a few skill values, so retracking on every skill-up
-- of any skill costs nothing but a comparison
local retrackSoon = QoL.Debounce(1, function() Track() end)

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("SKILL_LINES_CHANGED")
events:SetScript("OnEvent", function()
  if event == "PLAYER_ENTERING_WORLD" then
    this:UnregisterEvent("PLAYER_ENTERING_WORLD")
    Track(true)
  elseif Setting("survivalTrees") and Setting("survivalTreesAuto") then
    retrackSoon()
  end
end)

if pfQuestConfig then
  pfQuestConfig:HookScript("OnHide", function() Track() end)
end

SLASH_PFQUESTOCTOTREES1 = "/pfqtrees"
SlashCmdList["PFQUESTOCTOTREES"] = function(msg)
  local cmd = string.lower(msg or "")
  if cmd == "on" or cmd == "all" or cmd == "auto" then
    pfQuest_config["survivalTrees"] = "1"
    pfQuest_config["survivalTreesAuto"] = cmd == "all" and "0" or (cmd == "auto" and "1" or pfQuest_config["survivalTreesAuto"])
    local min, max = Range()
    if not Track(true) then
      QoL.Print("No Survival trees for your skill (" .. SurvivalSkill() .. "). They'll appear once you learn Survival.")
    elseif Setting("survivalTreesAuto") then
      QoL.Print(string.format("Tracking Survival trees for skill %d-%d (yours is %d).", min, max, SurvivalSkill()))
    else
      QoL.Print("Tracking all Survival trees.")
    end
  elseif cmd == "off" then
    pfQuest_config["survivalTrees"] = "0"
    Track(true)
    QoL.Print("Survival trees no longer tracked.")
  else
    local counts = {}
    for id, skill in pairs(TREES) do
      local data = pfDB["objects"]["data"][id]
      counts[skill] = (counts[skill] or 0) + (data and data["coords"] and table.getn(data["coords"]) or 0)
    end
    QoL.Print(string.format("Survival trees %s, your Survival skill %d.",
      Setting("survivalTrees") and (Setting("survivalTreesAuto") and "tracked within your skill" or "all tracked") or "not tracked",
      SurvivalSkill()))
    for _, skill in ipairs({ 5, 125, 175, 225, 250, 270 }) do
      DEFAULT_CHAT_FRAME:AddMessage(string.format("  skill %3d: %d spawns", skill, counts[skill] or 0))
    end
    DEFAULT_CHAT_FRAME:AddMessage("/pfqtrees on | auto | all | off")
  end
end
