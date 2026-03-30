# Camera System Design

> Replaces the ad-hoc camera code scattered across `map_screen.dart` and `camera_bounds_controller.dart`. Designed from Pokémon Go, Ingress, Google Maps, Apple Maps, Civilization, and Fog of World reference analysis.

## Status: Superseded by locked-follow camera. See docs/district-hierarchy-design.md

---

## 1. Current State (Audit)

### What exists

| Component | File | Lines | Role |
|-----------|------|-------|------|
| MapOptions.maxBounds | map_screen.dart | 18 | Hard camera bounds from detection zone |
| CameraBoundsController | camera_bounds_controller.dart | 116 | Computes bounds from district centroids |
| RubberBandController | rubber_band_controller.dart | 241 | 60fps interpolation between 1Hz GPS — **well-built, keep** |
| PlayerMarkerLayer | player_marker_layer.dart | 46 | Blue dot + pulse via WidgetLayer |
| DpadControls | dpad_controls.dart | 158 | On-screen d-pad for keyboard mode |
| Ad-hoc fitBounds | map_screen.dart (5 locations) | — | Scattered zoom-to-fit calls |

### What was deleted (PR #359)

- `CameraController` — follow/free mode toggle
- `CameraModeProvider` — CameraMode enum
- Follow mode entirely — replaced by free pan + native maxBounds

### Problems

1. **No camera state machine.** Behavior is implicit in scattered `fitBounds`/`moveCamera` calls.
2. **No follow mode.** Player walks off-screen with no recenter mechanism.
3. **No gesture detection.** Can't distinguish user pans from programmatic moves. (`MapEventStartMoveCamera` with `CameraChangeReason.apiGesture` IS available in josxha v0.1.2 — just not wired.)
4. **Bounds are zone-scoped, not player-scoped.** Camera can drift 2-5km within the detection zone.
5. **Camera not decoupled from map_screen.** 1500-line widget owns all logic. Not testable.

---

## 2. Reference Systems Summary

| Pattern | Best reference | EarthNova lesson |
|---------|---------------|-----------------|
| Follow + free toggle | Apple Maps progressive cycle | Single FAB: free → following. Gesture breaks follow. |
| Recenter animation | Google Maps 500ms easeTo | `animateCamera` 400ms ease-out cubic, not instant jump |
| Zoom constraints | Ingress scanner range | z12 min (no scanning cheat), z17 max, z15 default |
| Gesture detection | Google Maps `onCameraMoveStarted(reason)` | `MapEventStartMoveCamera.reason == apiGesture` → free mode |
| GPS smoothing | Strava 3-layer pipeline | Accuracy filter (exists) → deadzone (add later) → rubber-band (exists) |
| Fog at all zoom levels | Civilization, Fog of World | GeoJSON fog is resolution-independent — already correct |
| Semantic zoom | Civilization detail levels | Gate visual complexity on zoom (labels at z≥15, icons at z≥14.5) |

**Full research:** See git history for the unabridged 13-system analysis.

---

## 3. Architecture

### 3 Modes (not 5)

The oracle review stripped `followingHeading` (no compass data yet) and `returning` (animation state, not a mode). What remains:

```dart
enum CameraMode {
  /// Locked to player position, north-up. Camera follows rubber-band.
  following,

  /// User has panned/zoomed. Camera is free. Recenter FAB visible.
  free,

  /// fitBounds showing explored area or detection zone.
  overview,
}
```

### State

```dart
class CameraState {
  final CameraMode mode;
  final Geographic? playerPosition;   // null = no GPS yet
  final double zoom;
  final bool isAnimating;             // true during recenter animation

  bool get hasPlayer => playerPosition != null;
  bool get showRecenterFab => mode == CameraMode.free && hasPlayer;
}
```

No `bearing`, `pitch`, `lastGesture`, `distanceToPlayer` — those are deferred features.

### State Machine

```
                ┌─────────────┐
                │  following  │ ←── default on startup
                │ (locked to  │
                │  player)    │
                └──────┬──────┘
                       │
          gesture      │      overview btn
          ┌────────────┼────────────┐
          ▼                         ▼
    ┌───────────┐            ┌───────────┐
    │   free    │            │  overview │
    │ (FAB vis) │            │ (fitBounds│
    └─────┬─────┘            └─────┬─────┘
          │                        │
    FAB tap                   gesture
          │                        │
          ▼                        ▼
    ┌───────────┐            ┌───────────┐
    │ following │            │   free    │
    │ (400ms    │            └───────────┘
    │  animate) │
    └───────────┘
```

