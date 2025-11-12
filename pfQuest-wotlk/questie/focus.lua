---@class QuestieFocus
local QuestieFocus = QuestieLoader:CreateModule("QuestieFocus")

QuestieFocus.activeQuest = QuestieFocus.activeQuest or nil
QuestieFocus.remoteFocusByPlayer = QuestieFocus.remoteFocusByPlayer or {}
QuestieFocus.remoteFocusCounts = QuestieFocus.remoteFocusCounts or {}
QuestieFocus.lastShareState = QuestieFocus.lastShareState or false
QuestieFocus.glowColors = {
  localFocus = { 1, 0.85, 0.2, 0.9 },
  remoteFocus = { 0.35, 0.7, 1, 0.85 },
}

local function ToNumber(val)
  if type(val) == "number" then
    return val
  end
  if type(val) == "string" then
    return tonumber(val)
  end
  return nil
end

local function GetConfig()
  pfQuest_config = pfQuest_config or {}
  return pfQuest_config
end

local function IsEnabledFlag(value, default)
  if value == nil then
    return default
  end
  if type(value) == "boolean" then
    return value
  end
  return tostring(value) == "1"
end

local function ClampAlpha(alpha)
  alpha = tonumber(alpha) or 0
  if alpha < 0 then
    return 0
  end
  if alpha > 1 then
    return 1
  end
  return alpha
end

function QuestieFocus:GetDimAlpha()
  local config = GetConfig()
  if config["focusfade"] == "0" then
    return 0.6
  end
  return 0.25
end

function QuestieFocus:GetRemoteDimAlpha()
  return 0.5
end

function QuestieFocus:IsEnabled()
  local config = GetConfig()
  return config["focusenable"] == "1"
end

function QuestieFocus:IsActive()
  return self:IsEnabled() and self.activeQuest ~= nil
end

function QuestieFocus:ShouldDimClusters()
  local config = GetConfig()
  return IsEnabledFlag(config["focusclusterdim"], true)
end

function QuestieFocus:ShouldHighlight()
  local config = GetConfig()
  return IsEnabledFlag(config["focushighlight"], true)
end

function QuestieFocus:ShouldShareWithParty()
  local config = GetConfig()
  return config["focuspartyshare"] == "1"
end

function QuestieFocus:ShouldReceiveFromParty()
  local config = GetConfig()
  return config["focuspartyreceive"] ~= "0"
end

function QuestieFocus:GetFocusQuest()
  return self.activeQuest
end

function QuestieFocus:IsQuestFocused(questId)
  local active = self.activeQuest
  if not active then
    return false
  end
  local numeric = ToNumber(questId)
  return numeric ~= nil and numeric == active
end

function QuestieFocus:FrameHasFocus(frame)
  if not frame or not self.activeQuest then
    return false
  end
  return FrameQuestMatches(frame, self.activeQuest)
end

function QuestieFocus:FrameHasRemoteFocus(frame)
  if not self:ShouldReceiveFromParty() then return false end
  if not frame or not self:HasRemoteFocus() then return false end
  for questId in pairs(self.remoteFocusCounts) do
    if FrameQuestMatches(frame, questId) then
      return true
    end
  end
  return false
end

function QuestieFocus:EnsureFocusGlow(frame)
  if not frame or frame.focusGlow then
    return
  end

  local basePath = pfQuestConfig and pfQuestConfig.path or "Interface\\AddOns\\pfQuest-wotlk"
  local texturePath = basePath .. "\\img\\track"
  local glow = frame:CreateTexture(nil, "ARTWORK")
  glow:SetTexture(texturePath)
  glow:SetBlendMode("ADD")
  glow:SetPoint("CENTER", frame, "CENTER", 0, 0)
  local baseSize = frame:GetWidth() or frame.defsize or 16
  glow:SetWidth(baseSize + 6)
  glow:SetHeight(baseSize + 6)
  glow:Hide()

  frame.focusGlow = glow
end

