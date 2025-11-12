local QuestieTooltips = QuestieLoader:ImportModule("QuestieTooltips")
local PartySync = QuestieLoader:ImportModule("QuestiePartySync")

local Bridge = QuestieLoader:CreateModule("pfQuestTooltipBridge")

-- Track registered quests for progress updates
Bridge.registeredQuests = Bridge.registeredQuests or {}

local sanitize = pfUI and pfUI.api and pfUI.api.SanitizePattern

local monsterPattern = sanitize and sanitize(QUEST_MONSTERS_KILLED) or "(.*):%s*([%d]+)%s*/%s*([%d]+)"
local itemPattern = sanitize and sanitize(QUEST_OBJECTS_FOUND) or "(.*):%s*([%d]+)%s*/%s*([%d]+)"

local function normalize(name)
  if not name then return nil end
  name = string.lower(name)
  name = string.gsub(name, "^%s+", "")
  name = string.gsub(name, "%s+$", "")
  return name
end

local function rgbToHex(r, g, b)
  r = math.floor(math.max(0, math.min(1, r or 1)) * 255 + 0.5)
  g = math.floor(math.max(0, math.min(1, g or 1)) * 255 + 0.5)
  b = math.floor(math.max(0, math.min(1, b or 1)) * 255 + 0.5)
  return string.format("%02x%02x%02x", r, g, b)
end

local function buildProgressLines(meta)
  if not meta.qlogid then return nil, nil end

  local objectives = GetNumQuestLeaderBoards(meta.qlogid)
  if not objectives or objectives <= 0 then return nil, nil end

  local lines = {}
  local details = {}
  local wantedSpawn = normalize(meta.spawn)
  local wantedItems = {}

  if type(meta.item) == "table" then
    for _, name in pairs(meta.item) do
      if type(name) == "string" then
        wantedItems[normalize(name)] = true
      end
    end
  elseif type(meta.item) == "string" then
    wantedItems[normalize(meta.item)] = true
  end

  for i = 1, objectives do
    local text, objectiveType = GetQuestLogLeaderBoard(i, meta.qlogid)
    if text then
      local mapTooltip = pfMap and pfMap.tooltip
      if objectiveType == "monster" then
        local _, _, monsterName, cur, req = string.find(text, monsterPattern)
        if monsterName and (normalize(monsterName) == wantedSpawn) then
          local fulfilled = tonumber(cur) or 0
          local required = tonumber(req) or 0
          local r, g, b = mapTooltip and mapTooltip:GetColor(fulfilled, required) or 1, 1, 1
          local color = rgbToHex(r, g, b)
          table.insert(lines, string.format("|cffaaaaaa- |r|cff%s%s: %s/%s|r", color, monsterName, fulfilled, required))
          table.insert(details, {
            index = i,
            name = monsterName,
            fulfilled = fulfilled,
            required = required,
            type = "monster",
          })
        end
      elseif objectiveType == "item" then
        local _, _, itemName, cur, req = string.find(text, itemPattern)
        if itemName and wantedItems[normalize(itemName)] then
          local fulfilled = tonumber(cur) or 0
          local required = tonumber(req) or 0
          local r, g, b = mapTooltip and mapTooltip:GetColor(fulfilled, required) or 1, 1, 1
          local color = rgbToHex(r, g, b)
          table.insert(lines, string.format("|cffaaaaaa- |r|cff%s%s: %s/%s|r", color, itemName, fulfilled, required))
          table.insert(details, {
            index = i,
            name = itemName,
            fulfilled = fulfilled,
            required = required,
            type = "item",
          })
        end
      end
    end
  end

  local output = next(lines) and lines or nil
  if not next(details) then
    details = nil
  end

  return output, details
end

local function getQuestName(meta)
  if meta.quest then return meta.quest end
  if meta.questid and pfDB and pfDB.quests and pfDB.quests.loc and pfDB.quests.loc[meta.questid] then
    return pfDB.quests.loc[meta.questid].T
  end
end

local function determineKey(meta)
  if meta.itemid then
    return "i_" .. meta.itemid
  end

  if not meta.spawnid then return nil end

  if meta.QTYPE and string.find(meta.QTYPE, "OBJECT") then
    return "o_" .. meta.spawnid
  end

  local objectLoc = pfQuest_Loc and pfQuest_Loc["Object"]
  if objectLoc and meta.spawntype == objectLoc then
    return "o_" .. meta.spawnid
  end

  return "m_" .. meta.spawnid
