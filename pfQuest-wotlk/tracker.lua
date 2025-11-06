-- multi api compat
local compat = pfQuestCompat
local L = pfQuest_Loc

-- Quest Tracker Frame
pfQuestTracker = CreateFrame("Frame", "pfQuestTracker", UIParent)
pfQuestTracker:Hide()
pfQuestTracker:SetWidth(250)
pfQuestTracker:SetHeight(400)
pfQuestTracker:SetPoint("TOPRIGHT", Minimap, "TOPLEFT", -20, 0)
pfQuestTracker:SetFrameStrata("MEDIUM")
pfQuestTracker:SetMovable(true)
pfQuestTracker:SetResizable(true)
pfQuestTracker:EnableMouse(true)
pfQuestTracker:RegisterForDrag("LeftButton")
pfQuestTracker:SetClampedToScreen(true)
pfQuestTracker:SetMinResize(150, 200)
pfQuestTracker:SetMaxResize(600, 1000)

pfQuestTracker:SetScript("OnDragStart", function()
  if not pfQuest_config.lock then
    this:StartMoving()
  end
end)

pfQuestTracker:SetScript("OnDragStop", function()
  this:StopMovingOrSizing()
  
  -- Save position and size
  local point, relativeTo, relativePoint, xOfs, yOfs = this:GetPoint()
  local width, height = this:GetWidth(), this:GetHeight()
  pfQuest_config.trackerpos = { point, "UIParent", relativePoint, xOfs, yOfs }
  pfQuest_config.trackersize = { width, height }
end)

-- Background
pfQuestTracker.bg = pfQuestTracker:CreateTexture(nil, "BACKGROUND")
pfQuestTracker.bg:SetAllPoints()
pfQuestTracker.bg:SetTexture(0, 0, 0, 0.5)

-- Title Bar (clickable area for right-click lock)
pfQuestTracker.titlebar = CreateFrame("Frame", nil, pfQuestTracker)
pfQuestTracker.titlebar:SetPoint("TOPLEFT", pfQuestTracker, "TOPLEFT", 75, 0) -- Leave space for 4 left buttons
pfQuestTracker.titlebar:SetPoint("TOPRIGHT", pfQuestTracker, "TOPRIGHT", -90, 0) -- Leave space for right buttons
pfQuestTracker.titlebar:SetHeight(25)
pfQuestTracker.titlebar:SetFrameLevel(pfQuestTracker:GetFrameLevel())
pfQuestTracker.titlebar:EnableMouse(true)
pfQuestTracker.titlebar:RegisterForDrag("LeftButton")

-- Right-click to lock/unlock
pfQuestTracker.titlebar:SetScript("OnMouseDown", function()
  if arg1 == "RightButton" then
    pfQuest_config.lock = not pfQuest_config.lock
    if pfQuest_config.lock then
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest Tracker: |cffff5555LOCKED")
      -- Update resize grip visibility
      if pfQuestTracker.resizegrip then
        pfQuestTracker.resizegrip:Hide()
      end
    else
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest Tracker: |cff55ff55UNLOCKED")
      if pfQuestTracker.resizegrip then
        pfQuestTracker.resizegrip:Show()
      end
    end
  elseif arg1 == "LeftButton" and not pfQuest_config.lock then
    pfQuestTracker:StartMoving()
  end
end)

pfQuestTracker.titlebar:SetScript("OnMouseUp", function()
  if arg1 == "LeftButton" then
    pfQuestTracker:StopMovingOrSizing()
    
    -- Save position
    local point, relativeTo, relativePoint, xOfs, yOfs = pfQuestTracker:GetPoint()
    local width, height = pfQuestTracker:GetWidth(), pfQuestTracker:GetHeight()
    pfQuest_config.trackerpos = { point, "UIParent", relativePoint, xOfs, yOfs }
    pfQuest_config.trackersize = { width, height }
  end
end)

