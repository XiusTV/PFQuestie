-- multi api compat
local compat = pfQuestCompat
local L = pfQuest_Loc
local wipe = _G.wipe or function(tbl)
  for key in pairs(tbl) do
    tbl[key] = nil
  end
end
local math_max = math.max

pfQuest_history = {}
pfQuest_colors = {}
pfQuest_config = {}

local reset = {
  config = function()
    local dialog = StaticPopupDialogs["PFQUEST_RESET"]
    dialog.text = L["Do you really want to reset the configuration?"]
    dialog.OnAccept = function()
      pfQuest_config = nil
      ReloadUI()
    end

    StaticPopup_Show("PFQUEST_RESET")
  end,
  history = function()
    local dialog = StaticPopupDialogs["PFQUEST_RESET"]
    dialog.text = L["Do you really want to reset the quest history?"]
    dialog.OnAccept = function()
      pfQuest_history = nil
      ReloadUI()
    end

    StaticPopup_Show("PFQUEST_RESET")
  end,
  cache = function()
    local dialog = StaticPopupDialogs["PFQUEST_RESET"]
    dialog.text = L["Do you really want to reset the caches?"]
    dialog.OnAccept = function()
      pfQuest_questcache = nil
      ReloadUI()
    end

    StaticPopup_Show("PFQUEST_RESET")
  end,
  everything = function()
    local dialog = StaticPopupDialogs["PFQUEST_RESET"]
    dialog.text = L["Do you really want to reset everything?"]
    dialog.OnAccept = function()
      pfQuest_config, pfBrowser_fav, pfQuest_history, pfQuest_colors, pfQuest_server, pfQuest_questcache = nil
      ReloadUI()
    end

    StaticPopup_Show("PFQUEST_RESET")
  end,
}

