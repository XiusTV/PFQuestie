local PartySync = QuestieLoader:CreateModule("QuestiePartySync")
PartySync.private = PartySync.private or {}

local AceFacade = pfQuestAce
local AceComm = AceFacade and AceFacade:Get("AceComm-3.0")
local AceSerializer = AceFacade and AceFacade:Get("AceSerializer-3.0")
local AceTimer = AceFacade and AceFacade:Get("AceTimer-3.0")
local AceEvent = AceFacade and AceFacade:Get("AceEvent-3.0")

local function DebugPrint(...)
  if not PartySync or not PartySync.debug then return end
  local message = "|cff33ffccpf|cffffffffQuest|r|cff66aaffParty|r:"
  for i = 1, select("#", ...) do
    local part = select(i, ...)
    if type(part) == "table" then
      part = "<table>"
    end
    message = message .. " " .. tostring(part)
  end
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage(message)
  end
end

-- Use "pfQuest" prefix since RegisterAddonMessagePrefix doesn't exist in Wrath
-- We'll encode our message type in the payload to distinguish from other pfQuest messages
PartySync.prefix = "pfQuest"
PartySync.subPrefix = "pfQPS" -- Sub-prefix encoded in payload
PartySync.version = 2
PartySync.remoteTTL = 180
PartySync.localObjectives = PartySync.localObjectives or {}
PartySync.pendingKeys = PartySync.pendingKeys or {}
PartySync.remoteByKey = PartySync.remoteByKey or {}
PartySync.lastRoster = PartySync.lastRoster or {}
PartySync._broadcastHandle = PartySync._broadcastHandle or nil
PartySync._yellState = PartySync._yellState or {
  waiting = {},
  timer = nil,
  lastFlush = 0,
}
PartySync.initialized = PartySync.initialized or false

local function ResolveDistribution()
  if GetNumRaidMembers and GetNumRaidMembers() > 0 then
    return "RAID"
  end
  if GetNumPartyMembers and GetNumPartyMembers() > 0 then
    return "PARTY"
  end
  return nil
end

local badYellLocations = {
  [1453] = true,
  [1455] = true,
  [1457] = true,
  [1947] = true,
  [1454] = true,
  [1456] = true,
  [1458] = true,
  [1954] = true,
  [1955] = true,
  [1459] = true,
  [1460] = true,
  [1461] = true,
  [1957] = true,
}

local function IsYellAllowed()
  if pfQuest_config and pfQuest_config["disablepartyells"] == "1" then
    return false
  end
  local mapId = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  if mapId and badYellLocations[mapId] then
    return false
  end
  return true
end

local function SerializeYellPayload(payload)
  if not payload or not payload.k then return nil end
  return table.concat({ payload.k, payload.q or 0, payload.o or 0, payload.f or 0, payload.r or 0 }, ":")
end

local function ParseYellPayload(message)
  if not message then return nil end
  local key, q, o, f, r = string.match(message, "^([^:]+):(%d+):(%d+):(%d+):(%d+)$")
  if not key then return nil end
  return {
    k = key,
    q = tonumber(q),
    o = tonumber(o),
    f = tonumber(f),
    r = tonumber(r),
  }
end

local function GetLocalPlayerName()
  local name = UnitName and UnitName("player")
  if name and name ~= "" then
    return name
  end
  return "player"
end

local function NormalizePlayerName(name)
  if not name then return nil end
  return string.match(name, "^[^%-]+") or name
end

local function BuildGroupRoster()
  local roster = {}
  roster[GetLocalPlayerName()] = true

  if GetNumRaidMembers and GetNumRaidMembers() > 0 then
    for i = 1, GetNumRaidMembers() do
      local name = UnitName("raid" .. i)
      if name and name ~= "" then
        roster[name] = true
      end
    end
  elseif GetNumPartyMembers and GetNumPartyMembers() > 0 then
    for i = 1, GetNumPartyMembers() do
      local name = UnitName("party" .. i)
      if name and name ~= "" then
        roster[name] = true
      end
    end
  end

  return roster
