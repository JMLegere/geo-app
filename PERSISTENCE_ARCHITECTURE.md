# Persistence Layer & Data Flow Architecture

**Last Updated:** 2026-04-02  
**Status:** Complete (Phases 1–4 implemented)

---

## Executive Summary

The app uses a **server-authoritative, offline-first** persistence model:

- **SQLite (Drift)** = local cache + offline write queue
- **Supabase** = source of truth (when configured)
- **Write Queue** = deferred sync outbox for offline-first resilience
- **Hydration** = SQLite → providers on startup, then Supabase in background

**Key principle:** All writes go to SQLite first. Only after SQLite succeeds do we enqueue for Supabase. This prevents corrupt payloads from reaching the server if the local write fails.

---

## Database Schema (Drift ORM)

### Core Tables (10 total)

| Table | Purpose | Rows | Key Fields |
|-------|---------|------|-----------|
| `LocalCellProgressTable` | Per-user cell visit history | ~1000s | `(userId, cellId)` unique |
| `LocalItemInstanceTable` | Unique discovered items | ~1000s | `id` (UUID) |
| `LocalPlayerProfileTable` | Player stats & streaks | 1 per user | `id` (userId) |
| `LocalSpeciesTable` | IUCN species + enrichment | 32,752 | `definitionId` |
| `LocalWriteQueueTable` | Offline sync outbox | ~100s | `id` (auto-increment) |
| `LocalCellPropertiesTable` | Geo-derived cell data | ~1000s | `cellId` (global) |
| `LocalCountryTable` | Geographic hierarchy | 195 | `id` |
| `LocalStateTable` | Geographic hierarchy | ~5000 | `id` |
| `LocalCityTable` | Geographic hierarchy | ~30k | `id` |
| `LocalDistrictTable` | Geographic hierarchy | ~500k | `id` |

**Schema version:** 24 (latest)

### LocalCellProgressTable

```dart
id: text (PK)
userId: text
cellId: text
fogState: text (enum: 'unknown', 'detected', 'nearby', 'explored', 'present')
distanceWalked: real (default 0.0)
visitCount: integer (default 0)
restorationLevel: real (default 0.0)
lastVisited: datetime (nullable)
createdAt: datetime
updatedAt: datetime

Unique constraint: (userId, cellId)
```

**Purpose:** Tracks per-user cell visits. Fog state is **computed** from this data, not stored.

### LocalItemInstanceTable

```dart
id: text (PK, UUID v4)
userId: text
definitionId: text (FK → LocalSpeciesTable)
displayName: text
scientificName: text (nullable)
categoryName: text (enum: fauna, flora, mineral, fossil, artifact, food, orb)
rarityName: text (nullable, enum: leastConcern, nearThreatened, vulnerable, endangered, criticallyEndangered, extinct)
habitatsJson: text (JSON array)
continentsJson: text (JSON array)
taxonomicClass: text (nullable, e.g., "Mammalia")
affixes: text (JSON array of {type, key, value})
badgesJson: text (JSON array, e.g., ["first_discovery", "beta"])
parentAId: text (nullable, for bred offspring)
parentBId: text (nullable, for bred offspring)
acquiredAt: datetime
acquiredInCellId: text (nullable)
dailySeed: text (nullable, for deterministic re-derivation)
status: text (enum: active, donated, placed, released, traded)
iconUrl: text (nullable)
artUrl: text (nullable)

// Species enrichment denormalization (15 fields + 17 version stamps)
animalClassName: text (nullable)
animalClassNameEnrichver: text (nullable, commit SHA)
foodPreferenceName: text (nullable)
foodPreferenceNameEnrichver: text (nullable)
climateName: text (nullable)
climateNameEnrichver: text (nullable)
brawn: integer (nullable, 0–90)
brawnEnrichver: text (nullable)
wit: integer (nullable, 0–90)
witEnrichver: text (nullable)
speed: integer (nullable, 0–90)
speedEnrichver: text (nullable)
sizeName: text (nullable, enum: fine, diminutive, tiny, small, medium, large, huge, gargantuan, colossal)
sizeNameEnrichver: text (nullable)
iconUrlEnrichver: text (nullable)
artUrlEnrichver: text (nullable)

// Cell properties denormalization (6 fields + 6 version stamps)
cellHabitatName: text (nullable)
cellHabitatNameEnrichver: text (nullable)
cellClimateName: text (nullable)
cellClimateNameEnrichver: text (nullable)
cellContinentName: text (nullable)
cellContinentNameEnrichver: text (nullable)

// Location hierarchy denormalization (5 fields + 5 version stamps)
locationDistrict: text (nullable)
locationDistrictEnrichver: text (nullable)
locationCity: text (nullable)
locationCityEnrichver: text (nullable)
locationState: text (nullable)
locationStateEnrichver: text (nullable)
locationCountry: text (nullable)
locationCountryEnrichver: text (nullable)
locationCountryCode: text (nullable)
locationCountryCodeEnrichver: text (nullable)
```

