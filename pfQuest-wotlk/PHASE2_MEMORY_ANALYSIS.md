# Phase 2: Memory Hotspot Assessment

## Executive Summary

This document identifies memory usage hotspots, data-heavy systems, potential memory leaks, and caching patterns in `pfQuest-wotlk` and `pfQuest-bronzebeard`. The analysis is based on code review and identifies areas for optimization.

---

## 1. Baseline Memory Measurement Plan

### Recommended Measurement Points

Use `/script print(GetAddOnMemoryUsage("pfQuest-wotlk"))` and `/script print(GetAddOnMemoryUsage("pfQuest-bronzebeard"))` at the following points:

1. **Initial Load**: After login, before any quest interaction
2. **After Quest Log Scan**: After initial quest log population
3. **After Map Interaction**: After opening world map with nodes rendered
4. **After Extended Play**: After 30+ minutes of gameplay
5. **After Zone Changes**: After traveling between multiple zones

### Expected Memory Footprint (Estimated)

- **pfQuest-wotlk**: ~15-25 MB (base) + ~5-10 MB (after map usage)
- **pfQuest-bronzebeard**: ~2-5 MB (database patches)

---

## 2. Data-Heavy Systems

### 2.1 Static Database Files (`db/*.lua`)

**Location**: `pfQuest-wotlk/db/` + `pfQuest-bronzebeard/db/`

**Memory Impact**: **HIGH** (10-15 MB estimated)

**Structure**:
- Global tables: `items`, `quests`, `objects`, `units`, `zones`, `professions`, `areatrigger`, `refloot`
- Localized overlays: `enUS`, `deDE`, `frFR`, `esES`, `ruRU`, `koKR`, `zhCN`, `zhTW`, `ptBR`
- Each locale contains: `items`, `objects`, `professions`, `quests`, `units`, `zones`
- Expansion variants: `-tbc` suffix files for TBC data

**Findings**:
- All database files load at addon initialization via `init/*.xml` manifests
- Entire database structure stored in `pfDB` global table
- Locale-specific files loaded based on `GetLocale()` but all languages may be parsed during load
- No lazy loading - all quest/NPC/item data loaded regardless of whether player needs it

**Optimization Opportunities**:
- [ ] **Conditional locale loading**: Only load player's locale + `enUS` fallback
- [ ] **Lazy zone loading**: Load zone data only when player enters that zone
- [ ] **Database compression**: Consider using more compact data structures (arrays vs keyed tables)
- [ ] **Split TBC data**: Load TBC tables only if player is in TBC zones or client version requires it

### 2.2 Questlog State Tables

**Location**: `pfQuest-wotlk/quest.lua`

**Memory Impact**: **LOW-MEDIUM** (~1-2 MB)

**Structure**:
```lua
pfQuest.questlog = {}      -- Active quest state
pfQuest.questlog_tmp = {}  -- Temporary scan buffer
pfQuest.queue = {}         -- Update queue
```

**Findings**:
- Questlog tables use flip-flop pattern (`questlog_flip` / `questlog_flop`) to avoid allocation during updates
- Queue table cleared after processing (`pfQuest.queue[id] = nil`)
- Temporary questlog cleared after each scan (`pfQuest.questlog_tmp[k] = nil`)
- Tables properly cleaned, but could accumulate abandoned quests if not detected

**Potential Issues**:
- Quest log may retain quests that were abandoned if `REMOVE` events missed
- Queue could grow if processing lags (unlikely but possible)

**Optimization Opportunities**:
- [ ] Add periodic cleanup to verify questlog matches actual quest log state
- [ ] Cap queue size with fallback to full refresh if queue exceeds threshold

---

## 3. Memory Leak Candidates

### 3.1 Indefinitely Growing Caches

#### `cache` in `database.lua` (getcluster function)

**Location**: `pfQuest-wotlk/database.lua:35-68`

**Issue**: **HIGH RISK** - Cache grows indefinitely with no cleanup

```lua
local cache, cacheindex = {}
local function getcluster(tbl, name)
  cacheindex = string.format("%s:%s", name, table.getn(tbl))
  if not cache[cacheindex] then
    -- ... expensive computation ...
    cache[cacheindex] = { tbl[best.index][1] + .001, tbl[best.index][2] + .001, count }
  end
  return cache[cacheindex][1], cache[cacheindex][2], cache[cacheindex][3]
end
```

**Problem**: 
- Cache key format: `"tablename:size"`
- Each unique table size creates a new cache entry
- Cache never cleared, grows with each unique search pattern
- No size limit or LRU eviction

**Estimated Growth**: 
- Could accumulate 100-500 entries after extended play
- Each entry ~32 bytes = ~3-16 KB (small but grows indefinitely)

**Optimization**:
- [ ] **Add cache size limit**: Cap at 100 entries with LRU eviction
- [ ] **Periodic cleanup**: Clear cache on zone change or after X minutes
- [ ] **Use weak table**: `setmetatable(cache, {__mode = "k"})` if references allow

#### `levcache` in `database.lua` (levenshtein distance)

**Location**: `pfQuest-wotlk/database.lua:79-140`

**Issue**: **HIGH RISK** - Cache grows indefinitely with no cleanup

```lua
local levcache = {}
local function lev(str1, str2, limit)
  if levcache[str1..":"..str2] then
    return levcache[str1..":"..str2]
  end
  -- ... expensive computation ...
  levcache[str1..":"..str2] = cost
  return cost
end
```

**Problem**:
- Cache key: concatenated string `str1..":"..str2`
- Each unique string pair creates a new cache entry
- No limit or cleanup mechanism
- String concatenation creates temporary strings (GC pressure)

