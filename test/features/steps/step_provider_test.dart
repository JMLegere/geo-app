import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:earth_nova/core/state/player_provider.dart';
import 'package:earth_nova/features/steps/providers/step_provider.dart';
import 'package:earth_nova/features/steps/services/step_service.dart';
import 'package:earth_nova/shared/constants.dart';

// ---------------------------------------------------------------------------
// Mock StepService
// ---------------------------------------------------------------------------

/// Hand-written mock for [StepService] that returns deterministic values.
///
/// Uses the web stub's interface (no-op start/stop/dispose, empty stream)
/// but overrides [getCurrentStepCount] to return a configurable value.
class MockStepService implements StepService {
  final int currentStepCount;
  final StreamController<int> _controller = StreamController<int>.broadcast();
  bool startCalled = false;
  bool disposeCalled = false;

  MockStepService({this.currentStepCount = 0});

  @override
  Stream<int> get stepCountStream => _controller.stream;

  @override
  Future<int> getCurrentStepCount({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    return currentStepCount;
  }

  @override
  void start() {
    startCalled = true;
  }

  @override
  void stop() {}

  @override
  void dispose() {
    disposeCalled = true;
    _controller.close();
  }

  /// Emit a step count value on the live stream (for testing startLiveStream).
  void emitSteps(int steps) {
    _controller.add(steps);
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

ProviderContainer makeContainer(MockStepService mockService) {
  final container = ProviderContainer(
    overrides: [
      stepServiceProvider.overrideWithValue(mockService),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('StepNotifier.hydrate()', () {
    // ------------------------------------------------------------------
    // Pedometer delta vs minimum floor
    // ------------------------------------------------------------------

    test('uses pedometer delta when it exceeds the daily minimum', () async {
      // OS reports 6500 steps; last known was 4500 → pedometer delta = 2000.
      // Daily minimum = 1000 × 1 day = 1000. Pedometer wins.
      final mock = MockStepService(currentStepCount: 6500);
      final container = makeContainer(mock);

      final delta = await container.read(stepProvider.notifier).hydrate(
            lastKnownStepCount: 4500,
            totalSteps: 100,
          );

      expect(delta, equals(2000));
      expect(container.read(stepProvider).loginDelta, equals(2000));
    });

    test('uses daily minimum when pedometer delta is lower', () async {
      // OS reports 4700; last known 4500 → pedometer delta = 200.
      // Daily minimum = 1000 × 1 day = 1000. Minimum wins.
      final mock = MockStepService(currentStepCount: 4700);
      final container = makeContainer(mock);

      final delta = await container.read(stepProvider.notifier).hydrate(
            lastKnownStepCount: 4500,
            totalSteps: 100,
          );

      expect(delta, equals(kMinDailyStepGrant));
    });

    test('scales minimum by days since last session', () async {
      // No pedometer steps (web stub).
      // Last session 3 days ago → minimum = 1000 × 3 = 3000.
      final mock = MockStepService(currentStepCount: 0);
      final container = makeContainer(mock);

      final threeDaysAgo = DateTime.now().subtract(const Duration(days: 3));
      final delta = await container.read(stepProvider.notifier).hydrate(
            lastKnownStepCount: 0,
            totalSteps: 0,
            lastSessionDate: threeDaysAgo,
          );

      expect(delta, equals(kMinDailyStepGrant * 3));
    });

    test('caps days-since at 30 to prevent runaway grants', () async {
      final mock = MockStepService(currentStepCount: 0);
      final container = makeContainer(mock);

      final longAgo = DateTime.now().subtract(const Duration(days: 100));
      final delta = await container.read(stepProvider.notifier).hydrate(
            lastKnownStepCount: 0,
            totalSteps: 0,
            lastSessionDate: longAgo,
          );

      expect(delta, equals(kMinDailyStepGrant * 30));
    });

    // ------------------------------------------------------------------
    // Player state integration
    // ------------------------------------------------------------------

    test('adds delta to playerProvider.totalSteps', () async {
      // Pedometer delta = 2000, exceeds minimum → delta = 2000.
      final mock = MockStepService(currentStepCount: 6500);
      final container = makeContainer(mock);

      container.read(playerProvider.notifier).loadProfile(
            cellsObserved: 0,
            totalDistanceKm: 0.0,
            currentStreak: 0,
            longestStreak: 0,
            totalSteps: 100,
          );

      await container.read(stepProvider.notifier).hydrate(
            lastKnownStepCount: 4500,
            totalSteps: 100,
          );

      expect(container.read(playerProvider).totalSteps, equals(2100));
    });

    // ------------------------------------------------------------------
    // Animation state
    // ------------------------------------------------------------------

    test('sets isAnimating=true when delta > 0', () async {
      final mock = MockStepService(currentStepCount: 6500);
      final container = makeContainer(mock);

      await container.read(stepProvider.notifier).hydrate(
            lastKnownStepCount: 4500,
            totalSteps: 100,
          );

      expect(container.read(stepProvider).isAnimating, isTrue);
    });

    test('isAnimating is always true since minimum floor is at least 1000',
        () async {
      // Even with 0 pedometer delta, the minimum floor ensures delta > 0.
      final mock = MockStepService(currentStepCount: 0);
      final container = makeContainer(mock);

      await container.read(stepProvider.notifier).hydrate(
            lastKnownStepCount: 0,
            totalSteps: 0,
          );

      expect(container.read(stepProvider).isAnimating, isTrue);
      expect(
          container.read(stepProvider).loginDelta, equals(kMinDailyStepGrant));
    });

    // ------------------------------------------------------------------
    // Edge cases
    // ------------------------------------------------------------------

    test('first launch grants daily minimum (lastKnownStepCount=0)', () async {
      final mock = MockStepService(currentStepCount: 5000);
      final container = makeContainer(mock);

      final delta = await container.read(stepProvider.notifier).hydrate(
            lastKnownStepCount: 0,
            totalSteps: 0,
          );

      // Pedometer delta is 0 (no baseline), minimum floor = 1000.
      expect(delta, equals(kMinDailyStepGrant));
    });

    test('device reboot grants daily minimum (OS counter reset)', () async {
      // OS counter reset to 100 but last known was 5000 → pedometer delta
      // clamped to 0. Daily minimum = 1000 → delta = 1000.
      final mock = MockStepService(currentStepCount: 100);
      final container = makeContainer(mock);

      final delta = await container.read(stepProvider.notifier).hydrate(
            lastKnownStepCount: 5000,
            totalSteps: 10000,
          );

      expect(delta, equals(kMinDailyStepGrant));
    });

    test('stores lastSessionDate in state', () async {
      final mock = MockStepService(currentStepCount: 6500);
      final container = makeContainer(mock);

      final sessionDate = DateTime(2026, 3, 8);
      await container.read(stepProvider.notifier).hydrate(
            lastKnownStepCount: 4500,
            totalSteps: 0,
            lastSessionDate: sessionDate,
          );

      expect(container.read(stepProvider).lastSessionDate, equals(sessionDate));
    });
  });

  group('StepNotifier.startLiveStream()', () {
    test('calls start() on the step service', () async {
      final mock = MockStepService(currentStepCount: 1000);
      final container = makeContainer(mock);

      await container.read(stepProvider.notifier).hydrate(
            lastKnownStepCount: 900,
            totalSteps: 0,
          );

      container.read(stepProvider.notifier).startLiveStream();

      expect(mock.startCalled, isTrue);
    });

    test('forwards incremental steps to playerProvider', () async {
      // Pedometer delta = 100, minimum = 1000 → hydrate adds 1000.
      final mock = MockStepService(currentStepCount: 1000);
      final container = makeContainer(mock);

      await container.read(stepProvider.notifier).hydrate(
            lastKnownStepCount: 900,
            totalSteps: 0,
          );

      container.read(stepProvider.notifier).startLiveStream();

      // Emit 1050 → increment = 50 (from baseline 1000).
      mock.emitSteps(1050);
      await Future<void>.delayed(Duration.zero);

      // 1000 (hydrate) + 50 (live) = 1050.
      expect(container.read(playerProvider).totalSteps, equals(1050));
    });

    test('ignores negative increments (step counter glitch)', () async {
      final mock = MockStepService(currentStepCount: 1000);
      final container = makeContainer(mock);

      await container.read(stepProvider.notifier).hydrate(
            lastKnownStepCount: 0,
            totalSteps: 0,
          );

      container.read(stepProvider.notifier).startLiveStream();

      // Emit a value lower than baseline → increment clamped to 0.
      mock.emitSteps(500);
      await Future<void>.delayed(Duration.zero);

      // Only hydration steps (minimum floor), no live increment.
      expect(container.read(playerProvider).totalSteps,
          equals(kMinDailyStepGrant));
    });
  });

  group('StepNotifier.markAnimationComplete()', () {
    test('sets isAnimating=false and hasAnimated=true', () async {
      final mock = MockStepService(currentStepCount: 6500);
      final container = makeContainer(mock);

      await container.read(stepProvider.notifier).hydrate(
            lastKnownStepCount: 4000,
            totalSteps: 0,
          );

      expect(container.read(stepProvider).isAnimating, isTrue);

      container.read(stepProvider.notifier).markAnimationComplete();

      final state = container.read(stepProvider);
      expect(state.isAnimating, isFalse);
      expect(state.hasAnimated, isTrue);
    });
  });
}
