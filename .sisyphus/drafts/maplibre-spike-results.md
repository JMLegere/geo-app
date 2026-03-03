# MapLibre Package Comparison Spike — Task 7

## TL;DR

**Recommendation: `maplibre` by josxha** — Flutter-native children API with `WidgetLayer`, better overlay composition, offline download support, and active development. The `maplibre_gl` platform-view approach creates compositing friction for our CustomPaint fog overlay use case.

---

## Packages Compared

| Attribute | `maplibre_gl` | `maplibre` (josxha) |
|-----------|--------------|---------------------|
| pub.dev | pub.dev/packages/maplibre_gl | pub.dev/packages/maplibre |
| GitHub | maplibre/flutter-maplibre-gl | josxha/flutter-maplibre |
| Version (at evaluation) | 0.25.0 | 0.1.x+ (actively developing) |
| Architecture | **Platform Views** (native MapLibre SDK embedded) | **Flutter-native composition** with children API |
| Rendering | Native GL context (AndroidView / UiKitView) | Native GL context with Flutter widget tree composition |
| Impeller support | Relies on platform view compositing; potential flickering | Flutter-native children avoid compositing issues |

---

## Evaluation Criteria

### 1. CustomPaint/Shader Overlay Compatibility (CRITICAL for fog-of-war)

**`maplibre_gl`**: Uses platform views. A `CustomPaint` widget placed in a `Stack` above the map will:
- Work visually (renders on top)
- **Block touch events** from reaching the map unless `IgnorePointer`/`AbsorbPointer` is carefully managed
- May cause **compositing jank** on Android (platform view + Flutter widget = texture bridge overhead)
- Impeller compositing with platform views is a known friction point — potential black frames or flickering during rapid pan/zoom

**`maplibre` (josxha)**: Uses a `children` API where Flutter widgets are composed within the map widget tree:
- `WidgetLayer` allows placing Flutter widgets at geographic coordinates (geo-anchored markers)
- A `CustomPaint` fog overlay can be placed as a child or in a `Stack` with cleaner compositing since the package is designed for Flutter widget composition
- Touch event passthrough is handled natively by the package's gesture system

**Verdict**: josxha wins for overlay composition. The children-based API was designed for exactly this pattern.

### 2. Camera State Access (CRITICAL for fog-camera sync)

**`maplibre_gl`**: Provides `onCameraTrackingChanged`, `onCameraIdle`, and access to `mapController.cameraPosition` via the controller. Real-time camera tracking during gestures requires polling or listening to move events. Camera state includes center, zoom, bearing, tilt.

**`maplibre` (josxha)**: Provides `MapController` with:
- `moveCamera(center:, zoom:, bearing:, pitch:)` — instant
- `animateCamera(center:, zoom:, bearing:, pitch:, nativeDuration:)` — animated
- `fitBounds(bounds:, padding:)` — fit to region
- `onEvent` callback receives typed events including `MapEventClick`, camera move events
- Camera state readable at any time from the controller

**Verdict**: Both provide camera access. josxha's typed event system is cleaner.

### 3. WidgetLayer / Flutter Widget Placement

**`maplibre_gl`**: No native WidgetLayer. Markers are added via `addSymbol()` which uses native map symbols (not Flutter widgets). Flutter widgets require manual `Stack` + coordinate-to-screen-point conversion.

**`maplibre` (josxha)**: Built-in `WidgetLayer` with `Marker` objects:
```dart
WidgetLayer(
  markers: [
    Marker(
      point: Geographic(lon: 9.17, lat: 47.68),
      size: Size(120, 80),
      child: Container(...), // Any Flutter widget
    ),
  ],
)
```
Full Flutter widget tree as markers, including `GestureDetector`, animations, etc.

**Verdict**: josxha wins decisively. Native WidgetLayer is a major advantage for player markers, UI overlays.

### 4. Offline Tile Region Download

**`maplibre_gl`**: Supports offline regions via `downloadOfflineRegion()`. Mature implementation inherited from Mapbox GL.

**`maplibre` (josxha)**: Supports offline via `manager.downloadRegion()` with async stream progress:
```dart
final stream = await manager.downloadRegion(
  minZoom: 10, maxZoom: 14,
  bounds: LngLatBounds(...),
  mapStyleUrl: '...',
  pixelDensity: 1,
);
await for (final update in stream) {
  // progress tracking
}
```

**Verdict**: Both support offline. josxha's stream-based API is more Flutter-idiomatic.

