import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fog_of_world/features/journal/widgets/journal_progress_bar.dart';

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

Future<void> _pumpBar(
  WidgetTester tester, {
  required int collected,
  required int total,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: JournalProgressBar(
          collected: collected,
          total: total,
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('JournalProgressBar', () {
    testWidgets('renders without error', (tester) async {
      await _pumpBar(tester, collected: 0, total: 30);
      expect(find.byType(JournalProgressBar), findsOneWidget);
    });

    testWidgets('shows "0 / 30 collected" when nothing collected',
        (tester) async {
      await _pumpBar(tester, collected: 0, total: 30);
      expect(find.text('0 / 30 collected'), findsOneWidget);
    });

    testWidgets('shows correct count when some collected', (tester) async {
      await _pumpBar(tester, collected: 12, total: 30);
      expect(find.text('12 / 30 collected'), findsOneWidget);
    });

    testWidgets('shows correct count when all collected', (tester) async {
      await _pumpBar(tester, collected: 30, total: 30);
      expect(find.text('30 / 30 collected'), findsOneWidget);
    });

    testWidgets('renders a LinearProgressIndicator', (tester) async {
      await _pumpBar(tester, collected: 5, total: 10);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('progress indicator value is 0.0 when nothing collected',
        (tester) async {
      await _pumpBar(tester, collected: 0, total: 30);

      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, equals(0.0));
    });

    testWidgets('progress indicator value is 1.0 when all collected',
        (tester) async {
      await _pumpBar(tester, collected: 10, total: 10);

      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, equals(1.0));
    });

    testWidgets('progress indicator value matches fraction', (tester) async {
      await _pumpBar(tester, collected: 15, total: 30);

      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, closeTo(0.5, 0.001));
    });

    testWidgets('progress indicator is 0.0 when total is 0', (tester) async {
      await _pumpBar(tester, collected: 0, total: 0);

      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, equals(0.0));
    });

    testWidgets('shows percentage label', (tester) async {
      await _pumpBar(tester, collected: 15, total: 30);
      // 50% should be shown
      expect(find.text('50%'), findsOneWidget);
    });

    testWidgets('shows 0% label when nothing collected', (tester) async {
      await _pumpBar(tester, collected: 0, total: 30);
      expect(find.text('0%'), findsOneWidget);
    });

    testWidgets('shows 100% label when all collected', (tester) async {
      await _pumpBar(tester, collected: 5, total: 5);
      expect(find.text('100%'), findsOneWidget);
    });
  });
}
