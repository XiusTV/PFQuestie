-- pfQuest Capture UI
-- Compact monitoring window for quest capture with resizing

pfQuestCaptureUI = CreateFrame("Frame", "pfQuestCaptureUI", UIParent)
pfQuestCaptureUI:Hide()
pfQuestCaptureUI:SetWidth(350)
pfQuestCaptureUI:SetHeight(200)
pfQuestCaptureUI:SetPoint("CENTER", 0, 100)
pfQuestCaptureUI:SetFrameStrata("MEDIUM")
pfQuestCaptureUI:SetMovable(true)
pfQuestCaptureUI:SetResizable(true)
pfQuestCaptureUI:EnableMouse(true)
pfQuestCaptureUI:SetClampedToScreen(true)
pfQuestCaptureUI:SetMinResize(250, 150)
pfQuestCaptureUI:SetMaxResize(600, 800)
pfQuestCaptureUI:RegisterForDrag("LeftButton")
pfQuestCaptureUI:SetScript("OnDragStart", function() this:StartMoving() end)
pfQuestCaptureUI:SetScript("OnDragStop", function() 
  this:StopMovingOrSizing()
  -- Save position
  local point, relativeTo, relativePoint, xOfs, yOfs = this:GetPoint()
  pfQuest_CaptureConfig.windowPos = {point, relativePoint, xOfs, yOfs}
  local width, height = this:GetWidth(), this:GetHeight()
  pfQuest_CaptureConfig.windowSize = {width, height}
end)
pfUI.api.CreateBackdrop(pfQuestCaptureUI, nil, true, 0.85)
table.insert(UISpecialFrames, "pfQuestCaptureUI")

-- Restore saved position and size
if pfQuest_CaptureConfig.windowPos then
  pfQuestCaptureUI:ClearAllPoints()
  pfQuestCaptureUI:SetPoint(
    pfQuest_CaptureConfig.windowPos[1], 
    UIParent, 
    pfQuest_CaptureConfig.windowPos[2], 
    pfQuest_CaptureConfig.windowPos[3], 
    pfQuest_CaptureConfig.windowPos[4]
  )
end
if pfQuest_CaptureConfig.windowSize then
  pfQuestCaptureUI:SetWidth(pfQuest_CaptureConfig.windowSize[1])
  pfQuestCaptureUI:SetHeight(pfQuest_CaptureConfig.windowSize[2])
end

-- Title bar for dragging
pfQuestCaptureUI.titlebar = CreateFrame("Frame", nil, pfQuestCaptureUI)
pfQuestCaptureUI.titlebar:SetPoint("TOPLEFT", pfQuestCaptureUI, "TOPLEFT", 0, 0)
pfQuestCaptureUI.titlebar:SetPoint("TOPRIGHT", pfQuestCaptureUI, "TOPRIGHT", -50, 0)
pfQuestCaptureUI.titlebar:SetHeight(25)
pfQuestCaptureUI.titlebar:EnableMouse(true)
pfQuestCaptureUI.titlebar:RegisterForDrag("LeftButton")
pfQuestCaptureUI.titlebar:SetScript("OnDragStart", function()
  pfQuestCaptureUI:StartMoving()
end)
pfQuestCaptureUI.titlebar:SetScript("OnDragStop", function()
  pfQuestCaptureUI:StopMovingOrSizing()
  local point, relativeTo, relativePoint, xOfs, yOfs = pfQuestCaptureUI:GetPoint()
  pfQuest_CaptureConfig.windowPos = {point, relativePoint, xOfs, yOfs}
end)

-- Title
pfQuestCaptureUI.title = pfQuestCaptureUI:CreateFontString(nil, "OVERLAY", "GameFontNormal")
pfQuestCaptureUI.title:SetPoint("LEFT", pfQuestCaptureUI.titlebar, "LEFT", 8, 0)
pfQuestCaptureUI.title:SetFont(pfUI.font_default, pfUI_config.global.font_size + 1, "OUTLINE")
pfQuestCaptureUI.title:SetText("|cff33ffccpf|cffffffffQuest Capture")

-- Close button
pfQuestCaptureUI.closeBtn = CreateFrame("Button", nil, pfQuestCaptureUI)
pfQuestCaptureUI.closeBtn:SetPoint("TOPRIGHT", -5, -5)
pfQuestCaptureUI.closeBtn:SetHeight(20)
pfQuestCaptureUI.closeBtn:SetWidth(20)
pfQuestCaptureUI.closeBtn.texture = pfQuestCaptureUI.closeBtn:CreateTexture()
pfQuestCaptureUI.closeBtn.texture:SetTexture(pfQuestConfig.path.."\\compat\\close")
pfQuestCaptureUI.closeBtn.texture:SetAllPoints()
pfQuestCaptureUI.closeBtn:SetScript("OnClick", function() pfQuestCaptureUI:Hide() end)
pfUI.api.SkinButton(pfQuestCaptureUI.closeBtn, 1, 0.3, 0.3)