-- Tooltip for titlebar
pfQuestTracker.titlebar:SetScript("OnEnter", function()
  GameTooltip:SetOwner(this, "ANCHOR_TOP")
  GameTooltip:ClearLines()
  GameTooltip:AddLine("|cff33ffccpf|cffffffffQuest Tracker", 1, 1, 1)
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine("|cffffcc00Title Bar:", 0.5, 1, 0.5)
  GameTooltip:AddLine("Left-click & Drag: Move tracker", 0.7, 0.7, 0.7)
  GameTooltip:AddLine("Right-click: Lock/Unlock position", 0.7, 0.7, 0.7)
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine("|cffffcc00Quest Entries:", 0.5, 1, 0.5)
  GameTooltip:AddLine("Click: Expand/collapse that quest", 0.7, 0.7, 0.7)
  GameTooltip:AddLine("Shift+Click: Expand/collapse ALL", 1, 0.8, 0)
  GameTooltip:AddLine("Ctrl+Click: View on map", 0.5, 1, 0.5)
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine("|cffffcc00Corner Resize Grip:", 0.5, 1, 0.5)
  GameTooltip:AddLine("Drag: Resize tracker window", 0.7, 0.7, 0.7)
  GameTooltip:AddLine(" ")
  local lockStatus = pfQuest_config and pfQuest_config.lock
  if lockStatus then
    GameTooltip:AddLine("|cffff5555● Currently LOCKED", 1, 0.3, 0.3)
    GameTooltip:AddLine("|cffaaaaaa(Right-click to unlock)", 0.7, 0.7, 0.7)
  else
    GameTooltip:AddLine("|cff55ff55● Currently UNLOCKED", 0.3, 1, 0.3)
    GameTooltip:AddLine("|cffaaaaaa(Right-click to lock)", 0.7, 0.7, 0.7)
  end
  GameTooltip:Show()
end)

pfQuestTracker.titlebar:SetScript("OnLeave", function()
  GameTooltip:Hide()
end)

-- Helper function to create top bar buttons
local function CreateTopButton(name, iconName, point, xOffset, tooltip, clickFunc, vertexColor, customTooltip)
  local btn = CreateFrame("Button", "pfQuestTracker"..name, pfQuestTracker)
  btn:SetPoint(point, xOffset, -5)
  btn:SetHeight(16)
  btn:SetWidth(16)
  btn:SetFrameLevel(pfQuestTracker:GetFrameLevel() + 2)
  btn:EnableMouse(true)
  btn:RegisterForClicks("LeftButtonUp")
  
  -- No background - buttons are transparent, only icon shows
  btn.texture = btn:CreateTexture(nil, "ARTWORK")
  btn.texture:SetTexture(pfQuestConfig.path.."\\img\\"..iconName)
  btn.texture:SetAllPoints()
  
  if vertexColor then
    btn.texture:SetVertexColor(unpack(vertexColor))
  else
    btn.texture:SetVertexColor(1, 1, 1, 1)  -- Default white
  end
  
  if clickFunc then
    btn:SetScript("OnClick", clickFunc)
  end
  
  -- Use custom tooltip function if provided, otherwise use simple tooltip
  if customTooltip then
    btn:SetScript("OnEnter", customTooltip)
  else
    btn:SetScript("OnEnter", function()
      GameTooltip:SetOwner(this, "ANCHOR_TOP")
      GameTooltip:ClearLines()
      GameTooltip:AddLine(tooltip, 1, 1, 1)
      GameTooltip:Show()
    end)
  end
  
  btn:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)
  
  -- NO button skinning - transparent background, only icon visible
  
  return btn
end

-- Mode tracking for the tracker
pfQuestTracker.mode = "QUEST_TRACKING"

-- Left side buttons (mode switching) - TOP BAR FROM OG
pfQuestTracker.btnquest = CreateTopButton("Quests", "tracker_quests", "TOPLEFT", 5, 
  L["Show Current Quests"] or "Show Current Quests", 
  function()
    pfQuestTracker.mode = "QUEST_TRACKING"
    pfQuestTracker.btnquest.texture:SetVertexColor(.2, 1, .8)
    pfQuestTracker.btndatabase.texture:SetVertexColor(1, 1, 1)
    pfQuestTracker.btngiver.texture:SetVertexColor(1, 1, 1)
    if pfMap then pfMap:UpdateNodes() end
  end,
  {.2, 1, .8})  -- Default active color

pfQuestTracker.btndatabase = CreateTopButton("Database", "tracker_database", "TOPLEFT", 22,
  L["Show Database Results"] or "Show Database Results",
  function()
    pfQuestTracker.mode = "DATABASE_TRACKING"
    pfQuestTracker.btnquest.texture:SetVertexColor(1, 1, 1)
    pfQuestTracker.btndatabase.texture:SetVertexColor(.2, 1, .8)
    pfQuestTracker.btngiver.texture:SetVertexColor(1, 1, 1)
    if pfMap then pfMap:UpdateNodes() end
  end)

pfQuestTracker.btngiver = CreateTopButton("Giver", "tracker_giver", "TOPLEFT", 39,
  L["Show Quest Givers"] or "Show Quest Givers",
  function()
    pfQuestTracker.mode = "GIVER_TRACKING"
    pfQuestTracker.btnquest.texture:SetVertexColor(1, 1, 1)
    pfQuestTracker.btndatabase.texture:SetVertexColor(1, 1, 1)
    pfQuestTracker.btngiver.texture:SetVertexColor(.2, 1, .8)
    if pfMap then pfMap:UpdateNodes() end
  end)