-- default config
pfQuest_defconfig = {
  { -- 1: All Quests; 2: Tracked; 3: Manual; 4: Hide
    config = "trackingmethod",
    text = nil, default = 1, type = nil
  },

  { text = L["General"],
    default = nil, type = "header" },
  { text = L["Enable World Map Menu"],
    default = "1", type = "checkbox", config = "worldmapmenu" },
  { text = L["Enable Minimap Button"],
    default = "1", type = "checkbox", config = "minimapbutton" },
  { text = L["Enable Quest Tracker"],
    default = "1", type = "checkbox", config = "showtracker", onupdate = function()
      if Questie and Questie.LoaderInitialized then
        if pfQuest_config["showtracker"] == "1" then
          Questie.db.profile.trackerEnabled = true
          QuestieLoader:ImportModule("QuestieTracker"):Enable()
        else
          Questie.db.profile.trackerEnabled = false
          local tracker = QuestieLoader:ImportModule("QuestieTracker")
          if tracker and tracker.Disable then
            tracker:Disable()
          end
        end
      end
    end },
  { text = L["Enable Quest Auto Accept"],
    default = "0", type = "checkbox", config = "autoaccept", onupdate = function()
      if Questie and Questie.db and Questie.db.profile then
        Questie.db.profile.autoaccept = pfQuest_config["autoaccept"] == "1"
      end
    end },
  { text = L["Enable Quest Auto Turn-In"],
    default = "0", type = "checkbox", config = "autocomplete", onupdate = function()
      if Questie and Questie.db and Questie.db.profile then
        Questie.db.profile.autocomplete = pfQuest_config["autocomplete"] == "1"
      end
    end },
  { text = L["Auto Accept Daily Quests"],
    default = "0", type = "checkbox", config = "autoacceptdailyonly", onupdate = function()
      if QuestieAuto and QuestieAuto.settings then
        QuestieAuto.settings.dailyOnly = pfQuest_config["autoacceptdailyonly"] == "1"
      end
    end },
  { text = L["Auto Quest Exclusions (comma or newline separated)"],
    default = "", type = "text", config = "autoexclusions", onupdate = function()
      if QuestieAuto and QuestieAuto.SetCustomExclusions then
        QuestieAuto:SetCustomExclusions(pfQuest_config["autoexclusions"] or "")
      end
    end },
  { text = L["Enable Quest Log Buttons"],
    default = "1", type = "checkbox", config = "questlogbuttons" },
  { text = L["Enable Quest Link Support"],
    default = "1", type = "checkbox", config = "questlinks" },
  { text = L["Show Database IDs"],
    default = "0", type = "checkbox", config = "showids" },
  { text = L["Draw Favorites On Login"],
    default = "0", type = "checkbox", config = "favonlogin" },
  { text = L["Minimum Item Drop Chance"],
    default = "1", type = "text", config = "mindropchance" },
  { text = L["Show Tooltips"],
    default = "1", type = "checkbox", config = "showtooltips" },
  { text = L["Show Party Progress On Tooltips"] or "Show Party Progress On Tooltips",
    default = "1", type = "checkbox", config = "tooltippartyprogress", onupdate = function()
      local partySync = QuestieLoader and QuestieLoader.ImportModule and QuestieLoader:ImportModule("QuestiePartySync")
      if partySync and partySync.RefreshFromConfig then
        partySync:RefreshFromConfig()
      end
    end },
  { text = L["Disable Party Progress Yells"] or "Disable Party Progress Yells",
    default = "0", type = "checkbox", config = "disablepartyells", onupdate = function()
      local partySync = QuestieLoader and QuestieLoader.ImportModule and QuestieLoader:ImportModule("QuestiePartySync")
      if partySync and partySync.RefreshFromConfig then
        partySync:RefreshFromConfig()
      end
    end },
  { text = L["Show Help On Tooltips"],
    default = "1", type = "checkbox", config = "tooltiphelp" },
  { text = L["Show Level On Quest Tracker"],
    default = "1", type = "checkbox", config = "trackerlevel" },
  { text = L["Show Level On Quest Log"],
    default = "0", type = "checkbox", config = "questloglevel" },

  { text = L["Questing"],
    default = nil, type = "header" },
  { text = L["Quest Tracker Visibility"],
    default = "0", type = "text", config = "trackeralpha" },
  { text = L["Quest Tracker Font Size"],
    default = "12", type = "text", config = "trackerfontsize", },
  { text = L["Quest Tracker Unfold Objectives"],
    default = "0", type = "checkbox", config = "trackerexpand" },
  { text = L["Enable Quest Focus"] or "Enable Quest Focus",
    default = "0", type = "checkbox", config = "focusenable", onupdate = function()
      local focus = QuestieLoader and QuestieLoader.ImportModule and QuestieLoader:ImportModule("QuestieFocus")
      if focus and focus.RefreshFromConfig then
        focus:RefreshFromConfig()
      end
    end },
  { text = L["Fade Non-Focused Quest Icons"] or "Fade Non-Focused Quest Icons",
    default = "1", type = "checkbox", config = "focusfade", onupdate = function()
      local focus = QuestieLoader and QuestieLoader.ImportModule and QuestieLoader:ImportModule("QuestieFocus")
      if focus and focus.Apply then
        focus:Apply()
      end
    end },
  { text = L["Dim Cluster Nodes While Focused"] or "Dim Cluster Nodes While Focused",
    default = "1", type = "checkbox", config = "focusclusterdim", onupdate = function()
      local focus = QuestieLoader and QuestieLoader.ImportModule and QuestieLoader:ImportModule("QuestieFocus")
      if focus and focus.RefreshFromConfig then
        focus:RefreshFromConfig()
      elseif focus and focus.Apply then
        focus:Apply()
      end
    end },
  { text = L["Highlight Focused Quest Icons"] or "Highlight Focused Quest Icons",
    default = "1", type = "checkbox", config = "focushighlight", onupdate = function()
      local focus = QuestieLoader and QuestieLoader.ImportModule and QuestieLoader:ImportModule("QuestieFocus")
      if focus and focus.RefreshFromConfig then
        focus:RefreshFromConfig()
      elseif focus and focus.Apply then
        focus:Apply()
      end
    end },
  { text = L["Share Quest Focus With Party"] or "Share Quest Focus With Party",
    default = "0", type = "checkbox", config = "focuspartyshare", onupdate = function()
      local focus = QuestieLoader and QuestieLoader.ImportModule and QuestieLoader:ImportModule("QuestieFocus")
      if focus and focus.RefreshFromConfig then
        focus:RefreshFromConfig()
      end
    end },
  { text = L["Show Party Focus Highlights"] or "Show Party Focus Highlights",
    default = "0", type = "checkbox", config = "focuspartyreceive", onupdate = function()
      local focus = QuestieLoader and QuestieLoader.ImportModule and QuestieLoader:ImportModule("QuestieFocus")
      if focus and focus.RefreshFromConfig then
        focus:RefreshFromConfig()
      end
    end },
  { text = L["Stick Durability Frame"] or "Stick Durability Frame",
    default = "0", type = "checkbox", config = "stickydurability", onupdate = function()
      local tracker = QuestieLoader and QuestieLoader.ImportModule and QuestieLoader:ImportModule("QuestieTracker")
      if tracker and tracker.SyncProfileFromConfig then
        tracker:SyncProfileFromConfig()
      end
      if tracker and tracker.UpdateAnchoredFrames then
        tracker:UpdateAnchoredFrames()
      end
    end },
  { text = L["Stick VoiceOver Frame"] or "Stick VoiceOver Frame",
    default = "0", type = "checkbox", config = "stickyvoiceover", onupdate = function()
      local tracker = QuestieLoader and QuestieLoader.ImportModule and QuestieLoader:ImportModule("QuestieTracker")
      if tracker and tracker.SyncProfileFromConfig then
        tracker:SyncProfileFromConfig()
      end
      if tracker and tracker.UpdateAnchoredFrames then
        tracker:UpdateAnchoredFrames()
      end
    end },
  { text = L["Fade Tracker When Idle"] or "Fade Tracker When Idle",
    default = "0", type = "checkbox", config = "trackerfade", onupdate = function()
      local tracker = QuestieLoader and QuestieLoader.ImportModule and QuestieLoader:ImportModule("QuestieTracker")
      if tracker and tracker.SyncProfileFromConfig then
        tracker:SyncProfileFromConfig()
      end
      if tracker and tracker.RefreshFade then
        tracker:RefreshFade()
      end
    end },
  { text = L["Quest Objective Spawn Points (World Map)"],
    default = "1", type = "checkbox", config = "showspawn" },
  { text = L["Quest Objective Spawn Points (Mini Map)"],
    default = "1", type = "checkbox", config = "showspawnmini" },
  { text = L["Quest Objective Icons (World Map)"],
    default = "1", type = "checkbox", config = "showcluster" },
  { text = L["Quest Objective Icons (Mini Map)"],
    default = "0", type = "checkbox", config = "showclustermini" },
  { text = L["Display Available Quest Givers"],
    default = "1", type = "checkbox", config = "allquestgivers" },
  { text = L["Display Current Quest Givers"],
    default = "1", type = "checkbox", config = "currentquestgivers" },
  { text = L["Display Low Level Quest Givers"],
    default = "0", type = "checkbox", config = "showlowlevel" },
  { text = L["Display Level+3 Quest Givers"],
    default = "0", type = "checkbox", config = "showhighlevel" },
  { text = L["Display Event & Daily Quests"],
    default = "0", type = "checkbox", config = "showfestival" },

  { text = L["Map & Minimap"],
    default = nil, type = "header" },
  { text = L["Enable Minimap Nodes"],
    default = "1", type = "checkbox", config = "minimapnodes" },
  { text = L["Use Icons For Tracking Nodes"],
    default = "1", type = "checkbox", config = "trackingicons" },
  { text = L["Use Monochrome Cluster Icons"],
    default = "0", type = "checkbox", config = "clustermono" },
  { text = L["Use Cut-Out Minimap Node Icons"],
    default = "1", type = "checkbox", config = "cutoutminimap" },
  { text = L["Use Cut-Out World Map Node Icons"],
    default = "0", type = "checkbox", config = "cutoutworldmap" },
  { text = L["Color Map Nodes By Spawn"],
    default = "0", type = "checkbox", config = "spawncolors" },
  { text = L["World Map Node Transparency"],
    default = "1.0", type = "text", config = "worldmaptransp" },
  { text = L["Minimap Node Transparency"],
    default = "1.0", type = "text", config = "minimaptransp" },
  { text = L["Node Fade Transparency"],
    default = "0.3", type = "text", config = "nodefade" },
  { text = L["Highlight Nodes On Mouseover"],
    default = "1", type = "checkbox", config = "mouseover" },

  { text = L["Routes"],
    default = nil, type = "header" },
  { text = L["Show Route Between Objects"],
    default = "1", type = "checkbox", config = "routes" },
  { text = L["Include Unified Quest Locations"],
    default = "1", type = "checkbox", config = "routecluster" },
  { text = L["Include Quest Enders"],
    default = "1", type = "checkbox", config = "routeender" },
  { text = L["Include Quest Starters"],
    default = "0", type = "checkbox", config = "routestarter" },
  { text = L["Show Route On Minimap"],
    default = "0", type = "checkbox", config = "routeminimap" },
  { text = L["Show Arrow Along Routes"],
    default = "1", type = "checkbox", config = "arrow" },

  { text = L["User Data"],
    default = nil, type = "header" },
  { text = L["Reset Configuration"],
    default = "1", type = "button", func = reset.config },
  { text = L["Reset Quest History"],
    default = "1", type = "button", func = reset.history },
  { text = L["Reset Cache"],
    default = "1", type = "button", func = reset.cache },
  { text = L["Reset Everything"],
    default = "1", type = "button", func = reset.everything },
}

