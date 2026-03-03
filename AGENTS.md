# Agent Guidance

## Core Principles

- **Debug for root cause first**: When a feature misbehaves, add targeted logs to capture exact inputs/outputs, then apply 5-why analysis before changing logic.
- **Prefer high-signal logs**: Include HTTP status codes, response sizes, key config flags, and derived values (e.g., GPS accuracy, fog density, tile coordinates). Avoid noisy per-frame spam unless explicitly needed.
- **Respect API constraints**: If a paid API fails, fall back to free alternatives and log the attempted endpoint, why it failed, and what fallback was used.
- **Surface runtime values**: When changing defaults, log actual runtime values at startup so configuration overrides don't mask the change.
- **Keep changes reversible**: Guard new behaviors with feature flags and default to non-destructive fallbacks.

---

# Architecture / Design

## Runtime Shell (`FogOfWorldApp`)

- Initializes Riverpod providers (location, map, fog state, persistence).
- Boots MapLibre map widget, GPS tracker, fog overlay, and camera controller.
- Applies forced start location, zoom, and style overrides; logs initialization state.
- Manages app lifecycle: GPS permission requests, offline detection, sync queue.

## Map Layer (MapLibre + Impeller)

- **MapLibre**: Vector/raster tiles via Mapbox GL; API key via env/inspector; free-tier endpoints first with fallbacks; north-up orientation.
- **Impeller**: GPU-accelerated rendering for fog shader and cell overlays.
- Tile streaming on location change; prefetch 1-tile radius; anchor overlays to map center to avoid drift.
- Fog shader: 5 discrete states (Undetected, Unexplored, Hidden, Concealed, Observed) with density values [1.0, 0.75, 0.5, 0.25, 0.0].

## Location Tracking (`PlayerLocationTracker`)

- GPS init with fallback simulation (random walk); emits `OnLocationUpdated` events.
- Configurable speeds, start location, and logging verbosity.
- Handles iOS/Android permission requests; logs accuracy meters and timestamp.
- Detects canopy/indoor GPS degradation; triggers fallback to simulation if accuracy > 50m.

## Geo Mapping (`GeoReference`, `GeoUtils`)

- Mercator conversion, meters-per-unit scaling, origin setting.
- Helpers for meters ↔ lat/lon conversion and world-space offsets.
- Caches tile coordinates to avoid redundant calculations.

## Fog State System (`FogStateProvider`, `CellStateSystem`)

- **FogStateProvider**: Riverpod provider managing global fog state (current cell, revealed set, explored set).
- **CellStateSystem**: Event-driven state transitions on player movement.
  - Undetected → Unexplored (on entry)
  - Unexplored → Revealed (if within reveal radius of present cell)
  - Revealed → Explored (on sustained presence)
  - Explored → Present (on re-entry)
- Emits `OnCellStateChanged` events; updates view layer and persistence.

## Persistence Layer (`LocalFirstPersistence`, `SyncQueue`)

- **LocalFirstPersistence**: SQLite for explored/revealed cell IDs, species sightings, season state.
- **SyncQueue**: Offline-first event queue; syncs to Supabase when online.
- Handles conflict resolution (last-write-wins for cell state; append-only for sightings).
- Logs cache hit rate, sync latency, and conflict count.

## View Layer (`CellTileView`, `FogOverlay`, `PlayerMarker`)

- **CellTileView**: Builds CustomPaint meshes per tile; materials map state to color/opacity.
- **FogOverlay**: Renders fog shader on top of map; updates density based on cell state.
- **PlayerMarker**: Indicates current position; pulses when in Present state.

## Camera Controller (`PlayerCameraFollower`)

- Follow/lock logic with optional heading alignment and zoom.
- Can be locked north-up with fixed position for debugging.
- Syncs with map camera; handles zoom constraints (min 12, max 18).

---

# Directory Structure

