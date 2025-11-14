--[[
  Ace3 compatibility bootstrap
  This shim attempts to acquire the minimal Ace3 toolset Questie relies on.
  If the embedded libraries are not yet present they will simply be left nil;
  dependent code should guard against missing libs until bundling is complete.
]]

pfQuestAce = pfQuestAce or { libs = {} }
pfQuestCompat = pfQuestCompat or {}

local libs = pfQuestAce.libs

local function Acquire(libName)
  if type(LibStub) ~= "function" then return nil end

  local ok, lib = pcall(LibStub, libName, true)
  if ok then
    return lib
  end

  return nil
end

local needed = {
  "AceAddon-3.0",
  "AceEvent-3.0",
  "AceConsole-3.0",
  "AceTimer-3.0",
  "AceBucket-3.0",
  "AceHook-3.0",
  "AceComm-3.0",
  "AceSerializer-3.0",
  "AceDB-3.0",
  "AceDBOptions-3.0",
  "AceGUI-3.0",
  "AceConfigRegistry-3.0",
  "AceConfigDialog-3.0",
  "AceConfigCmd-3.0",
  "LibSharedMedia-3.0",
  "HereBeDragons-2.0",
  "HereBeDragons-Pins-2.0",
}

for _, name in ipairs(needed) do
  libs[name] = libs[name] or Acquire(name)
end

function pfQuestAce:Get(libName)
  return libs[libName]
end

function pfQuestAce:IsAvailable(libName)
  return libs[libName] ~= nil
end

function pfQuestAce:Embed(target, ...)
  for i = 1, select("#", ...) do
    local libName = select(i, ...)
    local lib = libs[libName]
    if lib and type(lib.Embed) == "function" then
      lib:Embed(target)
    end
  end

  return target
end

-- convenience re-exports for consumers that expect globals
pfQuestAce.Addon = libs["AceAddon-3.0"]
pfQuestAce.Event = libs["AceEvent-3.0"]
pfQuestAce.Console = libs["AceConsole-3.0"]
pfQuestAce.Timer = libs["AceTimer-3.0"]
pfQuestAce.Bucket = libs["AceBucket-3.0"]
pfQuestAce.Hook = libs["AceHook-3.0"]
pfQuestAce.Comm = libs["AceComm-3.0"]
pfQuestAce.Serializer = libs["AceSerializer-3.0"]
pfQuestAce.DB = libs["AceDB-3.0"]
pfQuestAce.DBOptions = libs["AceDBOptions-3.0"]
pfQuestAce.GUI = libs["AceGUI-3.0"]
pfQuestAce.ConfigRegistry = libs["AceConfigRegistry-3.0"]
pfQuestAce.ConfigDialog = libs["AceConfigDialog-3.0"]
pfQuestAce.ConfigCmd = libs["AceConfigCmd-3.0"]
pfQuestAce.Media = libs["LibSharedMedia-3.0"]
pfQuestAce.HBD = libs["HereBeDragons-2.0"]
pfQuestAce.HBDPins = libs["HereBeDragons-Pins-2.0"]

pfQuestCompat.Ace = pfQuestAce

local warned = false

local function WarnMissing()
  if warned then return end
  warned = true

  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpfQuest|r Ace compatibility shim active, waiting for embedded libraries.")
  end
end

for _, name in ipairs(needed) do
  if not libs[name] then
    WarnMissing()
    break
  end
end