StaticPopupDialogs["PFQUEST_RESET"] = {
  button1 = YES,
  button2 = NO,
  timeout = 0,
  whileDead = 1,
  hideOnEscape = 1,
}

pfQuestConfig = CreateFrame("Frame", "pfQuestConfig", UIParent)
pfQuestConfig:Hide()
pfQuestConfig:SetWidth(760)
pfQuestConfig:SetHeight(560)
pfQuestConfig:SetPoint("CENTER", 0, 0)
pfQuestConfig:SetFrameStrata("HIGH")
pfQuestConfig:SetMovable(true)
pfQuestConfig:EnableMouse(true)
pfQuestConfig:SetClampedToScreen(true)
pfQuestConfig:RegisterEvent("ADDON_LOADED")
pfQuestConfig:SetScript("OnEvent", function()
  if arg1 == "pfQuest" or arg1 == "pfQuest-tbc" or arg1 == "pfQuest-wotlk" then
    pfQuestConfig:LoadConfig()
    pfQuestConfig:MigrateHistory()
    pfQuestConfig:CreateConfigEntries(pfQuest_defconfig)

    pfQuest_questcache = pfQuest_questcache or {}
    pfQuest_history = pfQuest_history or {}
    pfQuest_colors = pfQuest_colors or {}
    pfQuest_config = pfQuest_config or {}
    pfQuest_track = pfQuest_track or {}
    pfBrowser_fav = pfBrowser_fav or {["units"] = {}, ["objects"] = {}, ["items"] = {}, ["quests"] = {}}

    -- clear quest history on new characters
    if UnitXP("player") == 0 and UnitLevel("player") == 1 then
      pfQuest_history = {}
    end

    if pfBrowserIcon and pfQuest_config["minimapbutton"] == "0" then
      pfBrowserIcon:Hide()
    end
  end
end)

