local Tracker = QuestieLoader:ImportModule("QuestieTracker")
local compat = pfQuestCompat

local function ShouldTrackerBeEnabled()
  if not pfQuest_config then
    pfQuest_config = {}
  end

  local showtracker = pfQuest_config["showtracker"]
  if showtracker == nil then
    return true
  end
  return showtracker == "1"
end

local function InitializeTracker()
  if not Tracker then return end

  if Tracker.SyncProfileFromConfig then
    Tracker:SyncProfileFromConfig()
  end

  if ShouldTrackerBeEnabled() then
    if Tracker.Enable then
      Tracker:Enable()
    elseif Tracker.Initialize then
      Tracker:Initialize()
    end
  else
    if Tracker.Disable then
      Tracker:Disable()
    end
  end
end

local configLoaded = false

local function UpdateConfigLoaded(addonName)
  if addonName == "pfQuest-wotlk" or addonName == "pfQuest-tbc" or addonName == "pfQuest" then
    configLoaded = true
  end
end

local configCheckFrame = CreateFrame("Frame")
configCheckFrame:RegisterEvent("ADDON_LOADED")
configCheckFrame:SetScript("OnEvent", function(self, event, addonName)
  UpdateConfigLoaded(addonName)
  if configLoaded and Questie and Questie.db and Questie.db.profile then
    InitializeTracker()
  end
end)

if pfQuest_config and pfQuest_config["showtracker"] ~= nil then
  configLoaded = true
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(self, event, addonName)
  if event == "ADDON_LOADED" then
    UpdateConfigLoaded(addonName)
  end

  if Questie and Questie.db and Questie.db.profile and configLoaded then
    InitializeTracker()
    self:UnregisterAllEvents()
    self:SetScript("OnUpdate", nil)
  end
end)

local attempts = 0
initFrame:SetScript("OnUpdate", function(self)
  attempts = attempts + 1
  if pfQuest_config and pfQuest_config["showtracker"] ~= nil then
    configLoaded = true
  end

  if Questie and Questie.db and Questie.db.profile and configLoaded then
    InitializeTracker()
    self:UnregisterAllEvents()
    self:SetScript("OnUpdate", nil)
  elseif attempts > 1000 then
    self:UnregisterAllEvents()
    self:SetScript("OnUpdate", nil)
  end
end)

