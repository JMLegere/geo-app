# Persistence Layer Documentation Index

Complete analysis of the Flutter app's persistence architecture, data flows, and repository pattern.

---

## Documents

### 1. **PERSISTENCE_ARCHITECTURE.md** (36 KB)
**Comprehensive reference for the entire persistence layer.**

**Sections:**
- Executive Summary
- Database Schema (10 tables, detailed field definitions)
- Repository Pattern (6 repositories with full CRUD operations)
- Riverpod Provider Wiring
- Data Flow Diagrams (5 complete flows)
- Write Queue Lifecycle
- SupabasePersistence API
- Conditional Supabase Configuration
- Persistence Consumer Functions
- Hydration from Supabase
- Denormalization Strategy
- Performance Optimizations
- Error Handling
- Observability
- Testing Patterns
- Known Limitations
- Future Work

**Best for:** Deep understanding, implementation details, API reference

---

### 2. **PERSISTENCE_QUICK_REFERENCE.md** (12 KB)
**Quick lookup guide for common tasks and patterns.**

**Sections:**
- The Golden Rule (SQLite first, then queue)
- 6 Repositories at a Glance (table format)
- Data Flow: Discovery → Sync
- Data Flow: Startup Hydration
- Write Queue Lifecycle (4 phases)
- Conditional Supabase (when configured vs. not)
- Denormalization: Why?
- Performance Optimizations (table format)
- Error Handling (table format)
- Observability (structured events + debug logs)
- Testing (integration test patterns)
- Checklist: Adding a New Entity Type (8 steps)
- Key Files (9 files with purposes)
- Constants (3 constants)
- Gotchas (8 critical gotchas)

**Best for:** Quick lookup, debugging, adding new features

---

### 3. **PERSISTENCE_ENTITY_FLOWS.md** (24 KB)
**Complete lifecycle for each entity type.**

**Sections:**
- Item Instance (creation → persistence → sync → hydration → display)
- Cell Progress (creation → persistence → sync → hydration → display)
- Player Profile (creation → persistence → sync → hydration → display)
- Cell Properties (creation → persistence → sync → hydration → display)
- Summary Table
- Key Principles (8 principles)

**Best for:** Understanding specific entity types, tracing data flow end-to-end

---

## Quick Navigation

### By Task

| Task | Document | Section |
|------|----------|---------|
| Understand overall architecture | ARCHITECTURE | Executive Summary |
| Look up a repository | QUICK_REFERENCE | 6 Repositories at a Glance |
| Trace item discovery flow | ENTITY_FLOWS | Item Instance |
| Debug persistence error | QUICK_REFERENCE | Error Handling |
| Add a new entity type | QUICK_REFERENCE | Checklist: Adding a New Entity Type |
| Understand write queue | ARCHITECTURE | Write Queue Lifecycle |
| Understand hydration | ENTITY_FLOWS | Summary Table |
| Understand Supabase sync | ARCHITECTURE | SupabasePersistence API |
| Optimize performance | ARCHITECTURE | Performance Optimizations |
| Set up observability | ARCHITECTURE | Observability |
| Write tests | ARCHITECTURE | Testing Patterns |

### By Role

**Backend Engineer (Supabase)**
1. Read ARCHITECTURE: SupabasePersistence API
2. Read ARCHITECTURE: Write Queue Lifecycle
3. Read ENTITY_FLOWS: All entity flows
4. Reference QUICK_REFERENCE: Gotchas

**Frontend Engineer (Flutter)**
1. Read QUICK_REFERENCE: The Golden Rule
2. Read QUICK_REFERENCE: 6 Repositories at a Glance
3. Read ENTITY_FLOWS: Relevant entity flows
4. Reference QUICK_REFERENCE: Checklist for new features

**QA / Tester**
1. Read ARCHITECTURE: Testing Patterns
2. Read ARCHITECTURE: Error Handling
3. Read QUICK_REFERENCE: Gotchas
4. Reference ENTITY_FLOWS: Data flows to test

**DevOps / Observability**
1. Read ARCHITECTURE: Observability
2. Read ARCHITECTURE: Error Handling
3. Read QUICK_REFERENCE: Constants
4. Reference ARCHITECTURE: Known Limitations