pfQuestConfig:SetScript("OnMouseDown", function()
  this:StartMoving()
end)

pfQuestConfig:SetScript("OnMouseUp", function()
  this:StopMovingOrSizing()
end)

pfQuestConfig:SetScript("OnShow", function()
  this:UpdateConfigEntries()
end)

pfQuestConfig.vpos = 40

pfUI.api.CreateBackdrop(pfQuestConfig, nil, true, 0.75)
table.insert(UISpecialFrames, "pfQuestConfig")

-- detect current addon path
local tocs = { "", "-master", "-tbc", "-wotlk" }
for _, name in pairs(tocs) do
  local current = string.format("pfQuest%s", name)
  local _, title = GetAddOnInfo(current)
  if title then
    pfQuestConfig.path = "Interface\\AddOns\\" .. current
    pfQuestConfig.version = tostring(GetAddOnMetadata(current, "Version"))
    break
  end
end

pfQuestConfig.title = pfQuestConfig:CreateFontString("Status", "LOW", "GameFontNormal")
pfQuestConfig.title:SetFontObject(GameFontWhite)
pfQuestConfig.title:SetPoint("TOP", pfQuestConfig, "TOP", 0, -8)
pfQuestConfig.title:SetJustifyH("LEFT")
pfQuestConfig.title:SetFont(pfUI.font_default, 14)
pfQuestConfig.title:SetText("|cff33ffccpf|rQuest " .. L["Config"])

pfQuestConfig.close = CreateFrame("Button", "pfQuestConfigClose", pfQuestConfig)
pfQuestConfig.close:SetPoint("TOPRIGHT", -5, -5)
pfQuestConfig.close:SetHeight(20)
pfQuestConfig.close:SetWidth(20)
pfQuestConfig.close.texture = pfQuestConfig.close:CreateTexture("pfQuestionDialogCloseTex")
pfQuestConfig.close.texture:SetTexture(pfQuestConfig.path.."\\compat\\close")
pfQuestConfig.close.texture:ClearAllPoints()
pfQuestConfig.close.texture:SetPoint("TOPLEFT", pfQuestConfig.close, "TOPLEFT", 4, -4)
pfQuestConfig.close.texture:SetPoint("BOTTOMRIGHT", pfQuestConfig.close, "BOTTOMRIGHT", -4, 4)

pfQuestConfig.close.texture:SetVertexColor(1,.25,.25,1)
pfUI.api.SkinButton(pfQuestConfig.close, 1, .5, .5)
pfQuestConfig.close:SetScript("OnClick", function()
  this:GetParent():Hide()
end)

pfQuestConfig.welcome = CreateFrame("Button", "pfQuestConfigWelcome", pfQuestConfig)
pfQuestConfig.welcome:SetWidth(160)
pfQuestConfig.welcome:SetHeight(28)
pfQuestConfig.welcome:SetPoint("BOTTOMLEFT", 10, 10)
pfQuestConfig.welcome:SetScript("OnClick", function() pfQuestConfig:Hide(); pfQuestInit:Show() end)
pfQuestConfig.welcome.text = pfQuestConfig.welcome:CreateFontString("Caption", "LOW", "GameFontWhite")
pfQuestConfig.welcome.text:SetAllPoints(pfQuestConfig.welcome)
pfQuestConfig.welcome.text:SetFont(pfUI.font_default, pfUI_config.global.font_size, "OUTLINE")
pfQuestConfig.welcome.text:SetText(L["Welcome Screen"])
pfUI.api.SkinButton(pfQuestConfig.welcome)

pfQuestConfig.save = CreateFrame("Button", "pfQuestConfigReload", pfQuestConfig)
pfQuestConfig.save:SetWidth(160)
pfQuestConfig.save:SetHeight(28)
pfQuestConfig.save:SetPoint("BOTTOMRIGHT", -10, 10)
pfQuestConfig.save:SetScript("OnClick", ReloadUI)
pfQuestConfig.save.text = pfQuestConfig.save:CreateFontString("Caption", "LOW", "GameFontWhite")
pfQuestConfig.save.text:SetAllPoints(pfQuestConfig.save)
pfQuestConfig.save.text:SetFont(pfUI.font_default, pfUI_config.global.font_size, "OUTLINE")
pfQuestConfig.save.text:SetText(L["Save & Close"])
pfUI.api.SkinButton(pfQuestConfig.save)

