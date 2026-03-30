# Map Feature

Pure renderer for the map. All game logic lives in `GameCoordinator` (`lib/core/game/`). MapScreen reads coordinator state, feeds rubber-band position updates back, and renders fog/camera/markers.

---

## Directory Structure

This feature has a unique structure (different from other features):

```
lib/features/map/
├── controllers/        # Pure logic controllers (NOT Riverpod)
├── layers/             # (empty — Canvas fog system deleted; GeoJSON system is in controllers/)
├── models/             # Screen-space projection models
├── providers/          # Riverpod NotifierProviders (camera state, mode)
├── utils/              # GeoJSON builders, Mercator projection, icon rendering
├── widgets/            # UI overlays (HUD, controls, status bar)
└── map_screen.dart     # Feature root screen (NOT in screens/)
```

---

## Subdirectories

### controllers/

Pure logic controllers with callback injection. **NOT Riverpod Notifiers.** Plain Dart classes that take callbacks in constructor. This makes them testable without Riverpod.

**3 controllers:**

- **CameraController**: Follow/free mode switching, zoom constraints (min/max), camera movement logic. Calls `onCameraMove(lat, lon)`, `onZoomChanged(zoom)` callbacks.
- **FogOverlayController**: Manages fog render state + cell property icon GeoJSON + territory border GeoJSON. Has `cellPropertiesCache`, `dailySeed`, and `locationNodesCache` setters. Getters: `cellIconsGeoJson` (SymbolLayer), `borderFillGeoJson` (FillLayer), `borderLinesGeoJson` (LineLayer). Territory border build is guarded by non-empty `cellPropertiesCache` and `locationNodesCache`.
- **MapOverlayController**: Coordinates multiple overlays (fog, player marker, debug HUD).

**Controller Pattern:**
- Controllers are plain Dart classes (not Notifiers, not Widgets)
- They take callbacks in constructor (e.g., `onCameraMove`, `onZoomChanged`)
- This makes them testable without Riverpod
- This is the INTENDED pattern for map-related logic

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
- **territory_border_geojson_builder.dart**: Stellaris-style territory border rendering. Two static methods:
  - `buildBorderFill()` — Polygon FeatureCollection with BFS-computed `border_distance_<level>` and `region_color_<level>` properties for quadratic opacity falloff (0.15 → 0.04 → 0.01 → 0.00 over 3 cells)
  - `buildBorderLines()` — LineString FeatureCollection on shared Voronoi edges where adjacent cells belong to different admin regions. Properties: `border_color`, `line_weight`, `admin_level`
  - Stacking rule: only lowest-level differing border renders between adjacent cells (district > city > state > country)
  - Color: from `LocationNode.colorHex`, or deterministic FNV-1a hash of `osmId` when null
  - Line weights: country 3px, state 2px, city 1.5px, district 1px (constants in `shared/constants.dart`)
- **cell_property_geojson_builder.dart**: Builds Point FeatureCollection for cell property icons:
  - `buildCellIcons()` — GeoJSON Point features with `icon`, `offsetX`, `offsetY` properties
  - Visibility rules: current/visited → full grid (habitat + climate + event), adjacent unvisited with event → "?" icon, else → nothing
  - Icon IDs reference images registered via `MapIconRenderer`
- **map_icon_renderer.dart**: Renders emoji to PNG bytes for MapLibre `addImage()`:
  - `renderEmoji(String emoji)` → `Future<Uint8List>` (64×64 PNG via Canvas/TextPainter)
  - Static ID helpers: `habitatIconId()`, `climateIconId()`, `eventIconId()`, `eventUnknownId`
  - Required because MapLibre cannot render emoji in `text-field` (BMP-only limitation)
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

## Cell Property Icons Layer

4th MapLibre layer — SymbolLayer rendering cell property icons as registered PNG images.

**Pipeline:**
```
GameIcons emoji → MapIconRenderer.renderEmoji() → PNG bytes
  → controller.addImage(id, bytes) → MapLibre image registry
    → SymbolLayer reads 'icon-image' from GeoJSON feature properties
```

**Source/Layer IDs:** `cell-icons-src` / `cell-icons-layer`

**Icon visibility rules (CellPropertyGeoJsonBuilder):**
- Current cell OR visited cell → full grid: habitat (top-left), climate (top-right), event (bottom-center)
- Adjacent unvisited with event → single "❓" unknown icon (Witcher 3 style)
- Everything else → no icons

**Data flow per frame:**
1. `_updateFogRendering()` sets `fogOverlayController.cellPropertiesCache` + `dailySeed`
2. `fogOverlayController.update()` calls `CellPropertyGeoJsonBuilder.buildCellIcons()`
3. GeoJSON source updated via `setGeoJsonSource()`
4. SymbolLayer renders icons using `['get', 'icon']` data-driven expression

**MapLibre emoji limitation:** Emoji in `text-field` silently drops characters outside BMP (U+0000–U+FFFF). Most emoji are outside BMP. Solution: render to PNG and use `addImage()`.

