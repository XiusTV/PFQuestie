local loader = {}

local isLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
local loadAddon = C_AddOns and C_AddOns.LoadAddOn or LoadAddOn

loader.localeAddons = {
  ["deDE"] = "pfQuest-wotlk-locale-deDE",
  ["frFR"] = "pfQuest-wotlk-locale-frFR",
  ["koKR"] = "pfQuest-wotlk-locale-koKR",
  ["ptBR"] = "pfQuest-wotlk-locale-ptBR",
  ["ruRU"] = "pfQuest-wotlk-locale-ruRU",
  ["zhCN"] = "pfQuest-wotlk-locale-zhCN",
  ["zhTW"] = "pfQuest-wotlk-locale-zhTW",
  ["esES"] = "pfQuest-wotlk-locale-esES",
}

loader.localeFallbacks = {
  ["enGB"] = "enUS",
  ["esMX"] = "esES",
  ["ptPT"] = "ptBR",
}

loader.loaded = {}

function loader:Ensure(locale)
  if not locale then return false end

  if locale == "enUS" then
    self.loaded[locale] = true
    return true
  end

  if self.loaded[locale] then
    return true
  end

  local target = self.localeAddons[locale]
  if not target then
    local fallback = self.localeFallbacks[locale]
    if fallback then
      if fallback == "enUS" then
        self.loaded[locale] = true
        return true
      end
      target = self.localeAddons[fallback]
    end
  end

  if not target then
    self.loaded[locale] = false
    return false
  end

  if isLoaded and isLoaded(target) then
    self.loaded[locale] = true
    return true
  end

  if not loadAddon then
    self.loaded[locale] = false
    return false
  end

  local success, reason = loadAddon(target)
  if success then
    self.loaded[locale] = true
    return true
  end

  self.loaded[locale] = false

  if reason and DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff33ffccpfQuest:|r Failed to load locale addon |cffff5555%s|r (%s)", target, tostring(reason)))
  end

  return false
end

function loader:EnsureCurrent()
  local locale = GetLocale()
  if not locale then return end

  if not self:Ensure(locale) then
    local fallback = self.localeFallbacks[locale]
    if fallback and fallback ~= locale then
      self:Ensure(fallback)
    end
  end
end

pfQuestLocaleLoader = loader
pfQuestLocaleLoader:EnsureCurrent()