**Transitions:**

| From | Event | To | Action |
|------|-------|----|----|
| `following` | User gesture | `free` | Cancel animation, show FAB |
| `following` | Overview button | `overview` | `fitBounds` detection zone |
| `free` | FAB tap | `following` | `animateCamera` to player, 400ms ease-out |
| `free` | Overview button | `overview` | `fitBounds` |
| `overview` | Any gesture | `free` | Show FAB |
| `overview` | FAB tap | `following` | `animateCamera` to player |

---

## 4. Components

### 4.1 CameraController (NEW)

**Location:** `lib/features/map/controllers/camera_controller.dart`

Pure Dart class. No Flutter, no Riverpod. Exposes state via `ValueNotifier<CameraMode>`.

```dart
class CameraController {
  CameraController({
    required this.onMoveToPlayer,
    required this.onFitBounds,
  });

  /// Callback: animate camera to player position.
  final void Function(Geographic center, Duration duration) onMoveToPlayer;

  /// Callback: fit camera to bounds.
  final void Function(LngLatBounds bounds, EdgeInsets padding, Duration duration) onFitBounds;

  /// Current mode — consumed by RecenterFAB via ValueListenableBuilder.
  final ValueNotifier<CameraMode> mode = ValueNotifier(CameraMode.following);

  Geographic? _playerPosition;

  /// Called on each rubber-band display update (~60fps, but only meaningful at 1Hz GPS rate).
  void onPlayerPositionUpdate(Geographic position) {
    _playerPosition = position;
    if (mode.value == CameraMode.following) {
      onMoveToPlayer(position, kGpsFollowDuration);
    }
  }

  /// Called when MapLibre detects a user gesture (pan/pinch/rotate).
  void onUserGesture() {
    if (mode.value != CameraMode.free) {
      mode.value = CameraMode.free;
    }
  }

  /// Called when user taps the recenter FAB.
  void recenter() {
    final pos = _playerPosition;
    if (pos == null) return;
    onMoveToPlayer(pos, kRecenterDuration);
    mode.value = CameraMode.following;
  }

  /// Called when user taps the overview button.
  void showOverview(LngLatBounds bounds) {
    onFitBounds(bounds, const EdgeInsets.all(20), kOverviewDuration);
    mode.value = CameraMode.overview;
  }

  void dispose() {
    mode.dispose();
  }
}
```

**~60 lines.** No sealed classes, no command pattern, no timers, no Riverpod provider. Two callbacks, one ValueNotifier. The map screen wires the callbacks to `mapController.animateCamera` / `mapController.fitBounds`.

### 4.2 RecenterFAB (NEW)

**Location:** `lib/features/map/widgets/recenter_fab.dart`

```dart
class RecenterFab extends StatelessWidget {
  const RecenterFab({
    required this.modeNotifier,
    required this.onRecenter,
    super.key,
  });

  final ValueNotifier<CameraMode> modeNotifier;
  final VoidCallback onRecenter;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<CameraMode>(
      valueListenable: modeNotifier,
      builder: (context, mode, _) {
        if (mode == CameraMode.following) return const SizedBox.shrink();
        return FloatingActionButton.small(
          onPressed: onRecenter,
          child: const Icon(Icons.my_location),
        );
      },
    );
  }
}
```

**~30 lines.** Visible in `free` and `overview`. Hidden in `following`. No animation, no pulsing, no distance tiers — YAGNI.

### 4.3 Existing Components (Keep unchanged)

| Component | Why |
|-----------|-----|
| RubberBandController | Well-built. Feeds position to CameraController. |
| PlayerMarkerLayer | Reads from rubber-band ValueNotifier, not camera. |
| DpadControls | Feeds keyboard steps to LocationService, not camera. |
| FogOverlayController | Decoupled — rebuilds on cell change, not camera move. |
| CameraBoundsController | **Keep for now.** maxBounds still useful until soft leash proves out. |

