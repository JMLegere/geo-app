# Ideal Architecture

> Where the architecture should evolve for the current product vision. For how it works today, see [current-architecture.md](current-architecture.md). For the implementation bridge, see the Technical Roadmap in [roadmap.md](roadmap.md).

---

## Design Principles

1. **Offline-first remains non-negotiable.** SQLite is always the source of truth. Cloud is a replication target, not a dependency.
2. **Event-sourced state.** Every meaningful game action produces a domain event. State is derived from events. This enables sync, replay, undo, and audit.
3. **Features are autonomous.** No god feature. Each feature owns its slice of the game loop and can be enabled/disabled independently.
4. **Data scales lazily.** Species, cells, and game content load on-demand, not at startup. The app should handle 100k+ records without startup cost.
5. **The map is a renderer, not an orchestrator.** Game logic lives in services. The map renders the result.

---

## Target System Diagram

```
┌──────────────────────────────────────────────────────────────┐
│                       Flutter App                             │
│                                                               │
│  ┌─────────────┐  ┌──────────────┐  ┌────────────────────┐  │
│  │  Map Screen  │  │  Pack Screen  │  │  Museum / Town     │  │
│  │  (renderer)  │  │  (inventory)  │  │  Sanctuary Screen  │  │
│  └──────┬───────┘  └──────┬───────┘  └────────┬───────────┘  │
│         │                 │                    │              │
│  ┌──────▼─────────────────▼────────────────────▼───────────┐ │
│  │                Feature Coordinators                      │ │
│  │  ExplorationCoordinator · DiscoveryCoordinator           │ │
│  │  InventoryCoordinator · MuseumCoordinator                │ │
│  │  NPCCoordinator · QuestCoordinator                       │ │
│  └──────────────────────┬──────────────────────────────────┘ │
│                         │                                     │
│  ┌──────────────────────▼──────────────────────────────────┐ │
│  │                   Domain Services                        │ │
│  │  FogService · CellService · SpeciesService               │ │
│  │  LootService · SeasonService · BiomeService              │ │
│  │  StreakService · RestorationService                      │ │
│  └──────────────────────┬──────────────────────────────────┘ │
│                         │                                     │
│  ┌──────────────────────▼──────────────────────────────────┐ │
│  │                   Event Bus + State                       │ │
│  │  Domain Events → Event Store → Projections (Notifiers)   │ │
│  └──────────────────────┬──────────────────────────────────┘ │
│                         │                                     │
│  ┌──────────────────────▼──────────────────────────────────┐ │
│  │                   Persistence                             │ │
│  │  Event Store (SQLite) · Repositories · Sync Engine       │ │
│  └──────────────────────┬──────────────────────────────────┘ │
│                         │                                     │
│  ┌──────────────────────▼──────────────────────────────────┐ │
│  │                   External                                │ │
│  │  Supabase (sync) · GPS · Weather API · Tile Provider     │ │
│  └──────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
```

---

## Key Architectural Shifts

### 1. Event-Sourced State (biggest change)

**Current:** Notifiers hold state. Persistence is a manual afterthought.
**Ideal:** Every game action emits a domain event. Notifiers project from events.

```
Domain Events (append-only):
  SpeciesCollected { cellId, speciesId, quantity, timestamp }
  CellVisited { cellId, position, timestamp }
  StreakUpdated { current, longest, timestamp }
  SpeciesDonated { speciesId, museumWing, timestamp }
  SpeciesPlaced { speciesId, sanctuaryTile, timestamp }
  SpeciesReleased { speciesId, timestamp }
  QuestAccepted { questId, npcId, timestamp }
  QuestCompleted { questId, reward, timestamp }
  NPCDiscovered { npcId, location, timestamp }
  ...

Event Store (SQLite table):
  id | type | payload (JSON) | timestamp | synced

Projections (Notifiers rebuild from events):
  InventoryNotifier → replay SpeciesCollected/Donated/Placed/Released → current inventory
  FogNotifier → replay CellVisited → visited set → compute fog (unchanged)
  AchievementNotifier → replay all events → evaluate achievements
```

