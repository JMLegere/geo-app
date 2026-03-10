import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:earth_nova/core/state/player_provider.dart';
import 'package:earth_nova/features/steps/providers/step_provider.dart';
import 'package:earth_nova/features/steps/services/step_service.dart';

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
    test('computes login delta when lastKnownStepCount > 0', () async {
      // OS reports 5000 steps; last known was 4500 → delta = 500.
      final mock = MockStepService(currentStepCount: 5000);
      final container = makeContainer(mock);

      final delta = await container.read(stepProvider.notifier).hydrate(
            lastKnownStepCount: 4500,
            totalSteps: 100,
          );

      expect(delta, equals(500));
    });

    test('updates stepState.loginDelta after hydration', () async {
      final mock = MockStepService(currentStepCount: 5000);
      final container = makeContainer(mock);

      await container.read(stepProvider.notifier).hydrate(
            lastKnownStepCount: 4500,
            totalSteps: 100,
          );

      final stepState = container.read(stepProvider);
      expect(stepState.loginDelta, equals(500));
    });

    test('sets isAnimating=true when delta > 0', () async {
      final mock = MockStepService(currentStepCount: 5000);
      final container = makeContainer(mock);

      await container.read(stepProvider.notifier).hydrate(
            lastKnownStepCount: 4500,
            totalSteps: 100,
          );

      expect(container.read(stepProvider).isAnimating, isTrue);
    });

    test('adds delta to playerProvider.totalSteps', () async {
      final mock = MockStepService(currentStepCount: 5000);
      final container = makeContainer(mock);

      // Set initial totalSteps via loadProfile.
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

      expect(container.read(playerProvider).totalSteps, equals(600));
    });

    test('delta is 0 when lastKnownStepCount is 0 (first launch)', () async {
      // First launch: no persisted baseline → delta = 0.
      final mock = MockStepService(currentStepCount: 5000);
      final container = makeContainer(mock);

      final delta = await container.read(stepProvider.notifier).hydrate(
            lastKnownStepCount: 0,
            totalSteps: 0,
          );

      expect(delta, equals(0));
      expect(container.read(stepProvider).loginDelta, equals(0));
      expect(container.read(stepProvider).isAnimating, isFalse);
    });

    test('clamps delta to 0 on device reboot (OS counter reset)', () async {
      // OS counter reset to 100 but last known was 5000 → delta clamped to 0.
      final mock = MockStepService(currentStepCount: 100);
      final container = makeContainer(mock);

      final delta = await container.read(stepProvider.notifier).hydrate(
            lastKnownStepCount: 5000,
            totalSteps: 10000,
          );

      expect(delta, equals(0));
      expect(container.read(stepProvider).isAnimating, isFalse);
    });

    test('does not add steps to player when delta is 0', () async {
      final mock = MockStepService(currentStepCount: 4500);
      final container = makeContainer(mock);

      container.read(playerProvider.notifier).loadProfile(
            cellsObserved: 0,
            totalDistanceKm: 0.0,
            currentStreak: 0,
            longestStreak: 0,
            totalSteps: 200,
          );

      await container.read(stepProvider.notifier).hydrate(
            lastKnownStepCount: 4500, // same as OS → delta = 0
            totalSteps: 200,
          );

      // totalSteps unchanged.
      expect(container.read(playerProvider).totalSteps, equals(200));
    });
  });

  group('StepNotifier.startLiveStream()', () {
    test('calls start() on the step service', () async {
      final mock = MockStepService(currentStepCount: 1000);
      final container = makeContainer(mock);

      // Hydrate first to set _lastStreamValue baseline.
      await container.read(stepProvider.notifier).hydrate(
            lastKnownStepCount: 900,
            totalSteps: 0,
          );

      container.read(stepProvider.notifier).startLiveStream();

      expect(mock.startCalled, isTrue);
    });

    test('forwards incremental steps to playerProvider', () async {
      final mock = MockStepService(currentStepCount: 1000);
      final container = makeContainer(mock);

      // Hydrate: baseline = 1000.
      await container.read(stepProvider.notifier).hydrate(
            lastKnownStepCount: 900,
            totalSteps: 0,
          );

      container.read(stepProvider.notifier).startLiveStream();

      // Emit 1050 → increment = 50.
      mock.emitSteps(1050);
      await Future<void>.delayed(Duration.zero);

      // Player should have gained 100 (delta from hydrate) + 50 (live) = 150.
      expect(container.read(playerProvider).totalSteps, equals(150));
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

      // No steps added (delta from hydrate was 0, live increment was 0).
      expect(container.read(playerProvider).totalSteps, equals(0));
    });
  });

  group('StepNotifier.markAnimationComplete()', () {
    test('sets isAnimating=false and hasAnimated=true', () async {
      final mock = MockStepService(currentStepCount: 5000);
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