-- Resize grip (bottom right corner)
pfQuestCaptureUI.resizegrip = CreateFrame("Frame", nil, pfQuestCaptureUI)
pfQuestCaptureUI.resizegrip:SetFrameLevel(pfQuestCaptureUI:GetFrameLevel() + 10)
pfQuestCaptureUI.resizegrip:SetWidth(16)
pfQuestCaptureUI.resizegrip:SetHeight(16)
pfQuestCaptureUI.resizegrip:SetPoint("BOTTOMRIGHT", 0, 0)
pfQuestCaptureUI.resizegrip:EnableMouse(true)
pfQuestCaptureUI.resizegrip.texture = pfQuestCaptureUI.resizegrip:CreateTexture(nil, "OVERLAY")
pfQuestCaptureUI.resizegrip.texture:SetTexture(pfQuestConfig.path.."\\img\\resize")
pfQuestCaptureUI.resizegrip.texture:SetAllPoints()
pfQuestCaptureUI.resizegrip.texture:SetVertexColor(0.8, 0.8, 0.8, 0.5)

pfQuestCaptureUI.resizegrip:SetScript("OnMouseDown", function()
  pfQuestCaptureUI:StartSizing("BOTTOMRIGHT")
end)

pfQuestCaptureUI.resizegrip:SetScript("OnMouseUp", function()
  pfQuestCaptureUI:StopMovingOrSizing()
  local width, height = pfQuestCaptureUI:GetWidth(), pfQuestCaptureUI:GetHeight()
  pfQuest_CaptureConfig.windowSize = {width, height}
end)

pfQuestCaptureUI.resizegrip:SetScript("OnEnter", function()
  GameTooltip:SetOwner(this, "ANCHOR_CURSOR")
  GameTooltip:ClearLines()
  GameTooltip:AddLine("Drag to resize", 1, 1, 1)
  GameTooltip:Show()
end)

pfQuestCaptureUI.resizegrip:SetScript("OnLeave", function()
  GameTooltip:Hide()
end)

-- Status bar (compact version below title)
pfQuestCaptureUI.statusBar = pfQuestCaptureUI:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
pfQuestCaptureUI.statusBar:SetPoint("TOPLEFT", pfQuestCaptureUI, "TOPLEFT", 8, -28)
pfQuestCaptureUI.statusBar:SetFont(pfUI.font_default, pfUI_config.global.font_size - 1, "OUTLINE")
pfQuestCaptureUI.statusBar:SetJustifyH("LEFT")

-- Toggle capture button (compact)
pfQuestCaptureUI.toggleBtn = CreateFrame("Button", nil, pfQuestCaptureUI)
pfQuestCaptureUI.toggleBtn:SetPoint("TOPRIGHT", pfQuestCaptureUI, "TOPRIGHT", -30, -5)
pfQuestCaptureUI.toggleBtn:SetWidth(40)
pfQuestCaptureUI.toggleBtn:SetHeight(16)
pfQuestCaptureUI.toggleBtn.text = pfQuestCaptureUI.toggleBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
pfQuestCaptureUI.toggleBtn.text:SetPoint("CENTER")
pfQuestCaptureUI.toggleBtn.text:SetFont(pfUI.font_default, pfUI_config.global.font_size - 2, "OUTLINE")
pfUI.api.SkinButton(pfQuestCaptureUI.toggleBtn)

pfQuestCaptureUI.toggleBtn:SetScript("OnClick", function()
  pfQuest_CaptureConfig.enabled = not pfQuest_CaptureConfig.enabled
  pfQuestCaptureUI:UpdateUI()
  DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest Capture: " .. (pfQuest_CaptureConfig.enabled and "|cff55ff55ENABLED" or "|cffff5555DISABLED"))
end)

-- Scroll frame for quest list (compact)
pfQuestCaptureUI.scroll = CreateFrame("ScrollFrame", "pfQuestCaptureUIScroll", pfQuestCaptureUI)
pfQuestCaptureUI.scroll:SetPoint("TOPLEFT", pfQuestCaptureUI, "TOPLEFT", 5, -48)
pfQuestCaptureUI.scroll:SetPoint("BOTTOMRIGHT", pfQuestCaptureUI, "BOTTOMRIGHT", -5, 35)
pfQuestCaptureUI.scroll:EnableMouseWheel(true)
pfQuestCaptureUI.scroll:SetScript("OnMouseWheel", function()
  local current = this:GetVerticalScroll()
  local maxScroll = this:GetVerticalScrollRange()
  
  if arg1 > 0 then
    current = math.max(0, current - 20)
  else
    current = math.min(maxScroll, current + 20)
  end
  
  this:SetVerticalScroll(current)
end)

-- Content frame (dynamic width based on window size)
pfQuestCaptureUI.content = CreateFrame("Frame", nil, pfQuestCaptureUI.scroll)
pfQuestCaptureUI.content:SetWidth(1)
pfQuestCaptureUI.content:SetHeight(1)
pfQuestCaptureUI.scroll:SetScrollChild(pfQuestCaptureUI.content)

-- Update content width on resize
pfQuestCaptureUI:SetScript("OnSizeChanged", function()
  if pfQuestCaptureUI.content then
    pfQuestCaptureUI.content:SetWidth(this:GetWidth() - 15)
  end
end)

