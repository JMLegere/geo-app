# Discovery Feature

Species encounter events when player enters cells. Dual-notifier pattern: DiscoveryNotifier (state) + notification overlay (toast queue).

## Architecture

- `DiscoveryService` (in map/providers/) — watches fogResolver, speciesService, habitatService, cellService, seasonService. Subscribes to fog state changes, emits discovery events.
- `DiscoveryNotifier` — manages notification queue and history
- `speciesServiceProvider` — currently a dev fixture with inline JSON (will be async asset loader in production)

## Encounter Flow

1. Player enters new cell → fogResolver emits FogStateChangedEvent
2. DiscoveryService receives event → calls speciesService.getSpeciesForCell()
3. Species rolled deterministically (SHA-256 seeded by cellId)
4. DiscoveryEvent emitted on onDiscovery stream
5. map_screen subscribes → calls discoveryProvider.notifier.showDiscovery()
6. DiscoveryNotificationOverlay displays toast

## Dual Notifier Pattern

Same as achievements:
- `discoveryProvider` — NotifierProvider managing DiscoveryState (history, stats)
- Notification overlay reads from discoveryProvider and shows/dismisses toasts
- Queue-based: multiple discoveries can stack

## Species Service Provider

`speciesServiceProvider` in this feature provides the species pool:
- Currently: dev fixture with inline JSON (50 species from test fixtures)
- Production: will load from `assets/species_data.json` (32,752 records)
- Provides: `getSpeciesForCell()`, `getPoolForArea()`, `forHabitat()`, `forContinent()`, `all`, `totalSpecies`

## Gotchas

- DiscoveryService lives in map/providers/ (not discovery/), because it depends on 5 map-related providers
- Species encounters are deterministic: same cellId always yields same species. This is by design.
- `speciesServiceProvider` returns synchronously (no FutureProvider) — species data must be loaded before first use
- Season affects which species appear (80% year-round, 10% summer-only, 10% winter-only)
- Encounter slots per cell: 3 max (from kEncounterSlotsPerCell or default parameter)

## State Shape

```dart
class DiscoveryState {
  final List<DiscoveryEvent> history;
  final Map<String, int> speciesCountByHabitat;
  final int totalDiscoveries;
}
```

## Testing

- `test/features/discovery/` — service tests with mock dependencies
- `test/integration/discovery_workflow_test.dart` — full flow with real persistence
- Use `makeDiscoveryEvent()` factory for test fixtures
