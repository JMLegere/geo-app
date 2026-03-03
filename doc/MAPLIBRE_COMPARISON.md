# MapLibre Flutter Package Comparison

**Date**: March 2, 2026  
**Comparison**: `maplibre_gl` (official) vs `maplibre` (josxha)

---

## 1. PACKAGE METADATA & MAINTENANCE

### maplibre_gl (Official - maplibre/flutter-maplibre-gl)

| Metric | Value |
|--------|-------|
| **Current Version** | 0.25.0 |
| **Last Published** | 2026-01-07 |
| **GitHub Stars** | 324 |
| **GitHub Forks** | 177 |
| **Open Issues** | 89 |
| **Last Updated** | 2026-03-01 |
| **Repository** | https://github.com/maplibre/flutter-maplibre-gl |
| **Pub.dev** | https://pub.dev/packages/maplibre_gl |
| **Maintenance Status** | **ACTIVE** - Regular releases, 14 releases total |

### maplibre (josxha - josxha/flutter-maplibre)

| Metric | Value |
|--------|-------|
| **Current Version** | 0.3.4+1 |
| **Last Published** | 2026-02-27 |
| **GitHub Stars** | 102 |
| **GitHub Forks** | 29 |
| **Open Issues** | 17 |
| **Last Updated** | 2026-03-02 |
| **Repository** | https://github.com/josxha/flutter-maplibre |
| **Pub.dev** | https://pub.dev/packages/maplibre |
| **Maintenance Status** | **ACTIVE** - Regular releases, federated plugin architecture |

---

## 2. ARCHITECTURE & COMPOSITION APPROACH

### maplibre_gl (Official)

**Platform View Strategy**: **Native Platform Views** (AndroidView / UiKitView)
- Uses native MapLibre GL bindings directly
- Android: `org.maplibre.maplibregl.MapLibreMapsPlugin`
- iOS: Native Swift/Objective-C bindings
- Web: `maplibre-gl-js` via JavaScript interop

**Widget Composition**:
```dart
MapLibreMap(
  initialCameraPosition: _initial,
  onMapCreated: (controller) => _controller = controller,
  onStyleLoadedCallback: () => setState(() => _styleLoaded = true),
)
```

**Overlay Approach**:
- **CustomPaint on top**: ✅ **SUPPORTED** via `Stack` composition
- Platform view is a native widget; Flutter widgets can be layered above it
- **Touch event blocking**: ⚠️ **POTENTIAL ISSUE** - Platform views can block touch events to layers above
- **Workaround**: Use `gestureRecognizers` parameter to configure gesture handling

**Key Limitation**: 
- No built-in `WidgetLayer` for placing Flutter widgets at map coordinates
- Must manually calculate screen positions from lat/lng using controller

---

### maplibre (josxha)

**Platform View Strategy**: **Federated Plugin with FFI (iOS) + Native (Android)**
- iOS: Complete FFI implementation (no method channels)
- Android: Native bindings
- Web: `maplibre-gl-js` via JavaScript interop
- **Experimental**: Windows/macOS via WebView

**Widget Composition**:
```dart
MapLibreMap(
  onMapCreated: (controller) => _controller = controller,
  children: [
    WidgetLayer(
      markers: [
        Marker(
          point: Geographic.latLng(lat: 37.7749, lng: -122.4194),
          size: Size(50, 50),
          child: MyCustomWidget(),
        ),
      ],
    ),
  ],
)
```

**Overlay Approach**:
- **CustomPaint on top**: ✅ **SUPPORTED** via `children` parameter
- **WidgetLayer**: ✅ **BUILT-IN** - Native support for placing Flutter widgets at map coordinates
- **Touch event handling**: ✅ **BETTER** - `WidgetLayer` has `allowInteraction` flag
  - iOS/Android: Uses `TranslucentPointer` to prevent blocking map gestures
  - Web: Uses `PointerInterceptor` for selective interaction
