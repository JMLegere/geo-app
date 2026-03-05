# MapLibre Package Decision: Quick Reference

**Decision Date**: March 2, 2026  
**Recommendation**: **maplibre** (josxha) v0.3.4+  
**Status**: READY FOR IMPLEMENTATION

---

## Why maplibre (josxha)?

### 1. **WidgetLayer** - Your Killer Feature
```dart
// Automatic coordinate-to-screen conversion
WidgetLayer(
  markers: [
    Marker(
      point: Geographic.latLng(lat: playerLat, lng: playerLng),
      size: Size(100, 100),
      child: CustomPaint(painter: FogOfWarPainter(...)),
    ),
  ],
)
```
- **maplibre_gl**: ❌ No WidgetLayer - requires manual screen position calculation
- **maplibre**: ✅ Built-in, automatic tracking, handles rotation/pitch

### 2. **Impeller Rendering Safety**
- **maplibre_gl**: ⚠️ Open issue #196 since 2023 (Android Impeller broken)
- **maplibre**: ✅ No known Impeller issues, modern FFI architecture

### 3. **Stability**
- **maplibre_gl**: 89 open issues
- **maplibre**: 17 open issues (5x fewer)

### 4. **Modern Architecture**
- iOS: Complete FFI (no method channels)
- Federated plugin structure
- Better performance profile

---

## Feature Checklist ✅

| Requirement | Status | Notes |
|-------------|--------|-------|
| CustomPaint fog overlay | ✅ | Via Stack + WidgetLayer |
| Real-time camera state | ✅ | `MapEventMoveCamera` events |
| Offline tile download | ✅ | `downloadOfflineRegion()` |
| Impeller compatible | ✅ | No known issues |
| GeoJSON + Fill layers | ✅ | Full support |
| Touch event handling | ✅ | `TranslucentPointer` built-in |

---

## Implementation Path

### Step 1: Add Dependency
```yaml
dependencies:
  maplibre: ^0.3.4+1
```

### Step 2: Create Fog Overlay Widget
```dart
class FogOverlay extends StatelessWidget {
  final MapController controller;
  final FogState fogState;
  final Geographic playerLocation;

  @override
  Widget build(BuildContext context) {
    return WidgetLayer(
      markers: [
        Marker(
          point: playerLocation,
          size: Size(256, 256),
          child: CustomPaint(
            painter: FogOfWarPainter(fogState),
            size: Size(256, 256),
          ),
          rotate: true,  // Rotate with map bearing
          flat: true,    // Flatten when camera tilts
        ),
      ],
    );
  }
}
```

### Step 3: Integrate with MapLibreMap
```dart
MapLibreMap(
  onMapCreated: (controller) => _controller = controller,
  children: [
    FogOverlay(
      controller: _controller,
      fogState: fogState,
      playerLocation: playerLocation,
    ),
  ],
)
```

### Step 4: Listen to Camera Events
```dart
_controller.onEvent.add((event) {
  if (event is MapEventMoveCamera) {
    final camera = event.camera;
    logger.info('Camera: zoom=${camera.zoom}, bearing=${camera.bearing}');
  }
});
```

---

## Known Limitations

1. **Smaller Community**: 102 stars vs 324 (official)
   - Mitigation: Code is well-maintained, active development
   
2. **Fewer Examples**: Official has more documentation
   - Mitigation: API is intuitive, source code is readable

3. **Windows/macOS Experimental**: WebView-based
   - Mitigation: Not required for your use case (mobile-first)

---

## Fallback Plan

If josxha package encounters critical issues:

1. **Switch to maplibre_gl** (official)
2. Implement manual WidgetLayer equivalent:
   ```dart
   // Calculate screen position from lat/lng
   final screenPos = await controller.toScreenLocation(latLng);
   
   // Update on camera move
   controller.onCameraMove.add((position) {
     _updateFogScreenPosition(position);
   });
   ```
3. Use `gestureRecognizers` to prevent touch blocking

---

## Testing Checklist

- [ ] Fog overlay renders at correct map coordinates
- [ ] Fog overlay rotates with map bearing
- [ ] Fog overlay flattens when camera tilts
- [ ] Touch events pass through to map (no blocking)
- [ ] Camera callbacks fire during gestures
- [ ] Offline region download works
- [ ] GeoJSON fill layers render correctly
- [ ] Impeller rendering is smooth (no flicker)
- [ ] iOS and Android both work
- [ ] Performance is acceptable at zoom 12-18

---

## References

- **Full Comparison**: See `MAPLIBRE_COMPARISON.md`
- **Official Docs**: https://flutter-maplibre.pages.dev/docs/
- **GitHub**: https://github.com/josxha/flutter-maplibre
- **Pub.dev**: https://pub.dev/packages/maplibre

---

## Next Steps

1. ✅ Decision made: Use `maplibre` (josxha)
2. → Add to pubspec.yaml
3. → Implement FogOverlay widget
4. → Test on iOS + Android with Impeller enabled
5. → Integrate with existing FogStateProvider
6. → Performance profiling