function pfQuestConfig:LoadConfig()
  if not pfQuest_config then pfQuest_config = {} end
  for id, data in pairs(pfQuest_defconfig) do
    if data.config and not pfQuest_config[data.config] then
      pfQuest_config[data.config] = data.default
    end
  end
end

function pfQuestConfig:MigrateHistory()
  if not pfQuest_history then return end

  local match = false

  for entry, data in pairs(pfQuest_history) do
    if type(entry) == "string" then
      for id in pairs(pfDatabase:GetIDByName(entry, "quests")) do
        pfQuest_history[id] = { 0, 0 }
        pfQuest_history[entry] = nil
        match = true
      end
    elseif data == true then
      pfQuest_history[entry] = { 0, 0 }
    elseif type(data) == "table" and not data[1] then
      pfQuest_history[entry] = { 0, 0 }
    end
  end

  if match == true then
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest|r: " .. L["Quest history migration completed."])
  end
end

local configframes = {}
function pfQuestConfig:CreateConfigEntries(config)
  if self.categories then
    for _, cat in pairs(self.categories) do
      if cat.button then
        cat.button:Hide()
      end
      if cat.frame then
        cat.frame:Hide()
      end
    end
  end

  if self.categoryButtons then
    for _, button in pairs(self.categoryButtons) do
      button:Hide()
    end
  end

  wipe(configframes)

  self.categories = {}
  self.categoryOrder = {}
  self.categoryButtons = {}

  local sidebarWidth = 190

  if not self.sidebar then
    self.sidebar = CreateFrame("Frame", nil, self)
    self.sidebar:SetPoint("TOPLEFT", 10, -40)
    self.sidebar:SetPoint("BOTTOMLEFT", 10, 50)
    self.sidebar:SetWidth(sidebarWidth)
    pfUI.api.CreateBackdrop(self.sidebar, nil, true, 0.5)
  end

  if not self.content then
    self.content = CreateFrame("Frame", nil, self)
    self.content:SetPoint("TOPLEFT", self.sidebar, "TOPRIGHT", 10, 0)
    self.content:SetPoint("BOTTOMRIGHT", -10, 50)
    pfUI.api.CreateBackdrop(self.content, nil, true, 0.5)

    self.scroll = CreateFrame("ScrollFrame", "pfQuestConfigScroll", self.content, "UIPanelScrollFrameTemplate")
    self.scroll:SetPoint("TOPLEFT", 6, -6)
    self.scroll:SetPoint("BOTTOMRIGHT", -26, 6)
    if self.scroll.SetClipsChildren then
      self.scroll:SetClipsChildren(true)
    end

    self.scrollContent = CreateFrame("Frame", nil, self.scroll)
    self.scrollContent:SetPoint("TOPLEFT", 0, 0)
    self.scrollContent:SetWidth(math_max(self.content:GetWidth() - 32, 0))
    self.scrollContent:SetHeight(1)
    self.scroll:SetScrollChild(self.scrollContent)

    self.content:SetScript("OnSizeChanged", function(_, width)
      if not pfQuestConfig.scrollContent then return end
      pfQuestConfig.scrollContent:SetWidth(math_max(width - 32, 0))
    end)
  end

  local DEFAULT_CATEGORY = L["General"] or "General"
  local currentCategory = nil

  for _, data in ipairs(config) do
    if data.type == "header" then
      currentCategory = data.text or DEFAULT_CATEGORY
      if not self.categories[currentCategory] then
        table.insert(self.categoryOrder, currentCategory)
        self.categories[currentCategory] = { entries = {} }
      end
    elseif data.type then
      if not currentCategory then
        currentCategory = DEFAULT_CATEGORY
        if not self.categories[currentCategory] then
          table.insert(self.categoryOrder, currentCategory)
          self.categories[currentCategory] = { entries = {} }
        end
      end
      table.insert(self.categories[currentCategory].entries, data)
    end
  end

  local previousButton = nil
  for _, name in ipairs(self.categoryOrder) do
    local category = self.categories[name]

    local button = CreateFrame("Button", nil, self.sidebar)
    button:SetWidth(sidebarWidth - 20)
    button:SetHeight(26)
    if previousButton then
      button:SetPoint("TOP", previousButton, "BOTTOM", 0, -6)
    else
      button:SetPoint("TOP", self.sidebar, "TOP", 0, -12)
    end
    button.text = button:CreateFontString(nil, "OVERLAY", "GameFontWhite")
    button.text:SetAllPoints(button)
    button.text:SetFont(pfUI.font_default, pfUI_config.global.font_size, "OUTLINE")
    button.text:SetText(name)
    pfUI.api.SkinButton(button)
    button:SetScript("OnClick", function()
      pfQuestConfig:ShowCategory(name)
    end)

    category.button = button
    self.categoryButtons[name] = button
    previousButton = button

    local container = CreateFrame("Frame", nil, self.scrollContent)
    container:SetPoint("TOPLEFT", self.scrollContent, "TOPLEFT", 12, -12)
    container:SetPoint("RIGHT", self.scrollContent, "RIGHT", -12, 0)
    container:Hide()

    category.frame = container
    category.totalHeight = 20

    container.title = container:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    container.title:SetFont(pfUI.font_default, pfUI_config.global.font_size + 2, "OUTLINE")
    container.title:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    container.title:SetText(name)
    container.title:SetJustifyH("LEFT")

    local anchor = container.title
    local spacing = 10
    local rowHeight = 26

    for _, data in ipairs(category.entries) do
      local entryData = data
      local frame = CreateFrame("Frame", nil, container)
      frame:SetHeight(rowHeight)
      frame:SetPoint("LEFT", container, "LEFT", 0, 0)
      frame:SetPoint("RIGHT", container, "RIGHT", 0, 0)
      frame:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -spacing)
      anchor = frame

      frame.caption = frame:CreateFontString(nil, "OVERLAY", "GameFontWhite")
      frame.caption:SetFont(pfUI.font_default, pfUI_config.global.font_size, "OUTLINE")
      frame.caption:SetPoint("LEFT", frame, "LEFT", 0, 0)
      frame.caption:SetPoint("RIGHT", frame, "RIGHT", -180, 0)
      frame.caption:SetJustifyH("LEFT")
      frame.caption:SetText(entryData.text or "")

      if entryData.type == "checkbox" then
        frame.input = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
        frame.input:SetNormalTexture("")
        frame.input:SetPushedTexture("")
        frame.input:SetHighlightTexture("")
        pfUI.api.CreateBackdrop(frame.input, nil, true)
        frame.input:SetWidth(18)
        frame.input:SetHeight(18)
        frame.input:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
        frame.input.config = entryData.config
        if pfQuest_config[entryData.config] == "1" then
          frame.input:SetChecked()
        end
        frame.input:SetScript("OnClick", function()
          if this:GetChecked() then
            pfQuest_config[this.config] = "1"
          else
            pfQuest_config[this.config] = "0"
          end

          if entryData.onupdate then
            entryData.onupdate()
          end

          pfQuest:ResetAll()
        end)
      elseif entryData.type == "text" then
        frame.input = CreateFrame("EditBox", nil, frame)
        frame.input:SetTextColor(.2,1,.8,1)
        frame.input:SetJustifyH("RIGHT")
        frame.input:SetTextInsets(6,6,4,4)
        frame.input:SetWidth(140)
        frame.input:SetHeight(20)
        frame.input:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
        frame.input:SetFontObject(GameFontNormal)
        frame.input:SetAutoFocus(false)
        frame.input:SetScript("OnEscapePressed", function()
          this:ClearFocus()
        end)
        frame.input:SetScript("OnEnterPressed", function()
          this:ClearFocus()
        end)
        frame.input.config = entryData.config
        frame.input:SetText(pfQuest_config[entryData.config])
        frame.input:SetScript("OnTextChanged", function()
          pfQuest_config[this.config] = this:GetText()
          if entryData.onupdate then
            entryData.onupdate()
          end
        end)
        pfUI.api.CreateBackdrop(frame.input, nil, true)
      elseif entryData.type == "button" and entryData.func then
        frame.input = CreateFrame("Button", nil, frame)
        frame.input:SetWidth(120)
        frame.input:SetHeight(20)
        frame.input:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
        frame.input:SetScript("OnClick", entryData.func)
        frame.input.text = frame.input:CreateFontString(nil, "OVERLAY", "GameFontWhite")
        frame.input.text:SetAllPoints(frame.input)
        frame.input.text:SetFont(pfUI.font_default, pfUI_config.global.font_size, "OUTLINE")
        frame.input.text:SetText("OK")
        pfUI.api.SkinButton(frame.input)
      end

      if frame.input and pfUI.api.emulated then
        frame.input:SetWidth(frame.input:GetWidth()/.6)
        frame.input:SetHeight(frame.input:GetHeight()/.6)
        frame.input:SetScale(.8)
        if frame.input.SetTextInsets then
          frame.input:SetTextInsets(8,8,8,8)
        end
      end

      configframes[entryData] = frame
      spacing = 8
      category.totalHeight = category.totalHeight + rowHeight + spacing
    end

    category.totalHeight = category.totalHeight + 10
    category.totalHeight = math_max(category.totalHeight, (self.content and self.content:GetHeight() or 0) - 40)
    container:SetHeight(category.totalHeight)
  end

  if self.categoryOrder[1] then
    self:ShowCategory(self.categoryOrder[1])
  end
