# Fog-of-War Rendering Approach — Decision Matrix

## Quick Comparison

| Aspect | Heatmap Layer | Fill Layer | CustomPaint | Shader |
|--------|---|---|---|---|
| **Soft Edges** | ✅ Native blur | ❌ Hard edges | ✅ Feathering | ✅ Distance field |
| **Performance** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Ease of Use** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐ |
| **Cross-Platform** | ✅ All | ✅ All | ✅ All | ⚠️ Platform-specific |
| **Animation** | ✅ Smooth | ✅ Smooth | ✅ Per-frame | ✅ Real-time |
| **Customization** | ⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Learning Curve** | Easy | Very Easy | Medium | Hard |
| **Max Points** | 1000+ | 100+ | 50+ | 10000+ |

---

## Recommendation by Use Case

### 🎯 "I want beautiful, atmospheric fog with soft edges"
**→ Use Heatmap Layer (Option A)**

**Why**:
- Gaussian blur creates naturally soft edges
- GPU-accelerated, excellent performance
- Works on all platforms without modification
- Minimal code to implement

**Implementation Time**: 2-3 hours

**Code Complexity**: Low
```dart
HeatmapLayer(
  id: 'fog-heatmap',
  source: 'fog-source',
  color: Expression.interpolate(...),
  radius: 30,
  opacity: 0.7,
)
```

---

### 🎮 "I want discrete cell-based fog with clear boundaries"
**→ Use Fill Layer (Option B)**

**Why**:
- Simple, predictable rendering
- Easy to animate cell state transitions
- Per-cell opacity control
- Minimal GPU overhead

**Implementation Time**: 1-2 hours

**Code Complexity**: Very Low
```dart
FillLayer(
  id: 'fog-fill',
  source: 'fog-cells',
  paint: {
    'fill-color': '#000000',
    'fill-opacity': Expression.match(...),
  },
)
```

**Caveat**: Hard edges. Combine with subtle heatmap for softness.

---

### 🎨 "I want full control over fog rendering and custom effects"
**→ Use CustomPaint Overlay (Option C)**

**Why**:
- Full control over rendering
- Can implement custom edge effects
- Supports per-frame animation
- Can use flutter_shaders for GPU acceleration

**Implementation Time**: 4-6 hours

**Code Complexity**: Medium
```dart
class FogPainter extends CustomPainter {
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 15);
    canvas.drawPath(cellPath, paint);
  }
}
```

**Caveat**: More CPU-intensive; requires careful optimization.

---

### 🚀 "I want maximum performance with complex fog algorithms"
**→ Use Shader-Based Custom Layer (Option D)**

**Why**:
- GPU-accelerated rendering
- Can implement complex algorithms (Perlin noise, distance fields)
- Minimal CPU overhead
- Supports 10000+ points

**Implementation Time**: 8-12 hours

**Code Complexity**: Hard (requires GLSL/WebGL knowledge)

**Caveat**: Platform-specific shader compilation; steeper learning curve.

---

## Hybrid Approach (Recommended for Production)

**Combine Heatmap + Fill Layer**:

1. **Fill Layer** (bottom) — Discrete cell boundaries with data-driven opacity
2. **Heatmap Layer** (top) — Soft edge blur for atmospheric effect

**Advantages**:
- Clear cell boundaries (game-like feel)
- Soft edges (beautiful aesthetic)
- Excellent performance
- Easy to animate

**Implementation**:
```dart
MapLibreMap(
  layers: [
    // Cell boundaries (hard edges)
    FillLayer(
      id: 'fog-cells',
      source: 'fog-cells',
      paint: {
        'fill-color': '#000000',
        'fill-opacity': Expression.match(
          Expression.get('state'),
          'undetected', 1.0,
          'unexplored', 0.75,
          'hidden', 0.5,
          'concealed', 0.25,
          'observed', 0.0,
        ),
      },
    ),
    // Soft edge blur (atmospheric)
    HeatmapLayer(
      id: 'fog-blur',
      source: 'fog-blur-source',
      radius: 25,
      opacity: 0.3, // Subtle overlay
    ),
  ],
)
```

---

## Decision Tree

```
START
  ↓
Do you want soft, atmospheric edges?
  ├─ YES → Do you need per-frame animation?
  │         ├─ YES → CustomPaint (Option C)
  │         └─ NO → Heatmap Layer (Option A) ✅ RECOMMENDED
  │
  └─ NO → Do you need discrete cell boundaries?
           ├─ YES → Fill Layer (Option B)
           └─ NO → Shader Layer (Option D)
```

---

## Performance Benchmarks (Estimated)

### Heatmap Layer
- **Points**: 1000
- **FPS**: 60 (smooth)
- **Memory**: ~10 MB
- **GPU Load**: Low

### Fill Layer
- **Cells**: 100
- **FPS**: 60 (smooth)
- **Memory**: ~5 MB
- **GPU Load**: Very Low

### CustomPaint
- **Cells**: 50
- **FPS**: 50-60 (depends on complexity)
- **Memory**: ~15 MB
- **GPU Load**: Medium

### Shader Layer
- **Points**: 10000
- **FPS**: 60 (smooth)
- **Memory**: ~20 MB
- **GPU Load**: Low (GPU-accelerated)

---

## Implementation Roadmap

### Phase 1: MVP (Week 1)
- [ ] Implement Heatmap Layer with test data
- [ ] Use OpenMapTiles Positron style
- [ ] Basic fog state mapping (5 states)
- [ ] Player marker with WidgetLayer

### Phase 2: Polish (Week 2)
- [ ] Add smooth camera animations
- [ ] Implement zoom-based opacity
- [ ] Add cell grid visualization (optional)
- [ ] Performance profiling with DevTools

### Phase 3: Advanced (Week 3+)
- [ ] Hybrid Heatmap + Fill Layer approach
- [ ] Custom edge effects (feathering, gradients)
- [ ] Real-time fog animation
- [ ] Offline caching for explored areas

---

## Final Recommendation

**For your project (beautiful, Apple Maps-like aesthetic)**:

### Start with: **Heatmap Layer (Option A)**
- ✅ Soft, atmospheric fog edges
- ✅ Excellent performance
- ✅ Cross-platform support
- ✅ Easy to implement
- ✅ Aligns with "visually stunning" goal

### Later, consider: **Hybrid Heatmap + Fill Layer**
- Adds discrete cell boundaries (game-like feel)
- Maintains soft edges (beautiful aesthetic)
- Best of both worlds

### Avoid initially: **CustomPaint, Shader**
- More complex
- Overkill for MVP
- Can add later if needed for advanced effects

---

## Code Template to Get Started

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

---

**Status**: Ready to implement  
**Recommended Approach**: Heatmap Layer (Option A)  
**Estimated MVP Time**: 2-3 hours  
**Date**: March 2, 2026
