import 'package:earth_nova/features/map/presentation/widgets/map_status_bar.dart';
import 'package:earth_nova/features/map/presentation/screens/map_screen.dart';
import 'package:earth_nova/shared/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets('uses singular labels only for exactly one', (tester) async {
    Future<void> pump({
      required int cells,
      required int steps,
      required int days,
    }) => tester.pumpWidget(
      ShadApp(
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
    expect(find.text('cell'), findsOneWidget);
    expect(find.text('step'), findsOneWidget);
    expect(find.text('day'), findsOneWidget);
    await pump(cells: 2, steps: 0, days: 3);
    expect(find.text('cells'), findsOneWidget);
    expect(find.text('steps'), findsOneWidget);
    expect(find.text('days'), findsOneWidget);
  });

  testWidgets('uses neutral status chrome and announces pending sync', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const ShadApp(
        home: Scaffold(
          body: MapStatusBar(
            cellsObserved: 3,
            totalSteps: 0,
            streakDays: 0,
            pendingVisits: 2,
            paddingTop: 0,
          ),
        ),
      ),
    );

    expect(find.byType(ShadCard), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('syncing'), findsOneWidget);
    expect(find.bySemanticsLabel('2 visits syncing'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('reflows without overflow at 200% text', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ShadApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: MapStatusBar(
              cellsObserved: 247,
              totalSteps: 15200,
              streakDays: 4,
              pendingVisits: 2,
              paddingTop: 0,
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
      tester.getRect(find.byType(ShadCard)).right,
      lessThanOrEqualTo(320 - Spacing.giant - Spacing.lg),
    );
    expect(find.text('247'), findsOneWidget);
    expect(find.text('15.2k'), findsOneWidget);
  });

  testWidgets('places paused status below the HUD without overlap', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ShadApp(
        home: Scaffold(
          body: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MapStatusBar(
                cellsObserved: 3,
                totalSteps: 0,
                streakDays: 0,
                paddingTop: 0,
              ),
              SizedBox(height: 8),
              DiscoveryPausedBanner(),
            ],
          ),
        ),
      ),
    );

    final statusRect = tester.getRect(find.byType(MapStatusBar));
    final pausedRect = tester.getRect(find.byType(DiscoveryPausedBanner));
    expect(statusRect.bottom, lessThanOrEqualTo(pausedRect.top));
  });
}