end

local function BuildYellPayloadFromObjective(objective)
  if not objective or not objective.key then return nil end
  return {
    k = objective.key,
    q = objective.questId or 0,
    o = objective.objectiveIndex or 0,
    f = objective.fulfilled or 0,
    r = objective.required or 0,
  }
end

local function BuildYellPayloadFromEntry(entry)
  if not entry or not entry.key then return nil end
  return {
    k = entry.key,
    q = entry.questId or 0,
    o = entry.objectiveIndex or 0,
    f = entry.fulfilled or 0,
    r = entry.required or 0,
  }
end

function PartySync:SendFullSync(distribution, target)
  self:Initialize()
  if not self.initialized then return end
  if not (self.serializer and self.SendCommMessage) then return end

  distribution = distribution or (target and "WHISPER" or ResolveDistribution())
  
  if not distribution then return end
  if distribution == "WHISPER" and not target then return end

  local objectiveCount = 0
  if self.localObjectives then
    for _ in pairs(self.localObjectives) do objectiveCount = objectiveCount + 1 end
  end

  for key, data in pairs(self.localObjectives) do
    if type(data) == "table" then
      local payload = {
        v = self.version,
        t = "obj",
        p = self.subPrefix, -- Sub-prefix to identify our messages
        key = key,
        questId = data.questId,
        objectiveIndex = data.objectiveIndex,
        fulfilled = data.fulfilled,
        required = data.required,
        name = data.name,
      }

      local serialized = self.serializer:Serialize(payload)
      if serialized and type(serialized) == "string" and #serialized > 0 then
        if distribution == "WHISPER" then
          self:SendCommMessage(self.prefix, serialized, "WHISPER", target)
        else
          self:SendCommMessage(self.prefix, serialized, distribution)
        end
      end
    end
  end
end

function PartySync:RequestSync(target)
  if not target or target == GetLocalPlayerName() then return end
  self:Initialize()
  if not self.initialized then return end
  if not (self.serializer and self.SendCommMessage) then return end

  local payload = {
    v = self.version,
    t = "req",
    p = self.subPrefix, -- Sub-prefix to identify our messages
  }

  local serialized = self.serializer:Serialize(payload)
  if serialized and type(serialized) == "string" and #serialized > 0 then
    self:SendCommMessage(self.prefix, serialized, "WHISPER", target)
    DebugPrint("request sync", target)
  end
end

function PartySync:HandleRosterChange(roster)
  self:Initialize()
  if not self.initialized then return false end

  roster = roster or BuildGroupRoster()
  self.lastRoster = self.lastRoster or {}

  local added = {}
  for name in pairs(roster) do
    if name ~= GetLocalPlayerName() and not self.lastRoster[name] then
      table.insert(added, name)
    end
  end

  self.lastRoster = roster
  if #added > 0 then
    DebugPrint("new members", table.concat(added, ","))
  end

  for _, name in ipairs(added) do
    self:RequestSync(name)
  end

  return #added > 0
end

function PartySync:IsEnabled()
  if pfQuest_config then
    if pfQuest_config["tooltippartyprogress"] ~= "0" then
      return true
    end
    if pfQuest_config["focuspartyshare"] == "1" or pfQuest_config["focuspartyreceive"] == "1" then
      return true
    end
  end
  return false
end

