import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/shared/debug/gesture_injector.dart';

Widget _testTarget(List<PointerEvent> events) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Listener(
      onPointerDown: events.add,
      onPointerMove: events.add,
      onPointerUp: events.add,
      child: Container(
        width: 400,
        height: 400,
        color: const Color(0xFF000000),
      ),
    ),
  );
}

void main() {
  group('GestureInjector.swipe', () {
    testWidgets('dispatches pointer down, 20 move events, and pointer up',
        (tester) async {
      final events = <PointerEvent>[];
      await tester.pumpWidget(_testTarget(events));

      await GestureInjector.swipe(
        const Offset(50, 200),
        const Offset(350, 200),
        duration: const Duration(milliseconds: 300),
      );
      await tester.pump();

      final downs = events.whereType<PointerDownEvent>().toList();
      final moves = events.whereType<PointerMoveEvent>().toList();
      final ups = events.whereType<PointerUpEvent>().toList();

      expect(downs.length, 1);
      expect(moves.length, 20);
      expect(ups.length, 1);
      expect(downs.first.device, 1);
      expect(moves.first.device, 1);
      expect(ups.first.device, 1);
    });

    testWidgets('swipe starts at start offset and ends at end offset',
        (tester) async {
      final events = <PointerEvent>[];
      await tester.pumpWidget(_testTarget(events));

      const start = Offset(50, 200);
      const end = Offset(350, 200);
      await GestureInjector.swipe(start, end);
      await tester.pump();

      final downs = events.whereType<PointerDownEvent>().toList();
      final ups = events.whereType<PointerUpEvent>().toList();

      expect(downs.first.position, start);
      expect(ups.first.position, end);
    });
  });

  group('GestureInjector.doubleTap', () {
    testWidgets('dispatches two down/up cycles at the same point',
        (tester) async {
      final events = <PointerEvent>[];
      await tester.pumpWidget(_testTarget(events));

      const point = Offset(200, 200);
      await GestureInjector.doubleTap(point);
      await tester.pump();

      final downs = events.whereType<PointerDownEvent>().toList();
      final ups = events.whereType<PointerUpEvent>().toList();

      expect(downs.length, 2);
      expect(ups.length, 2);
      expect(downs[0].position, point);
      expect(downs[1].position, point);
      expect(ups[0].position, point);
      expect(ups[1].position, point);
    });

    testWidgets('uses device id 1 for both taps', (tester) async {
      final events = <PointerEvent>[];
      await tester.pumpWidget(_testTarget(events));

      await GestureInjector.doubleTap(const Offset(200, 200));
      await tester.pump();

      for (final e in events) {
        expect(e.device, 1);
      }
    });
  });

  group('GestureInjector.pinch', () {
    testWidgets('dispatches two pointers moving inward', (tester) async {
      final events = <PointerEvent>[];
      await tester.pumpWidget(_testTarget(events));

      const center = Offset(200, 200);
      const distance = 100.0;
      await GestureInjector.pinch(center, distance);
      await tester.pump();

      final downs = events.whereType<PointerDownEvent>().toList();
      final ups = events.whereType<PointerUpEvent>().toList();

      expect(downs.map((e) => e.device).toSet(), {1, 2});
      expect(ups.map((e) => e.device).toSet(), {1, 2});

      final p1Down = downs.firstWhere((e) => e.device == 1);
      final p2Down = downs.firstWhere((e) => e.device == 2);
      expect(p1Down.position.dx, closeTo(center.dx - distance / 2, 0.01));
      expect(p2Down.position.dx, closeTo(center.dx + distance / 2, 0.01));

      final p1Up = ups.firstWhere((e) => e.device == 1);
      final p2Up = ups.firstWhere((e) => e.device == 2);
      expect(p1Up.position.dx, closeTo(center.dx - distance * 0.3 / 2, 0.01));
      expect(p2Up.position.dx, closeTo(center.dx + distance * 0.3 / 2, 0.01));
    });
  });

  group('GestureInjector.spread', () {
    testWidgets('dispatches two pointers moving outward', (tester) async {
      final events = <PointerEvent>[];
      await tester.pumpWidget(_testTarget(events));

      const center = Offset(200, 200);
      const distance = 100.0;
      await GestureInjector.spread(center, distance);
      await tester.pump();

      final downs = events.whereType<PointerDownEvent>().toList();
      final ups = events.whereType<PointerUpEvent>().toList();

      expect(downs.map((e) => e.device).toSet(), {1, 2});
      expect(ups.map((e) => e.device).toSet(), {1, 2});

      final p1Down = downs.firstWhere((e) => e.device == 1);
      final p2Down = downs.firstWhere((e) => e.device == 2);
      expect(p1Down.position.dx, closeTo(center.dx - distance * 0.3 / 2, 0.01));
      expect(p2Down.position.dx, closeTo(center.dx + distance * 0.3 / 2, 0.01));

      final p1Up = ups.firstWhere((e) => e.device == 1);
      final p2Up = ups.firstWhere((e) => e.device == 2);
      expect(p1Up.position.dx, closeTo(center.dx - distance / 2, 0.01));
      expect(p2Up.position.dx, closeTo(center.dx + distance / 2, 0.01));
    });
  });
}