**Purpose:** Unique item instances with rolled affixes. Denormalized enrichment fields snapshot species data at discovery time.

### LocalPlayerProfileTable

```dart
id: text (PK, userId)
displayName: text
currentStreak: integer (default 0)
longestStreak: integer (default 0)
totalDistanceKm: real (default 0.0)
currentSeason: text (enum: summer, winter)
hasCompletedOnboarding: boolean (default false)
lastLat: real (nullable)
lastLon: real (nullable)
totalSteps: integer (default 0)
lastKnownStepCount: integer (default 0)
createdAt: datetime
updatedAt: datetime
```

**Purpose:** Player profile. `cellsObserved` is **computed** from cell progress count, not stored.

### LocalSpeciesTable

```dart
definitionId: text (PK, e.g., "fauna_vulpes_vulpes")
scientificName: text
commonName: text
taxonomicClass: text
iucnStatus: text (enum: leastConcern, nearThreatened, vulnerable, endangered, criticallyEndangered, extinct)
habitatsJson: text (JSON array)
continentsJson: text (JSON array)

// Enrichment (nullable until AI-classified)
animalClass: text (nullable, enum: 35 animal classes)
foodPreference: text (nullable, enum: critter, fish, fruit, grub, nectar, seed, veg)
climate: text (nullable, enum: tropic, temperate, boreal, frigid)
brawn: integer (nullable, 0–90)
wit: integer (nullable, 0–90)
speed: integer (nullable, 0–90)
size: text (nullable, enum: fine, diminutive, tiny, small, medium, large, huge, gargantuan, colossal)
iconUrl: text (nullable)
artUrl: text (nullable)
iconPrompt: text (nullable)
artPrompt: text (nullable)
enrichedAt: datetime (nullable)

// Per-field enrichment version stamps (commit SHA)
animalClassEnrichver: text (nullable)
foodPreferenceEnrichver: text (nullable)
climateEnrichver: text (nullable)
brawnEnrichver: text (nullable)
witEnrichver: text (nullable)
speedEnrichver: text (nullable)
sizeEnrichver: text (nullable)
iconPromptEnrichver: text (nullable)
artPromptEnrichver: text (nullable)
iconUrlEnrichver: text (nullable)
artUrlEnrichver: text (nullable)
```

**Purpose:** IUCN species catalog (32,752 rows) + AI enrichment. Seeded from `assets/species_data.json` on first run.

### LocalWriteQueueTable

```dart
id: integer (PK, auto-increment)
entityType: text (enum: itemInstance, cellProgress, profile, cellProperties)
entityId: text (primary key of entity being synced)
operation: text (enum: upsert, delete)
payload: text (JSON snapshot of entity)
userId: text (for routing after account switch)
status: text (enum: pending, rejected, default pending)
attempts: integer (default 0)
lastError: text (nullable)
createdAt: datetime
updatedAt: datetime
```

**Purpose:** Offline sync outbox. Entries are deleted after server confirmation or marked rejected if validation fails.

### LocalCellPropertiesTable

```dart
cellId: text (PK, Voronoi cell ID)
habitats: text (JSON array of habitat names)
climate: text (enum: tropic, temperate, boreal, frigid)
continent: text (enum: asia, northAmerica, southAmerica, africa, oceania, europe)
locationId: text (nullable, FK → district)
districtId: text (nullable, FK → LocalDistrictTable)
createdAt: datetime
```

**Purpose:** Globally shared cell properties. Resolved once when a cell becomes adjacent, then cached forever.

---

## Repository Pattern

### 6 Repositories (Pure Dart, no Riverpod)

Each repository wraps `AppDatabase` and provides domain-specific CRUD operations.

#### 1. ItemInstanceRepository

**Wraps:** `LocalItemInstanceTable`

**CRUD Operations:**
- `addItem(ItemInstance, userId)` — insert new item
- `upsertItem(ItemInstance, userId)` — insert or replace (for Supabase hydration)
- `getItemsByUser(userId)` → `List<ItemInstance>`
- `getItemsByCell(userId, cellId)` → `List<ItemInstance>`
- `getItem(id)` → `ItemInstance?`
- `updateItem(ItemInstance, userId)` → `bool`
- `deleteItem(id)` → `int` (rows deleted)
- `getItemCount(userId)` → `int`
- `getUniqueDefinitionIds(userId)` → `Set<String>`
- `clearUserItems(userId)` → `int`

