import 'dart:async';
import 'dart:io';

import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/core/observability/trace_context.dart';
import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/identification/presentation/providers/items_provider.dart';
import 'package:earth_nova/features/pack/presentation/screens/pack_screen.dart';
import 'package:earth_nova/features/pack/presentation/widgets/species_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'phase_five_capture_support.dart';
import 'phase_seven_capture_support.dart';

final _observability = ObservabilityService(
  sessionId: 'phase-five-pack-fixture',
);

const _phaseSevenPackSpeciesAssets = [
  'pack/initial-loading-390x844.png',
  'pack/initial-loading-1440x900.png',
  'pack/examination-busy-390x844.png',
  'pack/examination-busy-1440x900.png',
  'pack/initial-empty-1440x900.png',
  'pack/filtered-zero-1440x900.png',
  'pack/error-retry-1440x900.png',
  'species/unexamined-1440x900.png',
  'species/examined-unidentified-1440x900.png',
  'species/identified-1440x900.png',
];

final _packItems = <Item>[
  _item(
    id: 'pack-red-fox',
    name: 'Red Fox',
    scientificName: 'Vulpes vulpes',
    rarity: 'leastConcern',
    taxonomicClass: 'MAMMALIA',
    habitats: const ['Forest'],
    continents: const ['Europe'],
    day: 12,
  ),
  _item(
    id: 'pack-gray-wolf',
    name: 'Gray Wolf',
    scientificName: 'Canis lupus',
    rarity: 'leastConcern',
    taxonomicClass: 'MAMMALIA',
    day: 11,
  ),
  _item(
    id: 'pack-snow-leopard',
    name: 'Snow Leopard',
    scientificName: 'Panthera uncia',
    rarity: 'vulnerable',
    taxonomicClass: 'MAMMALIA',
    day: 10,
  ),
  _item(
    id: 'pack-bald-eagle',
    name: 'Bald Eagle',
    scientificName: 'Haliaeetus leucocephalus',
    rarity: 'leastConcern',
    taxonomicClass: 'AVES',
    day: 9,
  ),
  _item(
    id: 'pack-blue-whale',
    name: 'Blue Whale',
    scientificName: 'Balaenoptera musculus',
    rarity: 'endangered',
    taxonomicClass: 'MAMMALIA',
    day: 8,
  ),
  _item(
    id: 'pack-green-turtle',
    name: 'Green Turtle',
    scientificName: 'Chelonia mydas',
    rarity: 'endangered',
    taxonomicClass: 'REPTILIA',
    day: 7,
  ),
  _item(
    id: 'pack-peregrine-falcon',
    name: 'Peregrine Falcon',
    scientificName: 'Falco peregrinus',
    rarity: 'leastConcern',
    taxonomicClass: 'AVES',
    day: 6,
  ),
  _item(
    id: 'pack-red-panda',
    name: 'Red Panda',
    scientificName: 'Ailurus fulgens',
    rarity: 'endangered',
    taxonomicClass: 'MAMMALIA',
    day: 5,
  ),
  _item(
    id: 'pack-axolotl',
    name: 'Axolotl',
    scientificName: 'Ambystoma mexicanum',
    rarity: 'criticallyEndangered',
    taxonomicClass: 'AMPHIBIA',
    day: 4,
  ),
  _item(
    id: 'pack-sea-otter',
    name: 'Sea Otter',
    scientificName: 'Enhydra lutris',
    rarity: 'endangered',
    taxonomicClass: 'MAMMALIA',
    day: 3,
  ),
  _item(
    id: 'pack-monarch',
    name: 'Monarch Butterfly',
    scientificName: 'Danaus plexippus',
    rarity: 'endangered',
    taxonomicClass: 'INSECTA',
    day: 2,
  ),
  _item(
    id: 'pack-unexamined-warbler',
    name: 'Yellow Warbler',
    scientificName: 'Setophaga aestiva',
    identificationState: ItemIdentificationState.unidentified,
    examinationState: ItemExaminationState.unexamined,
    day: 1,
  ),
];