-- Quest Capture/Learning button
pfQuestTracker.btncapture = CreateTopButton("Capture", "cluster_item", "TOPLEFT", 56,
  "Quest Capture System",
  function()
    if pfQuestCaptureUI then
      if pfQuestCaptureUI:IsShown() then
        pfQuestCaptureUI:Hide()
      else
        pfQuestCaptureUI:Show()
        if pfQuestCaptureUI.UpdateUI then
          pfQuestCaptureUI:UpdateUI()
        end
      end
    end
  end,
  nil,  -- No default vertex color, set by UpdateColor
  function()  -- Custom tooltip showing status
    GameTooltip:SetOwner(this, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("|cff33ffccpf|cffffffffQuest Capture System", 1, 1, 1)
    GameTooltip:AddLine(" ")
    
    -- Show status with color
    if pfQuest_CaptureConfig and pfQuest_CaptureConfig.enabled then
      GameTooltip:AddLine("Status: |cff55ff55ENABLED", 1, 1, 1)
      GameTooltip:AddLine("Capturing quest data in background", 0.7, 0.7, 0.7)
    else
      GameTooltip:AddLine("Status: |cffff5555DISABLED", 1, 1, 1)
      GameTooltip:AddLine("Quest data not being captured", 0.7, 0.7, 0.7)
    end
    
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Click: Open capture monitor", 0.5, 1, 0.5)
    GameTooltip:AddLine("Use /questcapture toggle to enable/disable", 0.6, 0.6, 0.6)
    GameTooltip:Show()
  end)

-- Update capture button color based on enabled state
pfQuestTracker.btncapture.UpdateColor = function()
  if pfQuest_CaptureConfig and pfQuest_CaptureConfig.enabled then
    pfQuestTracker.btncapture.texture:SetVertexColor(0.3, 1, 0.3)  -- Green when enabled
  else
    pfQuestTracker.btncapture.texture:SetVertexColor(1, 0.3, 0.3)  -- Red when disabled
  end
end

-- Set initial color
pfQuestTracker.btncapture.UpdateColor()

-- Right side buttons (utilities) - TOP BAR FROM OG
pfQuestTracker.btnsearch = CreateTopButton("Search", "tracker_search", "TOPRIGHT", -89,
  L["Open Database Browser"] or "Open Database Browser",
  function()
    if pfBrowser then pfBrowser:Show() end
  end)

pfQuestTracker.btnclean = CreateTopButton("Clean", "tracker_clean", "TOPRIGHT", -72,
  L["Clean Database Results"] or "Clean Database Results",
  function()
    if pfMap then 
      pfMap:DeleteNode("PFDB")
      pfMap:UpdateNodes()
    end
  end)

pfQuestTracker.btnsettings = CreateTopButton("Settings", "tracker_settings", "TOPRIGHT", -25,
  L["Open Settings"] or "Open Settings",
  function()
    if pfQuestConfig then pfQuestConfig:Show() end
  end,
  {0.8, 0.8, 0.8})

pfQuestTracker.btnclose = CreateTopButton("Close", "tracker_close", "TOPRIGHT", -5,
  L["Close Tracker"] or "Close Tracker",
  function()
    pfQuest_config["showtracker"] = "0"
    pfQuestTracker:Hide()
    DEFAULT_CHAT_FRAME:AddMessage(L["|cff33ffccpf|cffffffffQuest: Tracker is now hidden. Type `/db tracker` to show."])
  end,
  {1, .25, .25})

-- Title
pfQuestTracker.title = pfQuestTracker:CreateFontString("pfQuestTrackerTitle", "ARTWORK", "GameFontNormalLarge")
pfQuestTracker.title:SetPoint("TOP", pfQuestTracker, "TOP", 0, -8)
pfQuestTracker.title:SetText("|cff33ffccpf|cffffffffQuest Tracker")
if pfUI and pfUI.font_default and pfUI_config and pfUI_config.global and pfUI_config.global.font_size then
  pfQuestTracker.title:SetFont(pfUI.font_default, pfUI_config.global.font_size + 2, "OUTLINE")
end

-- Resize Grip (bottom-right corner)
pfQuestTracker.resizegrip = CreateFrame("Frame", nil, pfQuestTracker)
pfQuestTracker.resizegrip:SetWidth(16)
pfQuestTracker.resizegrip:SetHeight(16)
pfQuestTracker.resizegrip:SetPoint("BOTTOMRIGHT", pfQuestTracker, "BOTTOMRIGHT", 0, 0)
pfQuestTracker.resizegrip:EnableMouse(true)
pfQuestTracker.resizegrip:SetFrameLevel(pfQuestTracker:GetFrameLevel() + 1)

-- Visual indicator for resize grip
pfQuestTracker.resizegrip.texture = pfQuestTracker.resizegrip:CreateTexture(nil, "OVERLAY")
pfQuestTracker.resizegrip.texture:SetAllPoints()
pfQuestTracker.resizegrip.texture:SetTexture(1, 1, 1, 0.3)

-- Draw diagonal lines for resize grip visual
pfQuestTracker.resizegrip.line1 = pfQuestTracker.resizegrip:CreateTexture(nil, "OVERLAY")
pfQuestTracker.resizegrip.line1:SetTexture(1, 1, 1, 0.5)
pfQuestTracker.resizegrip.line1:SetWidth(10)
pfQuestTracker.resizegrip.line1:SetHeight(1)
pfQuestTracker.resizegrip.line1:SetPoint("BOTTOMRIGHT", pfQuestTracker.resizegrip, "BOTTOMRIGHT", -2, 4)

pfQuestTracker.resizegrip.line2 = pfQuestTracker.resizegrip:CreateTexture(nil, "OVERLAY")
pfQuestTracker.resizegrip.line2:SetTexture(1, 1, 1, 0.5)
pfQuestTracker.resizegrip.line2:SetWidth(10)
pfQuestTracker.resizegrip.line2:SetHeight(1)
pfQuestTracker.resizegrip.line2:SetPoint("BOTTOMRIGHT", pfQuestTracker.resizegrip, "BOTTOMRIGHT", -2, 8)

pfQuestTracker.resizegrip.line3 = pfQuestTracker.resizegrip:CreateTexture(nil, "OVERLAY")
pfQuestTracker.resizegrip.line3:SetTexture(1, 1, 1, 0.5)
pfQuestTracker.resizegrip.line3:SetWidth(10)
pfQuestTracker.resizegrip.line3:SetHeight(1)
pfQuestTracker.resizegrip.line3:SetPoint("BOTTOMRIGHT", pfQuestTracker.resizegrip, "BOTTOMRIGHT", -2, 12)

-- Resize grip drag functionality
pfQuestTracker.resizegrip:SetScript("OnMouseDown", function()
  if not pfQuest_config.lock then
    pfQuestTracker:StartSizing("BOTTOMRIGHT")
  end
end)

pfQuestTracker.resizegrip:SetScript("OnMouseUp", function()
  pfQuestTracker:StopMovingOrSizing()
  
  -- Save size
  local width, height = pfQuestTracker:GetWidth(), pfQuestTracker:GetHeight()
  pfQuest_config.trackersize = { width, height }
end)

-- Tooltip for resize grip
pfQuestTracker.resizegrip:SetScript("OnEnter", function()
  if not pfQuest_config.lock then
    GameTooltip:SetOwner(this, "ANCHOR_CURSOR")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Drag to resize", 1, 1, 1)
    GameTooltip:Show()
  end
end)

pfQuestTracker.resizegrip:SetScript("OnLeave", function()
  GameTooltip:Hide()
end)

-- Initialize lock state
pfQuest_config = pfQuest_config or {}
pfQuest_config.lock = pfQuest_config.lock or false

-- Hide resize grip when locked
if pfQuest_config.lock then
  pfQuestTracker.resizegrip:Hide()
end

-- Scroll Frame
pfQuestTracker.scroll = CreateFrame("ScrollFrame", "pfQuestTrackerScroll", pfQuestTracker)
pfQuestTracker.scroll:SetPoint("TOPLEFT", pfQuestTracker, "TOPLEFT", 5, -30)
pfQuestTracker.scroll:SetPoint("BOTTOMRIGHT", pfQuestTracker, "BOTTOMRIGHT", -5, 5)

-- Content Frame
pfQuestTracker.content = CreateFrame("Frame", "pfQuestTrackerContent", pfQuestTracker.scroll)
pfQuestTracker.content:SetWidth(240)
pfQuestTracker.content:SetHeight(1)
pfQuestTracker.scroll:SetScrollChild(pfQuestTracker.content)

-- Enable mouse wheel scrolling
pfQuestTracker.scroll:EnableMouseWheel(true)
pfQuestTracker.scroll:SetScript("OnMouseWheel", function()
  local current = this:GetVerticalScroll()
  local maxScroll = this:GetVerticalScrollRange()
  
  if arg1 > 0 then
    current = math.max(0, current - 20)
  else
    current = math.min(maxScroll, current + 20)
  end
  
  this:SetVerticalScroll(current)
end)

-- Quest Entry Pool
pfQuestTracker.questEntries = {}
pfQuestTracker.objectiveEntries = {}
pfQuestTracker.expandedQuests = {}  -- Track which quests are expanded
local entryPool = {}
local objectivePool = {}

-- Create entry from pool
local function GetQuestEntry()
  local entry = table.remove(entryPool)
  if not entry then
    entry = CreateFrame("Button", nil, pfQuestTracker.content)
    entry:SetWidth(230)
    entry:SetHeight(20)
    
    entry.text = entry:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    entry.text:SetPoint("LEFT", entry, "LEFT", 5, 0)
    entry.text:SetJustifyH("LEFT")
    entry.text:SetWidth(220)
    entry.text:SetWordWrap(false)
    
    entry:SetScript("OnEnter", function()
      if this.questID then
        GameTooltip:SetOwner(this, "ANCHOR_LEFT")
        GameTooltip:ClearLines()
        GameTooltip:AddLine(this.questTitle, 1, 1, 1)
        
        local isExpanded = pfQuestTracker.expandedQuests[this.questID]
        if isExpanded then
          GameTooltip:AddLine(" ")
          GameTooltip:AddLine("Click: Collapse objectives", 0.7, 0.7, 0.7)
        else
          GameTooltip:AddLine(" ")
          GameTooltip:AddLine("Click: Expand objectives", 0.7, 0.7, 0.7)
        end
        GameTooltip:AddLine("Ctrl+Click: View on map", 0.5, 1, 0.5)
        GameTooltip:AddLine("Shift+Click: Toggle all quests", 1, 0.8, 0)
        GameTooltip:Show()
      end
    end)
    
    entry:SetScript("OnLeave", function()
      GameTooltip:Hide()
    end)
    
    entry:SetScript("OnClick", function()
      if this.questID then
        if IsControlKeyDown() then
          -- Show quest on map
          local meta = { ["addon"] = "PFQUEST_TRACKER" }
          if pfDatabase then
            local maps = pfDatabase:SearchQuestID(this.questID, meta)
            if maps and pfMap then
              pfMap:ShowMapID(pfDatabase:GetBestMap(maps))
            end
          end
        elseif IsShiftKeyDown() then
          -- Toggle ALL quests
          local anyExpanded = false
          for qid, expanded in pairs(pfQuestTracker.expandedQuests) do
            if expanded then
              anyExpanded = true
              break
            end
          end
          
          -- If any are expanded, collapse all. Otherwise, expand all.
          if anyExpanded then
            pfQuestTracker.expandedQuests = {}
          else
            -- Expand all current quests
            for _, entry in pairs(pfQuestTracker.questEntries) do
              if entry.questID then
                pfQuestTracker.expandedQuests[entry.questID] = true
              end
            end
          end
          pfQuestTracker:UpdateTracker()
        else
          -- Toggle THIS quest
          pfQuestTracker.expandedQuests[this.questID] = not pfQuestTracker.expandedQuests[this.questID]
          pfQuestTracker:UpdateTracker()
        end
      end
    end)
  end
  
  -- Apply current font size from config
  local fontSize = tonumber(pfQuest_config["trackerfontsize"]) or 12
  if pfUI and pfUI.font_default then
    entry.text:SetFont(pfUI.font_default, fontSize, "OUTLINE")
  end
  
  entry:Show()
  return entry
end

-- Create objective entry from pool
local function GetObjectiveEntry()
  local entry = table.remove(objectivePool)
  if not entry then
    entry = CreateFrame("Frame", nil, pfQuestTracker.content)
    entry:SetWidth(230)
    entry:SetHeight(28)  -- Increased to allow 2 lines
    
    entry.text = entry:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    entry.text:SetPoint("TOPLEFT", entry, "TOPLEFT", 15, -2)
    entry.text:SetWidth(210)
    entry.text:SetJustifyH("LEFT")
    entry.text:SetJustifyV("TOP")
    entry.text:SetWordWrap(true)
  end
  
  -- Apply current font size from config (smaller for objectives)
  local fontSize = tonumber(pfQuest_config["trackerfontsize"]) or 12
  if pfUI and pfUI.font_default then
    entry.text:SetFont(pfUI.font_default, math.max(fontSize - 2, 8), "OUTLINE")
  end
  
  entry:Show()
  return entry
end

-- Return entry to pool
local function ReleaseEntry(entry, isObjective)
  entry:Hide()
  entry:ClearAllPoints()
  entry.questID = nil
  entry.questTitle = nil
  
  if isObjective then
    table.insert(objectivePool, entry)
  else
    table.insert(entryPool, entry)
  end
end

-- Get quest objectives
local function GetQuestObjectives(questIndex)
  local objectives = {}
  local numObjectives = GetNumQuestLeaderBoards(questIndex)
  
  for i = 1, numObjectives do
    local text, type, finished = GetQuestLogLeaderBoard(i, questIndex)
    if text then
      table.insert(objectives, {
        text = text,
        finished = finished
      })
    end
  end
  
  return objectives
end

-- Update tracker
function pfQuestTracker:UpdateTracker()
  -- Save the currently selected quest to restore it later
  local currentSelection = GetQuestLogSelection()
  
  -- Release all entries
  for _, entry in pairs(self.questEntries) do
    ReleaseEntry(entry, false)
  end
  for _, entry in pairs(self.objectiveEntries) do
    ReleaseEntry(entry, true)
  end
  
  self.questEntries = {}
  self.objectiveEntries = {}
  
  -- Apply current config settings
  local alpha = tonumber(pfQuest_config["trackeralpha"]) or 1.0
  self:SetAlpha(alpha)
  
  -- Check if tracker is enabled
  if pfQuest_config["showtracker"] == "0" then
    self:Hide()
    -- Restore selection before returning
    SelectQuestLogEntry(currentSelection)
    return
  end
  
  -- Get quest log entries
  local numEntries, numQuests = GetNumQuestLogEntries()
  
  -- Make sure tracker is shown
  self:Show()
  
  -- Also ensure it's at proper strata
  self:SetFrameStrata("MEDIUM")
  
  local yOffset = 0
  local questCount = 0
  
  for i = 1, numEntries do
    local questTitle, level, questTag, isHeader, isCollapsed, isComplete = GetQuestLogTitle(i)
    
    -- Check if this is an actual quest (not a header)
    -- In Lua, 0 is truthy, so we need to explicitly check for non-header
    if questTitle and (not isHeader or isHeader == 0 or isHeader == false) then
      -- Get quest ID
      SelectQuestLogEntry(i)
      local questID = nil
      local questText = GetQuestLogQuestText()
      
      -- Try to get quest ID from database
      if pfDB and pfDB["quests"] and pfDB["quests"]["loc"] then
        for qid, qdata in pairs(pfDB["quests"]["loc"]) do
          if qdata["T"] == questTitle then
            questID = qid
            break
          end
        end
      end
      
      -- Create quest entry
      local entry = GetQuestEntry()
      entry.questID = questID or i
      entry.questTitle = questTitle
      
      -- Color based on completion
      local color = isComplete and "|cff00ff00" or "|cffffffff"
      
      -- Add level if enabled
      local levelText = ""
      if pfQuest_config["trackerlevel"] == "1" then
        levelText = "|cffffcc00[" .. level .. "]|r "
      end
      
      -- Truncate quest title if too long
      local displayTitle = questTitle
      if string.len(displayTitle) > 30 then
        displayTitle = string.sub(displayTitle, 1, 27) .. "..."
      end
      
      entry.text:SetText(levelText .. color .. displayTitle)
      entry:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, -yOffset)
      
      table.insert(self.questEntries, entry)
      questCount = questCount + 1
      yOffset = yOffset + 20
      
      -- Add objectives if this quest is expanded
      if pfQuestTracker.expandedQuests[entry.questID] then
        local objectives = GetQuestObjectives(i)
        
        for _, obj in ipairs(objectives) do
          local objEntry = GetObjectiveEntry()
          
          -- Color based on completion
          local objColor = obj.finished and "|cff00ff00" or "|cffaaaaaa"
          
          -- Don't truncate - let it wrap to 2 lines
          objEntry.text:SetText(objColor .. "- " .. obj.text)
          objEntry:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, -yOffset)
          
          -- Calculate actual text height (in case it wraps to 2 lines)
          local textHeight = objEntry.text:GetStringHeight()
          local entryHeight = math.max(textHeight + 4, 14)
          objEntry:SetHeight(entryHeight)
          
          table.insert(self.objectiveEntries, objEntry)
          yOffset = yOffset + entryHeight
        end
        
        -- Add spacing after quest with objectives
        if #objectives > 0 then
          yOffset = yOffset + 4
        end
      end
    end
  end
  
  -- Update content height
  self.content:SetHeight(math.max(yOffset, 1))
  
  -- Adjust tracker visibility based on config
  local alpha = tonumber(pfQuest_config["trackeralpha"]) or 1.0
  self:SetAlpha(alpha)
  
  -- Restore the originally selected quest
  SelectQuestLogEntry(currentSelection)