**Conversion:** Domain `ItemInstance` ↔ Drift `LocalItemInstance` (32 denormalized fields)

**Called by:**
- `gameCoordinatorProvider` — hydration + discovery persistence
- `syncProvider` — rejection rollback
- `queueProcessorProvider` — first-badge award validation

#### 2. CellProgressRepository

**Wraps:** `LocalCellProgressTable`

**CRUD Operations:**
- `create(id, userId, cellId, fogState, ...)` — new cell visit
- `read(userId, cellId)` → `LocalCellProgress?`
- `readByUser(userId)` → `List<LocalCellProgress>`
- `update(userId, cellId, fogState?, distanceWalked?, ...)` — update fields
- `delete(userId, cellId)` → `int`
- `getFogState(userId, cellId)` → `FogState?`
- `updateFogState(userId, cellId, newState)` — set fog state
- `addDistance(userId, cellId, distance)` — increment distance
- `incrementVisitCount(userId, cellId)` — increment visit count
- `getCellsByFogState(userId, state)` → `List<LocalCellProgress>`
- `getCellCountByFogState(userId)` → `Map<FogState, int>`

**Called by:**
- `gameCoordinatorProvider` — hydration + cell visit persistence
- `syncProvider` — rejection rollback (cell progress)

#### 3. ProfileRepository

**Wraps:** `LocalPlayerProfileTable`

**CRUD Operations:**
- `create(userId, displayName, ...)` — new profile
- `read(userId)` → `LocalPlayerProfile?`
- `update(userId, displayName?, currentStreak?, ...)` — update fields
- `delete(userId)` → `int`
- `updateDisplayName(userId, name)`
- `updateCurrentStreak(userId, streak)`
- `updateLongestStreak(userId, streak)`
- `addDistance(userId, distanceKm)` — increment distance
- `updateSeason(userId, season)`
- `incrementCurrentStreak(userId)` — increment + update longest
- `resetCurrentStreak(userId)`
- `markOnboardingComplete(userId)`
- `getAllProfiles()` → `List<LocalPlayerProfile>` (debug/export)

**Called by:**
- `gameCoordinatorProvider` — hydration + profile persistence
- `onboardingScreen` — mark onboarding complete
- `syncProvider` — rejection rollback (profile)

#### 4. WriteQueueRepository

**Wraps:** `LocalWriteQueueTable`

**CRUD Operations:**
- `enqueue(entityType, entityId, operation, payload, userId)` → `int` (queue ID)
- `getPending(limit?, userId?)` → `List<WriteQueueEntry>`
- `getRejected(userId?)` → `List<WriteQueueEntry>`
- `countPending(userId?)` → `int`
- `deleteEntry(id)` — remove after server confirmation
- `deleteEntries(List<int>)` — batch cleanup
- `markRejected(id, error)` — mark as rejected
- `incrementAttempts(id, error)` — increment retry count
- `deleteStale(cutoff)` — cleanup old entries
- `clearUser(userId)` — remove all entries for user

**Called by:**
- `queueProcessor` — enqueue/flush/cleanup
- `syncProvider` — rejection processing

#### 5. CellPropertyRepository

**Wraps:** `LocalCellPropertiesTable`

**CRUD Operations:**
- `get(cellId)` → `CellProperties?`
- `upsert(CellProperties)` — insert or replace
- `updateLocationId(cellId, locationId)` — update FK
- `getAll()` → `List<CellProperties>`

**Called by:**
- `gameCoordinatorProvider` — hydration + cell property persistence
- `cellPropertyResolverProvider` — cache lookup

#### 6. HierarchyRepository

**Wraps:** `LocalCountryTable`, `LocalStateTable`, `LocalCityTable`, `LocalDistrictTable`

**CRUD Operations:**
- `getAllCountries()`, `getStatesForCountry(id)`, `getCitiesForState(id)`, `getDistrictsForCity(id)`
- `getCountry(id)`, `getState(id)`, `getCity(id)`, `getDistrict(id)`
- `upsertCountry(HCountry)`, `upsertState(HState)`, `upsertCity(HCity)`, `upsertDistrict(HDistrict)`

**Called by:**
- `gameCoordinatorProvider` — hydration from Supabase
- Location enrichment service — district lookup

---

## Riverpod Provider Wiring

### Database & Repository Providers

