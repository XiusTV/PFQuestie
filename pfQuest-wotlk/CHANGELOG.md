# Changelog - pfQuest Enhanced

## Recent Updates

### Quest Capture System Integration

**Added:**
- Automated quest capture system that learns new quests as you play
- Quest capture monitor UI (`/pfquest capture`)
- NPC tracking with accurate zone ID detection
- Objective location tracking
- Quest item drop source tracking
- Export functionality for sharing captured data
- External merger tool integration for permanent storage

**Fixed:**
- Quest objectives now display correctly on map
- Disabled auto-injection to prevent database corruption
- Quest capture now works passively without interfering with core functionality
- Per-character quest history properly isolated
- Resizable quest tracker with bottom-right corner grip

**Technical:**
- Quest capture saves to SavedVariables only (no live injection)
- External merger tool properly formats and integrates captured data
- Proper objective structures created by merger
- Quest tracking mode safety checks (handles string/number values)

### Known Issues
- Auto-injection into pfDB breaks quest objectives (DISABLED by design)
- Use external merger tool to make captured quests permanent

### Usage
1. Play WoW - quest capture works automatically
2. Run pfQuest Merger Tool when you close WoW
3. Restart WoW - captured quests now permanent!

See `QUEST_CAPTURE_SYSTEM.md` for full documentation.

---

## Previous Versions

Based on pfQuest 7.0.1 by Shagu
- Original quest database and core functionality
- Database from VMaNGOS and CMaNGOS projects

