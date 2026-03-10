import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:earth_nova/core/state/player_provider.dart';
import 'package:earth_nova/features/map/widgets/status_bar.dart';

void main() {
  group('StatusBar', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: StatusBar()),
          ),
        ),
      );
      expect(find.byType(StatusBar), findsOneWidget);
    });

    testWidgets('shows default zeros when provider state is empty',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MediaQuery(
            data: MediaQueryData(),
            child: MaterialApp(
              home: Scaffold(body: StatusBar()),
            ),
          ),
        ),
      );

      // Default PlayerState: cellsObserved=0, currentStreak=0, totalSteps=0
      expect(find.textContaining('0 cells'), findsOneWidget);
      expect(find.textContaining('0 days'), findsOneWidget);
      expect(find.textContaining('🚶'), findsOneWidget);
    });

    testWidgets('shows updated values when provider state changes',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MediaQuery(
            data: MediaQueryData(),
            child: MaterialApp(
              home: Scaffold(body: StatusBar()),
            ),
          ),
        ),
      );

      // Update player state.
      container.read(playerProvider.notifier)
        ..incrementCellsObserved()
        ..incrementCellsObserved()
        ..incrementStreak()
        ..incrementStreak();

      await tester.pump();

      expect(find.textContaining('2 cells'), findsOneWidget);
      expect(find.textContaining('2 days'), findsOneWidget);
    });

    testWidgets('contains three stat pills', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MediaQuery(
            data: MediaQueryData(),
            child: MaterialApp(
              home: Scaffold(body: StatusBar()),
            ),
          ),
        ),
      );

      // One pill per stat (cells, steps, streak).
      expect(find.byType(Text), findsAtLeastNWidgets(3));
    });

    testWidgets('shows step count with compact formatting', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Add 1500 steps → should display as "1.5k"
      container.read(playerProvider.notifier).addSteps(1500);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MediaQuery(
            data: MediaQueryData(),
            child: MaterialApp(
              home: Scaffold(body: StatusBar()),
            ),
          ),
        ),
      );

      expect(find.textContaining('1.5k'), findsOneWidget);
    });

    testWidgets('shows large step count without decimal', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Add 15000 steps → should display as "15k"
      container.read(playerProvider.notifier).addSteps(15000);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MediaQuery(
            data: MediaQueryData(),
            child: MaterialApp(
              home: Scaffold(body: StatusBar()),
            ),
          ),
        ),
      );

      expect(find.textContaining('15k'), findsOneWidget);
    });
  });

  group('StatusBar._formatSteps', () {
    test('returns raw number below 1000', () {
      expect(StatusBar.formatSteps(0), '0');
      expect(StatusBar.formatSteps(999), '999');
    });

    test('returns one decimal for 1k–9.9k', () {
      expect(StatusBar.formatSteps(1000), '1.0k');
      expect(StatusBar.formatSteps(1234), '1.2k');
      expect(StatusBar.formatSteps(9999), '10.0k');
    });

    test('returns whole number for 10k+', () {
      expect(StatusBar.formatSteps(10000), '10k');
      expect(StatusBar.formatSteps(15432), '15k');
      expect(StatusBar.formatSteps(100000), '100k');
    });
  });
}
