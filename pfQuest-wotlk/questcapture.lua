-- pfQuest Automated Quest Capture System
-- Automatically captures quest data for contributing to pfQuest database

-- Initialize saved variables
pfQuest_CapturedQuests = pfQuest_CapturedQuests or {}
pfQuest_InjectedData = pfQuest_InjectedData or {
  quests = { loc = {}, data = {} },
  units = { loc = {}, data = {} },
}
pfQuest_CaptureConfig = pfQuest_CaptureConfig or {
  enabled = true,
  autoExport = false,
  debug = false, -- Debug mode for verbose capture messages
}

-- Quest capture data structure
local captureData = {}
local currentQuestNPC = nil
local previousObjectives = {} -- Track previous objective states to detect changes
local pendingQuestNPC = nil -- Store NPC info from QUEST_DETAIL for next acceptance
local lastInteractedNPC = nil -- Store last NPC you interacted with (fallback for gossip menus)
local recentNPCs = {} -- Store recent NPCs you've interacted with (60 second cache)

-- Helper function to get NPC/Object info
local function GetTargetInfo()
  -- Try multiple unit frames in order of priority
  local units = {"questnpc", "npc", "target", "mouseover"}
  
  for _, unit in ipairs(units) do
    if UnitExists(unit) and UnitIsPlayer(unit) == nil then
      local name = UnitName(unit)
      local guid = UnitGUID(unit)
      local type = UnitCreatureType(unit) or "NPC"
      
      if name and guid then
        return name, guid, type
      end
    end
  end
  
  return nil, nil, nil
end

-- Extract ID from GUID (multiple methods for compatibility)
local function GetIDFromGUID(guid)
  if not guid then return nil end
  
  -- Method 1: Standard GUID format (Creature-0-ServerID-ZoneUID-SpawnID-CreatureID-000000000)
  local _, _, _, _, _, id = string.find(guid, "(%w+)-(%d+)-(%d+)-(%d+)-(%d+)-(%d+)")
  if id then
    return tonumber(id)
  end
  
  -- Method 2: Try alternative format
  local id2 = string.match(guid, "0x%x+%x%x%x%x(%x%x%x%x%x%x)$")
  if id2 then
    return tonumber(id2, 16)
  end
  
  -- Method 3: Try extracting last number segment
  local id3 = string.match(guid, "%-(%d+)$")
  if id3 then
    return tonumber(id3)
  end
  
  return nil
end

-- Get current player position and zone (OPTIMIZED for performance)
local function GetPlayerLocation()
  -- CRITICAL: Get the player's ACTUAL zone, not the open map's zone
  -- GetZoneText() returns where the player physically is, regardless of map state
  local zoneName = GetZoneText()
  local subZoneName = GetSubZoneText()
  
  -- Try to get zone ID from name first (no map operations needed!)
  local zoneID = nil
  if pfMap and pfMap.GetMapIDByName then
    zoneID = pfMap:GetMapIDByName(zoneName)
  end
  
  -- Only use map operations if zone lookup failed
  local x, y, continent, zone
  if not zoneID then
    -- Save current map state
    local savedContinent = GetCurrentMapContinent()
    local savedZone = GetCurrentMapZone()
    local mapWasOpen = WorldMapFrame:IsShown()
    
    -- Force map to player's current zone to get accurate coordinates
    SetMapToCurrentZone()
    x, y = GetPlayerMapPosition("player")
    continent = GetCurrentMapContinent()
    zone = GetCurrentMapZone()
    
    -- Restore map state if it was open
    if mapWasOpen then
      SetMapZoom(savedContinent, savedZone)
    end
    
    -- Calculate zone ID
    zoneID = continent * 100 + zone
  else
    -- We have zone ID from name, get coordinates without map operations
    x, y = GetPlayerMapPosition("player")
    continent = math.floor(zoneID / 100)
    zone = zoneID - (continent * 100)
  end
  
  -- Convert from 0-1 range to 0-100 for consistency with pfQuest format
  x = x * 100
  y = y * 100
  
  return {
    x = x,
    y = y,
    continent = continent,
    zone = zone,
    zoneID = zoneID,
    zoneName = zoneName,
    subZone = subZoneName,
    timestamp = time()
  }
end

-- Inject all captured quests into live database
function InjectAllCapturedQuests(showMessages)
  if not pfDB or not pfDB["quests"] then return 0 end
  
  showMessages = showMessages or false
  local count = 0
  
  for title, data in pairs(pfQuest_CapturedQuests) do
    if data.questID and not (type(data.questID) == "string" and string.find(data.questID, "custom_")) then
      InjectQuestIntoDatabase(title, data, false) -- false = silent individual injection
      count = count + 1
    end
  end
  
  -- CRITICAL: Reload database cache after all injections
  -- This updates the local 'units', 'quests', 'objects' references in database.lua
  if count > 0 and pfDatabase and pfDatabase.Reload then
    pfDatabase.Reload()
    
    if showMessages and pfQuest_CaptureConfig.debug then
      DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa  Database cache reloaded for " .. count .. " injected quests")
    end
    
    -- CRITICAL: Force immediate quest giver update
    -- Don't wait for pfQuest's OnUpdate tick - trigger search NOW
    if pfQuest_config and pfQuest_config["allquestgivers"] == "1" then
      -- First, manually check if our injected quests will show
      if showMessages and pfQuest_CaptureConfig.debug then
        for title, data in pairs(pfQuest_CapturedQuests) do
          if data.questID and not (type(data.questID) == "string" and string.find(data.questID, "custom_")) then
            local qid = tonumber(data.questID)
            if qid then
              -- Check if quest passes filter
              local plevel = UnitLevel("player")
              local inLog = pfQuest and pfQuest.questlog and pfQuest.questlog[qid]
              local inHistory = pfQuest_history and pfQuest_history[qid]
              
              if not inLog and not inHistory then
                DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa  Quest " .. qid .. " (" .. title .. ") should show - checking NPCs...")
                
                -- Check if NPC exists
                if pfDB.units and pfDB.units.data then
                  local npcID = data.startNPC and data.startNPC.id
                  if npcID then
                    if pfDB.units.data[npcID] then
                      local coords = pfDB.units.data[npcID].coords or {}
                      DEFAULT_CHAT_FRAME:AddMessage("|cff55ff55    ✓ NPC " .. npcID .. " exists with " .. table.getn(coords) .. " spawn(s)")
                      
                      -- Show spawn zones
                      for i, coord in ipairs(coords) do
                        DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa      Spawn " .. i .. ": Zone " .. coord[3] .. " at (" .. math.floor(coord[1]) .. ", " .. math.floor(coord[2]) .. ")")
                      end
                    else
                      DEFAULT_CHAT_FRAME:AddMessage("|cffff5555    ✗ NPC " .. npcID .. " NOT in pfDB.units.data!")
                    end
                  end
                end
              else
                DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00  Quest " .. qid .. " filtered: " .. (inLog and "in log" or "completed"))
              end
            end
          end
        end
      end
      
      local meta = { ["addon"] = "PFQUEST" }
      local maps = pfDatabase:SearchQuests(meta)
      
      -- Count how many maps were created
      local mapCount = 0
      if maps then
        for _ in pairs(maps) do
          mapCount = mapCount + 1
        end
      end
      
      if showMessages and pfQuest_CaptureConfig.debug then
        DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa  Forced quest giver map update - created " .. mapCount .. " map entries")
      end
      
      -- Queue map update (let pfQuest handle it naturally)
      if pfMap then
        pfMap.queue_update = GetTime()
      end
    end
  end
  
  if showMessages and count > 0 then
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest Capture: Injected " .. count .. " quests into live database")
  end
  
  return count
end