-- Quest entry pool
local captureEntryPool = {}
pfQuestCaptureUI.entries = {}

-- Helper to check if quest is in database
local function IsQuestInDatabase(questTitle)
  if not pfDB or not pfDB["quests"] or not pfDB["quests"]["loc"] then
    return false
  end
  
  for qid, qdata in pairs(pfDB["quests"]["loc"]) do
    if qdata["T"] == questTitle then
      return true
    end
  end
  
  return false
end

local function GetCaptureEntry()
  -- Reuse from pool if available
  if table.getn(captureEntryPool) > 0 then
    local entry = table.remove(captureEntryPool)
    entry:Show()
    return entry
  end
  
  -- Create new entry (compact version)
  local entry = CreateFrame("Frame", nil, pfQuestCaptureUI.content)
  entry:SetHeight(40)
  pfUI.api.CreateBackdrop(entry, nil, true, 0.4)
  
  -- Quest title with status badge
  entry.title = entry:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  entry.title:SetPoint("TOPLEFT", entry, "TOPLEFT", 5, -4)
  entry.title:SetFont(pfUI.font_default, pfUI_config.global.font_size - 1, "OUTLINE")
  entry.title:SetJustifyH("LEFT")
  
  -- Quest info (compact - one line)
  entry.info = entry:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  entry.info:SetPoint("TOPLEFT", entry.title, "BOTTOMLEFT", 0, -2)
  entry.info:SetFont(pfUI.font_default, pfUI_config.global.font_size - 2, "OUTLINE")
  entry.info:SetJustifyH("LEFT")
  entry.info:SetTextColor(0.6, 0.6, 0.6)
  
  entry:Show()
  return entry
end

local function ReleaseCaptureEntry(entry)
  entry:Hide()
  entry:ClearAllPoints()
  entry.questData = nil
  table.insert(captureEntryPool, entry)
end

-- Update UI
function pfQuestCaptureUI:UpdateUI()
  -- Release all entries
  if self.entries then
    for _, entry in pairs(self.entries) do
      ReleaseCaptureEntry(entry)
    end
  end
  self.entries = {}
  
  -- Update status
  local totalCount = 0
  local newCount = 0
  
  for title, _ in pairs(pfQuest_CapturedQuests) do
    totalCount = totalCount + 1
    if not IsQuestInDatabase(title) then
      newCount = newCount + 1
    end
  end
  
  local statusText = "|cffffcc00" .. totalCount .. "|r captured"
  if newCount > 0 then
    statusText = statusText .. " (|cffff8800" .. newCount .. " NEW|r)"
  end
  
  if pfQuest_CaptureConfig.enabled then
    statusText = statusText .. " |cff55ff55●"
    self.toggleBtn.text:SetText("|cff55ff55ON")
    self.toggleBtn.text:SetTextColor(0.3, 1, 0.3)
  else
    statusText = statusText .. " |cffff5555●"
    self.toggleBtn.text:SetText("|cffff5555OFF")
    self.toggleBtn.text:SetTextColor(1, 0.3, 0.3)
  end
  self.statusBar:SetText(statusText)
  
  -- Sort captured quests by level
  local sortedQuests = {}
  for title, data in pairs(pfQuest_CapturedQuests) do
    table.insert(sortedQuests, {title = title, data = data})
  end
  
  table.sort(sortedQuests, function(a, b)
    local levelA = a.data.level or 0
    local levelB = b.data.level or 0
    if levelA == levelB then
      return a.title < b.title
    end
    return levelA < levelB
  end)
  
  -- Create entries (compact, monitoring style)
  local yOffset = 0
  local windowWidth = self:GetWidth()
  
  for i, quest in ipairs(sortedQuests) do
    local entry = GetCaptureEntry()
    entry.questData = quest.data
    entry.questTitle = quest.title
    entry:SetWidth(windowWidth - 15)
    
    -- Check if quest is new (not in database)
    local isNew = not IsQuestInDatabase(quest.title)
    local statusBadge = ""
    local statusColor = "|cff55ff55"
    
    if isNew then
      statusBadge = "|cffff8800[NEW!]|r "
      statusColor = "|cffff8800"
    else
      statusBadge = "|cff55ff55[DB]|r "
    end
    
    -- Title with level and status
    local level = quest.data.level or "?"
    local titleText = statusBadge .. "|cffffcc00[" .. level .. "]|r " .. quest.title
    
    -- Truncate title if too long based on window width
    local maxTitleWidth = windowWidth - 25
    entry.title:SetWidth(maxTitleWidth)
    entry.title:SetText(titleText)
    
    -- Info line (compact)
    local infoText = ""
    
    -- Start NPC (compact)
    if quest.data.startNPC and quest.data.startNPC.name then
      infoText = infoText .. "|cff55ff55▶|r " .. quest.data.startNPC.name
    else
      infoText = infoText .. "|cffaaaaaa▶ Unknown"
    end
    
    -- End NPC (compact)
    if quest.data.endNPC and quest.data.endNPC.name then
      infoText = infoText .. " |cffffcc00◀|r " .. quest.data.endNPC.name
    end
    
            -- Quest items count
            if quest.data.questItems and table.getn(quest.data.questItems) > 0 then
              infoText = infoText .. " |cff00ff00●|r" .. table.getn(quest.data.questItems)
            end
            
            -- Objective locations count
            if quest.data.objectiveLocations then
              local totalLocs = 0
              for objIndex, objData in pairs(quest.data.objectiveLocations) do
                if objData.locations then
                  totalLocs = totalLocs + table.getn(objData.locations)
                end
              end
              if totalLocs > 0 then
                infoText = infoText .. " |cff00ccff📍|r" .. totalLocs
              end
            end
    
    entry.info:SetWidth(maxTitleWidth)
    entry.info:SetText(infoText)
    
    entry:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, -yOffset)
    table.insert(self.entries, entry)
    yOffset = yOffset + 42
  end
  
  -- Update content height
  self.content:SetHeight(math.max(yOffset, 1))