```dart
// Core database singleton
appDatabaseProvider: Provider<AppDatabase>
  └─ Creates AppDatabase with platform-aware connection
  └─ Lifecycle: created at app startup, disposed on shutdown

// Repository providers (watch appDatabaseProvider)
itemInstanceRepositoryProvider: Provider<ItemInstanceRepository>
cellProgressRepositoryProvider: Provider<CellProgressRepository>
profileRepositoryProvider: Provider<ProfileRepository>
writeQueueRepositoryProvider: Provider<WriteQueueRepository>
cellPropertyRepositoryProvider: Provider<CellPropertyRepository>
hierarchyRepositoryProvider: Provider<HierarchyRepository>
```

### Sync Providers

```dart
supabaseClientProvider: Provider<SupabaseClient?>
  └─ Returns null if Supabase not configured

supabasePersistenceProvider: Provider<SupabasePersistence?>
  └─ Returns null if Supabase not configured
  └─ Wraps SupabaseClient for persistence operations

queueProcessorProvider: Provider<QueueProcessor>
  └─ Watches: writeQueueRepositoryProvider, itemInstanceRepositoryProvider
  └─ Manages offline sync outbox

syncProvider: NotifierProvider<SyncNotifier, SyncStatus>
  └─ Watches: supabasePersistenceProvider, queueProcessorProvider
  └─ Handles manual sync + rejection processing
```

---

## Data Flow Diagrams

### 1. Item Discovery Flow

```
GameCoordinator.onItemDiscovered
  ↓
gameCoordinatorProvider (callback wired)
  ├─ 1. Add to in-memory inventory (itemsProvider.addItem)
  ├─ 2. Show discovery toast (discoveryProvider.showDiscovery)
  └─ 3. persistItemDiscovery()
       ├─ SQLite: itemRepo.addItem(instance, userId)
       │   └─ LocalItemInstanceTable.insert()
       └─ Write Queue: queueProcessor.enqueue()
           ├─ LocalWriteQueueTable.insert()
           └─ Auto-schedule flush (5s debounce)
                ├─ QueueProcessor.flush()
                │   └─ SupabasePersistence.upsertItemInstance()
                │       └─ Supabase `item_instances` table
                └─ On success: delete queue entry
                └─ On rejection: mark rejected + rollback inventory
```

**Key:** SQLite write must succeed before enqueue. If SQLite fails, item is not queued.

### 2. Cell Visit Flow

```
GameCoordinator.onCellVisited(cellId)
  ↓
gameCoordinatorProvider (callback wired)
  ├─ 1. Increment cellsObserved (playerProvider.incrementCellsObserved)
  └─ 2. persistCellVisit()
       ├─ SQLite: cellProgressRepo.read() → check if first visit
       │   ├─ First visit: cellProgressRepo.create()
       │   └─ Returning: cellProgressRepo.incrementVisitCount()
       └─ Write Queue: queueProcessor.enqueue()
           ├─ LocalWriteQueueTable.insert()
           └─ Auto-schedule flush
                ├─ QueueProcessor.flush()
                │   └─ SupabasePersistence.upsertCellProgress()
                │       └─ Supabase `cell_progress` table
                └─ On success: delete queue entry
```

**Key:** Payload uses current DB values (visitCount, distanceWalked) to avoid stale defaults.

### 3. Profile State Flow

```
PlayerNotifier state change (cells, distance, streaks)
  ↓
gameCoordinatorProvider (ref.listen on playerProvider)
  ├─ Debounce 5s (accumulate rapid changes)
  └─ persistProfileState()
       ├─ SQLite: profileRepo.read() → check if exists
       │   ├─ Exists: profileRepo.update()
       │   └─ New: profileRepo.create()
       └─ Write Queue: queueProcessor.enqueue()
           ├─ LocalWriteQueueTable.insert()
           └─ Auto-schedule flush
                ├─ QueueProcessor.flush()
                │   └─ SupabasePersistence.upsertProfile()
                │       └─ Supabase `profiles` table
                └─ On success: delete queue entry
```

**Key:** Debounced to 5s to avoid hammering IndexedDB-backed SQLite on iOS (each write = 1.5–3s).

### 4. Cell Properties Flow

```
GameCoordinator.onCellPropertiesResolved(properties)
  ↓
gameCoordinatorProvider (callback wired)
  └─ persistCellProperties()
       ├─ SQLite: cellPropertyRepo.upsert(properties)
       │   └─ LocalCellPropertiesTable.upsert()
       └─ Write Queue: queueProcessor.enqueue()
           ├─ LocalWriteQueueTable.insert()
           └─ Auto-schedule flush
                ├─ QueueProcessor.flush()
                │   └─ SupabasePersistence.upsertCellProperties()
                │       └─ Supabase `cell_properties` table
                └─ On success: delete queue entry
```