**Estimated Growth**:
- Could accumulate 1000+ entries during heavy search usage
- Each entry ~24 bytes + string keys = ~50-100 KB or more

**Optimization**:
- [ ] **Add cache size limit**: Cap at 500 entries with LRU eviction
- [ ] **Hash-based key**: Use numeric hash instead of string concatenation
- [ ] **Periodic cleanup**: Clear cache after search operations complete

### 3.2 Map Rendering Caches

#### `rgbcache` in `map.lua`

**Location**: `pfQuest-wotlk/map.lua:39`

**Issue**: **LOW RISK** - Uses weak table, but could still accumulate

```lua
local rgbcache = setmetatable({},{__mode="kv"})
```

**Analysis**: Uses weak table (`__mode="kv"`), so entries are garbage collected when keys/values are no longer referenced. However, if color strings are kept in memory elsewhere (e.g., quest names), cache entries persist.

**Optimization**:
- [ ] **Monitor growth**: Track cache size and add limit if growth observed
- [ ] **Precompute common colors**: Cache default quest colors at load time

#### `unifiedcache` and `similar_nodes` in `map.lua`

**Location**: `pfQuest-wotlk/map.lua:59-64`

**Issue**: **MEDIUM RISK** - Could accumulate node metadata

```lua
local unifiedcache = {}
local similar_nodes = {}
```

**Analysis**: These store combined metadata across map nodes to avoid duplication. Growth depends on number of unique quest/NPC/object combinations rendered.

**Potential Issues**:
- Grows with each unique quest giver/NPC/object combination
- Not cleared when map updates or zone changes
- Could accumulate stale data if quests complete

**Optimization**:
- [ ] **Clear on zone change**: Reset caches when player changes zones
- [ ] **Clear on quest log update**: Invalidate when quest state changes
- [ ] **Use weak references**: If possible, allow GC to clean up unused entries

### 3.3 Tracker Frame Pools

**Location**: `pfQuest-wotlk/questie/tracker/core.lua:531-664`

**Issue**: **LOW-MEDIUM RISK** - Frames should be recycled, but could leak

**Structure**:
```lua
TrackerLinePool.lines = {}              -- Pool of available line frames
TrackerLinePool.inUse = {}              -- Currently displayed lines
TrackerLinePool.itemButtons = {}        -- Pool of item button frames
TrackerLinePool.itemButtonsInUse = {}   -- Currently displayed buttons
TrackerLinePool.pendingCombatButtons = {} -- Buttons waiting for combat end
```

**Analysis**: Frame pooling is good practice, but potential issues:

1. **`pendingCombatButtons`**: Could accumulate if player stays in combat for extended periods
2. **Leaked frames**: If frames aren't properly released back to pool
3. **Frame creation**: If pool empties, new frames are created (could accumulate over time)

**Findings**:
- `ReleaseAll()` properly moves frames back to pool
- `ProcessPendingButtonReleases()` handles combat-safe cleanup
- However, if combat lock persists, `pendingCombatButtons` could grow

**Optimization**:
- [ ] **Cap pool size**: Limit maximum pool size to prevent unbounded growth
- [ ] **Force release after combat**: Clear `pendingCombatButtons` queue after extended combat
- [ ] **Monitor pool growth**: Track pool sizes to detect leaks

---

## 4. Caching Strategy Analysis

### 4.1 Effective Caching Patterns

✅ **Good**: 
- Frame pooling in tracker (reuses UI elements)
- Questlog flip-flop pattern (avoids allocations)
- Weak tables for map caches (`rgbcache`, `validmaps`)

### 4.2 Problematic Caching Patterns

❌ **Bad**:
- Indefinitely growing caches (`cache`, `levcache`)
- No cache size limits
- No cache invalidation strategies
- String concatenation for cache keys (GC pressure)

### 4.3 Recommendations

1. **Implement LRU cache**: Create reusable LRU cache utility with size limits
2. **Add cache metrics**: Track cache hit rates and sizes for monitoring
3. **Periodic cleanup**: Add timer-based cleanup for long-lived caches
4. **Zone-based invalidation**: Clear caches on zone changes where appropriate

---

## 5. Summary of Memory Issues

| Issue | Severity | Estimated Impact | Priority |
|-------|----------|------------------|----------|
| Static database loading (all locales) | **HIGH** | 10-15 MB | P1 |
| `levcache` indefinite growth | **MEDIUM** | 50-100 KB+ | P2 |
| `cache` indefinite growth (getcluster) | **LOW** | 3-16 KB | P3 |
| Map caches not cleared on zone change | **MEDIUM** | Variable | P2 |
| Tracker frame pool growth | **LOW** | ~1-5 KB per frame | P3 |
| Queue accumulation risk | **LOW** | Minimal if working correctly | P4 |

**Priority Legend**:
- **P1**: High impact, should address soon
- **P2**: Medium impact, address if time permits
- **P3**: Low impact, address if optimization pass
- **P4**: Monitoring only, likely not an issue

---

## 6. Next Steps

1. **Immediate Actions** (Phase 3):
   - Add cache size limits to `cache` and `levcache`
   - Implement cache cleanup on zone changes
   - Add monitoring/logging for cache growth

2. **Short-term Optimizations** (Phase 4):
   - Lazy-load locale data (only player locale + enUS)
   - Clear map caches on quest log updates
   - Cap tracker frame pool sizes

3. **Long-term Optimizations** (Future):
   - Consider database compression
   - Implement LRU cache utility
   - Add memory profiling hooks for runtime monitoring

---

**Generated**: Phase 2 Memory Hotspot Assessment
**Status**: Ready for Phase 3 (Legacy Code & Library Cleanup)
