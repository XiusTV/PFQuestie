# Phase 5 Validation & Benchmark Plan

## Objectives
- Quantify impact of Phase 4 optimizations on memory and CPU usage
- Provide repeatable test scenarios and measurement tooling
- Establish acceptance thresholds before shipping release 0.9

## Metrics & Tools

| Metric | Tool/Command | Notes |
| --- | --- | --- |
| Addon Memory (KB) | `/dump GetAddOnMemoryUsage("pfQuest-wotlk")` | Run after `UpdateAddOnMemoryUsage()`; convert MB = value / 1024 |
| Total Lua Memory | `/dump collectgarbage("count")` | Returns KB of Lua heap; track deltas |
| CPU Profiling (optional) | `/console scriptProfile 1` (reload required) | Use only when needed; disable after capture |
| Frame Time | `/framestack` + third-party (TinyPerf) | Optional; note FPS before/after |

### Automation Macro (in-game)
```
/run UpdateAddOnMemoryUsage(); print("pfQuest Mem:", GetAddOnMemoryUsage("pfQuest-wotlk"), "KB")
/run print("Lua Heap:", collectgarbage("count"), "KB")
```

### External Logging
- Enable WoW combat log logging (`/combatlog`) if tracking CPU spikes due to combat events.
- For long sessions, capture `/eventtrace` snapshots to identify high-frequency events.

## Test Scenarios

| Scenario | Steps | Metrics Captured |
| --- | --- | --- |
| Cold Login | Fresh client start → login character (no map open) | Memory baseline, Lua heap |
| Idle 5 min | Stand in capital city without interaction | Memory drift |
| Map Stress | Open world map, pan across continents, toggle filters | Memory before/after, ensure cache eviction works |
| Questing Loop | Accept 5 quests, complete objectives, turn in | Memory baseline vs post loop, tracker update frequency |
| Extended Play | 30-minute mixed gameplay (travel, combat, questing) | Memory trend (record every 10 min) |
| Capture Disabled | Repeat Extended Play with quest capture off | Compare to base to ensure capture gating works |
| Dual-Addon Check | pfQuest + pfQuest-bronzebeard enabled | Validate memory/CPU overhead when both active |

## Data Recording Template

| Scenario | Time | Addon Memory (KB) | Lua Heap (KB) | Notes |
| --- | --- | --- | --- | --- |
| Cold Login | 00:00 |  |  |  |
| Cold Login (post map) | 00:02 |  |  |  |
| Idle 5 min | 00:05 |  |  |  |
| ... | ... | ... | ... | ... |

Store results in `benchmarks/phase5/YYYY-MM-DD-character.csv` for reproducibility.

## Success Criteria
- Memory reduction ≥ 10% vs Phase 2 baseline in Map Stress + Extended Play scenarios
- No cache growth beyond configured limits after Extended Play
- No new Lua errors or taint logs during scenarios
- Tracker/map performance equal or better (subjective FPS checks)

## Regression Checks
- Repeat scenarios with optimizations toggled off (if feature-flagged) to compare
- Validate quest capture still works when enabled
- Ensure pfQuest-bronzebeard DB merge unaffected by lazy-loading changes

## Next Steps
1. Implement Phase 4 optimizations behind dev flag for A/B testing
2. Execute baseline measurements (current build) & log results
3. Apply optimizations, rerun scenarios, compare metrics
4. Document findings in `benchmarks/PHASE5_RESULTS.md`