final _unexaminedSpecies = _item(
  id: 'species-unexamined',
  name: 'Yellow Warbler',
  scientificName: 'Setophaga aestiva',
  identificationState: ItemIdentificationState.unidentified,
  examinationState: ItemExaminationState.unexamined,
  day: 15,
);

final _examinedUnidentifiedSpecies = _item(
  id: 'species-examined-unidentified',
  name: 'Yellow Warbler',
  scientificName: 'Setophaga aestiva',
  taxonomicClass: 'AVES',
  identificationState: ItemIdentificationState.unidentified,
  examinationState: ItemExaminationState.examined,
  day: 15,
);

final _identifiedSpecies = _item(
  id: 'species-identified',
  name: 'Red Fox',
  scientificName: 'Vulpes vulpes',
  rarity: 'endangered',
  taxonomicClass: 'MAMMALIA',
  habitats: const ['Forest', 'Mountain'],
  continents: const ['Europe', 'Asia'],
  cellId: 'v_45_67',
  artUrl: 'https://example.invalid/species-art.png',
  iconUrl: 'https://example.invalid/species-icon.png',
  day: 15,
);

void main() {
  test('declares the ten phase seven Pack and species assets', () {
    expect(_phaseSevenPackSpeciesAssets, hasLength(10));
    expect(_phaseSevenPackSpeciesAssets.toSet(), hasLength(10));
  });

  for (final viewport in const [
    (name: '390x844', size: phaseFiveMobileSize, columns: 3),
    (name: '1440x900', size: phaseFiveDesktopSize, columns: 6),
  ]) {
    testWidgets(
      'captures populated Pack at ${viewport.name}',
      (tester) async {
        _resetViewAfterTest(tester);
        final scene = _PackScene(
          _FixtureItemsNotifier(ItemsState(items: _packItems, hasLoaded: true)),
        );

        await _captureOffline(
          tester,
          size: viewport.size,
          name: 'pack/populated-${viewport.name}.png',
          child: scene,
        );

        final grid = tester.widget<GridView>(
          find.byKey(const Key('pack-grid')),
        );
        final delegate =
            grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
        expect(delegate.crossAxisCount, viewport.columns);
        expect(
          find.byKey(const ValueKey('pack-item-pack-red-fox')),
          findsOneWidget,
        );
      },
      skip: !phaseFiveCaptureEnabled,
    );
  }

  for (final viewport in const [
    (name: '390x844', size: phaseSevenMobileSize),
    (name: '1440x900', size: phaseSevenDesktopSize),
  ]) {
    testWidgets(
      'captures Pack initial loading at ${viewport.name}',
      (tester) async {
        _resetViewAfterTest(tester);
        await _capturePhaseSevenOffline(
          tester,
          size: viewport.size,
          name: 'pack/initial-loading-${viewport.name}.png',
          child: _PackScene(
            _FixtureItemsNotifier(const ItemsState(isLoading: true)),
          ),
          prepare: (tester) async {
            expect(find.bySemanticsLabel('Loading Pack'), findsOneWidget);
          },
        );
      },
      skip: !phaseSevenCaptureEnabled,
    );
  }

  for (final viewport in const [
    (name: '390x844', size: phaseSevenMobileSize),
    (name: '1440x900', size: phaseSevenDesktopSize),
  ]) {
    testWidgets(
      'captures Pack examination busy at ${viewport.name}',
      (tester) async {
        _resetViewAfterTest(tester);
        await _capturePhaseSevenOffline(
          tester,
          size: viewport.size,
          name: 'pack/examination-busy-${viewport.name}.png',
          child: _PackScene(
            _BusyExaminationItemsNotifier(
              ItemsState(items: [_packItems.last], hasLoaded: true),
            ),
          ),
          prepare: (tester) async {
            await tester.tap(
              find.byKey(const ValueKey('pack-item-pack-unexamined-warbler')),
            );
            await tester.pump();
            expect(
              find.byKey(const Key('pack-examining-icon')),
              findsOneWidget,
            );
          },
        );
      },
      skip: !phaseSevenCaptureEnabled,
    );
  }

  testWidgets('captures the initially empty Pack', (tester) async {
    _resetViewAfterTest(tester);
    await _captureOffline(
      tester,
      size: phaseFiveMobileSize,
      name: 'pack/initial-empty-390x844.png',
      child: _PackScene(
        _FixtureItemsNotifier(const ItemsState(hasLoaded: true)),
      ),
    );

    expect(find.text('Your Pack is empty'), findsOneWidget);
    expect(find.text('No discoveries match your filters'), findsNothing);
    expect(find.text("Couldn't load your collection"), findsNothing);
  }, skip: !phaseFiveCaptureEnabled);

  testWidgets('captures Pack fetch error with retry', (tester) async {
    _resetViewAfterTest(tester);
    final notifier = _FixtureItemsNotifier(
      const ItemsState(error: 'Connection timed out'),
    );
    await _captureOffline(
      tester,
      size: phaseFiveMobileSize,
      name: 'pack/error-retry-390x844.png',
      child: _PackScene(notifier),
    );

    expect(find.text("Couldn't load your collection"), findsOneWidget);
    expect(find.text('Try Again'), findsOneWidget);
    final callsBeforeRetry = notifier.fetchCalls;
    await tester.tap(find.text('Try Again'));
    await tester.pump();
    expect(notifier.fetchCalls, callsBeforeRetry + 1);
  }, skip: !phaseFiveCaptureEnabled);

  testWidgets(
    'captures Pack filtered-zero without a gesture',
    (tester) async {
      _resetViewAfterTest(tester);
      final scene = _PackScene(
        _FixtureItemsNotifier(ItemsState(items: _packItems, hasLoaded: true)),
      );
      const name = 'pack/filtered-zero-390x844.png';

      // Mount without writing first: capture finalization lingers in this
      // harness, so the filtered state must be the test's only capture.
      await HttpOverrides.runZoned(
        () => pumpPhaseFiveFixture(
          tester,
          size: phaseFiveMobileSize,
          child: scene,
        ),
        createHttpClient: (_) => _OfflineHttpClient(),
      );
      await tester.enterText(find.byType(TextField), 'no matching discovery');
      await tester.pumpAndSettle();
      await _captureOffline(
        tester,
        size: phaseFiveMobileSize,
        name: name,
        child: scene,
      );

      expect(find.text('No discoveries match your filters'), findsOneWidget);
      expect(find.text('Your Pack is empty'), findsNothing);
      expect(find.text("Couldn't load your collection"), findsNothing);
      expect(
        tester.widget<Text>(find.byKey(const Key('compact-bar-count'))).data,
        '0',
      );
    },
    skip: !phaseFiveCaptureEnabled,
  );

  testWidgets(
    'captures the initially empty Pack on desktop',
    (tester) async {
      _resetViewAfterTest(tester);
      await _capturePhaseSevenOffline(
        tester,
        size: phaseSevenDesktopSize,
        name: 'pack/initial-empty-1440x900.png',
        child: _PackScene(
          _FixtureItemsNotifier(const ItemsState(hasLoaded: true)),
        ),
        prepare: (tester) async {
          expect(find.text('Your Pack is empty'), findsOneWidget);
          expect(find.text('No discoveries match your filters'), findsNothing);
          expect(find.text("Couldn't load your collection"), findsNothing);
        },
      );
    },
    skip: !phaseSevenCaptureEnabled,
  );

  testWidgets(
    'captures Pack filtered-zero on desktop without a gesture',
    (tester) async {
      _resetViewAfterTest(tester);
      await _capturePhaseSevenOffline(
        tester,
        size: phaseSevenDesktopSize,
        name: 'pack/filtered-zero-1440x900.png',
        child: _PackScene(
          _FixtureItemsNotifier(ItemsState(items: _packItems, hasLoaded: true)),
        ),
        prepare: (tester) async {
          await tester.enterText(
            find.byType(TextField),
            'no matching discovery',
          );
          await tester.pumpAndSettle();
          expect(
            find.text('No discoveries match your filters'),
            findsOneWidget,
          );
          expect(find.text('Your Pack is empty'), findsNothing);
          expect(
            tester
                .widget<Text>(find.byKey(const Key('compact-bar-count')))
                .data,
            '0',
          );
        },
      );
    },
    skip: !phaseSevenCaptureEnabled,
  );

  testWidgets(
    'captures Pack fetch error with retry on desktop',
    (tester) async {
      _resetViewAfterTest(tester);
      final notifier = _FixtureItemsNotifier(
        const ItemsState(error: 'Connection timed out'),
      );
      await _capturePhaseSevenOffline(
        tester,
        size: phaseSevenDesktopSize,
        name: 'pack/error-retry-1440x900.png',
        child: _PackScene(notifier),
        prepare: (tester) async {
          expect(find.text("Couldn't load your collection"), findsOneWidget);
          expect(find.text('Try Again'), findsOneWidget);
          final callsBeforeRetry = notifier.fetchCalls;
          await tester.tap(find.text('Try Again'));
          await tester.pump();
          expect(notifier.fetchCalls, callsBeforeRetry + 1);
        },
      );
    },
    skip: !phaseSevenCaptureEnabled,
  );

  for (final fixture in [
    (name: 'species/unexamined-390x844.png', item: _unexaminedSpecies),
    (
      name: 'species/examined-unidentified-390x844.png',
      item: _examinedUnidentifiedSpecies,
    ),
    (name: 'species/identified-390x844.png', item: _identifiedSpecies),
  ]) {
    testWidgets('captures ${fixture.name}', (tester) async {
      _resetViewAfterTest(tester);
      final scene = _SpeciesScene(fixture.item);

      await HttpOverrides.runZoned(() async {
        await capturePhaseFiveFixture(
          tester,
          size: phaseFiveMobileSize,
          name: fixture.name,
          child: scene,
        );
        if (fixture.item.artUrl != null) {
          await tester.pump();
          await tester.pump();
          await capturePhaseFiveFixture(
            tester,
            size: phaseFiveMobileSize,
            name: fixture.name,
            child: scene,
          );
        }
      }, createHttpClient: (_) => _OfflineHttpClient());

      expect(
        find.byKey(ValueKey('species-card-${fixture.item.id}')),
        findsOneWidget,
      );
      if (!fixture.item.isExamined) {
        expect(find.text(fixture.item.displayName), findsNothing);
        expect(find.text(fixture.item.scientificName!), findsNothing);
        expect(find.text('Unexamined fauna Item'), findsOneWidget);
      } else {
        expect(find.text(fixture.item.displayName), findsNWidgets(2));
        expect(find.text(fixture.item.scientificName!), findsOneWidget);
        expect(
          find.text(fixture.item.isUnidentified ? 'Examined' : 'Identified'),
          findsOneWidget,
        );
      }
      if (fixture.item.artUrl != null) {
        expect(
          find.byKey(ValueKey('species-art-${fixture.item.id}')),
          findsOneWidget,
        );
        expect(
          find.byKey(ValueKey('species-media-fallback-${fixture.item.id}')),
          findsOneWidget,
        );
      }
    }, skip: !phaseFiveCaptureEnabled);
  }

  for (final fixture in [
    (name: 'species/unexamined-1440x900.png', item: _unexaminedSpecies),
    (
      name: 'species/examined-unidentified-1440x900.png',
      item: _examinedUnidentifiedSpecies,
    ),
    (name: 'species/identified-1440x900.png', item: _identifiedSpecies),
  ]) {
    testWidgets('captures ${fixture.name}', (tester) async {
      _resetViewAfterTest(tester);
      await _capturePhaseSevenOffline(
        tester,
        size: phaseSevenDesktopSize,
        name: fixture.name,
        child: _SpeciesScene(fixture.item),
        prepare: (tester) async {
          if (fixture.item.artUrl != null) {
            await tester.pump();
            await tester.pump();
          }
          expect(
            find.byKey(ValueKey('species-card-${fixture.item.id}')),
            findsOneWidget,
          );
          if (!fixture.item.isExamined) {
            expect(find.text('Unexamined fauna Item'), findsOneWidget);
          } else {
            expect(find.text(fixture.item.displayName), findsNWidgets(2));
            expect(
              find.text(
                fixture.item.isUnidentified ? 'Examined' : 'Identified',
              ),
              findsOneWidget,
            );
          }
          if (fixture.item.artUrl != null) {
            expect(
              find.byKey(ValueKey('species-art-${fixture.item.id}')),
              findsOneWidget,
            );
            expect(
              find.byKey(ValueKey('species-media-fallback-${fixture.item.id}')),
              findsOneWidget,
            );
          }
        },
      );
    }, skip: !phaseSevenCaptureEnabled);
  }

  test(
    'fixture identities preserve the three production disclosure states',
    () {
      expect(_unexaminedSpecies.id, 'species-unexamined');
      expect(
        _unexaminedSpecies.visibleDisplayName,
        'Unidentified fauna specimen',
      );
      expect(_unexaminedSpecies.visibleScientificName, isNull);
      expect(_examinedUnidentifiedSpecies.id, 'species-examined-unidentified');
      expect(_examinedUnidentifiedSpecies.visibleDisplayName, 'Yellow Warbler');
      expect(_examinedUnidentifiedSpecies.isUnidentified, isTrue);
      expect(_identifiedSpecies.id, 'species-identified');
      expect(_identifiedSpecies.visibleDisplayName, 'Red Fox');
      expect(_identifiedSpecies.isUnidentified, isFalse);
    },
  );
}