```
lib/
├── main.dart                          # App entry point
├── core/
│   ├── constants/
│   │   └── game_constants.dart        # kMaxSpecies, kBiomeCount, kFogLevels, etc.
│   ├── models/
│   │   ├── cell_state.dart            # CellState enum (Undetected, Unexplored, Hidden, Concealed, Observed)
│   │   ├── cell_data.dart             # CellData (id, latLon, polygon, neighbors, state)
│   │   ├── species.dart               # Species (id, name, biome, rarity, sightings)
│   │   └── location.dart              # Location (lat, lon, accuracy, timestamp)
│   ├── services/
│   │   ├── geo_reference.dart         # Mercator conversion, meters-per-unit
│   │   ├── geo_utils.dart             # Lat/lon ↔ meters, offset calculations
│   │   └── location_service.dart      # GPS init, permission handling
│   └── utils/
│       ├── logger.dart                # High-signal logging utilities
│       └── error_handler.dart         # Error recovery and fallback logic
├── features/
│   ├── map/
│   │   ├── providers/
│   │   │   ├── map_provider.dart      # MapLibre controller, tile state
│   │   │   └── camera_provider.dart   # Camera position, zoom, heading
│   │   ├── widgets/
│   │   │   ├── map_widget.dart        # MapLibre widget wrapper
│   │   │   └── fog_overlay.dart       # Fog shader overlay
│   │   └── services/
│   │       └── tile_loader.dart       # Tile fetching, caching, stitching
│   ├── location/
│   │   ├── providers/
│   │   │   └── location_provider.dart # GPS stream, fallback simulation
│   │   └── services/
│   │       └── player_location_tracker.dart
│   ├── fog/
│   │   ├── providers/
│   │   │   ├── fog_state_provider.dart    # Global fog state (current cell, revealed, explored)
│   │   │   └── cell_state_provider.dart   # Per-cell state management
│   │   ├── services/
│   │   │   └── cell_state_system.dart     # State transitions, event emission
│   │   └── widgets/
│   │       ├── cell_tile_view.dart        # CustomPaint cell rendering
│   │       └── player_marker.dart         # Current position indicator
│   ├── persistence/
│   │   ├── providers/
│   │   │   └── persistence_provider.dart  # SQLite access, cache
│   │   └── services/
│   │       ├── local_first_persistence.dart
│   │       └── sync_queue.dart            # Offline-first sync to Supabase
│   └── species/
│       ├── providers/
│       │   └── species_provider.dart      # Species list, sightings
│       └── widgets/
│           └── species_list.dart
├── shared/
│   ├── constants.dart                 # Game constants (kMaxSpecies, kBiomeCount, etc.)
│   ├── theme.dart                     # Colors, typography, fog state → color mapping
│   └── extensions.dart                # Utility extensions (LatLng, Duration, etc.)
└── app.dart                           # App widget, router setup

test/
├── core/
│   ├── services/
│   │   ├── geo_reference_test.dart
│   │   └── geo_utils_test.dart
│   └── utils/
│       └── logger_test.dart
├── features/
│   ├── fog/
│   │   └── services/
│   │       └── cell_state_system_test.dart
│   └── persistence/
│       └── services/
│           └── local_first_persistence_test.dart
└── fixtures/
    ├── mock_location.dart
    ├── mock_cell_data.dart
    └── mock_species.dart
```

---

# Key Patterns

## Riverpod Providers

- **StateNotifier providers**: Manage mutable state (fog state, camera position, sync queue).
- **FutureProvider**: Async operations (GPS init, tile fetch, Supabase sync).
- **StreamProvider**: Continuous streams (GPS location, map events, persistence changes).
- **Family modifiers**: Per-cell or per-tile state (e.g., `cellStateProvider.family(cellId)`).

Example:
```dart
final fogStateProvider = StateNotifierProvider<FogStateNotifier, FogState>((ref) {
  return FogStateNotifier(ref.watch(persistenceProvider));
});

final locationProvider = StreamProvider<Location>((ref) {
  return ref.watch(locationServiceProvider).locationStream;
});
```

## Local-First Persistence

- Write all state changes to SQLite immediately (optimistic updates).
- Queue sync events (explored cell, species sighting) for Supabase.
- On sync failure, retry with exponential backoff; log attempt count and error.
- On conflict (e.g., cell state changed remotely), apply last-write-wins for state, append-only for sightings.

