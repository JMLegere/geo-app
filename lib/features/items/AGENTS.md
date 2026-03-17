# Items Feature

Item lifecycle management: the canonical collection of all `ItemInstance` objects the player owns or has interacted with. Provides `itemsProvider` (formerly `inventoryProvider`) and `StatsService` for deterministic stat rolling.

---

## Subdirectories

### providers/

- `itemsProvider`: `NotifierProvider<ItemsNotifier, ItemsState>` — item instances grouped by status. Formerly `inventoryProvider`/`InventoryNotifier`/`InventoryState` in `core/state/`.
- `ItemsState`: Immutable state with `items: List<ItemInstance>`, helpers for filtering by `ItemInstanceStatus`. `copyWith()` for updates.
- `ItemsNotifier`: Loads from `ItemInstanceRepository` on startup via `loadItems()`. Receives new discoveries from `GameCoordinator` callbacks. Updates item status (donate, place, release, trade).

### services/

- `StatsService`: Deterministic stat and weight rolling for item instances. Pure Dart, SHA-256 only (no `dart:math`). Moved from `core/species/`.
  - `rollIntrinsicAffix(scientificName, instanceSeed, {enrichedStats})` → `Affix` with `{speed, brawn, wit}` values. Base stats from enrichment (sum=90) get ±30 per-instance variance, clamped to [1, 100].
  - `rollWeightGrams(AnimalSize size, String instanceSeed)` → `int` grams. Domain-separated seed `"weight:$instanceSeed"`.
  - Without enrichment: fallback base stats (30, 30, 30). Without size: weight not rolled.

---

## Item Lifecycle

```
Wild (not owned)
  → Discovered → active (in Pack / Sanctuary)
  → donated (Museum — permanent)
  → placed (Sanctuary — visible on map)
  → released (returned to wild)
  → traded (exchanged with other player)
```

`ItemInstanceStatus` enum: `active`, `donated`, `placed`, `released`, `traded`.

---

## Item Locations

| Status | Where shown | Notes |
|--------|-------------|-------|
| `active` | Pack tab | Default after discovery |
| `placed` | Sanctuary (Home tab) | Player explicitly placed |
| `donated` | Museum (future) | Permanent, non-reversible |
| `released` | — | Removed from collection |
| `traded` | — | Future multiplayer feature |

---

## Conventions

- `loadItems()` replaces state entirely — call only on startup or after full re-sync. Discoveries during load window are queued and applied after hydration.
- `itemsProvider` is a global singleton (`NotifierProvider`, no `.autoDispose`).
- `StatsService` seed format for stats: `"$scientificName:$instanceSeed"` — changing this breaks all existing stat rolls.
- `StatsService` seed format for weight: `"weight:$instanceSeed"` — domain-separated from stats.
- `gameCoordinatorProvider` calls `itemsProvider.notifier` directly when a discovery fires.

---

## Gotchas

- Renamed from `inventoryProvider` → `itemsProvider`. Update all `ref.watch(inventoryProvider)` calls.
- `ItemsNotifier` replaces `InventoryNotifier`. `ItemsState` replaces `InventoryState`.
- `StatsService` moved from `core/species/` — update imports to `features/items/services/stats_service.dart`.
- Test file: `test/features/items/providers/items_provider_test.dart` (formerly inventory_provider_test).
- Test file: `test/features/items/services/stats_service_test.dart` (formerly in test/core/species/).
