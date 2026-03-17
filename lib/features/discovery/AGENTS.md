# Discovery Feature

Species encounter events when player enters cells. Dual-notifier pattern: DiscoveryNotifier (state) + notification overlay (toast queue).

## Architecture

- `DiscoveryService` (in map/providers/) — watches fogResolver, speciesService, habitatService, cellService, seasonService. Subscribes to fog state changes, emits discovery events.
- `DiscoveryNotifier` — manages notification queue and recent history
- `speciesServiceProvider` — `Provider<SpeciesService>`, watches `speciesCacheProvider` and `enrichmentMapProvider`. Returns `SpeciesService.fromCache()` when cache is loaded (with merged enrichments), otherwise empty `SpeciesService` (no encounters until loaded).

## Encounter Flow

1. Player enters new cell → fogResolver emits FogStateChangedEvent
2. DiscoveryService receives event → checks `cellPropertiesLookup(cellId)` for cell event
3. **No event** → normal `speciesService.getSpeciesForCell()` (habitat + continent + climate + season)
4. **Migration event** → `speciesService.getSpeciesForMigration()` — species from different continent, prefers different climate
5. **Nesting Site event** → `speciesService.getSpeciesForNestingSite()` — guaranteed EN/CR/EX species
6. Species rolled deterministically (SHA-256 seeded by dailySeed + cellId)
7. `DiscoveryEvent` created with `cellEventType` field (null for normal encounters)
8. GameCoordinator rolls intrinsic affix via StatsService, creates ItemInstance with UUID
9. gameCoordinatorProvider wires callbacks → discoveryProvider.notifier.showDiscovery() + inventoryProvider.notifier.addItem() + discoveryService.markCollected() + SQLite persistence
9b. gameCoordinatorProvider fires enrichmentService.requestEnrichment() (fire-and-forget) if species not yet enriched
10. DiscoveryNotificationOverlay displays toast

## Cell Properties Integration

**`cellPropertiesLookup`**: Mutable callback field on DiscoveryService. Type: `CellProperties? Function(String cellId)?`

**Wiring**: Set by `gameCoordinatorProvider` after both DiscoveryService and GameCoordinator are created. Points to `gameCoordinator.getCellProperties()`. Avoids circular provider dependency — callback only invoked at event time, never during construction.

**Event flow in `_onFogStateChanged()`**:
1. Lookup `CellProperties` for the visited cell via `cellPropertiesLookup`
2. If properties have an event → use event-specific species method
3. If no properties or no event → fall through to normal encounter
4. `DiscoveryEvent.cellEventType` records which event triggered (for UI display)

## Enrichment Integration

- `speciesServiceProvider` merges `enrichmentMapProvider` data into `FaunaDefinition` at load time
- Pattern: `enrichmentMapAsync.asData?.value ?? {}` — gracefully handles loading/error states
- When enrichment exists for a species, `FaunaDefinition.copyWith()` applies animalClass, foodPreference, climate
- Non-blocking: species service works with or without enrichments

## Dual Notifier Pattern

Same as achievements:
- `discoveryProvider` — NotifierProvider managing DiscoveryState (history + notification)
- Notification overlay reads from discoveryProvider and shows/dismisses toasts
- Queue-based: multiple discoveries can stack

## Species Service Provider

Two providers in `discovery_provider.dart`:

- `enrichmentMapProvider` (`FutureProvider`): Loads all cached enrichments from SQLite via `enrichmentRepositoryProvider`. Returns `Map<String, SpeciesEnrichment>` keyed by definitionId.
- `speciesServiceProvider` (`Provider`): Watches `speciesCacheProvider` and `enrichmentMapProvider`. Returns `SpeciesService.fromCache()` with merged enrichments when cache is loaded; empty `SpeciesService` otherwise.

## Gotchas

- DiscoveryService lives in map/providers/ (not discovery/), because it depends on 5 map-related providers
- Species encounters are deterministic: same cellId always yields same species. This is by design.
- `speciesServiceProvider` returns empty service until `speciesCacheProvider` is populated — no encounters fire until SQLite DB loads
- Season affects which species appear (80% year-round, 10% summer-only, 10% winter-only)
- Encounter slots per cell: 1 (kEncounterSlotsPerCell)
- Tests must override `speciesServiceProvider` to inject test fixtures
- `cellPropertiesLookup` is nullable — DiscoveryService works without it (falls through to normal encounters)
- Cell events REPLACE base encounters (not additive). If migration has no valid species, falls back to normal roll.
- `FaunaDefinition.climate` is nullable (AI-enriched) — migration prefers climate mismatch but falls back to full pool

## State Shape

```dart
class DiscoveryState {
  final List<DiscoveryEvent> recentDiscoveries;  // Last 20, newest first
  final bool hasActiveNotification;
  final DiscoveryEvent? currentNotification;
}
```

## Testing

- `test/features/discovery/` — service tests with mock dependencies
- `test/integration/discovery_workflow_test.dart` — full flow with real persistence
- Use `makeDiscoveryEvent()` factory for test fixtures
- Override `speciesServiceProvider` in tests — NOT `speciesDataProvider`
