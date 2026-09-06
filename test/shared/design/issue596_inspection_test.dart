import 'package:earth_nova/shared/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets(
    'inspection keeps close and actions fixed while content scrolls',
    (tester) async {
      tester.view.physicalSize = const Size(390, 520);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      var closed = false;
      await tester.pumpWidget(
        ShadApp(
          theme: AppDesignTheme.dark(),
          home: Scaffold(
            body: AppInspectionPanel(
              semanticLabel: 'Item inspection',
              title: const AppText(
                'An exceptionally long complete Item name',
                role: AppTextRole.itemName,
              ),
              onClose: () => closed = true,
              footer: const SizedBox(
                key: Key('inspection-actions'),
                height: 44,
              ),
              child: Column(
                children: List.generate(
                  20,
                  (index) => SizedBox(height: 44, child: Text('Row $index')),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('inspection-scroll-view')), findsOneWidget);
      expect(find.byKey(const Key('inspection-actions')), findsOneWidget);
      expect(find.byTooltip('Close item inspection'), findsOneWidget);

      await tester.drag(
        find.byKey(const Key('inspection-scroll-view')),
        const Offset(0, -300),
      );
      await tester.pump();

      expect(find.byKey(const Key('inspection-actions')), findsOneWidget);
      await tester.tap(find.byTooltip('Close item inspection'));
      expect(closed, isTrue);
    },
  );

  testWidgets('inspection close target is at least 44 logical pixels', (
    tester,
  ) async {
    await tester.pumpWidget(
      ShadApp(
        theme: AppDesignTheme.dark(),
        home: Scaffold(
          body: AppInspectionPanel(
            semanticLabel: 'Item inspection',
            title: const Text('Item'),
            onClose: () {},
            child: const Text('Details'),
          ),
        ),
      ),
    );

    final size = tester.getSize(find.byKey(const Key('inspection-close')));
    expect(size.width, greaterThanOrEqualTo(DesignMetrics.touchTarget));
    expect(size.height, greaterThanOrEqualTo(DesignMetrics.touchTarget));
  });
}
