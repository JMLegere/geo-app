import 'package:flutter/material.dart' hide StepState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:earth_nova/features/steps/providers/step_provider.dart';
import 'package:earth_nova/features/steps/widgets/step_recap.dart';

// ---------------------------------------------------------------------------
// Test-only notifier
// ---------------------------------------------------------------------------

/// Minimal [StepNotifier] override that returns a pre-configured initial
/// state without performing any I/O (no StepService, no live stream).
///
/// Overrides [build] to skip `stepServiceProvider`, so widget tests don't
/// require a real or mocked `StepService`. [markAnimationComplete] is
/// inherited from [StepNotifier] and only mutates `state` — safe to call.
class _TestStepNotifier extends StepNotifier {
  final StepState _initial;

  _TestStepNotifier(this._initial);

  /// Returns the pre-configured state. Does NOT call super.build() so that
  /// [stepServiceProvider] is never read and `_stepService` is never set.
  /// The inherited [markAnimationComplete] only touches `state`, so this is
  /// safe.
  @override
  StepState build() => _initial;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _buildTestWidget({required StepState initialState}) {
  return ProviderScope(
    overrides: [
      stepProvider.overrideWith(() => _TestStepNotifier(initialState)),
    ],
    child: const MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [StepRecap()],
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('StepRecap', () {
    // ── Scenario 1: animation plays ──────────────────────────────────────

    testWidgets(
      'shows card when isAnimating=true and loginDelta > 0',
      (tester) async {
        await tester.pumpWidget(_buildTestWidget(
          initialState: const StepState(loginDelta: 500, isAnimating: true),
        ));
        // pumpWidget runs one frame; postFrameCallback fires → entry starts.
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('Step Recap'), findsOneWidget);
        expect(find.text('steps'), findsOneWidget);
      },
    );

    testWidgets(
      'count-up starts at 0 at animation start',
      (tester) async {
        await tester.pumpWidget(_buildTestWidget(
          initialState: const StepState(loginDelta: 300, isAnimating: true),
        ));
        // No time advance — count is at the begin value.
        await tester.pump();

        expect(find.text('+0'), findsOneWidget);
      },
    );

    testWidgets(
      'count-up reaches loginDelta by end of animation',
      (tester) async {
        await tester.pumpWidget(_buildTestWidget(
          initialState: const StepState(loginDelta: 300, isAnimating: true),
        ));

        // Advance past both animations (350 ms entry + 1500 ms count-up).
        // onEnd fires → markAnimationComplete() → hasAnimated=true.
        await tester.pump(const Duration(milliseconds: 1850));

        // The animation completed — hasAnimated confirms the full count-up ran.
        final container =
            ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
        expect(container.read(stepProvider).hasAnimated, isTrue);
      },
    );

    // ── Scenario 2: no animation when flag is false ───────────────────────

    testWidgets(
      'does not show when isAnimating=false',
      (tester) async {
        await tester.pumpWidget(_buildTestWidget(
          initialState: const StepState(loginDelta: 500, isAnimating: false),
        ));
        await tester.pump();

        expect(find.text('Step Recap'), findsNothing);
        expect(find.text('+500'), findsNothing);
      },
    );

    testWidgets(
      'does not show when loginDelta is 0 even if isAnimating=true',
      (tester) async {
        await tester.pumpWidget(_buildTestWidget(
          initialState: const StepState(loginDelta: 0, isAnimating: true),
        ));
        await tester.pump();

        expect(find.text('Step Recap'), findsNothing);
      },
    );

    // ── markAnimationComplete called after animation ends ─────────────────

    testWidgets(
      'calls markAnimationComplete after count-up animation ends',
      (tester) async {
        await tester.pumpWidget(_buildTestWidget(
          initialState: const StepState(loginDelta: 100, isAnimating: true),
        ));
        await tester.pump(); // Initial frame.

        // Confirm animation is in progress.
        final container =
            ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
        expect(container.read(stepProvider).isAnimating, isTrue);

        // Advance past both animations: 350 ms entry + 1500 ms count-up.
        // The TweenAnimationBuilder starts after the entry animation completes,
        // so onEnd fires at ~1850 ms total.
        await tester.pump(const Duration(milliseconds: 1850));

        // markAnimationComplete() should have set isAnimating=false and
        // hasAnimated=true.
        expect(container.read(stepProvider).isAnimating, isFalse);
        expect(container.read(stepProvider).hasAnimated, isTrue);
      },
    );

    testWidgets(
      'widget disappears after markAnimationComplete is called',
      (tester) async {
        await tester.pumpWidget(_buildTestWidget(
          initialState: const StepState(loginDelta: 200, isAnimating: true),
        ));
        await tester.pump();

        // Card is visible during the animation.
        expect(find.text('Step Recap'), findsOneWidget);

        // Advance past both animations: 350 ms entry + 1500 ms count-up.
        await tester.pump(const Duration(milliseconds: 1850));
        // One extra frame for the rebuild after state change.
        await tester.pump();

        // Widget should now be SizedBox.shrink() — card is gone.
        expect(find.text('Step Recap'), findsNothing);
      },
    );

    // ── markAnimationComplete NOT called when no animation ────────────────

    testWidgets(
      'does not call markAnimationComplete when isAnimating=false',
      (tester) async {
        await tester.pumpWidget(_buildTestWidget(
          initialState: const StepState(loginDelta: 500, isAnimating: false),
        ));
        await tester.pump(const Duration(milliseconds: 2000));

        // State should be unchanged — isAnimating stays false, hasAnimated
        // stays false (never set by this notifier).
        final container =
            ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
        expect(container.read(stepProvider).isAnimating, isFalse);
        expect(container.read(stepProvider).hasAnimated, isFalse);
      },
    );

    // ── Subtitle date formatting ──────────────────────────────────────────

    testWidgets('shows "earned while away" when lastSessionDate is null',
        (tester) async {
      await tester.pumpWidget(_buildTestWidget(
        initialState: const StepState(loginDelta: 100, isAnimating: true),
      ));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('earned while away'), findsOneWidget);
    });

    testWidgets('shows "since yesterday" when session was yesterday',
        (tester) async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      await tester.pumpWidget(_buildTestWidget(
        initialState: StepState(
          loginDelta: 100,
          isAnimating: true,
          lastSessionDate: yesterday,
        ),
      ));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('since yesterday'), findsOneWidget);
    });

    testWidgets('shows formatted date for older sessions', (tester) async {
      // A date 5 days ago, same year.
      final fiveDaysAgo = DateTime.now().subtract(const Duration(days: 5));
      await tester.pumpWidget(_buildTestWidget(
        initialState: StepState(
          loginDelta: 100,
          isAnimating: true,
          lastSessionDate: fiveDaysAgo,
        ),
      ));
      await tester.pump(const Duration(milliseconds: 200));

      // Should show "since <date>" with month abbreviation.
      expect(find.textContaining('since'), findsOneWidget);
      // Should NOT show "yesterday" or "while away".
      expect(find.text('since yesterday'), findsNothing);
      expect(find.text('earned while away'), findsNothing);
    });
  });
}
