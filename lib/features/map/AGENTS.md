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

**FogState density values:**
- `[1.0, 0.75, 0.5, 0.25, 0.0]` map to opacity
- 1.0 = fully fogged (Undetected)
- 0.0 = fully revealed (Observed)

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

- **DebugHUD**: Shows lat/lon, zoom, cell ID, fog state
- **MapControls**: Zoom in/out buttons, follow/free mode toggle
- **StatusBar**: Top bar with connection status, GPS accuracy

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

**Player marker:** Widget overlay (not a map layer). Positioned via Stack + Positioned widget.

---

## map_screen.dart

At feature root (NOT in `screens/`). ConsumerStatefulWidget.

**Heavy initState/dispose:** Manual service lifecycle. Uses `late final` fields for CellService, LocationService, DiscoveryService.

**Known anti-pattern:** Services should be injected via Riverpod providers, not instantiated in StatefulWidget.

---

## Known Issues / Tech Debt

### Hardcoded Values

- **Default coordinates:** `_defaultLat = 37.7749`, `_defaultLon = -122.4194` in map_screen.dart. Should move to `constants.dart`.
- **Voronoi grid bounds:** `minLat: 37.5, maxLat: 38.0, minLon: -122.7, maxLon: -122.1` hardcoded. Should be configurable.

### State Management

- **StreamSubscriptions stored as widget fields:** Should use Riverpod StreamProvider instead.
- **Multiple `ref.read(...notifier)` calls in event handlers:** Should batch via callbacks or use `ref.listen()`.

### Service Instantiation

- **Services instantiated in StatefulWidget:** CellService, LocationService, DiscoveryService created in `initState()`. Should be provided via Riverpod providers.

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
