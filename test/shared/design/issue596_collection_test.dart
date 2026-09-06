import 'package:earth_nova/shared/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets(
    'collection exposes a visible scroll position and reaches its last Item',
    (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        ShadApp(
          theme: AppDesignTheme.dark(),
          home: Scaffold(
            body: SizedBox(
              width: 390,
              height: 300,
              child: AppCollectionGrid(
                controller: controller,
                itemCount: 80,
                itemBuilder: (_, index) => Text('Item $index'),
              ),
            ),
          ),
        ),
      );
      expect(
        tester.widget<Scrollbar>(find.byType(Scrollbar)).thumbVisibility,
        isTrue,
      );
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();
      expect(find.text('Item 79'), findsOneWidget);
    },
  );

  testWidgets(
    'collection keeps five columns and large text without overflowing',
    (tester) async {
      for (final scale in [1.0, 2.0]) {
        await tester.pumpWidget(
          ShadApp(
            theme: AppDesignTheme.dark(),
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: SizedBox(
                  width: 390,
                  height: 600,
                  child: AppCollectionGrid(
                    itemCount: 10,
                    itemBuilder: (_, index) => AppItemCard(
                      artwork: const Icon(Icons.pets),
                      unknown: index == 0,
                      property: index == 0
                          ? null
                          : const AppCardProperty(
                              label: 'Class',
                              value: 'Mammals',
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final grid = tester.widget<GridView>(find.byType(GridView));
        final delegate =
            grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
        expect(delegate.crossAxisCount, 5);
        expect(find.text('Unknown'), findsOneWidget);
        expect(find.text('Mammals'), findsWidgets);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('Unknown card cannot render supplied properties', (tester) async {
    await tester.pumpWidget(
      ShadApp(
        theme: AppDesignTheme.dark(),
        home: Scaffold(
          body: SizedBox(
            width: 80,
            height: 150,
            child: AppItemCard(
              artwork: const Icon(Icons.help_outline),
              unknown: true,
              property: const AppCardProperty(label: 'Secret', value: 'Hidden'),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Hidden'), findsNothing);
    expect(find.text('Unknown'), findsOneWidget);
  });
}
