---@class QuestieAuto
local QuestieAuto = QuestieLoader:CreateModule("QuestieAuto")

local function IsModifierHeld()
  return IsShiftKeyDown() or IsControlKeyDown() or IsAltKeyDown()
end

QuestieAuto.settings = QuestieAuto.settings or {}
QuestieAuto.settings.dailyOnly = QuestieAuto.settings.dailyOnly or false
QuestieAuto.settings.customExclusionString = QuestieAuto.settings.customExclusionString or ""
QuestieAuto.settings.exclusions = QuestieAuto.settings.exclusions or {}

QuestieAuto.defaultExclusions = QuestieAuto.defaultExclusions or {
  ["Allegiance to the Aldor"] = false,
  ["Allegiance to the Scryers"] = false,
}

local function StrTrim(str)
  return (str:gsub("^%s+", ""):gsub("%s+$", ""))
end

function QuestieAuto:RefreshExclusions()
  self.settings.exclusions = {}
  for questTitle, state in pairs(self.defaultExclusions) do
    self.settings.exclusions[questTitle] = state
  end

  local raw = self.settings.customExclusionString or ""
  if raw ~= "" then
    for name in string.gmatch(raw, "([^,\n]+)") do
      local trimmed = StrTrim(name)
      if trimmed ~= "" then
        self.settings.exclusions[trimmed] = false
      end
    end
  end
end

function QuestieAuto:SetCustomExclusions(raw)
  self.settings.customExclusionString = raw or ""
  self:RefreshExclusions()
end

local function IsQuestExcluded(title)
  if not title or title == "" then return false end
  local exclusions = QuestieAuto.settings.exclusions
  if not exclusions then return false end
  local value = exclusions[title]
  if value == nil then
    return false
  end
  return value == false
end

local function IsDailyFromFrequency(freq)
  if freq == nil then return false end
  if type(freq) == "boolean" then return freq end
  if type(freq) == "number" then
    -- 1 == daily on Wrath client
    return freq == 1
  end
  return false
end

local function IsAutoAcceptEnabled()
  if pfQuest_config and pfQuest_config["autoaccept"] ~= nil then
    return pfQuest_config["autoaccept"] == "1"
  end
  return Questie.db and Questie.db.profile and Questie.db.profile.autoaccept
end

local function IsAutoCompleteEnabled()
  if pfQuest_config and pfQuest_config["autocomplete"] ~= nil then
    return pfQuest_config["autocomplete"] == "1"
  end
  return Questie.db and Questie.db.profile and Questie.db.profile.autocomplete
end

local function ShouldAutoAccept(isDaily)
  if not IsAutoAcceptEnabled() then
    return false
  end
  local dailyOnly = pfQuest_config and pfQuest_config["autoacceptdailyonly"] == "1" or QuestieAuto.settings.dailyOnly
  if dailyOnly and not isDaily then
    return false
  end
  return true
end

local function ShouldAutoComplete()
  return IsAutoCompleteEnabled()
end

local function IsQuestCompleteByName(title, level)
  if not title then return false end
  for i = 1, GetNumQuestLogEntries() do
    local questTitle, _, _, _, _, _, complete = GetQuestLogTitle(i)
    if questTitle == title then
      if complete == 1 then
        return true
      end
      local numObjectives = GetNumQuestLeaderBoards(i)
      if numObjectives == 0 then
        return true
      end
      local allComplete = true
      for objIndex = 1, numObjectives do
        local _, _, objectiveComplete = GetQuestLogLeaderBoard(objIndex, i)
        if not objectiveComplete then
          allComplete = false
          break
        end
      end
      if allComplete then
        return true
      end
    end
  end
  return false
end