end

-- Show quest details (placeholder for now)
function pfQuestCaptureUI:ShowQuestDetails(questData)
  DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest: " .. questData.title)
  DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa-- Start: " .. (questData.startNPC and questData.startNPC.name or "Unknown"))
  DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa-- End: " .. (questData.endNPC and questData.endNPC.name or "Unknown"))
  DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa-- Level: " .. (questData.level or "?"))
  
  if questData.objectives then
    DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa-- Objectives:")
    for _, obj in pairs(questData.objectives) do
      DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa   " .. obj.text)
    end
  end
  
  if questData.questItems and table.getn(questData.questItems) > 0 then
    DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa-- Quest Items:")
    for _, item in pairs(questData.questItems) do
      DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa   " .. item.itemName .. " from " .. (item.sourceNPC or "Unknown"))
    end
  end
end

-- Show export window
function pfQuestCaptureUI:ShowExport()
  if not pfQuestExportWindow then
    -- Create export window if it doesn't exist
    CreateExportWindow()
  end
  
  -- Generate export data
  local exportText = GenerateExportData()
  
  -- Show window and populate editbox
  pfQuestExportWindow:Show()
  pfQuestExportWindow.editbox:SetText(exportText)
  pfQuestExportWindow.editbox:HighlightText()
  pfQuestExportWindow.editbox:SetFocus()
  
  DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest Capture: Export window opened - |cffffcc00Ctrl+C|r to copy")
end