end

-- Reset function for backwards compatibility with old tracker API
-- Called by pfMap:UpdateNodes() and other parts of the system
function pfQuestTracker.Reset()
  -- Clear the node-based entries (for DATABASE_TRACKING and GIVER_TRACKING modes)
  pfQuestTracker.nodeEntries = {}
  
  -- If in QUEST_TRACKING mode, update from quest log
  if pfQuestTracker.mode == "QUEST_TRACKING" then
    pfQuestTracker:UpdateTracker()
  end
end

-- ButtonAdd function for backwards compatibility with old tracker API
-- Called by pfMap when adding quest nodes to tracker
function pfQuestTracker.ButtonAdd(title, node)
  if not title or not node then return end
  
  -- Store node entries for non-quest-log modes
  pfQuestTracker.nodeEntries = pfQuestTracker.nodeEntries or {}
  pfQuestTracker.nodeEntries[title] = node
  
  -- If in DATABASE_TRACKING or GIVER_TRACKING mode, refresh display
  if pfQuestTracker.mode == "DATABASE_TRACKING" or pfQuestTracker.mode == "GIVER_TRACKING" then
    pfQuestTracker:UpdateTrackerNodes()
  end
end

-- Update tracker for node-based modes (DATABASE_TRACKING, GIVER_TRACKING)
function pfQuestTracker:UpdateTrackerNodes()
  if self.mode == "QUEST_TRACKING" then
    -- Use regular quest log update
    self:UpdateTracker()
    return
  end
  
  -- Save the currently selected quest to restore it later
  local currentSelection = GetQuestLogSelection()
  
  -- Release all entries
  for _, entry in pairs(self.questEntries) do
    ReleaseEntry(entry, false)
  end
  for _, entry in pairs(self.objectiveEntries) do
    ReleaseEntry(entry, true)
  end
  
  self.questEntries = {}
  self.objectiveEntries = {}
  
  -- Check if tracker is enabled
  if pfQuest_config["showtracker"] == "0" then
    self:Hide()
    SelectQuestLogEntry(currentSelection)
    return
  end
  
  self:Show()
  self:SetFrameStrata("MEDIUM")
  
  local yOffset = 0
  
  -- Display node entries based on mode
  if self.nodeEntries then
    -- Sort entries by title
    local sortedEntries = {}
    for title, node in pairs(self.nodeEntries) do
      table.insert(sortedEntries, {title = title, node = node})
    end
    
    table.sort(sortedEntries, function(a, b)
      return (a.title or "") < (b.title or "")
    end)
    
    -- Create entries for each node
    for _, data in ipairs(sortedEntries) do
      local entry = GetQuestEntry()
      entry.questID = nil
      entry.questTitle = data.title
      entry.nodeData = data.node
      
      -- Set text based on mode
      local displayText = data.title
      if self.mode == "GIVER_TRACKING" and data.node.qlvl then
        displayText = "|cffffcc00["..data.node.qlvl.."]|r " .. data.title
      end
      
      entry.text:SetText(displayText)
      entry:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, -yOffset)
      
      table.insert(self.questEntries, entry)
      yOffset = yOffset + 20
    end
  end
  
  -- Update content height
  self.content:SetHeight(math.max(yOffset, 1))
  
  -- Adjust tracker visibility based on config
  local alpha = tonumber(pfQuest_config["trackeralpha"]) or 1.0
  self:SetAlpha(alpha)
  
  -- Restore the originally selected quest
  SelectQuestLogEntry(currentSelection)
