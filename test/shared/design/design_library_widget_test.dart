import 'package:earth_nova/shared/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets('design library catalog is reachable without overflow', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final (:size, :textScaler) in [
      (size: const Size(390, 844), textScaler: TextScaler.noScaling),
      (size: const Size(1440, 900), textScaler: TextScaler.noScaling),
      (size: const Size(390, 844), textScaler: const TextScaler.linear(2)),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: child!,
          ),
          home: Scaffold(
            body: ShadTheme(
              data: ShadThemeData(
                brightness: Brightness.dark,
                colorScheme: const ShadZincColorScheme.dark(),
              ),
              child: const DesignLibraryExample(),
            ),
          ),
        ),
      );

      final continueAction = find.widgetWithText(AppButton, 'Continue');

      expect(tester.takeException(), isNull);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(find.text('Design system'), findsOneWidget);
      expect(find.byType(AppBadge), findsWidgets);
      expect(find.byType(AppNotice), findsWidgets);
      expect(find.byType(AppCard), findsWidgets);
      expect(find.byType(AppFieldRow), findsOneWidget);
      expect(find.byType(AppStatGrid), findsOneWidget);
      expect(find.byType(AppEmptyState), findsOneWidget);
      expect(find.byType(AppErrorState), findsOneWidget);
      expect(find.byType(LoadingDots), findsOneWidget);

      await tester.ensureVisible(continueAction);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(tester.getTopLeft(continueAction).dy, greaterThanOrEqualTo(0));
      expect(
        tester.getBottomRight(continueAction).dy,
        lessThanOrEqualTo(size.height),
      );
    }
  });
}
