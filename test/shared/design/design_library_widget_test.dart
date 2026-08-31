import 'package:earth_nova/shared/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets('design library example renders the canonical foundation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShadTheme(
            data: ShadThemeData(
              brightness: Brightness.dark,
              colorScheme: const ShadZincColorScheme.dark(),
            ),
            child: const SingleChildScrollView(child: DesignLibraryExample()),
          ),
        ),
      ),
    );

    expect(find.text('Design system'), findsOneWidget);
    expect(find.byType(AppButton), findsWidgets);
    expect(find.byType(AppBadge), findsWidgets);
    expect(find.byType(AppNotice), findsWidgets);
    expect(find.byType(AppCard), findsWidgets);
    expect(find.byType(AppFieldRow), findsOneWidget);
    expect(find.byType(AppStatGrid), findsOneWidget);
    expect(find.byType(AppEmptyState), findsOneWidget);
    expect(find.byType(AppErrorState), findsOneWidget);
    expect(find.byType(LoadingDots), findsOneWidget);
  });
}
