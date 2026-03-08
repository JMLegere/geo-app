import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/features/navigation/providers/tab_index_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Test harness
//
// TabShell cannot be pumped directly in widget tests because MapScreen depends
// on MapLibre (native FFI). Instead, we build a structurally identical harness
// that replaces the real tab children with SizedBox.shrink() placeholders.
// This lets us verify the BottomNavigationBar layout and tap behaviour using
// the same tabIndexProvider that TabShell uses in production.
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
          BottomNavigationBarItem(
            icon: Icon(Icons.explore),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Town',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.backpack),
            label: 'Pack',
          ),
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
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('TabShell navigation bar', () {
    testWidgets('renders 4 BottomNavigationBarItems', (tester) async {
      await _pumpShell(tester);

      final navBar =
          tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar));
      expect(navBar.items.length, 4);
    });

    testWidgets('renders Map, Home, Town, Pack labels', (tester) async {
      await _pumpShell(tester);

      expect(find.text('Map'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Town'), findsOneWidget);
      expect(find.text('Pack'), findsOneWidget);
    });

    testWidgets('renders correct icons for all 4 tabs', (tester) async {
      await _pumpShell(tester);

      expect(find.byIcon(Icons.explore), findsOneWidget);
      expect(find.byIcon(Icons.home), findsOneWidget);
      expect(find.byIcon(Icons.people), findsOneWidget);
      expect(find.byIcon(Icons.backpack), findsOneWidget);
    });

    testWidgets('initial selected tab is 0 (Map)', (tester) async {
      final container = await _pumpShell(tester);

      expect(container.read(tabIndexProvider), 0);
    });

    testWidgets('tapping Home tab updates tab index to 1', (tester) async {
      final container = await _pumpShell(tester);

      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();

      expect(container.read(tabIndexProvider), 1);
    });

    testWidgets('tapping Town tab updates tab index to 2', (tester) async {
      final container = await _pumpShell(tester);

      await tester.tap(find.text('Town'));
      await tester.pumpAndSettle();

      expect(container.read(tabIndexProvider), 2);
    });

    testWidgets('tapping Pack tab updates tab index to 3', (tester) async {
      final container = await _pumpShell(tester);

      await tester.tap(find.text('Pack'));
      await tester.pumpAndSettle();

      expect(container.read(tabIndexProvider), 3);
    });

    testWidgets('tapping back to Map tab resets index to 0', (tester) async {
      final container = await _pumpShell(tester);

      await tester.tap(find.text('Pack'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Map'));
      await tester.pumpAndSettle();

      expect(container.read(tabIndexProvider), 0);
    });

    testWidgets('BottomNavigationBar reflects provider state changes',
        (tester) async {
      final container = await _pumpShell(tester);

      // Mutate via notifier — bar should repaint
      await container.read(tabIndexProvider.notifier).setTab(3);
      await tester.pump();

      final navBar =
          tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar));
      expect(navBar.currentIndex, 3);
    });
  });
}