local function HandleGossip()
  if IsModifierHeld() then return end

  if ShouldAutoComplete() then
    local index = 1
    local title = select(1, GetGossipActiveQuests())
    while title do
      local level = select(2 + (index - 1) * 4, GetGossipActiveQuests())
      local isComplete = select(4 + (index - 1) * 4, GetGossipActiveQuests())
      if not IsQuestExcluded(title) and (isComplete or IsQuestCompleteByName(title, level)) then
        SelectGossipActiveQuest(index)
        return
      end
      index = index + 1
      title = select(1 + (index - 1) * 4, GetGossipActiveQuests())
    end
  end

  if Questie.db and Questie.db.profile and Questie.db.profile.autoaccept then
    local titleIndex = 1
    local available = { GetGossipAvailableQuests() }
    local stride = 6
    local i = 1
    while available[titleIndex] do
      local title = available[titleIndex]
      local frequency = available[titleIndex + 3]
      local isDaily = IsDailyFromFrequency(frequency)
      if not IsQuestExcluded(title) and ShouldAutoAccept(isDaily) then
        SelectGossipAvailableQuest(i)
        return
      end
      i = i + 1
      titleIndex = titleIndex + stride
    end
  end
end

local function HandleGreeting()
  Questie.Print("QuestieAuto: QUEST_GREETING")
  if IsModifierHeld() then return end

  if ShouldAutoComplete() then
    for questIndex = 1, GetNumActiveQuests() do
      local title, isComplete = GetActiveTitle(questIndex)
      local level = GetActiveLevel and GetActiveLevel(questIndex)
      if not IsQuestExcluded(title) and (isComplete or IsQuestCompleteByName(title, level)) then
        Questie.Print("QuestieAuto: selecting greeting active quest", title or "nil")
        SelectActiveQuest(questIndex)
        return
      end
    end
  end

  if Questie.db and Questie.db.profile and Questie.db.profile.autoaccept then
    for questIndex = 1, GetNumAvailableQuests() do
      local title = GetAvailableTitle(questIndex)
      local _, frequency = GetAvailableQuestInfo(questIndex)
      local isDaily = IsDailyFromFrequency(frequency)
      if not IsQuestExcluded(title) and ShouldAutoAccept(isDaily) then
      Questie.Print("QuestieAuto: selecting greeting available quest", title or "nil")
        SelectAvailableQuest(questIndex)
        return
      end
    end
  end
end

function QuestieAuto:GOSSIP_SHOW()
  HandleGossip()
end

function QuestieAuto:QUEST_GREETING()
  HandleGreeting()
end

function QuestieAuto:QUEST_DETAIL()
  if IsModifierHeld() then return end
  local title = GetTitleText()
  if IsQuestExcluded(title) then return end
  local isDaily = QuestIsDaily and QuestIsDaily()
  if ShouldAutoAccept(isDaily) then
    AcceptQuest()
  end
end

function QuestieAuto:QUEST_ACCEPT_CONFIRM()
  if IsModifierHeld() then return end
  local title = GetTitleText()
  if IsQuestExcluded(title) then return end
  local isDaily = QuestIsDaily and QuestIsDaily()
  if ShouldAutoAccept(isDaily) then
    ConfirmAcceptQuest()
  end
end

function QuestieAuto:QUEST_PROGRESS()
  if IsModifierHeld() then return end
  if not ShouldAutoComplete() then return end
  local title = GetTitleText()
  if IsQuestExcluded(title) then return end
  if IsQuestCompletable() then
    CompleteQuest()
  end
end

function QuestieAuto:QUEST_COMPLETE()
  if IsModifierHeld() then return end
  if not ShouldAutoComplete() then return end
  local title = GetTitleText()
  if IsQuestExcluded(title) then return end

  local rewardChoices = GetNumQuestChoices()
  if rewardChoices == 0 then
    GetQuestReward(-1)
  elseif rewardChoices == 1 then
    GetQuestReward(1)
  end
end

if pfQuest_config then
  QuestieAuto.settings.dailyOnly = pfQuest_config["autoacceptdailyonly"] == "1"
  QuestieAuto:SetCustomExclusions(pfQuest_config["autoexclusions"] or "")
else
  QuestieAuto:RefreshExclusions()
end

return QuestieAuto