**Why this matters:**
- **Sync becomes event replication.** Send unsent events to Supabase. Receive events from other devices. Merge by timestamp.
- **No data loss.** Every action is logged. Achievement state survives restart.
- **Undo is free.** Remove last event, re-project.
- **Analytics is free.** Events ARE the analytics.

**Migration path:** Start with `SpeciesCollected` events (needed for inventory model). Expand to other events incrementally. Existing notifiers become projections over the event store instead of standalone state holders.

### 2. Feature Coordinators (decompose the god feature)

**Current:** `map_screen.dart` runs GPS, game logic, fog, discovery, camera, rendering.
**Ideal:** Coordinators own game logic. Screens are pure renderers.

```
ExplorationCoordinator (lives in core/, not features/):
  - Owns GPS subscription lifecycle
  - Runs game loop tick (fog computation, cell visits)
  - Independent of any screen — runs even when map isn't visible
  - Emits domain events (CellVisited, FogUpdated)

DiscoveryCoordinator:
  - Listens to CellVisited events
  - Runs species loot rolls
  - Emits SpeciesCollected events
  - Handles daily seed rotation

InventoryCoordinator:
  - Manages species inventory (add, donate, place, release)
  - Emits SpeciesDonated, SpeciesPlaced, SpeciesReleased events
  - Enforces museum permanence rule

MapScreen (renderer only):
  - Reads fog state → renders GeoJSON layers
  - Reads player position → renders marker
  - Reads camera mode → controls MapLibre camera
  - Zero game logic
```

**Why this matters:**
- Map screen stays small and focused
- Discovery works even when map isn't mounted (background mode)
- New mechanics (quests, NPCs, weather) get their own coordinators instead of growing map_screen
- Each coordinator is independently testable

### 3. Inventory Model (species as items)

**Current:** Binary collection — `CollectedSpecies` is a unique flag per species × cell.
**Ideal:** Quantity-tracked inventory items that can be consumed.

```
Inventory Item:
  speciesId: String
  quantity: int
  instances: List<{cellId, collectedAt, dailySeed?}>

Operations:
  collect(speciesId, cellId) → quantity++
  donate(speciesId, museumWing) → quantity-- (permanent, emits SpeciesDonated)
  place(speciesId, sanctuaryTile) → quantity-- (flexible, emits SpeciesPlaced)
  release(speciesId) → quantity-- (permanent, emits SpeciesReleased)
  retrieve(speciesId, sanctuaryTile) → quantity++ (sanctuary placement is reversible)
```

**DB schema change:** Either add `quantity` column to existing table, or move to instance-based tracking (one row per collected instance) for richer metadata.

**Downstream impact:** Every consumer of `collectionProvider` needs updating — pack, sanctuary, achievements, discovery, sync.

### 4. Lazy Species Data

**Current:** 6 MB JSON loaded into memory at startup.
**Ideal:** Indexed SQLite table queried on-demand.

```
species table (SQLite, populated from JSON on first launch):
  scientificName TEXT PK
  commonName TEXT
  taxonomicClass TEXT
  iucnStatus TEXT
  -- Indexed for loot table queries:
  CREATE INDEX idx_species_habitat ON species_habitats(habitat)
  CREATE INDEX idx_species_continent ON species_continents(continent)
  CREATE INDEX idx_species_status ON species(iucnStatus)

species_habitats (many-to-many):
  speciesName TEXT FK
  habitat TEXT

species_continents (many-to-many):
  speciesName TEXT FK
  continent TEXT
```

**Why:** Startup time, memory, and extensibility. Adding 50k plant/mineral/fossil records to a monolithic JSON is unsustainable. SQLite handles 100k+ records with indexed queries in milliseconds.

**Migration path:** Import JSON → SQLite on first launch (one-time migration). Keep JSON as the distribution format, SQLite as the runtime format.

### 5. Sync Engine

**Current:** Fire-and-forget write-through to Supabase. No queue, no retry, no conflict resolution.
**Ideal:** Offline queue with reliable sync.

```
Sync Engine:
  1. Local write → SQLite event store (always succeeds)
  2. Background worker picks up unsynced events
  3. Batch upload to Supabase (with retry + exponential backoff)
  4. Mark events as synced
  5. Pull remote events (from other devices) → merge into local store
  6. Conflict resolution: timestamp-based last-write-wins (simple, predictable)

Sync States:
  synced | pending | failed | conflicted

Observability:
  SyncStatusNotifier provides: pendingCount, lastSyncAt, errors
```