### 4.4 What NOT to build (deferred)

| Feature | Why deferred |
|---------|-------------|
| `followingHeading` mode | No compass data. Add when device heading API is wired. |
| Auto-recenter timer (8s) | FAB is sufficient. Add if users report "I forgot to recenter." |
| Player offset (look-ahead) | Fog game = radial exploration. Centered player is fine. |
| Zoom spring (bounce at limits) | MapLibre already clamps. Cosmetic polish for later. |
| 3-tier soft leash with pulsing | Single FAB visibility threshold is enough. |
| Stationary deadzone filter | Useful but independent of camera. Add in a separate PR. |
| CameraCommand sealed class | Over-engineered. Two callbacks do the job. |
| CameraProvider (Riverpod) | ValueNotifier consumed by one widget tree. No need. |

---

## 5. Data Flow

```
GPS (1Hz)
  │
  └─→ RubberBandController (60fps interpolation)
        │
        ├─→ PlayerMarkerLayer (ValueNotifier<Geographic> → blue dot)
        │
        ├─→ CameraController.onPlayerPositionUpdate(position)
        │     │
        │     ├── mode == following: onMoveToPlayer(pos, 250ms)
        │     │     → map_screen calls mapController.animateCamera(...)
        │     │
        │     └── mode == free/overview: no-op
        │
        └─→ GameCoordinator._processGameLogic() (fog, discovery — unchanged)

User gesture
  │
  └─→ MapLibre fires MapEventStartMoveCamera(reason: apiGesture)
        │
        └─→ map_screen._onMapEvent() → cameraController.onUserGesture()
              │
              └── mode.value = CameraMode.free → RecenterFAB becomes visible

FAB tap
  │
  └─→ cameraController.recenter()
        │
        ├── onMoveToPlayer(playerPos, 400ms)
        │     → mapController.animateCamera(center: pos, nativeDuration: 400)
        │
        └── mode.value = CameraMode.following → RecenterFAB hides
```

---

## 6. Zoom Semantics

| Zoom | Radius | Gameplay | Rendering |
|------|--------|----------|-----------|
| z12 | ~5km | District overview | Fog regions only. No cell boundaries. |
| z13 | ~2km | Multi-cell | Cell boundaries appear. Territory borders. |
| z14 | ~1km | Detection range | Fog animation starts. Habitat fill. Icons appear. |
| **z15** | **~500m** | **Default** | **Full detail: cells, icons, labels, animations.** |
| z16 | ~200m | Close | Individual cell detail. Full-size species art. |
| z17 | ~100m | Max zoom | Pixel-level cell exploration. |

**Semantic zoom gates (implement in Phase 2):**

```dart
bool shouldRenderCellBoundaries(double zoom) => zoom >= 13.0;
bool shouldRenderSpeciesIcons(double zoom) => zoom >= 14.5;
bool shouldRenderCellLabels(double zoom) => zoom >= 15.0;
bool shouldAnimateFogEdges(double zoom) => zoom >= 14.0;
```

### Constants

```dart
const double kCameraMinZoom = 12.0;
const double kCameraMaxZoom = 17.0;
const double kCameraDefaultZoom = 15.0;

const Duration kGpsFollowDuration = Duration(milliseconds: 250);
const Duration kRecenterDuration = Duration(milliseconds: 400);
const Duration kOverviewDuration = Duration(milliseconds: 1000);
```

---

## 7. Animation Curves

| Transition | Duration | Curve | Why |
|-----------|----------|-------|-----|
| GPS follow | 250ms | Linear | Predictable. Arrives before next GPS tick. |
| Recenter | 400ms | Ease-out cubic | Fast start, gentle landing. Feels responsive. |
| Overview | 1000ms | Ease-in-out cubic | Deliberate, cinematic. |

MapLibre's `animateCamera(nativeDuration:)` handles the animation natively on the GPU. No Dart-side animation controller needed.

---

## 8. Edge Cases

