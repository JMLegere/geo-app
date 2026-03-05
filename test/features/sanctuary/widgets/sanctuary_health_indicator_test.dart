import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fog_of_world/features/sanctuary/widgets/sanctuary_health_indicator.dart';

Future<void> _pump(WidgetTester tester, double percentage) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SanctuaryHealthIndicator(percentage: percentage),
        ),
      ),
    ),
  );
}

void main() {
  group('SanctuaryHealthIndicator', () {
    testWidgets('shows percentage text for 40%', (tester) async {
      await _pump(tester, 0.4);
      expect(find.text('40%'), findsOneWidget);
    });

    testWidgets('shows percentage text for 0%', (tester) async {
      await _pump(tester, 0.0);
      expect(find.text('0%'), findsOneWidget);
    });

    testWidgets('shows percentage text for 100%', (tester) async {
      await _pump(tester, 1.0);
      expect(find.text('100%'), findsOneWidget);
    });

    testWidgets('shows "growing" message when percentage is below 75%',
        (tester) async {
      await _pump(tester, 0.4);
      expect(find.text('Your sanctuary is growing'), findsOneWidget);
    });

    testWidgets('shows "growing" message at exactly 74%', (tester) async {
      await _pump(tester, 0.74);
      expect(find.text('Your sanctuary is growing'), findsOneWidget);
    });

    testWidgets('shows "thriving" message at exactly 75%', (tester) async {
      await _pump(tester, 0.75);
      expect(find.text('Your sanctuary is thriving'), findsOneWidget);
    });

    testWidgets('shows "thriving" message at 100%', (tester) async {
      await _pump(tester, 1.0);
      expect(find.text('Your sanctuary is thriving'), findsOneWidget);
    });

    testWidgets('clamps above 1.0 to 100%', (tester) async {
      await _pump(tester, 1.5);
      expect(find.text('100%'), findsOneWidget);
    });

    testWidgets('clamps below 0.0 to 0%', (tester) async {
      await _pump(tester, -0.3);
      expect(find.text('0%'), findsOneWidget);
    });

    testWidgets('renders CustomPaint ring', (tester) async {
      await _pump(tester, 0.5);
      // Flutter may render additional CustomPaint widgets internally;
      // assert that at least one CustomPaint (our ring) is present.
      expect(find.byType(CustomPaint), findsWidgets);
    });
  });
}