-- Inject captured quest data into pfDB (live database)
function InjectQuestIntoDatabase(questTitle, data, showMessage)
  if not data or not data.questID then return end
  if not pfDB or not pfDB["quests"] then return end
  
  local qid = data.questID
  
  -- Don't inject if it's a temporary custom ID
  if type(qid) == "string" and string.find(qid, "custom_") then
    return
  end
  
  qid = tonumber(qid)
  if not qid then return end
  
  -- Initialize database tables if they don't exist
  pfDB["quests"]["loc"] = pfDB["quests"]["loc"] or {}
  pfDB["quests"]["data"] = pfDB["quests"]["data"] or {}
  
  -- Inject quest locale data
  if not pfDB["quests"]["loc"][qid] then
    pfDB["quests"]["loc"][qid] = {}
  end
  
  pfDB["quests"]["loc"][qid]["T"] = data.title
  
  if data.description and data.description ~= "" then
    pfDB["quests"]["loc"][qid]["D"] = data.description
  end
  
  -- Combine objectives into single string
  if data.objectives and table.getn(data.objectives) > 0 then
    local objText = ""
    for i, obj in ipairs(data.objectives) do
      objText = objText .. obj.text
      if i < table.getn(data.objectives) then
        objText = objText .. "\n"
      end
    end
    pfDB["quests"]["loc"][qid]["O"] = objText
  end
  
  -- Inject quest metadata
  if not pfDB["quests"]["data"][qid] then
    pfDB["quests"]["data"][qid] = {}
  end
  
  if data.level then
    pfDB["quests"]["data"][qid]["lvl"] = data.level
  end
  
  -- Set minimum level to 1 so the quest shows for all characters
  -- This is critical for level-scaling servers and ensures visibility on all servers
  pfDB["quests"]["data"][qid]["min"] = 1
  
  -- CRITICAL: Add class restriction if this is a class-specific quest
  if data.classRestriction then
    pfDB["quests"]["data"][qid]["class"] = data.classRestriction
    
    -- Also save to persistent storage
    pfQuest_InjectedData.quests.data[qid]["class"] = data.classRestriction
    
    if pfQuest_CaptureConfig.debug then
      DEFAULT_CHAT_FRAME:AddMessage("|cffff9900  Class restriction added: " .. data.classRestriction)
    end
  end
  
  -- CRITICAL: ALSO save to SavedVariable for persistence across /reload
  -- Copy quest data to persistent storage
  pfQuest_InjectedData.quests.loc[qid] = pfQuest_InjectedData.quests.loc[qid] or {}
  pfQuest_InjectedData.quests.loc[qid]["T"] = pfDB["quests"]["loc"][qid]["T"]
  if pfDB["quests"]["loc"][qid]["D"] then
    pfQuest_InjectedData.quests.loc[qid]["D"] = pfDB["quests"]["loc"][qid]["D"]
  end
  if pfDB["quests"]["loc"][qid]["O"] then
    pfQuest_InjectedData.quests.loc[qid]["O"] = pfDB["quests"]["loc"][qid]["O"]
  end
  
  pfQuest_InjectedData.quests.data[qid] = pfQuest_InjectedData.quests.data[qid] or {}
  pfQuest_InjectedData.quests.data[qid]["lvl"] = pfDB["quests"]["data"][qid]["lvl"]
  pfQuest_InjectedData.quests.data[qid]["min"] = 1
  
  -- Inject start NPC and add to units database
  if data.startNPC and data.startNPC.id then
    pfDB["quests"]["data"][qid]["start"] = pfDB["quests"]["data"][qid]["start"] or {}
    pfDB["quests"]["data"][qid]["start"]["U"] = pfDB["quests"]["data"][qid]["start"]["U"] or {}
    
    -- Add to quest start units list if not already there
    local found = false
    for _, existingID in ipairs(pfDB["quests"]["data"][qid]["start"]["U"]) do
      if existingID == data.startNPC.id then
        found = true
        break
      end
    end
    
    if not found then
      table.insert(pfDB["quests"]["data"][qid]["start"]["U"], data.startNPC.id)
    end
    
    -- CRITICAL: Also save quest start NPCs to persistent storage
    pfQuest_InjectedData.quests.data[qid]["start"] = pfQuest_InjectedData.quests.data[qid]["start"] or {}
    pfQuest_InjectedData.quests.data[qid]["start"]["U"] = pfQuest_InjectedData.quests.data[qid]["start"]["U"] or {}
    if not found then
      table.insert(pfQuest_InjectedData.quests.data[qid]["start"]["U"], data.startNPC.id)
    end
    
    -- Initialize units database
    pfDB["units"] = pfDB["units"] or {}
    pfDB["units"]["data"] = pfDB["units"]["data"] or {}
    pfDB["units"]["loc"] = pfDB["units"]["loc"] or {}
    
    -- Add NPC locale data (name)
    if not pfDB["units"]["loc"][data.startNPC.id] then
      pfDB["units"]["loc"][data.startNPC.id] = data.startNPC.name or "Quest Giver"
    end
    
    -- Initialize NPC data if needed
    if not pfDB["units"]["data"][data.startNPC.id] then
      pfDB["units"]["data"][data.startNPC.id] = {
        ["coords"] = {},
        ["lvl"] = tostring(data.level or "?"),
      }
    end
    
    -- CRITICAL: ALSO save NPC to persistent storage
    pfQuest_InjectedData.units.loc[data.startNPC.id] = pfDB["units"]["loc"][data.startNPC.id]
    pfQuest_InjectedData.units.data[data.startNPC.id] = pfQuest_InjectedData.units.data[data.startNPC.id] or { coords = {}, lvl = tostring(data.level or "?") }
    
    -- Add NPC spawn location from quest acceptance location (if we have it)
    if data.startNPC.location and data.startNPC.location.x and data.startNPC.location.y and data.startNPC.location.zoneID then
      local loc = data.startNPC.location
      local coordExists = false
      
      if pfDB["units"]["data"][data.startNPC.id]["coords"] then
        for _, coord in ipairs(pfDB["units"]["data"][data.startNPC.id]["coords"]) do
          if coord[1] == loc.x and coord[2] == loc.y and coord[3] == loc.zoneID then
            coordExists = true
            break
          end
        end
      else
        pfDB["units"]["data"][data.startNPC.id]["coords"] = {}
      end
      
      if not coordExists then
        local coordData = {
          loc.x,
          loc.y,
          loc.zoneID,
          0 -- No respawn time for NPCs
        }
        table.insert(pfDB["units"]["data"][data.startNPC.id]["coords"], coordData)
        
        -- CRITICAL: Also save to persistent storage
        table.insert(pfQuest_InjectedData.units.data[data.startNPC.id].coords, coordData)
        
        if showMessage ~= false and pfQuest_CaptureConfig.debug then
          DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa  Added NPC spawn: (" .. math.floor(loc.x) .. ", " .. math.floor(loc.y) .. ") Zone:" .. loc.zoneID)
        end
      end
    end
    
    -- ALSO check objective locations as fallback (old method)
    if data.objectiveLocations then
      for objIndex, objData in pairs(data.objectiveLocations) do
        if objData.locations and table.getn(objData.locations) > 0 then
          local firstLoc = objData.locations[1]
          if firstLoc and firstLoc.x and firstLoc.y and firstLoc.zoneID then
            -- Initialize units database if needed
            pfDB["units"] = pfDB["units"] or {}
            pfDB["units"]["data"] = pfDB["units"]["data"] or {}
            pfDB["units"]["loc"] = pfDB["units"]["loc"] or {}
            
            -- Add NPC locale data
            if not pfDB["units"]["loc"][data.startNPC.id] then
              pfDB["units"]["loc"][data.startNPC.id] = data.startNPC.name or "Quest Giver"
            end
            
            -- Add NPC to units database
            if not pfDB["units"]["data"][data.startNPC.id] then
              pfDB["units"]["data"][data.startNPC.id] = {
                ["coords"] = {},
                ["lvl"] = tostring(data.level or "?"),
              }
            end
            
            -- Add spawn coordinate (format: {x, y, zoneID, respawn_time})
            local coordExists = false
            if pfDB["units"]["data"][data.startNPC.id]["coords"] then
              for _, coord in ipairs(pfDB["units"]["data"][data.startNPC.id]["coords"]) do
                if coord[1] == firstLoc.x and coord[2] == firstLoc.y and coord[3] == firstLoc.zoneID then
                  coordExists = true
                  break
                end
              end
            else
              pfDB["units"]["data"][data.startNPC.id]["coords"] = {}
            end
            
            if not coordExists then
              table.insert(pfDB["units"]["data"][data.startNPC.id]["coords"], {
                firstLoc.x,
                firstLoc.y,
                firstLoc.zoneID,
                0 -- No respawn time for NPCs
              })
            end
            
            break -- Only use first location
          end
        end
      end
    end
  end
  
  -- Inject end NPC and add to units database
  if data.endNPC and data.endNPC.id then
    pfDB["quests"]["data"][qid]["end"] = pfDB["quests"]["data"][qid]["end"] or {}
    pfDB["quests"]["data"][qid]["end"]["U"] = pfDB["quests"]["data"][qid]["end"]["U"] or {}
    
    -- Add to quest end units list if not already there
    local found = false
    for _, existingID in ipairs(pfDB["quests"]["data"][qid]["end"]["U"]) do
      if existingID == data.endNPC.id then
        found = true
        break
      end
    end
    
    if not found then
      table.insert(pfDB["quests"]["data"][qid]["end"]["U"], data.endNPC.id)
    end
    
    -- Add NPC spawn location to units database (use last objective location)
    if data.objectiveLocations then
      local lastLoc = nil
      for objIndex, objData in pairs(data.objectiveLocations) do
        if objData.locations and table.getn(objData.locations) > 0 then
          lastLoc = objData.locations[table.getn(objData.locations)]
        end
      end
      
      if lastLoc and lastLoc.x and lastLoc.y and lastLoc.zoneID then
        -- Initialize units database if needed
        pfDB["units"] = pfDB["units"] or {}
        pfDB["units"]["data"] = pfDB["units"]["data"] or {}
        pfDB["units"]["loc"] = pfDB["units"]["loc"] or {}
        
        -- Add end NPC locale data
        if not pfDB["units"]["loc"][data.endNPC.id] then
          pfDB["units"]["loc"][data.endNPC.id] = data.endNPC.name or "Quest Ender"
        end
        
        -- Add end NPC to units database (can be same as start NPC)
        if not pfDB["units"]["data"][data.endNPC.id] then
          pfDB["units"]["data"][data.endNPC.id] = {
            ["coords"] = {},
            ["lvl"] = tostring(data.level or "?"),
          }
        end
        
        -- Add spawn coordinate
        local coordExists = false
        if pfDB["units"]["data"][data.endNPC.id]["coords"] then
          for _, coord in ipairs(pfDB["units"]["data"][data.endNPC.id]["coords"]) do
            if coord[1] == lastLoc.x and coord[2] == lastLoc.y and coord[3] == lastLoc.zoneID then
              coordExists = true
              break
            end
          end
        else
          pfDB["units"]["data"][data.endNPC.id]["coords"] = {}
        end
        
        if not coordExists then
          table.insert(pfDB["units"]["data"][data.endNPC.id]["coords"], {
            lastLoc.x,
            lastLoc.y,
            lastLoc.zoneID,
            0 -- No respawn time for NPCs
          })
        end
      end
    end
  end
  
  -- CRITICAL: Reload database cache to update local references
  -- This ensures the injected NPCs are available in SearchQuests()
  if pfDatabase and pfDatabase.Reload then
    pfDatabase.Reload()
  end
  
  -- CRITICAL: Force immediate quest giver search to display the quest
  -- Don't wait for pfQuest's OnUpdate - trigger NOW
  if pfQuest_config and pfQuest_config["allquestgivers"] == "1" then
    local meta = { ["addon"] = "PFQUEST" }
    pfDatabase:SearchQuests(meta)
  end
  
  -- Queue map update (let pfQuest handle it naturally)
  if pfMap then
    pfMap.queue_update = GetTime()
  end
  
  -- Debug message
  if showMessage ~= false and pfQuest_CaptureConfig.debug then
    local npcCount = 0
    if data.startNPC and data.startNPC.id and pfDB["units"]["data"][data.startNPC.id] then 
      npcCount = npcCount + 1 
    end
    if data.endNPC and data.endNPC.id and pfDB["units"]["data"][data.endNPC.id] then 
      npcCount = npcCount + 1 
    end
    
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest |cff00ff00Injected:|r '|cffffcc00" .. questTitle .. "|r' [" .. (data.level or "?") .. "] min:" .. (pfDB["quests"]["data"][qid]["min"] or "?") .. " NPCs:" .. npcCount)
    DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa  Database reloaded + quest givers refreshed")
  end
