import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/models/item.dart';
import 'package:earth_nova/providers/items_provider.dart';
import 'package:earth_nova/screens/pack_screen.dart';

void main() {
  group('PackScreen', () {
    testWidgets('compact bar shows filtered count, not total item count',
        (tester) async {
      // 4 fauna + 2 flora = 6 total; compact bar should show 4 (fauna default).
      final items = [
        _item('1', 'Red Fox', ItemCategory.fauna, rarity: 'leastConcern'),
        _item('2', 'Blue Whale', ItemCategory.fauna, rarity: 'endangered'),
        _item('3', 'Oak Tree', ItemCategory.flora, rarity: 'leastConcern'),
        _item('4', 'Pine Tree', ItemCategory.flora, rarity: 'leastConcern'),
        _item('5', 'Gray Wolf', ItemCategory.fauna, rarity: 'vulnerable'),
        _item('6', 'Brown Bear', ItemCategory.fauna, rarity: 'leastConcern'),
      ];

      await _pumpPack(tester, items);

      expect(find.text('Pack'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('compact-bar-count'))).data,
        '4',
      );
      expect(find.textContaining('Pack ·'), findsNothing);
    });

    testWidgets('compact bar shows zero when no items match category',
        (tester) async {
      // Only flora items — default fauna category yields 0 matches.
      final items = [
        _item('1', 'Oak Tree', ItemCategory.flora, rarity: 'leastConcern'),
      ];

      await _pumpPack(tester, items);

      expect(find.text('Pack'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('compact-bar-count'))).data,
        '0',
      );
    });

    testWidgets('tapping category chip updates compact bar count',
        (tester) async {
      final items = [
        _item('1', 'Red Fox', ItemCategory.fauna, rarity: 'leastConcern'),
        _item('2', 'Oak Tree', ItemCategory.flora, rarity: 'leastConcern'),
        _item('3', 'Pine Tree', ItemCategory.flora, rarity: 'leastConcern'),
      ];

      await _pumpPack(tester, items);

      // Initial: fauna → 1 item.
      expect(
        tester.widget<Text>(find.byKey(const Key('compact-bar-count'))).data,
        '1',
      );

      // Tap the "Flora" category chip label.
      await tester.tap(find.text('Flora'));
      await tester.pumpAndSettle();

      // Now flora → 2 items.
      expect(
        tester.widget<Text>(find.byKey(const Key('compact-bar-count'))).data,
        '2',
      );
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

      expect(find.text('Pack'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('compact-bar-count'))).data,
        '2',
      );
    });

    testWidgets('tapping compact bar toggles filter panel', (tester) async {
      final items = [
        _item('1', 'Red Fox', ItemCategory.fauna, taxonomicClass: 'MAMMALIA'),
      ];

      await _pumpPack(tester, items);

      // Panel is always in widget tree (slide animation) but clipped to 0.
      // Verify the chevron rotates when tapped.
      await tester.tap(find.byKey(const Key('compact-bar')));
      await tester.pumpAndSettle();

      // After expanding, the panel rows are rendered — fauna gets all 4 rows.
      expect(find.text('SORT'), findsOneWidget);
      expect(find.text('TYPE'), findsOneWidget);
      expect(find.text('HABITAT'), findsOneWidget);
      expect(find.text('REGION'), findsOneWidget);
    });

    testWidgets('non-fauna category hides TYPE row in panel', (tester) async {
      final items = [
        _item('1', 'Diamond', ItemCategory.mineral),
      ];

      await _pumpPack(tester, items);

      // Switch to mineral.
      await tester.tap(find.text('Mineral'));
      await tester.pumpAndSettle();

      // Mineral gets SORT only — no TYPE/HABITAT/REGION.
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
      expect(
        tester.widget<Text>(find.byKey(const Key('compact-bar-count'))).data,
        '1',
      );

      // Expand panel.
      await tester.tap(find.byKey(const Key('compact-bar')));
      await tester.pumpAndSettle();

      // Find the birds toggle by key.
      await tester.tap(find.byKey(const ValueKey('filter-type-birds')));
      await tester.pumpAndSettle();

      // No mammals match birds filter → 0.
      expect(
        tester.widget<Text>(find.byKey(const Key('compact-bar-count'))).data,
        '0',
      );
      expect(find.text('No discoveries match your filters'), findsOneWidget);
    });
    testWidgets('changing sort mode updates compact bar', (tester) async {
      final items = [
        _item('1', 'Red Fox', ItemCategory.fauna, rarity: 'endangered'),
        _item('2', 'Gray Wolf', ItemCategory.fauna, rarity: 'leastConcern'),
      ];

      await _pumpPack(tester, items);

      // Default sort is Recent (appears in compact bar + panel sort row).
      expect(find.text('Recent'), findsAtLeast(1));

      // Expand panel.
      await tester.tap(find.byKey(const Key('compact-bar')));
      await tester.pumpAndSettle();

      // Tap Rarity sort.
      await tester.tap(find.text('Rarity'));
      await tester.pumpAndSettle();

      // Compact bar should now show Rarity.
      expect(find.text('Rarity'), findsAtLeast(1));
    });

    testWidgets('switching sort to Name works', (tester) async {
      final items = [
        _item('1', 'Zebra', ItemCategory.fauna),
        _item('2', 'Aardvark', ItemCategory.fauna),
      ];

      await _pumpPack(tester, items);

      // Expand panel.
      await tester.tap(find.byKey(const Key('compact-bar')));
      await tester.pumpAndSettle();

      // Tap A→Z sort.
      await tester.tap(find.text('A→Z'));
      await tester.pumpAndSettle();

      expect(find.text('A→Z'), findsAtLeast(1));
    });

    testWidgets('error state shows retry button', (tester) async {
      final container = ProviderContainer(
        overrides: [
          itemsProvider.overrideWith(() => _ErrorItemsNotifier()),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: PackScreen()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text("Couldn't load your collection"), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
    });

    testWidgets('flora category shows HABITAT and REGION in panel',
        (tester) async {
      final items = [
        _item('1', 'Oak Tree', ItemCategory.flora),
      ];

      await _pumpPack(tester, items);

      // Switch to flora.
      await tester.tap(find.text('Flora'));
      await tester.pumpAndSettle();

      // Flora gets SORT + HABITAT + REGION but NOT TYPE.
      expect(find.text('SORT'), findsOneWidget);
      expect(find.text('TYPE'), findsNothing);
      expect(find.text('HABITAT'), findsOneWidget);
      expect(find.text('REGION'), findsOneWidget);
    });

    testWidgets('toggling filter off restores all items', (tester) async {
      final items = [
        _item('1', 'Red Fox', ItemCategory.fauna, taxonomicClass: 'MAMMALIA'),
        _item('2', 'Eagle', ItemCategory.fauna, taxonomicClass: 'AVES'),
      ];

      await _pumpPack(tester, items);
      expect(
        tester.widget<Text>(find.byKey(const Key('compact-bar-count'))).data,
        '2',
      );

      // Expand, filter to mammals by key.
      await tester.tap(find.byKey(const Key('compact-bar')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('filter-type-mammals')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const Key('compact-bar-count'))).data,
        '1',
      );

      // Toggle mammals off → back to all.
      await tester.tap(find.byKey(const ValueKey('filter-type-mammals')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const Key('compact-bar-count'))).data,
        '2',
      );
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
  // Use a tall viewport so the filter panel (up to ~320 px when "Clear" row
  // is visible) plus the empty/grid state both fit without overflow.
  tester.view.physicalSize = const Size(800, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

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

/// Mock that returns an error state — tests the error UI.
class _ErrorItemsNotifier extends ItemsNotifier {
  @override
  ItemsState build() => const ItemsState(
        isLoading: false,
        error: 'Connection timed out',
      );

  @override
  Future<void> fetchItems() async {}
}
