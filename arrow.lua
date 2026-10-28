-- Corpse arrow: while you're a ghost, pfQuest's route arrow points at your
-- corpse instead of your quests. Ported from the pfQuest-octo pack's
-- pfquest-arrow.lua (Shadowtoots' module for pfQuest-turtle). That module also
-- added an arrow scale setting; brues-code's pfQuest has one of its own.
--
-- The old version only worked while a quest target kept the arrow shown, read
-- the corpse from map coordinates, and left the corpse text on the arrow after
-- you revived. This one shows the arrow itself, uses world coordinates like
-- pfQuest's arrow does, and puts pfQuest's text back.

local QoL = pfQuestOctoQoL
if not QoL.enabled or not UnitPosition or not pfQuest.route or not pfQuest.route.arrow then return end

local arrow = pfQuest.route.arrow

local corpseMessages = {
  "Skill Issue, have fun running back",
  "Git Gud Scrub",
  "You Died LOL",
  "Walk of Shame Initiated",
  "Corpse Run Express",
  "Better Luck Next Time",
  "RIP Your Repair Bill",
  "Death Tax Collector Awaits",
  "Your Body is Over There Dummy",
  "Congratulations, You're Dead",
  "Achievement Unlocked: Floor Tank",
  "Press F to Pay Respects",
  "This is Why We Can't Have Nice Things",
  "Maybe Try Reading the Tactics Next Time",
  "Outstanding Move, Chief",
  "Welcome to the Spirit World",
  "Ghost Mode: ACTIVATED",
  "That Went Well",
  "Professional Grave Digger",
  "Another Happy Landing",
  "Task Failed Successfully",
  "Speedrun: Any% Death Category",
  "You've Been Disconnected from Life",
  "Error 404: HP Not Found",
  "Critical Hit: Your Pride",
  "Respawn Timer: Your Dignity",
  "New Personal Best: Worst Decision",
  "Plot Twist: You're the Bad Guy",
  "Congratulations, You Played Yourself",
  "Tutorial Complete: How to Die",
  "Achievement: First Time?",
  "Pro Tip: Don't Die Next Time",
  "Your Performance Review: Needs Improvement",
  "Status Update: Currently Deceased",
  "That's a Bold Strategy Cotton",
  "The Afterlife Called, They're Expecting You",
  "Death Certificate: Cause of Death - Bad Decision",
}

QoL.AddConfig({
  { text = "|cff33ffccCorpse Arrow|r", type = "header" },
  { text = "Point the Arrow at Your Corpse", default = "1", type = "checkbox", config = "corpseArrow" },
})
QoL.SetDefaults({ corpseArrow = "1" })

local corpse        -- { north, west, instanceID } of your body, while you're dead
local showing       -- the corpse is on the arrow
local saved         -- pfQuest's arrow texts from before, to put back

local function modulo(val, by)
  return val - floor(val / by) * by
end

local function Enabled()
  return pfQuest_config and pfQuest_config["corpseArrow"] == "1" and pfQuest_config["arrow"] ~= "0"
end

-- Logged in or reloaded as a ghost, so the death wasn't seen: read the corpse
-- off the zone map instead. The map has to show your own zone for that.
local function CorpseFromMap()
  if WorldMapFrame:IsShown() then return end
  SetMapToCurrentZone()
  local x, y = GetCorpseMapPosition()
  local uiMapID = C_Map.GetBestMapForUnit("player")
  if not x or (x == 0 and y == 0) or not uiMapID then return end
  local instanceID, world = C_Map.GetWorldPosFromMapPos(uiMapID, { x = x, y = y })
  if world then
    corpse = { world.x, world.y, instanceID }
  end
end

-- the corpse's direction and distance, or nil while it can't be pointed at
local function CorpseTarget()
  if not Enabled() or not UnitIsGhost("player") then return end
  if not corpse then CorpseFromMap() end
  if not corpse then return end
  local pWest, pNorth, _, instanceID = UnitPosition("player")
  if not pNorth or instanceID ~= corpse[3] then return end
  local dNorth, dWest = corpse[1] - pNorth, corpse[2] - pWest
  return math.atan2(dWest, dNorth) - GetPlayerFacing(), sqrt(dNorth * dNorth + dWest * dWest)
end

local function ShowCorpse(angle, yards)
  if not showing then
    showing = true
    saved = { arrow.title:GetText(), arrow.description:GetText() }
    arrow.title:SetText("Corpse")
    arrow.description:SetText("|cffff0000" .. corpseMessages[math.random(table.getn(corpseMessages))] .. "|r")
    arrow.texture:SetAlpha(0)
  end

  -- the same arrow drawing pfQuest uses: 108 directions on a 9 x 12 sheet
  local perc = math.abs((math.pi - math.abs(angle)) / math.pi)
  local r, g, b = pfUI.api.GetColorGradient(floor(perc * 100) / 100)
  local cell = modulo(floor(angle / (math.pi * 2) * 108 + 0.5), 108)
  local column, row = modulo(cell, 9), floor(cell / 9)
  arrow.model:SetTexCoord((column * 56) / 512, ((column + 1) * 56) / 512, (row * 42) / 512, ((row + 1) * 42) / 512)
  arrow.model:SetVertexColor(r, g, b)
  arrow.model:SetAlpha(1)

  local distance = floor(yards)
  if distance ~= arrow.distance.number then
    arrow.distance:SetText(string.format("|cffaaaaaa%s: %d", pfQuest_Loc["Distance"] or "Distance", distance))
    arrow.distance.number = distance
  end
end

local function RestoreArrow()
  showing = nil
  if saved then
    arrow.title:SetText(saved[1])
    arrow.description:SetText(saved[2])
    saved = nil
  end
  -- pfQuest only rewrites the distance when the number changes
  arrow.distance.number = nil
end

local OnUpdate = arrow:GetScript("OnUpdate")
arrow:SetScript("OnUpdate", function()
  local angle, yards = CorpseTarget()
  if angle then
    ShowCorpse(angle, yards)
    return
  end
  if showing then RestoreArrow() end
  if OnUpdate then OnUpdate() end
end)

-- pfQuest only shows the arrow when a quest needs it, and a hidden frame gets
-- no OnUpdate, so show it here while there's a corpse to point at
local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_DEAD")
watcher:RegisterEvent("PLAYER_ALIVE")
watcher:RegisterEvent("PLAYER_UNGHOST")
watcher:SetScript("OnEvent", function()
  if event == "PLAYER_DEAD" then
    local west, north, _, instanceID = UnitPosition("player")
    corpse = north and { north, west, instanceID } or nil
  elseif not UnitIsDeadOrGhost("player") then
    corpse = nil
  end
end)
watcher:SetScript("OnUpdate", function()
  this.elapsed = (this.elapsed or 0) + arg1
  if this.elapsed < 0.5 then return end
  this.elapsed = 0
  if not arrow:IsShown() and CorpseTarget() then
    arrow:Show()
  end
end)

SLASH_PFQUESTOCTOARROW1 = "/pfqarrow"
SlashCmdList["PFQUESTOCTOARROW"] = function(msg)
  local cmd = string.lower(msg or "")
  if cmd == "on" or cmd == "off" then
    pfQuest_config["corpseArrow"] = cmd == "on" and "1" or "0"
    QoL.Print("Corpse arrow " .. (cmd == "on" and "enabled" or "disabled") .. ".")
  else
    QoL.Print("Corpse arrow " .. (Enabled() and "enabled" or "disabled") .. ". /pfqarrow on | off")
  end
end
