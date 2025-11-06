# Changelog - pfQuest-Bronzebeard Enhanced

## Recent Updates

### Quest Capture System Integration

**Added:**
- Automated quest capture system for Bronzebeard realm
- Quest capture monitor UI (`/pfquest capture`)
- NPC tracking with accurate Bronzebeard zone coordinates
- Objective location tracking specific to Bronzebeard spawns
- Quest item drop source tracking
- Export functionality for sharing Bronzebeard quest data
- External merger tool integration for permanent storage

**Fixed:**
- Quest objectives now display correctly on map
- Disabled auto-injection to prevent database corruption
- Quest capture now works passively without interfering with core pfQuest-wotlk
- Bronzebeard-specific quest data properly integrated

**Technical:**
- Quest capture saves to SavedVariables with `_BB` suffix to avoid conflicts
- External merger tool properly formats and integrates captured data
- Compatible with pfQuest-wotlk core functionality
- Separate SavedVariables: `pfQuest_CapturedQuests_BB`, `pfQuest_InjectedData_BB`, `pfQuest_CaptureConfig_BB`

### Known Issues
- Auto-injection into pfDB breaks quest objectives (DISABLED by design)
- Use external merger tool to make captured quests permanent

### Usage
1. Play WoW on Bronzebeard - quest capture works automatically
2. Run pfQuest Merger Tool when you close WoW
3. Restart WoW - captured Bronzebeard quests now permanent!

See `QUEST_CAPTURE_SYSTEM.md` for full documentation.

---

## About This Branch

Maintained by XiusTV exclusively for the Bronzebeard realm (Warcraft Reborn/Ascension).

Based on pfQuest 7.0.1 by Shagu with Bronzebeard-specific extensions.

**Support:** [Buy Me A Coffee](https://buymeacoffee.com/xius)