---

## Key Concepts

### The Golden Rule
**All writes go to SQLite first. Only after SQLite succeeds do we enqueue for Supabase.**

This prevents corrupt payloads from reaching the server if the local write fails.

### Server-Authoritative, Offline-First
- **SQLite** = local cache + offline write queue
- **Supabase** = source of truth (when configured)
- **Write Queue** = deferred sync outbox

### 6 Repositories
1. **ItemInstanceRepository** — items (CRUD)
2. **CellProgressRepository** — cell visits (CRUD)
3. **ProfileRepository** — player profile (CRUD)
4. **WriteQueueRepository** — sync outbox (CRUD)
5. **CellPropertyRepository** — cell properties (CRUD)
6. **HierarchyRepository** — geographic hierarchy (CRUD)

### Data Flow Pattern
```
Entity Created
  ↓
SQLite Write (via Repository)
  ↓
Write Queue Enqueue (only if SQLite succeeds)
  ↓
Auto-Flush (5s debounce)
  ↓
Supabase Upsert (via SupabasePersistence)
  ↓
On Success: Delete Queue Entry
On Rejection: Mark Rejected + Rollback (items only)
```

### Hydration Pattern
```
Phase 1: SQLite → Providers (fast, ~200ms)
  ├─ itemRepo.getItemsByUser() → itemsProvider.loadItems()
  ├─ cellProgressRepo.readByUser() → fogResolver.loadVisitedCells()
  ├─ profileRepo.read() → playerProvider.loadProfile()
  └─ cellPropertyRepo.getAll() → coordinator.loadCellProperties()

Phase 2: Supabase → SQLite (background, non-blocking)
  ├─ persistence.fetchProfile() → profileRepo.create()
  ├─ persistence.fetchCellProgress() → cellProgressRepo.create() [batch]
  ├─ persistence.fetchItemInstances() → itemRepo.upsertItem() [batch]
  ├─ persistence.fetchSpeciesUpdates() → db.updateSpeciesEnrichment() [batch]
  ├─ persistence.fetchCellProperties() → cellPropertyRepo.upsert() [batch]
  └─ persistence.fetchHierarchy() → hierarchyRepo.upsert*() [batch]

Phase 3: Start Game Loop
  └─ coordinator.start(gpsStream, discoveryStream)
```

---

## Critical Design Decisions

1. **SQLite first, then queue** — Prevents corrupt payloads from reaching server
2. **Payload uses current DB values** — Avoids stale defaults if write is delayed
3. **Rejection rollback is item-only** — Items rolled back locally, cell progress/profile are not
4. **Hydration doesn't re-hydrate providers** — Phase 2 runs in background, avoids race with discoveries
5. **Cell properties are globally shared** — No userId in SQLite, but write queue needs userId for routing
6. **Denormalization is one-way** — Item instances snapshot species data at discovery, server changes don't propagate
7. **Batching prevents UI jank** — Hydration yields every 50 rows, cell properties batch 5 writes
8. **Debouncing prevents hammering SQLite** — Profile writes debounced to 5s, avoids blocking on iOS IndexedDB

---

## Database Schema Overview

### Core Tables (6)
- `LocalCellProgressTable` — per-user cell visits
- `LocalItemInstanceTable` — unique discovered items (60 columns with denormalization)
- `LocalPlayerProfileTable` — player stats & streaks
- `LocalSpeciesTable` — IUCN species + enrichment (32,752 rows)
- `LocalWriteQueueTable` — offline sync outbox
- `LocalCellPropertiesTable` — geo-derived cell data (globally shared)

### Hierarchy Tables (4)
- `LocalCountryTable` — 195 countries
- `LocalStateTable` — ~5,000 states/provinces
- `LocalCityTable` — ~30,000 cities
- `LocalDistrictTable` — ~500,000 districts

---

## Performance Optimizations