end

-- Track objective progress changes
local function TrackObjectiveProgress(questTitle, objectiveIndex, objectiveText, showMessage)
  if not captureData[questTitle] then return end
  if not captureData[questTitle].objectiveLocations then
    captureData[questTitle].objectiveLocations = {}
  end
  
  -- Initialize objective tracking if not exists
  if not captureData[questTitle].objectiveLocations[objectiveIndex] then
    captureData[questTitle].objectiveLocations[objectiveIndex] = {
      text = objectiveText,
      locations = {}
    }
  else
    -- Update the objective text to always show latest progress
    captureData[questTitle].objectiveLocations[objectiveIndex].text = objectiveText
  end
  
  -- Get current player location
  local location = GetPlayerLocation()
  
  -- Only record if coordinates are valid (not 0,0 which means not on map)
  if location.x > 0 or location.y > 0 then
    -- Add location to this objective
    table.insert(captureData[questTitle].objectiveLocations[objectiveIndex].locations, {
      x = location.x,
      y = location.y,
      zone = location.zoneName,
      subZone = location.subZone,
      continent = location.continent,
      timestamp = location.timestamp
    })
    
    -- Save to permanent storage
    pfQuest_CapturedQuests[questTitle] = captureData[questTitle]
    
    -- Optional debug message (only if debug mode enabled)
    if showMessage and pfQuest_CaptureConfig.debug then
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest |cff00ccffCapture:|r Objective location recorded for '|cffffcc00" .. questTitle .. "|r' (" .. math.floor(location.x) .. ", " .. math.floor(location.y) .. ")")
    end
  end
end

-- Capture quest when viewing it (QUEST_DETAIL)
local function CaptureQuestDetail()
  local title = GetTitleText()
  if not title or title == "" then return end
  
  local npcName, npcGUID, npcType = GetTargetInfo()
  local npcID = GetIDFromGUID(npcGUID)
  
  -- If no target info, try using last interacted NPC (for gossip menus)
  if (not npcName or not npcID) and lastInteractedNPC and (time() - lastInteractedNPC.timestamp) < 10 then
    npcName = lastInteractedNPC.name
    npcGUID = lastInteractedNPC.guid
    npcID = lastInteractedNPC.id
    npcType = lastInteractedNPC.type
    
    if pfQuest_CaptureConfig.debug then
      DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa[DEBUG] Using last interacted NPC: " .. npcName .. " (ID: " .. npcID .. ")")
    end
  end
  
  -- If still no NPC, search recent NPC cache (60 second window)
  if (not npcName or not npcID) and table.getn(recentNPCs) > 0 then
    local now = time()
    -- Find most recent NPC within 60 seconds
    for i = table.getn(recentNPCs), 1, -1 do
      local cached = recentNPCs[i]
      if (now - cached.timestamp) < 60 then
        npcName = cached.name
        npcGUID = cached.guid
        npcID = cached.id
        npcType = cached.type
        
        if pfQuest_CaptureConfig.debug then
          DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa[DEBUG] Using recent NPC cache: " .. npcName .. " (ID: " .. npcID .. ") [" .. (now - cached.timestamp) .. "s ago]")
        end
        break
      end
    end
  end
  
  -- Store NPC info for when quest is accepted
  if npcName and npcID then
    pendingQuestNPC = {
      questTitle = title,
      name = npcName,
      id = npcID,
      type = npcType,
      timestamp = time(),
    }
    
    if pfQuest_CaptureConfig.debug then
      DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa[DEBUG] Cached start NPC for '" .. title .. "': " .. npcName .. " (ID: " .. npcID .. ")")
    end
  else
    if pfQuest_CaptureConfig.debug then
      DEFAULT_CHAT_FRAME:AddMessage("|cffff5555[DEBUG] Failed to cache start NPC for '" .. title .. "' (no target or interaction info)")
    end
  end
  
  -- Initialize quest data if new
  if not captureData[title] then
    captureData[title] = {
      title = title,
      description = GetQuestText(),
      startNPC = {},
      endNPC = {},
      objectives = {},
      questItems = {},
      rewards = {},
      choiceRewards = {},
      timestamp = time(),
    }
  end
  
  -- Store start NPC info immediately
  if pendingQuestNPC then
    captureData[title].startNPC = {
      name = pendingQuestNPC.name,
      id = pendingQuestNPC.id,
      type = pendingQuestNPC.type,
    }
  end
  
  -- Get objectives from quest detail window
  local objectives = GetObjectiveText()
  if objectives then
    captureData[title].detailObjectives = objectives
  end
end

-- Capture quest when accepted (added to quest log)
local function CaptureQuestAccepted()
  local title = arg1  -- QUEST_ACCEPTED event provides title in arg1
  if not title or title == "" then return end
  
  -- Delay to ensure quest is in log
  local captureFrame = CreateFrame("Frame")
  captureFrame.timer = 0
  captureFrame.questTitle = title
  captureFrame:SetScript("OnUpdate", function()
    this.timer = this.timer + arg1
    if this.timer > 0.3 then
      -- Find quest in log
      local numEntries = GetNumQuestLogEntries()
      for i = 1, numEntries do
        local questTitle, level, questTag, isHeader = GetQuestLogTitle(i)
        
        if questTitle == this.questTitle and not isHeader then
          SelectQuestLogEntry(i)
          
          -- Initialize if not exists
          if not captureData[questTitle] then
            captureData[questTitle] = {
              title = questTitle,
              startNPC = {},
              endNPC = {},
              objectives = {},
              questItems = {},
              rewards = {},
              choiceRewards = {},
              timestamp = time(),
            }
          end
          
          -- Store quest metadata
          captureData[questTitle].level = level
          captureData[questTitle].tag = questTag
          captureData[questTitle].description = GetQuestLogQuestText()
          
          -- Get objectives
          local numObjectives = GetNumQuestLeaderBoards(i)
          captureData[questTitle].objectives = {}
          for j = 1, numObjectives do
            local text, type, finished = GetQuestLogLeaderBoard(j, i)
            if text then
              table.insert(captureData[questTitle].objectives, {
                text = text,
                type = type,
              })
            end
          end
          
          -- Get rewards
          local numRewards = GetNumQuestLogRewards(i)
          captureData[questTitle].rewards = {}
          for j = 1, numRewards do
            local itemName, itemTexture, itemQuantity = GetQuestLogRewardInfo(j, i)
            if itemName then
              table.insert(captureData[questTitle].rewards, {
                name = itemName,
                quantity = itemQuantity,
              })
            end
          end
          
          -- Get choice rewards
          local numChoices = GetNumQuestLogChoices(i)
          captureData[questTitle].choiceRewards = {}
          for j = 1, numChoices do
            local itemName, itemTexture, itemQuantity = GetQuestLogChoiceInfo(j, i)
            if itemName then
              table.insert(captureData[questTitle].choiceRewards, {
                name = itemName,
                quantity = itemQuantity,
              })
            end
          end
          
          DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest Capture: Tracking '|cffffcc00" .. questTitle .. "|r' [" .. level .. "]")
          break
        end
      end
      
      this:SetScript("OnUpdate", nil)
    end
  end)
end

-- Capture quest turn-in NPC (OPTIMIZED - minimal processing)
local function CaptureQuestComplete()
  local title = GetTitleText()
  if not title or title == "" then return end
  
  -- Initialize if doesn't exist
  if not captureData[title] then
    captureData[title] = {
      title = title,
      startNPC = {},
      endNPC = {},
      objectives = {},
      questItems = {},
      rewards = {},
      choiceRewards = {},
      timestamp = time(),
    }
  end
  
  -- Quick NPC capture - no heavy operations
  local npcName, npcGUID, npcType = GetTargetInfo()
  local npcID = GetIDFromGUID(npcGUID)
  
  if npcName and npcID then
    captureData[title].endNPC = {
      name = npcName,
      id = npcID,
      type = npcType,
    }
    
    if pfQuest_CaptureConfig.debug then
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest Capture: '|cffffcc00" .. title .. "|r' completed at |cff55ff55" .. npcName .. " (ID: " .. npcID .. ")")
    end
  else
    if pfQuest_CaptureConfig.debug then
      DEFAULT_CHAT_FRAME:AddMessage("|cffff5555[DEBUG] Failed to capture end NPC for '" .. title .. "' (no target info)")
    end
  end