- **Marker positioning**: Automatic screen-space calculation with camera tracking

**Key Advantage**:
- `WidgetLayer` + `Marker` system handles coordinate-to-screen conversion automatically
- Supports rotation, pitch, and alignment transformations
- Built-in support for flat/rotated markers

---

## 3. CAMERA STATE ACCESS (Real-Time Callbacks)

### maplibre_gl (Official)

**Camera Callbacks**: ✅ **SUPPORTED**

```dart
controller.onCameraMove.add((position) {
  print('Camera: ${position.target}, zoom: ${position.zoom}');
});

controller.onCameraIdle.add(() {
  print('Camera idle');
});
```

**Available Events**:
- `onCameraMove` - Fires during camera movement (gestures + programmatic)
- `onCameraIdle` - Fires when camera stops moving
- `onCameraMoveStarted` - Fires when camera starts moving

**Data Available**:
- `CameraPosition`: target (LatLng), zoom, bearing, tilt
- Real-time during gestures ✅

---

### maplibre (josxha)

**Camera Callbacks**: ✅ **SUPPORTED**

```dart
controller.onEvent.add((event) {
  if (event is MapEventMoveCamera) {
    print('Camera: ${event.camera}');
  }
});
```

**Available Events**:
- `MapEventMoveCamera` - During camera movement
- `MapEventCameraIdle` - When camera stops
- `MapEventStartMoveCamera` - When camera starts moving

**Data Available**:
- `MapCamera`: center (Geographic), zoom, bearing, pitch
- Real-time during gestures ✅

**Difference**: Uses event-based system vs callback-based; more flexible for multiple listeners

---

## 4. OFFLINE TILE REGION DOWNLOAD SUPPORT

### maplibre_gl (Official)

**Offline Support**: ✅ **FULL SUPPORT**

```dart
// Download offline region
final region = OfflineRegion(
  bounds: LatLngBounds(southwest: LatLng(...), northeast: LatLng(...)),
  minZoom: 12,
  maxZoom: 18,
  pixelRatio: 1.0,
);

await controller.downloadOfflineRegion(region, onTileFunctionType: (progress) {
  print('Downloaded: ${progress.downloadedTileCount}/${progress.requiredTileCount}');
});

// List downloaded regions
final regions = await controller.getOfflineRegions();

// Delete region
await controller.deleteOfflineRegion(region.id);
```

**Features**:
- Region-based download with bounds, zoom range, pixel ratio
- Progress callbacks
- List/delete offline regions
- Global offline mode toggle: `setOffline(true)`

---

### maplibre (josxha)

**Offline Support**: ✅ **FULL SUPPORT**

```dart
// Download offline region
final region = OfflineRegion(
  bounds: LngLatBounds(southwest: LngLat(...), northeast: LngLat(...)),
  minZoom: 12,
  maxZoom: 18,
  pixelRatio: 1.0,
);

await controller.downloadOfflineRegion(region, onProgress: (progress) {
  print('Downloaded: ${progress.downloadedTileCount}/${progress.requiredTileCount}');
});

// List downloaded regions
final regions = await controller.listOfflineRegions();

// Delete region
await controller.deleteOfflineRegion(region.id);
```

**Features**:
- Region-based download with bounds, zoom range, pixel ratio
- Progress callbacks
- List/delete offline regions
- Equivalent API surface to official package

---

## 5. GEOJSON & FILL LAYER SUPPORT

### maplibre_gl (Official)

**GeoJSON Support**: ✅ **FULL**

```dart
// Add GeoJSON source
await controller.addGeoJsonSource(
  'my-source',
  GeoJsonSourceProperties(data: geojsonString),
);

// Add fill layer
await controller.addFillLayer(
  'my-source',
  'my-layer',
  FillLayerProperties(
    fillColor: '#088',
    fillOpacity: 0.8,
  ),
);
```