function PartySync:Initialize()
  if self.initialized then return end
  
  -- Re-acquire Ace libraries dynamically (they might not have been loaded when this file first executed)
  local facade = pfQuestAce
  
  -- Try to re-acquire libraries via LibStub if they're missing
  local function AcquireLib(libName)
    if not LibStub then return nil end
    -- Try LibStub:GetLibrary first (direct method call)
    if LibStub.GetLibrary then
      local lib = LibStub:GetLibrary(libName, true)
      if lib then
        -- Update pfQuestAce.libs if it exists
        if facade and facade.libs then
          facade.libs[libName] = lib
        end
        return lib
      end
    end
    -- Fallback: try calling LibStub as a function (via metatable)
    local ok, lib = pcall(LibStub, libName, true)
    if ok and lib then
      -- Update pfQuestAce.libs if it exists
      if facade and facade.libs then
        facade.libs[libName] = lib
      end
      return lib
    end
    return nil
  end
  
  -- Try to get libraries from pfQuestAce first, then try LibStub directly
  local comm = (facade and facade:Get("AceComm-3.0")) or AcquireLib("AceComm-3.0")
  local serializer = (facade and facade:Get("AceSerializer-3.0")) or AcquireLib("AceSerializer-3.0")
  local timer = (facade and facade:Get("AceTimer-3.0")) or AcquireLib("AceTimer-3.0")
  local event = (facade and facade:Get("AceEvent-3.0")) or AcquireLib("AceEvent-3.0")
  
  if not (facade and comm and serializer and timer and event) then 
    if self.debug then
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest|r|cff66aaffPartySync|r: Initialize() - missing Ace libraries (comm=" .. tostring(comm) .. " serializer=" .. tostring(serializer) .. " timer=" .. tostring(timer) .. " event=" .. tostring(event) .. ")")
    end
    return 
  end

  -- Store libraries in self for later use
  self.serializer = serializer

  facade:Embed(self, "AceComm-3.0", "AceEvent-3.0", "AceTimer-3.0")

  DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest|r|cff66aaffPartySync|r: Initialize() - Registering comm prefix=" .. self.prefix)
  
  -- Try to register prefix BEFORE RegisterComm (Wrath compatibility)
  -- In Wrath, RegisterAddonMessagePrefix might need to be called directly
  local prefixRegistered = false
  if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
    local ok, err = pcall(C_ChatInfo.RegisterAddonMessagePrefix, self.prefix)
    if ok then
      prefixRegistered = true
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest|r|cff66aaffPartySync|r: Initialize() - Registered prefix via C_ChatInfo (success)")
    else
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest|r|cff66aaffPartySync|r: Initialize() - C_ChatInfo.RegisterAddonMessagePrefix error: " .. tostring(err))
    end
  elseif RegisterAddonMessagePrefix then
    local ok, err = pcall(RegisterAddonMessagePrefix, self.prefix)
    if ok then
      prefixRegistered = true
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest|r|cff66aaffPartySync|r: Initialize() - Registered prefix via RegisterAddonMessagePrefix (success)")
    else
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest|r|cff66aaffPartySync|r: Initialize() - RegisterAddonMessagePrefix error: " .. tostring(err))
    end
  else
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest|r|cff66aaffPartySync|r: Initialize() - No RegisterAddonMessagePrefix available (Wrath - messages may still work)")
  end
  
  -- RegisterComm handles prefix registration internally (calls RegisterAddonMessagePrefix if available)
  -- In Wrath, prefix registration might not be required or might be handled differently
  local registerResult = self:RegisterComm(self.prefix)
  DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest|r|cff66aaffPartySync|r: Initialize() - RegisterComm called, result=" .. tostring(registerResult))
  
  -- Verify callback exists
  if self.OnCommReceived then
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest|r|cff66aaffPartySync|r: Initialize() - OnCommReceived method exists")
  else
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest|r|cff66aaffPartySync|r: Initialize() - WARNING: OnCommReceived method NOT found!")
  end
  self:RegisterEvent("PLAYER_ENTERING_WORLD", "HandlePlayerEnteringWorld")
  self:RegisterEvent("PARTY_MEMBERS_CHANGED", "CleanupGroupMembers")
  self:RegisterEvent("RAID_ROSTER_UPDATE", "CleanupGroupMembers")
  self:RegisterEvent("CHAT_MSG_YELL", "HandleYell")

  for key, objective in pairs(self.localObjectives) do
    if type(objective) == "table" then
      objective.key = objective.key or key
    end
  end

  self.initialized = true
  if self.debug then
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest|r|cff66aaffPartySync|r: Initialize() - SUCCESS! initialized=true")
  end
