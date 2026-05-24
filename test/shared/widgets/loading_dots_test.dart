import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/shared/widgets/loading_dots.dart';

void main() {
  group('LoadingDots', () {
    testWidgets('renders a text-free progress spinner', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Center(child: LoadingDots()))),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.public), findsNothing);
      expect(find.text('🌍'), findsNothing);
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
