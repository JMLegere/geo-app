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
      // 4 fauna + 2 flora = 6 total; title should show 4 (fauna filter).
      final items = [
        Item(
          id: '1',
          definitionId: 'species1',
          displayName: 'Red Fox',
          category: ItemCategory.fauna,
          rarity: 'leastConcern',
          acquiredAt: DateTime(2026, 1, 1),
          status: ItemStatus.active,
        ),
        Item(
          id: '2',
          definitionId: 'species2',
          displayName: 'Blue Whale',
          category: ItemCategory.fauna,
          rarity: 'endangered',
          acquiredAt: DateTime(2026, 1, 2),
          status: ItemStatus.active,
        ),
        Item(
          id: '3',
          definitionId: 'species3',
          displayName: 'Oak Tree',
          category: ItemCategory.flora,
          rarity: 'leastConcern',
          acquiredAt: DateTime(2026, 1, 3),
          status: ItemStatus.active,
        ),
        Item(
          id: '4',
          definitionId: 'species4',
          displayName: 'Pine Tree',
          category: ItemCategory.flora,
          rarity: 'leastConcern',
          acquiredAt: DateTime(2026, 1, 4),
          status: ItemStatus.active,
        ),
        Item(
          id: '5',
          definitionId: 'species5',
          displayName: 'Gray Wolf',
          category: ItemCategory.fauna,
          rarity: 'vulnerable',
          acquiredAt: DateTime(2026, 1, 5),
          status: ItemStatus.active,
        ),
        Item(
          id: '6',
          definitionId: 'species6',
          displayName: 'Brown Bear',
          category: ItemCategory.fauna,
          rarity: 'leastConcern',
          acquiredAt: DateTime(2026, 1, 6),
          status: ItemStatus.active,
        ),
      ];

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

      // Default filter is fauna — should show 4 fauna items, not 6 total.
      expect(find.text('Pack · 4'), findsOneWidget);
      expect(find.text('Pack · 6'), findsNothing);
    });

    testWidgets('shows pack count of zero when no items match filter',
        (tester) async {
      // Only flora items — default fauna filter yields 0 matches.
      final items = [
        Item(
          id: '1',
          definitionId: 'species1',
          displayName: 'Oak Tree',
          category: ItemCategory.flora,
          rarity: 'leastConcern',
          acquiredAt: DateTime(2026, 1, 1),
          status: ItemStatus.active,
        ),
      ];

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

      // items exist but none match the fauna filter → "Pack · 0".
      expect(find.text('Pack · 0'), findsOneWidget);
    });

    testWidgets('updates title when filter changes', (tester) async {
      final items = [
        Item(
          id: '1',
          definitionId: 'species1',
          displayName: 'Red Fox',
          category: ItemCategory.fauna,
          rarity: 'leastConcern',
          acquiredAt: DateTime(2026, 1, 1),
          status: ItemStatus.active,
        ),
        Item(
          id: '2',
          definitionId: 'species2',
          displayName: 'Oak Tree',
          category: ItemCategory.flora,
          rarity: 'leastConcern',
          acquiredAt: DateTime(2026, 1, 2),
          status: ItemStatus.active,
        ),
        Item(
          id: '3',
          definitionId: 'species3',
          displayName: 'Pine Tree',
          category: ItemCategory.flora,
          rarity: 'leastConcern',
          acquiredAt: DateTime(2026, 1, 3),
          status: ItemStatus.active,
        ),
      ];

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

      // Initial: fauna filter → 1 item.
      expect(find.text('Pack · 1'), findsOneWidget);

      // Tap the "Flora" category chip label to switch filter.
      await tester.tap(find.text('Flora'));
      await tester.pumpAndSettle();

      // Now flora filter → 2 items.
      expect(find.text('Pack · 2'), findsOneWidget);
      expect(find.text('Pack · 1'), findsNothing);
    });

    testWidgets('shows empty state when user has no items at all',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          itemsProvider.overrideWith(() => _MockItemsNotifier([])),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: PackScreen()),
        ),
      );

      await tester.pumpAndSettle();

      // No items at all → title stays plain 'Pack'.
      expect(find.text('Pack'), findsOneWidget);
      expect(find.textContaining('Pack ·'), findsNothing);
    });

    testWidgets('swiping PageView left advances to next category',
        (tester) async {
      // 2 fauna + 1 flora — distinct counts let us confirm the category
      // switched by checking the title after the swipe settles.
      final items = [
        Item(
          id: '1',
          definitionId: 'species1',
          displayName: 'Red Fox',
          category: ItemCategory.fauna,
          rarity: 'leastConcern',
          acquiredAt: DateTime(2026, 1, 1),
          status: ItemStatus.active,
        ),
        Item(
          id: '2',
          definitionId: 'species2',
          displayName: 'Gray Wolf',
          category: ItemCategory.fauna,
          rarity: 'leastConcern',
          acquiredAt: DateTime(2026, 1, 2),
          status: ItemStatus.active,
        ),
        Item(
          id: '3',
          definitionId: 'species3',
          displayName: 'Oak Tree',
          category: ItemCategory.flora,
          rarity: 'leastConcern',
          acquiredAt: DateTime(2026, 1, 3),
          status: ItemStatus.active,
        ),
      ];

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

      // Initial: fauna (page 0) → 2 items.
      expect(find.text('Pack · 2'), findsOneWidget);

      // Swipe left to advance to the next category (flora, page 1).
      await tester.fling(
        find.byType(PageView),
        const Offset(-400, 0),
        800,
      );
      await tester.pumpAndSettle();

      // After the swipe, flora is active → 1 item.
      expect(find.text('Pack · 1'), findsOneWidget);
      expect(find.text('Pack · 2'), findsNothing);
    });

    testWidgets('swiping PageView right goes back to previous category',
        (tester) async {
      // Start on flora (page 1) by tapping the chip, then swipe right back
      // to fauna (page 0). Counts: 1 fauna, 2 flora.
      final items = [
        Item(
          id: '1',
          definitionId: 'species1',
          displayName: 'Red Fox',
          category: ItemCategory.fauna,
          rarity: 'leastConcern',
          acquiredAt: DateTime(2026, 1, 1),
          status: ItemStatus.active,
        ),
        Item(
          id: '2',
          definitionId: 'species2',
          displayName: 'Oak Tree',
          category: ItemCategory.flora,
          rarity: 'leastConcern',
          acquiredAt: DateTime(2026, 1, 2),
          status: ItemStatus.active,
        ),
        Item(
          id: '3',
          definitionId: 'species3',
          displayName: 'Pine Tree',
          category: ItemCategory.flora,
          rarity: 'leastConcern',
          acquiredAt: DateTime(2026, 1, 3),
          status: ItemStatus.active,
        ),
      ];

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

      // Navigate to flora first via chip tap.
      await tester.tap(find.text('Flora'));
      await tester.pumpAndSettle();
      expect(find.text('Pack · 2'), findsOneWidget);

      // Swipe right to return to fauna.
      await tester.fling(
        find.byType(PageView),
        const Offset(400, 0),
        800,
      );
      await tester.pumpAndSettle();

      // Back to fauna → 1 item.
      expect(find.text('Pack · 1'), findsOneWidget);
      expect(find.text('Pack · 2'), findsNothing);
    });
  });
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