end

function PartySync:RefreshFromConfig()
  if not self:IsEnabled() then
    if self._broadcastHandle and self.CancelTimer then
      self:CancelTimer(self._broadcastHandle)
    end
    if self._yellState and self._yellState.timer and self.CancelTimer then
      self:CancelTimer(self._yellState.timer)
      self._yellState.timer = nil
    end
    self._broadcastHandle = nil
    self.pendingKeys = {}
    self.localObjectives = {}
    self.remoteByKey = {}
    if self._yellState then
      self._yellState.waiting = {}
      self._yellState.lastFlush = 0
    end
  else
    self:Initialize()
    if self.initialized then
      self:CleanupGroupMembers()
      self:SendFullSync()
    end
  end
end

local function CopyDetail(detail, meta)
  local name = detail.name or meta.spawn or (type(meta.item) == "table" and meta.item[1]) or meta.item or meta.quest or ""
  return {
    questId = meta.questid,
    objectiveIndex = detail.index,
    name = name,
    fulfilled = detail.fulfilled or 0,
    required = detail.required or 0,
  }
end

function PartySync:OnMetaProgress(meta, key, details)
  if not key or not details or not details[1] then 
    if self.debug then
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest|r|cff66aaffPartySync|r: OnMetaProgress early return - key=" .. tostring(key) .. " details[1]=" .. tostring(details and details[1]))
    end
    return 
  end
  
  if not self:IsEnabled() then return end
  
  self:Initialize()
  if not self.initialized then 
    if self.debug then
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest|r|cff66aaffPartySync|r: OnMetaProgress - initialized=false")
    end
    return 
  end

  local changed = false
  local distribution = ResolveDistribution()
  
  for _, detail in ipairs(details) do
    local payload = CopyDetail(detail, meta)
    payload.key = key
    local existing = self.localObjectives[key]
    if not existing or existing.fulfilled ~= payload.fulfilled or existing.required ~= payload.required then
      self.localObjectives[key] = payload
      self.pendingKeys[key] = "update"
      changed = true
      if not distribution then
        self:QueueYellUpdate(key, payload)
      end
      DebugPrint("local update", key, payload.fulfilled, payload.required, distribution or "YELL")
      break
    end
  end

  if changed then
    self:ScheduleBroadcast()
  end
end

function PartySync:OnQuestRemoved(questId)
  if not questId then return end
  if not self.initialized then return end

  local changed = false
  for key, detail in pairs(self.localObjectives) do
    if detail.questId == questId then
      self.localObjectives[key] = nil
      self.pendingKeys[key] = "remove"
      changed = true
      if self._yellState and self._yellState.waiting then
        self._yellState.waiting[key] = nil
      end
    end
  end

  if changed then
    self:ScheduleBroadcast()
  end

  for key, bucket in pairs(self.remoteByKey) do
    for player, entry in pairs(bucket) do
      if entry.questId == questId then
        bucket[player] = nil
      end
    end
    if not next(bucket) then
      self.remoteByKey[key] = nil
    end
  end
end

function PartySync:ScheduleBroadcast()
  if not self.initialized then return end
  if self._broadcastHandle then return end
  self._broadcastHandle = self:ScheduleTimer("FlushBroadcastQueue", 1)
end

