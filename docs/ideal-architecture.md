# Ideal Architecture

> Where the architecture should evolve. Joint decisions from the design jam (2026-03-06). For how it works today, see [current-architecture.md](current-architecture.md). For implementation order, see the Technical Roadmap in [roadmap.md](roadmap.md).

---

## Design Principles

1. **Server-authoritative.** Supabase is the source of truth. SQLite is a local cache and offline write queue.
2. **Offline-resilient.** Read-only offline. Client rolls encounters using cached daily seed (24h grace). Server validates on reconnect.
3. **Everything is an item.** Species, plants, minerals, fossils, artifacts — all items. Each instance has unique randomly-rolled affixes. Collections are bundles of items.
4. **The map is a renderer, not an orchestrator.** Game logic lives in GameCoordinator. Map renders the result.
5. **Build for the endgame.** Schema and services designed for the full product vision (5 item categories, breeding, NPCs, quests, trading, social).

---

## Target System Diagram

```
┌──────────────────────────────────────────────────────────────────┐
│                         Flutter App                               │
│                                                                   │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────┐ │
│  │ Map Screen  │  │ Home Screen│  │ Town Screen│  │ Pack Screen│ │
│  │ (renderer)  │  │ (sanctuary)│  │ (NPCs)     │  │ (inventory)│ │
│  └─────┬───────┘  └─────┬──────┘  └─────┬──────┘  └─────┬──────┘ │
│        └────────────────┼────────────────┼───────────────┘        │
│                         │                                         │
│  ┌──────────────────────▼──────────────────────────────────────┐ │
│  │                  GameCoordinator                             │ │
│  │  Pure Dart service. Owns GPS → game logic → write queue.    │ │
│  │  Runs independently of any screen. Never stops on tab switch.│ │
│  └──────────────────────┬──────────────────────────────────────┘ │
│                         │                                         │
│  ┌──────────────────────▼──────────────────────────────────────┐ │
│  │                  Domain Services                             │ │
│  │  FogService · CellService · SpeciesService · LootService    │ │
│  │  SeasonService · BiomeService · BreedingService             │ │
│  │  AffixRoller · DailySeedService                             │ │
│  └──────────────────────┬──────────────────────────────────────┘ │
│                         │                                         │
│  ┌──────────────────────▼──────────────────────────────────────┐ │
│  │                  State Layer (Riverpod)                       │ │
│  │  Notifiers project from server state + local cache.          │ │
│  │  UI watches notifiers. GameCoordinator emits via Stream.     │ │
│  └──────────────────────┬──────────────────────────────────────┘ │
│                         │                                         │
│  ┌──────────────────────▼──────────────────────────────────────┐ │
│  │                  Persistence                                  │ │
│  │  SQLite (local cache) · Write Queue · Repositories          │ │
│  └──────────────────────┬──────────────────────────────────────┘ │
│                         │                                         │
│  ┌──────────────────────▼──────────────────────────────────────┐ │
│  │                  Server (Supabase)                            │ │
│  │  Source of truth. Auth · Game state · Daily seed ·           │ │
│  │  Encounter validation · Leaderboards · Social                │ │
│  └──────────────────────────────────────────────────────────────┘ │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │                  External                                     │ │
│  │  GPS (device) · Tile Provider · Weather API (future)         │ │
│  └──────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────┘
```

---

## Key Architectural Shifts

### 1. Server-Authoritative with Offline Resilience

**Current:** SQLite is source of truth. Supabase is optional write-through backup.
**Ideal:** Supabase is source of truth. SQLite is local cache + offline write queue.

```
ONLINE FLOW:
  Player enters cell → client sends claim to server →
  server rolls encounter (or validates client roll) →
  server writes to DB → server responds with confirmed discovery →
  client caches in SQLite → UI shows discovery

OFFLINE FLOW:
  Player enters cell → client rolls encounter using cached daily seed →
  UI shows discovery (optimistic, marked "syncing...") →
  action queued in local write queue →
  on reconnect: queue flushes to server →
  server re-derives roll from seed + cellId →
  match? confirmed. mismatch? rolled back.
```

**Daily seed system:**
- Server generates a seed per calendar day (midnight GMT rotation)
- Client fetches seed on app open (cached locally)
- Same seed + same cellId + same algorithm = same result for all players
- Enables deterministic offline encounters AND server validation
- Creates "Wordle effect" — social sharing of daily finds
- Seed cached for 24h — offline grace period until next rotation
- Stale seed (next day, still offline) → discoveries pause

**Write queue:**
- Temporary outbox of "actions taken offline that server doesn't know about"
- Stored in SQLite (survives app restart)
- Flushed on reconnect, deleted after server confirms
- NOT a permanent event log — server is the permanent record
- Queue entries: `{ type, payload, timestamp, status: pending|confirmed|rejected }`

