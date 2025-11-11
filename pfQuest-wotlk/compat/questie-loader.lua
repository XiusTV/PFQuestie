--[[
  Questie loader bridge
  Replicates Questie's lightweight module registry so we can progressively port
  Questie modules without rewriting their wiring.
]]

if not QuestieLoader then
  ---@class QuestieLoader
  QuestieLoader = {}

  local modules = {}
  QuestieLoader._modules = modules

  ---@generic T
  ---@param name `T`
  ---@return T|{ private: table }
  function QuestieLoader:CreateModule(name)
    if not modules[name] then
      modules[name] = { private = {} }
    end

    return modules[name]
  end

  QuestieLoader.ImportModule = QuestieLoader.CreateModule

  function QuestieLoader:PopulateGlobals()
    for name, module in pairs(modules) do
      _G[name] = module
    end
  end
end

pfQuestCompat.QuestieModules = QuestieLoader._modules

-- Provide a minimal Questie object so upcoming ports can bind to it.
Questie = Questie or {}

local function defaultPrinter(...)
  local parts = {}
  for i = 1, select("#", ...) do
    parts[i] = tostring(select(i, ...))
  end
  local msg = table.concat(parts, " ")
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpfQuest|r " .. msg)
  else
    print("|cff33ffccpfQuest|r", msg)
  end
end

Questie.Print = Questie.Print or defaultPrinter
Questie.Error = Questie.Error or defaultPrinter
Questie.Warning = Questie.Warning or defaultPrinter
Questie.Debug = Questie.Debug or function() end

-- Allow Ace-style addon creation once libraries are embedded.
if pfQuestAce and pfQuestAce.Addon and not Questie._isAceAddon then
  Questie = pfQuestAce.Addon:NewAddon(Questie, "Questie",
    "AceEvent-3.0", "AceConsole-3.0", "AceTimer-3.0")
  Questie._isAceAddon = true
end