-- Generate export data in pfQuest database format
function GenerateExportData()
  local output = {}
  local questCount = 0
  local newQuestCount = 0
  
  -- Header
  table.insert(output, "-- pfQuest Captured Quest Data")
  table.insert(output, "-- Generated: " .. date("%Y-%m-%d %H:%M:%S"))
  table.insert(output, "-- Total quests: " .. GetCapturedQuestCount())
  table.insert(output, "")
  table.insert(output, "----------------------------------------")
  table.insert(output, "-- QUEST LOCALE DATA (enUS)")
  table.insert(output, "----------------------------------------")
  table.insert(output, "")
  
  for title, data in pairs(pfQuest_CapturedQuests) do
    if data.title and data.questID then
      -- Check if it's a new quest (not in DB)
      local isNew = not IsQuestInDatabase(title)
      
      -- ONLY export NEW quests (not in database)
      if isNew then
        questCount = questCount + 1
        newQuestCount = newQuestCount + 1
        
        local qid = data.questID
        
        -- Quest locale data
        table.insert(output, "-- [NEW] " .. title .. " [" .. (data.level or "?") .. "]")
        table.insert(output, "pfDB[\"quests\"][\"loc\"][" .. qid .. "] = {")
        table.insert(output, "  [\"T\"] = \"" .. EscapeString(data.title) .. "\",")
        
        if data.description and data.description ~= "" then
          table.insert(output, "  [\"D\"] = \"" .. EscapeString(data.description) .. "\",")
        end
        
        -- Objectives
        if data.objectives and table.getn(data.objectives) > 0 then
          local objText = ""
          for i, obj in ipairs(data.objectives) do
            objText = objText .. obj.text
            if i < table.getn(data.objectives) then
              objText = objText .. "\\n"
            end
          end
          table.insert(output, "  [\"O\"] = \"" .. EscapeString(objText) .. "\",")
        end
        
        table.insert(output, "}")
        table.insert(output, "")
      end
    end
  end
  
  table.insert(output, "")
  table.insert(output, "----------------------------------------")
  table.insert(output, "-- QUEST METADATA")
  table.insert(output, "----------------------------------------")
  table.insert(output, "")
  
  for title, data in pairs(pfQuest_CapturedQuests) do
    if data.title and data.questID then
      local isNew = not IsQuestInDatabase(title)
      
      -- ONLY export NEW quests (not in database)
      if isNew then
        local qid = data.questID
        
        table.insert(output, "-- [NEW] " .. title)
        table.insert(output, "pfDB[\"quests\"][\"data\"][" .. qid .. "] = {")
        
        if data.level then
          table.insert(output, "  [\"lvl\"] = " .. data.level .. ",")
        end
        
        -- Start NPC
        if data.startNPC and data.startNPC.id then
          table.insert(output, "  [\"start\"] = {")
          table.insert(output, "    [\"U\"] = {" .. data.startNPC.id .. "}, -- " .. (data.startNPC.name or "Unknown"))
          table.insert(output, "  },")
        end
        
        -- End NPC
        if data.endNPC and data.endNPC.id then
          table.insert(output, "  [\"end\"] = {")
          table.insert(output, "    [\"U\"] = {" .. data.endNPC.id .. "}, -- " .. (data.endNPC.name or "Unknown"))
          table.insert(output, "  },")
        end
        
        table.insert(output, "}")
        table.insert(output, "")
      end
    end
  end
  
  -- Objective spawn locations (ONLY for NEW quests)
  local hasObjectiveLocations = false
  for title, data in pairs(pfQuest_CapturedQuests) do
    local isNew = not IsQuestInDatabase(title)
    if isNew and data.objectiveLocations then
      for objIndex, objData in pairs(data.objectiveLocations) do
        if objData.locations and table.getn(objData.locations) > 0 then
          hasObjectiveLocations = true
          break
        end
      end
    end
    if hasObjectiveLocations then break end
  end
  
  if hasObjectiveLocations then
    table.insert(output, "")
    table.insert(output, "----------------------------------------")
    table.insert(output, "-- OBJECTIVE SPAWN LOCATIONS (NEW QUESTS ONLY)")
    table.insert(output, "-- (To be integrated into unit/object spawn data)")
    table.insert(output, "----------------------------------------")
    table.insert(output, "")
    
    for title, data in pairs(pfQuest_CapturedQuests) do
      local isNew = not IsQuestInDatabase(title)
      
      -- ONLY export objective locations for NEW quests
      if isNew and data.objectiveLocations then
        local hasLocs = false
        for objIndex, objData in pairs(data.objectiveLocations) do
          if objData.locations and table.getn(objData.locations) > 0 then
            hasLocs = true
            break
          end
        end
        
        if hasLocs then
          table.insert(output, "-- [NEW] " .. title .. " [Quest " .. data.questID .. "]")
          
          for objIndex, objData in pairs(data.objectiveLocations) do
            if objData.locations and table.getn(objData.locations) > 0 then
              table.insert(output, "-- Objective " .. objIndex .. ": " .. (objData.text or "Unknown"))
              table.insert(output, "-- Spawn coordinates (x, y, zone):")
              
              for i, loc in ipairs(objData.locations) do
                table.insert(output, "--   (" .. math.floor(loc.x) .. ", " .. math.floor(loc.y) .. ") " .. (loc.zone or "Unknown"))
              end
              
              table.insert(output, "")
            end
          end
        end
      end
    end
  end
  
  -- Summary
  table.insert(output, "")
  table.insert(output, "----------------------------------------")
  table.insert(output, "-- EXPORT SUMMARY")
  table.insert(output, "----------------------------------------")
  table.insert(output, "-- Total quests exported: " .. questCount)
  table.insert(output, "-- New quests (not in DB): " .. newQuestCount)
  table.insert(output, "-- Quest items tracked: " .. GetTotalQuestItems())
  table.insert(output, "-- Objective locations: " .. GetTotalObjectiveLocations())
  table.insert(output, "")
  
  return table.concat(output, "\n")
end

-- Helper: Escape string for Lua code
function EscapeString(str)
  if not str then return "" end
  str = string.gsub(str, "\\", "\\\\")
  str = string.gsub(str, "\"", "\\\"")
  str = string.gsub(str, "\n", "\\n")
  str = string.gsub(str, "\r", "")
  return str
end

-- Helper: Count total quest items
function GetTotalQuestItems()
  local count = 0
  for title, data in pairs(pfQuest_CapturedQuests) do
    if data.questItems then
      count = count + table.getn(data.questItems)
    end
  end
  return count
end

-- Helper: Count total objective locations
function GetTotalObjectiveLocations()
  local count = 0
  for title, data in pairs(pfQuest_CapturedQuests) do
    if data.objectiveLocations then
      for objIndex, objData in pairs(data.objectiveLocations) do
        if objData.locations then
          count = count + table.getn(objData.locations)
        end
      end
    end
  end
  return count
end

-- Helper: Count captured quests
function GetCapturedQuestCount()
  local count = 0
  for _ in pairs(pfQuest_CapturedQuests) do
    count = count + 1
  end
  return count
end

