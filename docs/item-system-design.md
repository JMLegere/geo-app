# Item System Design

> Every discoverable thing in EarthNova is an item. Items are unique instances with randomly-rolled affixes. Design jam decision (2026-03-06).

---

## Core Concept

**PoE / CryptoKitty model, not Stardew stacking.** Every item instance is unique — two Red Foxes found in different cells have different randomly-rolled stats. Items don't stack. Rarity gates affix pool depth. Breeding combines traits from two parents.

**5 item categories:** Fauna, Flora, Mineral, Fossil, Artifact.

---

## Data Model

### ItemDefinition (Static Blueprint)

Loaded from bundled asset data. Immutable. One per species/item type.

```dart
sealed class ItemDefinition {
  final String id;                    // e.g. "fauna_vulpes_vulpes"
  final String displayName;           // "Red Fox"
  final String? scientificName;       // "Vulpes vulpes" (fauna/flora)
  final String? description;
  final ItemCategory category;        // fauna, flora, mineral, fossil, artifact
  final IucnStatus? rarity;           // gates affix pool depth
  final List<Habitat> habitats;       // where it spawns
  final List<Continent> continents;   // geographic filter
  final Season? seasonRestriction;    // null = year-round
  final List<String> contextTags;     // flexible metadata for filtering
}

enum ItemCategory { fauna, flora, mineral, fossil, artifact }
```

**Concrete types:**

| Type | Unique fields | Source |
|------|--------------|--------|
| `FaunaDefinition` | `taxonomicClass` | 32k IUCN dataset |
| `FloraDefinition` | `plantType` (tree, flower, fungus, etc.) | TBD dataset |
| `MineralDefinition` | `crystalSystem`, `hardness` | TBD dataset |
| `FossilDefinition` | `era`, `fossilType` | TBD dataset |
| `ArtifactDefinition` | `period`, `origin` | TBD dataset |

### ItemInstance (Unique Discovered Item)

Every discovery creates a new instance. No stacking — each is distinct.

```dart
@immutable
class ItemInstance {
  final String id;                    // UUID — globally unique
  final String definitionId;          // → ItemDefinition.id
  final List<Affix> affixes;          // randomly rolled prefix/suffix stats
  final String? parentAId;            // null for wild-caught
  final String? parentBId;            // null for wild-caught
  final DateTime acquiredAt;
  final String? acquiredInCellId;     // where it was found
  final String? dailySeed;            // seed used for this roll (server validation)
  final ItemInstanceStatus status;    // active, donated, placed, released, traded
}

enum ItemInstanceStatus { active, donated, placed, released, traded }
```

