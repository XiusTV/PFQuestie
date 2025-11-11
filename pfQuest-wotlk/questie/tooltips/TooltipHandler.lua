local QuestieTooltips = QuestieLoader:ImportModule("QuestieTooltips")
local TooltipBridge = QuestieLoader:ImportModule("pfQuestTooltipBridge")
local PartySync = QuestieLoader:ImportModule("QuestiePartySync")

local Handler = QuestieLoader:CreateModule("QuestieTooltipHandler")
Handler.lastUnitGuid = nil

-- Reset lastUnitGuid on tooltip clear to allow re-processing
GameTooltip:HookScript("OnTooltipCleared", function()
  Handler.lastUnitGuid = nil
end)

local UnitGUID = UnitGUID

local function ShouldShowTooltips()
  if pfQuest_config and pfQuest_config["showtooltips"] ~= nil then
    return pfQuest_config["showtooltips"] == "1"
  end
  return true
end

local function AppendTooltipLines(tooltip, key)
  if not tooltip or not key then return end
  local data = QuestieTooltips:GetTooltip(key)
  local partyLines = PartySync and PartySync.GetTooltipLines and PartySync:GetTooltipLines(key) or nil
  
  if not data and not partyLines then return end

  if pfQuest_config and pfQuest_config["showids"] == "1" then
    local id = string.sub(key, 3)
    if string.sub(key, 1, 2) == "m_" then
      tooltip:AddDoubleLine("NPC ID", "|cFFFFFFFF" .. id .. "|r")
    elseif string.sub(key, 1, 2) == "i_" then
      tooltip:AddDoubleLine("Item ID", "|cFFFFFFFF" .. id .. "|r")
    elseif string.sub(key, 1, 2) == "o_" then
      tooltip:AddDoubleLine("Object ID", "|cFFFFFFFF" .. id .. "|r")
    end
  end

  local added = false
  if data then
    for _, entry in pairs(data) do
      if entry.lines then
        for _, line in ipairs(entry.lines) do
          tooltip:AddLine(line)
        end
        added = true
      elseif entry.text then
        tooltip:AddLine(entry.text)
        added = true
      end
    end
  end

  if partyLines then
    for _, line in ipairs(partyLines) do
      tooltip:AddLine(line)
    end
    added = true
  end

  if added then
    tooltip:Show()
  end

  return added
end

function Handler:HandleUnit(tooltip)
  if not ShouldShowTooltips() then return end
  local _, unitToken = tooltip:GetUnit()
  if not unitToken then return end

  local guid = UnitGUID(unitToken)
  if not guid then return end
  
  -- Parse GUID - try multiple formats for compatibility
  local guidType, npcId
  if string.find(guid, "^Creature%-") or string.find(guid, "^Vehicle%-") then
    -- Standard format: Creature-0-ServerID-ZoneUID-SpawnID-CreatureID-000000000
    guidType, _, _, _, _, npcId = strsplit("-", guid)
  else
    -- Try alternative parsing methods
    -- Method 1: Extract last number segment
    npcId = string.match(guid, "%-(%d+)$")
    if npcId then
      guidType = "Creature" -- Assume creature if we can extract ID
    else
      -- Method 2: Try hex format
      local hexId = string.match(guid, "0x%x+%x%x%x%x(%x%x%x%x%x%x)$")
      if hexId then
        npcId = tonumber(hexId, 16)
        guidType = "Creature"
      end
    end
  end
  
  if not guidType or (guidType ~= "Creature" and guidType ~= "Vehicle") then return end
  if not npcId then return end
  
  npcId = tonumber(npcId)
  if not npcId then return end

  if Handler.lastUnitGuid == guid then return end
  Handler.lastUnitGuid = guid

  AppendTooltipLines(tooltip, "m_" .. npcId)
end

function Handler:HandleItem(tooltip)
  if not ShouldShowTooltips() then return end
  local _, link = tooltip:GetItem()
  if not link then return end

  local itemId = tonumber(link:match("item:(%d+)"))
  if not itemId then return end

  AppendTooltipLines(tooltip, "i_" .. itemId)
end

function Handler:HandleNode(meta, tooltip)
  if not ShouldShowTooltips() then return end
  if not TooltipBridge or not TooltipBridge.GetKey then return end
  local key = TooltipBridge:GetKey(meta)
  if not key then return end
  AppendTooltipLines(tooltip or GameTooltip, key)
end

return Handler

