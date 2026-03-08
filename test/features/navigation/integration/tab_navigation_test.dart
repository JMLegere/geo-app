import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/features/navigation/providers/tab_index_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Test harness
//
// TabShell cannot be pumped directly in widget tests because MapScreen depends
// on MapLibre (native FFI). Instead we build a structurally identical harness
// that replaces the real tab children with SizedBox.shrink() placeholders.
//
// This exercises the same tabIndexProvider wiring and BottomNavigationBar
// interaction as the production TabShell without touching platform channels.
// ---------------------------------------------------------------------------

class _TestTabShell extends ConsumerWidget {
  const _TestTabShell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(tabIndexProvider);

    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: const [
          SizedBox.shrink(), // Map (0)
          SizedBox.shrink(), // Home (1)
          SizedBox.shrink(), // Town (2)
          SizedBox.shrink(), // Pack (3)
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) => ref.read(tabIndexProvider.notifier).setTab(index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Map'),
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Town'),
          BottomNavigationBarItem(icon: Icon(Icons.backpack), label: 'Pack'),
        ],
      ),
    );
  }
}

Future<ProviderContainer> _pumpShell(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final container = ProviderContainer();
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: _TestTabShell()),
    ),
  );
  return container;
}

// ---------------------------------------------------------------------------
// Integration tests
//
// These tests verify that the widget layer, tabIndexProvider, and
// SharedPreferences all behave correctly as an integrated system.
// Each test exercises more than one layer simultaneously.
// ---------------------------------------------------------------------------

void main() {
  group('Tab navigation integration', () {
    testWidgets('TabShell renders BottomNavigationBar with 4 labelled items',
        (tester) async {
      await _pumpShell(tester);

      // All 4 labels visible in the nav bar.
      expect(find.text('Map'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Town'), findsOneWidget);
      expect(find.text('Pack'), findsOneWidget);

      // BottomNavigationBar exists with exactly 4 items.
      final navBar =
          tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar));
      expect(navBar.items.length, 4);
    });

    testWidgets('default tab is Map (index 0)', (tester) async {
      final container = await _pumpShell(tester);

      // Provider state starts at 0.
      expect(container.read(tabIndexProvider), 0);

      // BottomNavigationBar reflects index 0.
      final navBar =
          tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar));
      expect(navBar.currentIndex, 0);
    });

    testWidgets('tapping each tab updates selection in provider and nav bar',
        (tester) async {
      final container = await _pumpShell(tester);

      // Tap Home → index 1.
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(container.read(tabIndexProvider), 1);
      expect(
        tester
            .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
            .currentIndex,
        1,
      );

      // Tap Town → index 2.
      await tester.tap(find.text('Town'));
      await tester.pumpAndSettle();
      expect(container.read(tabIndexProvider), 2);

      // Tap Pack → index 3.
      await tester.tap(find.text('Pack'));
      await tester.pumpAndSettle();
      expect(container.read(tabIndexProvider), 3);

      // Tap Map → index 0.
      await tester.tap(find.text('Map'));
      await tester.pumpAndSettle();
      expect(container.read(tabIndexProvider), 0);
      expect(
        tester
            .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
            .currentIndex,
        0,
      );
    });

    testWidgets('tab switch persists to SharedPreferences', (tester) async {
      await _pumpShell(tester);

      // Tap Pack (index 3).
      await tester.tap(find.text('Pack'));
      await tester.pumpAndSettle();

      // Verify persisted in SharedPreferences.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('selected_tab_index'), 3);

      // Tap Home (index 1) — verify prefs update.
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      final prefs2 = await SharedPreferences.getInstance();
      expect(prefs2.getInt('selected_tab_index'), 1);
    });

    test('persisted tab index is restored on new provider container', () async {
      // Seed SharedPreferences with a previously saved tab (Town = 2).
      SharedPreferences.setMockInitialValues({'selected_tab_index': 2});

      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Trigger notifier build (starts async _loadState).
      container.read(tabIndexProvider);

      // One microtask iteration allows SharedPreferences.getInstance()
      // to complete and the state update to propagate.
      await Future<void>.delayed(Duration.zero);

      expect(container.read(tabIndexProvider), 2);
    });
  });
}