**Features**:
- `GeoJsonSource` with dynamic data updates
- `FillLayer`, `LineLayer`, `SymbolLayer`, `CircleLayer`, `HeatmapLayer`
- Fill extrusion support
- Expression-based styling

---

### maplibre (josxha)

**GeoJSON Support**: ✅ **FULL**

```dart
// Add GeoJSON source
await controller.addSource(
  'my-source',
  GeoJsonSource(data: geojsonString),
);

// Add fill layer
await controller.addLayer(
  FillStyleLayer(
    id: 'my-layer',
    sourceId: 'my-source',
    paint: FillPaint(fillColor: Color(0xFF088888)),
  ),
);
```

**Features**:
- `GeoJsonSource` with dynamic data updates
- `FillStyleLayer`, `LineStyleLayer`, `SymbolStyleLayer`, `CircleStyleLayer`, `HeatmapStyleLayer`
- Fill extrusion support
- Expression-based styling with typed properties

**Difference**: josxha uses more strongly-typed layer/paint properties (generated code)

---

## 6. IMPELLER RENDERING ENGINE COMPATIBILITY

### maplibre_gl (Official)

**Impeller Support**: ⚠️ **KNOWN ISSUES**

**Open Issue**: [#196 - Impeller not supported](https://github.com/maplibre/flutter-maplibre-gl/issues/196)
- Status: **OPEN** since 2023-06-29
- Tags: `bug`, `android`
- Description: Map rendering issues when Impeller is enabled

**Related Issues**:
- [#671 - Map rendering issue on some devices](https://github.com/maplibre/flutter-maplibre-gl/issues/671) - CLOSED
- [#562 - Broken rendering after Flutter 3.29.2 upgrade](https://github.com/maplibre/flutter-maplibre-gl/issues/562) - CLOSED
- [#327 - Map flickers when app is resumed](https://github.com/maplibre/flutter-maplibre-gl/issues/327) - CLOSED

**Current Status**: 
- Impeller support is **NOT GUARANTEED**
- Rendering issues reported on Android with Impeller enabled
- Workaround: Disable Impeller in `android/app/build.gradle`

---

### maplibre (josxha)

**Impeller Support**: ✅ **NO KNOWN ISSUES**

- No open issues related to Impeller
- Recent releases (0.3.3+, 0.3.4+) include rendering improvements
- iOS FFI implementation (v0.3.4+) may have better Impeller compatibility
- **Recommendation**: Likely safer choice for Impeller-based apps

---

## 7. ANDROID & iOS SUPPORT QUALITY

### maplibre_gl (Official)

**Android**:
- MapLibre Native: **12.3.0** (as of v0.25.0)
- Kotlin: **2.3.0**
- Android Gradle Plugin: **8.13.2**
- OkHttp: **5.3.2**
- **Status**: Well-maintained, regular updates

**iOS**:
- MapLibre Native: Latest (version not explicitly stated in pubspec)
- Swift/Objective-C bindings
- **Status**: Well-maintained

**Known Issues**:
- iOS filter expression: `["!has", "value"]` must be `["!", ["has", "value"]]`
- iOS color format: Use hex `#FFAA00` instead of `rgba(...)`
- iOS crashes if `NSLocationWhenInUseUsageDescription` not set

---

### maplibre (josxha)

**Android**:
- MapLibre Native: **12.2** (as of v0.3.2)
- JNI/JNIGen: **^0.15.1**
- **Status**: Well-maintained, recent updates

**iOS**:
- MapLibre Native: **6.21** (as of v0.3.3)
- **FFI Implementation**: Complete FFI migration (v0.3.4+)
- No method channels (better performance)
- **Status**: Recently modernized with FFI

**Experimental**:
- Windows/macOS support via WebView (v0.3.4+)

**Known Issues**:
- iOS: `animateCamera()` zoom level jump (fixed in v0.3.4)
- iOS: `onStyleLoaded()` not called when style loads immediately (fixed in v0.3.4)

---

## 8. BREAKING CHANGES & MIGRATION NOTES

### maplibre_gl (Official)

**Recent Breaking Changes** (v0.24.0 - v0.25.0):

**v0.24.0** (Major):
- Feature interaction callbacks signature changed
- `OnFeatureInteractionCallback`: Now includes `id` and nullable `annotation`
- **Before**: `(Point, LatLng, Annotation, String layerId)`
- **After**: `(Point, LatLng, String id, String layerId, Annotation?)`
- Allows interaction with unmanaged style-layer features

**v0.25.0** (Minor):
- MapLibre Android SDK upgraded 11.13.5 → 12.3.0
- Kotlin upgraded to 2.3.0
- No breaking changes in API

**Migration Path**:
- From flutter-mapbox-gl: Mostly source-compatible
- Remove Mapbox token initialization
- Replace Mapbox style URLs with MapLibre/self-hosted

---

### maplibre (josxha)

**Recent Changes** (v0.3.3 - v0.3.4+1):

**v0.3.4** (Major):
- iOS: Complete FFI migration (no more method channels)
- Federated plugin restructure
- Experimental Windows/macOS support
- **No breaking changes** to public API

**v0.3.3** (Minor):
- Widget/Canvas rendering to image for markers
- Filter expressions support
- Bug fixes for iOS/Android

**Migration Path**:
- Stable API surface
- No major breaking changes expected
- Federated plugin structure is transparent to users

---

## 9. FEATURE COMPARISON MATRIX

| Feature | maplibre_gl | maplibre (josxha) | Notes |
|---------|-------------|-------------------|-------|
| **Vector Tiles** | ✅ | ✅ | Both support MVT |
| **Raster Tiles** | ✅ | ✅ | Both support raster sources |
| **Camera Control** | ✅ | ✅ | Both have full camera API |
| **Camera Callbacks** | ✅ | ✅ | Both support onCameraMove/Idle |
| **Gestures** | ✅ | ✅ | Both support all gestures |
| **Annotations** | ✅ | ✅ | Symbols, circles, lines, fills |
| **GeoJSON** | ✅ | ✅ | Both support dynamic GeoJSON |
| **Fill Layers** | ✅ | ✅ | Both support fill layers |
| **Heatmaps** | ✅ | ✅ | Both support heatmap layers |
| **Offline Regions** | ✅ | ✅ | Both support region download |
| **WidgetLayer** | ❌ | ✅ | **josxha only** - Flutter widgets at map coords |
| **CustomPaint Overlay** | ✅ | ✅ | Both support Stack composition |
| **User Location** | ✅ | ✅ | Both support location tracking |
| **Web Support** | ✅ | ✅ | Both support web via maplibre-gl-js |
| **Impeller Safe** | ⚠️ | ✅ | **josxha safer** - no known issues |
| **iOS FFI** | ❌ | ✅ | **josxha only** - v0.3.4+ |
| **Windows/macOS** | ❌ | ✅ (Experimental) | **josxha only** - WebView-based |

---

## 10. KNOWN ISSUES & OPEN PROBLEMS

### maplibre_gl (Official)

**Critical**:
- [#196] Impeller rendering broken on Android (OPEN since 2023)

**High Priority**:
- [#651] Inconsistent behavior across MapLibre GL JS runtime versions (OPEN)
- [#371] moveCamera() doesn't work in onMapCreated callback (OPEN)

**Medium Priority**:
- [#258] Add support for 'setPadding' (OPEN)
- [#299] CameraUpdate newLatLngBounds with bottom not working on iOS (OPEN)

**Total Open Issues**: 89

---

### maplibre (josxha)

**Critical**: None reported

**High Priority**:
- [#488] feat!: typed style layer properties and expressions (OPEN - feature)
- [#478] onStyleLoaded never fires on Android (OPEN)

**Medium Priority**:
- [#417] feat: handle gestures in flutter (OPEN - feature)
- [#383] Add support for custom HTTP headers in tile requests (OPEN)

**Total Open Issues**: 17 (significantly fewer)

---

## 11. RECOMMENDATION FOR YOUR USE CASE

### Your Requirements:
1. CustomPaint/shader fog-of-war overlay on top of map
2. Real-time camera state access (center, zoom, bearing)
3. Offline tile support
4. Impeller rendering engine compatibility
5. GeoJSON fill layer support

### RECOMMENDATION: **maplibre (josxha)**

**Reasons**:

1. **WidgetLayer Support** ✅
   - Built-in `WidgetLayer` + `Marker` system
   - Automatic coordinate-to-screen conversion
   - Better touch event handling via `TranslucentPointer`
   - Eliminates manual screen position calculations

2. **Impeller Safety** ✅
   - No known Impeller rendering issues
   - Official package has open #196 issue since 2023
   - iOS FFI implementation (v0.3.4+) is modern and Impeller-friendly

3. **Fewer Open Issues** ✅
   - 17 open issues vs 89 in official
   - More stable, less churn
   - Better signal-to-noise ratio

4. **Modern Architecture** ✅
   - iOS FFI (no method channels)
   - Federated plugin structure
   - Experimental Windows/macOS support

5. **All Required Features** ✅
   - Camera callbacks: ✅
   - Offline regions: ✅
   - GeoJSON + Fill layers: ✅
   - CustomPaint overlay: ✅ (via Stack)

### Caveats:

- **Smaller community**: 102 stars vs 324 (but actively maintained)
- **Fewer examples**: Official package has more documentation
- **Experimental features**: Windows/macOS are experimental

### If You Choose Official (maplibre_gl):

**Pros**:
- Larger community (324 stars)
- More examples and documentation
- Longer track record

**Cons**:
- Impeller rendering issues (open since 2023)
- No WidgetLayer - manual screen position calculation required
- More open issues (89 vs 17)
- Requires workarounds for CustomPaint overlay touch handling

---

## 12. IMPLEMENTATION NOTES FOR YOUR FOG OVERLAY

### With maplibre (josxha) - RECOMMENDED:

```dart
Stack(
  children: [
    MapLibreMap(
      onMapCreated: (controller) => _controller = controller,
      children: [
        // Your fog overlay as CustomPaint
        WidgetLayer(
          markers: [
            Marker(
              point: Geographic.latLng(lat: playerLat, lng: playerLng),
              size: Size(100, 100),
              child: CustomPaint(
                painter: FogOfWarPainter(fogState),
                size: Size(100, 100),
              ),
            ),
          ],
        ),
      ],
    ),
  ],
)
```

**Advantages**:
- Automatic coordinate tracking
- Built-in rotation/pitch support
- Touch events handled correctly

### With maplibre_gl (Official):

```dart
Stack(
  children: [
    MapLibreMap(
      onMapCreated: (controller) => _controller = controller,
      onCameraMove: (position) {
        // Manually recalculate fog overlay position
        _updateFogPosition(position);
      },
    ),
    // Manual CustomPaint overlay
    Positioned(
      left: _fogScreenX,
      top: _fogScreenY,
      child: CustomPaint(
        painter: FogOfWarPainter(fogState),
        size: Size(100, 100),
      ),
    ),
  ],
)
```

**Disadvantages**:
- Manual screen position calculation
- Must handle camera updates manually
- Touch event blocking potential

---

## CONCLUSION

**For your geo-game with fog-of-war overlay and Impeller rendering**:

→ **Use `maplibre` (josxha v0.3.4+)**

It provides:
- ✅ Built-in WidgetLayer for coordinate-based overlays
- ✅ No Impeller rendering issues
- ✅ Modern FFI architecture
- ✅ All required features (camera callbacks, offline, GeoJSON)
- ✅ Fewer bugs and better stability

The smaller community is offset by better architecture, fewer issues, and direct support for your use case.

