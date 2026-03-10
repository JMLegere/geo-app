# Step-Based Exploration — Wave 1 Learnings

## Task 2: PlayerNotifier.spendSteps() — COMPLETE ✓

**Implementation Pattern**:
- Guard clause: `if (amount <= 0 || amount > state.totalSteps) return false;`
- Immutable update: `state = state.copyWith(totalSteps: state.totalSteps - amount);`
- Return bool: true on success, false on failure (no exceptions)

**Test Coverage** (6 tests, all passing):
1. Sufficient balance (1000 → spend 500 → 500) ✓
2. Insufficient balance (499 → spend 500 → 499, no mutation) ✓
3. Exact balance (500 → spend 500 → 0) ✓
4. Zero spend (1000 → spend 0 → 1000, returns false) ✓
5. Negative spend (1000 → spend -100 → 1000, returns false) ✓
6. Field isolation (other fields unchanged) ✓

**Key Insight**: The method is the inverse of `addSteps()` but with validation. The guard clause must check BOTH conditions (amount <= 0 AND amount > balance) to prevent overdraft and reject invalid inputs. This is a simple, focused method that enables the exploration flow.

**Files Modified**:
- `lib/core/state/player_provider.dart` — added spendSteps() method (lines 89-102)
- `test/core/state/player_provider_test.dart` — added 6 tests in group('spendSteps', ...)

**Test Results**: 46/46 tests pass (17 existing + 6 new spendSteps tests + 23 other state tests)


## Task 1: FogStateResolver.visitCellRemotely (2026-03-10)

### Successful Pattern: Extract + Delegate
- Extracted `_markCellVisited(String cellId, FogState newState)` private helper
- Both `onLocationUpdate` and `visitCellRemotely` delegate to it
- `onLocationUpdate` passes `FogState.observed`; `visitCellRemotely` passes `FogState.hidden`
- Helper handles: add to visitedCellIds, remove from frontier, expand frontier with neighbors, emit event

### No-op ordering matters
- Check `_visitedCellIds.contains(cellId)` BEFORE frontier check
- Visited cells are never in frontier, so if frontier check ran first it would throw instead of no-op

### Stream is sync: true
- Events emitted synchronously in `_markCellVisited` — `collectEvents()` pattern works without async

### MockCellService: integer parsing
- `getCellsInRing` uses `int.parse(parts[1])` — only works with integer cell IDs
- `getCellCenter` uses `double.parse(parts[1])` — supports decimal IDs for distance tests
- For new tests, use integer coords only (e.g., `cell_1_0`) when calling methods that parse IDs

### _everDetectedCellIds: lazy via resolve()
- `_markCellVisited` does NOT explicitly add to `_everDetectedCellIds`
- `resolve()` adds lazily when the cell is resolved
- This matches the original `onLocationUpdate` behaviour — safe to keep consistent

## T5: Step persistence wiring (2026-03-10)

### What was already done (from T3)
- `LocalPlayerProfileTable` already had `totalSteps` and `lastKnownStepCount` columns (schema v10)
- `ProfileRepository.create()` already accepted both params and passed them to `LocalPlayerProfile`
- `PlayerNotifier.loadProfile()` already had `totalSteps` and `lastKnownStepCount` optional params

### What T5 added
1. **`ProfileRepository.update()`** — added `int? totalSteps` and `int? lastKnownStepCount` optional params; included in `copyWith()` using `?? existing.field` pattern (preserves existing value when not specified)

2. **`_persistProfileState()` SQLite write** — added `totalSteps: playerState.totalSteps` and `lastKnownStepCount: playerState.lastKnownStepCount` to both `profileRepo.update()` and `profileRepo.create()` calls

3. **`_persistProfileState()` Supabase payload** — added `'total_steps': playerState.totalSteps` and `'last_known_step_count': playerState.lastKnownStepCount` to the `jsonEncode` map (always included, not conditional)

4. **`rehydrateData()` profile hydration** — added `totalSteps: profile.totalSteps` and `lastKnownStepCount: profile.lastKnownStepCount` to the `loadProfile()` call in the `if (profile != null)` branch

### Key pattern: update() preserves fields not specified
The `update()` method uses `?? existing.field` for all optional params. This means:
- Calling `update(userId: id, currentStreak: 3)` leaves `totalSteps` and `lastKnownStepCount` unchanged
- This is the correct pattern — partial updates don't clobber unrelated fields

### Tests added (3 new tests in profile_repository_test.dart)
- "step fields round-trip through SQLite" — full create/read/update/read cycle
- "step fields default to zero when not provided" — default value verification
- "update preserves step fields when not specified" — partial update safety

