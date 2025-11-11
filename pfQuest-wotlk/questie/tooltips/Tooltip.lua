---@class QuestieTooltips
local QuestieTooltips = QuestieLoader:CreateModule("QuestieTooltips")
QuestieTooltips.private = QuestieTooltips.private or {}

QuestieTooltips.lookupByKey = QuestieTooltips.lookupByKey or {}
QuestieTooltips.lookupKeysByQuestId = QuestieTooltips.lookupKeysByQuestId or {}

function QuestieTooltips:RegisterObjectiveTooltip(questId, key, objectiveData)
  if not questId or not key or not objectiveData then return end

  local questKey = tostring(questId)

  self.lookupByKey[key] = self.lookupByKey[key] or {}
  self.lookupKeysByQuestId[questKey] = self.lookupKeysByQuestId[questKey] or {}

  local bucket = self.lookupByKey[key][questKey]
  if bucket then
    if bucket.lines and objectiveData.lines then
      local existing = {}
      for _, line in ipairs(bucket.lines) do
        existing[line] = true
      end
      for _, line in ipairs(objectiveData.lines) do
        if not existing[line] then
          table.insert(bucket.lines, line)
        end
      end
    elseif objectiveData.lines and not bucket.lines then
      bucket.lines = { unpack(objectiveData.lines) }
    end
  else
    self.lookupByKey[key][questKey] = objectiveData
  end

  self.lookupKeysByQuestId[questKey][key] = true
end

function QuestieTooltips:RemoveQuest(questId)
  if not questId then return end

  local questKey = tostring(questId)
  local keys = self.lookupKeysByQuestId[questKey]
  if not keys then return end

  for key in pairs(keys) do
    local bucket = self.lookupByKey[key]
    if bucket then
      bucket[questKey] = nil
      if not next(bucket) then
        self.lookupByKey[key] = nil
      end
    end
  end

  self.lookupKeysByQuestId[questKey] = nil
end

function QuestieTooltips:GetTooltip(key)
  return self.lookupByKey[key]
end

return QuestieTooltips