function QuestieFocus:UpdateGlow(frame, glowType)
  if not frame or not frame.focusGlow then return end
  if not glowType then
    -- Defer Hide() during combat to avoid secure function errors
    if not (InCombatLockdown and InCombatLockdown()) then
      frame.focusGlow:Hide()
    end
    frame.focusGlowType = nil
    return
  end

  local colorKey = glowType == "remote" and "remoteFocus" or "localFocus"
  local color = self.glowColors[colorKey] or self.glowColors.localFocus
  frame.focusGlow:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
  local size = (frame:GetWidth() or frame.defsize or 16) + 6
  frame.focusGlow:SetWidth(size)
  frame.focusGlow:SetHeight(size)
  -- Show() is safe during combat, only Hide() needs protection
  frame.focusGlow:Show()
  frame.focusGlowType = glowType
end

function QuestieFocus:AdjustFrameAlpha(frame, baseAlpha, context)
  local alpha = ClampAlpha(baseAlpha or frame.defalpha or 1)
  local glowType = nil

  if not self:IsEnabled() then
    return alpha, glowType
  end

  local highlight = context and context.highlight or false
  local isCluster = context and context.cluster or false

  if self:FrameHasFocus(frame) then
    alpha = 1
    glowType = "local"
  elseif not highlight then
    if self:FrameHasRemoteFocus(frame) and not self:IsActive() then
      alpha = math.max(alpha, 0.95)
      glowType = "remote"
    elseif self:ShouldReceiveFromParty() and self:HasRemoteFocus() and not self:IsActive() then
      alpha = math.min(alpha, self:GetRemoteDimAlpha())
    elseif isCluster and not self:ShouldDimClusters() then
      alpha = math.max(alpha, ClampAlpha(frame.defalpha or 1))
    elseif alpha > 0 then
      alpha = math.min(alpha, self:GetDimAlpha())
    end
  end

  return ClampAlpha(alpha), glowType
end

function QuestieFocus:Clear(silent)
  if not self.activeQuest then
    return
  end

  self.activeQuest = nil
  local config = GetConfig()
  config["focusQuestId"] = nil

  if self:ShouldShareWithParty() then
    local partySync = GetPartySync()
    if partySync and partySync.NotifyFocusChange then
      partySync:NotifyFocusChange("clear")
    end
  end

  if not silent then
    self:Apply()
  end
end

function QuestieFocus:SetQuest(questId, silent)
  if not self:IsEnabled() then
    if not silent then
      Questie.Print("Quest focus is disabled. Enable it in the pfQuest configuration to use this feature.")
    end
    return
  end

  local numeric = ToNumber(questId)
  if not numeric then
    return
  end

  if self.activeQuest and self.activeQuest == numeric then
    self:Clear(silent)
    return
  end

  self.activeQuest = numeric
  local config = GetConfig()
  config["focusQuestId"] = tostring(numeric)

  if self:ShouldShareWithParty() then
    local partySync = GetPartySync()
    if partySync and partySync.NotifyFocusChange then
      partySync:NotifyFocusChange("set", numeric)
    end
  end

  if not silent then
    self:Apply()
  end
end

function QuestieFocus:ToggleQuest(questId)
  if self:IsQuestFocused(questId) then
    self:Clear()
  else
    self:SetQuest(questId)
  end
end

function QuestieFocus:OnQuestRemoved(questId)
  if not questId then
    return
  end
  local numeric = ToNumber(questId)
  if numeric and self.activeQuest and self.activeQuest == numeric then
    self:Clear()
  end
end

function QuestieFocus:ApplyFrameStyle(frame)
  if not frame or not frame.SetAlpha then
    return
  end

  local baseAlpha = frame.defalpha or 1
  if frame.texture then
    baseAlpha = 1
  elseif frame.cluster then
    baseAlpha = 1
  end
  if pfMap and pfMap.EnsureFocusGlow then
    pfMap:EnsureFocusGlow(frame)
  end
  self:EnsureFocusGlow(frame)

  local alpha, glowType = self:AdjustFrameAlpha(frame, baseAlpha, {
    highlight = false,
    cluster = frame.cluster,
  })

  frame:SetAlpha(alpha)
  self:UpdateGlow(frame, glowType)
