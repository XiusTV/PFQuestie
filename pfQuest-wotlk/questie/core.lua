-- Questie scaffolding for pfQuest integration.
-- Phase 1: provide minimal module shells so subsequent ports can attach logic.

local addonName = ...

Questie = Questie or {}
Questie.AddonName = addonName or "Questie"
Questie.Version = Questie.Version or "embedded"

QuestieCompat = QuestieCompat or pfQuestCompat

-- Ensure module registry exists (created in compat/questie-loader.lua).
QuestieLoader = QuestieLoader or {}

-- Lightweight debug helpers; will be expanded once Questie logging is wired.
local function noop() end
local function concatArgs(...)
  local parts = {}
  for i = 1, select("#", ...) do
    parts[i] = tostring(select(i, ...))
  end
  return table.concat(parts, " ")
end

Questie.Print = Questie.Print or function(...)
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpfQuest|r " .. concatArgs(...))
  end
end
Questie.Error = Questie.Error or Questie.Print
Questie.Warning = Questie.Warning or noop
Questie.Debug = Questie.Debug or noop

-- Basic database/profile placeholders. Later phases will migrate pfQuest config.
Questie.db = Questie.db or {
  profile = {},
  char = {},
  global = {},
}

local profileDefaults = {
  trackerEnabled = true,
  autoaccept = false,
  autocomplete = false,
  trackerWidth = 280,
  trackerHeight = 400,
}

local charDefaults = {}

Questie.db.profile = Questie.db.profile or {}
for key, value in pairs(profileDefaults) do
  if Questie.db.profile[key] == nil then
    Questie.db.profile[key] = value
  end
end

Questie.db.char = Questie.db.char or {}
for key, value in pairs(charDefaults) do
  if Questie.db.char[key] == nil then
    Questie.db.char[key] = value
  end
end

-- Module skeletons ----------------------------------------------------------

local QuestieLib = QuestieLoader:CreateModule("QuestieLib")
QuestieLib.AddonPath = QuestieLib.AddonPath or "Interface\\AddOns\\pfQuest-wotlk"
QuestieLib.AddonPathSlash = QuestieLib.AddonPathSlash or "Interface/AddOns/pfQuest-wotlk"

function QuestieLib:GetAddonPath()
  return self.AddonPath
end

function QuestieLib:GetAddonPathSlash()
  return self.AddonPathSlash
end

function QuestieLib:GetQuestLocaleData(questId)
  if not pfDB or not pfDB["quests"] then return nil end
  local locTable = pfDB["quests"]["loc"]
  return locTable and locTable[questId] or nil
end

function QuestieLib:GetQuestData(questId)
  if not pfDB or not pfDB["quests"] then return nil end
  local dataTable = pfDB["quests"]["data"]
  return dataTable and dataTable[questId] or nil
end

local QuestieOptionsDefaults = QuestieLoader:CreateModule("QuestieOptionsDefaults")

function QuestieOptionsDefaults:Load()
  -- Stub: will be populated when Questie options merge.
  return {}
end

local QuestieOptions = QuestieLoader:CreateModule("QuestieOptions")

function QuestieOptions:OpenConfigWindow()
  Questie.Print("Questie options are not yet available in this build.")
end

local QuestieEventHandler = QuestieLoader:CreateModule("QuestieEventHandler")

function QuestieEventHandler:RegisterEarlyEvents()
  if self.initialized then return end

  local frame = CreateFrame("Frame")
  local events = {
    "GOSSIP_SHOW",
    "QUEST_GREETING",
    "QUEST_DETAIL",
    "QUEST_ACCEPT_CONFIRM",
    "QUEST_PROGRESS",
    "QUEST_COMPLETE",
  }

  for _, event in ipairs(events) do
    frame:RegisterEvent(event)
  end

  frame:SetScript("OnEvent", function(_, event, ...)
    local QuestieAutoModule = QuestieLoader:ImportModule("QuestieAuto")
    if QuestieAutoModule and QuestieAutoModule[event] then
      QuestieAutoModule[event](QuestieAutoModule, ...)
    end
  end)

  self.frame = frame
  self.initialized = true
end

QuestieEventHandler:RegisterEarlyEvents()

local QuestieDB = QuestieLoader:CreateModule("QuestieDB")

local questFieldMap = {
  questLevel = "lvl",
  requiredLevel = "min",
  nextQuestInChain = "next",
}

function QuestieDB.QueryQuestSingle(questId, field)
  local data = QuestieLib:GetQuestData(questId)
  if not data then return nil end

  local mapped = questFieldMap[field]
  if mapped then
    return data[mapped]
  end

  return data[field]
end

function QuestieDB.GetQuest(questId)
  if not questId then return nil end

  local data = QuestieLib:GetQuestData(questId) or {}
  local locData = QuestieLib:GetQuestLocaleData(questId) or {}

  return {
    Id = questId,
    name = locData.T,
    objective = locData.O,
    description = locData.D,
    questLevel = data.lvl,
    requiredLevel = data.min,
    nextQuestInChain = data.next,
    sourceItemId = data.srcitem,
  }
end

local QuestiePlayer = QuestieLoader:CreateModule("QuestiePlayer")

function QuestiePlayer:GetLocalizedClassName()
  local _, classFile = UnitClass("player")
  return LOCALIZED_CLASS_NAMES_MALE[classFile] or classFile or "UNKNOWN"
end

function QuestiePlayer:GetPlayerLevel()
  return UnitLevel("player")
end

local QuestieQuest = QuestieLoader:CreateModule("QuestieQuest")

function QuestieQuest:SmoothReset()
  -- No-op placeholder.
end

local QuestieMap = QuestieLoader:CreateModule("QuestieMap")

function QuestieMap:Update()
  -- To be implemented when Questie map logic ports over.
end

local QuestieTooltips = QuestieLoader:ImportModule("QuestieTooltips")

function QuestieTooltips:ResetTooltips()
  -- Placeholder for tooltip cache management.
end

-- Keep scaffolding minimal; additional modules will be added as migration advances.

