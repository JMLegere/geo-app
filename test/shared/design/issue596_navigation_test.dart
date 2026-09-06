import 'package:earth_nova/shared/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets('Help labels remain readable in compact category navigation at large text', (tester) async {
    await tester.pumpWidget(ShadApp(theme: AppDesignTheme.dark(), home: MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(2)),
      child: Scaffold(body: SizedBox(width: 48, child: AppNavButton(
        label: 'Mineral', icon: const Icon(Icons.diamond_outlined),
        showLabel: true, onPressed: () {},
      ))),
    )));
    expect(find.text('Mineral'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'navigation symbols keep their intended size and accessible names',
    (tester) async {
      await tester.pumpWidget(
        ShadApp(
          theme: AppDesignTheme.dark(),
          home: Scaffold(
            body: SizedBox(
              width: 150,
              child: AppNavButton(
                label: 'Pack',
                icon: const Icon(Icons.backpack),
                selected: true,
                onPressed: () {},
              ),
            ),
          ),
        ),
      );
      expect(find.text('Pack'), findsNothing);
      expect(find.bySemanticsLabel('Pack'), findsOneWidget);
      expect(
        IconTheme.of(tester.element(find.byIcon(Icons.backpack))).size,
        DesignMetrics.navigationIcon,
      );
      expect(
        tester.getSize(find.byType(ShadButton)).height,
        greaterThanOrEqualTo(44),
      );
    },
  );
  testWidgets('title ribbon is centered and roughly half the available width', (
    tester,
  ) async {
    await tester.pumpWidget(
      ShadApp(
        theme: AppDesignTheme.dark(),
        home: const Scaffold(
          body: SizedBox(width: 390, child: AppRibbon(title: 'Pack')),
        ),
      ),
    );
    final ribbon = tester.getSize(find.byKey(const Key('app-ribbon-material')));
    expect(ribbon.width, closeTo(195, 1));
    expect(find.bySemanticsLabel('Pack'), findsOneWidget);
  });
}