**Key:** Cell properties are globally shared (no userId in SQLite), but write queue still needs userId for routing.

### 5. Offline → Online Sync Flow

```
QueueProcessor.flush() [triggered by auto-flush timer or manual syncNow()]
  ├─ Guard: if Supabase not configured, return empty summary
  ├─ Guard: if flush already in progress, return empty summary
  └─ For each pending queue entry (oldest first, batch limited):
       ├─ Dispatch to SupabasePersistence method (upsertItemInstance, etc.)
       ├─ On success (FlushConfirmed):
       │   ├─ Delete queue entry
       │   └─ If first-discovery badge awarded: collect itemId
       ├─ On retryable error (FlushRetryable):
       │   └─ Increment attempts + record error
       │       └─ If max retries exceeded: mark rejected
       └─ On validation rejection (FlushRejected):
           └─ Mark entry as rejected + record error
                ├─ SyncNotifier.processRejections()
                │   ├─ For itemInstance: remove from inventory + delete from SQLite
                │   ├─ For cellProgress/profile: log only (server is source of truth)
                │   └─ Delete rejected queue entry
                └─ Show rejection toast to user
```

**Key:** Rejected entries trigger local rollback for items, but not for cell progress/profile (server is authoritative).

### 6. Startup Hydration Flow

```
gameCoordinatorProvider initialization
  ├─ Phase 1: SQLite → providers (fast, ~200ms)
  │   └─ rehydrateData(userId)
  │       ├─ itemRepo.getItemsByUser(userId)
  │       │   └─ itemsProvider.loadItems(items)
  │       ├─ cellProgressRepo.readByUser(userId)
  │       │   └─ fogResolver.loadVisitedCells(visitedCellIds)
  │       ├─ profileRepo.read(userId)
  │       │   └─ playerProvider.loadProfile(...)
  │       └─ cellPropertyRepo.getAll()
  │           └─ coordinator.loadCellProperties(propsMap)
  │
  ├─ Phase 2: Supabase → SQLite (background, non-blocking)
  │   └─ hydrateFromSupabase(userId)
  │       ├─ persistence.fetchProfile(userId)
  │       │   └─ profileRepo.create()
  │       ├─ persistence.fetchCellProgress(userId)
  │       │   └─ cellProgressRepo.create() [for each row]
  │       ├─ persistence.fetchItemInstances(userId)
  │       │   └─ itemRepo.upsertItem() [for each row]
  │       ├─ persistence.fetchSpeciesUpdates()
  │       │   └─ db.updateSpeciesEnrichment() [for each row]
  │       ├─ persistence.fetchCellProperties(visitedCellIds)
  │       │   └─ cellPropertyRepo.upsert() [for each row]
  │       └─ persistence.fetchHierarchy()
  │           └─ hierarchyRepo.upsert*() [for each row]
  │
  └─ Phase 3: Start game loop
      └─ coordinator.start(gpsStream, discoveryStream)
```

**Key:** Phase 1 completes before game loop starts. Phase 2 runs in background without re-hydrating providers (avoids race with in-flight discoveries).

---

## Write Queue Lifecycle

### Enqueue

```dart
// Called by persistItemDiscovery, persistCellVisit, persistProfileState, persistCellProperties
await queueProcessor.enqueue(
  entityType: WriteQueueEntityType.itemInstance,
  entityId: instance.id,
  operation: WriteQueueOperation.upsert,
  payload: jsonEncode({...}),
  userId: userId,
);
```

**Result:** Entry inserted into `LocalWriteQueueTable` with status='pending', attempts=0.

### Auto-Flush Schedule

```dart
// QueueProcessor._scheduleFlush()
// Fires exactly once per window (not debounced — first enqueue starts timer)
Timer(Duration(seconds: kWriteQueueAutoFlushDelaySeconds), () async {
  final summary = await flush(userId: userId);
  onAutoFlushComplete?.call(summary);
});
```

**Default:** `kWriteQueueAutoFlushDelaySeconds = 5` (from `shared/constants.dart`)

### Flush Attempt

```dart
// For each pending entry:
try {
  await persistence.upsertItemInstance(...);
  // Success → delete entry
  await queueRepo.deleteEntry(id);
} on SyncException catch (e) {
  // Retryable error → increment attempts
  await queueRepo.incrementAttempts(id, e.message);
  if (attempts >= kMaxQueueRetries) {
    // Max retries exceeded → mark rejected
    await queueRepo.markRejected(id, e.message);
  }
} on SyncValidationRejectedException catch (e) {
  // Server validation failed → mark rejected immediately
  await queueRepo.markRejected(id, e.reason);
}
```

