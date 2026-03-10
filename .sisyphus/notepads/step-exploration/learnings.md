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