-- Create export window
function CreateExportWindow()
  pfQuestExportWindow = CreateFrame("Frame", "pfQuestExportWindow", UIParent)
  pfQuestExportWindow:Hide()
  pfQuestExportWindow:SetWidth(600)
  pfQuestExportWindow:SetHeight(500)
  pfQuestExportWindow:SetPoint("CENTER", 0, 0)
  pfQuestExportWindow:SetFrameStrata("DIALOG")
  pfQuestExportWindow:SetMovable(true)
  pfQuestExportWindow:EnableMouse(true)
  pfQuestExportWindow:SetClampedToScreen(true)
  pfQuestExportWindow:RegisterForDrag("LeftButton")
  pfQuestExportWindow:SetScript("OnDragStart", function() this:StartMoving() end)
  pfQuestExportWindow:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
  pfUI.api.CreateBackdrop(pfQuestExportWindow, nil, true, 0.95)
  table.insert(UISpecialFrames, "pfQuestExportWindow")
  
  -- Title
  pfQuestExportWindow.title = pfQuestExportWindow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  pfQuestExportWindow.title:SetPoint("TOP", pfQuestExportWindow, "TOP", 0, -10)
  pfQuestExportWindow.title:SetFont(pfUI.font_default, pfUI_config.global.font_size + 2, "OUTLINE")
  pfQuestExportWindow.title:SetText("|cff33ffccpf|cffffffffQuest Export")
  
  -- Close button
  pfQuestExportWindow.closeBtn = CreateFrame("Button", nil, pfQuestExportWindow)
  pfQuestExportWindow.closeBtn:SetPoint("TOPRIGHT", -5, -5)
  pfQuestExportWindow.closeBtn:SetHeight(20)
  pfQuestExportWindow.closeBtn:SetWidth(20)
  pfQuestExportWindow.closeBtn.texture = pfQuestExportWindow.closeBtn:CreateTexture()
  pfQuestExportWindow.closeBtn.texture:SetTexture(pfQuestConfig.path.."\\compat\\close")
  pfQuestExportWindow.closeBtn.texture:SetAllPoints()
  pfQuestExportWindow.closeBtn:SetScript("OnClick", function() pfQuestExportWindow:Hide() end)
  pfUI.api.SkinButton(pfQuestExportWindow.closeBtn, 1, 0.3, 0.3)
  
  -- Instructions
  pfQuestExportWindow.instructions = pfQuestExportWindow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  pfQuestExportWindow.instructions:SetPoint("TOP", pfQuestExportWindow.title, "BOTTOM", 0, -10)
  pfQuestExportWindow.instructions:SetFont(pfUI.font_default, pfUI_config.global.font_size - 1, "OUTLINE")
  pfQuestExportWindow.instructions:SetText("|cffffcc00Press Ctrl+A to select all, then Ctrl+C to copy")
  
  -- Scroll frame for editbox
  pfQuestExportWindow.scroll = CreateFrame("ScrollFrame", "pfQuestExportWindowScroll", pfQuestExportWindow)
  pfQuestExportWindow.scroll:SetPoint("TOPLEFT", pfQuestExportWindow, "TOPLEFT", 10, -50)
  pfQuestExportWindow.scroll:SetPoint("BOTTOMRIGHT", pfQuestExportWindow, "BOTTOMRIGHT", -30, 45)
  pfQuestExportWindow.scroll:EnableMouseWheel(true)
  pfQuestExportWindow.scroll:SetScript("OnMouseWheel", function()
    local current = this:GetVerticalScroll()
    local maxScroll = this:GetVerticalScrollRange()
    
    if arg1 > 0 then
      -- Scroll up
      current = math.max(0, current - 40)
    else
      -- Scroll down
      current = math.min(maxScroll, current + 40)
    end
    
    this:SetVerticalScroll(current)
  end)
  
  -- EditBox (multi-line text area)
  pfQuestExportWindow.editbox = CreateFrame("EditBox", "pfQuestExportWindowEditBox", pfQuestExportWindow.scroll)
  pfQuestExportWindow.editbox:SetMultiLine(true)
  pfQuestExportWindow.editbox:SetAutoFocus(false)
  pfQuestExportWindow.editbox:SetFontObject(GameFontHighlightSmall)
  pfQuestExportWindow.editbox:SetWidth(560)
  pfQuestExportWindow.editbox:SetHeight(4000) -- Large height for all content
  pfQuestExportWindow.editbox:SetScript("OnEscapePressed", function() pfQuestExportWindow:Hide() end)
  pfQuestExportWindow.editbox:SetScript("OnCursorChanged", function()
    -- Auto-scroll to cursor position when typing/navigating
    local _, y = this:GetCursorPosition()
    
    -- FIX: y can be nil if editbox has no cursor, so check before comparing
    if not y then return end
    
    local scrollOffset = pfQuestExportWindow.scroll:GetVerticalScroll()
    local scrollHeight = pfQuestExportWindow.scroll:GetHeight()
    
    if y < scrollOffset then
      pfQuestExportWindow.scroll:SetVerticalScroll(math.max(0, y - 20))
    elseif y > (scrollOffset + scrollHeight) then
      pfQuestExportWindow.scroll:SetVerticalScroll(y - scrollHeight + 20)
    end
  end)
  pfQuestExportWindow.scroll:SetScrollChild(pfQuestExportWindow.editbox)
  
  -- Select All button
  pfQuestExportWindow.selectBtn = CreateFrame("Button", nil, pfQuestExportWindow)
  pfQuestExportWindow.selectBtn:SetPoint("BOTTOMLEFT", pfQuestExportWindow, "BOTTOMLEFT", 10, 10)
  pfQuestExportWindow.selectBtn:SetWidth(100)
  pfQuestExportWindow.selectBtn:SetHeight(28)
  pfQuestExportWindow.selectBtn.text = pfQuestExportWindow.selectBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  pfQuestExportWindow.selectBtn.text:SetPoint("CENTER")
  pfQuestExportWindow.selectBtn.text:SetFont(pfUI.font_default, pfUI_config.global.font_size, "OUTLINE")
  pfQuestExportWindow.selectBtn.text:SetText("Select All")
  pfUI.api.SkinButton(pfQuestExportWindow.selectBtn, 0.3, 0.8, 0.5)
  pfQuestExportWindow.selectBtn:SetScript("OnClick", function()
    pfQuestExportWindow.editbox:HighlightText()
    pfQuestExportWindow.editbox:SetFocus()
  end)
  
  -- Close button (bottom right)
  pfQuestExportWindow.doneBtn = CreateFrame("Button", nil, pfQuestExportWindow)
  pfQuestExportWindow.doneBtn:SetPoint("BOTTOMRIGHT", pfQuestExportWindow, "BOTTOMRIGHT", -10, 10)
  pfQuestExportWindow.doneBtn:SetWidth(100)
  pfQuestExportWindow.doneBtn:SetHeight(28)
  pfQuestExportWindow.doneBtn.text = pfQuestExportWindow.doneBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  pfQuestExportWindow.doneBtn.text:SetPoint("CENTER")
  pfQuestExportWindow.doneBtn.text:SetFont(pfUI.font_default, pfUI_config.global.font_size, "OUTLINE")
  pfQuestExportWindow.doneBtn.text:SetText("Done")
  pfUI.api.SkinButton(pfQuestExportWindow.doneBtn)
  pfQuestExportWindow.doneBtn:SetScript("OnClick", function()
    pfQuestExportWindow:Hide()
  end)
