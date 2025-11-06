# Quest Capture System - Bronzebeard

## Overview

The quest capture system for pfQuest-Bronzebeard automatically records quest data as you play on the Bronzebeard realm (Warcraft Reborn).

## How It Works

### In-Game Capture (Automatic)
1. Accept a new quest
2. System automatically captures:
   - Quest giver NPC location (with accurate zone ID)
   - Quest details (title, description, objectives)
   - Quest level and class restrictions
3. As you complete objectives:
   - Tracks where you kill monsters
   - Records object interaction locations
   - Monitors quest item drop sources
4. When you turn in quest:
   - Captures turn-in NPC location
   - Records reward data

### External Merger (Makes It Permanent)
1. Close WoW
2. Merger tool automatically extracts captured data
3. Generates proper database files
4. Next login: quests available for all characters!

## Installation

**Required:**
- pfQuest-bronzebeard addon (this folder)
- pfQuest-Tools merger (in `Interface\pfQuest-Tools\`)

**Setup:**
1. Both folders should already be in place
2. Go to: `Interface\pfQuest-Tools\dist\`
3. Run: `pfQuest Merger Tool.exe`
4. Configure paths in Settings (should auto-detect)
5. Click "Start Monitoring"
6. Done! Play WoW normally

## Commands

```
/pfquest capture          - Open capture monitor UI
/pfquest capture scan     - Scan quest log
/pfquest capture export   - Export as Lua
/pfquest capture clear    - Clear captured data
/pfquest capture status   - Show status
```

## Why No Auto-Injection?

Auto-injection was breaking quest objectives from showing on the map. The external merger tool is the **correct** approach:

### Previous Approach (Broken)
- ❌ Live injection into pfDB during gameplay
- ❌ Broke quest objective display
- ❌ Corrupted database structure

### Current Approach (Working)
- ✅ Passive capture to SavedVariables
- ✅ External tool properly formats data
- ✅ Quest objectives work perfectly
- ✅ Captured quests persist properly

## Workflow

### Daily Use
1. **Start merger tool** (one-time setup, keeps running)
2. **Play WoW** - accept and complete quests
3. **Close WoW** - merger auto-processes data
4. **Restart WoW** - captured quests now permanent!

### Viewing Captured Data
- Open monitor: `/pfquest capture`
- View captured quests in real-time
- See what's been recorded
- Export to share with others

### Sharing Contributions
1. Export captured quests: `/pfquest capture export`
2. Copy Lua code from export window
3. Share on Discord/GitHub
4. Help build the Bronzebeard quest database!

## Technical Notes

### SavedVariables
Captured data is stored in:
- `WTF\Account\[Account]\SavedVariables\pfQuest-bronzebeard.lua`

### Database Files
Merged data is written to:
- `AddOns\pfQuest-bronzebeard\db\captured\quests.lua`
- `AddOns\pfQuest-bronzebeard\db\captured\units.lua`

### Per-Character History
Quest completion is tracked per-character in:
- `WTF\Account\[Account]\[Realm]\[Character]\SavedVariables\pfQuest-bronzebeard.lua`

This ensures quests you've completed on one character still show as available on other characters.

## Support

For issues with:
- **Quest Capture System**: Open issue on XiusTV's repository
- **Original pfQuest**: See [Shagu's pfQuest](https://github.com/shagu/pfQuest)

---

**Maintained by XiusTV for Bronzebeard realm**

