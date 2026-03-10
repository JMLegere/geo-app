import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/features/sanctuary/widgets/streak_badge.dart';

Future<void> _pump(WidgetTester tester, int streak) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(child: StreakBadge(streak: streak)),
      ),
    ),
  );
}

void main() {
  group('StreakBadge', () {
    testWidgets('shows "Day N" label when streak > 0', (tester) async {
      await _pump(tester, 5);
      expect(find.text('Day 5'), findsOneWidget);
    });

    testWidgets('shows "Day 1" for first day', (tester) async {
      await _pump(tester, 1);
      expect(find.text('Day 1'), findsOneWidget);
    });

    testWidgets('shows "Day 30" for a long streak', (tester) async {
      await _pump(tester, 30);
      expect(find.text('Day 30'), findsOneWidget);
    });

    testWidgets('shows flame icon when streak > 0', (tester) async {
      await _pump(tester, 3);
      expect(find.text('🔥'), findsOneWidget);
    });

    testWidgets('shows "Start your streak!" when streak is 0', (tester) async {
      await _pump(tester, 0);
      expect(find.text('Start your streak!'), findsOneWidget);
    });

    testWidgets('does NOT show flame icon when streak is 0', (tester) async {
      await _pump(tester, 0);
      expect(find.text('🔥'), findsNothing);
    });

    testWidgets('does NOT show "Day N" text when streak is 0', (tester) async {
      await _pump(tester, 0);
      expect(find.text('Day 0'), findsNothing);
    });

    testWidgets('does NOT show start message when streak > 0', (tester) async {
      await _pump(tester, 5);
      expect(find.text('Start your streak!'), findsNothing);
    });
  });
}
