# Phase 4 Optimization Plan

## Goals
- Reduce runtime memory footprint without sacrificing features
- Trim redundant CPU work (map refreshes, tracker updates)
- Prepare for Phase 5 benchmarks (measure impact)

## Prioritized Targets

| Area | Issue | Optimization Strategy | Notes |
| --- | --- | --- | --- |
| Static DB Loading | All locale DBs load eagerly (~15MB) | Lazy-load locale DBs; only load player locale + enUS fallback | Requires toc/XML adjustments; add loader that fetches locale table on demand |
| Map Node Caches | `map.lua` caches (unifiedcache/similar_nodes) never reset | Add zone-change + questlog-change invalidation; consider weak tables | Reduces long-play memory usage |
| Cluster/Levenshtein cache | `database.lua` `cache` & `levcache` grow unbounded | Implement LRU cache wrapper with max entries; flush on logout | Key to preventing long sessions from ballooning memory |
| Tracker Updates | `QuestieTracker:Update()` runs after every quest log tick | Ensure update throttle + combat queue already implemented; add `QuestieCombatQueue` gating | Evaluate further deferral of expensive rebuilds |
| Quest Capture | Capture frames hook many events | Gate capture module behind config; disable if not capturing | Bronzebeard + core capture duplicates |
| Bronzebeard Legacy Config | Dual config keys require migrations every load | Set cutoff date & drop `bronzebeard*` keys then remove migrations | Simplifies config tables |
| Embedded Libraries | Unused libs (LDB, dropdown, worldmap buttons) | Remove packaged copies; update toc | Shrinks addon size/load time |

## Cache Strategy

1. Implement generic LRU cache helper (`Cache:Create(maxEntries)`) and use for:
   - `database.lua` cluster cache (size 200)
   - `database.lua` levenshtein cache (size 500)
2. Add zone-change / questlog-change hooks to clear map caches (`unifiedcache`, `similar_nodes`).
3. Provide `/pfq cache clear` command to flush caches on demand.

## DB Loading Roadmap

1. Split `init/*.xml` to conditionally include locale files based on `GetLocale()`.
2. Provide fallback loader that loads enUS strings if requested locale missing.
3. Optionally chunk large DB tables (zones, units) to defer until first query.

## UI/CPU Micro-Optimizations

- Remove tracker stub & related map calls (Phase 3 follow-up) to reduce per-update loops.
- Ensure `pfQuest:UpdateQuestlog()` short-circuits when queue empty.
- Replace repeated `GetNumSkillLines()` loops with cached values (only recalc on skill change).
- Defer world map refresh when map closed (`pfMap:UpdateNodes()` guard).

## Validation Prep (Phase 5)

- Define baseline addon memory (Phase 2 data) for comparison.
- Prepare test scenarios: login, map open/close, zone change, 30 min gameplay.
- Set up `/dump GetAddOnMemoryUsage("pfQuest-wotlk")` + `collectgarbage("count")` scripts.

## Next Steps
1. ✅ Implement cache utility and wire into `database.lua`. *(2025-11-14)*
2. ✅ Add cache invalidation triggers for map caches. *(2025-11-14)*
3. ✅ Prototype locale lazy-loading (start with optional build flag). *(2025-11-14)*
4. ✅ Remove unused libraries from toc & package. *(2025-11-14)*
5. ✅ Prepare measurement script for Phase 5. *(2025-11-14)*
