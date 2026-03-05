# Fog Shader Spike Results

**Status**: Code complete, math tested, device visual testing pending  
**Date**: 2026-03-02

---

## Approach

CustomPaint + `FragmentProgram` overlay in a `Stack` above `MapLibreMap`.

The GLSL shader (`shaders/fog.frag`) runs entirely on the GPU:
- Reads 6 uniforms: viewport size (2), player screen position (2), reveal radius (1), fog density (1).
- Computes per-fragment distance to player via `length(fragCoord - playerPos)`.
- Applies `smoothstep` across the annulus `[0.7 × revealRadius, revealRadius]` for a soft edge.
- Outputs `vec4(0.1, 0.1, 0.15, fog × 0.85)` — dark navy with variable alpha.

---

## Architecture

```
FogMath (pure Dart)
  └─ Mirrors GLSL smoothstep logic
  └─ Fully unit-testable without GPU

FogShaderPainter (CustomPainter)
  └─ Receives ui.FragmentShader
  └─ Sets 6 uniforms, drawRect full viewport
  └─ shouldRepaint on position/radius/density changes

FogOverlayWidget (StatefulWidget)
  └─ Loads shader via FragmentProgram.fromAsset
  └─ Wrapped in IgnorePointer → map gestures pass through
  └─ Uses LayoutBuilder for viewport size

FogSpikeScreen (Widget)
  └─ Stack: MapLibreMap (bottom) + FogOverlayWidget (top)
  └─ Hardcoded player position at SF (37.7749, -122.4194)
  └─ Debug HUD (bottom-left)
```

---

## Camera Sync Strategy

1. `MapLibreMap.onMapCreated` stores `MapController`.
2. `MapLibreMap.onStyleLoaded` triggers first projection and shows overlay.
3. `MapLibreMap.onEvent` receives `MapEventMoveCamera` on every camera change.
4. `MapController.toScreenLocation(Position)` (`async`) converts the player's
   geographic position to screen pixels.
5. `setState` rebuilds `FogOverlayWidget` with the new `Offset`.

This ensures the clear region stays pinned to the player's geographic position
as the user pans/zooms, with no drift.

---

## Known Risks

### Platform View Compositing (High)
MapLibre renders via a native GL surface (Android `SurfaceView` / iOS `MTKView`).
Flutter's CustomPaint renders on the Flutter texture. Compositing the two can
produce flickering or black frames on some devices/drivers — especially on
Android with Vulkan + Impeller enabled.

**Mitigation options (for device testing phase)**:
- Set `androidMode: AndroidPlatformViewMode.tlhc_vd` (already MapLibre default)
  which uses Texture Layer Hybrid Composition — reduces compositing overhead.
- Disable Impeller on Android if compositing fails: add
  `FLTEnableImpeller=false` to `AndroidManifest.xml`.
- As a last resort, disable the fog overlay during active panning and re-enable
  on `MapEventStopMoveCamera`.

### Fallback Plan
If shader compositing causes persistent flickering on device:

1. **MapLibre FillLayer approach**: Create a GeoJSON polygon covering the entire
   map with a hole at the player position. Add as a `FillLayer` with
   `fillColor: rgba(26, 26, 38, 0.85)` and `fillOpacity` keyed to fog state.
   Pro: zero compositing issues (stays in native GL). Con: requires GeoJSON
   polygon updates on every camera move; harder to achieve the smooth edge.

2. **Canvas + ClipPath approach**: Render fog in a Flutter `CustomPaint`
   (no shader) using `canvas.clipPath` + `canvas.drawColor`. Pro: no GPU
   dependency. Con: no smooth edge without heavy CPU paint; still has the
   platform-view compositing problem.

---

## Test Coverage

`test/features/spikes/fog_shader_test.dart` covers the `FogMath` class
(pure Dart, no GPU dependency) with 9 test groups / 15 assertions:

| # | Scenario | Expected |
|---|----------|----------|
| 1 | Fragment at player position | alpha ≈ 0.0 |
| 2 | Fragment well outside radius | alpha ≈ 0.85 |
| 3 | Fragment at reveal radius edge | 0 < alpha < 0.85 |
| 4 | Fragment at inner radius (0.7×) | alpha ≈ 0.0 |
| 5 | fogDensity = 0.0 everywhere | alpha = 0.0 |
| 6 | fogDensity = 0.5 | alpha halved |
| 7 | revealRadius = 0 | everything fogged |
| 8 | Symmetry: equal distances | equal alphas |
| 9 | smoothstep at t=0, 0.25, 0.5, 0.75, 1.0 | cubic Hermite values |

---

## Next Steps

1. **Device test**: Run `FogSpikeScreen` on a real Android + iOS device.
   Verify: fog renders, clear region follows camera movement, no flickering.
2. **Performance baseline**: Measure frame time with shader active during
   continuous pan. Target < 16 ms (60 fps).
3. **Compositing fix** (if needed): Apply one of the fallback mitigations.
4. **Integrate with `CellStateSystem`**: Replace hardcoded position with
   `locationProvider` stream; replace single clear region with per-cell
   opacity grid keyed to `kFogDensityValues`.
