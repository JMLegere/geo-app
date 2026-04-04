import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/models/item.dart';
import 'package:earth_nova/providers/items_provider.dart';
import 'package:earth_nova/screens/pack_screen.dart';

void main() {
  group('PackScreen', () {
    testWidgets('shows filtered count in title, not total count',
        (tester) async {
      // 4 fauna + 2 flora = 6 total; title should show 4 (fauna default).
      final items = [
        _item('1', 'Red Fox', ItemCategory.fauna, rarity: 'leastConcern'),
        _item('2', 'Blue Whale', ItemCategory.fauna, rarity: 'endangered'),
        _item('3', 'Oak Tree', ItemCategory.flora, rarity: 'leastConcern'),
        _item('4', 'Pine Tree', ItemCategory.flora, rarity: 'leastConcern'),
        _item('5', 'Gray Wolf', ItemCategory.fauna, rarity: 'vulnerable'),
        _item('6', 'Brown Bear', ItemCategory.fauna, rarity: 'leastConcern'),
      ];

      await _pumpPack(tester, items);

      expect(find.text('Pack · 4'), findsOneWidget);
      expect(find.text('Pack · 6'), findsNothing);
    });

    testWidgets('shows pack count of zero when no items match category',
        (tester) async {
      // Only flora items — default fauna category yields 0 matches.
      final items = [
        _item('1', 'Oak Tree', ItemCategory.flora, rarity: 'leastConcern'),
      ];

      await _pumpPack(tester, items);

      expect(find.text('Pack · 0'), findsOneWidget);
    });

    testWidgets('tapping category chip updates title count', (tester) async {
      final items = [
        _item('1', 'Red Fox', ItemCategory.fauna, rarity: 'leastConcern'),
        _item('2', 'Oak Tree', ItemCategory.flora, rarity: 'leastConcern'),
        _item('3', 'Pine Tree', ItemCategory.flora, rarity: 'leastConcern'),
      ];

      await _pumpPack(tester, items);

      // Initial: fauna → 1 item.
      expect(find.text('Pack · 1'), findsOneWidget);

      // Tap the "Flora" category chip label.
      await tester.tap(find.text('Flora'));
      await tester.pumpAndSettle();

      // Now flora → 2 items.
      expect(find.text('Pack · 2'), findsOneWidget);
      expect(find.text('Pack · 1'), findsNothing);
    });

    testWidgets('shows empty state when user has no items at all',
        (tester) async {
      await _pumpPack(tester, []);

      expect(find.text('Pack'), findsOneWidget);
      expect(find.textContaining('Pack ·'), findsNothing);
    });

    testWidgets('compact bar shows sort mode and species count',
        (tester) async {
      final items = [
        _item('1', 'Red Fox', ItemCategory.fauna),
        _item('2', 'Gray Wolf', ItemCategory.fauna),
        _item('3', 'Oak Tree', ItemCategory.flora),
      ];

      await _pumpPack(tester, items);

      // Compact bar should show "Recent" label.
      expect(find.text('Recent'), findsOneWidget);
      // Title should show filtered count.
      expect(find.text('Pack · 2'), findsOneWidget);
    });

    testWidgets('tapping compact bar expands filter panel', (tester) async {
      final items = [
        _item('1', 'Red Fox', ItemCategory.fauna, taxonomicClass: 'MAMMALIA'),
      ];

      await _pumpPack(tester, items);

      // Panel labels should NOT be visible before expand.
      expect(find.text('SORT'), findsNothing);
      expect(find.text('TYPE'), findsNothing);

      // Tap the compact bar area (find by "Recent" label).
      await tester.tap(find.text('Recent'));
      await tester.pumpAndSettle();

      // Panel labels should now be visible.
      expect(find.text('SORT'), findsOneWidget);
      expect(find.text('TYPE'), findsOneWidget);
      expect(find.text('HABITAT'), findsOneWidget);
      expect(find.text('REGION'), findsOneWidget);
    });

    testWidgets('non-fauna category only shows SORT row in panel',
        (tester) async {
      final items = [
        _item('1', 'Diamond', ItemCategory.mineral),
      ];

      await _pumpPack(tester, items);

      // Switch to mineral.
      await tester.tap(find.text('Mineral'));
      await tester.pumpAndSettle();

      // Expand panel.
      await tester.tap(find.text('Recent'));
      await tester.pumpAndSettle();

      // Only SORT row — no TYPE/HABITAT/REGION for minerals.
      expect(find.text('SORT'), findsOneWidget);
      expect(find.text('TYPE'), findsNothing);
      expect(find.text('HABITAT'), findsNothing);
      expect(find.text('REGION'), findsNothing);
    });

    testWidgets('filter-driven empty state shows correct message',
        (tester) async {
      final items = [
        _item('1', 'Red Fox', ItemCategory.fauna,
            taxonomicClass: 'MAMMALIA', habitats: ['Forest']),
      ];

      await _pumpPack(tester, items);

      // All items visible initially.
      expect(find.text('Pack · 1'), findsOneWidget);

      // Expand panel.
      await tester.tap(find.text('Recent'));
      await tester.pumpAndSettle();

      // Find the birds toggle by key.
      await tester.tap(find.byKey(const ValueKey('filter-type-birds')));
      await tester.pumpAndSettle();

      // No mammals match birds filter → 0.
      expect(find.text('Pack · 0'), findsOneWidget);
      expect(find.text('No discoveries match your filters'), findsOneWidget);
    });
    testWidgets('toggling filter off restores all items', (tester) async {
      final items = [
        _item('1', 'Red Fox', ItemCategory.fauna, taxonomicClass: 'MAMMALIA'),
        _item('2', 'Eagle', ItemCategory.fauna, taxonomicClass: 'AVES'),
      ];

      await _pumpPack(tester, items);
      expect(find.text('Pack · 2'), findsOneWidget);

      // Expand, filter to mammals by key.
      await tester.tap(find.text('Recent'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('filter-type-mammals')));
      await tester.pumpAndSettle();
      expect(find.text('Pack · 1'), findsOneWidget);

      // Toggle mammals off → back to all.
      await tester.tap(find.byKey(const ValueKey('filter-type-mammals')));
      await tester.pumpAndSettle();
      expect(find.text('Pack · 2'), findsOneWidget);
    });
  });
}

// ─── Test helpers ─────────────────────────────────────────────────────────────

Item _item(
  String id,
  String name,
  ItemCategory category, {
  String? rarity,
  String? taxonomicClass,
  List<String> habitats = const [],
  List<String> continents = const [],
}) =>
    Item(
      id: id,
      definitionId: 'def-$id',
      displayName: name,
      category: category,
      rarity: rarity,
      acquiredAt: DateTime(2026, 1, int.parse(id)),
      status: ItemStatus.active,
      taxonomicClass: taxonomicClass,
      habitats: habitats,
      continents: continents,
    );

Future<void> _pumpPack(WidgetTester tester, List<Item> items) async {
  final container = ProviderContainer(
    overrides: [
      itemsProvider.overrideWith(() => _MockItemsNotifier(items)),
    ],
  );

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: PackScreen()),
    ),
  );

  await tester.pumpAndSettle();
}

/// Mock [ItemsNotifier] that returns a pre-loaded state — no Supabase call.
class _MockItemsNotifier extends ItemsNotifier {
  _MockItemsNotifier(this._items);
  final List<Item> _items;

  @override
  ItemsState build() =>
      ItemsState(items: _items, isLoading: false, error: null);

  @override
  Future<void> fetchItems() async {
    // State already set in build — nothing to fetch.
  }
}