end

-- Bottom buttons (4 buttons: Export, Inject, Clear, Refresh)
pfQuestCaptureUI.exportBtn = CreateFrame("Button", nil, pfQuestCaptureUI)
pfQuestCaptureUI.exportBtn:SetPoint("BOTTOMLEFT", pfQuestCaptureUI, "BOTTOMLEFT", 5, 5)
pfQuestCaptureUI.exportBtn:SetWidth(60)
pfQuestCaptureUI.exportBtn:SetHeight(22)
pfQuestCaptureUI.exportBtn.text = pfQuestCaptureUI.exportBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
pfQuestCaptureUI.exportBtn.text:SetPoint("CENTER")
pfQuestCaptureUI.exportBtn.text:SetFont(pfUI.font_default, pfUI_config.global.font_size - 1, "OUTLINE")
pfQuestCaptureUI.exportBtn.text:SetText("Export")
pfUI.api.SkinButton(pfQuestCaptureUI.exportBtn, 0.3, 0.8, 0.5)
pfQuestCaptureUI.exportBtn:SetScript("OnClick", function()
  pfQuestCaptureUI:ShowExport()
end)
pfQuestCaptureUI.exportBtn:SetScript("OnEnter", function()
  GameTooltip:SetOwner(this, "ANCHOR_TOP")
  GameTooltip:ClearLines()
  GameTooltip:AddLine("Export NEW Quests", 1, 1, 1)
  GameTooltip:AddLine("Export only quests not in database", 0.7, 0.7, 0.7)
  GameTooltip:Show()
end)
pfQuestCaptureUI.exportBtn:SetScript("OnLeave", function()
  GameTooltip:Hide()
end)

pfQuestCaptureUI.injectBtn = CreateFrame("Button", nil, pfQuestCaptureUI)
pfQuestCaptureUI.injectBtn:SetPoint("LEFT", pfQuestCaptureUI.exportBtn, "RIGHT", 5, 0)
pfQuestCaptureUI.injectBtn:SetWidth(60)
pfQuestCaptureUI.injectBtn:SetHeight(22)
pfQuestCaptureUI.injectBtn.text = pfQuestCaptureUI.injectBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
pfQuestCaptureUI.injectBtn.text:SetPoint("CENTER")
pfQuestCaptureUI.injectBtn.text:SetFont(pfUI.font_default, pfUI_config.global.font_size - 1, "OUTLINE")
pfQuestCaptureUI.injectBtn.text:SetText("Inject")
pfUI.api.SkinButton(pfQuestCaptureUI.injectBtn, 0.5, 0.8, 1)
pfQuestCaptureUI.injectBtn:SetScript("OnClick", function()
  if InjectAllCapturedQuests then
    local count = InjectAllCapturedQuests(false)
    if count > 0 then
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest Capture: Injected " .. count .. " quests into live database")
      DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00All characters can now see these quests!")
    else
      DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00No quests to inject")
    end
    pfQuestCaptureUI:UpdateUI()
  end
end)
pfQuestCaptureUI.injectBtn:SetScript("OnEnter", function()
  GameTooltip:SetOwner(this, "ANCHOR_TOP")
  GameTooltip:ClearLines()
  GameTooltip:AddLine("Inject to Live Database", 0.5, 0.8, 1)
  GameTooltip:AddLine("Push all captured quests to pfDB", 0.7, 0.7, 0.7)
  GameTooltip:AddLine("Makes them visible on maps", 0.7, 0.7, 0.7)
  GameTooltip:Show()
end)
pfQuestCaptureUI.injectBtn:SetScript("OnLeave", function()
  GameTooltip:Hide()
end)

