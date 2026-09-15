import 'package:earth_nova/ui/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

Widget host(Widget child, {double scale = 1}) => ShadApp(
  theme: AppDesignTheme.dark(),
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
    child: Scaffold(
      body: Center(
        child: SizedBox(width: 350, child: SingleChildScrollView(child: child)),
      ),
    ),
  ),
);

void main() {
  testWidgets(
    'unavailable action explains without submitting by touch or keyboard',
    (tester) async {
      var submissions = 0;
      await tester.pumpWidget(
        host(
          AppButton(
            label: 'Identify',
            onPressed: () => submissions++,
            unavailableReason: 'Visit a known Villager first',
          ),
        ),
      );
      await tester.tap(find.text('Identify'));
      await tester.pump();
      expect(find.text('Visit a known Villager first'), findsOneWidget);
      expect(submissions, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(submissions, 0);
    },
  );
  testWidgets(
    'busy action retains size and label without duplicate submissions',
    (tester) async {
      var submissions = 0;
      await tester.pumpWidget(
        host(
          AppButton(
            label: 'Identify this Item',
            onPressed: () => submissions++,
          ),
        ),
      );
      final before = tester.getSize(find.byType(ShadButton));
      await tester.pumpWidget(
        host(
          AppButton(
            label: 'Identify this Item',
            onPressed: () => submissions++,
            isLoading: true,
          ),
        ),
      );
      expect(tester.getSize(find.byType(ShadButton)), before);
      expect(find.text('Identify this Item'), findsOneWidget);
      await tester.tap(find.byType(ShadButton), warnIfMissed: false);
      expect(submissions, 0);
    },
  );
  testWidgets(
    'press immediately depresses and cancellation restores without command',
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        host(AppButton(label: 'Continue', onPressed: () => taps++)),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Continue')),
      );
      await tester.pump();
      final pressed = tester.widget<AnimatedContainer>(
        find.byKey(const Key('app-button-depth')),
      );
      expect(pressed.transform!.getTranslation().y, DesignMetrics.bevel);
      await gesture.cancel();
      await tester.pump();
      final released = tester.widget<AnimatedContainer>(
        find.byKey(const Key('app-button-depth')),
      );
      expect(released.transform!.getTranslation().y, 0);
      expect(taps, 0);
    },
  );
  testWidgets(
    'complete Item name shrinks without wrapping or losing semantics',
    (tester) async {
      const name = 'A very long naturally distinguishing complete Item name';
      await tester.pumpWidget(
        host(const AppText(name, role: AppTextRole.itemName)),
      );
      expect(find.bySemanticsLabel(name), findsOneWidget);
      expect(find.byType(FittedBox), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('progress retains completed fraction and an accessible result', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(const AppProgress(current: 4, requirement: 4, label: 'Requirement')),
    );
    expect(find.text('4 / 4'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Requirement: 4 of 4, complete'),
      findsOneWidget,
    );
  });
  testWidgets('three stat columns wrap rows at phone width', (tester) async {
    await tester.pumpWidget(
      host(
        AppStatGrid(
          inspection: true,
          items: [
            for (var i = 0; i < 4; i++)
              AppStatItem(
                label: 'Size $i',
                value: '$i',
                icon: const Icon(Icons.straighten),
              ),
          ],
        ),
      ),
    );
    final first = tester.getTopLeft(find.byKey(const ValueKey('app-stat-0')));
    final third = tester.getTopLeft(find.byKey(const ValueKey('app-stat-2')));
    final fourth = tester.getTopLeft(find.byKey(const ValueKey('app-stat-3')));
    final bar = tester.getRect(find.byKey(const ValueKey('app-stat-value-0')));
    final icon = tester.getRect(find.byIcon(Icons.straighten).first);
    expect(icon.left, lessThan(bar.left));
    expect(icon.right, greaterThan(bar.left));
    expect(
      tester.getBottomLeft(find.text('Size 0')).dy,
      lessThanOrEqualTo(bar.top),
    );
    expect(third.dy, first.dy);
    expect(fourth.dy, greaterThan(first.dy));
    expect(tester.takeException(), isNull);
  });
  testWidgets('cost remains inside each equal-width action and reward below', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        AppActionRow(
          actions: [
            AppButton(
              label: 'Identify',
              onPressed: () {},
              cost: const AppResourceAmount(
                amount: '400',
                label: 'Resource',
                icon: Icon(Icons.hexagon),
              ),
              reward: const AppResourceAmount(
                amount: '+80',
                label: 'XP',
                icon: Icon(Icons.star),
              ),
            ),
            AppButton(
              label: 'Details',
              onPressed: () {},
              variant: AppButtonVariant.secondary,
            ),
          ],
        ),
        scale: 2,
      ),
    );
    expect(
      tester.getSize(find.byType(ShadButton).first).width,
      tester.getSize(find.byType(ShadButton).last).width,
    );
    expect(
      tester.getTopLeft(find.text('+80')).dy,
      greaterThan(tester.getBottomLeft(find.byType(ShadButton).first).dy),
    );
    expect(tester.takeException(), isNull);
  });
}
