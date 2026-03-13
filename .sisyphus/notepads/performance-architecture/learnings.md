# Learnings — Performance Architecture Plan

## Task 1: Eliminate Startup OnboardingScreen Flash (2026-03-13)

### Root Cause
Triple navigation rebuild: auth resolves (~100ms) before profile hydration (~1000ms). During the gap, `hasCompletedOnboarding` is `false` (default), causing a brief OnboardingScreen flash for returning users.

### Solution
Added `isHydrated` flag to `PlayerState` — gates `_resolveHome()` routing until profile hydration completes. `LoadingScreen` shown while unhydrated.

### Key Learnings

1. **PlayerState identity**: No `==`/`hashCode` override — Riverpod compares by reference. Every `copyWith()` triggers listeners. This is intentional for the current codebase but means any state mutation fires all watchers.

2. **loadProfile() creates new instances**: Uses constructor (not `copyWith`), so `isHydrated` naturally resets to `false`. This makes sign-out → re-login work correctly without explicit reset logic.

3. **New user edge case**: For brand new users with no profile/cell progress, `loadProfile()` is never called by `game_coordinator_provider.dart`. The `markHydrated()` call must be placed after the hydration if/else block to handle both paths.

4. **Dart switch guard clauses**: `switch` expressions support `when` guards — `AuthStatus.authenticated when !playerState.isHydrated => LoadingScreen(...)`. Clean pattern for multi-condition routing.

5. **AnimatedSwitcher key stability**: Using the same `ValueKey('loading')` for the pre-hydration LoadingScreen and the auth-loading LoadingScreen prevents unnecessary transition animations during the hydration window.

6. **Idempotent state mutations**: `markHydrated()` guards with `if (!state.isHydrated)` to avoid redundant state changes and listener notifications. Important pattern for any flag that should only transition once per lifecycle.

---

## Task 2: RubberBand Ticker Pause Mechanism (2026-03-13)

### Goal
Pause the RubberBand ticker (60fps interpolation) when the player is stationary to save CPU/battery. Prevent restart for GPS jitter (<10m) but restart for genuine movement (>10m).

### Implementation

**3 key changes:**

1. **Added `kTickerRestartThresholdMeters = 10.0`** to `constants.dart` — GPS jitter hysteresis threshold. Prevents stop/start flapping from small GPS noise.

2. **Added `_tickerPaused` flag** to `RubberBandController`:
   - Set to `true` when display reaches target (within snap threshold)
   - Checked in `setTarget()` to decide: restart ticker (genuine movement) or stay paused (jitter)
   - Checked at start of `_onTick()` to prevent callbacks when paused

3. **Three-case logic in `setTarget()`**:
   - **Initialization**: First call snaps display to target, starts ticker
   - **Paused state**: Check distance from display to new target
     - If >= 10m: genuine movement → restart ticker
     - If < 10m: GPS jitter → stay paused, update target silently
   - **Running state**: Just update target, interpolation continues

### Key Learnings

1. **Pause happens at snap threshold, not immediately**: The ticker pauses only when the display reaches the target (within 0.5m snap threshold). This prevents premature pausing during normal interpolation.

2. **GPS jitter hysteresis prevents flapping**: A 10m threshold is large enough to filter out typical GPS noise (±5m accuracy) but small enough to catch real movement. Without this, a stationary player with drifting GPS would constantly restart/pause the ticker.

3. **Early return in `_onTick()` is critical**: When paused, `_onTick()` must return immediately (`if (!_initialized || _tickerPaused) return;`). Otherwise, even though `_ticker.stop()` was called, test harnesses (or any code calling `vsync.tick()` directly) will still fire the callback.

4. **Distance calculation matters**: Haversine distance between two lat/lon points is non-trivial. A 0.0001° difference in latitude is ~11m, not 0.5m. Test coordinates must be chosen carefully to hit the intended threshold (< 10m for jitter, > 10m for movement).

5. **Test pattern for pause mechanism**:
   - Set initial target, then move target by ~11m (genuine movement)
   - Simulate frames until convergence (ticker pauses automatically)
   - Verify `isTickerPaused == true`
   - Call `setTarget()` with small distance (~5m) — ticker should stay paused
   - Call `setTarget()` with large distance (>10m) — ticker should restart
   - Verify no callbacks emitted while paused

