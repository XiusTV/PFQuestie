World of Warcraft 3.3.5 (WotLK) Addons by XiusTV:

- [ElvUI VibeUI](https://github.com/XiusTV/Elvui-VibeUI)
- [PFQuest-WotLK](https://github.com/XiusTV/PFQuest-Wotlk)
- [pfQuest-BronzeBeard](https://github.com/XiusTV/pfQuest-BronzeBeard)
- [WarcraftEnhanced](https://github.com/XiusTV/WarcraftEnhanced)

Support: [Buy Me A Coffee](https://buymeacoffee.com/xius)

---

# pfQuest-BronzeBeard Enhanced

**Server-specific quest database extension for the Bronzebeard realm on Warcraft Reborn with automated quest capture system.**

## About This Branch

This is a **custom fork maintained exclusively by XiusTV** for the Ascension/Warcraft Reborn Bronzebeard realm. This branch includes server-specific quest data, custom NPC spawns, and specialized database overrides for WoW 3.3.5.

**⚠️ This is an independent project.** The original pfQuest developers (Shagu and contributors) are not involved with this branch.

## 🌟 Enhanced Features

### Quest Capture System
This version includes an **automated quest learning system**:

- ✅ **Automatic quest detection** - Captures quest data when you accept new quests
- ✅ **NPC tracking** - Records quest giver and turn-in NPC locations with accurate zone IDs
- ✅ **Objective tracking** - Monitors where you complete quest objectives
- ✅ **Quest item sources** - Tracks which NPCs drop quest items
- ✅ **Reward data** - Captures quest rewards and choice rewards
- ✅ **Export functionality** - Generate Lua database files from captured quests
- ✅ **External merger tool** - Permanently integrates captured data into addon database

### What is pfQuest-BronzeBeard?

An extension of pfQuest that provides accurate quest and spawn data specifically for the Bronzebeard realm, including:

- Custom quest locations and objectives
- Server-specific NPC spawn points
- Bronzebeard realm database overrides
- Automated quest capture for missing quests
- Compatibility with WotLK 3.3.5 client

## Installation

1. Download the latest release or clone this repository
2. Extract to `Wow-Directory\Interface\AddOns\pfQuest-bronzebeard`
3. Restart WoW
4. Type `/db show` to open the database browser

## Commands

### Basic Commands
- `/db show` - Open the quest database browser
- `/db object [name]` - Search for objects/NPCs
- `/db quest [name]` - Search for quests
- `/db item [name]` - Search for items

### Quest Capture Commands
- `/pfquest capture` - Open quest capture monitor UI
- `/pfquest capture scan` - Scan quest log for new quests
- `/pfquest capture export` - Export captured quests as Lua
- `/pfquest capture clear` - Clear all captured quest data
- `/pfquest capture status` - Show capture system status

## External Merger Tool

The quest capture system saves data to SavedVariables but **does not auto-inject** (to prevent breaking quest objectives). To make captured quests permanent:

1. Navigate to `Interface\pfQuest-Tools\dist\`
2. Run `pfQuest Merger Tool.exe` (or use Python version in `Merger Via CMD\`)
3. Click "Start Monitoring"
4. Play WoW - capture quests normally
5. When you close WoW, the tool automatically merges captured data into the addon database
6. Next time you load WoW, captured quests are available for all characters!

This approach ensures captured quests are properly integrated without corrupting the quest objective system.

## Requirements

- World of Warcraft 3.3.5 (WotLK)
- Bronzebeard realm (Warcraft Reborn)

## Credits

**This Branch:**
- Developed and maintained by **XiusTV**

**Original pfQuest:**
- Created by **Shagu** - [Original pfQuest Repository](https://github.com/shagu/pfQuest)
- Database contributions from VMaNGOS and CMaNGOS projects

This project uses the pfQuest framework created by Shagu. All Bronzebeard-specific data and modifications are by XiusTV.

## License

This addon follows the same license as the original pfQuest project.

---

**For issues specific to this Bronzebeard branch, please open an issue on this repository.**

