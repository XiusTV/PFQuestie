# Phase 3 Cleanup Plan

## Legacy Module Inventory

| Component | Location | Status | Notes | Proposed Action |
| --- | --- | --- | --- | --- |
| Quest Browser UI | `pfQuest-wotlk/browser.lua` | Active | Still referenced via `/db show` and favorites; heavy table ops but functional | Keep for now; audit data caching later |
| Quest Journal UI | `pfQuest-wotlk/journal.lua` | Active | Slash command `/db journal`; duplicates browser logic | Keep; consider merging with browser for DRYness |
| Route drawing | `pfQuest-wotlk/route.lua` | Active | Tied to `routes` config; used by map/path routines | Keep; optimize only after profiling |
| Legacy tracker stub | `pfQuest-wotlk/tracker.lua` | Stub shim | Provides compatibility API (`Reset`, `ButtonAdd`, `Show/Hide`) but now no-ops | Evaluate removal once map code stops calling stub |
| Old tracker references | `pfQuest-wotlk/map.lua` | Active | Still calls `pfQuest.tracker.Reset/ButtonAdd`; ensures old API satisfied | Replace with Questie tracker adapter or prune calls |
| Quest capture system | `pfQuest-wotlk/questcapture*.lua` | Active | Used for data gathering exports; expensive runtime watchers | Keep but gate behind config toggle? review performance |
| Bronzebeard quest capture | `pfQuest-bronzebeard/questcapture*.lua` | Duplicate | Mirrors main addon capture module | Deduplicate: load shared module from pfQuest-wotlk |
| Bronzebeard update announcer | `pfQuest-bronzebeard/pfQuest-bronzebeard.lua` | Legacy | Sends chat addon version pings each login/party | Consider removing to reduce chat spam |
| Documentation artifacts | `Documentation/`, `INTEGRATION_*.md` | Static | Dev references only | Optionally move to docs folder or package outside release |

## Candidate Removals / Consolidation

- **Quest capture duplication**: unify capture logic in core addon; Bronzebeard consumes shared module.
- **Legacy tracker shim**: once map callbacks migrate to Questie tracker, remove stub and dead calls.
- **Bronzebeard version pings**: remove `pfqb` chat spam module unless still required for community update checks.

## Tracker Stub Analysis (Phase 3)

### References to `pfQuest.tracker` API