**Key properties:**
- Each instance has its own UUID — no two are the same
- Multiple instances of same definition allowed (3 Red Foxes, each with different affixes)
- `parentAId` / `parentBId` = null for wild-caught, populated for bred offspring
- `dailySeed` stored for server-side re-derivation and validation
- `status` tracks lifecycle (can't donate an already-donated item)

### Affix (Randomly-Rolled Stat Modifier)

PoE-style prefix/suffix system. CryptoKitty-style breeding traits.

```dart
@immutable
class Affix {
  final String id;                    // e.g. "swift", "ancient", "resilient"
  final AffixType type;               // prefix or suffix
  final Map<String, dynamic> values;  // flexible stat payload
}

enum AffixType { prefix, suffix }
```

**Affix rolling rules:**
- Rarity gates pool depth: LC = 0-1 affixes, NT = 1-2, VU = 2-3, EN = 3-4, CR = 4-5, EX = 5+
- Affix pool per rarity tier (definitions TBD, stored server-side)
- Roll is deterministic: `hash(dailySeed + cellId + definitionId)` → affix selection
- Server can re-derive the exact roll to validate offline claims

**What affixes ARE (TBD — placeholder concepts):**
- Prefixes: "Swift", "Ancient", "Luminous", "Colossal", "Shadow"
- Suffixes: "of Resilience", "of the Deep", "of Dawn", "of Stone"
- Values: numeric stats, visual modifiers, breeding trait flags
- Exact stat system to be designed — schema supports arbitrary key-value pairs

### Breeding

Two item instances → offspring with inherited/combined traits.

```dart
// Breeding input
class BreedingPair {
  final String parentAId;             // ItemInstance.id
  final String parentBId;             // ItemInstance.id
}

// Breeding output (server-generated)
class BreedingResult {
  final ItemInstance offspring;        // new instance with inherited affixes
  final List<Affix> inheritedFromA;   // which affixes came from parent A
  final List<Affix> inheritedFromB;   // which affixes came from parent B
  final List<Affix> mutations;        // new affixes from breeding (rare)
}
```

**Breeding rules (TBD):**
- Parents must be same category (fauna + fauna, not fauna + mineral)
- Same species? Different species? Cross-species? — TBD
- Trait inheritance: dominant/recessive? random mix? weighted by rarity?
- Mutations: small chance of new affix not present in either parent
- Server-validated (prevent impossible trait combinations)
- Offspring references both parents (`parentAId`, `parentBId`)

---

## Collection / Bundle System

Bundles = groupings of items with rewards. Stardew community center model.

```dart
@immutable
class ItemBundle {
  final String id;
  final String displayName;
  final String? description;
  final BundleType type;
  final List<BundleRequirement> requirements;
  final BundleReward? reward;
}

enum BundleType {
  museum,        // permanent donation (items consumed forever)
  npcRequest,    // NPC asks for specific items (items consumed)
  set,           // thematic collection (items NOT consumed, just tracked)
  achievement,   // milestone-based (no items consumed)
}

@immutable
class BundleRequirement {
  final String definitionId;          // which item type
  final int quantity;                 // how many instances needed
  final AffixRequirement? affixReq;  // optional: must have specific affix
}

sealed class BundleReward { ... }
// CurrencyReward, ItemReward, SanctuaryReward, AchievementReward, etc.
```

**Achievement examples:**
- "Discover 100 forest fauna" — tracks milestone, no item consumption
- "Donate one of each habitat type to museum" — tracks donations
- "Find a species with 5+ affixes" — tracks rare rolls

---

## Service Layer

### InventoryService (Pure Logic)

```dart
class InventoryService {
  List<ItemInstance> getByDefinition(List<ItemInstance> inv, String defId);
  List<ItemInstance> getByCategory(List<ItemInstance> inv, ItemCategory cat);
  List<ItemInstance> getActive(List<ItemInstance> inv);
  bool canCompletBundle(List<ItemInstance> inv, ItemBundle bundle);
}
```

### AffixRoller (Deterministic Rolling)

```dart
class AffixRoller {
  /// Roll affixes for a discovered item.
  /// Deterministic: same inputs → same output (for server validation).
  List<Affix> roll({
    required String dailySeed,
    required String cellId,
    required String definitionId,
    required IucnStatus rarity,
  });
}
```

### BreedingService (Server-Validated)

```dart
class BreedingService {
  /// Compute offspring traits from two parents.
  /// Server runs this — client sends breeding request, server returns result.
  BreedingResult breed({
    required ItemInstance parentA,
    required ItemInstance parentB,
    required String breedingSeed,   // server-provided
  });
}
```

### DailySeedService

```dart
class DailySeedService {
  /// Fetch today's seed from server. Cache locally (24h TTL).
  Future<String> getSeed();

  /// Validate an offline roll against the seed.
  bool validateRoll({
    required String seed,
    required String cellId,
    required String definitionId,
    required List<Affix> claimedAffixes,
  });
}
```

---

## Database Schema

### Drift (SQLite — local cache)

```dart
@DataClassName('LocalItemInstanceData')
class LocalItemInstanceTable extends Table {
  TextColumn get id => text()();                              // UUID
  TextColumn get userId => text()();
  TextColumn get definitionId => text()();
  TextColumn get affixes => text()();                         // JSON array
  TextColumn get parentAId => text().nullable()();
  TextColumn get parentBId => text().nullable()();
  DateTimeColumn get acquiredAt => dateTime()();
  TextColumn get acquiredInCellId => text().nullable()();
  TextColumn get dailySeed => text().nullable()();
  TextColumn get status => text()();                          // enum name

  @override
  Set<Column> get primaryKey => {id};
}
```

### Supabase (source of truth)

```sql
create table item_instances (
  id uuid primary key,
  user_id uuid references auth.users not null,
  definition_id text not null,
  affixes jsonb not null default '[]',
  parent_a_id uuid references item_instances,
  parent_b_id uuid references item_instances,
  acquired_at timestamptz not null default now(),
  acquired_in_cell_id text,
  daily_seed text,
  status text not null default 'active',
  created_at timestamptz not null default now()
);

-- RLS: users can only read/write their own items
alter table item_instances enable row level security;
create policy "users own their items"
  on item_instances for all
  using (auth.uid() = user_id);

-- Indexes for common queries
create index idx_items_user on item_instances(user_id);
create index idx_items_definition on item_instances(definition_id);
create index idx_items_status on item_instances(status);
```

---

## Riverpod Integration

```dart
final inventoryProvider = NotifierProvider<InventoryNotifier, List<ItemInstance>>(
  () => InventoryNotifier(),
);

class InventoryNotifier extends Notifier<List<ItemInstance>> {
  @override
  List<ItemInstance> build() {
    // Load from local cache (SQLite)
    // Server is source of truth — cache refreshed on connect
    return [];
  }

  void addItem(ItemInstance item) { ... }
  void updateStatus(String id, ItemInstanceStatus status) { ... }
  List<ItemInstance> getByDefinition(String defId) { ... }
  List<ItemInstance> getByCategory(ItemCategory cat) { ... }
}
```

---

## Migration from Current System

**Current:** `CollectedSpecies` = binary flag per species x cell. 24 files consume this model.

**Migration path:**

| Step | Change | Impact |
|------|--------|--------|
| 1 | Create `ItemDefinition` sealed class hierarchy | New files, no breaking changes |
| 2 | Create `ItemInstance` + `Affix` models | New files, no breaking changes |
| 3 | Add `LocalItemInstanceTable` to Drift schema | Schema migration, run `build_runner` |
| 4 | Create `InventoryNotifier` (parallel to existing `CollectionNotifier`) | New provider, no breaking changes |
| 5 | Migrate `DiscoveryService` to produce `ItemInstance` instead of `CollectedSpecies` | Breaking — discovery pipeline changes |
| 6 | Migrate consumers (pack, sanctuary, achievements) from collection → inventory | Breaking — UI layer changes |
| 7 | Remove old `CollectedSpecies` model + `CollectionRepository` | Cleanup |
| 8 | Data migration: existing collected species → ItemInstance with 0 affixes | One-time migration |

Steps 1-4 are additive (no breaking changes). Steps 5-7 are the breaking migration. Step 8 preserves existing player data.

---

## Open Questions

| Question | Impact | Notes |
|----------|--------|-------|
| What are the actual affix stats? | Affix `values` schema | Ecological theme — needs game design pass |
| Affix pool definitions per rarity tier | AffixRoller config | Stored server-side for easy tuning |
| Breeding rules (same species only? cross-species?) | BreedingService logic | CryptoKitty allows cross-breed, PoE doesn't |
| Dominant/recessive trait inheritance | BreedingService logic | Affects breeding strategy depth |
| Mutation rate on breeding | BreedingService config | How often new traits appear |
| Flora/Mineral/Fossil/Artifact datasets | Asset data | Need real-world sources like IUCN for fauna |
| Inventory limits | UX decision | Unlimited? Capacity upgrades? |
| "Best in class" display | UI feature | Show best roll per species? Compare rolls? |
| Item trading rules | Server validation | What can be traded? Level restrictions? |
