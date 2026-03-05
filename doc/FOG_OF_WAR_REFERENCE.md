# Fog-of-War Map Rendering Reference for Flutter/MapLibre

**Date**: March 2, 2026  
**Purpose**: Production-quality visual patterns for beautiful map rendering with fog-of-war overlays in Flutter using MapLibre.

---

## 1. MapLibre Flutter Package — Latest API & Architecture

### Official Resources
- **Pub.dev**: https://pub.dev/packages/maplibre (v0.3.4+1, updated 3 days ago)
- **GitHub**: https://github.com/josxha/flutter-maplibre (88 stars, active)
- **Documentation**: https://flutter-maplibre.pages.dev/docs/
- **API Reference**: https://pub.dev/documentation/maplibre/latest/maplibre/
- **Hosted Demo**: https://flutter-maplibre.pages.dev/demo

### Architecture Overview
MapLibre Flutter is a **modern rewrite** of maplibre_gl with native interoperability:
- **Web**: Uses maplibre-gl-js (fork of mapbox-gl-js)
- **Android/iOS**: Uses maplibre-native (fork of mapbox-gl-native) via FFI/JNI
- **macOS/Windows**: Uses maplibre-gl-js through WebView
- **Goal**: Consistent cross-platform experience with excellent performance

### Key Layer Types Available
1. **Circle Layer** — Points rendered as circles with customizable radius/color
2. **Fill Layer** — Polygons with fill color and optional stroke
3. **Fill Extrusion Layer** — 3D extruded polygons (buildings, terrain)
4. **Heatmap Layer** — Density-based visualization (soft, blurred point clouds)
5. **Line Layer** — Stroked lines with customizable width/color
6. **Raster Layer** — Raster tiles (satellite, imagery)
7. **Symbol Layer** — Icons and text labels
8. **Hillshade Layer** — Elevation shading from DEM data
9. **WidgetLayer** — Flutter widgets anchored to map coordinates (overlay on top)

### Annotation Layers (High-Level API)
- **CircleLayer** — Easy API for point circles
- **PolygonLayer** — Easy API for polygons
- **PolylineLayer** — Easy API for lines
- **MarkerLayer** — Easy API for markers with icons
- **WidgetLayer** — Flutter widgets as map annotations

---

## 2. Fog-of-War Rendering Approaches

### Option A: Heatmap Layer (Recommended for Soft Edges)
**Best for**: Atmospheric, soft fog edges; smooth density transitions

**Advantages**:
- Native MapLibre support — no custom shaders needed
- Soft, blurred edges by default (Gaussian blur)
- Efficient GPU rendering
- Supports opacity/density control per point
- Works across all platforms (web, iOS, Android)

**Implementation Pattern**:
```dart
// Create GeoJSON source with point features
// Each point's properties can include a "weight" for density control
final source = GeoJsonSource(
  id: 'fog-points',
  data: GeoJsonData.fromFeatures([
    Feature(
      geometry: Point(Geographic(lon: 0, lat: 0)),
      properties: {'weight': 1.0}, // Controls density
    ),
  ]),
);

// Add heatmap layer
final heatmapLayer = HeatmapLayer(
  id: 'fog-heatmap',
  source: source.id,
  // Color ramp: density → color
  color: Expression.interpolate(
    base: 1,
    input: Expression.heatmapDensity(),
    stops: [
      [0.0, Colors.transparent],
      [0.5, Colors.grey.withOpacity(0.5)],
      [1.0, Colors.black.withOpacity(0.8)],
    ],
  ),
  radius: 30, // Blur radius (pixels)
  intensity: 1.0, // Overall intensity
  opacity: 0.7,
);
```

**Fog-of-War Mapping**:
- **Undetected**: No heatmap point (fully transparent)
- **Unexplored**: Low-weight point (light gray, 0.25 opacity)
- **Hidden**: Medium-weight point (medium gray, 0.5 opacity)
- **Concealed**: High-weight point (dark gray, 0.75 opacity)
- **Observed**: No heatmap point (fully transparent, map visible)