**Why:** Multi-device support (play on phone, check museum on web). Reliable data preservation. Foundation for real-time features.

---

## New Systems Architecture

### Museum System

```
MuseumService (pure domain logic):
  - 7 fauna wings + 3 future non-fauna wings
  - Wing unlock thresholds (donation milestones)
  - Donation slot mapping (species → eligible wings via habitat)
  - Permanent donation enforcement

MuseumNotifier (projection):
  - Rebuilds from SpeciesDonated events
  - Tracks: donated species per wing, unlock state, completion %

Museum DB:
  museum_donations: speciesId, wing, donatedAt (append-only, never delete)
  museum_wings: wing, unlocked, unlockedAt
```

### NPC System

```
NPCService:
  - NPC definitions (name, personality, dialogue trees, portrait, location)
  - Spawn conditions: milestone-based + location-based
  - Discovery evaluation (like achievement checks — pull-based)

NPCNotifier (projection):
  - Rebuilds from NPCDiscovered events
  - Tracks: discovered NPCs, conversation state, active quests

NPC DB:
  discovered_npcs: npcId, discoveredAt, location
  npc_conversations: npcId, dialogueNodeId, timestamp
```

### Quest System

```
QuestService:
  - Quest/treasure map generation from NPC requests, exploration drops, milestones
  - Quest objective evaluation (arrive at location + find species)
  - Reward calculation

QuestNotifier (projection):
  - Rebuilds from QuestAccepted/QuestCompleted events
  - Tracks: active quests, completed quests, available maps

Quest DB:
  quests: questId, type, objective (JSON), sourceNpcId, reward (JSON), status, expiresAt
  treasure_maps: questId, targetLat, targetLon, targetSpeciesId
```

### Daily Seed System

```
DailySeedService:
  - seed = SHA-256(dateString + cellId)
  - Generates daily species pool per cell (separate from permanent cell species)
  - Reset at midnight GMT
  - Deterministic: same cell + same day = same species for all players

Integration:
  - DiscoveryCoordinator checks both permanent (cell seed) and daily (date seed) pools
  - Daily species show indicator on map
  - Creates "Wordle effect" — social sharing of daily finds
```

---

## Migration Strategy

Prioritized by dependency order and product roadmap:

| Phase | Change | Enables |
|-------|--------|---------|
| **1** | Inventory model (schema + provider) | Museum, Pack redesign, NPC bundles, strategic collecting |
| **2** | Event store for SpeciesCollected | Reliable persistence, sync foundation, analytics |
| **3** | ExplorationCoordinator (extract from map) | Background discovery, cleaner map, new mechanics |
| **4** | Species data → SQLite | Daily seed, categories expansion, performance |
| **5** | Expand events to all domain actions | Full replay, achievement persistence, undo |
| **6** | Sync engine | Multi-device, real-time, reliable cloud backup |

Each phase is independently shippable. Phase 1 is the P0 prerequisite — everything else builds on inventory.

---

## Design Jam Questions

Things worth discussing before committing to implementation:

1. **Event sourcing granularity:** Full event sourcing (every action is an event) vs hybrid (events for sync-critical data, direct state for ephemeral)? Full is cleaner but more upfront work.

2. **Coordinator lifecycle:** Should coordinators run globally (like a game engine) or only when relevant screens are mounted? Global = discoveries happen in background. Mounted = simpler lifecycle but misses events.

3. **Species data format:** Keep JSON as distribution + import to SQLite at runtime? Or ship SQLite directly as an asset? JSON is human-editable, SQLite is faster to query.

4. **Sync conflict model:** Last-write-wins is simple but loses data. CRDT-style merge is robust but complex. For a cozy game, is last-write-wins good enough?

5. **Museum permanence:** If donations are permanent and event-sourced, should there be a "curator undo" NPC mechanic for regretted donations? Or is permanence the whole point (Stardew model)?

6. **How far to go right now?** The inventory model (Phase 1) is clearly next. But should we also lay event store foundations in the same pass, or is that over-engineering for the current stage?
