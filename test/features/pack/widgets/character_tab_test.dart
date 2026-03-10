import 'package:flutter/material.dart' hide Durations;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:earth_nova/core/state/player_provider.dart';
import 'package:earth_nova/features/pack/widgets/character_tab.dart';

void main() {
  group('CharacterTab', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: CharacterTab()),
          ),
        ),
      );
      expect(find.byType(CharacterTab), findsOneWidget);
    });

    testWidgets('shows steps row with zero by default', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: CharacterTab()),
          ),
        ),
      );

      expect(find.text('Steps'), findsOneWidget);
      // Default totalSteps = 0, step icon present.
      expect(find.textContaining('🚶'), findsOneWidget);
    });

    testWidgets('shows step count with comma formatting', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(playerProvider.notifier).addSteps(1500);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: CharacterTab()),
          ),
        ),
      );

      expect(find.text('1,500'), findsOneWidget);
    });

    testWidgets('shows large step count with commas', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(playerProvider.notifier).addSteps(15432);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: CharacterTab()),
          ),
        ),
      );

      expect(find.text('15,432'), findsOneWidget);
    });
  });

  group('CharacterTab._formatSteps', () {
    test('returns raw number below 1000', () {
      expect(CharacterTab.formatSteps(0), '0');
      expect(CharacterTab.formatSteps(42), '42');
      expect(CharacterTab.formatSteps(999), '999');
    });

    test('adds commas for 1000+', () {
      expect(CharacterTab.formatSteps(1000), '1,000');
      expect(CharacterTab.formatSteps(1234), '1,234');
      expect(CharacterTab.formatSteps(10000), '10,000');
      expect(CharacterTab.formatSteps(100000), '100,000');
      expect(CharacterTab.formatSteps(1000000), '1,000,000');
    });
  });
}