end

-- Capture when quest is finished (removed from log)
local function CaptureQuestFinished()
  -- Save all current capture data to permanent storage
  for title, data in pairs(captureData) do
    if data.level then  -- Only save if quest was actually tracked
      pfQuest_CapturedQuests[title] = data
    end
  end
  
  -- Clear temporary capture data
  captureData = {}
end

-- Track quest item drops from kills
local function TrackQuestItemDrop(itemLink)
  if not itemLink then return end
  
  -- Extract item name
  local _, _, itemName = string.find(itemLink, "%[(.+)%]")
  if not itemName then return end
  
  -- Check if this is a quest item (usually starts with quest-related text)
  local itemType = GetItemInfo(itemLink)
  
  -- Get current target info (what dropped the item)
  local targetName = UnitName("target")
  local targetGUID = UnitGUID("target")
  local targetID = GetIDFromGUID(targetGUID)
  
  -- Try to match item to active quests
  local numEntries = GetNumQuestLogEntries()
  for i = 1, numEntries do
    local questTitle, level, questTag, isHeader = GetQuestLogTitle(i)
    
    if questTitle and not isHeader and captureData[questTitle] then
      -- Check if this item is mentioned in objectives
      for _, obj in pairs(captureData[questTitle].objectives or {}) do
        if obj.text and string.find(obj.text, itemName) then
          -- This item belongs to this quest!
          if not captureData[questTitle].questItems then
            captureData[questTitle].questItems = {}
          end
          
          table.insert(captureData[questTitle].questItems, {
            itemName = itemName,
            sourceNPC = targetName,
            sourceID = targetID,
            timestamp = time(),
          })
          
          DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest Capture: Quest item |cff00ff00" .. itemName .. "|r from |cffffcc00" .. (targetName or "Unknown"))
          break
        end
      end
    end
  end
end

-- Hook into pfQuest's quest detection system (more reliable!)
function pfQuestCapture_OnNewQuest(questTitle, questID, qlogID)
  if not pfQuest_CaptureConfig.enabled then return end
  if not questTitle or questTitle == "" then return end
  
  -- Initialize quest data if new
  if not captureData[questTitle] then
    captureData[questTitle] = {
      title = questTitle,
      questID = questID,
      startNPC = {},
      endNPC = {},
      objectives = {},
      questItems = {},
      rewards = {},
      choiceRewards = {},
      timestamp = time(),
    }
  end
  
    -- Get quest data from quest log using the qlogID
    SelectQuestLogEntry(qlogID)
    local questText = GetQuestLogQuestText()
    local level, questTag = select(2, GetQuestLogTitle(qlogID))
    
    captureData[questTitle].description = questText
    captureData[questTitle].level = level
    captureData[questTitle].questID = questID
    
    -- CRITICAL: Detect class-specific quests
    -- Quest tag can be "Warrior", "Hunter", "Paladin", etc. for class quests
    if questTag and questTag ~= "" then
      -- Check if the tag is a class name
      local classNames = {
        ["Warrior"] = 1,
        ["Paladin"] = 2,
        ["Hunter"] = 4,
        ["Rogue"] = 8,
        ["Priest"] = 16,
        ["Death Knight"] = 32,
        ["Shaman"] = 64,
        ["Mage"] = 128,
        ["Warlock"] = 256,
        ["Druid"] = 1024,
      }
      
      if classNames[questTag] then
        captureData[questTitle].classRestriction = classNames[questTag]
        
        if pfQuest_CaptureConfig.debug then
          DEFAULT_CHAT_FRAME:AddMessage("|cffff9900[Class Quest] " .. questTitle .. " is for " .. questTag .. " (bit: " .. classNames[questTag] .. ")")
        end
      end
    end
  
  -- Get objectives
  local numObjectives = GetNumQuestLeaderBoards(qlogID)
  captureData[questTitle].objectives = {}
  for j = 1, numObjectives do
    local text, type, finished = GetQuestLogLeaderBoard(j, qlogID)
    if text then
      table.insert(captureData[questTitle].objectives, {
        text = text,
        type = type,
      })
    end
  end
  
  -- Get rewards
  local numRewards = GetNumQuestLogRewards(qlogID)
  captureData[questTitle].rewards = {}
  for j = 1, numRewards do
    local itemName, itemTexture, itemQuantity = GetQuestLogRewardInfo(j, qlogID)
    if itemName then
      table.insert(captureData[questTitle].rewards, {
        name = itemName,
        quantity = itemQuantity,
      })
    end
  end
  
  -- Get choice rewards
  local numChoices = GetNumQuestLogChoices(qlogID)
  captureData[questTitle].choiceRewards = {}
  for j = 1, numChoices do
    local itemName, itemTexture, itemQuantity = GetQuestLogChoiceInfo(j, qlogID)
    if itemName then
      table.insert(captureData[questTitle].choiceRewards, {
        name = itemName,
        quantity = itemQuantity,
      })
    end
  end
  
  -- Capture player's current location (this is where the quest giver is)
  local location = GetPlayerLocation()
  
  -- Try to use cached NPC info from QUEST_DETAIL
  if pendingQuestNPC and pendingQuestNPC.questTitle == questTitle and (time() - pendingQuestNPC.timestamp) < 30 then
    -- Use cached NPC info (within 30 seconds)
    captureData[questTitle].startNPC = {
      name = pendingQuestNPC.name,
      id = pendingQuestNPC.id,
      type = pendingQuestNPC.type,
      location = location, -- Store NPC's spawn location
    }
    
    if pfQuest_CaptureConfig.debug then
      DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa[DEBUG] Using cached start NPC: " .. pendingQuestNPC.name .. " (ID: " .. pendingQuestNPC.id .. ") at (" .. math.floor(location.x) .. ", " .. math.floor(location.y) .. ")")
    end
    
    -- Clear pending NPC after use
    pendingQuestNPC = nil
  else
    -- Try to get NPC info from current target (fallback)
    local npcName, npcGUID, npcType = GetTargetInfo()
    local npcID = GetIDFromGUID(npcGUID)
    
    if npcName and npcID then
      captureData[questTitle].startNPC = {
        name = npcName,
        id = npcID,
        type = npcType,
        location = location, -- Store NPC's spawn location
      }
      
      if pfQuest_CaptureConfig.debug then
        DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa[DEBUG] Captured start NPC from target: " .. npcName .. " (ID: " .. npcID .. ") at (" .. math.floor(location.x) .. ", " .. math.floor(location.y) .. ")")
      end
    else
      if pfQuest_CaptureConfig.debug then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff5555[DEBUG] Failed to capture start NPC (no cached or target info)")
      end
    end
  end
  
  -- Debug message only
  if pfQuest_CaptureConfig.debug then
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest |cff55ff55Capture:|r Tracking '|cffffcc00" .. questTitle .. "|r' [" .. level .. "]")
  end
  
  -- Update UI if it's open
  if pfQuestCaptureUI and pfQuestCaptureUI:IsShown() then
    pfQuestCaptureUI:UpdateUI()
  end
end

-- Check for objective progress changes
-- Add throttling to prevent performance issues
local lastObjectiveCheck = 0
function CheckObjectiveProgress()
  if not pfQuest_CaptureConfig.enabled then return end
  
  -- OPTIMIZATION: Throttle to max once per 3 seconds to prevent breaking quest objectives
  -- This is purely for data collection, not real-time tracking
  local now = GetTime()
  if now - lastObjectiveCheck < 3.0 then
    return
  end
  lastObjectiveCheck = now
  
  local numEntries, numQuests = GetNumQuestLogEntries()
  
  for i = 1, (numEntries or 0) do
    local questTitle, level, questTag, isHeader, isCollapsed, isComplete = GetQuestLogTitle(i)
    
    -- Only process actual quests
    if questTitle and (isHeader == 0 or isHeader == nil or isHeader == false) then
      SelectQuestLogEntry(i)
      
      -- Get current objectives
      local numObjectives = GetNumQuestLeaderBoards(i)
      
      for j = 1, numObjectives do
        local text, type, finished = GetQuestLogLeaderBoard(j, i)
        
        if text then
          -- Create unique key for this objective
          local objKey = questTitle .. "_" .. j
          
          -- Check if objective has changed
          if previousObjectives[objKey] ~= text then
            -- Objective has changed (progressed or regressed)
            
            -- Only track if it's a kill/collect objective (has numbers like "0/12")
            local current, total = string.match(text, "(%d+)/(%d+)")
            if current and total then
              current = tonumber(current)
              total = tonumber(total)
              
              -- Get previous count (if exists)
              local prevCurrent = 0
              if previousObjectives[objKey] then
                prevCurrent = tonumber((string.match(previousObjectives[objKey], "(%d+)/(%d+)"))) or 0
              end
              
              -- Only track if count increased (progress, not regression)
              if current > prevCurrent then
                -- Track this location as an objective location
                -- Show message if this is the first location for this objective
                local showMsg = not captureData[questTitle] or 
                                not captureData[questTitle].objectiveLocations or 
                                not captureData[questTitle].objectiveLocations[j] or 
                                table.getn(captureData[questTitle].objectiveLocations[j].locations or {}) == 0
                TrackObjectiveProgress(questTitle, j, text, showMsg)
              end
            end
            
            -- Update previous state
            previousObjectives[objKey] = text
          end
        end
      end
    end
  end