**Max retries:** `kMaxQueueRetries = 5` (from `shared/constants.dart`)

### Rejection Processing

```dart
// SyncNotifier.processRejections()
for (final entry in rejected) {
  switch (entry.entityType) {
    case WriteQueueEntityType.itemInstance:
      // Remove from inventory + delete from SQLite
      ref.read(itemsProvider.notifier).removeItem(entry.entityId);
      await itemRepo.deleteItem(entry.entityId);
      break;
    case WriteQueueEntityType.cellProgress:
    case WriteQueueEntityType.profile:
      // Log only — server is source of truth
      break;
  }
  // Delete rejected entry from queue
  await queueRepo.deleteEntry(entry.id);
}
```

**Key:** Only items are rolled back locally. Cell progress and profile are not rolled back (server is authoritative).

### Stale Entry Cleanup

```dart
// Runs periodically (not yet implemented, but infrastructure exists)
final cutoff = DateTime.now().subtract(Duration(days: 7));
await queueRepo.deleteStale(cutoff);
```

**Deletes:** Entries with status='confirmed' or 'rejected' older than cutoff. Never deletes 'pending' entries.

---

## SupabasePersistence API

### Profile Operations

```dart
Future<Map<String, dynamic>?> fetchProfile(String userId)
Future<void> upsertProfile({
  required String userId,
  String? displayName,
  int? currentStreak,
  int? longestStreak,
  double? totalDistanceKm,
  String? currentSeason,
  bool? hasCompletedOnboarding,
})
```

### Cell Progress Operations

```dart
Future<List<Map<String, dynamic>>> fetchCellProgress(String userId)
Future<void> upsertCellProgress({
  required String userId,
  required String cellId,
  required String fogState,
  double distanceWalked = 0,
  int visitCount = 0,
  DateTime? lastVisited,
})
```

### Item Instance Operations

```dart
Future<List<Map<String, dynamic>>> fetchItemInstances(String userId)
Future<void> upsertItemInstance({
  required String id,
  required String userId,
  required String definitionId,
  required String affixes,
  // ... 30+ optional denormalized fields
})
```

### Cell Properties Operations

```dart
Future<List<Map<String, dynamic>>> fetchCellProperties(List<String> cellIds)
Future<void> upsertCellProperties({
  required String cellId,
  required List<String> habitats,
  required String climate,
  required String continent,
  String? locationId,
})
```

### Species Enrichment Operations

```dart
Future<List<Map<String, dynamic>>> fetchSpeciesUpdates({required DateTime since})
```

### Hierarchy Operations

```dart
Future<List<Map<String, dynamic>>> fetchCountries()
Future<List<Map<String, dynamic>>> fetchStates()
Future<List<Map<String, dynamic>>> fetchCities()
Future<List<Map<String, dynamic>>> fetchDistricts()
```

---

## Conditional Supabase

### When Configured

```dart
// In main.dart, before runApp():
await Supabase.initialize(
  url: SupabaseConfig.url,
  anonKey: SupabaseConfig.anonKey,
);
```

**Result:**
- `supabaseClientProvider` returns `SupabaseClient`
- `supabasePersistenceProvider` returns `SupabasePersistence`
- `queueProcessor.canSync` returns `true`
- Write queue auto-flushes every 5s
- Hydration fetches from Supabase in background

### When NOT Configured

```dart
// SupabaseConfig.url or SupabaseConfig.anonKey is empty
```

**Result:**
- `supabaseClientProvider` returns `null`
- `supabasePersistenceProvider` returns `null`
- `queueProcessor.canSync` returns `false`
- Write queue entries are created but never flushed
- Hydration reads from SQLite only
- App runs in offline-only mode (no sync)

---

## Persistence Consumer Functions

### persistItemDiscovery

```dart
Future<void> persistItemDiscovery({
  required ItemInstance instance,
  required String userId,
  required ItemInstanceRepository itemRepo,
  required QueueProcessor queueProcessor,
  ObservabilityBuffer? obs,
})
```