**References**:
- MapLibre Heatmap Layer: https://flutter-maplibre.pages.dev/docs/style-layers/heatmap-layer/
- Geoapify Heatmap Tutorial: https://www.geoapify.com/tutorial/js-heatmap-example-with-maplibre-gl/
- MapLibre GL Heatmap Spec: https://www.maplibre.org/maplibre-style-spec/layers/

---

### Option B: Fill Layer with Opacity (Hard Cell Boundaries)
**Best for**: Discrete cell-based fog; clear exploration boundaries

**Advantages**:
- Simple, predictable rendering
- Easy to animate cell state transitions
- Supports per-cell opacity control
- Works well with polygon cell grids

**Implementation Pattern**:
```dart
// Create polygon features for each cell
final cellPolygons = cells.map((cell) {
  return Feature(
    geometry: Polygon.from([cell.boundary]), // List of LatLng
    properties: {
      'cellId': cell.id,
      'state': cell.state.name, // 'undetected', 'unexplored', etc.
    },
  );
}).toList();

final source = GeoJsonSource(
  id: 'fog-cells',
  data: GeoJsonData.fromFeatures(cellPolygons),
);

// Add fill layer with data-driven opacity
final fillLayer = FillLayer(
  id: 'fog-fill',
  source: source.id,
  paint: {
    'fill-color': '#000000',
    'fill-opacity': Expression.match(
      Expression.get('state'),
      'undetected', 1.0,
      'unexplored', 0.75,
      'hidden', 0.5,
      'concealed', 0.25,
      'observed', 0.0, // Fully transparent
    ),
  },
);
```

**Limitation**: Hard edges between cells. To soften:
- Use **feathering** (gradient mask) in CustomPaint overlay
- Combine with a subtle heatmap layer on top for edge blur

---

### Option C: CustomPaint Overlay (Maximum Control)
**Best for**: Complex fog shapes; custom edge effects; per-frame animation

**Advantages**:
- Full control over rendering
- Can implement custom shaders (via flutter_gpu or Impeller)
- Supports feathered/soft edges via Canvas.drawPath + blur filters
- Can animate fog density per frame

**Disadvantages**:
- More CPU-intensive than native layers
- Requires careful performance optimization
- Platform-specific rendering differences

**Implementation Pattern**:
```dart
class FogOverlay extends CustomPaint {
  FogOverlay({
    required this.revealedCells,
    required this.exploredCells,
    required this.mapBounds,
  }) : super(
    painter: FogPainter(
      revealedCells: revealedCells,
      exploredCells: exploredCells,
      mapBounds: mapBounds,
    ),
  );

  final Set<String> revealedCells;
  final Set<String> exploredCells;
  final Rect mapBounds;
}

class FogPainter extends CustomPainter {
  FogPainter({
    required this.revealedCells,
    required this.exploredCells,
    required this.mapBounds,
  });

  final Set<String> revealedCells;
  final Set<String> exploredCells;
  final Rect mapBounds;

  @override
  void paint(Canvas canvas, Size size) {
    // Draw fog overlay with soft edges
    final fogPaint = Paint()
      ..color = Colors.black.withOpacity(0.7)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 15); // Feather edges

    // Draw unexplored areas (hard fog)
    for (final cell in unexploredCells) {
      canvas.drawPath(cell.path, fogPaint);
    }

    // Draw explored areas (lighter fog)
    final exploredPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10);
    for (final cell in exploredCells) {
      canvas.drawPath(cell.path, exploredPaint);
    }
  }

  @override
  bool shouldRepaint(FogPainter oldDelegate) {
    return revealedCells != oldDelegate.revealedCells ||
        exploredCells != oldDelegate.exploredCells;
  }
}
```