Example:
```dart
// Local write
await persistence.markCellExplored(cellId);

// Queue sync
syncQueue.enqueue(SyncEvent.cellExplored(cellId));

// Sync on connectivity change
ref.watch(connectivityProvider).whenData((isOnline) {
  if (isOnline) syncQueue.flush();
});
```

## Event-Driven State Transitions

- Emit `OnCellStateChanged` events when a cell transitions.
- Listeners (view layer, persistence, analytics) react independently.
- Prevents tight coupling between systems.

Example:
```dart
class CellStateSystem {
  final _stateChangedStream = StreamController<CellStateChangeEvent>();
  
  void updatePlayerLocation(Location loc) {
    final cell = findContainingCell(loc);
    if (cell.state == CellState.unexplored) {
      cell.state = CellState.revealed;
      _stateChangedStream.add(CellStateChangeEvent(cell.id, CellState.revealed));
    }
  }
}
```

## High-Signal Logging

- Log GPS updates with accuracy, timestamp, and tile coordinate.
- Log tile requests with URL (masked key), HTTP status, response size, and texture dimensions.
- Log fog state transitions with cell ID, old state, new state, and trigger (e.g., "player entered").
- Log persistence operations with operation type, row count, and latency.
- Log sync events with event type, status (queued/sent/acked), and retry count.

Example:
```dart
logger.info(
  'GPS update: lat=${loc.latitude}, lon=${loc.longitude}, '
  'accuracy=${loc.accuracy}m, tile=[${tileX},${tileY}]'
);

logger.info(
  'Tile fetch: url=https://api.mapbox.com/...?key=*****, '
  'status=200, bytes=45678, texture=512x512'
);

logger.info(
  'Cell state transition: cellId=$cellId, '
  'old=${oldState.name}, new=${newState.name}, trigger=player_entered'
);
```

---

# Debugging Guide

## Widget Tree Inspection

**Problem**: Fog overlay not rendering or positioned incorrectly.

**Steps**:
1. Enable Flutter DevTools widget inspector: `flutter run --devtools`.
2. Inspect `FogOverlay` widget: verify it's mounted, not hidden by another widget, and has correct size/position.
3. Check `CustomPaint` bounds: log `size` in `paint()` method.
4. Verify `Impeller` is enabled: check `pubspec.yaml` for `flutter_gpu` dependency and `main.dart` for `enableImpeller: true`.

**High-signal logs**:
```dart
logger.info('FogOverlay mounted: size=${size.width}x${size.height}, '
  'offset=${offset.dx},${offset.dy}');
logger.info('Fog shader compiled: ${shader != null}');
```

## Riverpod Provider State Inspection

**Problem**: Fog state not updating when player moves.

**Steps**:
1. Add a debug widget that reads and displays `fogStateProvider`:
   ```dart
   Consumer(builder: (context, ref, child) {
     final fogState = ref.watch(fogStateProvider);
     return Text('Current cell: ${fogState.currentCell?.id}');
   });
   ```
2. Verify `locationProvider` is emitting updates: add a listener.
3. Check `CellStateSystem.updatePlayerLocation()` is being called: add a log.
4. Verify `FogStateNotifier` is updating state: log in `state = newState`.

**High-signal logs**:
```dart
logger.info('Location update: lat=${loc.latitude}, lon=${loc.longitude}');
logger.info('Cell lookup: found cellId=$cellId, state=${cell.state.name}');
logger.info('Fog state updated: currentCell=$cellId, '
  'revealed=${fogState.revealed.length}, explored=${fogState.explored.length}');
```

## Map Rendering Diagnostics

**Problem**: Map tiles not loading or fog shader not applying.

**Steps**:
1. Verify MapLibre controller is initialized: check `mapController != null` in `MapWidget.onMapCreated()`.
2. Check tile requests in network tab (DevTools → Network): verify URLs are valid and responses are non-empty PNGs.
3. Verify fog shader is compiled: check `Impeller` logs in console.
4. Temporarily disable fog overlay and verify map renders: if yes, focus on shader; if no, focus on tile loading.
5. Check map camera: verify zoom is in range [12, 18] and center is at player location.