function PartySync:FlushBroadcastQueue()
  self._broadcastHandle = nil
  if not self:IsEnabled() then
    self.pendingKeys = {}
    return
  end

  local distribution = ResolveDistribution()
  if not distribution then
    for key, action in pairs(self.pendingKeys) do
      if action ~= "remove" then
        local objective = self.localObjectives[key]
        if objective then
          self:QueueYellUpdate(key, objective)
        end
      end
      self.pendingKeys[key] = nil
    end
    self:ScheduleYell()
    return
  end

  for key, action in pairs(self.pendingKeys) do
    local payload
    if action == "remove" or not self.localObjectives[key] then
      payload = { v = self.version, t = "obj", p = self.subPrefix, key = key, remove = true }
    else
      local data = self.localObjectives[key]
      payload = {
        v = self.version,
        t = "obj",
        p = self.subPrefix, -- Sub-prefix to identify our messages
        key = key,
        questId = data.questId,
        objectiveIndex = data.objectiveIndex,
        fulfilled = data.fulfilled,
        required = data.required,
        name = data.name,
      }
    end

    local serialized = self.serializer:Serialize(payload)
    if serialized and type(serialized) == "string" and #serialized > 0 then
      self:SendCommMessage(self.prefix, serialized, distribution)
    end

    self.pendingKeys[key] = nil
  end
end

function PartySync:HandlePlayerEnteringWorld()
  self:CleanupExpired(true)
  self:CleanupGroupMembers()
end

function PartySync:CleanupGroupMembers()
  local roster = BuildGroupRoster()

  if self.remoteByKey then
    for key, bucket in pairs(self.remoteByKey) do
      for player in pairs(bucket) do
        if not roster[player] then
          bucket[player] = nil
        end
      end
      if not next(bucket) then
        self.remoteByKey[key] = nil
      end
    end
  end

  local added = self:HandleRosterChange(roster)
  if added then
    self:SendFullSync()
    DebugPrint("full sync broadcast")
  end
end

function PartySync:CleanupExpired(force)
  if not next(self.remoteByKey) then return end
  local now = GetTime and GetTime() or 0
  for key, bucket in pairs(self.remoteByKey) do
    for player, entry in pairs(bucket) do
      local expired = force or not entry.updated or (now - entry.updated) > self.remoteTTL
      if expired then
        bucket[player] = nil
      end
    end
    if not next(bucket) then
      self.remoteByKey[key] = nil
    end
  end
end

function PartySync:GetTooltipLines(key)
  if not key then return nil end
  if not self:IsEnabled() then return nil end
  if not self.initialized then self:Initialize() end
  if not self.initialized then return nil end

  self:CleanupExpired(false)
  local bucket = self.remoteByKey[key]
  
  -- If not found, try alternative key formats (m_ vs o_ for NPCs/objects)
  if not bucket or not next(bucket) then
    local prefix, id = string.match(key, "^([moi])_(.+)$")
    if prefix and id then
      -- Try alternative prefix: m_<id> <-> o_<id>
      if prefix == "m" then
        bucket = self.remoteByKey["o_" .. id]
      elseif prefix == "o" then
        bucket = self.remoteByKey["m_" .. id]
      end
    end
  end
  
  -- If still not found, try to find by quest ID
  -- First check if there's quest data for this key
  if (not bucket or not next(bucket)) then
    local QuestieTooltips = QuestieLoader:ImportModule("QuestieTooltips")
    local questIds = {}
    
    if QuestieTooltips then
      local questData = QuestieTooltips:GetTooltip(key)
      if questData then
        -- Collect all quest IDs that use this key
        for questId in pairs(questData) do
          table.insert(questIds, tonumber(questId))
        end
      end
    end
    
    -- If no quest data found for this key, search ALL stored entries for any quest IDs
    -- This handles cases where the NPC ID doesn't match the spawn ID used when storing
    if #questIds == 0 then
      local seenQuestIds = {}
      for remoteKey, remoteBucket in pairs(self.remoteByKey) do
        for player, entry in pairs(remoteBucket) do
          if entry.questId and not seenQuestIds[entry.questId] then
            table.insert(questIds, entry.questId)
            seenQuestIds[entry.questId] = true
          end
        end
      end
    end
    
    if #questIds > 0 then
      -- Search all remote entries for matching quest IDs
      local allEntries = {}
      for remoteKey, remoteBucket in pairs(self.remoteByKey) do
        for player, entry in pairs(remoteBucket) do
          if entry.questId then
            for _, questId in ipairs(questIds) do
              if entry.questId == questId then
                if not allEntries[remoteKey] then
                  allEntries[remoteKey] = {}
                end
                allEntries[remoteKey][player] = entry
              end
            end
          end
        end
      end
      
      -- Merge all matching entries into a single bucket
      if next(allEntries) then
        bucket = {}
        for _, remoteBucket in pairs(allEntries) do
          for player, entry in pairs(remoteBucket) do
            bucket[player] = entry
          end
        end
      end
    end
  end
  
  if not bucket or not next(bucket) then
    return nil
  end

  local now = GetTime and GetTime() or 0
  local lines = {}
  for player, entry in pairs(bucket) do
    if entry.updated and (now - entry.updated) <= self.remoteTTL then
      local progress
      if entry.required and entry.required > 0 then
        progress = string.format("%d/%d", entry.fulfilled or 0, entry.required)
      else
        progress = tostring(entry.fulfilled or 0)
      end
      local label = entry.name or (entry.questId and ("Quest " .. entry.questId)) or "Quest"
      table.insert(lines, { player = player, line = string.format("|cff5f87ff%s|r |cffa0a8ff%s|r |cffcfd7ff(%s)|r", player, label, progress) })
    end
  end

  if not next(lines) then
    self.remoteByKey[key] = nil
    return nil
  end

  table.sort(lines, function(a, b)
    return a.player < b.player
  end)

  local output = { "|cff6fa9ffParty Progress|r" }
  for _, entry in ipairs(lines) do
    table.insert(output, "|cff4f6faf•|r " .. entry.line)
  end
  return output