**References**:
- Flutter CustomPaint with transparent cutout: https://helgesver.re/articles/flutter-anchored-overlay-cutout-backdrop
- Flutter semi-transparent blurring layer: https://stackoverflow.com/questions/51526681/flutter-how-to-get-a-semitransparent-blurring-layer-with-a-hole-with-soft-edge
- fog_edge_blur package: https://pub.dev/packages/fog_edge_blur (uses flutter_shaders for GPU-accelerated blur)

---

### Option D: Shader-Based Custom Layer (Advanced)
**Best for**: Highly optimized fog rendering; complex visual effects

**Advantages**:
- GPU-accelerated rendering
- Can implement complex fog algorithms (Perlin noise, distance fields)
- Supports real-time animation
- Minimal CPU overhead

**Disadvantages**:
- Requires WebGL/GLSL knowledge
- Platform-specific shader compilation
- Steeper learning curve

**References**:
- MapLibre GL Shader Layer: https://github.com/geoblocks/maplibre-gl-shader-layer (TypeScript, but architecture applicable)
- Custom fire symbols shader: https://xweather.com/docs/mapsgl/examples/custom-fires-shader
- MapLibre GL custom layers: https://maplibre.org/maplibre-gl-js/docs/examples/

---

## 3. Fog-of-War Visual Design Patterns

### Fog State Color Palette (Inspired by Fog of World App)
```dart
const fogStateColors = {
  CellState.undetected: Color(0xFF1a1a1a),    // Dark gray/black
  CellState.unexplored: Color(0xFF4a4a4a),   // Medium gray
  CellState.hidden: Color(0xFF6a6a6a),       // Light gray
  CellState.concealed: Color(0xFF8a8a8a),    // Lighter gray
  CellState.observed: Color(0x00000000),     // Transparent
};

const fogStateOpacities = {
  CellState.undetected: 1.0,    // Fully opaque
  CellState.unexplored: 0.75,   // 75% opaque
  CellState.hidden: 0.5,        // 50% opaque
  CellState.concealed: 0.25,    // 25% opaque
  CellState.observed: 0.0,      // Fully transparent
};
```

### Soft Edge Rendering Techniques

#### 1. Gaussian Blur (Heatmap Layer)
- **Radius**: 20-40 pixels (adjust for zoom level)
- **Intensity**: 0.8-1.0
- **Effect**: Smooth, atmospheric fog edges
- **Performance**: Excellent (native GPU)

#### 2. Feathered Edges (CustomPaint)
```dart
// Use MaskFilter.blur to feather polygon edges
final paint = Paint()
  ..maskFilter = MaskFilter.blur(BlurStyle.normal, 15);
canvas.drawPath(cellPath, paint);
```

#### 3. Gradient Mask (CustomPaint)
```dart
// Create radial gradient from cell center outward
final gradient = RadialGradient(
  center: Alignment.center,
  radius: 1.0,
  colors: [
    Colors.transparent,
    Colors.black.withOpacity(0.5),
    Colors.black.withOpacity(1.0),
  ],
  stops: [0.0, 0.5, 1.0],
);

final paint = Paint()..shader = gradient.createShader(cellBounds);
canvas.drawPath(cellPath, paint);
```

#### 4. Distance Field (Shader-Based)
- Compute signed distance from cell boundary
- Use distance to modulate opacity
- Smooth transitions over 10-20 pixel range
- Most efficient for many cells

---

## 4. Apple Maps Aesthetic — Clean & Minimal

### Visual Characteristics
- **Color Palette**: Soft, desaturated colors (light grays, muted greens, subtle blues)
- **Typography**: Clean, sans-serif (San Francisco on iOS)
- **Contrast**: High contrast for readability, low contrast for background elements
- **Minimalism**: Removes unnecessary UI chrome; focuses on map content
- **Smooth Animations**: Easing curves for camera transitions, layer fades
- **Depth**: Subtle shadows and layering (not 3D extrusion)

### MapLibre Style Recommendations