end

-- Scan quest log function (extracted for reuse)
function ScanQuestLog(showDebug)
  if not pfQuest_CaptureConfig.enabled then return 0 end
  
  showDebug = showDebug or false
  if showDebug then
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest Capture: Scanning quest log...")
  end
  
  -- GetNumQuestLogEntries() returns: numEntries (including headers), numQuests (actual quests)
  local numEntries, numQuests = GetNumQuestLogEntries()
  local found = 0
  
  if showDebug then
    DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa[DEBUG] Quest log has " .. (numEntries or 0) .. " entries, " .. (numQuests or 0) .. " quests")
  end
  
  -- Scan all entries (including headers to filter them out)
  for i = 1, (numEntries or 0) do
    local questTitle, level, questTag, isHeader, isCollapsed, isComplete = GetQuestLogTitle(i)
    
    if showDebug then
      DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa[DEBUG] Entry " .. i .. ": " .. (questTitle or "nil") .. ", isHeader=" .. tostring(isHeader))
    end
    
    -- In Lua, 0 is truthy! We need to check if isHeader is actually 1 or nil/false
    -- Headers have isHeader = 1, quests have isHeader = 0 or nil
    if questTitle and (isHeader == 0 or isHeader == nil or isHeader == false) then
      SelectQuestLogEntry(i)
      
      -- Try to get quest ID from pfQuest database
      local questID = nil
      if pfDB and pfDB["quests"] and pfDB["quests"]["loc"] then
        for qid, qdata in pairs(pfDB["quests"]["loc"]) do
          if qdata["T"] == questTitle then
            questID = qid
            break
          end
        end
      end
      
      -- Initialize quest data
      if not captureData[questTitle] then
        captureData[questTitle] = {
          title = questTitle,
          questID = questID or ("custom_" .. i),
          startNPC = {},
          endNPC = {},
          objectives = {},
          questItems = {},
          rewards = {},
          choiceRewards = {},
          timestamp = time(),
        }
      end
      
      captureData[questTitle].level = level
      captureData[questTitle].description = GetQuestLogQuestText()
      
      -- Get objectives
      local numObjectives = GetNumQuestLeaderBoards(i)
      captureData[questTitle].objectives = {}
      for j = 1, numObjectives do
        local text, type, finished = GetQuestLogLeaderBoard(j, i)
        if text then
          table.insert(captureData[questTitle].objectives, {
            text = text,
            type = type,
          })
        end
      end
      
      -- Get rewards
      local numRewards = GetNumQuestLogRewards(i)
      captureData[questTitle].rewards = {}
      for j = 1, numRewards do
        local itemName, itemTexture, itemQuantity = GetQuestLogRewardInfo(j, i)
        if itemName then
          table.insert(captureData[questTitle].rewards, {
            name = itemName,
            quantity = itemQuantity,
          })
        end
      end
      
      -- Get choice rewards
      local numChoices = GetNumQuestLogChoices(i)
      captureData[questTitle].choiceRewards = {}
      for j = 1, numChoices do
        local itemName, itemTexture, itemQuantity = GetQuestLogChoiceInfo(j, i)
        if itemName then
          table.insert(captureData[questTitle].choiceRewards, {
            name = itemName,
            quantity = itemQuantity,
          })
        end
      end
      
      -- Save to permanent storage immediately
      pfQuest_CapturedQuests[questTitle] = captureData[questTitle]
      
      if showDebug then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest |cff55ff55Capture:|r Tracking '|cffffcc00" .. questTitle .. "|r' [" .. level .. "]")
      end
      found = found + 1
    end
  end
  
  if showDebug then
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest Capture: Scanned " .. found .. " quests in quest log")
  end
  
  if pfQuestCaptureUI and pfQuestCaptureUI:IsShown() then
    pfQuestCaptureUI:UpdateUI()
  end
  
  return found
end

-- REMOVED: NPC monitor frame (was causing performance issues)
-- NPC caching is now handled efficiently by PLAYER_TARGET_CHANGED and UPDATE_MOUSEOVER_UNIT events
-- This eliminates the constant OnUpdate overhead

-- OPTIMIZED: Periodic scan timer (5 minutes for quest log scan)
local periodicScanFrame = CreateFrame("Frame")
periodicScanFrame.timer = 0
periodicScanFrame.objectiveTimer = 0
periodicScanFrame.scanInterval = 300 -- 5 minutes for full scan
periodicScanFrame.objectiveInterval = 10 -- 10 seconds for objective check (was every QUEST_LOG_UPDATE!)
periodicScanFrame:SetScript("OnUpdate", function()
  if not pfQuest_CaptureConfig.enabled then return end
  
  this.timer = this.timer + arg1
  this.objectiveTimer = this.objectiveTimer + arg1
  
  -- Check objectives every 10 seconds instead of every QUEST_LOG_UPDATE
  -- This prevents breaking quest objective display while still tracking progress
  if this.objectiveTimer >= this.objectiveInterval then
    this.objectiveTimer = 0
    CheckObjectiveProgress() -- Now throttled to 10 second intervals
  end
  
  -- Full quest log scan every 5 minutes
  if this.timer >= this.scanInterval then
    this.timer = 0
    ScanQuestLog(false) -- Silent periodic scan
    
    -- DO NOT auto-inject - breaks quest objectives
    -- User can manually inject with /pfquest capture inject
    -- InjectAllCapturedQuests(false) -- false = silent mode
  end
end)

-- Event handler
local capture = CreateFrame("Frame")

-- Function to register/unregister all capture events
local function UpdateCaptureEvents()
  if pfQuest_CaptureConfig.enabled then
    capture:RegisterEvent("PLAYER_TARGET_CHANGED")
    capture:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
    capture:RegisterEvent("GOSSIP_SHOW")
    capture:RegisterEvent("QUEST_GREETING")
    capture:RegisterEvent("QUEST_DETAIL")
    capture:RegisterEvent("QUEST_COMPLETE")
    capture:RegisterEvent("QUEST_FINISHED")
    capture:RegisterEvent("QUEST_ACCEPTED")
    capture:RegisterEvent("QUEST_LOG_UPDATE")
    capture:RegisterEvent("CHAT_MSG_LOOT")
  else
    capture:UnregisterEvent("PLAYER_TARGET_CHANGED")
    capture:UnregisterEvent("UPDATE_MOUSEOVER_UNIT")
    capture:UnregisterEvent("GOSSIP_SHOW")
    capture:UnregisterEvent("QUEST_GREETING")
    capture:UnregisterEvent("QUEST_DETAIL")
    capture:UnregisterEvent("QUEST_COMPLETE")
    capture:UnregisterEvent("QUEST_FINISHED")
    capture:UnregisterEvent("QUEST_ACCEPTED")
    capture:UnregisterEvent("QUEST_LOG_UPDATE")
    capture:UnregisterEvent("CHAT_MSG_LOOT")
  end
end

-- Always register PLAYER_LOGIN to initialize
capture:RegisterEvent("PLAYER_LOGIN")

-- Merge pfQuest_InjectedData into pfDB on addon load
-- This makes injected quests persist across /reload
local function MergeInjectedDataIntoDatabase()
  if not pfDB or not pfQuest_InjectedData then return end
  
  local questCount = 0
  local npcCount = 0
  
  -- Merge quest locale data
  if pfQuest_InjectedData.quests and pfQuest_InjectedData.quests.loc then
    pfDB["quests"] = pfDB["quests"] or {}
    pfDB["quests"]["loc"] = pfDB["quests"]["loc"] or {}
    
    for qid, locData in pairs(pfQuest_InjectedData.quests.loc) do
      pfDB["quests"]["loc"][qid] = locData
      questCount = questCount + 1
    end
  end
  
  -- Merge quest metadata
  if pfQuest_InjectedData.quests and pfQuest_InjectedData.quests.data then
    pfDB["quests"]["data"] = pfDB["quests"]["data"] or {}
    
    for qid, questData in pairs(pfQuest_InjectedData.quests.data) do
      pfDB["quests"]["data"][qid] = questData
    end
  end
  
  -- Merge NPC locale data
  if pfQuest_InjectedData.units and pfQuest_InjectedData.units.loc then
    pfDB["units"] = pfDB["units"] or {}
    pfDB["units"]["loc"] = pfDB["units"]["loc"] or {}
    
    for npcID, name in pairs(pfQuest_InjectedData.units.loc) do
      pfDB["units"]["loc"][npcID] = name
      npcCount = npcCount + 1
    end
  end
  
  -- Merge NPC data
  if pfQuest_InjectedData.units and pfQuest_InjectedData.units.data then
    pfDB["units"]["data"] = pfDB["units"]["data"] or {}
    
    for npcID, npcData in pairs(pfQuest_InjectedData.units.data) do
      pfDB["units"]["data"][npcID] = npcData
    end
  end
  
  -- Reload database cache to pick up merged data
  if pfDatabase and pfDatabase.Reload and questCount > 0 then
    pfDatabase.Reload()
    
    if pfQuest_CaptureConfig.debug then
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest Capture: Loaded " .. questCount .. " injected quests and " .. npcCount .. " NPCs from SavedVariables")
    end
  end