**What works offline (read-only from cache):**
- Walk around, see cached map tiles
- Fog animates visually (doesn't persist until confirmed)
- Browse existing collection, sanctuary, pack
- View cached leaderboards, stats
- Camera / photograph

**What requires server (writes to permanent record):**
- Discover / collect items (with 24h seed-validated grace)
- Commit fog reveals (persist visited cells)
- Unlock achievements
- Restore cells
- Increment streaks
- Trade with other players
- Submit to leaderboards
- Complete NPC bundles / quests

### 2. Item Model — Unique Instances with Random Affixes

**Status:** Phase 1 COMPLETE. `ItemDefinition` (sealed), `ItemInstance`, `Affix`, and `inventoryProvider` are live.
**Remaining:** Affix rolling system, breeding, bundles, museum donations.

**5 item categories:**

| Category | Source | Examples |
|----------|--------|---------|
| Fauna | 32k IUCN dataset | Red Fox, Amur Leopard, Blue Whale |
| Flora | TBD dataset | Chanterelle, Oak, Venus Flytrap |
| Mineral | TBD dataset | Quartz, Obsidian, Emerald |
| Fossil | TBD dataset | Ammonite, Trilobite, T-Rex Tooth |
| Artifact | TBD dataset | Arrowhead, Roman Coin, Pottery Shard |

**Item instance model:**

```dart
// Static blueprint (loaded from asset data)
sealed class ItemDefinition {
  String id;
  String displayName;
  ItemCategory category;       // fauna, flora, mineral, fossil, artifact
  IucnStatus? rarity;          // gates affix pool depth
  List<Habitat> habitats;
  List<Continent> continents;
  Season? seasonRestriction;
  List<String> contextTags;    // flexible metadata
}

// Concrete types
class FaunaDefinition extends ItemDefinition { ... }
class FloraDefinition extends ItemDefinition { ... }
class MineralDefinition extends ItemDefinition { ... }
class FossilDefinition extends ItemDefinition { ... }
class ArtifactDefinition extends ItemDefinition { ... }

// Unique instance — each discovery is a distinct roll
class ItemInstance {
  String id;                   // UUID
  String definitionId;         // → ItemDefinition
  List<Affix> affixes;         // randomly rolled prefix/suffix stats
  String? parentAId;           // null for wild-caught
  String? parentBId;           // null for wild-caught
  DateTime acquiredAt;
  String? acquiredInCellId;
  String? dailySeed;           // seed used for this roll (for validation)
}

// Affix — arbitrary stat modifier
class Affix {
  String key;                  // e.g. "swift", "resilient", "ancient"
  AffixType type;              // prefix or suffix
  Map<String, dynamic> values; // flexible stat payload
}
```

**Key properties:**
- Items do NOT stack — each instance is unique (different affixes)
- Multiple instances of same species allowed (3 Red Foxes, each different)
- Rarity (IUCN status) gates affix pool: LC = 0-1 affixes, CR/EX = more/better
- Breeding: two instances → offspring inherits/combines traits (parent_a + parent_b)
- Collections/bundles: groupings of items with reward on completion
- Achievements: track item milestones ("discover 100 forest fauna")

### 3. GameCoordinator — Extract from Map Screen

**Current:** `map_screen.dart` (25 files) is a god feature. Owns GPS, fog, discovery, camera, streaks, rendering. Everything stops when map unmounts.
**Ideal:** GameCoordinator is a pure Dart service that runs above the UI.

```
GameCoordinator (pure Dart, no Riverpod dependency):
  OWNS:
    - GPS subscription lifecycle
    - Game loop tick (~10 Hz, throttled from GPS 1 Hz)
    - Fog state computation (visual + pending confirmation)
    - Discovery processing (roll items on cell visit)
    - Write queue management (queue offline, flush on reconnect)
    - Connectivity monitoring (online/offline state)
    - Daily seed cache (fetch on connect, use offline)
    - Streak tracking
    - Restoration progress

  DOES NOT OWN:
    - Map rendering (MapLibre, GeoJSON layers)
    - Widget state, navigation
    - Camera position/mode
    - Toast/notification UI
    - RubberBand interpolation (stays in map for 60fps rendering)

  EMITS:
    - Stream<GameState> — notifiers project from this
    - Discovery events — UI subscribes for toasts
    - Connectivity state changes
    - Write queue status (pending count, flush progress)

  LIFECYCLE:
    - Created at app start (ProviderScope level)
    - Runs forever — never stops on tab switch
    - Disposes on app shutdown
```

**Directory:**
```
lib/core/game/
  ├── game_coordinator.dart     # Pure Dart service
  ├── game_state.dart           # Immutable state class
  ├── write_queue.dart          # Offline action queue
  └── daily_seed_service.dart   # Seed fetch/cache/validate
```

**Map screen becomes renderer only:**
```
MapScreen:
  - Reads fog state from GameCoordinator stream → renders GeoJSON layers
  - Reads player position → renders marker via RubberBand (60fps)
  - Reads camera mode → controls MapLibre camera
  - Zero game logic
```

### 4. Persistence — Server-First with Local Cache

**Current:** 3 SQLite tables (profile, cell progress, collected species). Write-through to Supabase.
**Ideal:** Server-first. SQLite mirrors server state + holds write queue.

**Local SQLite schema (cache + queue):**

```
-- Cache of server state
item_definitions        -- static blueprints (loaded from bundled assets)
item_instances          -- player's inventory (mirror of server)
cell_progress           -- visited cells, fog state, restoration
player_profile          -- stats, streaks, distance

-- Offline write queue
write_queue             -- pending actions for server
  id TEXT PK
  type TEXT              -- 'discover', 'visit_cell', 'breed', etc.
  payload TEXT           -- JSON
  created_at DATETIME
  status TEXT            -- 'pending', 'confirmed', 'rejected'
  daily_seed TEXT        -- seed used (for validation)

-- Local-only
daily_seed_cache        -- current seed + expiry
```

**Supabase schema (source of truth):**

```
-- Auth (existing)
auth.users

-- Game state
item_instances          -- all player items, server-authoritative
cell_visits             -- visited cells per player
player_profiles         -- stats, streaks
achievements            -- unlocked achievements

-- Game config (server-owned)
daily_seeds             -- seed per day, generated by server
affix_pools             -- affix definitions per rarity tier (future)

-- Social (future)
leaderboards
trades
sanctuary_visits
```

**Sync flow:**
```
App open → fetch daily seed + latest state from server → cache in SQLite
Action (online) → server validates → writes to Supabase → updates local cache
Action (offline) → write queue → flush on reconnect → server validates → cache updated
Rejected action → remove from local cache → UI rolls back
```

---

## Future Systems (Schema-Ready, Not Yet Implemented)

### Breeding System
- Two item instances → offspring with inherited/combined traits
- `parent_a_id` + `parent_b_id` on ItemInstance (null for wild-caught)
- Trait inheritance rules TBD
- Server-validated (prevent impossible trait combinations)

### Collection / Bundle System
- Bundles = groupings of items with rewards (Stardew community center style)
- `ItemCollection { id, requirements: List<ItemRequirement>, reward }`
- Completing a bundle = submit items → receive reward
- Museum donations = permanent bundle (items consumed, never returned)

### Achievement System
- Track item-related milestones ("discover 100 forest fauna")
- Server-side evaluation (anti-cheat)
- Achievement definitions stored server-side (can add new ones without app update)

### NPC System
- Discoverable NPCs on map (location-based spawning)
- Dialogue, quests, bundle requests
- NPC state persisted server-side

### Quest / Treasure Map System
- NPC-issued or exploration-dropped quests
- "Go to cell X, find species Y" directed exploration
- Rewards: rare items, sanctuary progression, NPC relationship

### Trading System
- Player-to-player item trading (online only)
- Server mediates (prevents duplication, validates ownership)

### Leaderboards
- Server-aggregated rankings
- Categories: total species, rarest find, most cells explored, etc.

---

## Migration Strategy

Prioritized by dependency order:

| Phase | Change | Enables |
|-------|--------|---------|
| **1** | Item model (sealed classes, instance schema, affix system) | Everything downstream — this is the foundation |
| **2** | GameCoordinator (extract from map_screen) | Background discoveries, tab-independent game loop |
| **3** | Server-authoritative persistence (Supabase source of truth, write queue) | Online validation, daily seed, anti-cheat |
| **4** | Daily seed system (server-generated, client-cached, 24h grace) | Deterministic encounters, social "Wordle effect" |
| **5** | Breeding system | Trait inheritance, offspring generation |
| **6** | Collections / bundles / museum | Stardew-style community center |
| **7** | Social features (leaderboards, trading, sanctuary visits) | Multiplayer |

Each phase is independently shippable. Phase 1 is the prerequisite for everything.

---

## Open Questions (TBD)

| Question | Impact | Notes |
|----------|--------|-------|
| What are the actual affix stats? | Item schema `values` field | Ecological theme — "swift", "resilient", "ancient"? |
| Affix rolling algorithm / weighting | AffixRoller service | Rarity gates pool depth, but exact weights TBD |
| Breeding trait inheritance rules | BreedingService | CryptoKitty-style dominant/recessive? Random mix? |
| Server plausibility checks beyond seed | Supabase Edge Functions | GPS speed limits? Time-based checks? |
| Flora/Mineral/Fossil/Artifact datasets | Asset data files | Need real-world data sources like IUCN for fauna |
| Decoration items | Schema supports it, no design yet | Sanctuary furniture/cosmetics |
| Inventory limits | UX decision | Unlimited? Capacity upgrades? |
| "Best in class" / favorite / pinned UX | UI feature | Display best roll vs all rolls |
| Map tile offline caching | MapLibre OfflineManager | "Download for offline" feature |
| Background execution (app backgrounded) | Platform services | Android WorkManager / iOS BackgroundModes |
