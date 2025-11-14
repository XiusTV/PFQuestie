World of Warcraft 3.3.5 (WotLK) Addons by XiusTV:

- [ElvUI VibeUI](https://github.com/XiusTV/Elvui-VibeUI)
- [PFQuest-WotLK](https://github.com/XiusTV/PFQuest-Wotlk)
- [pfQuest-BronzeBeard](https://github.com/XiusTV/pfQuest-BronzeBeard)
- [WarcraftEnhanced](https://github.com/XiusTV/WarcraftEnhanced)

Support: [Buy Me A Coffee](https://buymeacoffee.com/xius)

---

# pfQuest-Bronzebeard Enhanced

**Server-specific quest database extension for the Bronzebeard realm on Warcraft Reborn, built on the modern pfQuest Enhanced WotLK fork.**

## About This Branch

This branch bundles all pfQuest Enhanced upgrades (a Questie-integrated tracker, durability/VoiceOver anchoring, enhanced quest links, auto questing, map improvements, and party sync utilities) together with Bronzebeard-only database overrides so Ascension players get a single drop-in package for WotLK 3.3.5.\[1\]

**⚠️ Independent maintenance notice.** The original pfQuest maintainers (Shagu and contributors) are not involved with this realm-specific distribution.

## 🌟 Key Features

- **Questie-style tracker** with quest focus controls, inline quest items, configurable idle fade, and a resize handle so the tracker looks and feels like Questie while running on pfQuest data.\[1\]
- **Enhanced quest links** that inject difficulty colors, safe chat truncation, and tooltips so sharing quests in chat is more reliable.\[1\]
- **Quest giver patrol paths & map overlays** so you can see roaming NPC routes directly in the world map when the database supports it.\[1\]
- **Auto questing toolkit** with accept/turn-in, daily-only mode, exclusion lists, and quest log utilities to streamline repeat runs.\[1\]
- **Party sync & tooltip upgrades** via the Questie-style party module, providing progress hints for grouped players.\[1\]
- **Bronzebeard-specific database layer** that ships custom NPC spawns, zone coordinates, and quest metadata required for the Ascension realm.

## Installation

1. Download the latest release or clone this repository.
2. Copy the folders `pfQuest-wotlk` and `pfQuest-bronzebeard` into `World of Warcraft\Interface\AddOns\`.
3. Restart WoW and enable both addons on the character select screen.
4. Use `/pfq config` or `/pfquest config` to open the configuration UI, and `/db show` to open the database browser.

## Commands

- `/pfq config` – Open the redesigned configuration interface.
- `/db show` – Launch the database browser.
- `/db object [name]`, `/db quest [name]`, `/db item [name]` – Search for specific entities.
- `/pfquest tracker` – Toggle the Questie-style tracker.

## Requirements

- World of Warcraft 3.3.5a client.
- Bronzebeard realm (Warcraft Reborn / Ascension).

## Credits

**This Branch**
- Maintained by **XiusTV** with Bronzebeard-specific overrides and QA.

**Upstream pfQuest Enhanced**
- Based on **pfQuest** by **Shagu** with modernization by the PFQuestie project.\[1\]
- Database contributions from the VMaNGOS and CMaNGOS projects.

## License

This addon follows the same license as the upstream pfQuest project.

---

**Need help?** Ping the XiusTV community on Discord or open an issue in this repository.

[1]: https://github.com/XiusTV/PFQuestie