end

function PartySync:OnCommReceived(prefix, message, distribution, sender)
  if prefix ~= self.prefix then return end
  if not sender then return end
  sender = NormalizePlayerName(sender)
  if sender == GetLocalPlayerName() then return end
  if not self:IsEnabled() then return end
  self:Initialize()
  if not self.initialized then return end
  if not self.serializer then return end

  -- Check if message looks like AceSerializer data (should start with ^1)
  if not message or #message < 2 or string.sub(message, 1, 2) ~= "^1" then
    return
  end
  
  local ok, payload = self.serializer:Deserialize(message)
  if not ok or type(payload) ~= "table" then 
    if self.debug then
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest|r|cff66aaffPartySync|r: OnCommReceived - deserialize failed from " .. (sender or "unknown"))
    end
    return 
  end
  
  -- Check for our sub-prefix to distinguish from other pfQuest messages
  if payload.p ~= self.subPrefix then
    return
  end
  
  if self.debug then
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest|r|cff66aaffPartySync|r: OnCommReceived - type=" .. tostring(payload.t) .. " from " .. sender .. " key=" .. tostring(payload.key))
  end

  if payload.t == "req" then
    DebugPrint("sync request from", sender)
    if self:IsEnabled() then
      self:SendFullSync("WHISPER", sender)
    end
    return
  end
  if not payload.v or payload.v < 1 or not payload.key then
    if payload.t ~= "focus" then
      return
    end
  end

  if payload.t == "focus" then
    if not IsFocusReceiveEnabled() then return end
    local focusModule = GetFocusModule()
    if not focusModule then return end
    local questId = tonumber(payload.q)
    if payload.a == "set" and questId and questId > 0 then
      focusModule:OnRemoteFocusSet(sender, questId)
    else
      focusModule:OnRemoteFocusClear(sender)
    end
    return
  end

  if payload.t and payload.t ~= "obj" then
    return
  end

  if payload.remove then
    self:RemoveRemoteEntry(payload.key, sender)
    DebugPrint("remote remove", sender, payload.key)
    return
  end

  self:StoreRemoteEntry(payload.key, sender, {
    questId = payload.questId,
    objectiveIndex = payload.objectiveIndex,
    fulfilled = payload.fulfilled,
    required = payload.required,
    name = payload.name,
  })
  DebugPrint("remote update", sender, payload.key, payload.fulfilled, payload.required)
