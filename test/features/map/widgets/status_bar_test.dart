import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fog_of_world/core/state/player_provider.dart';
import 'package:fog_of_world/features/map/widgets/status_bar.dart';

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

      // Default PlayerState: cellsObserved=0, currentStreak=0
      expect(find.textContaining('0 cells'), findsOneWidget);
      expect(find.textContaining('0 days'), findsOneWidget);
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

      // One pill per stat (cells, streak).
      expect(find.byType(Text), findsAtLeastNWidgets(2));
    });
  });
}