end

function pfQuestConfig:UpdateConfigEntries()
  for _, data in ipairs(pfQuest_defconfig) do
    if data.type and configframes[data] and configframes[data].input then
      if data.type == "checkbox" then
        configframes[data].input:SetChecked((pfQuest_config[data.config] == "1" and true or nil))
      elseif data.type == "text" then
        configframes[data].input:SetText(pfQuest_config[data.config])
      end
    end
  end
end

function pfQuestConfig:ShowCategory(name)
  if not self.categories or not self.categories[name] then return end
  if not self.scroll or not self.scrollContent then return end

  for _, categoryName in ipairs(self.categoryOrder) do
    local category = self.categories[categoryName]
    if category and category.frame then
      if categoryName == name then
        category.frame:Show()
        self.scrollContent:SetHeight(category.totalHeight)
        if ScrollFrame_UpdateScrollChildRect then
          ScrollFrame_UpdateScrollChildRect(self.scroll)
        end
        self.scroll:SetVerticalScroll(0)
      else
        category.frame:Hide()
      end
    end

    local button = category and category.button
    if button and button.text then
      if categoryName == name then
        button.text:SetTextColor(.3, 1, .8)
      else
        button.text:SetTextColor(1, 1, 1)
      end
    end
  end

  self.activeCategory = name
