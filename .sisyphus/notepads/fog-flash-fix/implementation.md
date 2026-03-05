
## [2026-03-05] Task 1 — Fog loading cover + _onStyleLoaded restructure

### Changes made
1. **Added `_fogReady` field** (line 118, after `_fogLayersInitialized`): `bool _fogReady = false;`
2. **Replaced `_onStyleLoaded()`** — removed `addPostFrameCallback` wrapper, removed `markReady()` call, delegates to `_initFogAndReveal()`
3. **Added `_initFogAndReveal()` async method** — explicit async flow: `_initFogLayers` → `updateAsync` (no `onBatchReady`) → `_updateFogSources` → `markReady()` → `setState(_fogReady = true)`
4. **Added cover widget** as last Stack child: `IgnorePointer` > `AnimatedOpacity` (300ms) > `Container(color: Color(0xFF161620))`

### Decisions
- `onBatchReady` callback removed from `updateAsync` call — was causing double-fire of `_updateFogSources()` (once via callback mid-batch, once after `updateAsync` completes)
- `markReady()` deliberately moved to AFTER fog sources are set — prevents `_processGameLogic()` from firing fog updates before layers exist
- No `addPostFrameCallback` — fog init runs directly in `_onStyleLoaded()` flow

### Gotchas
- `fog_overlay_controller.dart` `updateAsync` signature confirmed: `onBatchReady` is `void Function()? onBatchReady` (optional, line 132) — safe to omit
- Pre-existing `info` diagnostic in file (line 50, comment_references) — not introduced by these changes, not a blocker
- `AnimatedOpacity` and `IgnorePointer` are in `flutter/material.dart` — no new imports needed

### Verification
- `flutter analyze lib/features/map/map_screen.dart` → 1 pre-existing info, 0 errors, 0 warnings
- All acceptance criteria confirmed via grep