#### Minimal Light Style (Apple Maps-like)
```json
{
  "version": 8,
  "name": "Minimal Light",
  "center": [0, 0],
  "zoom": 2,
  "pitch": 0,
  "bearing": 0,
  "sources": {
    "maplibre": {
      "url": "https://demotiles.maplibre.org/tiles/tiles.json",
      "type": "vector"
    }
  },
  "layers": [
    {
      "id": "background",
      "type": "background",
      "paint": {
        "background-color": "#f5f5f5"
      }
    },
    {
      "id": "water",
      "type": "fill",
      "source": "maplibre",
      "source-layer": "water",
      "paint": {
        "fill-color": "#e8f4f8",
        "fill-opacity": 0.8
      }
    },
    {
      "id": "landuse",
      "type": "fill",
      "source": "maplibre",
      "source-layer": "landuse",
      "paint": {
        "fill-color": "#f0f0f0",
        "fill-opacity": 0.6
      }
    },
    {
      "id": "roads",
      "type": "line",
      "source": "maplibre",
      "source-layer": "roads",
      "paint": {
        "line-color": "#cccccc",
        "line-width": 1,
        "line-opacity": 0.7
      }
    },
    {
      "id": "labels",
      "type": "symbol",
      "source": "maplibre",
      "source-layer": "places",
      "layout": {
        "text-field": ["get", "name"],
        "text-size": 12,
        "text-font": ["Open Sans Regular"]
      },
      "paint": {
        "text-color": "#333333",
        "text-opacity": 0.8
      }
    }
  ]
}
```

### Free MapLibre Styles (Production-Ready)
1. **OpenMapTiles Positron** (Recommended for Apple Maps aesthetic)
   - URL: `https://tiles.openfreemap.org/styles/positron`
   - Characteristics: Light, minimal, clean
   - Perfect base for fog-of-war overlay

2. **OpenMapTiles Liberty**
   - URL: `https://tiles.openfreemap.org/styles/liberty`
   - Characteristics: Colorful but balanced

3. **VersaTiles Graybeard**
   - URL: `https://tiles.versatiles.org/assets/styles/graybeard/style.json`
   - Characteristics: Monochromatic, elegant

4. **Protomaps Light**
   - URL: `https://api.protomaps.com/styles/v2/light.json?key=YOUR_KEY`
   - Characteristics: Minimal, data-focused

