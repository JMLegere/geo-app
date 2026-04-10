import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/features/identification/presentation/providers/items_provider.dart';
import 'package:earth_nova/features/identification/presentation/screens/pack_screen.dart';
import 'dart:io';

void main() {
  group('PackScreen', () {
    testWidgets('compact bar shows filtered count, not total item count',
        (tester) async {
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
    });

    testWidgets('compact bar shows zero when no items match category',
        (tester) async {
      final items = [
        _item('1', 'Oak Tree', ItemCategory.flora, rarity: 'leastConcern'),
      ];

      await _pumpPack(tester, items);

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

      expect(
        tester.widget<Text>(find.byKey(const Key('compact-bar-count'))).data,
        '1',
      );

      await tester.tap(find.text('Flora'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(find.byKey(const Key('compact-bar-count'))).data,
        '2',
      );
    });

    testWidgets('shows empty state when user has no items at all',
        (tester) async {
      await _pumpPack(tester, []);

      expect(find.text('Pack'), findsOneWidget);
    });

    testWidgets('compact bar shows sort mode and species count',
        (tester) async {
      final items = [
        _item('1', 'Red Fox', ItemCategory.fauna),
        _item('2', 'Gray Wolf', ItemCategory.fauna),
        _item('3', 'Oak Tree', ItemCategory.flora),
      ];

      await _pumpPack(tester, items);

      expect(find.text('Recent'), findsAtLeast(1));
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

      await tester.tap(find.byKey(const Key('compact-bar')));
      await tester.pumpAndSettle();

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

      await tester.tap(find.text('Mineral'));
      await tester.pumpAndSettle();

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

      expect(
        tester.widget<Text>(find.byKey(const Key('compact-bar-count'))).data,
        '1',
      );

      await tester.tap(find.byKey(const Key('compact-bar')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('filter-type-birds')));
      await tester.pumpAndSettle();

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

      expect(find.text('Recent'), findsAtLeast(1));

      await tester.tap(find.byKey(const Key('compact-bar')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Rarity'));
      await tester.pumpAndSettle();

      expect(find.text('Rarity'), findsAtLeast(1));
    });

    testWidgets('switching sort to Name works', (tester) async {
      final items = [
        _item('1', 'Zebra', ItemCategory.fauna),
        _item('2', 'Aardvark', ItemCategory.fauna),
      ];

      await _pumpPack(tester, items);

      await tester.tap(find.byKey(const Key('compact-bar')));
      await tester.pumpAndSettle();

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

      await tester.tap(find.text('Flora'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('compact-bar')));
      await tester.pumpAndSettle();

      expect(find.text('SORT'), findsOneWidget);
      expect(find.text('TYPE'), findsNothing);
      expect(find.text('HABITAT'), findsOneWidget);
      expect(find.text('REGION'), findsOneWidget);
    });

    testWidgets('rarity toggles appear in panel for all categories',
        (tester) async {
      final items = [
        _item('1', 'Diamond', ItemCategory.mineral, rarity: 'leastConcern'),
      ];

      await _pumpPack(tester, items);
      await tester.tap(find.text('Mineral'));
      await tester.pumpAndSettle();

      expect(find.text('RARITY'), findsOneWidget);
      expect(find.text('CR'), findsOneWidget);
      expect(find.text('EN'), findsOneWidget);
      expect(find.text('VU'), findsOneWidget);
    });

    testWidgets('search bar filters by name', (tester) async {
      final items = [
        _item('1', 'Red Fox', ItemCategory.fauna),
        _item('2', 'Gray Wolf', ItemCategory.fauna),
        _item('3', 'Arctic Fox', ItemCategory.fauna),
      ];

      await _pumpPack(tester, items);
      expect(
        tester.widget<Text>(find.byKey(const Key('compact-bar-count'))).data,
        '3',
      );

      await tester.enterText(find.byType(TextField), 'Fox');
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(find.byKey(const Key('compact-bar-count'))).data,
        '2',
      );
    });

    testWidgets('tapping item opens species card bottom sheet', (tester) async {
      final items = [
        _item('1', 'Red Fox', ItemCategory.fauna,
            rarity: 'leastConcern', scientificName: 'Vulpes vulpes'),
      ];

      await _pumpPack(tester, items);

      await tester.tap(find.text('Red Fox'));
      await tester.pumpAndSettle();

      expect(find.text('Vulpes vulpes'), findsOneWidget);
      expect(find.text('Jan 1, 2026'), findsOneWidget);
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

      await tester.tap(find.byKey(const Key('compact-bar')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('filter-type-mammals')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const Key('compact-bar-count'))).data,
        '1',
      );

      await tester.tap(find.byKey(const ValueKey('filter-type-mammals')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const Key('compact-bar-count'))).data,
        '2',
      );
    });

    test('subPageCount equals ItemCategory.values.length', () {
      expect(PackScreen.subPageCount, ItemCategory.values.length);
    });

    testWidgets('accepts and uses an injected PageController', (tester) async {
      final controller = PageController();
      addTearDown(controller.dispose);

      final container = ProviderContainer(
        overrides: [
          itemsProvider.overrideWith(() => _MockItemsNotifier([])),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: PackScreen(pageController: controller)),
        ),
      );
      await tester.pumpAndSettle();

      // The injected controller should now be attached to the PageView.
      expect(controller.hasClients, isTrue);
    });

    testWidgets('does not dispose an injected PageController on unmount',
        (tester) async {
      final controller = PageController();
      // No addTearDown here — this test verifies that PackScreen does NOT
      // dispose the injected controller, so we dispose it ourselves at the end.

      final container = ProviderContainer(
        overrides: [
          itemsProvider.overrideWith(() => _MockItemsNotifier([])),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: PackScreen(pageController: controller)),
        ),
      );
      await tester.pumpAndSettle();

      // Unmount the widget.
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();

      // Controller was injected — PackScreen must NOT have disposed it.
      // Calling dispose() on an already-disposed controller throws.
      expect(() => controller.dispose(), returnsNormally);
    });

    test('source: PackScreen does not dispose injected controller', () {
      final source = File(
        'lib/features/identification/presentation/screens/pack_screen.dart',
      ).readAsStringSync();

      // When a controller is injected, the widget must NOT call dispose() on it.
      // The accepted pattern is a bool flag: _ownsController.
      expect(source, contains('_ownsController'));
    });

    testWidgets('calls onEdgeSwipe(left) when overscrolling past page 0',
        (tester) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final swipes = <EdgeSwipeDirection>[];
      final container = ProviderContainer(
        overrides: [
          itemsProvider.overrideWith(() => _MockItemsNotifier([
                _item('1', 'Red Fox', ItemCategory.fauna),
              ])),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: PackScreen(onEdgeSwipe: swipes.add),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Drag right (overscroll past page 0 = left edge).
      await tester.drag(find.byType(PageView), const Offset(400, 0));
      await tester.pumpAndSettle();

      expect(swipes, contains(EdgeSwipeDirection.left));
    });

    testWidgets(
        'calls onEdgeSwipe(right) when overscrolling past the last page',
        (tester) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final swipes = <EdgeSwipeDirection>[];
      final controller = PageController(
        initialPage: PackScreen.subPageCount - 1,
      );
      addTearDown(controller.dispose);

      final container = ProviderContainer(
        overrides: [
          itemsProvider.overrideWith(() => _MockItemsNotifier([
                _item('1', 'Red Fox', ItemCategory.fauna),
              ])),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: PackScreen(
              pageController: controller,
              onEdgeSwipe: swipes.add,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Drag left (overscroll past last page = right edge).
      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();

      expect(swipes, contains(EdgeSwipeDirection.right));
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
  String? scientificName,
  List<String> habitats = const [],
  List<String> continents = const [],
}) =>
    Item(
      id: id,
      definitionId: 'def-$id',
      displayName: name,
      scientificName: scientificName,
      category: category,
      rarity: rarity,
      acquiredAt: DateTime(2026, 1, int.parse(id)),
      status: ItemStatus.active,
      taxonomicClass: taxonomicClass,
      habitats: habitats,
      continents: continents,
    );

Future<void> _pumpPack(WidgetTester tester, List<Item> items) async {
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

class _MockItemsNotifier extends ItemsNotifier {
  _MockItemsNotifier(this._items);
  final List<Item> _items;

  @override
  ItemsState build() =>
      ItemsState(items: _items, isLoading: false, error: null);

  @override
  Future<void> fetchItems() async {}
}

class _ErrorItemsNotifier extends ItemsNotifier {
  @override
  ItemsState build() => const ItemsState(
        isLoading: false,
        error: 'Connection timed out',
      );

  @override
  Future<void> fetchItems() async {}
}
