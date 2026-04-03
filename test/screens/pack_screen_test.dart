import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/screens/pack_screen.dart';

void main() {
  group('PackScreen', () {
    testWidgets('shows empty state when no items', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: PackScreen())),
      );
      expect(find.textContaining('No discoveries'), findsOneWidget);
    });

    testWidgets('shows Pack title', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: PackScreen())),
      );
      expect(find.textContaining('Pack'), findsOneWidget);
    });

    testWidgets('shows filter row with All chip', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: PackScreen())),
      );
      expect(find.text('All'), findsOneWidget);
    });
  });
}