end

capture:SetScript("OnEvent", function()
  -- Handle PLAYER_LOGIN first (before checking enabled flag)
  if event == "PLAYER_LOGIN" then
    -- DO NOT auto-merge on login - it breaks quest objectives
    -- User can manually inject with /pfquest capture inject if needed
    -- MergeInjectedDataIntoDatabase()
    
    -- Register/unregister events based on enabled state
    UpdateCaptureEvents()
    
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest Capture: " .. (pfQuest_CaptureConfig.enabled and "|cff00ff00ENABLED" or "|cffff5555DISABLED"))
    return
  end
  
  if not pfQuest_CaptureConfig.enabled then return end
  
  if event == "PLAYER_TARGET_CHANGED" or event == "UPDATE_MOUSEOVER_UNIT" then
    -- Cache NPC when you target or mouseover them
    local unit = (event == "PLAYER_TARGET_CHANGED") and "target" or "mouseover"
    
    if UnitExists(unit) and not UnitIsPlayer(unit) then
      local npcName = UnitName(unit)
      local npcGUID = UnitGUID(unit)
      local npcType = UnitCreatureType(unit) or "NPC"
      
      -- Debug: Show GUID and extraction attempt
      if pfQuest_CaptureConfig.debug then
        DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa[DEBUG] Unit: " .. (npcName or "nil") .. " | GUID: " .. (npcGUID or "nil"))
      end
      
      local npcID = GetIDFromGUID(npcGUID)
      
      if pfQuest_CaptureConfig.debug and not npcID then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff5555[DEBUG] Failed to extract ID from GUID!")
      end
      
      if npcName and npcID then
        -- Add to recent NPCs cache
        table.insert(recentNPCs, {
          name = npcName,
          guid = npcGUID,
          id = npcID,
          type = npcType,
          timestamp = time(),
        })
        
        -- Keep only last 20 NPCs
        if table.getn(recentNPCs) > 20 then
          table.remove(recentNPCs, 1)
        end
        
        -- Also store as last interacted
        lastInteractedNPC = {
          name = npcName,
          guid = npcGUID,
          id = npcID,
          type = npcType,
          timestamp = time(),
        }
        
        if pfQuest_CaptureConfig.debug then
          local source = (event == "PLAYER_TARGET_CHANGED") and "Target" or "Mouseover"
          DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa[" .. source .. "] Cached NPC: " .. npcName .. " (ID: " .. npcID .. ")")
        end
      elseif npcName and pfQuest_CaptureConfig.debug then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff5555[DEBUG] NPC name exists but ID extraction failed: " .. npcName)
      end
    end
  elseif event == "GOSSIP_SHOW" or event == "QUEST_GREETING" then
    -- Cache the NPC when gossip/greeting opens (before quest detail)
    local npcName, npcGUID, npcType = GetTargetInfo()
    local npcID = GetIDFromGUID(npcGUID)
    
    if npcName and npcID then
      lastInteractedNPC = {
        name = npcName,
        guid = npcGUID,
        id = npcID,
        type = npcType,
        timestamp = time(),
      }
      
      if pfQuest_CaptureConfig.debug then
        DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa[DEBUG] Cached interacted NPC: " .. npcName .. " (ID: " .. npcID .. ")")
      end
    end
  elseif event == "QUEST_DETAIL" then
    CaptureQuestDetail()
  elseif event == "QUEST_COMPLETE" then
    CaptureQuestComplete()
  elseif event == "QUEST_FINISHED" then
    -- DEFER heavy database operations to avoid blocking
    local deferFrame = CreateFrame("Frame")
    deferFrame.timer = 0
    deferFrame:SetScript("OnUpdate", function()
      this.timer = this.timer + arg1
      if this.timer < 0.2 then return end -- Wait 0.2 seconds after quest finishes
      
      -- Save current capture data to permanent storage AND inject into pfDB
      for title, data in pairs(captureData) do
        if data.level then
          pfQuest_CapturedQuests[title] = data
          
          -- Debug message only
          if pfQuest_CaptureConfig.debug then
            DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest |cff55ff55Capture:|r Saved '|cffffcc00" .. title .. "|r'")
          end
          
          -- DO NOT auto-inject - breaks quest objectives
          -- InjectQuestIntoDatabase(title, data, pfQuest_CaptureConfig.debug)
        end
      end
      
      -- DO NOT auto-inject - corrupts quest objectives
      -- User can manually inject with /pfquest capture inject
      -- InjectAllCapturedQuests(false)
      
      -- Update UI if open
      if pfQuestCaptureUI and pfQuestCaptureUI:IsShown() then
        pfQuestCaptureUI:UpdateUI()
      end
      
      -- Clean up
      this:SetScript("OnUpdate", nil)
    end)
  elseif event == "CHAT_MSG_LOOT" then
    -- arg1 contains the loot message
    local _, _, itemLink = string.find(arg1, "|c%x+|H(item:%d+:%d+:%d+:%d+)|h%[.-%]|h|r")
    if itemLink then
      TrackQuestItemDrop(itemLink)
    end
  elseif event == "QUEST_COMPLETE" then
    -- Quest completed - scan to capture completion data
    -- OPTIMIZATION: Reuse global delay frame instead of creating new ones
    if not pfQuestCapture_DelayFrame then
      pfQuestCapture_DelayFrame = CreateFrame("Frame")
    end
    pfQuestCapture_DelayFrame.timer = 0
    pfQuestCapture_DelayFrame.action = "COMPLETE"
    pfQuestCapture_DelayFrame:SetScript("OnUpdate", function()
      this.timer = this.timer + arg1
      if this.timer >= 1.0 then
        this:SetScript("OnUpdate", nil)
        ScanQuestLog(false) -- Silent scan
      end
    end)
  elseif event == "QUEST_ACCEPTED" then
    -- Quest accepted - scan and inject captured quests
    -- OPTIMIZATION: Reuse global delay frame instead of creating new ones
    if not pfQuestCapture_DelayFrame then
      pfQuestCapture_DelayFrame = CreateFrame("Frame")
    end
    pfQuestCapture_DelayFrame.timer = 0
    pfQuestCapture_DelayFrame.action = "ACCEPTED"
    pfQuestCapture_DelayFrame:SetScript("OnUpdate", function()
      this.timer = this.timer + arg1
      if this.timer >= 0.5 then
        this:SetScript("OnUpdate", nil)
        ScanQuestLog(false) -- Silent scan
        -- Objective progress now checked by periodic timer (every 10s) to prevent corruption
        
        -- DO NOT auto-inject - breaks quest objectives
        -- InjectAllCapturedQuests(false) -- Silent injection
      end
    end)
  elseif event == "QUEST_LOG_UPDATE" then
    -- OPTIMIZATION: DISABLED - This event fires TOO frequently (100+ times/second)
    -- Objective checking moved to periodic timer only to prevent breaking quest display
    -- CheckObjectiveProgress() -- DISABLED - breaks quest objectives display
  elseif event == "PLAYER_LOGIN" then
    -- Scan quest log on login and inject captured quests
    local delayFrame = CreateFrame("Frame")
    delayFrame.timer = 0
    delayFrame:SetScript("OnUpdate", function()
      this.timer = this.timer + arg1
      if this.timer >= 2.0 then
        this:SetScript("OnUpdate", nil)
        ScanQuestLog(false) -- Silent scan on login
        
        -- DO NOT auto-inject - corrupts quest objectives
        -- User can manually inject with /pfquest capture inject
        -- local count = InjectAllCapturedQuests(false)
        -- if count > 0 and pfQuest_CaptureConfig.debug then
        --   DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest Capture: Auto-injected " .. count .. " quests into live database")
        -- end
      end
    end)
    
    local count = 0
    for _ in pairs(pfQuest_CapturedQuests) do
      count = count + 1
    end
    
    -- Only show status on login if debug mode is enabled
    if pfQuest_CaptureConfig.debug then
      if count > 0 then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest Capture: Loaded " .. count .. " captured quests - Type |cff33ffcc/questcapture|r to view")
      end
      
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest Capture: " .. (pfQuest_CaptureConfig.enabled and "|cff55ff55ACTIVE" or "|cffff5555DISABLED") .. " - Type |cff33ffcc/questcapture help|r for info")
    end
  end
end)