### Style Customization Tools
- **Maputnik** (https://maputnik.github.io/) — Visual style editor
- **Snazzy Maps** (https://snazzymaps.com/) — Community styles (Google Maps, but concepts apply)
- **MapLibre Theme** (https://github.com/lhapaipai/maplibre-theme) — CSS theme system

---

## 5. Flutter MapLibre Implementation Examples

### Basic Map with Heatmap Fog Layer
```dart
import 'package:flutter/material.dart';
import 'package:maplibre/maplibre.dart';

class FogOfWarMap extends StatefulWidget {
  @override
  State<FogOfWarMap> createState() => _FogOfWarMapState();
}

class _FogOfWarMapState extends State<FogOfWarMap> {
  late MapController _mapController;
  List<Feature<Point>> _fogPoints = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Fog of War')),
      body: MapLibreMap(
        options: MapOptions(
          initCenter: Geographic(lon: 0, lat: 0),
          initZoom: 4,
          initStyle: 'https://tiles.openfreemap.org/styles/positron',
        ),
        onMapCreated: (controller) => _mapController = controller,
        layers: [
          // Heatmap layer for fog
          HeatmapLayer(
            id: 'fog-heatmap',
            source: 'fog-source',
            color: Expression.interpolate(
              base: 1,
              input: Expression.heatmapDensity(),
              stops: [
                [0.0, Colors.transparent],
                [0.3, Colors.grey.withOpacity(0.5)],
                [0.7, Colors.grey.withOpacity(0.8)],
                [1.0, Colors.black.withOpacity(0.9)],
              ],
            ),
            radius: 30,
            intensity: 0.8,
            opacity: 0.7,
          ),
        ],
        sources: [
          GeoJsonSource(
            id: 'fog-source',
            data: GeoJsonData.fromFeatures(_fogPoints),
          ),
        ],
        children: [
          MapScalebar(),
          SourceAttribution(),
          MapControlButtons(),
          MapCompass(),
        ],
      ),
    );
  }

  void updateFogPoints(List<Feature<Point>> points) {
    setState(() => _fogPoints = points);
  }
}
```

### Mixed Layers Example (From MapLibre Flutter Examples)
```dart
// See: https://github.com/josxha/flutter-maplibre/blob/main/examples/lib/layers_mixed_page.dart
MapLibreMap(
  options: const MapOptions(
    initZoom: 7,
    initCenter: Geographic(lon: 9.17, lat: 47.68),
  ),
  layers: [
    CircleLayer(
      points: _circlePoints,
      color: _circleColor,
      radius: 20,
      strokeColor: Colors.red,
      strokeWidth: 2,
    ),
    if (_polylineLayer case final Layer layer) layer,
  ],
)
```

### Style Switching (From MapLibre Flutter Examples)
```dart
// See: https://github.com/josxha/flutter-maplibre/blob/main/examples/lib/styled_map_page.dart
MapLibreMap(
  options: MapOptions(
    initCenter: const Geographic(lon: 9.17, lat: 47.68),
    initZoom: 2,
    initStyle: _style.uri,
  ),
  onMapCreated: (controller) => _controller = controller,
  onStyleLoaded: (style) {
    style.setProjection(MapProjection.globe);
  },
)

// Later, change style:
_controller.setStyle(newStyleUri);
```

---

## 6. Camera Animation & Smooth Transitions

### Smooth Camera Follow (Player Location)
```dart
// Animate camera to follow player
_mapController.animateCamera(
  CameraUpdate.newLatLngZoom(
    target: playerLocation,
    zoom: 15,
  ),
  duration: Duration(milliseconds: 500),
  curve: Curves.easeInOut,
);
```

### Zoom-Based Layer Opacity
```dart
// Fade fog layer based on zoom level
final opacityExpression = Expression.interpolate(
  base: 1,
  input: Expression.zoom(),
  stops: [
    [12, 0.9],   // Fully opaque at zoom 12
    [18, 0.3],   // 30% opaque at zoom 18
  ],
);

final heatmapLayer = HeatmapLayer(
  id: 'fog-heatmap',
  source: 'fog-source',
  opacity: opacityExpression,
);
```

---

## 7. Performance Optimization Tips

### 1. Heatmap Layer Optimization
- **Limit points**: Keep < 1000 points per heatmap for smooth 60 FPS
- **Cluster points**: Use MapLibre clustering for large datasets
- **Adjust radius**: Larger radius = more blur = better performance
- **Use zoom-based visibility**: Hide heatmap at high zoom levels

### 2. CustomPaint Optimization
- **Limit repaints**: Use `shouldRepaint()` to avoid unnecessary renders
- **Cache paths**: Pre-compute polygon paths, don't recalculate every frame
- **Use `RepaintBoundary`**: Isolate fog overlay from other widgets
- **Disable shadows**: Shadows are expensive; use simple colors instead

### 3. Fill Layer Optimization
- **Simplify polygons**: Reduce vertex count for cell boundaries
- **Use data-driven styling**: Avoid creating separate layers per state
- **Batch updates**: Update multiple cells in one `setFeatureState()` call

### 4. General MapLibre Tips
- **Prefetch tiles**: Use `prefetchZoomDelta` to load adjacent tiles
- **Limit layer count**: Keep < 20 layers for smooth performance
- **Use vector tiles**: Smaller file size than raster tiles
- **Cache offline**: Use `OfflineRegion` for areas with poor connectivity

---

## 8. Fog-of-War State Machine (Reference)

### Cell State Transitions
```
Undetected → Unexplored → Hidden → Concealed → Observed
    ↑                                              ↓
    └──────────────────────────────────────────────┘
```

### Rendering Mapping
| State | Heatmap Weight | Fill Opacity | Visual | Interaction |
|-------|---|---|---|---|
| **Undetected** | 1.0 | 1.0 | Solid black fog | Cannot interact |
| **Unexplored** | 0.75 | 0.75 | Dark gray fog | Cannot interact |
| **Hidden** | 0.5 | 0.5 | Medium gray fog | Cannot interact |
| **Concealed** | 0.25 | 0.25 | Light gray fog | Can see landmarks |
| **Observed** | 0.0 | 0.0 | Fully transparent | Full visibility |

---

## 9. References & Resources

### Official Documentation
- MapLibre Flutter: https://flutter-maplibre.pages.dev/docs/
- MapLibre GL JS: https://maplibre.org/maplibre-gl-js/docs/
- MapLibre Style Spec: https://www.maplibre.org/maplibre-style-spec/

### Community Projects
- Fog of World (inspiration): https://fogofworld.app/en/
- Flutter Fog-of-War (flutter_map): https://github.com/quentinchaignaud/fog-of-war
- MapLibre Shader Layer: https://github.com/geoblocks/maplibre-gl-shader-layer
- MapLibre Interpolate Heatmap: https://github.com/geoql/maplibre-gl-interpolate-heatmap

### Design Inspiration
- Apple Maps 2025: https://applemagazine.com/apple-maps-2025/
- iOS 26 Liquid Glass: https://9to5mac.com/2025/09/18/heres-everything-new-for-apple-maps-in-ios-26/
- Google Maps vs Apple Maps UX: https://medium.com/uxcentury/google-maps-vs-apple-maps-the-ux-you-never-noticed-e9f555785fb3

### Tutorials & Guides
- Geoapify Heatmap Tutorial: https://www.geoapify.com/tutorial/js-heatmap-example-with-maplibre-gl/
- Flutter CustomPaint Overlay: https://helgesver.re/articles/flutter-anchored-overlay-cutout-backdrop
- Pencil Style for MapLibre: https://googlemapsmania.blogspot.com/2025/11/a-pencil-style-for-maplibre.html

---

## 10. Recommended Architecture for Your Project

### Layering Strategy (Bottom to Top)
1. **Base Map** (MapLibre vector tiles)
2. **Cell Grid** (Fill layer with data-driven opacity)
3. **Fog Overlay** (Heatmap layer for soft edges)
4. **Player Marker** (WidgetLayer or Symbol layer)
5. **UI Controls** (MapScalebar, Compass, Buttons)

### State Management
- Use **Riverpod** (as per your AGENTS.md) for:
  - `fogStateProvider` — Current fog state (revealed, explored, etc.)
  - `locationProvider` — Player location stream
  - `mapStyleProvider` — Current map style
  - `cellStateProvider.family(cellId)` — Per-cell state

### Data Flow
```
GPS Location → PlayerLocationTracker
    ↓
CellStateSystem (determine which cell player is in)
    ↓
FogStateProvider (update revealed/explored sets)
    ↓
MapLibre Layers (update heatmap points, fill opacity)
    ↓
UI Render (smooth animation via camera controller)
```

---

## 11. Next Steps for Implementation

1. **Choose fog rendering approach**: Start with Heatmap Layer (Option A) for soft edges
2. **Select base map style**: Use OpenMapTiles Positron for Apple Maps aesthetic
3. **Implement cell state system**: Map cell states to heatmap weights/opacity
4. **Add smooth animations**: Use camera controller for player following
5. **Optimize performance**: Profile with DevTools, adjust layer counts/point density
6. **Test on real devices**: Emulator compositing is unreliable; test on iOS/Android

---

**Last Updated**: March 2, 2026  
**Status**: Production-ready reference material