end

-- Event handling
pfQuestTracker:RegisterEvent("QUEST_LOG_UPDATE")
pfQuestTracker:RegisterEvent("PLAYER_ENTERING_WORLD")
pfQuestTracker:RegisterEvent("ADDON_LOADED")

-- OPTIMIZATION: Throttle QUEST_LOG_UPDATE to prevent stuttering
local lastTrackerUpdate = 0
pfQuestTracker:SetScript("OnEvent", function()
  if event == "ADDON_LOADED" and (arg1 == "pfQuest-wotlk" or arg1 == "pfQuest") then
    -- Initialize tracker config
    if pfQuest_config["showtracker"] == nil then
      pfQuest_config["showtracker"] = "1"
    end
    if pfQuest_config["trackeralpha"] == nil then
      pfQuest_config["trackeralpha"] = "1.0"
    end
    if pfQuest_config["trackerfontsize"] == nil then
      pfQuest_config["trackerfontsize"] = "12"
    end
    if pfQuest_config["trackerexpand"] == nil then
      pfQuest_config["trackerexpand"] = "0"
    end
    if pfQuest_config["trackerlevel"] == nil then
      pfQuest_config["trackerlevel"] = "1"
    end
    
    -- Hide the default WoW quest tracker
    if pfQuestCompat and pfQuestCompat.QuestWatchFrame then
      pfQuestCompat.QuestWatchFrame:Hide()
    end
    
    -- Load saved position if it exists
    if pfQuest_config.trackerpos then
      this:ClearAllPoints()
      this:SetPoint(unpack(pfQuest_config.trackerpos))
    end
    
    -- Load saved size if it exists
    if pfQuest_config.trackersize then
      this:SetWidth(pfQuest_config.trackersize[1])
      this:SetHeight(pfQuest_config.trackersize[2])
    end
    
    -- Update resize grip visibility based on lock state
    if pfQuest_config.lock then
      pfQuestTracker.resizegrip:Hide()
    else
      pfQuestTracker.resizegrip:Show()
    end
    
    -- Update tracker
    this:UpdateTracker()
  elseif event == "QUEST_LOG_UPDATE" then
    -- OPTIMIZATION: Throttle QUEST_LOG_UPDATE to max once per 0.5 seconds
    -- This event fires VERY frequently and was causing stuttering
    local now = GetTime()
    if now - lastTrackerUpdate >= 0.5 then
      lastTrackerUpdate = now
      this:UpdateTracker()
    end
  elseif event == "PLAYER_ENTERING_WORLD" then
    this:UpdateTracker()
  end
end)