-- Slash command
SLASH_PFQUESTCAPTURE1 = "/questcapture"
SLASH_PFQUESTCAPTURE2 = "/qcapture"
SlashCmdList["PFQUESTCAPTURE"] = function(msg)
  if msg == "" then
    -- Toggle UI
    if pfQuestCaptureUI then
      if pfQuestCaptureUI:IsShown() then
        pfQuestCaptureUI:Hide()
      else
        pfQuestCaptureUI:Show()
        pfQuestCaptureUI:UpdateUI()
      end
    end
    return
  end
  
  if msg == "toggle" then
    pfQuest_CaptureConfig.enabled = not pfQuest_CaptureConfig.enabled
    
    -- Register/unregister all capture events
    UpdateCaptureEvents()
    
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest Capture: " .. (pfQuest_CaptureConfig.enabled and "|cff55ff55ENABLED" or "|cffff5555DISABLED"))
    DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa  All capture events " .. (pfQuest_CaptureConfig.enabled and "registered" or "unregistered"))
    
    -- Update tracker button color if it exists
    if pfQuestTracker and pfQuestTracker.btncapture and pfQuestTracker.btncapture.UpdateColor then
      pfQuestTracker.btncapture.UpdateColor()
    end
    
    -- Update capture UI toggle button if it's open
    if pfQuestCaptureUI and pfQuestCaptureUI.toggleBtn and pfQuestCaptureUI.toggleBtn.UpdateAppearance then
      pfQuestCaptureUI.toggleBtn.UpdateAppearance()
    end
    
    return
  end
  
  if msg == "debug" then
    pfQuest_CaptureConfig.debug = not pfQuest_CaptureConfig.debug
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest Capture Debug: " .. (pfQuest_CaptureConfig.debug and "|cff55ff55ENABLED" or "|cffff5555DISABLED"))
    return
  end
  
  if string.sub(msg, 1, 8) == "debugnpc" then
    -- Debug NPC data
    local npcIDStr = string.sub(msg, 10)
    local npcID = tonumber(npcIDStr)
    
    if not npcID then
      DEFAULT_CHAT_FRAME:AddMessage("|cffff5555Usage: /questcapture debugnpc <npc id>")
      return
    end
    
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest NPC Debug: |cffffcc00" .. npcID)
    DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    if pfDB and pfDB.units then
      -- Check locale
      if pfDB.units.loc and pfDB.units.loc[npcID] then
        DEFAULT_CHAT_FRAME:AddMessage("|cff55ff55✓ NPC Name: " .. pfDB.units.loc[npcID])
      else
        DEFAULT_CHAT_FRAME:AddMessage("|cffff5555✗ NPC Name: MISSING from units.loc")
      end
      
      -- Check data
      if pfDB.units.data and pfDB.units.data[npcID] then
        DEFAULT_CHAT_FRAME:AddMessage("|cff55ff55✓ NPC Data EXISTS")
        
        local coords = pfDB.units.data[npcID].coords or {}
        DEFAULT_CHAT_FRAME:AddMessage("  Spawn Count: " .. table.getn(coords))
        for i, coord in ipairs(coords) do
          DEFAULT_CHAT_FRAME:AddMessage("    - (" .. coord[1] .. ", " .. coord[2] .. ") Zone:" .. coord[3])
        end
        
        DEFAULT_CHAT_FRAME:AddMessage("  Level: " .. tostring(pfDB.units.data[npcID].lvl or "?"))
        DEFAULT_CHAT_FRAME:AddMessage("  Faction: " .. tostring(pfDB.units.data[npcID].fac or "NONE (shows for all)"))
        
        -- Check which quests use this NPC
        local questCount = 0
        for qid, qdata in pairs(pfDB.quests.data) do
          if qdata.start and qdata.start.U then
            for _, uid in ipairs(qdata.start.U) do
              if uid == npcID then
                local qname = pfDB.quests.loc[qid] and pfDB.quests.loc[qid].T or "Unknown"
                DEFAULT_CHAT_FRAME:AddMessage("  Quest: " .. qid .. " = " .. qname)
                questCount = questCount + 1
              end
            end
          end
        end
        DEFAULT_CHAT_FRAME:AddMessage("  Used by " .. questCount .. " quests")
      else
        DEFAULT_CHAT_FRAME:AddMessage("|cffff5555✗ NPC Data: MISSING from units.data")
      end
    else
      DEFAULT_CHAT_FRAME:AddMessage("|cffff5555✗ pfDB.units doesn't exist!")
    end
    
    DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    return
  end
  
  if string.sub(msg, 1, 5) == "check" then
    -- Check what's in pfDB for a specific quest
    local questName = string.sub(msg, 7) -- Get quest name after "check "
    if questName == "" then
      DEFAULT_CHAT_FRAME:AddMessage("|cffff5555Usage: /questcapture check <quest name>")
      return
    end
    
    -- Find quest in captured data (search both active tracking and saved data)
    local found = nil
    local searchTerm = string.lower(string.gsub(questName, "[%s%-]", "")) -- Remove spaces and hyphens
    
    -- First, search active tracking (captureData)
    for title, data in pairs(captureData) do
      local titleLower = string.lower(string.gsub(title, "[%s%-]", ""))
      if string.find(titleLower, searchTerm) or string.find(searchTerm, titleLower) then
        found = {title = title, data = data, source = "active"}
        break
      end
    end
    
    -- If not found, search saved data (pfQuest_CapturedQuests)
    if not found then
      for title, data in pairs(pfQuest_CapturedQuests) do
        local titleLower = string.lower(string.gsub(title, "[%s%-]", ""))
        if string.find(titleLower, searchTerm) or string.find(searchTerm, titleLower) then
          found = {title = title, data = data, source = "saved"}
          break
        end
      end
    end
    
    -- Debug: Show what we searched for
    if pfQuest_CaptureConfig.debug then
      DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa[DEBUG] Search term: '" .. searchTerm .. "'")
    end
    
    if not found then
      -- Count quests in each table
      local activeCount = 0
      for _ in pairs(captureData) do activeCount = activeCount + 1 end
      local savedCount = 0
      for _ in pairs(pfQuest_CapturedQuests) do savedCount = savedCount + 1 end
      
      DEFAULT_CHAT_FRAME:AddMessage("|cffff5555Quest not found in captured data: " .. questName)
      DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa  Active quests: " .. activeCount)
      DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa  Saved quests: " .. savedCount)
      return
    end
    
    if pfQuest_CaptureConfig.debug then
      DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa[Found in " .. found.source .. " data]")
    end
    
    local qid = tonumber(found.data.questID)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest DB Check: |cffffcc00" .. found.title)
    DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    -- Check pfDB["quests"]["loc"]
    if pfDB and pfDB["quests"] and pfDB["quests"]["loc"] and pfDB["quests"]["loc"][qid] then
      DEFAULT_CHAT_FRAME:AddMessage("|cff55ff55✓ Quest Locale Data EXISTS")
      DEFAULT_CHAT_FRAME:AddMessage("  Title: " .. (pfDB["quests"]["loc"][qid]["T"] or "missing"))
      DEFAULT_CHAT_FRAME:AddMessage("  Has Description: " .. (pfDB["quests"]["loc"][qid]["D"] and "YES" or "NO"))
      DEFAULT_CHAT_FRAME:AddMessage("  Has Objectives: " .. (pfDB["quests"]["loc"][qid]["O"] and "YES" or "NO"))
    else
      DEFAULT_CHAT_FRAME:AddMessage("|cffff5555✗ Quest Locale Data MISSING")
    end
    
    -- Check pfDB["quests"]["data"]
    if pfDB and pfDB["quests"] and pfDB["quests"]["data"] and pfDB["quests"]["data"][qid] then
      DEFAULT_CHAT_FRAME:AddMessage("|cff55ff55✓ Quest Metadata EXISTS")
      DEFAULT_CHAT_FRAME:AddMessage("  Level: " .. (pfDB["quests"]["data"][qid]["lvl"] or "missing"))
      DEFAULT_CHAT_FRAME:AddMessage("  Min Level: " .. (pfDB["quests"]["data"][qid]["min"] or "missing"))
      
      if pfDB["quests"]["data"][qid]["start"] then
        local startUnits = pfDB["quests"]["data"][qid]["start"]["U"] or {}
        DEFAULT_CHAT_FRAME:AddMessage("  Start NPCs: " .. table.getn(startUnits))
        for i, npcID in ipairs(startUnits) do
          local npcName = pfDB["units"] and pfDB["units"]["loc"] and pfDB["units"]["loc"][npcID] or "Unknown"
          DEFAULT_CHAT_FRAME:AddMessage("    - " .. npcID .. " (" .. npcName .. ")")
        end
      else
        DEFAULT_CHAT_FRAME:AddMessage("  Start NPCs: NONE")
      end
      
      if pfDB["quests"]["data"][qid]["end"] then
        local endUnits = pfDB["quests"]["data"][qid]["end"]["U"] or {}
        DEFAULT_CHAT_FRAME:AddMessage("  End NPCs: " .. table.getn(endUnits))
        for i, npcID in ipairs(endUnits) do
          local npcName = pfDB["units"] and pfDB["units"]["loc"] and pfDB["units"]["loc"][npcID] or "Unknown"
          DEFAULT_CHAT_FRAME:AddMessage("    - " .. npcID .. " (" .. npcName .. ")")
        end
      else
        DEFAULT_CHAT_FRAME:AddMessage("  End NPCs: NONE")
      end
    else
      DEFAULT_CHAT_FRAME:AddMessage("|cffff5555✗ Quest Metadata MISSING")
    end
    
    -- Check NPC spawn data
    if found.data.startNPC and found.data.startNPC.id then
      local npcID = found.data.startNPC.id
      if pfDB and pfDB["units"] and pfDB["units"]["data"] and pfDB["units"]["data"][npcID] then
        DEFAULT_CHAT_FRAME:AddMessage("|cff55ff55✓ Start NPC (" .. npcID .. ") Spawn Data EXISTS")
        local coords = pfDB["units"]["data"][npcID]["coords"] or {}
        DEFAULT_CHAT_FRAME:AddMessage("  Spawn Count: " .. table.getn(coords))
        for i, coord in ipairs(coords) do
          DEFAULT_CHAT_FRAME:AddMessage("    - (" .. coord[1] .. ", " .. coord[2] .. ") Zone:" .. coord[3])
        end
      else
        DEFAULT_CHAT_FRAME:AddMessage("|cffff5555✗ Start NPC (" .. npcID .. ") Spawn Data MISSING")
      end
    end
    
    -- Check if quest is filtered out (completed or in log)
    local isFiltered = false
    local filterReason = ""
    if pfQuest_history and pfQuest_history[qid] then
      isFiltered = true
      filterReason = "Completed (in quest history)"
    elseif pfQuest and pfQuest.questlog and pfQuest.questlog[qid] then
      isFiltered = true
      filterReason = "In quest log (objectives shown instead)"
    end
    
    if isFiltered then
      DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00⚠ Quest Filtered: " .. filterReason)
      DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa  Quest won't show as available on map")
    else
      DEFAULT_CHAT_FRAME:AddMessage("|cff55ff55✓ Quest Available: Will show on map for this character")
    end
    
    DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    return
  end
  
  if msg == "status" then
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest Capture Status:")
    DEFAULT_CHAT_FRAME:AddMessage("Capture: " .. (pfQuest_CaptureConfig.enabled and "|cff55ff55ENABLED" or "|cffff5555DISABLED"))
    DEFAULT_CHAT_FRAME:AddMessage("Debug: " .. (pfQuest_CaptureConfig.debug and "|cff55ff55ENABLED" or "|cffff5555DISABLED"))
    
    local count = 0
    for _ in pairs(pfQuest_CapturedQuests) do
      count = count + 1
    end
    DEFAULT_CHAT_FRAME:AddMessage("Captured quests: |cff33ffcc" .. count)
    
    local active = 0
    for _ in pairs(captureData) do
      active = active + 1
    end
    DEFAULT_CHAT_FRAME:AddMessage("Currently tracking: |cffffcc00" .. active)
    
    -- Show quest display settings that might affect visibility
    DEFAULT_CHAT_FRAME:AddMessage(" ")
    DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00Quest Display Settings:|r")
    DEFAULT_CHAT_FRAME:AddMessage("Show Low Level: " .. (pfQuest_config["showlowlevel"] == "1" and "|cff55ff55ON" or "|cffff5555OFF"))
    DEFAULT_CHAT_FRAME:AddMessage("Show High Level: " .. (pfQuest_config["showhighlevel"] == "1" and "|cff55ff55ON" or "|cffff5555OFF"))
    DEFAULT_CHAT_FRAME:AddMessage("Show Quest Givers: " .. (pfQuest_config["allquestgivers"] == "1" and "|cff55ff55ON" or "|cffff5555OFF"))
    DEFAULT_CHAT_FRAME:AddMessage(" ")
    DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa(Use /pfquest config to change these settings)")
    return
  end
  
  if msg == "export" then
    -- Export captured quests in pfQuest database format
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest Capture: Generating export...")
    DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa(Check pfQuestCaptureUI for exportable data)")
    
    if pfQuestCaptureUI then
      pfQuestCaptureUI:Show()
      pfQuestCaptureUI:ShowExport()
    end
    return
  end
  
  if msg == "save" then
    -- Manually save current capture data
    local saved = 0
    for title, data in pairs(captureData) do
      if data.level then
        pfQuest_CapturedQuests[title] = data
        saved = saved + 1
      end
    end
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest Capture: Saved " .. saved .. " quests to permanent storage")
    
    if pfQuestCaptureUI and pfQuestCaptureUI:IsShown() then
      pfQuestCaptureUI:UpdateUI()
    end
    return
  end
  
  if msg == "scan" then
    -- Manually scan quest log for tracking
    ScanQuestLog(pfQuest_CaptureConfig.debug) -- Show messages only if debug enabled
    return
  end
  
  if msg == "clear" then
    pfQuest_CapturedQuests = {}
    captureData = {}
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest Capture: Cleared all captured quest data")
    
    if pfQuestCaptureUI and pfQuestCaptureUI:IsShown() then
      pfQuestCaptureUI:UpdateUI()
    end
    return
  end
  
  if msg == "inject" then
    -- Inject all captured quests into live database
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest Capture: Injecting all captured quests into live database...")
    
    local count = InjectAllCapturedQuests(true) -- true = show messages
    
    if count > 0 then
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest Capture: Injected " .. count .. " quests into live database")
      DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00All characters can now see these quests on their maps!")
    else
      DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00No quests to inject (all have custom IDs or no data)")
    end
    
    return
  end
  
  if string.sub(msg, 1, 4) == "show" then
    -- Show detailed quest info (including objective locations)
    local questName = string.sub(msg, 6) -- Get quest name after "show "
    if questName == "" then
      DEFAULT_CHAT_FRAME:AddMessage("|cffff5555Usage: /questcapture show <quest name>")
      return
    end
    
    -- Find quest (case-insensitive partial match)
    local found = nil
    for title, data in pairs(pfQuest_CapturedQuests) do
      if string.find(string.lower(title), string.lower(questName)) then
        found = {title = title, data = data}
        break
      end
    end
    
    if not found then
      DEFAULT_CHAT_FRAME:AddMessage("|cffff5555Quest not found: " .. questName)
      return
    end
    
    -- Display quest info
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest: |cffffcc00" .. found.title .. " [" .. (found.data.level or "?") .. "]")
    
    if found.data.startNPC and found.data.startNPC.name then
      DEFAULT_CHAT_FRAME:AddMessage("  |cff55ff55Start:|r " .. found.data.startNPC.name .. " (ID: " .. (found.data.startNPC.id or "?") .. ")")
    end
    
    if found.data.endNPC and found.data.endNPC.name then
      DEFAULT_CHAT_FRAME:AddMessage("  |cffffcc00End:|r " .. found.data.endNPC.name .. " (ID: " .. (found.data.endNPC.id or "?") .. ")")
    end
    
    if found.data.objectiveLocations then
      DEFAULT_CHAT_FRAME:AddMessage("  |cff00ccffObjective Locations:|r")
      for objIndex, objData in pairs(found.data.objectiveLocations) do
        DEFAULT_CHAT_FRAME:AddMessage("    " .. objIndex .. ". " .. (objData.text or "Unknown"))
        if objData.locations and table.getn(objData.locations) > 0 then
          for i, loc in ipairs(objData.locations) do
            DEFAULT_CHAT_FRAME:AddMessage("       - (" .. math.floor(loc.x) .. ", " .. math.floor(loc.y) .. ") " .. (loc.zone or "?"))
          end
        else
          DEFAULT_CHAT_FRAME:AddMessage("       |cffaaaaaa(No locations captured yet)")
        end
      end
    end
    
    if found.data.questItems and table.getn(found.data.questItems) > 0 then
      DEFAULT_CHAT_FRAME:AddMessage("  |cff00ff00Quest Items:|r")
      for i, item in ipairs(found.data.questItems) do
        DEFAULT_CHAT_FRAME:AddMessage("    - " .. (item.name or "Unknown") .. " from " .. (item.source or "Unknown"))
      end
    end
    
    return
  end
  
  if msg == "help" then
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest Capture Commands:")
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc/questcapture|r - Toggle capture monitor window")
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc/questcapture scan|r - |cffffcc00Scan quest log NOW")
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc/questcapture save|r - Save currently tracked quests")
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc/questcapture status|r - Show capture status")
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc/questcapture show <quest>|r - |cff00ccffShow quest details with locations")
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc/questcapture check <quest>|r - |cffaaaaaa Verify quest in pfDB database")
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc/questcapture inject|r - |cff00ff00Push ALL captured quests to live DB")
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc/questcapture export|r - Export captured quest data")
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc/questcapture toggle|r - Enable/disable capture")
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc/questcapture debug|r - |cffaaaaaa Enable/disable debug messages")
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc/questcapture questlog|r - |cffaaaaaa Show quest log with completion status")
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc/questcapture clear|r - Clear all captured data")
    return
  end
  
  if msg == "questlog" then
    -- Show all quests in quest log with completion status
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest Log Status:")
    DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    local numEntries, numQuests = GetNumQuestLogEntries()
    DEFAULT_CHAT_FRAME:AddMessage("|cffffffQuest log entries: " .. numEntries .. " (Quests: " .. numQuests .. ")")
    DEFAULT_CHAT_FRAME:AddMessage(" ")
    
    for i = 1, numEntries do
      local questTitle, level, questTag, isHeader, isCollapsed, isComplete = GetQuestLogTitle(i)
      
      if questTitle and not isHeader then
        local numObjectives = GetNumQuestLeaderBoards(i)
        local allDone = true
        
        -- Check if all objectives are done
        for j = 1, numObjectives do
          local text, type, finished = GetQuestLogLeaderBoard(j, i)
          if not finished then
            allDone = false
          end
        end
        
        -- Determine status
        local status
        if isComplete == 1 or (numObjectives == 0) or allDone then
          status = "|cff55ff55[COMPLETE - Ready to turn in!]"
        elseif numObjectives == 0 then
          status = "|cffffcc00[No objectives - check quest]"
        else
          status = "|cffff5555[INCOMPLETE - " .. numObjectives .. " objectives]"
        end
        
        DEFAULT_CHAT_FRAME:AddMessage(status .. " |cffffffff" .. questTitle .. " [" .. level .. "]" .. (questTag and questTag ~= "" and " |cff888888(" .. questTag .. ")" or ""))
      end
    end
    
    DEFAULT_CHAT_FRAME:AddMessage(" ")
    DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa(Quests marked COMPLETE should show turn-in NPCs on map/routing)")
    DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa(Check: /pfquest config → 'Display Current Quest Givers' is enabled)")
    return
  end
  
  DEFAULT_CHAT_FRAME:AddMessage("|cffff5555Unknown command. Type /questcapture help for commands.")
end

