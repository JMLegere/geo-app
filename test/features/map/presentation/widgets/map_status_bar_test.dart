import 'package:earth_nova/features/map/presentation/widgets/map_status_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('uses singular labels only for exactly one', (tester) async {
    Future<void> pump({
      required int cells,
      required int steps,
      required int days,
    }) =>
        tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MapStatusBar(
                cellsObserved: cells,
                totalSteps: steps,
                streakDays: days,
                paddingTop: 0,
              ),
            ),
          ),
        );

    await pump(cells: 1, steps: 1, days: 1);
    expect(find.text('CELL'), findsOneWidget);
    expect(find.text('STEP'), findsOneWidget);
    expect(find.text('DAY'), findsOneWidget);
    await pump(cells: 2, steps: 0, days: 3);
    expect(find.text('CELLS'), findsOneWidget);
    expect(find.text('STEPS'), findsOneWidget);
    expect(find.text('DAYS'), findsOneWidget);
  });
}