class _PackScene extends StatelessWidget {
  const _PackScene(this.notifier);

  final _FixtureItemsNotifier notifier;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        itemsProvider.overrideWith(() => notifier),
        appObservabilityProvider.overrideWithValue(_observability),
      ],
      child: const PackScreen(),
    );
  }
}

class _SpeciesScene extends StatelessWidget {
  const _SpeciesScene(this.item);

  final Item item;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SpeciesCard(item: item, onOpenIdentificationService: (_) {}),
    );
  }
}

class _FixtureItemsNotifier extends ItemsNotifier {
  _FixtureItemsNotifier(this.initialState);

  final ItemsState initialState;
  int fetchCalls = 0;

  @override
  ItemsState build() => initialState;

  @override
  Future<void> fetchItems() async {
    fetchCalls++;
  }
}

class _BusyExaminationItemsNotifier extends _FixtureItemsNotifier {
  _BusyExaminationItemsNotifier(super.initialState);

  final _pendingExamination = Completer<Item?>();

  @override
  Future<Item?> examinePackItem(String itemId, {TraceContext? parent}) =>
      _pendingExamination.future;
}

class _OfflineHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) => Future<HttpClientRequest>.error(
    const SocketException('Phase 5 fixture is offline'),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _captureOffline(
  WidgetTester tester, {
  required Size size,
  required String name,
  required Widget child,
}) {
  return HttpOverrides.runZoned(
    () => capturePhaseFiveFixture(tester, size: size, name: name, child: child),
    createHttpClient: (_) => _OfflineHttpClient(),
  );
}

Future<void> _capturePhaseSevenOffline(
  WidgetTester tester, {
  required Size size,
  required String name,
  required Widget child,
  Future<void> Function(WidgetTester tester)? prepare,
}) {
  return HttpOverrides.runZoned(
    () => capturePhaseSevenFixture(
      tester,
      size: size,
      name: name,
      child: child,
      prepare: prepare,
    ),
    createHttpClient: (_) => _OfflineHttpClient(),
  );
}

void _resetViewAfterTest(WidgetTester tester) {
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Item _item({
  required String id,
  required String name,
  String? scientificName,
  String? rarity,
  String? taxonomicClass,
  List<String> habitats = const [],
  List<String> continents = const [],
  String? cellId,
  String? artUrl,
  String? iconUrl,
  ItemIdentificationState identificationState =
      ItemIdentificationState.identified,
  ItemExaminationState examinationState = ItemExaminationState.examined,
  required int day,
}) {
  return Item(
    id: id,
    definitionId: 'definition-$id',
    displayName: name,
    scientificName: scientificName,
    category: ItemCategory.fauna,
    rarity: rarity,
    iconUrl: iconUrl,
    artUrl: artUrl,
    acquiredAt: DateTime(2026, 1, day),
    acquiredInCellId: cellId,
    status: ItemStatus.active,
    taxonomicClass: taxonomicClass,
    habitats: habitats,
    continents: continents,
    identificationState: identificationState,
    examinationState: examinationState,
  );
}
