# Player Marker Fix - Learnings

## Session: Player Marker Invisible on Initial Load Fix

**Date**: 2026-03-05

### Problem
Player marker was invisible on initial load on Flutter web. The CSS opacity transition hides the MapLibre container during fog initialization, then reveals it. However, the WidgetLayer (which contains the player marker) wasn't recalculating its screen position when the container transitioned from hidden to visible.

### Solution
Added `WidgetsBinding.instance.addPostFrameCallback()` after `revealMapContainer()` in `_initFogAndReveal()` method. This forces the marker position ValueNotifier to toggle (null → value), which triggers `ValueListenableBuilder` to rebuild and forces MapLibre to recalculate the marker's screen position in the now-visible container.

### Key Implementation Details
1. **Location**: `lib/features/map/map_screen.dart`, lines 608-619 in `_initFogAndReveal()` method
2. **Timing**: Post-frame callback ensures DOM has processed the CSS opacity change before forcing repaint
3. **Safety**: Includes `if (!mounted) return` guard to prevent issues if widget is disposed before callback fires
4. **Mechanism**: Toggles `_markerPosition.value` from current position → null → current position, forcing rebuild

### Testing
- All 1002 tests pass (no regressions)
- Flutter analyze: 0 new issues (29 pre-existing issues unrelated to this change)
- Change is minimal and focused on the specific issue

### Why This Works
- The rubber-band controller updates marker position at 60fps, so the value is definitely non-null by reveal time
- CSS transitions need at least one animation frame to start
- `addPostFrameCallback` guarantees the DOM has processed the opacity change
- Toggling the ValueNotifier forces the WidgetLayer to recalculate screen coordinates
