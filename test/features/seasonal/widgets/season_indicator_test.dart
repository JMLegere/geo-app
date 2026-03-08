import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/models/season.dart';
import 'package:earth_nova/features/seasonal/widgets/season_indicator.dart';

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

/// Finds the [BoxDecoration] colour on the outermost [Container] inside
/// [SeasonIndicator].
Color? _indicatorColor(WidgetTester tester) {
  final container = tester.widget<Container>(
    find.descendant(
      of: find.byType(SeasonIndicator),
      matching: find.byType(Container),
    ).first,
  );
  return (container.decoration as BoxDecoration?)?.color;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('SeasonIndicator', () {
    testWidgets('shows "Summer" text in summer', (tester) async {
      await tester.pumpWidget(
        _wrap(const SeasonIndicator(season: Season.summer)),
      );

      expect(find.text('Summer'), findsOneWidget);
    });

    testWidgets('shows "Winter" text in winter', (tester) async {
      await tester.pumpWidget(
        _wrap(const SeasonIndicator(season: Season.winter)),
      );

      expect(find.text('Winter'), findsOneWidget);
    });

    testWidgets('shows ☀️ emoji in summer', (tester) async {
      await tester.pumpWidget(
        _wrap(const SeasonIndicator(season: Season.summer)),
      );

      expect(find.text('☀️'), findsOneWidget);
    });

    testWidgets('shows ❄️ emoji in winter', (tester) async {
      await tester.pumpWidget(
        _wrap(const SeasonIndicator(season: Season.winter)),
      );

      expect(find.text('❄️'), findsOneWidget);
    });

    testWidgets('summer has yellow-ish background (amber-50 #FFF9C4)',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const SeasonIndicator(season: Season.summer)),
      );

      const expectedColor = Color(0xFFFFF9C4);
      expect(
        _indicatorColor(tester),
        equals(expectedColor),
        reason: 'Summer background should be amber-50 (#FFF9C4)',
      );
    });

    testWidgets('winter has blue-ish background (blue-100 #BBDEFB)',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const SeasonIndicator(season: Season.winter)),
      );

      const expectedColor = Color(0xFFBBDEFB);
      expect(
        _indicatorColor(tester),
        equals(expectedColor),
        reason: 'Winter background should be blue-100 (#BBDEFB)',
      );
    });

    testWidgets('summer and winter have different background colours',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const SeasonIndicator(season: Season.summer)),
      );
      final summerColor = _indicatorColor(tester);

      await tester.pumpWidget(
        _wrap(const SeasonIndicator(season: Season.winter)),
      );
      final winterColor = _indicatorColor(tester);

      expect(summerColor, isNotNull);
      expect(winterColor, isNotNull);
      expect(summerColor, isNot(equals(winterColor)));
    });
  });
}
