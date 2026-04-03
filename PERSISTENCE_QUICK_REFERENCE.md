# Persistence Layer — Quick Reference

## The Golden Rule

**All writes go to SQLite first. Only after SQLite succeeds do we enqueue for Supabase.**

This prevents corrupt payloads from reaching the server if the local write fails.

---

## 6 Repositories at a Glance

| Repository | Table | Key Methods | Called By |
|------------|-------|-------------|-----------|
| **ItemInstanceRepository** | `LocalItemInstanceTable` | `addItem()`, `upsertItem()`, `getItemsByUser()`, `updateItem()`, `deleteItem()` | GameCoordinator (discovery), SyncProvider (rollback) |
| **CellProgressRepository** | `LocalCellProgressTable` | `create()`, `read()`, `incrementVisitCount()`, `addDistance()` | GameCoordinator (cell visit), SyncProvider (rollback) |
| **ProfileRepository** | `LocalPlayerProfileTable` | `create()`, `read()`, `update()`, `incrementCurrentStreak()` | GameCoordinator (profile), Onboarding |
| **WriteQueueRepository** | `LocalWriteQueueTable` | `enqueue()`, `getPending()`, `markRejected()`, `deleteEntry()` | QueueProcessor (flush), SyncProvider |
| **CellPropertyRepository** | `LocalCellPropertiesTable` | `get()`, `upsert()`, `updateLocationId()`, `getAll()` | GameCoordinator (cell props), Enrichment |
| **HierarchyRepository** | Country/State/City/District tables | `upsertCountry()`, `getStatesForCountry()`, etc. | GameCoordinator (hydration) |

---

## Data Flow: Discovery → Sync

```
1. GameCoordinator.onItemDiscovered(event, instance)
   ↓
2. gameCoordinatorProvider (callback wired)
   ├─ itemsProvider.addItem(instance)  [in-memory]
   ├─ discoveryProvider.showDiscovery(event)  [toast]
   └─ persistItemDiscovery(instance, userId)
       ├─ itemRepo.addItem(instance, userId)  [SQLite]
       │   └─ LocalItemInstanceTable.insert()
       └─ queueProcessor.enqueue(...)  [only if SQLite succeeds]
           └─ LocalWriteQueueTable.insert()
               └─ Auto-schedule flush (5s debounce)
                   ├─ QueueProcessor.flush()
                   │   └─ SupabasePersistence.upsertItemInstance()
                   │       └─ Supabase `item_instances` table
                   └─ On success: delete queue entry
                   └─ On rejection: mark rejected + rollback inventory
```

---

## Data Flow: Startup Hydration

```
gameCoordinatorProvider initialization
  ├─ Phase 1: SQLite → providers (fast, ~200ms)
  │   └─ rehydrateData(userId)
  │       ├─ itemRepo.getItemsByUser(userId) → itemsProvider.loadItems()
  │       ├─ cellProgressRepo.readByUser(userId) → fogResolver.loadVisitedCells()
  │       ├─ profileRepo.read(userId) → playerProvider.loadProfile()
  │       └─ cellPropertyRepo.getAll() → coordinator.loadCellProperties()
  │
  ├─ Phase 2: Supabase → SQLite (background, non-blocking)
  │   └─ hydrateFromSupabase(userId)
  │       ├─ persistence.fetchProfile() → profileRepo.create()
  │       ├─ persistence.fetchCellProgress() → cellProgressRepo.create() [batch]
  │       ├─ persistence.fetchItemInstances() → itemRepo.upsertItem() [batch]
  │       ├─ persistence.fetchSpeciesUpdates() → db.updateSpeciesEnrichment() [batch]
  │       ├─ persistence.fetchCellProperties() → cellPropertyRepo.upsert() [batch]
  │       └─ persistence.fetchHierarchy() → hierarchyRepo.upsert*() [batch]
  │
  └─ Phase 3: Start game loop
      └─ coordinator.start(gpsStream, discoveryStream)
```

**Key:** Phase 1 completes before game loop starts. Phase 2 runs in background without re-hydrating providers.

---

## Write Queue Lifecycle

```
1. ENQUEUE
   └─ persistItemDiscovery() → queueProcessor.enqueue()
       └─ LocalWriteQueueTable.insert(status='pending', attempts=0)

2. AUTO-FLUSH SCHEDULE
   └─ QueueProcessor._scheduleFlush()
       └─ Timer(5s) → flush()

3. FLUSH ATTEMPT
   └─ For each pending entry:
       ├─ SupabasePersistence.upsertItemInstance()
       ├─ On success: queueRepo.deleteEntry()
       ├─ On retryable error: queueRepo.incrementAttempts()
       │   └─ If max retries (5): queueRepo.markRejected()
       └─ On validation rejection: queueRepo.markRejected()

4. REJECTION PROCESSING
   └─ SyncNotifier.processRejections()
       ├─ For itemInstance: itemsProvider.removeItem() + itemRepo.deleteItem()
       ├─ For cellProgress/profile: log only (server is authoritative)
       └─ queueRepo.deleteEntry()
```

