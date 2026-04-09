import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/shared/debug/debug_gesture_overlay.dart';

class _FakeInjector implements GestureInjectorInterface {
  final List<String> calls = [];

  @override
  Future<void> swipeUp(Offset center, double distance) async =>
      calls.add('swipeUp');

  @override
  Future<void> swipeDown(Offset center, double distance) async =>
      calls.add('swipeDown');

  @override
  Future<void> swipeLeft(Offset center, double distance) async =>
      calls.add('swipeLeft');

  @override
  Future<void> swipeRight(Offset center, double distance) async =>
      calls.add('swipeRight');

  @override
  Future<void> pinch(Offset center, double distance) async =>
      calls.add('pinch');

  @override
  Future<void> spread(Offset center, double distance) async =>
      calls.add('spread');

  @override
  Future<void> doubleTap(Offset center) async => calls.add('doubleTap');
}

Widget _wrap(_FakeInjector injector) {
  return MaterialApp(
    home: Scaffold(
      body: Stack(
        children: [
          DebugGestureOverlay(injector: injector),
        ],
      ),
    ),
  );
}

void main() {
  group('DebugGestureOverlay', () {
    testWidgets('renders 7 buttons', (tester) async {
      final injector = _FakeInjector();
      await tester.pumpWidget(_wrap(injector));

      expect(find.byType(IconButton), findsNWidgets(7));
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
      expect(find.byTooltip('DblTap'), findsOneWidget);
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

    testWidgets('tapping DblTap calls injector.doubleTap', (tester) async {
      final injector = _FakeInjector();
      await tester.pumpWidget(_wrap(injector));

      await tester.tap(find.byTooltip('DblTap'));
      await tester.pump();

      expect(injector.calls, contains('doubleTap'));
    });

    testWidgets('does not throw when MediaQuery is absent', (tester) async {
      final injector = _FakeInjector();
      await tester.pumpWidget(
        Directionality(
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
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(IconButton), findsNWidgets(7));
    });
  });
}