### Performance Impact

- **Stationary player**: Ticker stops, 0 CPU/battery drain from interpolation
- **Moving player**: Ticker runs at 60fps as before
- **GPS jitter**: No ticker restart/stop churn — smooth experience

### Files Changed

- `lib/shared/constants.dart` — Added `kTickerRestartThresholdMeters`
- `lib/features/map/controllers/rubber_band_controller.dart` — Pause/restart logic
- `test/features/map/controllers/rubber_band_controller_test.dart` — 3 new tests (all passing)


---

## Task 3: Cap Startup Species Enrichment Requeue (2026-03-13)

### Goal
Cap startup enrichment to 10 species (highest priority first) and defer the rest to a lazy background drain (5 species every 30 seconds). Previously `_requeueUnenrichedSpecies()` fired enrichment requests for ALL unenriched species (109+ at ~4.2s/req = ~230s of continuous Edge Function calls).

### Implementation

**3 new constants in `constants.dart`:**
- `kStartupEnrichmentCap = 10` — max species queued at startup
- `kDeferredEnrichmentBatchSize = 5` — species per deferred drain tick
- `kDeferredEnrichmentIntervalSeconds = 30` — seconds between drain ticks

**Key structural insight — `gameCoordinatorProvider` is a closure, not a Notifier:**
The provider is `Provider<GameCoordinator>((ref) { ... })`. Local state (like `enrichmentCache`, `lastPersistedProfile`) lives as closure variables, not class fields. The deferred queue and timer follow the same pattern:
```dart
final deferredEnrichmentQueue = <({String definitionId, FaunaDefinition fauna, bool force})>[];
Timer? deferredDrainTimer;
```

**Extracted `partitionEnrichmentCandidates()` as a public top-level function:**
The original `_requeueUnenrichedSpecies` was a private top-level function — untestable without a full ProviderContainer. Extracting the partition logic as a public function (no `_` prefix) enables direct unit testing without Riverpod setup.

**Timer drain pattern:**
```dart
Timer.periodic(Duration(seconds: kDeferredEnrichmentIntervalSeconds), (_) {
  final batchSize = deferredQueue.length.clamp(0, kDeferredEnrichmentBatchSize);
  if (batchSize == 0) return;
  final batch = deferredQueue.sublist(0, batchSize);
  deferredQueue.removeRange(0, batchSize);
  for (final item in batch) { /* enrich */ }
});
```

**Sign-out cleanup is critical:**
On sign-out (`handleAuthState` unauthenticated branch), cancel timer AND clear queue. Without this, stale species from the previous session leak into the next login's enrichment queue.

### Key Learnings

1. **Extract pure functions for testability**: When logic lives inside a provider closure, extract it as a public top-level function. This avoids the overhead of spinning up a full ProviderContainer just to test a partition algorithm.

2. **`onTimerCreated` callback pattern**: Pass a `void Function(Timer)` callback into the requeue function so the caller (closure) can capture the timer reference for later cancellation. Avoids returning a tuple or using a mutable wrapper.

3. **`EnrichmentService` with null client is a no-op**: When `supabaseClient == null`, `EnrichmentService.enrich()` returns immediately. This makes it impossible to observe queued calls in unit tests — hence the pure function extraction strategy.

4. **Deferred queue is in-memory only**: No Drift persistence. If the app is killed mid-drain, unenriched species are re-discovered on next startup via the same `_requeueUnenrichedSpecies` call. No data loss — just re-queued.

5. **`clamp(0, batchSize)` prevents underflow**: When the queue has fewer items than `kDeferredEnrichmentBatchSize`, `clamp` ensures we don't try to `removeRange` past the end of the list.

6. **Timer cancellation in two places**: `ref.onDispose` (provider teardown) AND sign-out handler. Missing either causes a timer leak — the periodic callback fires against a disposed provider or a signed-out session.

### Files Changed

- `lib/shared/constants.dart` — Added 3 constants
- `lib/core/state/game_coordinator_provider.dart` — Closure vars, rewritten `_requeueUnenrichedSpecies`, new `partitionEnrichmentCandidates`, sign-out cleanup, dispose cleanup
- `test/core/state/enrichment_requeue_test.dart` — 16 new tests (all passing)
