# Map Feature

The centerpiece of the app. Beautiful, like Apple Maps or Fog of World. Renders a MapLibre GL base map with a fog-of-war overlay composited via Canvas. Player movement drives fog state transitions.

---

## Directory Structure

This feature has a unique structure (different from other features):

```
lib/features/map/
├── controllers/        # Pure logic controllers (NOT Riverpod)
├── layers/             # Fog rendering layer (Canvas compositing)
├── models/             # Screen-space projection models
├── providers/          # Riverpod NotifierProviders (camera state, mode)
├── utils/              # Pure math utilities (Mercator projection)
├── widgets/            # UI overlays (HUD, controls, status bar)
└── map_screen.dart     # Feature root screen (NOT in screens/)
```

---

## Subdirectories

### controllers/

Pure logic controllers with callback injection. **NOT Riverpod Notifiers.** Plain Dart classes that take callbacks in constructor. This makes them testable without Riverpod.

**3 controllers:**

- **CameraController**: Follow/free mode switching, zoom constraints (min/max), camera movement logic. Calls `onCameraMove(lat, lon)`, `onZoomChanged(zoom)` callbacks.
- **FogOverlayController**: Manages fog render state. Triggers repaint when fog state changes.
- **MapOverlayController**: Coordinates multiple overlays (fog, player marker, debug HUD).

**Controller Pattern:**
- Controllers are plain Dart classes (not Notifiers, not Widgets)
- They take callbacks in constructor (e.g., `onCameraMove`, `onZoomChanged`)
- This makes them testable without Riverpod
- This is the INTENDED pattern for map-related logic

### layers/

Fog rendering layer. Canvas compositing technique.

**2 classes:**

- **FogCanvasOverlay**: CustomPaint widget wrapper. Rebuilds when fog state changes.
- **FogCanvasPainter**: CustomPainter implementation. Renders fog via Canvas compositing.

**Canvas compositing technique:**
```dart
canvas.saveLayer() → fill with fog color → punch holes with BlendMode.dstOut → canvas.restore()
```

**FogState density values (fog opacity):**
- Undetected: 1.0, Unexplored: 1.0, Concealed: 0.95, Hidden: 0.5, Observed: 0.0
- Unexplored cells are pre-rendered in mid-fog at concealed density (0.95) behind the opaque base layer
- When a cell transitions to concealed, the base-fog hole is punched, revealing the pre-rendered polygon

### models/

**CellRenderData**: Screen-space projection of a cell for rendering. Contains pixel coordinates, fog density, and cell ID.

### providers/

**2 NotifierProviders** (Riverpod v3 Notifier pattern):

- **MapStateNotifier**: Camera position (lat, lon) + zoom level. Emits state on camera move.
- **CameraModeNotifier**: Follow/free mode enum. Toggles between following player and free exploration.

### utils/

**MercatorProjection**: Pure math Web Mercator (EPSG:3857). No async. No side effects.

- Converts Geographic (lat, lon) ↔ screen coordinates (x, y)
- Lat clamped to ±85.051129° (Web Mercator limit)
- Zoom-aware scaling

### widgets/

UI components overlaid on the map:

- **DebugHUD**: Terminal-style overlay with camera position, zoom, mode, visible/visited cell counts
- **MapControls**: Stacked FABs: recenter, zoom toggle (player/world), debug toggle (kDebugMode only)
- **StatusBar**: Frosted-glass top panel with cells observed + current streak. BackdropFilter blur.
- **PlayerMarkerLayer**: ValueListenableBuilder scopes 60fps marker updates. `Position(lng, lat)` — longitude first.
- **DPadControls**: On-screen directional pad for mobile web. 10m step per tap, 100ms long-press repeat.

### utils/

- **fog_geojson_builder.dart**: Static methods for 3-layer native GeoJSON fog system:
  - `buildBaseFog()` — world polygon with holes for non-opaque cells
  - `buildMidFog()` — individual polygons for hidden/concealed/unexplored with density property
  - `buildCellBorders()` — line outlines for unexplored (0.4 opacity) + concealed (0.25 opacity)
  - All coordinates are `[longitude, latitude]` (GeoJSON convention)
- **mercator_projection.dart**: Pure Web Mercator math. `geoToScreen`/`screenToGeo`/`visibleBounds`. Lat clamped ±85.051129°.
- **map_visibility.dart**: CSS-based MapLibre container visibility control for web. `AnimatedOpacity` cannot hide `HtmlElementView` — CSS injection required.
- **map_logger.dart**: Rate-limited logger with channels (RUBBER, CAMERA, FOG, KEY, LOC). Errors always log immediately. **Known debt:** mutable static variables.

---

## 3-Layer Native GeoJSON Fog System

The fog is rendered using 3 MapLibre native GeoJSON layers (NOT Canvas):

1. **fog-base** — Opaque world polygon with holes punched for non-opaque cells. Covers the entire world.
2. **fog-mid** — Semi-transparent fill polygons for hidden/concealed/unexplored cells. Each has a `density` property.
3. **fog-border** — Line outlines at unexplored (0.4) and concealed (0.25) opacity.

**Pre-rendering trick:** Unexplored cells are rendered in mid-fog at concealed density (0.95) but hidden behind the opaque base layer. When a cell transitions from unexplored to concealed, the base-fog hole is punched, revealing the already-rendered mid-fog polygon. This eliminates flash artifacts during transitions.

---

## Rubber-Band Controller