end

do -- welcome/init popup dialog
  local config_stage = {
    arrow = 1,
    mode = 2
  }

  local desaturate = function(texture, state)
    local supported = texture:SetDesaturated(state)
    if not supported then
      if state then
        texture:SetVertexColor(0.5, 0.5, 0.5)
      else
        texture:SetVertexColor(1.0, 1.0, 1.0)
      end
    end
  end

  -- create welcome/init window
  pfQuestInit = CreateFrame("Frame", "pfQuestInit", UIParent)
  pfQuestInit:Hide()
  pfQuestInit:SetWidth(400)
  pfQuestInit:SetHeight(270)
  pfQuestInit:SetMovable(true)
  pfQuestInit:EnableMouse(true)
  pfQuestInit:SetPoint("CENTER", 0, 0)
  pfQuestInit:RegisterEvent("PLAYER_ENTERING_WORLD")
  pfQuestInit:SetScript("OnMouseDown", function()
    this:StartMoving()
  end)

  pfQuestInit:SetScript("OnMouseUp", function()
    this:StopMovingOrSizing()
  end)

  pfQuestInit:SetScript("OnEvent", function()
    if pfQuest_config.welcome ~= "1" then
      -- parse current config
      if pfQuest_config["showspawn"] == "0" and pfQuest_config["showcluster"] == "1" then
        config_stage.mode = 1
      elseif pfQuest_config["showspawn"] == "1" and pfQuest_config["showcluster"] == "0" then
        config_stage.mode = 3
      end

      if pfQuest_config["arrow"] == "0" then
        config_stage.arrow = nil
      end

      pfQuestInit:Show()
    end
    this:UnregisterAllEvents()
  end)

  pfQuestInit:SetScript("OnShow", function()
    -- reload ui elements
    desaturate(pfQuestInit[1].bg, true)
    desaturate(pfQuestInit[2].bg, true)
    desaturate(pfQuestInit[3].bg, true)
    desaturate(pfQuestInit[config_stage.mode].bg, false)
    pfQuestInit.checkbox:SetChecked(config_stage.arrow)
  end)

  pfUI.api.CreateBackdrop(pfQuestInit, nil, true, 0.85)

  -- welcome title
  pfQuestInit.title = pfQuestInit:CreateFontString("Status", "LOW", "GameFontWhite")
  pfQuestInit.title:SetPoint("TOP", pfQuestInit, "TOP", 0, -17)
  pfQuestInit.title:SetJustifyH("LEFT")
  pfQuestInit.title:SetText(L["Please select your preferred |cff33ffccpf|cffffffffQuest|r mode:"])

  -- questing mode
  local buttons = {
    { caption = L["Simple Markers"], texture = "\\img\\init\\simple", position = { "TOPLEFT", 10, -40 },
      tooltip = L["Only show cluster icons with summarized objective locations based on spawn points"] },
    { caption = L["Combined"], texture = "\\img\\init\\combined", position = { "TOP", 0, -40 },
      tooltip = L["Show cluster icons with summarized locations and also display all spawn points of each quest objective"] },
    { caption = L["Spawn Points"], texture = "\\img\\init\\spawns", position = { "TOPRIGHT", -10, -40 },
      tooltip = L["Display all spawn points of each quest objective and hide summarized cluster icons."] },
  }

  for i, button in pairs(buttons) do
    pfQuestInit[i] = CreateFrame("Button", "pfQuestInitLeft", pfQuestInit)
    pfQuestInit[i]:SetWidth(120)
    pfQuestInit[i]:SetHeight(160)
    pfQuestInit[i]:SetPoint(unpack(button.position))
    pfQuestInit[i]:SetID(i)

    pfQuestInit[i].bg = pfQuestInit[i]:CreateTexture(nil, "NORMAL")
    pfQuestInit[i].bg:SetWidth(200)
    pfQuestInit[i].bg:SetHeight(200)
    pfQuestInit[i].bg:SetPoint("CENTER", 0, 0)
    pfQuestInit[i].bg:SetTexture(pfQuestConfig.path..button.texture)

    pfQuestInit[i].caption = pfQuestInit:CreateFontString("Status", "LOW", "GameFontWhite")
    pfQuestInit[i].caption:SetPoint("TOP", pfQuestInit[i], "BOTTOM", 0, -5)
    pfQuestInit[i].caption:SetJustifyH("LEFT")
    pfQuestInit[i].caption:SetText(button.caption)

    pfUI.api.SkinButton(pfQuestInit[i])

    pfQuestInit[i]:SetScript("OnClick", function()
      desaturate(pfQuestInit[1].bg, true)
      desaturate(pfQuestInit[2].bg, true)
      desaturate(pfQuestInit[3].bg, true)
      desaturate(pfQuestInit[this:GetID()].bg, false)
      config_stage.mode = this:GetID()
    end)

    local OnEnter = pfQuestInit[i]:GetScript("OnEnter")
    pfQuestInit[i]:SetScript("OnEnter", function()
      if OnEnter then OnEnter() end
      GameTooltip_SetDefaultAnchor(GameTooltip, this)

      GameTooltip:SetText(this.caption:GetText())
      GameTooltip:AddLine(buttons[this:GetID()].tooltip, 1, 1, 1, true)
      GameTooltip:SetWidth(100)
      GameTooltip:Show()
    end)

    local OnLeave = pfQuestInit[i]:GetScript("OnLeave")
    pfQuestInit[i]:SetScript("OnLeave", function()
      if OnLeave then OnLeave() end
      GameTooltip:Hide()
    end)
  end

  -- show arrows
  pfQuestInit.checkbox = CreateFrame("CheckButton", nil, pfQuestInit, "UICheckButtonTemplate")
  pfQuestInit.checkbox:SetPoint("BOTTOMLEFT", 10, 10)
  pfQuestInit.checkbox:SetNormalTexture("")
  pfQuestInit.checkbox:SetPushedTexture("")
  pfQuestInit.checkbox:SetHighlightTexture("")
  pfQuestInit.checkbox:SetWidth(22)
  pfQuestInit.checkbox:SetHeight(22)
  pfUI.api.CreateBackdrop(pfQuestInit.checkbox, nil, true)

  pfQuestInit.checkbox.caption = pfQuestInit:CreateFontString("Status", "LOW", "GameFontWhite")
  pfQuestInit.checkbox.caption:SetPoint("LEFT", pfQuestInit.checkbox, "RIGHT", 5, 0)
  pfQuestInit.checkbox.caption:SetJustifyH("LEFT")
  pfQuestInit.checkbox.caption:SetText(L["Show Navigation Arrow"])
  pfQuestInit.checkbox:SetScript("OnClick", function()
    config_stage.arrow = this:GetChecked()
  end)

  pfQuestInit.checkbox:SetScript("OnEnter", function()
    GameTooltip_SetDefaultAnchor(GameTooltip, this)
    GameTooltip:SetText(L["Navigation Arrow"])
    GameTooltip:AddLine(L["Show navigation arrow that points you to the nearest quest location."], 1, 1, 1, true)
    GameTooltip:SetWidth(100)
    GameTooltip:Show()
  end)

  pfQuestInit.checkbox:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  -- save button
  pfQuestInit.save = CreateFrame("Button", nil, pfQuestInit)
  pfQuestInit.save:SetWidth(100)
  pfQuestInit.save:SetHeight(24)
  pfQuestInit.save:SetPoint("BOTTOMRIGHT", -10, 10)
  pfQuestInit.save.text = pfQuestInit.save:CreateFontString("Caption", "LOW", "GameFontWhite")
  pfQuestInit.save.text:SetAllPoints(pfQuestInit.save)
  pfQuestInit.save.text:SetText(L["Save & Close"])

  pfUI.api.SkinButton(pfQuestInit.save)

  pfQuestInit.save:SetScript("OnClick", function()
    -- write current config
    if config_stage.mode == 1 then
      pfQuest_config["showspawn"] = "0"
      pfQuest_config["showspawnmini"] = "0"
      pfQuest_config["showcluster"] = "1"
      pfQuest_config["showclustermini"] = "1"
    elseif config_stage.mode == 2 then
      pfQuest_config["showspawn"] = "1"
      pfQuest_config["showspawnmini"] = "1"
      pfQuest_config["showcluster"] = "1"
      pfQuest_config["showclustermini"] = "0"
    elseif config_stage.mode == 3 then
      pfQuest_config["showspawn"] = "1"
      pfQuest_config["showspawnmini"] = "1"
      pfQuest_config["showcluster"] = "0"
      pfQuest_config["showclustermini"] = "0"
    end

    if config_stage.arrow then
      pfQuest_config["arrow"] = "1"
    else
      pfQuest_config["arrow"] = "0"
    end

    -- save welcome flag and reload
    pfQuest_config["welcome"] = "1"
    pfQuest:ResetAll()
    pfQuestInit:Hide()
  end)
end
