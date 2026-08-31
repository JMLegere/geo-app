import 'dart:ui' show SemanticsAction;

import 'package:earth_nova/shared/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

Widget _host(Widget child, {double width = 800}) => MaterialApp(
  home: Scaffold(
    body: ShadTheme(
      data: ShadThemeData(
        brightness: Brightness.dark,
        colorScheme: const ShadZincColorScheme.dark(),
      ),
      child: SizedBox(
        width: width,
        child: SingleChildScrollView(child: child),
      ),
    ),
  ),
);

void main() {
  testWidgets('canonical primitives and composites render', (tester) async {
    await tester.pumpWidget(
      _host(
        Column(
          children: [
            for (final variant in AppButtonVariant.values)
              AppButton(
                label: variant.name,
                onPressed: () {},
                variant: variant,
              ),
            for (final variant in AppBadgeVariant.values)
              AppBadge(label: variant.name, variant: variant),
            for (final tone in AppNoticeTone.values)
              AppNotice(title: tone.name, message: 'message', tone: tone),
            const AppCard(child: Text('card')),
            const AppFieldRow(label: 'Label', value: 'Value', helper: 'Helper'),
          ],
        ),
      ),
    );

    expect(
      find.byType(ShadButton),
      findsNWidgets(AppButtonVariant.values.length),
    );
    expect(
      find.byType(ShadBadge),
      findsNWidgets(AppBadgeVariant.values.length),
    );
    expect(find.byType(ShadAlert), findsNWidgets(AppNoticeTone.values.length));
    expect(find.byType(ShadCard), findsWidgets);
    expect(find.text('Label'), findsOneWidget);
  });

  testWidgets('button has a 44px action target and loading is disabled', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(
        Column(
          children: [
            AppButton(label: 'Save', onPressed: () => taps += 1),
            AppButton(
              label: 'Submit',
              onPressed: () => taps += 1,
              isLoading: true,
            ),
          ],
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(ShadButton).first).height,
      greaterThanOrEqualTo(44),
    );
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('Save'))
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isTrue,
    );
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('Submit loading'))
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isFalse,
    );
    expect(find.text('Loading'), findsOneWidget);
    expect(find.bySemanticsLabel('Submit loading'), findsOneWidget);
    expect(find.bySemanticsLabel('Loading'), findsNothing);
    await tester.tap(find.text('Loading'), warnIfMissed: false);
    expect(taps, 0);
  });

  testWidgets('button supports keyboard focus and activation', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(AppButton(label: 'Continue', onPressed: () => taps += 1)),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(taps, 1);
  });

  testWidgets('stat grid handles duplicate labels across responsive columns', (
    tester,
  ) async {
    const grid = AppStatGrid(
      items: [
        AppStatItem(label: 'Repeated', value: '1'),
        AppStatItem(label: 'Repeated', value: '2'),
      ],
    );
    await tester.pumpWidget(_host(grid, width: 390));
    final narrowFirst = tester.getTopLeft(
      find.byKey(const ValueKey('app-stat-0')),
    );
    final narrowSecond = tester.getTopLeft(
      find.byKey(const ValueKey('app-stat-1')),
    );
    expect(narrowSecond.dy, greaterThan(narrowFirst.dy));

    await tester.pumpWidget(_host(grid, width: 800));
    final wideFirst = tester.getTopLeft(
      find.byKey(const ValueKey('app-stat-0')),
    );
    final wideSecond = tester.getTopLeft(
      find.byKey(const ValueKey('app-stat-1')),
    );
    expect(wideSecond.dy, wideFirst.dy);
  });

  testWidgets(
    'stat grid remains finite under unbounded horizontal constraints',
    (tester) async {
      await tester.pumpWidget(
        _host(
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppStatGrid(
                items: [AppStatItem(label: 'One', value: '1')],
              ),
            ],
          ),
        ),
      );

      expect(
        tester.getSize(find.byKey(const ValueKey('app-stat-0'))).width,
        320,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('patterns render optional action and retry', (tester) async {
    await tester.pumpWidget(
      _host(
        Column(
          children: [
            AppEmptyState(
              title: 'Nothing here',
              message: 'Try another view.',
              actionLabel: 'Browse',
              onAction: () {},
            ),
            AppErrorState(
              title: 'Unable to load',
              message: 'Check your connection.',
              onRetry: () {},
            ),
          ],
        ),
      ),
    );

    expect(find.text('Browse'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(
      find.bySemanticsLabel('error: Unable to load. Check your connection.'),
      findsOneWidget,
    );
  });
}