**High-signal logs**:
```dart
logger.info('MapLibre initialized: zoom=${mapController.cameraPosition.zoom}, '
  'center=[${mapController.cameraPosition.target.latitude},'
  '${mapController.cameraPosition.target.longitude}]');

logger.info('Tile request: url=https://api.mapbox.com/...?key=****, '
  'status=200, bytes=45678');

logger.info('Fog shader applied: density=${fogDensity}, '
  'cellState=${cellState.name}');
```

## GPS Accuracy Logging

**Problem**: Player location jumps or drifts; GPS accuracy is poor.

**Steps**:
1. Log GPS updates with accuracy: `logger.info('GPS: lat=${loc.latitude}, lon=${loc.longitude}, accuracy=${loc.accuracy}m')`.
2. Check if accuracy > 50m: if yes, log a warning and consider switching to simulation.
3. Verify iOS/Android permissions are granted: check `location_service.dart` permission request logs.
4. Check for canopy/indoor GPS degradation: if accuracy degrades over time, log a warning.
5. Verify GPS is not being called too frequently: check `locationProvider` update frequency (should be ~1 Hz).

**High-signal logs**:
```dart
logger.info('GPS update: lat=${loc.latitude}, lon=${loc.longitude}, '
  'accuracy=${loc.accuracy}m, timestamp=${loc.timestamp}');

if (loc.accuracy > 50) {
  logger.warning('GPS accuracy poor (${loc.accuracy}m), switching to simulation');
}

logger.info('GPS permission: iOS=${iosPermission.name}, '
  'Android=${androidPermission.name}');
```

## Persistence Diagnostics

**Problem**: Cell state not persisting across app restarts; sync not working.

**Steps**:
1. Verify SQLite database is created: check `getApplicationDocumentsDirectory()` for `fog_of_world.db`.
2. Log persistence operations: `logger.info('Marked cell explored: cellId=$cellId, rows_affected=1')`.
3. Check sync queue: log enqueued events and sync attempts.
4. Verify Supabase connection: log auth token and sync endpoint.
5. Check for sync conflicts: log conflict resolution (last-write-wins, append-only).

**High-signal logs**:
```dart
logger.info('Persistence init: db_path=$dbPath, '
  'explored_count=${exploredCells.length}, revealed_count=${revealedCells.length}');

logger.info('Cell marked explored: cellId=$cellId, latency=${stopwatch.elapsedMilliseconds}ms');

logger.info('Sync event queued: type=${event.type}, '
  'queue_size=${syncQueue.length}');

logger.info('Sync attempt: status=sent, endpoint=https://..., '
  'retry_count=2, latency=${latency}ms');

logger.warning('Sync conflict: cellId=$cellId, '
  'local_state=${localState.name}, remote_state=${remoteState.name}, '
  'resolution=last_write_wins');
```

---

# Constraints

## Scope Ceilings

| Constraint | Value | Rationale |
|-----------|-------|-----------|
| Max species | 30 | Memory budget for species list; UI performance |
| Biomes | 5 | Manageable tile set; seasonal variation |
| Species per biome | 6 | Balanced discovery curve |
| Fog levels | 5 | Discrete visual states; shader complexity |
| Rarity tiers | 3 | Common, uncommon, rare; loot table simplicity |
| Seasons | 2 | Summer, winter; species availability |
| Max cells per tile | 100 | Mesh generation performance |
| Tile prefetch radius | 1 | Network bandwidth, memory cache |
| Sync retry limit | 5 | Prevent infinite retry loops |
| GPS update frequency | 1 Hz | Battery drain, state churn |

## Forbidden Patterns

- **No monolithic bootstrap**: Never create a single `FogOfWorldApp` class that initializes all systems. Use Riverpod providers instead.
- **No type-safety bypasses**: Never use `dynamic` or `as` casts without explicit type guards. Use sealed classes and pattern matching.
- **No direct SQLite queries**: Always use `LocalFirstPersistence` abstraction; never call `database.rawQuery()` directly.
- **No blocking operations on main thread**: All I/O (GPS, network, SQLite) must be async via `FutureProvider` or `StreamProvider`.
- **No global state**: Never use static variables or singletons. Use Riverpod providers for all shared state.
- **No hardcoded constants**: All game constants must be in `lib/shared/constants.dart`.
- **No platform-specific code in business logic**: Isolate iOS/Android code in `location_service.dart` and `platform_channels.dart`.

