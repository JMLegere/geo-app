import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/shared/debug/debug_gesture_overlay.dart';

class _FakeInjector implements GestureInjectorInterface {
  final List<String> calls = [];
  final List<Offset> centers = [];

  @override
  Future<void> swipeUp(Offset center, double distance) async {
    calls.add('swipeUp');
    centers.add(center);
  }

  @override
  Future<void> swipeDown(Offset center, double distance) async {
    calls.add('swipeDown');
    centers.add(center);
  }

  @override
  Future<void> swipeLeft(Offset center, double distance) async {
    calls.add('swipeLeft');
    centers.add(center);
  }

  @override
  Future<void> swipeRight(Offset center, double distance) async {
    calls.add('swipeRight');
    centers.add(center);
  }

  @override
  Future<void> pinch(Offset center, double distance) async {
    calls.add('pinch');
    centers.add(center);
  }

  @override
  Future<void> spread(Offset center, double distance) async {
    calls.add('spread');
    centers.add(center);
  }
}

Widget _wrap(_FakeInjector injector) {
  return ProviderScope(
    child: MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            DebugGestureOverlay(injector: injector),
          ],
        ),
      ),
    ),
  );
}

void main() {
  group('DebugGestureOverlay', () {
    testWidgets('renders 6 gesture buttons', (tester) async {
      final injector = _FakeInjector();
      await tester.pumpWidget(_wrap(injector));

      // Each gesture button is wrapped in a Tooltip; the toggle handle is not.
      expect(find.byType(Tooltip), findsNWidgets(6));
    });

    testWidgets('tooltip labels match expected text', (tester) async {
      final injector = _FakeInjector();
      await tester.pumpWidget(_wrap(injector));

      expect(find.byTooltip('Pinch'), findsOneWidget);
      expect(find.byTooltip('Spread'), findsOneWidget);
      expect(find.byTooltip('Up'), findsOneWidget);
      expect(find.byTooltip('Down'), findsOneWidget);
      expect(find.byTooltip('Left'), findsOneWidget);
      expect(find.byTooltip('Right'), findsOneWidget);
    });

    testWidgets('tapping Pinch calls injector.pinch', (tester) async {
      final injector = _FakeInjector();
      await tester.pumpWidget(_wrap(injector));
      await tester.tap(find.byTooltip('Pinch'));
      await tester.pump();
      expect(injector.calls, contains('pinch'));
    });

    testWidgets('tapping Spread calls injector.spread', (tester) async {
      final injector = _FakeInjector();
      await tester.pumpWidget(_wrap(injector));
      await tester.tap(find.byTooltip('Spread'));
      await tester.pump();
      expect(injector.calls, contains('spread'));
    });

    testWidgets('tapping Up calls injector.swipeUp', (tester) async {
      final injector = _FakeInjector();
      await tester.pumpWidget(_wrap(injector));
      await tester.tap(find.byTooltip('Up'));
      await tester.pump();
      expect(injector.calls, contains('swipeUp'));
    });

    testWidgets('tapping Down calls injector.swipeDown', (tester) async {
      final injector = _FakeInjector();
      await tester.pumpWidget(_wrap(injector));
      await tester.tap(find.byTooltip('Down'));
      await tester.pump();
      expect(injector.calls, contains('swipeDown'));
    });

    testWidgets('tapping Left calls injector.swipeLeft', (tester) async {
      final injector = _FakeInjector();
      await tester.pumpWidget(_wrap(injector));
      await tester.tap(find.byTooltip('Left'));
      await tester.pump();
      expect(injector.calls, contains('swipeLeft'));
    });

    testWidgets('tapping Right calls injector.swipeRight', (tester) async {
      final injector = _FakeInjector();
      await tester.pumpWidget(_wrap(injector));
      await tester.tap(find.byTooltip('Right'));
      await tester.pump();
      expect(injector.calls, contains('swipeRight'));
    });

    testWidgets('tapping toggle handle collapses gesture buttons',
        (tester) async {
      final injector = _FakeInjector();
      await tester.pumpWidget(_wrap(injector));

      // Starts expanded — Pinch icon is visible.
      expect(find.byIcon(Icons.zoom_out), findsOneWidget);

      // Tap the toggle handle to collapse.
      await tester.tap(find.byKey(const Key('debug_overlay_toggle')));
      await tester.pump();

      // Gesture buttons are no longer in the tree.
      expect(find.byIcon(Icons.zoom_out), findsNothing);
    });

    testWidgets('default injector delegates all 6 gestures without throwing',
        (tester) async {
      // Uses _DefaultInjector (no injector param) — exercises all delegation
      // methods that forward to GestureInjector static calls.
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Stack(children: [const DebugGestureOverlay()]),
            ),
          ),
        ),
      );

      for (final tooltip in [
        'Pinch',
        'Spread',
        'Up',
        'Down',
        'Left',
        'Right',
      ]) {
        await tester.tap(find.byTooltip(tooltip));
        await tester.pump();
      }

      expect(tester.takeException(), isNull);
    });

    testWidgets('does not throw when MediaQuery is absent', (tester) async {
      final injector = _FakeInjector();
      await tester.pumpWidget(
        ProviderScope(
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Overlay(
              initialEntries: [
                OverlayEntry(
                  builder: (_) => Stack(
                    children: [
                      DebugGestureOverlay(injector: injector),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      // Each gesture button is wrapped in a Tooltip; the toggle handle is not.
      expect(find.byType(Tooltip), findsNWidgets(6));
    });

    testWidgets('pinch uses y=80 gesture target, swipeUp uses screen-center y',
        (tester) async {
      final injector = _FakeInjector();
      await tester.pumpWidget(_wrap(injector));

      final size = tester.view.physicalSize / tester.view.devicePixelRatio;

      await tester.tap(find.byTooltip('Pinch'));
      await tester.pump();
      final pinchCenter = injector.centers.last;
      expect(pinchCenter.dy, equals(80.0),
          reason: 'pinch should use y=80 gesture target');
      expect(pinchCenter.dx, equals(size.width / 2),
          reason: 'pinch should use horizontal center');

      await tester.tap(find.byTooltip('Up'));
      await tester.pump();
      final swipeUpCenter = injector.centers.last;
      expect(swipeUpCenter.dy, isNot(equals(80.0)),
          reason: 'swipeUp should use screen-center y, not gesture target y');
    });

    testWidgets('spread uses y=80 gesture target', (tester) async {
      final injector = _FakeInjector();
      await tester.pumpWidget(_wrap(injector));

      final size = tester.view.physicalSize / tester.view.devicePixelRatio;

      await tester.tap(find.byTooltip('Spread'));
      await tester.pump();
      final spreadCenter = injector.centers.last;
      expect(spreadCenter.dy, equals(80.0),
          reason: 'spread should use y=80 gesture target');
      expect(spreadCenter.dx, equals(size.width / 2),
          reason: 'spread should use horizontal center');
    });
  });
}