end

function PartySync:QueueYellUpdate(key, objective)
  if not self._yellState then return end
  if not key or not objective then return end
  objective.key = objective.key or key
  local payload = BuildYellPayloadFromObjective(objective)
  if not payload then return end
  self._yellState.waiting[key] = payload
  self:ScheduleYell()
end

function PartySync:ScheduleYell()
  if not self._yellState then return end
  if self._yellState.timer then return end
  if not IsYellAllowed() then return end
  if not next(self._yellState.waiting) then return end
  self._yellState.timer = self:ScheduleTimer("FlushYellQueue", 2)
end

function PartySync:FlushYellQueue()
  if not self._yellState then return end
  self._yellState.timer = nil
  if not IsYellAllowed() then
    self._yellState.waiting = {}
    return
  end

  local now = GetTime and GetTime() or 0
  if now - (self._yellState.lastFlush or 0) < 2 then
    self._yellState.timer = self:ScheduleTimer("FlushYellQueue", 2)
    return
  end

  local key, payload = next(self._yellState.waiting)
  if not key or not payload then
    return
  end

  self._yellState.waiting[key] = nil
  local serialized = SerializeYellPayload(payload)
  if serialized then
    SendChatMessage(string.format("%s:%s", self.prefix, serialized), "YELL")
    self._yellState.lastFlush = now
  end

  if next(self._yellState.waiting) then
    self._yellState.timer = self:ScheduleTimer("FlushYellQueue", 2)
  end
end

function PartySync:StoreRemoteEntry(key, playerName, data)
  if not key or not playerName or not data then return end
  self.remoteByKey = self.remoteByKey or {}
  local bucket = self.remoteByKey[key]
  if not bucket then
    bucket = {}
    self.remoteByKey[key] = bucket
  end
  bucket[playerName] = {
    questId = data.questId,
    objectiveIndex = data.objectiveIndex,
    fulfilled = data.fulfilled,
    required = data.required,
    name = data.name,
    updated = GetTime and GetTime() or 0,
  }
end

function PartySync:RemoveRemoteEntry(key, playerName)
  if not key or not playerName then return end
  local bucket = self.remoteByKey and self.remoteByKey[key]
  if not bucket then return end
  bucket[playerName] = nil
  if not next(bucket) then
    self.remoteByKey[key] = nil
  end
end

function PartySync:HandleYell(_, message, sender)
  if not self:IsEnabled() then return end
  if not message or not sender then return end

  local prefix, payloadText = string.match(message, "^(%S+):(.+)$")
  if prefix ~= self.prefix then return end

  sender = NormalizePlayerName(sender)
  if sender == GetLocalPlayerName() then return end

  local payload = ParseYellPayload(payloadText)
  if not payload or not payload.k then return end

  self:StoreRemoteEntry(payload.k, sender, {
    questId = payload.q,
    objectiveIndex = payload.o,
    fulfilled = payload.f,
    required = payload.r,
  })
end

local function IsFocusShareEnabled()
  return pfQuest_config and pfQuest_config["focuspartyshare"] == "1"
end

local function IsFocusReceiveEnabled()
  return pfQuest_config and pfQuest_config["focuspartyreceive"] ~= "0"
end

local function GetFocusModule()
  if not QuestieLoader or not QuestieLoader.ImportModule then return nil end
  return QuestieLoader:ImportModule("QuestieFocus")
end

function PartySync:NotifyFocusChange(action, questId)
  if not IsFocusShareEnabled() then return end
  self:Initialize()
  if not self.initialized then return end

  local distribution = ResolveDistribution()
  if not distribution then return end

  local payload = {
    v = self.version,
    t = "focus",
    p = self.subPrefix, -- Sub-prefix to identify our messages
    a = action,
    q = tonumber(questId) or 0,
  }

  local serialized = self.serializer:Serialize(payload)
  if serialized and type(serialized) == "string" and #serialized > 0 then
    self:SendCommMessage(self.prefix, serialized, distribution, nil, "NORMAL")
  end