### Test result: 58/58 passed


## Task 7: Map Tap Handler + Cell Selection State (2026-03-10)

### Implementation Pattern: MapEventClick Guard

```dart
void _onMapEvent(MapEvent event) {
  if (event is MapEventClick) {
    final lat = event.point.lat.toDouble();  // num → double cast required
    final lon = event.point.lng.toDouble();  // num → double cast required
    final cellService = ref.read(cellServiceProvider);
    final cellId = cellService.getCellId(lat, lon);
    _onCellTapped(cellId);
  }
  // All other events (camera move, rotate, zoom) fall through silently
}
```

### Critical Gotchas

1. **`event.point.lat/lng` return `num`, not `double`** — must call `.toDouble()` before passing to `getCellId(double lat, double lon)`. LSP catches this immediately.

2. **MapLibre Position is (lng, lat) — longitude first** — but `event.point.lat` and `event.point.lng` are named properties, so accessing them by name is safe. The gotcha is only when constructing `Position(lng, lat)` directly.

3. **`MapLogger` has no generic `log()` method** — use `debugPrint('[TAG] message')` for ad-hoc logging in new methods. Only add named methods to MapLogger for high-frequency events.

4. **Non-click events must be ignored** — the rubber-band fires camera moves at 60fps. Without the `is MapEventClick` guard, every frame would trigger `getCellId`.

### Provider Design: CellSelectionNotifier

- `NotifierProvider<CellSelectionNotifier, String?>` — nullable String, null = no selection
- `select(cellId)` — sets selection
- `clear()` — resets to null (for bottom sheet dismiss in T8)
- File: `lib/features/map/providers/cell_selection_provider.dart`

### Test Strategy: Logic Isolation

The `_onMapEvent` method is a widget method — not directly unit-testable without a full widget harness. Instead, test the logic components in isolation:
- `CellSelectionNotifier` — pure provider tests with `ProviderContainer`
- Tap resolution logic — `MockCellService.getCellId(lat, lon)` called directly, asserting correct arg order and return value
- Integration: tap → getCellId → select() → provider state

### Files Modified
- `lib/features/map/map_screen.dart` — `_onMapEvent()` + `_onCellTapped()` + import
- `lib/features/map/providers/cell_selection_provider.dart` — new file
- `test/features/map/providers/cell_selection_provider_test.dart` — 14 new tests

### Test Results: 174/174 pass (14 new + 160 existing)

## T6: StepNotifier Hydration + Live Stream Wiring (2026-03-10)

### StepService Injection Pattern
- `StepService` was constructed directly in `StepNotifier.build()` — not injectable
- Added `stepServiceProvider = Provider<StepService>((ref) => StepService())` to `step_provider.dart`
- `StepNotifier.build()` now reads `ref.read(stepServiceProvider)` instead of `StepService()`
- Tests override via `stepServiceProvider.overrideWithValue(MockStepService(...))`

### Hydration Wiring in game_coordinator_provider.dart
- Step hydration added as step 4 in `rehydrateData()`, AFTER `lastPersistedProfile` capture
- Reads `profile?.lastKnownStepCount ?? 0` and `ref.read(playerProvider).totalSteps`
- Wrapped in `if (!kIsWeb)` guard + try/catch (non-blocking on failure)
- `startLiveStream()` added in `hydrateAndStart()` `.whenComplete()` callback, after `startLoop()`
- Both calls guarded by `if (!kIsWeb)`

### Login Delta Computation
- Formula: `delta = (currentOsSteps - lastKnownStepCount).clamp(0, currentOsSteps)`
- Clamp handles device reboot (OS counter resets to 0 or small value)
- `lastKnownStepCount == 0` → delta = 0 (first launch, no baseline)
- Delta > 0 → `playerProvider.notifier.addSteps(delta)` + `isAnimating = true`

### MockStepService Pattern
- Implements `StepService` interface (not extends — avoids pedometer_2 dependency in tests)
- `currentStepCount` constructor param for deterministic `getCurrentStepCount()`
- `StreamController<int>.broadcast()` for `stepCountStream`
- `emitSteps(int)` helper to push values on live stream in tests
- `startCalled` flag to verify `start()` was invoked

### Test Coverage (11 tests, all passing)
- hydrate: delta computed, loginDelta set, isAnimating set, totalSteps updated
- hydrate: delta=0 on first launch (lastKnown=0)
- hydrate: delta clamped to 0 on device reboot
- hydrate: no steps added when delta=0
- startLiveStream: start() called, incremental steps forwarded, negative increments ignored
- markAnimationComplete: isAnimating=false, hasAnimated=true