end

function QuestieFocus:Apply()
  if pfMap then
    if WorldMapFrame and WorldMapFrame:IsShown() and pfMap.UpdateNodes then
      pfMap:UpdateNodes()
    end
    if pfMap.UpdateMinimap then
      pfMap:UpdateMinimap()
    end
    pfMap.queue_update = GetTime()
  end

  local tracker = QuestieLoader:ImportModule("QuestieTracker")
  if tracker and tracker.started and tracker.Update then
    tracker:Update()
  end
end

function QuestieFocus:RefreshFromConfig()
  local config = GetConfig()
  if not self:IsEnabled() then
    self:Clear(true)
    self:Apply()
    return
  end

  local saved = ToNumber(config["focusQuestId"])
  self.activeQuest = saved

  local shareEnabled = self:ShouldShareWithParty()
  if shareEnabled ~= self.lastShareState then
    local partySync = GetPartySync()
    if partySync and partySync.NotifyFocusChange then
      if shareEnabled and self.activeQuest then
        partySync:NotifyFocusChange("set", self.activeQuest)
      elseif not shareEnabled then
        partySync:NotifyFocusChange("clear")
      end
    end
    self.lastShareState = shareEnabled
  end

  if not self:ShouldReceiveFromParty() then
    self:ClearAllRemoteFocus()
  end

  self:Apply()
end

function QuestieFocus:Initialize()
  local config = GetConfig()
  local saved = ToNumber(config["focusQuestId"])
  if saved then
    self.activeQuest = saved
  end
  self.lastShareState = self:ShouldShareWithParty()
  if self.lastShareState and self.activeQuest then
    local partySync = GetPartySync()
    if partySync and partySync.NotifyFocusChange then
      partySync:NotifyFocusChange("set", self.activeQuest)
    end
  end
  if not self:ShouldReceiveFromParty() then
    self:ClearAllRemoteFocus()
  end
end

QuestieFocus:Initialize()

local function GetPartySync()
  if not QuestieLoader or not QuestieLoader.ImportModule then return nil end
  return QuestieLoader:ImportModule("QuestiePartySync")
end

local function AdjustRemoteCount(self, questId, delta)
  if not questId then return end
  self.remoteFocusCounts[questId] = (self.remoteFocusCounts[questId] or 0) + delta
  if self.remoteFocusCounts[questId] <= 0 then
    self.remoteFocusCounts[questId] = nil
  end
end

function QuestieFocus:SetRemoteFocus(playerName, questId)
  if not playerName then return end
  local current = self.remoteFocusByPlayer[playerName]
  if current == questId then return end
  if current then
    AdjustRemoteCount(self, current, -1)
  end
  if questId and questId > 0 then
    self.remoteFocusByPlayer[playerName] = questId
    AdjustRemoteCount(self, questId, 1)
  else
    self.remoteFocusByPlayer[playerName] = nil
  end
end

function QuestieFocus:ClearRemoteFocus(playerName)
  self:SetRemoteFocus(playerName, nil)
end

function QuestieFocus:ClearAllRemoteFocus()
  for player, questId in pairs(self.remoteFocusByPlayer) do
    AdjustRemoteCount(self, questId, -1)
    self.remoteFocusByPlayer[player] = nil
  end
end

function QuestieFocus:HasRemoteFocus()
  return next(self.remoteFocusCounts) ~= nil
end

function QuestieFocus:OnRemoteFocusSet(playerName, questId)
  if not self:ShouldReceiveFromParty() then return end
  questId = ToNumber(questId)
  if questId and questId > 0 then
    self:SetRemoteFocus(playerName, questId)
  else
    self:ClearRemoteFocus(playerName)
  end
  self:Apply()
end

function QuestieFocus:OnRemoteFocusClear(playerName)
  self:ClearRemoteFocus(playerName)
  self:Apply()
end

return QuestieFocus

