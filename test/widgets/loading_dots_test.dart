import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/widgets/loading_dots.dart';

void main() {
  group('LoadingDots', () {
    testWidgets('renders initial dot', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Center(child: LoadingDots()))),
      );

      // Initially shows 1 dot
      expect(find.text('.'), findsOneWidget);
    });

    testWidgets('cycles through dot counts', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Center(child: LoadingDots()))),
      );

      // Start: 1 dot
      expect(find.text('.'), findsOneWidget);

      // Advance animation to 2 dots
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('..'), findsOneWidget);

      // Advance to 3 dots
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('...'), findsOneWidget);

      // Wraps back to 1 dot
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('.'), findsOneWidget);
    });

    testWidgets('disposes without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Center(child: LoadingDots()))),
      );

      // Pump a few frames then remove
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));

      // No errors — animation controller disposed cleanly
    });
  });
}