-- Update tracker periodically (for quest progress updates)
-- OPTIMIZATION: Increased from 1s to 2s to reduce CPU usage and stuttering
pfQuestTracker.updateTimer = 0
pfQuestTracker:SetScript("OnUpdate", function()
  this.updateTimer = this.updateTimer + arg1
  if this.updateTimer > 2 then
    this.updateTimer = 0
    if this:IsShown() then
      this:UpdateTracker()
    end
  end
  
  -- Hide the default WoW quest tracker
  if pfQuestCompat and pfQuestCompat.QuestWatchFrame and pfQuestCompat.QuestWatchFrame:IsShown() then
    pfQuestCompat.QuestWatchFrame:Hide()
  end
end)

-- Add slash command to show tracker
local oldSlashHandler = SlashCmdList["PFDB"]
SlashCmdList["PFDB"] = function(input, editbox)
  local command = string.lower(input or "")
  
  if command == "tracker" then
    if pfQuest_config["showtracker"] and pfQuest_config["showtracker"] == "0" then
      pfQuest_config["showtracker"] = "1"
      pfQuestTracker:UpdateTracker()
      pfQuestTracker:Show()
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest: Tracker is now visible.")
    else
      pfQuest_config["showtracker"] = "0"
      pfQuestTracker:Hide()
      DEFAULT_CHAT_FRAME:AddMessage(L["|cff33ffccpf|cffffffffQuest: Tracker is now hidden. Type `/db tracker` to show."])
    end
    return
  end
  
  if command == "lock" then
    pfQuest_config.lock = not pfQuest_config.lock
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest Tracker: " .. ( pfQuest_config.lock and "Locked" or "Unlocked" ))
    return
  end
  
  -- Debug command to check tracker status
  if command == "trackerdebug" then
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest Tracker Debug:")
    DEFAULT_CHAT_FRAME:AddMessage("Frame exists: " .. tostring(pfQuestTracker ~= nil))
    if pfQuestTracker then
      DEFAULT_CHAT_FRAME:AddMessage("IsShown: " .. tostring(pfQuestTracker:IsShown()))
      DEFAULT_CHAT_FRAME:AddMessage("IsVisible: " .. tostring(pfQuestTracker:IsVisible()))
      DEFAULT_CHAT_FRAME:AddMessage("Alpha: " .. tostring(pfQuestTracker:GetAlpha()))
      local w, h = pfQuestTracker:GetWidth(), pfQuestTracker:GetHeight()
      DEFAULT_CHAT_FRAME:AddMessage("Size: " .. tostring(w) .. "x" .. tostring(h))
      local point, relativeTo, relativePoint, xOfs, yOfs = pfQuestTracker:GetPoint()
      DEFAULT_CHAT_FRAME:AddMessage("Position: " .. tostring(point) .. " " .. tostring(xOfs) .. "," .. tostring(yOfs))
      DEFAULT_CHAT_FRAME:AddMessage("Config showtracker: " .. tostring(pfQuest_config["showtracker"]))
      DEFAULT_CHAT_FRAME:AddMessage("Config alpha: " .. tostring(pfQuest_config["trackeralpha"]))
      DEFAULT_CHAT_FRAME:AddMessage("Content height: " .. tostring(pfQuestTracker.content:GetHeight()))
      DEFAULT_CHAT_FRAME:AddMessage("Quest entries: " .. tostring(#pfQuestTracker.questEntries))
    end
    return
  end
  
  -- Debug command to force show tracker
  if command == "trackershow" then
    pfQuest_config["showtracker"] = "1"
    pfQuestTracker:ClearAllPoints()
    pfQuestTracker:SetPoint("TOPRIGHT", Minimap, "TOPLEFT", -20, 0)
    pfQuestTracker:SetWidth(250)
    pfQuestTracker:SetHeight(400)
    pfQuestTracker:SetAlpha(1.0)
    pfQuestTracker:UpdateTracker()
    pfQuestTracker:Show()
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest: Tracker force shown at default position.")
    DEFAULT_CHAT_FRAME:AddMessage("Run /db trackerdebug to see status")
    return
  end
  
  -- Call original handler
  if oldSlashHandler then
    oldSlashHandler(input, editbox)
  end
end

-- Make global available (for compatibility with rest of addon)
pfQuest = pfQuest or {}
pfQuest.tracker = pfQuestTracker
tracker = pfQuestTracker