end

local function levelColor(level, force)
  local color = "|cffffffff"
  if pfMap and pfMap.HexDifficultyColor then
    color = pfMap:HexDifficultyColor(level, force) or color
  elseif pfDatabase and pfDatabase.GetHexDifficultyColor then
    color = pfDatabase:GetHexDifficultyColor(level, force) or color
  end
  return color .. tostring(level) .. "|r"
end

local function appendQuestMetadata(lines, meta)
  local questData = pfDB and pfDB.quests and pfDB.quests.data and pfDB.quests.data[meta.questid]

  -- Removed Level and Required Level per user request - too much clutter

  if questData and questData.extra then
    if questData.extra.xp then
      table.insert(lines, string.format("|cffffffffXP:|r %s", questData.extra.xp))
    end
    if questData.extra.money then
      table.insert(lines, string.format("|cffffffff%s:|r %s",
        pfQuest_Loc and pfQuest_Loc["Reward"] or "Reward",
        GetCoinTextureString(questData.extra.money)))
    end
  end

  -- Handle drop rate - average if multiple items, or use single value
  if meta.droprate then
    local dropRate = meta.droprate
    -- If meta.item is a table with multiple items, we might want to average
    -- For now, just use the single droprate value
    if type(dropRate) == "table" then
      -- Average multiple drop rates
      local sum = 0
      local count = 0
      for _, rate in pairs(dropRate) do
        local numRate = tonumber(rate)
        if numRate then
          sum = sum + numRate
          count = count + 1
        end
      end
      if count > 0 then
        dropRate = math.floor((sum / count) + 0.5) -- Round to nearest integer
      else
        dropRate = nil
      end
    end
    if dropRate then
      table.insert(lines, string.format("|cffffffff%s:|r %s%%",
        pfQuest_Loc and pfQuest_Loc["Drop Rate"] or "Drop Rate",
        tostring(dropRate)))
    end
  end

  if meta.sellcount then
    local itemName = meta.item and meta.item[1] and meta.item[1] or ""
    local countText = tonumber(meta.sellcount) and meta.sellcount ~= 0 and ("x" .. meta.sellcount) or ""
    if itemName ~= "" then
      table.insert(lines, string.format("|cffffffff%s:|r %s %s",
        pfQuest_Loc and pfQuest_Loc["Vendor"] or "Vendor",
        itemName,
        countText))
    end
  end

  if pfQuest_config and pfQuest_config["showids"] == "1" then
    table.insert(lines, string.format("|cffffffffQuest ID:|r %s", meta.questid))
  end
end

local function appendFallback(lines, meta)
  if meta.description and meta.description ~= "" then
    local formatted = pfDatabase and pfDatabase.FormatQuestText and pfDatabase:FormatQuestText(meta.description) or meta.description
    table.insert(lines, "|cffdddddd" .. formatted .. "|r")
  elseif meta.spawn then
    table.insert(lines, "|cffdddddd" .. meta.spawn .. "|r")
  end
end

function Bridge:ResetQuest(questId)
  if not QuestieTooltips then return end
  QuestieTooltips:RemoveQuest(questId)
end

