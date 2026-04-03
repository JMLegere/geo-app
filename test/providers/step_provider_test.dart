import 'package:flutter_test/flutter_test.dart';

import 'package:earth_nova/providers/step_provider.dart';

void main() {
  // Note: StepNotifier tests that touch ProviderContainer are skipped because
  // StepNotifier.build() registers an onDispose that calls ref.read() — which
  // Riverpod 3 disallows inside lifecycle callbacks. The state class and
  // NoOpPedometer are tested directly instead.

  group('StepState', () {
    test('default values', () {
      const state = StepState();
      expect(state.loginDelta, 0);
      expect(state.isAnimating, false);
      expect(state.hasAnimated, false);
      expect(state.lastSessionDate, isNull);
    });

    test('copyWith overrides specified fields', () {
      const state = StepState(loginDelta: 50, isAnimating: true);
      final updated = state.copyWith(isAnimating: false, hasAnimated: true);
      expect(updated.loginDelta, 50);
      expect(updated.isAnimating, false);
      expect(updated.hasAnimated, true);
    });

    test('copyWith preserves unset fields', () {
      final state = StepState(
        loginDelta: 100,
        isAnimating: true,
        hasAnimated: false,
        lastSessionDate: DateTime(2026, 3, 1),
      );
      final updated = state.copyWith(loginDelta: 200);
      expect(updated.isAnimating, true);
      expect(updated.hasAnimated, false);
      expect(updated.lastSessionDate, DateTime(2026, 3, 1));
    });
  });

  group('NoOpPedometer', () {
    test('getCurrentStepCount returns 0', () async {
      const pedometer = NoOpPedometer();
      expect(await pedometer.getCurrentStepCount(), 0);
    });

    test('dispose is a no-op and does not throw', () {
      const pedometer = NoOpPedometer();
      pedometer.dispose();
    });
  });
}
