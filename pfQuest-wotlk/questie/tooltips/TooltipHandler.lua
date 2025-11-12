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

-- Helper to strip color codes from text
local function stripColorCodes(text)
  if not text then return "" end
  -- Remove all color codes like |cffffcc00, |r, etc.
  text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
  text = string.gsub(text, "|r", "")
  text = string.gsub(text, "|H.-|h", "")
  text = string.gsub(text, "|h", "")
  return text
end

-- Helper to normalize objective line for deduplication
local function normalizeObjective(line)
  if not line then return "" end
  -- Strip color codes first
  local clean = stripColorCodes(line)
  -- Remove leading dashes, whitespace, and quest markers
  clean = string.gsub(clean, "^%s*%-%s*", "")
  clean = string.gsub(clean, "^%s*%[%!%]%s*", "")
  clean = string.gsub(clean, "^%s*%[%?%]%s*", "")
  -- Remove inline drop rate percentages like [20%] or [20%] anywhere in the line
  clean = string.gsub(clean, "%s*%[%d+%%%]%s*", "")
  -- Extract item name and current progress (e.g., "Centaur Ear: 12/15" -> "Centaur Ear:12")
  -- Match pattern: item name, colon, optional space, current number, slash, total number
  local itemName, current = string.match(clean, "^(.+):%s*(%d+)/%d+")
  if itemName and current then
    -- Normalize item name: trim whitespace and convert to lowercase for matching
    itemName = string.gsub(itemName, "^%s+", "")
    itemName = string.gsub(itemName, "%s+$", "")
    -- Return normalized key: lowercase item name + current progress
    return string.lower(itemName) .. ":" .. current
  end
  -- Fallback: return cleaned and normalized line
  clean = string.gsub(clean, "^%s+", "")
  clean = string.gsub(clean, "%s+$", "")
  return string.lower(clean)
end

-- Helper to extract normalized quest name from text (strips color codes and quest markers)
local function extractQuestName(text)
  if not text then return "" end
  -- Strip color codes first
  local clean = stripColorCodes(text)
  -- Remove quest markers like [!] or [?] anywhere in the text
  clean = string.gsub(clean, "%[%!%]", "")
  clean = string.gsub(clean, "%[%?%]", "")
  -- Remove leading/trailing whitespace
  clean = string.gsub(clean, "^%s+", "")
  clean = string.gsub(clean, "%s+$", "")
  -- Return normalized (lowercase) for comparison
  return string.lower(clean)
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
  local seenQuests = {} -- Track quest names (normalized) to prevent duplication
  local dropRates = {} -- Track drop rates per quest for averaging
  local questEntries = {} -- Store entries by normalized quest name
  
  if data then
    -- First pass: collect all entries and drop rates
    for questId, entry in pairs(data) do
      if entry.lines and entry.lines[1] then
        local questNameRaw = entry.lines[1]
        local questName = extractQuestName(questNameRaw)
        
        if questName and questName ~= "" then
          -- Collect drop rates
          for _, line in ipairs(entry.lines) do
            local dropRate = string.match(line, "Drop Rate.*(%d+)%%")
            if dropRate then
              if not dropRates[questName] then
                dropRates[questName] = {}
              end
              table.insert(dropRates[questName], tonumber(dropRate))
            end
          end
          
          -- Store entry by normalized quest name
          if not questEntries[questName] then
            questEntries[questName] = {}
          end
          table.insert(questEntries[questName], entry)
        end
      elseif entry.text then
        local questName = extractQuestName(entry.text)
        if questName and questName ~= "" then
          if not questEntries[questName] then
            questEntries[questName] = {}
          end
          table.insert(questEntries[questName], entry)
        end
      end
    end
    
    -- Second pass: display each unique quest once
    for questName, entries in pairs(questEntries) do
      if not seenQuests[questName] then
        seenQuests[questName] = true
        
        -- Use the first entry for the quest name/header
        local firstEntry = entries[1]
        if firstEntry.lines then
          -- Show quest name (first line)
          tooltip:AddLine(firstEntry.lines[1])
          added = true
          
          -- Collect all unique objectives from all entries
          local seenObjectives = {}
          local objectiveLines = {} -- Store the best formatted version of each objective
          for _, entry in ipairs(entries) do
            for i = 2, #entry.lines do
              local line = entry.lines[i]
              -- Skip metadata lines
              if not string.find(line, "Level:") and 
                 not string.find(line, "Required:") and
                 not string.find(line, "Drop Rate:") and
                 not string.find(line, "Quest ID:") then
                -- Normalize the objective to detect duplicates
                local normalized = normalizeObjective(line)
                if normalized and normalized ~= "" then
                  if not seenObjectives[normalized] then
                    seenObjectives[normalized] = true
                    -- Store the line (prefer one without inline drop rate for cleaner display)
                    if not string.find(line, "%[%d+%%%]") then
                      -- Prefer lines without inline drop rate
                      objectiveLines[normalized] = line
                    elseif not objectiveLines[normalized] then
                      -- Fallback to any version if we don't have one yet
                      objectiveLines[normalized] = line
                    end
                  end
                end
              end
            end
          end
          
          -- Display all unique objectives
          for normalized, line in pairs(objectiveLines) do
            tooltip:AddLine(line)
            added = true
          end
          
          -- Add averaged drop rate if we have any
          if dropRates[questName] and #dropRates[questName] > 0 then
            local sum = 0
            for _, rate in ipairs(dropRates[questName]) do
              sum = sum + rate
            end
            local avgRate = math.floor((sum / #dropRates[questName]) + 0.5)
            tooltip:AddLine(string.format("|cffffffffDrop Rate:|r %d%%", avgRate))
            added = true
          end
        elseif firstEntry.text then
          tooltip:AddLine(firstEntry.text)
          added = true
        end
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