---

## Conditional Supabase

### When Configured
```dart
await Supabase.initialize(url: ..., anonKey: ...);
```
- `supabaseClientProvider` → `SupabaseClient`
- `supabasePersistenceProvider` → `SupabasePersistence`
- `queueProcessor.canSync` → `true`
- Write queue auto-flushes every 5s
- Hydration fetches from Supabase in background

### When NOT Configured
```dart
// SupabaseConfig.url or SupabaseConfig.anonKey is empty
```
- `supabaseClientProvider` → `null`
- `supabasePersistenceProvider` → `null`
- `queueProcessor.canSync` → `false`
- Write queue entries created but never flushed
- Hydration reads from SQLite only
- App runs in offline-only mode

---

## Denormalization: Why?

**LocalItemInstanceTable** carries 60 columns:
- 9 base fields (id, userId, definitionId, etc.)
- 15 species enrichment fields (animalClassName, brawn, wit, speed, etc.)
- 17 species enrichment version stamps (brawnEnrichver, etc.)
- 6 cell properties fields (cellHabitatName, cellClimateName, etc.)
- 6 cell properties version stamps
- 5 location hierarchy fields (locationDistrict, locationCity, etc.)
- 5 location hierarchy version stamps

**Why?**
1. **Offline resilience:** Item instances carry all needed data without additional lookups
2. **Deterministic re-derivation:** Server can validate encounters by re-deriving from seed + cell ID
3. **Enrichment versioning:** Per-field version stamps track which pipeline commit produced each value

---

## Performance Optimizations

| Optimization | Where | Why |
|--------------|-------|-----|
| **Write serialization** | Web (IndexedDB) | Prevent concurrent writes (ConstraintError) |
| **Batched persistence** | Cell properties (5 per batch) | iOS IndexedDB: 10–15ms per write, batch yields prevent jank |
| **Debounced profile** | Profile state (5s debounce) | Accumulate rapid changes, avoid hammering SQLite |
| **Lazy hydration** | Startup (Phase 1 + Phase 2) | Get player to map immediately, Supabase fetch in background |
| **Yield every 50 rows** | Hydration loops | Prevent blocking UI during bulk upserts |

---

## Error Handling

| Error | Handling | Result |
|-------|----------|--------|
| **SQLite write fails** | Log + return (don't enqueue) | Item not persisted, not queued |
| **Enqueue fails** | Log (item already persisted) | Item in SQLite but not queued (won't sync) |
| **Sync network error** | Increment attempts, retry up to 5x | Retryable, eventually marked rejected |
| **Sync validation rejection** | Mark rejected immediately | Trigger local rollback (for items) |
| **Hydration fails** | Log + mark hydrated + start loop | App continues with empty state |

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

**Pattern:**
```dart
final db = AppDatabase(NativeDatabase.memory());
final container = ProviderContainer(
  overrides: [
    appDatabaseProvider.overrideWithValue(db),
    itemInstanceRepositoryProvider.overrideWith(
      (ref) => ItemInstanceRepository(ref.watch(appDatabaseProvider)),
    ),
  ],
);
```

---

## Checklist: Adding a New Entity Type

1. **Add table to `AppDatabase`**
   ```dart
   @DataClassName('LocalMyEntity')
   class LocalMyEntityTable extends Table {
     // Define columns
   }
   ```

2. **Create repository**
   ```dart
   class MyEntityRepository {
     final AppDatabase _db;
     // CRUD methods
   }
   ```

3. **Create provider**
   ```dart
   final myEntityRepositoryProvider = Provider<MyEntityRepository>((ref) {
     final db = ref.watch(appDatabaseProvider);
     return MyEntityRepository(db);
   });
   ```

4. **Add write queue entity type**
   ```dart
   enum WriteQueueEntityType {
     itemInstance,
     cellProgress,
     profile,
     cellProperties,
     myEntity,  // ← Add here
   }
   ```

5. **Create persistence function**
   ```dart
   Future<void> persistMyEntity({
     required MyEntity entity,
     required String userId,
     required MyEntityRepository repo,
     required QueueProcessor queueProcessor,
   }) async {
     // 1. SQLite write
     // 2. Enqueue (only if SQLite succeeds)
   }
   ```

6. **Wire in gameCoordinatorProvider**
   ```dart
   coordinator.onMyEntityChanged = (entity) {
     persistMyEntity(...);
   };
   ```

7. **Add Supabase fetch/upsert**
   ```dart
   // In SupabasePersistence
   Future<List<Map<String, dynamic>>> fetchMyEntities(String userId) async { ... }
   Future<void> upsertMyEntity({...}) async { ... }
   ```

8. **Add hydration**
   ```dart
   // In hydrateFromSupabase()
   final myEntityRows = await persistence.fetchMyEntities(userId);
   for (final row in myEntityRows) {
     await myEntityRepo.upsert(...);
   }
   ```

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