function Bridge:RegisterMeta(meta)
  if not QuestieTooltips or not meta or not meta.questid then return end

  local key = determineKey(meta)
  if not key then return end

  local lines = {}
  local questName = getQuestName(meta)
  if questName then
    table.insert(lines, string.format("|cffffcc00%s|r", questName))
  end

  local progress, details = buildProgressLines(meta)
  if progress then
    for _, line in ipairs(progress) do
      table.insert(lines, line)
    end
  else
    appendFallback(lines, meta)
  end

  appendQuestMetadata(lines, meta)

  if not next(lines) then return end

  QuestieTooltips:RegisterObjectiveTooltip(meta.questid, key, {
    lines = lines,
    questId = meta.questid,
    key = key,
  })

  -- Store meta for progress tracking (store even if qlogid is nil - we'll update it later)
  if meta.questid then
    local questKey = tostring(meta.questid) .. "_" .. key
    if not self.registeredQuests[questKey] then
      self.registeredQuests[questKey] = {}
      -- Copy meta data for later re-processing
      for k, v in pairs(meta) do
        self.registeredQuests[questKey][k] = v
      end
      if PartySync and PartySync.debug then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest|r|cff66aaffBridge|r: registered quest " .. (meta.questid or "?") .. " key " .. (key or "?") .. " qlogid " .. (meta.qlogid or "nil (will update)"))
      end
    elseif meta.qlogid and not self.registeredQuests[questKey].qlogid then
      -- Update qlogid if we didn't have it before
      self.registeredQuests[questKey].qlogid = meta.qlogid
      if PartySync and PartySync.debug then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest|r|cff66aaffBridge|r: updated quest " .. (meta.questid or "?") .. " key " .. (key or "?") .. " qlogid " .. meta.qlogid)
      end
    end
  end

  if PartySync and PartySync.OnMetaProgress and details then
    if PartySync.debug then
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest|r|cff66aaffBridge|r: RegisterMeta calling OnMetaProgress for quest " .. (meta.questid or "?") .. " key " .. (key or "?") .. " details " .. (details and #details or 0))
    end
    PartySync:OnMetaProgress(meta, key, details)
  elseif PartySync and PartySync.debug and not details then
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest|r|cff66aaffBridge|r: RegisterMeta no details for quest " .. (meta.questid or "?") .. " key " .. (key or "?") .. " qlogid " .. (meta.qlogid or "nil"))
  end
end

function Bridge:GetKey(meta)
  return determineKey(meta)
end

-- Update progress for all registered quests on QUEST_LOG_UPDATE
local updateFrame = CreateFrame("Frame")
updateFrame:RegisterEvent("QUEST_LOG_UPDATE")
updateFrame:RegisterEvent("QUEST_ACCEPTED")
updateFrame:SetScript("OnEvent", function(self, event)
  -- Get PartySync to check debug status
  local PartySync = QuestieLoader and QuestieLoader:ImportModule("QuestiePartySync")
  if PartySync and PartySync.debug then
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest|r|cff66aaffBridge|r: Event fired: " .. (event or "nil"))
  end
  
  if event ~= "QUEST_LOG_UPDATE" then
    return -- Only process QUEST_LOG_UPDATE for now
  end
  
  -- Get PartySync dynamically in case it loads after this module
  local PartySync = QuestieLoader and QuestieLoader:ImportModule("QuestiePartySync")
  
  if not PartySync or not PartySync.OnMetaProgress then 
    if PartySync and PartySync.debug then
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest|r|cff66aaffBridge|r: QUEST_LOG_UPDATE fired but PartySync.OnMetaProgress not available")
    end
    return 
  end
  
  -- Throttle updates to prevent spam
  local now = GetTime()
  if not updateFrame.lastUpdate then updateFrame.lastUpdate = 0 end
  if now - updateFrame.lastUpdate < 0.5 then 
    if PartySync.debug then
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest|r|cff66aaffBridge|r: QUEST_LOG_UPDATE throttled")
    end
    return 
  end
  updateFrame.lastUpdate = now
  
  -- Delay processing slightly to allow quest log to fully update
  -- Use a simple frame timer since C_Timer might not exist in Wrath
  if not updateFrame.delayTimer then
    updateFrame.delayTimer = CreateFrame("Frame")
    updateFrame.delayTimer:Hide()
  end
  
  updateFrame.delayTimer.elapsed = 0
  updateFrame.delayTimer:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = (self.elapsed or 0) + elapsed
    if self.elapsed >= 0.1 then
      self.elapsed = 0
      self:Hide()
      
      -- Get PartySync dynamically
      local PartySync = QuestieLoader and QuestieLoader:ImportModule("QuestiePartySync")
      
      if not PartySync or not PartySync.OnMetaProgress then 
        if PartySync and PartySync.debug then
          DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest|r|cff66aaffBridge|r: delay timer fired but PartySync.OnMetaProgress not available")
        end
        return 
      end
  
      -- First, try to update qlogid for any quests that don't have it yet
      local numEntries, numQuests = GetNumQuestLogEntries()
      for questKey, storedMeta in pairs(Bridge.registeredQuests) do
        if storedMeta.questid and not storedMeta.qlogid then
          -- Try to find this quest in the quest log
          local expectedTitle = storedMeta.quest or (pfDB and pfDB.quests and pfDB.quests.loc and pfDB.quests.loc[storedMeta.questid] and pfDB.quests.loc[storedMeta.questid].T)
          if expectedTitle then
            for i = 1, numEntries do
              local title, level, questTag, isHeader = GetQuestLogTitle(i)
              if not isHeader and title == expectedTitle then
                -- Verify quest ID if possible
                local matches = true
                if GetQuestLink then
                  local oldSelection = GetQuestLogSelection()
                  SelectQuestLogEntry(i)
                  local questLink = GetQuestLink(i)
                  SelectQuestLogEntry(oldSelection)
                  if questLink then
                    local _, _, questId = string.find(questLink, "|c.*|Hquest:([%d]+):")
                    if questId and tonumber(questId) == storedMeta.questid then
                      storedMeta.qlogid = i
                      if PartySync.debug then
                        DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest|r|cff66aaffBridge|r: found qlogid " .. i .. " for quest " .. storedMeta.questid)
                      end
                      break
                    end
                  else
                    -- No quest link but title matches, assume it's correct
                    storedMeta.qlogid = i
                    if PartySync.debug then
                      DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest|r|cff66aaffBridge|r: found qlogid " .. i .. " for quest " .. storedMeta.questid .. " (by title)")
                    end
                    break
                  end
                else
                  -- No GetQuestLink, match by title only
                  storedMeta.qlogid = i
                  if PartySync.debug then
                    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest|r|cff66aaffBridge|r: found qlogid " .. i .. " for quest " .. storedMeta.questid .. " (by title)")
                  end
                  break
                end
              end
            end
          end
        end
      end
      
      -- Re-process all registered quests (now that we've updated qlogids)
      local processedCount = 0
      for questKey, storedMeta in pairs(Bridge.registeredQuests) do
        if storedMeta.qlogid and storedMeta.questid then
          processedCount = processedCount + 1
          -- Verify quest is still in log by checking qlogid directly first
          local numEntries, numQuests = GetNumQuestLogEntries()
          local found = false
          
          -- Debug message only if debug is enabled
          if PartySync and PartySync.debug and processedCount <= 3 then
            DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest|r|cff66aaffBridge|r: processing quest " .. storedMeta.questid .. " qlogid " .. storedMeta.qlogid)
          end
          
          -- First try: Check if qlogid is still valid
          if storedMeta.qlogid and storedMeta.qlogid > 0 and storedMeta.qlogid <= numEntries then
            local title, level, questTag, isHeader, isCollapsed, isComplete = GetQuestLogTitle(storedMeta.qlogid)
            if PartySync.debug then
              DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest|r|cff66aaffBridge|r: checking qlogid " .. storedMeta.qlogid .. " for quest " .. storedMeta.questid .. " - isHeader=" .. tostring(isHeader) .. " type=" .. type(isHeader) .. " title='" .. (title or "nil") .. "'")
            end
            -- In Wrath, isHeader can be 0 (number) for non-headers, so check explicitly
            if (isHeader == 0 or isHeader == false or isHeader == nil) and title then
              -- Try to verify quest ID using GetQuestLink if available
              if GetQuestLink then
                local oldSelection = GetQuestLogSelection()
                SelectQuestLogEntry(storedMeta.qlogid)
                local questLink = GetQuestLink(storedMeta.qlogid)
                SelectQuestLogEntry(oldSelection)
                if questLink then
                  local _, _, questId = string.find(questLink, "|c.*|Hquest:([%d]+):")
                  if questId and tonumber(questId) == storedMeta.questid then
                    found = true
                    if PartySync.debug then
                      DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest|r|cff66aaffBridge|r: quest " .. storedMeta.questid .. " found by questLink match")
                    end
                  end
                end
              end
              
              -- If GetQuestLink didn't confirm, match by title
              if not found then
                local expectedTitle = storedMeta.quest or (pfDB and pfDB.quests and pfDB.quests.loc and pfDB.quests.loc[storedMeta.questid] and pfDB.quests.loc[storedMeta.questid].T)
                if expectedTitle and title == expectedTitle then
                  found = true
                  if PartySync.debug then
                    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest|r|cff66aaffBridge|r: quest " .. storedMeta.questid .. " found by title match")
                  end
                end
              end
            end
          end
          
          -- Second try: If qlogid check failed, search by quest ID/title
          if not found then
            local expectedTitle = storedMeta.quest or (pfDB and pfDB.quests and pfDB.quests.loc and pfDB.quests.loc[storedMeta.questid] and pfDB.quests.loc[storedMeta.questid].T)
            if expectedTitle then
              for i = 1, numEntries do
                local title, level, questTag, isHeader, isCollapsed, isComplete = GetQuestLogTitle(i)
                if not isHeader and title == expectedTitle then
                  -- Try to verify quest ID using GetQuestLink if available
                  if GetQuestLink then
                    local oldSelection = GetQuestLogSelection()
                    SelectQuestLogEntry(i)
                    local questLink = GetQuestLink(i)
                    SelectQuestLogEntry(oldSelection)
                    if questLink then
                      local _, _, questId = string.find(questLink, "|c.*|Hquest:([%d]+):")
                      if questId and tonumber(questId) == storedMeta.questid then
                        found = true
                        storedMeta.qlogid = i
                        break
                      end
                    else
                      -- No quest link but title matches, assume it's correct
                      found = true
                      storedMeta.qlogid = i
                      break
                    end
                  else
                    -- No GetQuestLink, match by title only
                    found = true
                    storedMeta.qlogid = i
                    break
                  end
                end
              end
            end
          end
          
          -- Third try: If still not found but we have a qlogid, be lenient and assume it's still valid
          -- (quest log might be updating)
          if not found and storedMeta.qlogid and storedMeta.qlogid > 0 and storedMeta.qlogid <= numEntries then
            local title, level, questTag, isHeader = GetQuestLogTitle(storedMeta.qlogid)
            if not isHeader and title then
              -- Assume it's valid if there's a quest at that index
              found = true
              if PartySync.debug then
                DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest|r|cff66aaffBridge|r: quest " .. (storedMeta.questid or "?") .. " qlogid " .. (storedMeta.qlogid or "?") .. " found by lenient check")
              end
            end
          end
          
          if found then
            -- Reset not found counter since we found it
            storedMeta._notFoundCount = 0
            
            local key = determineKey(storedMeta)
            if key then
              local progress, details = buildProgressLines(storedMeta)
              if details and PartySync.OnMetaProgress then
                if PartySync.debug then
                  DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest|r|cff66aaffBridge|r: calling OnMetaProgress for quest " .. (storedMeta.questid or "?") .. " key " .. (key or "?") .. " details=" .. #details)
                end
                PartySync:OnMetaProgress(storedMeta, key, details)
              elseif PartySync.debug then
                DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest|r|cff66aaffBridge|r: quest " .. (storedMeta.questid or "?") .. " found but no details, skipping OnMetaProgress")
              end
            elseif PartySync.debug then
              DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest|r|cff66aaffBridge|r: quest " .. (storedMeta.questid or "?") .. " found but no key")
            end
          else
            -- Quest not found - but don't remove immediately, might be a timing issue
            -- Only remove if we've checked multiple times and it's consistently missing
            storedMeta._notFoundCount = (storedMeta._notFoundCount or 0) + 1
            if storedMeta._notFoundCount >= 3 then
              -- Only remove after 3 consecutive failures to find it
              if PartySync.debug then
                local expectedTitle = storedMeta.quest or (pfDB and pfDB.quests and pfDB.quests.loc and pfDB.quests.loc[storedMeta.questid] and pfDB.quests.loc[storedMeta.questid].T)
                DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest|r|cff66aaffBridge|r: quest " .. (storedMeta.questid or "?") .. " qlogid " .. (storedMeta.qlogid or "?") .. " title '" .. (expectedTitle or "nil") .. "' not found after " .. storedMeta._notFoundCount .. " checks, removing")
              end
              Bridge.registeredQuests[questKey] = nil
            elseif PartySync.debug then
              DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest|r|cff66aaffBridge|r: quest " .. (storedMeta.questid or "?") .. " not found (attempt " .. storedMeta._notFoundCount .. "/3), will retry")
            end
          end
        end
      end
    end
    end)
    updateFrame.delayTimer:Show()
end)

function Bridge:ResetQuest(questId)
  if not QuestieTooltips then return end
  QuestieTooltips:RemoveQuest(questId)
  
  -- Remove from registered quests tracking
  if questId then
    local questKeyStr = tostring(questId)
    for questKey in pairs(self.registeredQuests) do
      if string.find(questKey, "^" .. questKeyStr .. "_") then
        self.registeredQuests[questKey] = nil
      end
    end
  end
end

return Bridge


