pfQuest = pfQuest or {}

local function GetQuestieTracker()
  if not QuestieLoader or not QuestieLoader.ImportModule then
    return nil
  end
  return QuestieLoader:ImportModule("QuestieTracker")
end

local trackerAdapter = {}
trackerAdapter.__isStub = true

function trackerAdapter.Reset() end
function trackerAdapter.ButtonAdd(_) end

local function setConfigShowTracker(value)
  if pfQuest_config then
    pfQuest_config["showtracker"] = value and "1" or "0"
  end
end

function trackerAdapter:Show()
  setConfigShowTracker(true)
  local questieTracker = GetQuestieTracker()
  if questieTracker and questieTracker.Enable then
    questieTracker:Enable()
  end
end

function trackerAdapter:Hide()
  setConfigShowTracker(false)
  local questieTracker = GetQuestieTracker()
  if questieTracker and questieTracker.Disable then
    questieTracker:Disable()
  end
end

pfQuest.tracker = trackerAdapter

return trackerAdapter
