# Game Subsystem

Central game logic coordinator. Pure Dart — no Flutter, no Riverpod dependency.

---

## Purpose

GameCoordinator runs at ProviderScope level (never stops on tab switch) and owns:
- GPS stream subscription and error handling
- Game loop tick (~10 Hz throttle)
- Fog state computation via FogStateResolver
- Discovery event processing (rolls intrinsic affixes, creates ItemInstances)
- Output callbacks wired by gameCoordinatorProvider

The map screen is a pure renderer — it reads coordinator state and feeds rubber-band position updates back.

---

## Public API

### GameCoordinator

- `start(gpsStream, discoveryStream)` — subscribes to input streams, checks GPS permission
- `stop()` — cancels subscriptions, can restart
- `dispose()` — cancels subscriptions, closes streams permanently
- `updatePlayerPosition(double lat, double lon)` — called by rubber-band at 60fps, throttles game logic to ~10Hz

**Output Callbacks** (wired by gameCoordinatorProvider):
- `onPlayerLocationUpdate(Geographic, double)` → locationProvider
- `onGpsErrorChanged(GpsError)` → locationProvider error state
- `onCellVisited()` → playerProvider.incrementCellsObserved()
- `onItemDiscovered(DiscoveryEvent, ItemInstance)` → inventoryProvider + discoveryProvider

**Streams:**
- `onRawGpsUpdate` — broadcast (sync:true), `({Geographic position, double accuracy})` at 1Hz

### Enums

- `GpsError`: none, permissionDenied, permissionDeniedForever, serviceDisabled, lowAccuracy
- `GpsPermissionResult`: granted, denied, deniedForever, serviceDisabled

---

## Dual-Position Model

| Position | Source | Rate | Used For |
|----------|--------|------|----------|
| `rawGpsPosition` | GPS hardware | 1 Hz | Rubber-band target, GPS accuracy UI |
| `playerPosition` | Rubber-band feedback | 60 fps | ALL game logic (fog, discovery, cell transitions) |

**Critical:** ALL game logic uses `playerPosition`, NOT `rawGpsPosition`.

---

## Data Flow

```
GPS (1 Hz) → GameCoordinator._onRawGpsUpdate()
  ├─ stores rawGpsPosition + accuracy
  ├─ broadcasts onRawGpsUpdate (sync)
  └─ GPS accuracy check (real GPS only)

MapScreen subscribes → RubberBand.setTarget() → interpolates (60fps)
  → gameCoordinator.updatePlayerPosition(lat, lon)
    → throttle to ~10Hz (every 6th frame)
    → _processGameLogic()
      ├─ fogResolver.onLocationUpdate()
      └─ onPlayerLocationUpdate callback

Discovery: fogResolver.onVisitedCellAdded
  → DiscoveryService → DiscoveryEvent
  → GameCoordinator._onDiscovery()
    ├─ StatsService.rollIntrinsicAffix()
    ├─ creates ItemInstance with UUID
    └─ onItemDiscovered callback
```

---

## Conventions

- Game logic: every 6th frame (~10Hz). First call always processes. `_kGameLogicInterval = 6`
- `onRawGpsUpdate`: `StreamController.broadcast(sync: true)` — listeners must not do async
- `GpsError`/`GpsPermissionResult` mirror feature-layer enums to avoid core→features dependency
- Discovery: rolls intrinsic affix, creates ItemInstance with UUID + affixes + status=active
- Dependencies: FogStateResolver, StatsService (core only — no features/ imports)

---

## Provider Wiring

`gameCoordinatorProvider` (in `core/state/`) is the ONE justified exception to "core/ never imports features/":
- Reads `locationServiceProvider` for GPS stream
- Reads `discoveryServiceProvider` for discovery stream  
- Wires output callbacks to locationProvider, playerProvider, inventoryProvider, discoveryProvider

---

## Gotchas

- **Enum sync**: GpsError/GpsPermissionResult must stay in sync with feature-layer enums manually
- **First frame**: Frame counter starts at 0 — first `updatePlayerPosition()` always processes
- **Don't throttle externally**: MapScreen calls at 60fps — GameCoordinator handles its own throttling
- **stop() vs dispose()**: `stop()` allows restart, `dispose()` is permanent (closes StreamController)
