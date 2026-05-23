import 'package:earth_nova/shared/design.dart';
import 'package:earth_nova/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('design library example renders without route-specific styling',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const Scaffold(
          body: SingleChildScrollView(
            child: DesignLibraryExample(),
          ),
        ),
      ),
    );

    expect(find.text('Design system'), findsOneWidget);
    expect(find.text('CANONICAL'), findsWidgets);
    expect(find.text('MAP CELL DETAIL'), findsOneWidget);
  });

  testWidgets('primary design action preserves a usable touch target',
      (tester) async {
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: Center(
            child: EarthActionButton(
              label: 'Continue',
              onPressed: () => taps += 1,
            ),
          ),
        ),
      ),
    );

    final size = tester.getSize(find.byType(ElevatedButton));
    expect(size.height, greaterThanOrEqualTo(44));

    await tester.tap(find.text('Continue'));
    expect(taps, 1);
  });
}
