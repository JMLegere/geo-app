import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/shared/widgets/loading_dots.dart';

void main() {
  group('LoadingDots', () {
    testWidgets('renders initial dot', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Center(child: LoadingDots()))),
      );

      expect(find.text('.'), findsOneWidget);
    });

    testWidgets('cycles through dot counts', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Center(child: LoadingDots()))),
      );

      expect(find.text('.'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('..'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('...'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('.'), findsOneWidget);
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