**SymbolLayer note:** v0.1.2 constructor does NOT forward `minZoom`/`maxZoom` from base class.

---

## Territory Border Layers

5th and 6th MapLibre layers — Stellaris-style territory borders showing admin region ownership.

**Source/Layer IDs:**
- `territory-border-fill-src` / `territory-border-fill` — FillLayer with data-driven opacity from `border_distance_country`
- `territory-border-lines-src` / `territory-border-lines` — LineLayer with data-driven `border_color` and `line_weight`

**Layer ordering:** Rendered between `fog-border` and `cell-icons` layers.

**Data flow:**
1. `_loadLocationNodes()` lazily loads all `LocationNode` records from `LocationNodeRepository.getAll()` on first fog render
2. `fogOverlayController.locationNodesCache` receives the node map
3. `_buildGeoJson()` calls `TerritoryBorderGeoJsonBuilder.buildBorderFill()` / `.buildBorderLines()`
4. GeoJSON sources updated via `setGeoJsonSource()` in `_updateFogSources()`

**Fill layer properties per feature:**
```json
{"cell_id": "v_123_456", "border_distance_country": 0, "region_color_country": "#FF0000"}
```

**Line layer properties per feature:**
```json
{"admin_level": "country", "border_color": "#FF0000", "line_weight": 3.0}
```

**Opacity formula (quadratic falloff):** `base_opacity * (1 - distance/maxDistance)^2`
- Distance 0 (border cell): 0.15
- Distance 1: ~0.04
- Distance 2: ~0.01
- Distance 3+: 0.00

**Location node loading:** Lazy, fires once. Does not refresh during gameplay. Cache won't update until app restart if new cells are enriched.

---

## Admin Boundary Polygon Layers

7th and 8th MapLibre layers — GeoJSON fill + line layers rendering resolved admin boundaries fetched from Nominatim.

**Source/Layer IDs:**
- `admin-boundary-fill-src` / `admin-boundary-fill` — FillLayer with boundary polygon fill
- `admin-boundary-lines-src` / `admin-boundary-lines` — LineLayer outlining the boundary

**Layer ordering:** Rendered BELOW fog layers — boundaries are visible through fog.

**GeoJSON builder:** `AdminBoundaryGeoJsonBuilder` — builds FeatureCollections from `LocationNode.geometryJson` strings.

**Data flow (event-driven, NOT 10Hz):**
1. `AdminBoundaryService.requestBoundaries(locationNodeId)` triggers fetch via `resolve-admin-boundaries` Edge Function
2. `AdminBoundaryService.onBoundariesResolved` stream fires when geometry arrives
3. `FogOverlayController.updateAdminBoundaries()` rebuilds GeoJSON and calls `setGeoJsonSource()`

**Anti-pattern:** Never rebuild admin boundary GeoJSON in the 10Hz render loop. Boundaries only change on cell enrichment events.

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

## Coordination Flow (Post-GameCoordinator)

```
GameCoordinator (core/game/)
  ├─ Subscribes to GPS stream (1 Hz) via gameCoordinatorProvider
  ├─ Processes discovery events, rolls affixes
  ├─ Runs fog computation at ~10 Hz on playerPosition
  └─ Pushes state to Riverpod notifiers via callbacks

MapScreen (features/map/)
  ├─ Reads gameCoordinatorProvider (already started)
  ├─ Subscribes to onRawGpsUpdate stream
  │    → feeds rubber-band controller
  ├─ RubberBand interpolates (60 fps)
  │    → updates marker position (ValueNotifier)
  │    → moves camera (MapLibre moveCamera)
  │    → calls gameCoordinator.updatePlayerPosition(lat, lon)
  └─ Throttled fog GeoJSON rebuilds (~10 Hz via _renderFrame)
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

At feature root (NOT in `screens/`). ConsumerStatefulWidget. **Pure renderer** — no game logic.

All services injected via Riverpod providers. The widget manages:
- `_mapController` (MapLibre controller, set in `onMapCreated`)
- `_gameCoordinator` (read from gameCoordinatorProvider, already started)
- `_rawGpsSubscription` (subscribes to coordinator.onRawGpsUpdate for rubber-band)
- `_showDebugHud` toggle state
- `_locationNodesMap` / `_locationNodesLoaded` (lazy-loaded LocationNode cache for territory borders)
- Fog GeoJSON rendering (throttled ~10 Hz via `_renderFrame`)

**Removed from map_screen (now in GameCoordinator):**
- GPS subscription and error handling
- Discovery event processing and affix rolling
- Fog state computation (fogResolver.onLocationUpdate)
- Location provider updates
- Cell visited tracking
- GPS permission checks

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

- **System:** 3-layer GeoJSON (base fog world polygon + mid-fog semi-transparent fills + border outlines)
- **Update trigger:** Only on fog state change or camera move (not every frame)
- **Opacity:** Derived from FogState density values (Unknown: 1.0, Detected: 0.85, Nearby: 0.95, Explored: 0.5, Present: 0.0)

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
- Overlays: `*Overlay` (e.g., widget-based overlays on the map)

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