end

-- Initialize PartySync
pcall(function() PartySync:Initialize() end)

-- Hook CHAT_MSG_ADDON to manually handle pfQuest messages since RegisterAddonMessagePrefix doesn't exist in Wrath
-- AceComm's RegisterComm won't work without prefix registration, so we route messages manually
local commFrame = CreateFrame("Frame")
if commFrame then
  commFrame:RegisterEvent("CHAT_MSG_ADDON")
  commFrame:SetScript("OnEvent", function(self, event, prefix, message, distribution, sender)
    if event == "CHAT_MSG_ADDON" and prefix == "pfQuest" then
      -- Only process AceSerializer messages (start with ^1)
      if message and #message >= 2 and string.sub(message, 1, 2) == "^1" then
        local ps = QuestieLoader and QuestieLoader:ImportModule("QuestiePartySync")
        if ps and ps.OnCommReceived then
          pcall(ps.OnCommReceived, ps, prefix, message, distribution, sender)
        end
      end
    end
  end)
end

-- Debug command to check status
SLASH_PFQUESTPARTYSYNC1 = "/pfqps"
SlashCmdList["PFQUESTPARTYSYNC"] = function(msg)
  local cmd = string.lower((msg or ""):match("^%s*(.-)%s*$"))
  if cmd == "status" then
    local ps = QuestieLoader:ImportModule("QuestiePartySync")
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest|r PartySync Status:")
    DEFAULT_CHAT_FRAME:AddMessage("  Enabled: " .. tostring(ps:IsEnabled()))
    DEFAULT_CHAT_FRAME:AddMessage("  Initialized: " .. tostring(ps.initialized))
    DEFAULT_CHAT_FRAME:AddMessage("  Config (tooltippartyprogress): " .. tostring(pfQuest_config and pfQuest_config["tooltippartyprogress"] or "nil"))
    local localCount = 0
    if ps.localObjectives then
      for _ in pairs(ps.localObjectives) do localCount = localCount + 1 end
    end
    DEFAULT_CHAT_FRAME:AddMessage("  Local objectives: " .. localCount)
    local remoteCount = 0
    if ps.remoteByKey then
      for _, bucket in pairs(ps.remoteByKey) do
        for _ in pairs(bucket) do remoteCount = remoteCount + 1 end
      end
    end
    DEFAULT_CHAT_FRAME:AddMessage("  Remote entries: " .. remoteCount)
    if ps.remoteByKey then
      for key, bucket in pairs(ps.remoteByKey) do
        for player, entry in pairs(bucket) do
          DEFAULT_CHAT_FRAME:AddMessage("    " .. key .. " -> " .. player .. ": " .. (entry.fulfilled or 0) .. "/" .. (entry.required or 0))
        end
      end
    end
  elseif cmd == "debug" then
    local ps = QuestieLoader:ImportModule("QuestiePartySync")
    ps.debug = not ps.debug
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest|r PartySync debug: " .. (ps.debug and "ON" or "OFF"))
  elseif cmd == "sync" then
    local ps = QuestieLoader:ImportModule("QuestiePartySync")
    ps:Initialize()
    if ps.initialized then
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest|r PartySync: Testing comm - prefix=" .. ps.prefix)
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest|r PartySync: OnCommReceived exists=" .. tostring(ps.OnCommReceived ~= nil))
      ps:SendFullSync()
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest|r PartySync: Sent full sync")
    else
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest|r PartySync: Not initialized, cannot sync")
    end
  else
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest|r PartySync commands:")
    DEFAULT_CHAT_FRAME:AddMessage("  /pfqps status - Show current status")
    DEFAULT_CHAT_FRAME:AddMessage("  /pfqps debug - Toggle debug messages")
    DEFAULT_CHAT_FRAME:AddMessage("  /pfqps sync - Send full sync to party")
  end
end