| Location | Call | Purpose | Status | Action |
| --- | --- | --- | --- | --- |
| `map.lua:1024` | `pfQuest.tracker.Reset()` | Called when updating map nodes | **No-op** | Remove call (tracker doesn't need map reset) |
| `map.lua:1063` | `pfQuest.tracker.ButtonAdd(title, node)` | Called in loop to populate quest list from map pins | **No-op** | Remove call (QuestieTracker reads from `pfQuest.questlog` directly) |
| `slashcmd.lua:274` | `pfQuest.tracker:Show()` | `/db tracker` command | **Functional** | Migrate to call `QuestieTracker:Enable()` directly |
| `tracker.lua:38` | `pfQuest.tracker = trackerAdapter` | Defines stub API | Legacy shim | Remove after map/slashcmd migration |

### Analysis

**Why `Reset()` and `ButtonAdd()` are no-ops:**
- `Reset()`: The stub implementation is empty (`function trackerAdapter.Reset() end`)
- `ButtonAdd()`: The stub implementation is empty (`function trackerAdapter.ButtonAdd(_) end`)
- These were part of the old tracker system that manually populated from map node data

**Why they're not needed:**
- QuestieTracker reads directly from `pfQuest.questlog` (see `questie/tracker/core.lua:1119-1120`)
- The quest log is updated by `quest.lua` from actual quest log events
- Map nodes don't need to manually populate the tracker anymore

**Migration Plan:**
1. Remove `pfQuest.tracker.Reset()` call from `map.lua:1024` (no replacement needed)
2. Remove `pfQuest.tracker.ButtonAdd(title, node)` loop from `map.lua:1063` (no replacement needed)
3. Migrate `slashcmd.lua:274` to call QuestieTracker directly:
   ```lua
   -- Old:
   if pfQuest.tracker then pfQuest.tracker:Show() end
   
   -- New:
   local tracker = QuestieLoader and QuestieLoader.ImportModule and QuestieLoader:ImportModule("QuestieTracker")
   if tracker and tracker.Enable then tracker:Enable() end
   ```
4. After migration, delete `tracker.lua` entirely (no longer needed)

**Estimated Impact:**
- Removes ~40 lines of dead code
- Eliminates 2 redundant function calls per map update
- Simplifies codebase by removing legacy compatibility layer

## Next Steps

1. ✅ Audit embedded libraries (Phase 3 libs task) - **COMPLETE**
2. ✅ Identify obsolete config toggles/migrations - **COMPLETE**
3. ✅ Verify tracker integration can shed stub (map code updates required) - **COMPLETE**

**Phase 3 Status**: Ready for cleanup implementation

## Embedded Library Audit

| Library | Path | Observed Usage | Notes | Recommendation |
| --- | --- | --- | --- | --- |
| `LibStub`, `CallbackHandler-1.0` | `Libs/` | Required by all other embedded libs | Core dependency; minimal footprint | Keep |
| `AceAddon-3.0`, `AceEvent-3.0`, `AceConsole-3.0`, `AceTimer-3.0` | `Libs/AceAddon-3.0`, etc. | Used via `compat/questie-loader.lua` to wrap `Questie` into an Ace addon; timers/events leveraged by `questie/party/sync.lua` | Actively used by Questie integration | Keep |
| `AceComm-3.0`, `AceSerializer-3.0` | `Libs/AceComm-3.0`, `Libs/AceSerializer-3.0` | Imported in `questie/party/sync.lua` for sync payloads | Required for party sync MVP | Keep |
| `AceHook-3.0`, `AceBucket-3.0`, `AceTab-3.0` | `Libs/` | Exposed via `pfQuestAce`, but no in-repo usages yet | Idle baggage; could be removed or lazy loaded once confident | Candidate for removal after verification |
| `AceDB-3.0`, `AceDBOptions-3.0` | `Libs/` | Not yet referenced; future profile migration only | Provides profile scaffolding once Questie options land | Defer until config merge; consider lazy load |
| `AceGUI-3.0`, `AceConfig-3.0`, `AceGUI-SharedMediaWidgets`, `LibSharedMedia-3.0` | `Libs/` | Only touched by dev helper `Libs/Ace3.lua`; addon UI currently custom | High footprint; unused in live code | Plan to drop unless Questie options port needs them |
| `LibDataBroker-1.1`, `LibDBIcon-1.0` | `Libs/` | No LDB object creation in pfQuest; only dependency chain inside `LibDBIcon` | Safe to remove if minimap icon not planned | Mark for removal |
| `LibUIDropDownMenu-4.0` | `Libs/LibUIDropDownMenu/` | Library not referenced or loaded in `.toc`; Blizzard dropdown API meets needs | Dead weight | Remove |
| `HereBeDragons*-2.0` | `Libs/HereBeDragons/` | Not listed in `.toc`; Questie map not yet ported | Keep packaged for future Questie map integration but defer loading | Lazy load when Questie map work starts |
| `Krowi_WorldMapButtons` | `Libs/Krowi_WorldMapButtons/` | Not loaded or referenced | Legacy copy; unused | Remove |

### Library Cleanup Actions

- Remove unused packages (`LibDataBroker-1.1`, `LibDBIcon-1.0`, `LibUIDropDownMenu`, `Krowi_WorldMapButtons`) after double-checking no external addons rely on them.
- Convert optional Ace modules (`AceHook`, `AceBucket`, `AceTab`, `AceGUI`, `AceConfig`, `AceDB*`) to lazy-load stubs, only embedding when Questie options/profile work begins.
- Keep `HereBeDragons` staged but add loader gate so it doesn’t inflate load time until map integration.

## Configuration Audit (Phase 3)

| Key | Source Section | Active Usage | Notes | Action |
| --- | --- | --- | --- | --- |
| `trackingmethod` | Questing | `quest.lua` (map button + queue filters) | Legacy 4-mode tracking still in use; value 4 disables givers | Keep |
| `minimapbutton` | General | Checked in `config.lua` to hide pfBrowser icon | Depends on LibDBIcon removal; revisit after icon decision |
| `enableQuestieMenu` | General | `slashcmd.lua` bypasses `/db menu` when disabled | Keep for now; optional UX toggle |
| `showids` | General | Tooltip handlers show DB IDs | Keep |
| `favonlogin` | General | `browser.lua` auto-draw favorites | Keep |
| `mindropchance` | General | `database.lua` filters low drop nodes | Keep |
| `showtracker` + tracker fades | Questing | Questie tracker core uses them | Keep |
| `focus*` toggles | Questing | Questie focus module and tracker lines | Keep |
| `autoaccept*`, `autocomplete`, `autoexclusions` | Questing | `questie/auto/core.lua` + profile sync | Keep |
| `questlinks`, `enableQuestLinks`, `questLinkTooltip` | Quest Links | `compat/client.lua`, `questie/questlinks.lua` | Keep |
| `showgiverpaths` | Questing | `database.lua` + `map.lua` path drawing | Keep |
| `tooltippartyprogress`, `QuestiePartySync` toggles | Questing | `questie/party/sync.lua` | Keep |
| `trackerlevel`, `questloglevel`, `questlogbuttons` | Questing | `quest.lua` UI toggles | Keep |
| `nameplateEnabled`, `nameplateIconScale` | Questing | `questie/nameplate.lua` | Keep |
| Announce (`announceQuest*`, sounds) | Announce | `questie/announce.lua`, `questie/sounds.lua` | Keep |
| Map & Minimap toggles | Map | `map.lua`, `database.lua`, `quest.lua` | Keep |
| Route toggles | Routes | `route.lua`, `map.lua` | Keep |
| `continentPins`, `continentClickThrough`, `continentNodeSize`, `continentUtilityNodeSize` | Map & Minimap | `pfQuest-worldmap.lua` extension | Keep |
| `bronzebeardHide*`, `bronzebeardContinentPins` | Added by Bronzebeard | Legacy copies migrated to new keys | Mark for removal after migration window |
| `translate` | Browser UI | `quest.lua` language button | Keep |

### Legacy Migration Helpers

- `MigrateLegacyBronzebeardConfig` (pfQuest) and `CopyLegacyConfigValues` (pfQuest-bronzebeard): still required for users upgrading from extensions. Mark for future removal once release notes announce cutoff.
- Bronzebeard-only config entries (`bronzebeardHide*`, `bronzebeardContinentPins`) now redundant since new keys exist. Plan to remove from defaults and rely solely on modern names after next major release.

### Unused / Candidate Keys

No config entries were found without runtime references. Monitor once focus UX lands to ensure no dead toggles appear.
