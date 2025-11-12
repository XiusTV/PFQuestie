---@class QuestieAnnounce
-- Quest announcement module - handles quest accepted, finished objectives, and remaining objectives
local QuestieAnnounce = QuestieLoader:CreateModule("QuestieAnnounce")

-- Configuration helper
local function GetConfig()
  return pfQuest_config or {}
end

-- Migrate old bronzebeard config keys to new ones
local function MigrateConfig()
  local config = GetConfig()
  
  -- Migrate from bronzebeard keys if they exist and new keys don't
  if config["bronzebeardannounceFinished"] and not config["announceFinishedObjectives"] then
    config["announceFinishedObjectives"] = config["bronzebeardannounceFinished"]
  end
  
  if config["bronzebeardannounceRemaining"] and not config["announceRemainingObjectives"] then
    config["announceRemainingObjectives"] = config["bronzebeardannounceRemaining"]
  end
end

-- Handle quest accepted
function QuestieAnnounce:OnQuestAccepted(questTitle, questId, qlogid)
  local config = GetConfig()
  
  -- Check if announce is enabled
  if config["announceQuestAccepted"] ~= "1" then
    return
  end
  
  -- Only announce if in a party
  if GetNumPartyMembers() == 0 then
    return
  end
  
  if questTitle then
    local message = "[pfQuest] I accepted quest: " .. questTitle
    SendChatMessage(message, "PARTY")
  end
end

-- Handle quest objective updates via UI_INFO_MESSAGE
function QuestieAnnounce:OnQuestUpdate(message)
  local config = GetConfig()
  
  -- Only announce if in a party
  if GetNumPartyMembers() == 0 then
    return
  end
  
  if not message or type(message) ~= "string" then
    return
  end
  
  -- Parse objective update message (format: "Item Name: X/Y")
  local itemName, numItems, numNeeded = string.match(message, "(.*):%s*([-%d]+)%s*/%s*([-%d]+)%s*$")
  
  if itemName and numItems and numNeeded then
    local iNumItems = tonumber(numItems)
    local iNumNeeded = tonumber(numNeeded)
    local stillNeeded = iNumNeeded - iNumItems
    local questName = self:GetQuestNameForObjective(itemName)
    local outMessage
    
    if stillNeeded < 1 then
      -- Objective finished
      if config["announceFinishedObjectives"] == "1" then
        if questName then
          outMessage = "[pfQuest] I have finished " .. itemName .. " for quest: " .. questName .. ". " .. iNumItems .. "/" .. iNumNeeded
        else
          outMessage = "[pfQuest] I have finished " .. itemName .. ". " .. iNumItems .. "/" .. iNumNeeded
        end
      end
    else
      -- Objective remaining
      if config["announceRemainingObjectives"] == "1" then
        if questName then
          outMessage = "[pfQuest] " .. itemName .. " for " .. questName .. ": (" .. iNumItems .. "/" .. iNumNeeded .. "). " .. stillNeeded .. " Remaining."
        else
          outMessage = "[pfQuest] " .. itemName .. ": (" .. iNumItems .. "/" .. iNumNeeded .. "). " .. stillNeeded .. " Remaining."
        end
      end
    end
    
    if outMessage and outMessage ~= "" then
      SendChatMessage(outMessage, "PARTY")
    end
  end
end

-- Get quest name for an objective item
function QuestieAnnounce:GetQuestNameForObjective(objectiveName)
  local numQuestLogEntries = GetNumQuestLogEntries()
  
  for i = 1, numQuestLogEntries do
    local questTitle, level, questTag, suggestedGroup, isHeader, isCollapsed, isComplete = GetQuestLogTitle(i)
    
    if not isHeader and questTitle then
      SelectQuestLogEntry(i)
      local numObjectives = GetNumQuestLeaderBoards()
      
      for j = 1, numObjectives do
        local description, type, finished = GetQuestLogLeaderBoard(j)
        
        if description then
          local objName = string.match(description, "(.*):%s*[-%d]+%s*/%s*[-%d]+%s*$")
          
          if objName and string.find(string.lower(objName), string.lower(objectiveName), 1, true) then
            return questTitle
          end
        end
      end
    end
  end
  
  return nil
end

-- Initialize the announce module
function QuestieAnnounce:Initialize()
  -- Register for UI_INFO_MESSAGE to catch objective updates
  if not self.eventFrame then
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("UI_INFO_MESSAGE")
    frame:SetScript("OnEvent", function(self, event, message)
      if event == "UI_INFO_MESSAGE" and message then
        QuestieAnnounce:OnQuestUpdate(message)
      end
    end)
    self.eventFrame = frame
  end
end

-- Initialize on PLAYER_LOGIN
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event)
  if event == "PLAYER_LOGIN" then
    MigrateConfig()
    QuestieAnnounce:Initialize()
    self:UnregisterEvent("PLAYER_LOGIN")
  end
end)

return QuestieAnnounce