Smooth 60fps interpolation decouples display position from raw GPS:

- GPS updates (1 Hz) → `setTarget(lat, lon)` — sets target only
- Ticker (60 fps) → interpolates display position toward target
- Speed scales with distance: `max(minSpeedMps, speedMultiplier * distanceMeters)`
- Snap threshold: below 5m, snaps instantly to prevent sub-pixel oscillation
- Delta time clamped to 0.1s max to prevent huge jumps on tab-switch resume

**Game logic throttle:** `_gameLogicFrame % 6 == 0` gates fog/location updates to ~10 Hz.

---

## Coordination Flow

```
GPS/Simulator (1 Hz)
  → _onLocationUpdate() → _rubberBand.setTarget()
  → _rubberBand._onTick() (60 fps)
    → _onDisplayPositionUpdate(lat, lon)
      ├─ _markerPosition.value = (lat, lon)  [ValueNotifier → PlayerMarkerLayer]
      ├─ cameraController.onLocationUpdate()  [MapLibre moveCamera]
      └─ _gameLogicFrame % 6 == 0?
          └─ _processGameLogic(lat, lon)
              ├─ fogResolver.onLocationUpdate()
              ├─ locationProvider.notifier.updateLocation()
              ├─ fogOverlayController.update()  [viewport sampling + GeoJSON build]
              └─ _updateFogSources()  [MapLibre updateGeoJsonSource × 3 layers]
```

---

## MapLibre Specifics

**Package:** `maplibre` by josxha (v0.1.2), **NOT** `maplibre_gl`

**Position constructor:**
```dart
Position(lng, lat)  // LONGITUDE FIRST
```

**Camera animation:**
```dart
MapController.animateCamera(center: Position(lng, lat), nativeDuration: Duration(...))
```

**Player marker:** Widget overlay (not a map layer). Positioned via WidgetLayer + ValueListenableBuilder.

**Camera movement:** Uses `moveCamera()` (instant), NOT `animateCamera()` (flyTo). Rubber-band calls at 60fps — cascading animations cause zoom jitter.

**Zoom preservation:** Always pass explicit `zoom` to `moveCamera()`. Dart→JS interop sends `null` (not `undefined`), which MapLibre may interpret as "reset to default".

---

## map_screen.dart

At feature root (NOT in `screens/`). ConsumerStatefulWidget.

All services injected via Riverpod providers. The widget manages:
- `_mapController` (MapLibre controller, set in `onMapCreated`)
- `_locationService` (saved field for safe `dispose()` — `ref.read()` is unsafe after unmount)
- Stream subscriptions for location updates and discovery events
- `_showDebugHud` toggle state

The location → fog → camera → overlay pipeline is orchestrated in `_onLocationUpdate()`.

---

## Resolved Tech Debt

The following issues were resolved in the service injection refactoring:

- **Default coordinates**: Moved to `constants.dart` as `kDefaultMapLat`, `kDefaultMapLon`.
- **Voronoi grid bounds**: Moved to `constants.dart` as `kVoronoiMinLat/MaxLat/MinLon/MaxLon`, `kVoronoiGridRows/Cols/Seed`.
- **Service instantiation in StatefulWidget**: All services now provided via Riverpod providers (`cellServiceProvider`, `fogResolverProvider`, `cameraControllerProvider`, `fogOverlayControllerProvider`, `discoveryServiceProvider`, `locationServiceProvider`).
- **Manual service lifecycle in initState**: Provider lifecycle via `ref.onDispose()`.
- **Stream subscriptions in widget fields**: Subscriptions still in widget (required for MapLibre integration), but services come from providers.

---

## Constraints

### Camera

- **Min zoom:** 12
- **Max zoom:** 18
- **Follow mode:** Camera locked to player position, updates on location change
- **Free mode:** User can pan/zoom freely, camera does not follow player

### Fog Rendering

- **Repaint trigger:** Only on fog state change (not every frame)
- **Blend mode:** `BlendMode.dstOut` for punching holes in fog layer
- **Opacity:** Derived from FogState density values

### Mercator Projection

- **Lat bounds:** ±85.051129° (Web Mercator limit)
- **Lon bounds:** ±180° (wraps around)
- **Zoom range:** 0-22 (MapLibre standard)

---

## Conventions

### File Naming

- Controllers: `*_controller.dart`
- Layers: `*_overlay.dart`, `*_painter.dart`
- Models: `*_data.dart`
- Providers: `*_provider.dart`
- Utils: `*_projection.dart`, `*_utils.dart`
- Widgets: `*_hud.dart`, `*_controls.dart`, `*_bar.dart`

### Class Naming

- Controllers: `*Controller` (e.g., `CameraController`)
- Notifiers: `*Notifier` (e.g., `MapStateNotifier`)
- Painters: `*Painter` (e.g., `FogCanvasPainter`)
- Overlays: `*Overlay` (e.g., `FogCanvasOverlay`)

### Callback Naming

- `onCameraMove(double lat, double lon)`
- `onZoomChanged(double zoom)`
- `onModeToggle(CameraMode mode)`
- `onFogStateChanged(String cellId, FogState state)`

---

## Testing

- **Controllers:** Unit test with mock callbacks. No Riverpod needed.
- **Painters:** Widget test with mock Canvas. Verify draw calls.
- **Providers:** Test with ProviderContainer. Verify state transitions.
- **Projection:** Unit test with known lat/lon ↔ x/y pairs.