**Steps:**
1. Write to SQLite via `itemRepo.addItem()`
2. If success: enqueue via `queueProcessor.enqueue()`
3. If SQLite fails: return (don't enqueue)

**Payload:** JSON with id, definitionId, affixes, badges, status, etc.

### persistCellVisit

```dart
Future<void> persistCellVisit({
  required String cellId,
  required String userId,
  required CellProgressRepository cellProgressRepo,
  required QueueProcessor queueProcessor,
  ObservabilityBuffer? obs,
})
```

**Steps:**
1. Read existing cell progress from SQLite
2. If first visit: create new record with visitCount=1
3. If returning: increment visitCount
4. Enqueue with current DB values (visitCount, distanceWalked)

**Payload:** JSON with cellId, fogState, visitCount, distanceWalked, lastVisited

### persistCellProperties

```dart
Future<void> persistCellProperties({
  required CellProperties properties,
  required CellPropertyRepository cellPropertyRepo,
  required QueueProcessor queueProcessor,
  required String? userId,
  ObservabilityBuffer? obs,
})
```

**Steps:**
1. Write to SQLite via `cellPropertyRepo.upsert()`
2. If success and userId != null: enqueue via `queueProcessor.enqueue()`

**Payload:** JSON with cellId, habitats, climate, continent, locationId

### persistProfileState

```dart
Future<void> persistProfileState({
  required String userId,
  required PlayerState playerState,
  required ProfileRepository profileRepo,
  required QueueProcessor queueProcessor,
  double? lastLat,
  double? lastLon,
  ObservabilityBuffer? obs,
})
```

**Steps:**
1. Yield to event loop (avoid blocking on iOS IndexedDB)
2. Read existing profile from SQLite
3. If exists: update fields
4. If new: create with displayName='Explorer'
5. Enqueue with current state

**Payload:** JSON with displayName, currentStreak, longestStreak, totalDistanceKm, currentSeason, hasCompletedOnboarding, totalSteps, lastKnownStepCount, lastLat, lastLon

---

## Hydration from Supabase

### hydrateFromSupabase

```dart
Future<void> hydrateFromSupabase({
  required String userId,
  required SupabasePersistence? persistence,
  required ProfileRepository profileRepo,
  required CellProgressRepository cellProgressRepo,
  required ItemInstanceRepository itemRepo,
  required CellPropertyRepository cellPropertyRepo,
  HierarchyRepository? hierarchyRepo,
  AppDatabase? db,
  SpeciesCache? speciesCache,
  ObservabilityBuffer? obs,
})
```

**Steps:**
1. Fetch profile, cell progress, item instances in parallel
2. Fetch cell properties for visited cells (sequential, depends on cellRows)
3. Upsert profile → SQLite
4. Upsert cell progress rows → SQLite (yield every 50 rows)
5. Upsert item instances → SQLite (yield every 50 rows)
6. Delta-sync species enrichment → LocalSpeciesTable (full sync, no watermark)
7. Upsert cell properties → SQLite (yield every 50 rows)
8. Upsert hierarchy tables → SQLite (countries, states, cities, districts)

**Graceful handling:**
- Supabase not configured → no-op
- Network error → log and continue (SQLite-only fallback)
- Empty server data → no-op (fresh account)

**Key:** Runs in background after Phase 1 hydration. Does NOT re-hydrate providers (avoids race with in-flight discoveries).

---

## Denormalization Strategy

### Why Denormalize?

1. **Offline resilience:** Item instances carry all needed data (species enrichment, cell properties, location hierarchy) without requiring additional lookups
2. **Deterministic re-derivation:** Server can validate encounters by re-deriving from the same seed + cell ID
3. **Enrichment versioning:** Per-field version stamps track which pipeline commit produced each value

### LocalItemInstanceTable Denormalization

**Species enrichment (15 fields + 17 version stamps):**
- `animalClassName`, `foodPreferenceName`, `climateName`, `brawn`, `wit`, `speed`, `sizeName`, `iconUrl`, `artUrl`
- Each field has a companion `_enrichver` column (commit SHA)

**Cell properties (6 fields + 6 version stamps):**
- `cellHabitatName`, `cellClimateName`, `cellContinentName`
- Each field has a companion `_enrichver` column

**Location hierarchy (5 fields + 5 version stamps):**
- `locationDistrict`, `locationCity`, `locationState`, `locationCountry`, `locationCountryCode`
- Each field has a companion `_enrichver` column

**Total:** 32 denormalized columns + 28 version stamp columns = 60 columns per item instance

### Enrichment Version Stamps

**Purpose:** Track which pipeline commit produced each enrichment value.

**Format:** Commit SHA (e.g., `"abc123def456"`)

**Usage:**
- Server-side: `process-enrichment-queue` Edge Function stamps each field with the current `PIPELINE_VERSION` env var
- Client-side: Ignored (for future use in selective re-enrichment)

**Example:**
```json
{
  "brawn": 45,
  "brawnEnrichver": "abc123def456",
  "wit": 30,
  "witEnrichver": "abc123def456",
  "speed": 15,
  "speedEnrichver": "abc123def456"
}
```

---

## Performance Optimizations

### Write Serialization (Web)

```dart
class _WriteSerializer {
  Future<T> run<T>(Future<T> Function() action) async {
    // Wait for previous write to complete
    while (_inFlight != null) {
      try {
        await _inFlight;
      } catch (_) {}
    }
    // Execute action
    final result = await action();
    // Yield to let IndexedDB persistence complete
    await Future.delayed(Duration.zero);
    return result;
  }
}
```

**Purpose:** Prevent concurrent IndexedDB writes on web (which produce `ConstraintError: Index key is not unique`).

### Batched Persistence

```dart
// Persist cell properties in batches of 5 with yields between batches
for (var i = 0; i < allToPersist.length; i++) {
  await persistCellProperties(...);
  if ((i + 1) % 5 == 0) {
    await Future<void>.delayed(Duration.zero);
  }
}
```

**Purpose:** On iOS IndexedDB-backed SQLite, each write takes 10–15ms. Batches of 5 = ~75ms per batch (under JANK threshold).

### Debounced Profile Persistence

```dart
// Debounce profile writes to 5s
profileDebounceTimer?.cancel();
profileDebounceTimer = Timer(const Duration(seconds: 5), () {
  persistProfileState(...);
});
```

**Purpose:** Accumulate rapid changes (distance ticks, cell visits) and persist once after 5 seconds of calm.

### Lazy Hydration

```dart
// Phase 1: SQLite → providers (fast, ~200ms)
// Phase 2: Supabase → SQLite (background, non-blocking)
// Game loop starts after Phase 1 completes
```

**Purpose:** Get player to map immediately with cached data. Supabase fetch picked up on next app launch.

---

## Error Handling

### SQLite Errors

```dart
try {
  await itemRepo.addItem(instance, userId);
} catch (e) {
  debugPrint('[GameCoordinator] failed to persist item: $e');
  obs?.event('persistence_error', {...});
  return; // Do not enqueue
}
```

**Result:** Item not persisted locally, not queued for sync.

### Enqueue Errors

```dart
try {
  await queueProcessor.enqueue(...);
} catch (e) {
  debugPrint('[GameCoordinator] failed to enqueue item: $e');
  obs?.event('persistence_error', {...});
}
```

**Result:** Item persisted locally but not queued. Will not sync until manually re-queued (not yet implemented).

### Sync Errors

```dart
// SyncException (network, Supabase down)
// → Increment attempts, retry up to 5 times
// → If max retries exceeded, mark rejected

// SyncValidationRejectedException (server validation failed)
// → Mark rejected immediately
// → Trigger local rollback (for items)
```

### Hydration Errors

```dart
try {
  await rehydrateData(userId);
} catch (e) {
  debugPrint('[GameCoordinator] failed to hydrate: $e');
  // Mark hydrated even on failure so app progresses past LoadingScreen
  ref.read(playerProvider.notifier).markHydrated();
  startLoop();
}
```

**Result:** App continues with empty state (graceful degradation).

---

## Observability

### Structured Events

```dart
obs.event('sqlite_slow', {
  'operation': 'persist_item',
  'duration_ms': sw.elapsedMilliseconds,
});

obs.event('persistence_error', {
  'operation': 'persist_item',
  'entity_id': instance.id,
  'error': e.toString(),
});

obs.event('sync_flushed', {
  'confirmed': summary.confirmed,
  'rejected': summary.rejected,
  'retried': summary.retried,
  'stale_deleted': summary.staleDeleted,
});
```

**Destination:** `app_logs` table in Supabase (via `LogFlushService`)

### Debug Logs

```dart
debugPrint('[GameCoordinator] failed to persist item: $e');
debugPrint('[QueueProcessor] auto-flush complete: $summary');
debugPrint('[GameCoordinator] hydrating from Supabase for $userId...');
```

**Destination:** `app_logs` table in Supabase (via `DebugLogBuffer` + `LogFlushService`)

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
    // ... other overrides
  ],
);
```

### Offline Hydration Tests

**File:** `test/integration/offline_hydration_test.dart`

**Coverage:**
- Hydration without Supabase
- Item persistence in offline mode
- Write queue behavior when Supabase not configured

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

## References

- **Database schema:** `lib/core/database/app_database.dart`
- **Repositories:** `lib/core/persistence/*.dart`
- **Sync service:** `lib/features/sync/services/supabase_persistence.dart`
- **Queue processor:** `lib/features/sync/services/queue_processor.dart`
- **Persistence consumer:** `lib/core/state/persistence_consumer.dart`
- **Game coordinator:** `lib/core/state/game_coordinator_provider.dart`
- **Tests:** `test/integration/*.dart`
