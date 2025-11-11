# Changelog - PFQuestie Enhanced

All notable changes to the PFQuestie suite will be documented in this file.

---

## [Unreleased] - 2024-12

### Added - Questie Integration

#### Questie Tracker
- **Modern quest tracker UI** - Replaced pfQuest tracker with Questie-style tracker
- **Resize handle** - Drag bottom-right corner to resize tracker
- **Quest level display** - Shows quest level next to quest name
- **Quest log integration** - Click quests in tracker to open quest log
- **Default tracker suppression** - Automatically hides Blizzard's default tracker when enabled
- **Sticky frames** - Durability alerts and VoiceOver UI anchor to tracker

#### Questie Tooltips
- **Enhanced tooltips** - Quest objectives, progress, and metadata in tooltips
- **Party progress display** - See party members' quest progress in tooltips
- **Quest ID display** - Optional quest ID display in tooltips
- **Map node tooltips** - World map and minimap nodes show quest information

#### Quest Focus Feature
- **Focus quests** - Left-click tracker quests to focus them
- **Dim non-focused icons** - Map icons dim when a quest is focused
- **Highlight focused icons** - Focused quest icons glow and scale up
- **Party focus sharing** - Share focused quest with party members
- **Persistent focus** - Focus state survives reloads

#### Auto Questing
- **Auto-accept quests** - Automatically accept quests from NPCs
- **Auto-turn-in quests** - Automatically turn in completed quests
- **Daily-only mode** - Option to only auto-accept daily quests
- **Exclusion list** - Configure quests to never auto-accept
- **Modifier override** - Hold modifier key to bypass auto-questing

#### Party Progress Synchronization
- **Real-time sync** - Quest progress updates sent within 1 second
- **Tooltip integration** - Party progress appears in tooltips when hovering NPCs
- **Quest ID matching** - Works even when NPC IDs differ between clients
- **Automatic expiration** - Remote progress expires after 3 minutes
- **Yell fallback** - Works outside groups using `/yell` channel
- **Roster handshake** - Full sync when party roster changes

### Added - Configuration Panel

- **ElvUI-style layout** - Two-pane configuration with sidebar navigation
- **Category sidebar** - Click category names on the left to navigate
- **Scrollable content** - Options displayed in scrollable right pane
- **Real-time updates** - Most settings apply immediately without reload
- **Integrated callbacks** - `onupdate` callbacks sync settings with Questie modules

### Fixed

- **GUID parsing** - Fixed GUID parsing for Wrath client format
- **Key matching** - Fixed tooltip key matching (m_ vs o_ prefixes)
- **Quest ID lookup** - Added fallback quest ID lookup when keys don't match
- **Party sync messages** - Fixed missing sub-prefix in update messages
- **Config panel errors** - Fixed `SetClipsChildren` error on Wrath client
- **Map icon display** - Fixed alpha values causing icons to disappear
- **Quest registration** - Improved quest registration and qlogid tracking
- **Tooltip hooks** - Fixed tooltip hooks not firing on hover

### Changed

- **Update frequency** - Local updates batched with 1-second delay
- **Remote TTL** - Remote entries expire after 180 seconds (3 minutes)
- **Debug messages** - Reduced debug spam, only shows when debug mode enabled
- **Config structure** - Rebuilt config panel to use two-pane layout
- **Quest tracking** - Integrated Questie tracker as default tracker

### Technical

- **Ace3 libraries** - Bundled Ace3 libraries with compatibility shims
- **QuestieLoader** - Custom module loader for Questie-style modules
- **Dynamic library loading** - Ace libraries loaded dynamically at runtime
- **Wrath compatibility** - Fixed addon communication for Wrath (no RegisterAddonMessagePrefix)
- **Serializer handling** - Fixed AceSerializer return value handling
- **Event throttling** - Added throttling to QUEST_LOG_UPDATE events

---

## Previous Versions

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

---

## Based on pfQuest 7.0.1

- Original quest database and core functionality
- Database from VMaNGOS and CMaNGOS projects
- Core framework by Shagu

---

*For detailed integration progress, see `pfQuest-wotlk/INTEGRATION_PROGRESS.txt`*