---

# Known Risks

## Camera Sync (High)

**Risk**: Map camera and player position drift; fog overlay misaligned.

**Mitigation**:
- Anchor fog overlay to map center, not screen center.
- Sync camera updates with location updates (use `Riverpod.select()` to batch).
- Log camera position and player location on every update; alert if delta > 10m.

**Debugging**:
```dart
logger.info('Camera sync: map_center=[${mapCenter.latitude},${mapCenter.longitude}], '
  'player_loc=[${playerLoc.latitude},${playerLoc.longitude}], '
  'delta=${distance}m');
```

## Platform View Composition (High)

**Risk**: MapLibre (platform view) compositing with Impeller (GPU) causes flickering or black frames.

**Mitigation**:
- Use `AndroidViewSurface` (Android) and `UiKitView` (iOS) with `gestureRecognizers` to avoid input conflicts.
- Disable fog overlay during map panning; re-enable on pan end.
- Test on real devices (emulator compositing is unreliable).

**Debugging**:
```dart
logger.info('Platform view composition: android_surface=${androidSurface != null}, '
  'ios_view=${iosView != null}');
logger.warning('Flickering detected: frame_drop_count=$dropCount');
```

## GPS Accuracy Under Canopy (Medium)

**Risk**: GPS accuracy degrades under trees; player location jumps or drifts.

**Mitigation**:
- Log GPS accuracy on every update; switch to simulation if accuracy > 50m.
- Implement Kalman filter to smooth GPS noise.
- Allow manual location override for testing.

**Debugging**:
```dart
logger.info('GPS accuracy: ${loc.accuracy}m, '
  'using=${loc.accuracy < 50 ? "gps" : "simulation"}');
```

## iOS Permission Handling (Medium)

**Risk**: App crashes if GPS permission not granted; user experience broken.

**Mitigation**:
- Request permission on app launch; show explanation dialog.
- Fall back to simulation if permission denied.
- Log permission status on every app start.

**Debugging**:
```dart
logger.info('iOS permission: status=${permission.status.name}, '
  'isDenied=${permission.isDenied}, isPermanentlyDenied=${permission.isPermanentlyDenied}');
```

## Offline-First Sync (Medium)

**Risk**: Sync queue grows unbounded; conflicts between local and remote state.

**Mitigation**:
- Implement sync queue size limit (max 1000 events).
- Use last-write-wins for cell state; append-only for sightings.
- Log sync conflicts and resolution strategy.

**Debugging**:
```dart
logger.info('Sync queue: size=${syncQueue.length}, '
  'oldest_event_age=${oldestEvent.age.inSeconds}s');

logger.warning('Sync conflict: cellId=$cellId, '
  'local=${localState.name}, remote=${remoteState.name}, '
  'resolution=last_write_wins');
```

---

# Debugging Checklist

When a feature misbehaves:

1. **Capture exact inputs/outputs**: Log the player location, cell ID, fog state, and any API responses.
2. **Apply 5-why analysis**: Ask "why" 5 times to find root cause, not symptom.
3. **Isolate the system**: Disable unrelated features (fog overlay, sync, analytics) to narrow scope.
4. **Check constraints**: Verify no constraint violations (e.g., GPS update frequency, tile prefetch radius).
5. **Verify reversibility**: Ensure any fix can be toggled off via a feature flag.
6. **Log the fix**: Document the root cause and mitigation in this file.

---

# Future Work

- **Real tile provider**: Replace mock cell grid with MBTiles or Mapbox API; implement point-in-polygon checks.
- **Species discovery**: Implement species sighting mechanics; integrate with Supabase for leaderboards.
- **Seasonal variation**: Implement season transitions; vary species availability by season.
- **Multiplayer**: Add real-time player tracking via Supabase; implement cell ownership and trading.
- **Analytics**: Track player movement, species discoveries, and engagement metrics.
