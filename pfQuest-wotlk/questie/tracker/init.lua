local Tracker = QuestieLoader:ImportModule("QuestieTracker")

if Questie and Questie.db and Questie.db.profile and Questie.db.profile.trackerEnabled then
  Tracker:Initialize()
end

