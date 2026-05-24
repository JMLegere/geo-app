import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/shared/widgets/loading_dots.dart';

void main() {
  group('LoadingDots', () {
    testWidgets('renders canonical world icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Center(child: LoadingDots()))),
      );

      expect(find.byIcon(Icons.public), findsOneWidget);
      expect(find.text('🌍'), findsNothing);
    });

    testWidgets('wraps the world icon in a rotation transition',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Center(child: LoadingDots()))),
      );

      expect(
        find.descendant(
          of: find.byType(LoadingDots),
          matching: find.byType(RotationTransition),
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.public), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1200));
      expect(find.byIcon(Icons.public), findsOneWidget);
      expect(find.text('...'), findsNothing);
    });

    testWidgets('disposes without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Center(child: LoadingDots()))),
      );

      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    });
  });
}
