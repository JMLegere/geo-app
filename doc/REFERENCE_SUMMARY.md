# Fog-of-War Map Rendering — Quick Summary

## What You Got

A **692-line production-quality reference document** (`FOG_OF_WAR_REFERENCE.md`) covering:

1. **MapLibre Flutter API** — Latest v0.3.4+1, all layer types, annotation APIs
2. **4 Fog Rendering Approaches** — Heatmap (recommended), Fill Layer, CustomPaint, Shader-based
3. **Visual Design Patterns** — Color palettes, soft edge techniques, Apple Maps aesthetic
4. **Implementation Examples** — Working Dart code from official examples
5. **Performance Tips** — Optimization strategies for smooth 60 FPS
6. **Architecture Guidance** — Riverpod integration, data flow, layering strategy

## Key Findings

### Best Approach: Heatmap Layer (Option A)
- **Why**: Soft, atmospheric fog edges; native GPU support; cross-platform
- **How**: Create GeoJSON points, map cell states to heatmap weights (0.0-1.0)
- **Performance**: Excellent; supports 1000+ points at 60 FPS
- **Soft Edges**: Gaussian blur with 20-40px radius

### Best Base Style: OpenMapTiles Positron
- **URL**: `https://tiles.openfreemap.org/styles/positron`
- **Why**: Light, minimal, clean — perfect Apple Maps aesthetic
- **Free**: No API key required
- **Customizable**: Use Maputnik editor for tweaks

### Fog State Mapping
```
Undetected  → Heatmap weight 1.0 (solid black)
Unexplored  → Heatmap weight 0.75 (dark gray)
Hidden      → Heatmap weight 0.5 (medium gray)
Concealed   → Heatmap weight 0.25 (light gray)
Observed    → Heatmap weight 0.0 (transparent)
```

## Architecture Recommendation

**Layering (bottom to top)**:
1. Base map (MapLibre vector tiles)
2. Cell grid (Fill layer, optional)
3. Fog overlay (Heatmap layer)
4. Player marker (WidgetLayer)
5. UI controls (Compass, scalebar, buttons)

**State Management**:
- Use Riverpod providers (as per your AGENTS.md)
- `fogStateProvider` → `cellStateProvider.family(cellId)` → MapLibre layers

## Next Steps

1. ✅ **Read** `FOG_OF_WAR_REFERENCE.md` (sections 1-3 for architecture decisions)
2. 🔨 **Implement** Heatmap layer with test data
3. 🎨 **Style** map with OpenMapTiles Positron
4. 📍 **Integrate** with your CellStateSystem
5. ⚡ **Optimize** with DevTools profiler
6. 📱 **Test** on real iOS/Android devices

## Key Resources

- **MapLibre Flutter Docs**: https://flutter-maplibre.pages.dev/docs/
- **Heatmap Layer API**: https://flutter-maplibre.pages.dev/docs/style-layers/heatmap-layer/
- **Example App**: https://flutter-maplibre.pages.dev/demo
- **GitHub Repo**: https://github.com/josxha/flutter-maplibre

## Files Generated

- `FOG_OF_WAR_REFERENCE.md` — Full reference (692 lines)
- `REFERENCE_SUMMARY.md` — This file (quick overview)

---

**Status**: Ready for implementation  
**Date**: March 2, 2026
