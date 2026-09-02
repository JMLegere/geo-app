import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/core/observability/trace_context.dart';
import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/features/identification/presentation/providers/items_provider.dart';
import 'package:earth_nova/features/pack/presentation/screens/pack_screen.dart';
import 'package:earth_nova/shared/product/player_actions.dart';

void main() {
  group('PackScreen', () {
    testWidgets('compact bar shows filtered count, not total item count', (
      tester,
    ) async {
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

    testWidgets('compact bar shows zero when no items match category', (
      tester,
    ) async {
      final items = [
        _item('1', 'Oak Tree', ItemCategory.flora, rarity: 'leastConcern'),
      ];

      await _pumpPack(tester, items);

      expect(
        tester.widget<Text>(find.byKey(const Key('compact-bar-count'))).data,
        '0',
      );
    });

    testWidgets('tapping category chip updates compact bar count', (
      tester,
    ) async {
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

    testWidgets('mobile category controls wrap inside the viewport', (
      tester,
    ) async {
      await _pumpPack(tester, const [], size: const Size(390, 844));

      final lastCategory = find.byKey(const Key('pack-category-orb'));
      expect(lastCategory, findsOneWidget);
      expect(tester.getRect(lastCategory).right, lessThanOrEqualTo(378));
    });

    testWidgets('distinguishes an initially empty Pack', (tester) async {
      await _pumpPack(tester, []);

      expect(find.text('Your Pack is empty'), findsOneWidget);
      expect(find.text('No discoveries match your filters'), findsNothing);
    });

    testWidgets('does not fetch an intentionally empty loaded Pack', (
      tester,
    ) async {
      final notifier = _FetchTrackingItemsNotifier(hasLoaded: true);
      final container = ProviderContainer(
        overrides: [
          itemsProvider.overrideWith(() => notifier),
          appObservabilityProvider.overrideWithValue(
            ObservabilityService(sessionId: 'test-session'),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const ShadApp(home: PackScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(notifier.fetchCalls, 0);
    });

    testWidgets('compact bar shows sort mode and species count', (
      tester,
    ) async {
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
      final items = [_item('1', 'Diamond', ItemCategory.mineral)];

      await _pumpPack(tester, items);

      await tester.tap(find.text('Mineral'));
      await tester.pumpAndSettle();

      expect(find.text('SORT'), findsOneWidget);
      expect(find.text('TYPE'), findsNothing);
      expect(find.text('HABITAT'), findsNothing);
      expect(find.text('REGION'), findsNothing);
    });

    testWidgets('filter-driven empty state shows correct message', (
      tester,
    ) async {
      final items = [
        _item(
          '1',
          'Red Fox',
          ItemCategory.fauna,
          taxonomicClass: 'MAMMALIA',
          habitats: ['Forest'],
        ),
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

    testWidgets('error state retries the failed fetch', (tester) async {
      final notifier = _ErrorItemsNotifier();
      final container = ProviderContainer(
        overrides: [
          itemsProvider.overrideWith(() => notifier),
          appObservabilityProvider.overrideWithValue(
            ObservabilityService(sessionId: 'test-session'),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const ShadApp(home: PackScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Couldn't load your collection"), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
      final fetchCallsBeforeRetry = notifier.fetchCalls;

      await tester.tap(find.text('Try Again'));
      await tester.pump();

      expect(notifier.fetchCalls, fetchCallsBeforeRetry + 1);
    });

    testWidgets('flora category shows HABITAT and REGION in panel', (
      tester,
    ) async {
      final items = [_item('1', 'Oak Tree', ItemCategory.flora)];

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

    testWidgets('conservation toggles appear in panel for all categories', (
      tester,
    ) async {
      final items = [
        _item('1', 'Diamond', ItemCategory.mineral, rarity: 'leastConcern'),
      ];

      await _pumpPack(tester, items);
      await tester.tap(find.text('Mineral'));
      await tester.pumpAndSettle();

      expect(find.text('CONSERVATION'), findsOneWidget);
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

    testWidgets('search does not leak unidentified hidden species name', (
      tester,
    ) async {
      final items = [
        _item(
          '1',
          'Unidentified fauna specimen',
          ItemCategory.fauna,
          rarity: 'rare',
          identificationState: ItemIdentificationState.unidentified,
          identifiedDisplayName: 'Amberwing Warbler',
          examinationState: ItemExaminationState.unexamined,
        ),
      ];

      await _pumpPack(tester, items);

      await tester.enterText(find.byType(TextField), 'Amberwing');
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(find.byKey(const Key('compact-bar-count'))).data,
        '0',
      );
      expect(find.text('Amberwing Warbler'), findsNothing);
    });
    testWidgets(
      'newest exact Item is first and one unexamined tap opens its recognized same-ID card',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final newest = _item(
          '2',
          'Amberwing Warbler',
          ItemCategory.fauna,
          rarity: 'rare',
          scientificName: 'Setophaga aestiva',
          identificationState: ItemIdentificationState.unidentified,
          examinationState: ItemExaminationState.unexamined,
        );
        final examined = newest.copyWith(
          examinationState: ItemExaminationState.examined,
          examinedAt: DateTime.utc(2026, 1, 3),
        );
        final notifier = _ExaminationTrackingItemsNotifier([
          newest,
          _item('1', 'Older Item', ItemCategory.fauna),
        ], examined);
        final container = await _pumpPackWithNotifier(tester, notifier);

        final newestSurface = find.byKey(const ValueKey('pack-item-2'));
        final olderSurface = find.byKey(const ValueKey('pack-item-1'));
        expect(newestSurface, findsOneWidget);
        expect(olderSurface, findsOneWidget);
        final newestPosition = tester.getTopLeft(newestSurface);
        final olderPosition = tester.getTopLeft(olderSurface);
        expect(
          newestPosition.dy < olderPosition.dy ||
              newestPosition.dy == olderPosition.dy &&
                  newestPosition.dx < olderPosition.dx,
          isTrue,
        );
        expect(find.bySemanticsLabel('Unexamined fauna Item'), findsOneWidget);
        expect(find.text('Amberwing Warbler'), findsNothing);
        expect(find.text('Setophaga aestiva'), findsNothing);

        await tester.tap(newestSurface);
        await tester.pumpAndSettle();

        expect(notifier.examineCalls, 1);
        expect(notifier.lastExaminedItemId, '2');
        expect(notifier.lastParent, isNotNull);
        final trace = container
            .read(appObservabilityProvider)
            .pendingSpanRecords
            .singleWhere(
              (span) =>
                  span['span_name'] ==
                  'interaction.${PlayerActions.examinePackItem}',
            );
        expect(
          (trace['attributes'] as Map<String, dynamic>)['transition'],
          'examination_started',
        );
        expect(find.byKey(const ValueKey('species-card-2')), findsOneWidget);
        expect(find.text('Amberwing Warbler'), findsNWidgets(2));
        expect(find.text('Setophaga aestiva'), findsOneWidget);
        semantics.dispose();
      },
    );

    testWidgets('browsing Pack performs no gameplay mutation', (tester) async {
      final notifier = _ExaminationTrackingItemsNotifier([
        _item('1', 'Red Fox', ItemCategory.fauna),
      ], _item('1', 'Red Fox', ItemCategory.fauna));
      await _pumpPackWithNotifier(tester, notifier);

      await tester.tap(find.byKey(const Key('compact-bar')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Fox');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Red Fox'));
      await tester.pumpAndSettle();

      expect(notifier.examineCalls, 0);
      expect(notifier.identifyCalls, 0);
    });

    testWidgets('tapping an examined Item opens its species card', (
      tester,
    ) async {
      final items = [
        _item(
          '1',
          'Red Fox',
          ItemCategory.fauna,
          rarity: 'leastConcern',
          scientificName: 'Vulpes vulpes',
        ),
      ];

      final container = await _pumpPack(tester, items);

      await tester.tap(find.text('Red Fox'));
      await tester.pumpAndSettle();

      expect(find.text('Vulpes vulpes'), findsOneWidget);
      expect(find.text('Jan 1, 2026'), findsOneWidget);
      final trace = container
          .read(appObservabilityProvider)
          .pendingSpanRecords
          .singleWhere(
            (span) =>
                span['span_name'] ==
                'interaction.${PlayerActions.inspectPackFind}',
          );
      expect(
        (trace['attributes'] as Map<String, dynamic>)['transition'],
        'species_card_visible',
      );
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
    testWidgets('uses 3 columns below 600px', (tester) async {
      await _expectGrid(tester, width: 599, columns: 3, ratio: 0.78);
    });

    testWidgets('uses 4 columns from 600px through 899px', (tester) async {
      await _expectGrid(tester, width: 600, columns: 4, ratio: 0.82);
    });

    testWidgets('uses 6 columns from 900px', (tester) async {
      await _expectGrid(tester, width: 900, columns: 6, ratio: 0.85);
    });

    testWidgets('distinguishes a category with no discoveries', (tester) async {
      await _pumpPack(tester, [_item('1', 'Oak Tree', ItemCategory.flora)]);

      expect(find.text('No fauna discovered yet'), findsOneWidget);
      expect(find.text('Your Pack is empty'), findsNothing);
      expect(find.text('No discoveries match your filters'), findsNothing);
    });

    testWidgets('uses category media only when Item media is unavailable', (
      tester,
    ) async {
      await _pumpPack(tester, [_item('1', 'Red Fox', ItemCategory.fauna)]);

      expect(
        find.byKey(const ValueKey('pack-media-fallback-1')),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.pets_outlined), findsOneWidget);
    });

    testWidgets('shows a distinct loading state', (tester) async {
      final container = ProviderContainer(
        overrides: [
          itemsProvider.overrideWith(_LoadingItemsNotifier.new),
          appObservabilityProvider.overrideWithValue(
            ObservabilityService(sessionId: 'test-session'),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const ShadApp(home: PackScreen()),
        ),
      );
      await tester.pump();

      expect(find.bySemanticsLabel('Loading Pack'), findsOneWidget);
      expect(find.text('Your Pack is empty'), findsNothing);
      expect(find.text("Couldn't load your collection"), findsNothing);
    });

    testWidgets('busy guard prevents duplicate examination of the same Item', (
      tester,
    ) async {
      final item = _item(
        '1',
        'Red Fox',
        ItemCategory.fauna,
        identificationState: ItemIdentificationState.unidentified,
        examinationState: ItemExaminationState.unexamined,
      );
      final notifier = _BlockingExaminationNotifier(
        item,
        item.copyWith(
          examinationState: ItemExaminationState.examined,
          examinedAt: DateTime(2026, 1, 2),
        ),
      );
      await _pumpPackWithNotifier(tester, notifier);
      final surface = find.byKey(const ValueKey('pack-item-1'));

      await tester.tap(surface);
      await tester.pump();
      expect(find.text('Examining'), findsOneWidget);
      expect(find.byKey(const Key('pack-examining-icon')), findsOneWidget);
      await tester.tap(surface);
      await tester.pump();

      expect(notifier.examineCalls, 1);
      notifier.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('species-card-1')), findsOneWidget);
    });

    test('source: Pack presentation uses only neutral design vocabulary', () {
      final source = File(
        'lib/features/pack/presentation/screens/pack_screen.dart',
      ).readAsStringSync();

      expect(source, contains("package:earth_nova/shared/design.dart"));
      for (final token in const [
        'AppTheme',
        'design_tokens',
        'Earth',
        'TCG',
        'LinearGradient',
        'BoxShadow',
        'glow',
        'iconography.dart',
        'iucn_status_theme',
        'Color(0x',
      ]) {
        expect(source, isNot(contains(token)), reason: 'legacy token: $token');
      }
      expect(source, isNot(contains('.emoji')));
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
          appObservabilityProvider.overrideWithValue(
            ObservabilityService(sessionId: 'test-session'),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: ShadApp(home: PackScreen(pageController: controller)),
        ),
      );
      await tester.pumpAndSettle();

      // The injected controller should now be attached to the PageView.
      expect(controller.hasClients, isTrue);
    });

    testWidgets('does not dispose an injected PageController on unmount', (
      tester,
    ) async {
      final controller = PageController();
      // No addTearDown here — this test verifies that PackScreen does NOT
      // dispose the injected controller, so we dispose it ourselves at the end.

      final container = ProviderContainer(
        overrides: [
          itemsProvider.overrideWith(() => _MockItemsNotifier([])),
          appObservabilityProvider.overrideWithValue(
            ObservabilityService(sessionId: 'test-session'),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: ShadApp(home: PackScreen(pageController: controller)),
        ),
      );
      await tester.pumpAndSettle();

      // Unmount the widget.
      await tester.pumpWidget(const ShadApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();

      // Controller was injected — PackScreen must NOT have disposed it.
      // Calling dispose() on an already-disposed controller throws.
      expect(() => controller.dispose(), returnsNormally);
    });

    test('source: PackScreen does not dispose injected controller', () {
      final source = File(
        'lib/features/pack/presentation/screens/pack_screen.dart',
      ).readAsStringSync();

      // When a controller is injected, the widget must NOT call dispose() on it.
      // The accepted pattern is a bool flag: _ownsController.
      expect(source, contains('_ownsController'));
    });

    test('source: main.dart enables mouse drag via scrollBehavior', () {
      // OverscrollNotification fires correctly with default ClampingScrollPhysics
      // once mouse is included in dragDevices. The fix lives in MaterialApp.
      final mainSource = File('lib/main.dart').readAsStringSync();
      expect(mainSource, contains('scrollBehavior'));
      expect(mainSource, contains('PointerDeviceKind.mouse'));
    });

    testWidgets('calls onEdgeSwipe(left) when overscrolling past page 0', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final swipes = <EdgeSwipeDirection>[];
      final container = ProviderContainer(
        overrides: [
          itemsProvider.overrideWith(
            () =>
                _MockItemsNotifier([_item('1', 'Red Fox', ItemCategory.fauna)]),
          ),
          appObservabilityProvider.overrideWithValue(
            ObservabilityService(sessionId: 'test-session'),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: ShadApp(home: PackScreen(onEdgeSwipe: swipes.add)),
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
            itemsProvider.overrideWith(
              () => _MockItemsNotifier([
                _item('1', 'Red Fox', ItemCategory.fauna),
              ]),
            ),
            appObservabilityProvider.overrideWithValue(
              ObservabilityService(sessionId: 'test-session'),
            ),
          ],
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: ShadApp(
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
      },
    );
  });
}

// ─── Test helpers ─────────────────────────────────────────────────────────────
Future<void> _expectGrid(
  WidgetTester tester, {
  required double width,
  required int columns,
  required double ratio,
}) async {
  await _pumpPack(tester, [
    _item('1', 'Red Fox', ItemCategory.fauna),
  ], size: Size(width, 900));
  final grid = tester.widget<GridView>(find.byKey(const Key('pack-grid')));
  final delegate =
      grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
  expect(delegate.crossAxisCount, columns);
  expect(delegate.childAspectRatio, ratio);
}

Item _item(
  String id,
  String name,
  ItemCategory category, {
  String? rarity,
  String? taxonomicClass,
  String? scientificName,
  List<String> habitats = const [],
  List<String> continents = const [],
  ItemIdentificationState identificationState =
      ItemIdentificationState.identified,
  String? identifiedDisplayName,
  String? identifiedScientificName,
  ItemExaminationState examinationState = ItemExaminationState.examined,
  DateTime? examinedAt,
}) => Item(
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
  identificationState: identificationState,
  examinationState: examinationState,
  examinedAt: examinedAt,
  identifiedDisplayName: identifiedDisplayName,
  identifiedScientificName: identifiedScientificName,
);

Future<ProviderContainer> _pumpPack(
  WidgetTester tester,
  List<Item> items, {
  Size size = const Size(800, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  final container = ProviderContainer(
    overrides: [
      itemsProvider.overrideWith(() => _MockItemsNotifier(items)),
      appObservabilityProvider.overrideWithValue(
        ObservabilityService(sessionId: 'test-session'),
      ),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const ShadApp(home: PackScreen()),
    ),
  );

  await tester.pumpAndSettle();
  return container;
}

Future<ProviderContainer> _pumpPackWithNotifier(
  WidgetTester tester,
  ItemsNotifier notifier,
) async {
  tester.view.physicalSize = const Size(800, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  final container = ProviderContainer(
    overrides: [
      itemsProvider.overrideWith(() => notifier),
      appObservabilityProvider.overrideWithValue(
        ObservabilityService(sessionId: 'test-session'),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const ShadApp(home: PackScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return container;
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

class _FetchTrackingItemsNotifier extends ItemsNotifier {
  _FetchTrackingItemsNotifier({required this.hasLoaded});

  final bool hasLoaded;
  int fetchCalls = 0;

  @override
  ItemsState build() => ItemsState(hasLoaded: hasLoaded);

  @override
  Future<void> fetchItems() async {
    fetchCalls++;
  }
}

class _ExaminationTrackingItemsNotifier extends _MockItemsNotifier {
  _ExaminationTrackingItemsNotifier(super.items, this.examinedItem);

  final Item examinedItem;
  int examineCalls = 0;
  int identifyCalls = 0;
  TraceContext? lastParent;
  String? lastExaminedItemId;

  @override
  Future<Item?> examinePackItem(String itemId, {TraceContext? parent}) async {
    lastParent = parent;
    examineCalls++;
    lastExaminedItemId = itemId;
    state = state.copyWith(
      items: [
        for (final item in state.items)
          if (item.id == itemId) examinedItem else item,
      ],
    );
    return examinedItem;
  }

  @override
  Future<Item?> identifyUnidentifiedFind(String itemId) async {
    identifyCalls++;
    return null;
  }
}

class _LoadingItemsNotifier extends ItemsNotifier {
  @override
  ItemsState build() => const ItemsState(isLoading: true);

  @override
  Future<void> fetchItems() async {}
}

class _BlockingExaminationNotifier extends _MockItemsNotifier {
  _BlockingExaminationNotifier(Item item, this.examinedItem) : super([item]);

  final Item examinedItem;
  final Completer<Item?> _result = Completer<Item?>();
  int examineCalls = 0;

  @override
  Future<Item?> examinePackItem(String itemId, {TraceContext? parent}) {
    examineCalls++;
    return _result.future;
  }

  void complete() => _result.complete(examinedItem);
}

class _ErrorItemsNotifier extends ItemsNotifier {
  int fetchCalls = 0;

  @override
  ItemsState build() =>
      const ItemsState(isLoading: false, error: 'Connection timed out');

  @override
  Future<void> fetchItems() async {
    fetchCalls++;
  }
}