pfQuestCaptureUI.clearBtn = CreateFrame("Button", nil, pfQuestCaptureUI)
pfQuestCaptureUI.clearBtn:SetPoint("LEFT", pfQuestCaptureUI.injectBtn, "RIGHT", 5, 0)
pfQuestCaptureUI.clearBtn:SetWidth(60)
pfQuestCaptureUI.clearBtn:SetHeight(22)
pfQuestCaptureUI.clearBtn.text = pfQuestCaptureUI.clearBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
pfQuestCaptureUI.clearBtn.text:SetPoint("CENTER")
pfQuestCaptureUI.clearBtn.text:SetFont(pfUI.font_default, pfUI_config.global.font_size - 1, "OUTLINE")
pfQuestCaptureUI.clearBtn.text:SetText("Clear")
pfUI.api.SkinButton(pfQuestCaptureUI.clearBtn, 1, 0.5, 0.3)
pfQuestCaptureUI.clearBtn:SetScript("OnClick", function()
  StaticPopupDialogs["PFQUEST_CAPTURE_CLEAR"] = {
    text = "Clear all captured quest data?",
    button1 = YES,
    button2 = NO,
    OnAccept = function()
      pfQuest_CapturedQuests = {}
      pfQuestCaptureUI:UpdateUI()
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest Capture: All data cleared")
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
  }
  StaticPopup_Show("PFQUEST_CAPTURE_CLEAR")
end)
pfQuestCaptureUI.clearBtn:SetScript("OnEnter", function()
  GameTooltip:SetOwner(this, "ANCHOR_TOP")
  GameTooltip:ClearLines()
  GameTooltip:AddLine("Clear All Data", 1, 0.8, 0.5)
  GameTooltip:AddLine("Removes all captured quests", 0.7, 0.7, 0.7)
  GameTooltip:Show()
end)
pfQuestCaptureUI.clearBtn:SetScript("OnLeave", function()
  GameTooltip:Hide()
end)

pfQuestCaptureUI.refreshBtn = CreateFrame("Button", nil, pfQuestCaptureUI)
pfQuestCaptureUI.refreshBtn:SetPoint("LEFT", pfQuestCaptureUI.clearBtn, "RIGHT", 5, 0)
pfQuestCaptureUI.refreshBtn:SetWidth(60)
pfQuestCaptureUI.refreshBtn:SetHeight(22)
pfQuestCaptureUI.refreshBtn.text = pfQuestCaptureUI.refreshBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
pfQuestCaptureUI.refreshBtn.text:SetPoint("CENTER")
pfQuestCaptureUI.refreshBtn.text:SetFont(pfUI.font_default, pfUI_config.global.font_size - 1, "OUTLINE")
pfQuestCaptureUI.refreshBtn.text:SetText("Refresh")
pfUI.api.SkinButton(pfQuestCaptureUI.refreshBtn)
pfQuestCaptureUI.refreshBtn:SetScript("OnClick", function()
  pfQuestCaptureUI:UpdateUI()
  DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest Capture: Refreshed")
end)
pfQuestCaptureUI.refreshBtn:SetScript("OnEnter", function()
  GameTooltip:SetOwner(this, "ANCHOR_TOP")
  GameTooltip:ClearLines()
  GameTooltip:AddLine("Refresh List", 1, 1, 1)
  GameTooltip:AddLine("Update quest list display", 0.7, 0.7, 0.7)
  GameTooltip:Show()
end)
pfQuestCaptureUI.refreshBtn:SetScript("OnLeave", function()
  GameTooltip:Hide()
end)

-- Tooltip for titlebar with legend
pfQuestCaptureUI.titlebar:SetScript("OnEnter", function()
  GameTooltip:SetOwner(this, "ANCHOR_TOP")
  GameTooltip:ClearLines()
          GameTooltip:AddLine("|cff33ffccpf|cffffffffQuest Capture Monitor", 1, 1, 1)
          GameTooltip:AddLine(" ")
          GameTooltip:AddLine("|cffffcc00Legend:", 0.7, 0.7, 0.7)
          GameTooltip:AddLine("|cffff8800[NEW!]|r - Quest not in database (contribute!)", 1, 1, 1)
          GameTooltip:AddLine("|cff55ff55[DB]|r - Quest already in database", 1, 1, 1)
          GameTooltip:AddLine("|cff55ff55▶|r Start NPC | |cffffcc00◀|r End NPC", 1, 1, 1)
          GameTooltip:AddLine("|cff00ff00●|r Quest items | |cff00ccff📍|r Objective locations", 1, 1, 1)
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine("|cffaaaaaa Drag titlebar to move", 0.6, 0.6, 0.6)
  GameTooltip:AddLine("|cffaaaaaa Drag corner to resize", 0.6, 0.6, 0.6)
  GameTooltip:Show()
end)

pfQuestCaptureUI.titlebar:SetScript("OnLeave", function()
  GameTooltip:Hide()
end)