| Case | Behavior |
|------|----------|
| **No GPS yet** (`playerPosition == null`) | `following` mode does nothing. FAB hidden (can't recenter to nowhere). |
| **Zone timeout** (map loads without zone) | No maxBounds. Free mode works. Camera stays at restored position. |
| **Tab switch** (Map → Pack → Map) | With IndexedStack: camera state persists. With lazy tabs: controller lives on map widget, recreated with default state. |
| **Page resume** (iOS kills page, 60s gap) | gameCoordinatorProvider invalidated → new map mount → new CameraController → starts in `following`. |
| **Cold boot** (no cached position) | MapOptions default center (Fredericton). Camera in `following` but no-op until GPS arrives. |
| **Keyboard mode** | D-pad moves player via LocationService → rubber-band → CameraController. Follow mode tracks keyboard movement. |

---

## 9. Implementation Plan

### Phase 1: MVP Camera (fixes all audit problems)

**New files:**
- `lib/features/map/controllers/camera_controller.dart` — ~60 lines
- `lib/features/map/widgets/recenter_fab.dart` — ~30 lines
- `test/features/map/controllers/camera_controller_test.dart` — ~120 lines

**Modified files:**
- `lib/features/map/map_screen.dart` — Wire gesture detection, CameraController, RecenterFAB. Remove inline camera calls. (~80 lines changed)
- `lib/shared/constants.dart` — Add camera timing constants

**Keep unchanged:**
- `camera_bounds_controller.dart` — Still provides maxBounds (remove in Phase 2 if soft leash works)
- `camera_bounds_provider.dart` — Same
- `rubber_band_controller.dart` — Untouched
- `fog_overlay_controller.dart` — Untouched

**Specific changes in map_screen.dart:**

1. Create `CameraController` in `initState()` with callbacks wired to `_mapController`
2. In `_onMapEvent()`, handle `MapEventStartMoveCamera`:
   ```dart
   if (event is MapEventStartMoveCamera &&
       event.reason == CameraChangeReason.apiGesture) {
     _cameraController.onUserGesture();
   }
   ```
3. In `_onDisplayPositionUpdate()` (rubber-band callback), call:
   ```dart
   _cameraController.onPlayerPositionUpdate(position);
   ```
4. Add `RecenterFab` to the widget tree (positioned bottom-right, above existing FABs)
5. Remove ad-hoc `fitBounds` calls that duplicate follow behavior

**Does NOT change:**
- Fog rendering pipeline
- Game logic (discovery, cell visits)
- GPS pipeline
- Detection zone system

### Phase 2: Polish (after MVP validates)

- Remove `maxBounds` + `CameraBoundsController`, add simple soft leash (FAB visible when >500m from player)
- Semantic zoom gating (gate cell labels, icons, fog animation on zoom level)
- Stationary deadzone GPS filter
- Overview button (fitBounds over explored area)

### Future (when compass data is available)

- `followingHeading` mode (map rotates with device heading)
- Player offset / look-ahead (35% from bottom)
- Auto-recenter timeout (8s)
- Progressive FAB cycle (free → following → heading)

---

## 10. Test Plan

| Test | Verifies |
|------|----------|
| `starts in following mode` | Initial state |
| `GPS update in following emits onMoveToPlayer` | Follow works |
| `GPS update in free emits nothing` | Free doesn't fight user |
| `onUserGesture transitions to free` | Gesture detection |
| `recenter transitions free → following` | Recenter works |
| `recenter with null player is no-op` | Edge case |
| `overview transitions to overview` | Overview mode |
| `gesture during overview transitions to free` | Overview escape |
| `multiple gestures in free are idempotent` | No state thrash |
| `dispose cleans up ValueNotifier` | Lifecycle |

---

## 11. What We Deliberately Did NOT Design

| Omission | Rationale |
|----------|-----------|
| Heading-up rotation | No compass API wired. Top-down fog game doesn't need it yet. |
| Auto-recenter timer | Button is enough. Timer may annoy. Add if users report forgetting. |
| Player offset (look-ahead) | Radial fog exploration ≠ forward navigation. Center is fine. |
| Zoom spring / bounce | MapLibre already clamps. Cosmetic polish. |
| Distance-based FAB pulsing | Fog itself communicates "nothing here." One visibility threshold. |
| Command pattern | 2 callbacks. No queuing, no undo, no serialization. |
| Riverpod provider for camera | ValueNotifier consumed by 1 widget tree. No need for global state. |
| Camera replay / recording | No use case. |