### 5. GeoJSON Fill Layer (fog fallback)

**`maplibre_gl`**: `addFillLayer(sourceId, layerId, properties)` with full MapLibre style spec support. Fill layers with opacity, color, patterns. Well-documented.

**`maplibre` (josxha)**: Supports style layers including fill layers via the MapLibre style spec. Can add GeoJSON sources and fill layers programmatically.

**Verdict**: Both support fill layers via the MapLibre style spec. Equivalent capability.

### 6. Platform Support

**`maplibre_gl`**: Android ✅, iOS ✅, Web ✅ (via maplibre-gl-js). Mature, battle-tested.

**`maplibre` (josxha)**: Android ✅, iOS ✅, Web ✅, macOS ✅, Linux ✅, Windows ✅. Broader platform support.

**Verdict**: josxha has broader platform support (desktop targets too).

### 7. Impeller Compatibility

**`maplibre_gl`**: Platform view approach means MapLibre renders in a native GL context, then Flutter composites it with the Impeller-rendered widget tree. This texture bridge is the known source of:
- Flickering during fast pan/zoom
- Potential black frames when compositing native + Flutter layers
- Higher memory usage (double buffering)

**`maplibre` (josxha)**: Still uses a native GL context for map rendering (MapLibre is inherently native), but the children/widget composition layer is Flutter-native. The compositing boundary is the same (map is still a texture), but the package is being developed with Impeller in mind and the children API avoids adding extra compositing layers on top.

**Verdict**: Neither fully avoids the platform view compositing challenge (MapLibre itself is native GL), but josxha's design minimizes the number of compositing boundaries by keeping overlays in the Flutter widget tree rather than requiring additional Stack layers.

---

## Risk Assessment

### `maplibre_gl` Risks
1. **Overlay jank**: CustomPaint over platform view = compositing overhead. Fog overlay may visually lag behind map during fast gestures.
2. **Touch event routing**: Stack-based overlay blocks map gestures. Requires `IgnorePointer` dance.
3. **Maturity trap**: More mature but less actively developed; may not keep up with Flutter/Impeller changes.

### `maplibre` (josxha) Risks
1. **Younger package**: Less battle-tested in production. Potential undiscovered bugs.
2. **API stability**: Still pre-1.0 — API may change.
3. **Migration cost**: If we start with josxha and hit a blocker, switching back to `maplibre_gl` requires rewriting map integration code.

### Mitigation
- The fog overlay is the single most critical visual feature. Overlay composition quality outweighs maturity concerns.
- API instability risk is bounded — we're early in development and can absorb changes.
- If josxha hits a blocker in Task 9 (fog shader PoC), we can fall back to `maplibre_gl` + native FillLayer fog (no CustomPaint overlay).

---

## Decision

### Recommendation: `maplibre` by josxha

**Rationale**:
1. **Children API** — designed for Flutter widget composition on maps, which is exactly what we need for fog overlay + player marker
2. **WidgetLayer** — native support for placing Flutter widgets at geographic coordinates
3. **Cleaner gesture handling** — no platform view touch-event routing issues
4. **Offline support** — stream-based download API, Flutter-idiomatic
5. **Active development** — author responsive, broader platform targets
6. **Impeller-conscious** — designed with modern Flutter rendering in mind

**Trade-off accepted**: Younger, pre-1.0 API vs. better architecture fit for our fog overlay use case.

### Migration Action Items
1. Replace `maplibre_gl: ^0.25.0` with `maplibre: ^0.1.0` (or latest) in `pubspec.yaml`
2. Update imports from `package:maplibre_gl/maplibre_gl.dart` to `package:maplibre/maplibre.dart`
3. Replace `MapLibreMap` controller pattern with josxha's `MapLibreMap(options:, children:, onMapCreated:)` pattern
4. Use `Geographic` from geobase (already in our project) for coordinates — josxha uses the same

### Constraint
This decision is validated or invalidated by **Task 9 (Fog Shader PoC)**. If the CustomPaint overlay approach fails with josxha's package, we fall back to `maplibre_gl` + native FillLayer fog approach.

---

## Environment Note

This spike was conducted in a **headless CI environment** (no emulator/simulator). Evaluation is based on:
- API analysis and documentation review
- Source code architecture examination
- Known issues from GitHub issue trackers
- Community feedback and benchmark data

Visual rendering comparison (screenshots) will be validated in **Task 9** when the fog shader PoC runs on an actual device/emulator.