| Optimization | Where | Why |
|--------------|-------|-----|
| Write serialization | Web (IndexedDB) | Prevent concurrent writes (ConstraintError) |
| Batched persistence | Cell properties (5 per batch) | iOS IndexedDB: 10–15ms per write, batch yields prevent jank |
| Debounced profile | Profile state (5s debounce) | Accumulate rapid changes, avoid hammering SQLite |
| Lazy hydration | Startup (Phase 1 + Phase 2) | Get player to map immediately, Supabase fetch in background |
| Yield every 50 rows | Hydration loops | Prevent blocking UI during bulk upserts |

---

## Conditional Supabase

### When Configured
```dart
await Supabase.initialize(url: ..., anonKey: ...);
```
- Full sync + hydration enabled
- Write queue auto-flushes every 5s
- Supabase is source of truth

### When NOT Configured
```dart
// SupabaseConfig.url or SupabaseConfig.anonKey is empty
```
- Offline-only mode
- Write queue entries created but never flushed
- SQLite is the only persistence layer

---

## Error Handling

| Error | Handling | Result |
|-------|----------|--------|
| SQLite write fails | Log + return (don't enqueue) | Item not persisted, not queued |
| Enqueue fails | Log (item already persisted) | Item in SQLite but not queued (won't sync) |
| Sync network error | Increment attempts, retry up to 5x | Retryable, eventually marked rejected |
| Sync validation rejection | Mark rejected immediately | Trigger local rollback (for items) |
| Hydration fails | Log + mark hydrated + start loop | App continues with empty state |

---

## Observability

### Structured Events (→ `app_logs` table)
```dart
obs.event('sqlite_slow', {'operation': 'persist_item', 'duration_ms': 150});
obs.event('persistence_error', {'operation': 'persist_item', 'entity_id': '...', 'error': '...'});
obs.event('sync_flushed', {'confirmed': 5, 'rejected': 1, 'retried': 2, 'stale_deleted': 0});
obs.event('sqlite_hydration_complete', {'user_id': '...', 'item_count': 42, 'cell_count': 100});
```

### Debug Logs (→ `app_logs` table)
```dart
debugPrint('[GameCoordinator] failed to persist item: $e');
debugPrint('[QueueProcessor] auto-flush complete: $summary');
debugPrint('[GameCoordinator] hydrating from Supabase for $userId...');
```

---

## Testing

### Integration Tests
**File:** `test/integration/player_hydration_test.dart`

**Coverage:**
- Hydration from SQLite
- Item discovery persistence
- Cell visit persistence
- Profile state persistence
- Write queue enqueue/flush
- Rejection rollback

### Offline Hydration Tests
**File:** `test/integration/offline_hydration_test.dart`

**Coverage:**
- Hydration without Supabase
- Item persistence in offline mode
- Write queue behavior when Supabase not configured

---

## Key Files

| File | Purpose |
|------|---------|
| `lib/core/database/app_database.dart` | Drift ORM schema + queries |
| `lib/core/persistence/*.dart` | 6 repositories |
| `lib/core/state/game_coordinator_provider.dart` | Orchestration + hydration + persistence wiring |
| `lib/core/state/persistence_consumer.dart` | Persistence helper functions |
| `lib/features/sync/services/supabase_persistence.dart` | Supabase API wrapper |
| `lib/features/sync/services/queue_processor.dart` | Write queue flush logic |
| `lib/features/sync/providers/sync_provider.dart` | Sync UI state + rejection processing |
| `test/integration/player_hydration_test.dart` | Hydration tests |
| `test/integration/offline_hydration_test.dart` | Offline mode tests |

---

## Constants

| Constant | Value | File |
|----------|-------|------|
| `kWriteQueueAutoFlushDelaySeconds` | 5 | `lib/shared/constants.dart` |
| `kMaxQueueRetries` | 5 | `lib/shared/constants.dart` |
| `kDailySeedGraceHours` | 24 | `lib/shared/constants.dart` |

---

## Gotchas

1. **FogState is computed, not stored.** Only `visitedCellIds` are persisted. Never write per-cell fog state to the database.

2. **cellsObserved is computed, not stored.** Derived from cell progress count (observed + hidden fog states), not from profile.

3. **Cell properties are globally shared.** No userId in SQLite table. Write queue still needs userId for routing.

4. **Denormalization is one-way.** Item instances snapshot species data at discovery time. Server-side enrichment changes don't propagate to existing items.

5. **Rejection rollback is item-only.** Cell progress and profile are not rolled back locally (server is authoritative).

6. **Hydration doesn't re-hydrate providers.** Phase 2 (Supabase) runs in background without updating providers (avoids race with in-flight discoveries).

7. **Write queue entries are never auto-deleted.** Stale cleanup must be called manually (not yet scheduled).

8. **Supabase is optional.** App runs in offline-only mode if credentials are missing. Write queue entries are created but never flushed.

---

## Checklist: Adding a New Entity Type

1. **Add table to `AppDatabase`**
2. **Create repository**
3. **Create provider**
4. **Add write queue entity type**
5. **Create persistence function**
6. **Wire in gameCoordinatorProvider**
7. **Add Supabase fetch/upsert**
8. **Add hydration**

See QUICK_REFERENCE.md for detailed steps.

---

## Known Limitations

| Limitation | Impact | Workaround |
|-----------|--------|-----------|
| No delta-sync watermark for species | Full species sync on every hydration | Acceptable (32k rows, ~500 enriched) |
| No stale entry cleanup scheduled | Write queue grows unbounded | Manual cleanup via `deleteStale()` |
| No conflict resolution for concurrent edits | Last write wins | Server is authoritative (next sync reconciles) |
| Denormalization not auto-updated | Stale enrichment on item instances | Enrichment only changes server-side (rare) |
| No encryption for SQLite | Sensitive data readable on device | Acceptable for game data (no PII) |

---

## Future Work

- [ ] Implement scheduled stale entry cleanup
- [ ] Add delta-sync watermark for species (avoid full sync)
- [ ] Implement conflict resolution for concurrent edits
- [ ] Add encryption for SQLite (sensitive data)
- [ ] Implement selective re-enrichment (use version stamps)
- [ ] Add sync progress UI (% complete, ETA)
- [ ] Implement resumable uploads for large payloads
- [ ] Add compression for write queue payloads

---

## How to Use This Documentation

### For Understanding the System
1. Start with PERSISTENCE_QUICK_REFERENCE.md: The Golden Rule
2. Read PERSISTENCE_ARCHITECTURE.md: Executive Summary
3. Read PERSISTENCE_ENTITY_FLOWS.md: Summary Table
4. Deep dive into specific sections as needed

### For Debugging
1. Check PERSISTENCE_QUICK_REFERENCE.md: Gotchas
2. Check PERSISTENCE_QUICK_REFERENCE.md: Error Handling
3. Trace the relevant entity flow in PERSISTENCE_ENTITY_FLOWS.md
4. Reference PERSISTENCE_ARCHITECTURE.md for detailed API

### For Adding Features
1. Read PERSISTENCE_QUICK_REFERENCE.md: Checklist: Adding a New Entity Type
2. Reference PERSISTENCE_ENTITY_FLOWS.md: Key Principles
3. Follow the pattern from an existing entity type
4. Test with integration tests (see PERSISTENCE_ARCHITECTURE.md: Testing Patterns)

### For Performance Tuning
1. Read PERSISTENCE_ARCHITECTURE.md: Performance Optimizations
2. Check PERSISTENCE_QUICK_REFERENCE.md: Performance Optimizations
3. Profile with observability (see PERSISTENCE_ARCHITECTURE.md: Observability)
4. Reference PERSISTENCE_ARCHITECTURE.md: Known Limitations

---

## Document Statistics

| Document | Size | Lines | Sections |
|----------|------|-------|----------|
| PERSISTENCE_ARCHITECTURE.md | 36 KB | 2,500+ | 20+ |
| PERSISTENCE_QUICK_REFERENCE.md | 12 KB | 400+ | 15+ |
| PERSISTENCE_ENTITY_FLOWS.md | 24 KB | 1,000+ | 10+ |
| **Total** | **72 KB** | **3,900+** | **45+** |

---

## Last Updated

2026-04-02

## Status

Complete (Phases 1–4 implemented)
