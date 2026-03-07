# Discovery Feature

Species encounter events when player enters cells. Dual-notifier pattern: DiscoveryNotifier (state) + notification overlay (toast queue).

## Architecture

- `DiscoveryService` (in map/providers/) — watches fogResolver, speciesService, habitatService, cellService, seasonService. Subscribes to fog state changes, emits discovery events.
- `DiscoveryNotifier` — manages notification queue and recent history
- `speciesDataProvider` — `FutureProvider<List<FaunaDefinition>>`, loads 32,752 IUCN records from `assets/species_data.json` via `rootBundle`
- `speciesServiceProvider` — `Provider<SpeciesService>`, watches speciesDataProvider and enrichmentMapProvider. Merges AI enrichments (animalClass, foodPreference, climate) into FaunaDefinition at load time. Returns empty SpeciesService([]) during loading/error, full dataset with enrichments when ready.

## Encounter Flow

1. Player enters new cell → fogResolver emits FogStateChangedEvent
2. DiscoveryService receives event → calls speciesService.getSpeciesForCell()
3. Species rolled deterministically (SHA-256 seeded by cellId)
4. GameCoordinator rolls intrinsic affix via StatsService, creates ItemInstance with UUID
5. gameCoordinatorProvider wires callbacks → discoveryProvider.notifier.showDiscovery() + inventoryProvider.notifier.addItem() + discoveryService.markCollected() + SQLite persistence
5b. gameCoordinatorProvider fires enrichmentService.requestEnrichment() (fire-and-forget) if species not yet enriched
6. DiscoveryNotificationOverlay displays toast

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

Three providers in `discovery_provider.dart`:

- `speciesDataProvider` (`FutureProvider`): Loads full IUCN dataset asynchronously from bundled JSON asset. Parsed by `SpeciesDataLoader.fromJsonString()`.
- `enrichmentMapProvider` (`FutureProvider`): Loads all cached enrichments from SQLite via `enrichmentRepositoryProvider`. Returns `Map<String, SpeciesEnrichment>` keyed by scientificName.
- `speciesServiceProvider` (`Provider`): Watches `speciesDataProvider` and `enrichmentMapProvider`, provides `SpeciesService` with the full dataset merged with AI enrichments. Empty fallback during loading/error — no encounters fire until asset is ready.

## Gotchas

- DiscoveryService lives in map/providers/ (not discovery/), because it depends on 5 map-related providers
- Species encounters are deterministic: same cellId always yields same species. This is by design.
- `speciesServiceProvider` is async-aware via `speciesDataProvider` FutureProvider — returns empty service during loading, full service when ready
- Season affects which species appear (80% year-round, 10% summer-only, 10% winter-only)
- Encounter slots per cell: 3 max (from kEncounterSlotsPerCell or default parameter)
- Tests must override `speciesServiceProvider` (not `speciesDataProvider`) to inject test fixtures

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
