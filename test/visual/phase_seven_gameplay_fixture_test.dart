import 'dart:io';

import 'package:earth_nova/app/readiness/app_readiness.dart';
import 'package:earth_nova/core/domain/content/content_version_id.dart';
import 'package:earth_nova/core/domain/content/encounter_content.dart';
import 'package:earth_nova/core/domain/content/exact_version_ref.dart';
import 'package:earth_nova/core/domain/content/stable_content_id.dart';
import 'package:earth_nova/core/domain/entities/habitat.dart';
import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/core/observability/trace_context.dart';
import 'package:earth_nova/features/encounters/domain/entities/encounter_entities.dart';
import 'package:earth_nova/features/encounters/presentation/providers/pending_encounter_provider.dart';
import 'package:earth_nova/ui/product_surfaces/encounters/widgets/pending_encounter_layer.dart';
import 'package:earth_nova/features/living_world/data/dtos/living_world_dto.dart';
import 'package:earth_nova/features/living_world/domain/entities/town_projection.dart';
import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/features/map/domain/entities/cell_state.dart';
import 'package:earth_nova/features/map/domain/entities/encounter.dart';
import 'package:earth_nova/ui/product_surfaces/map/screens/map_screen.dart';
import 'package:earth_nova/ui/product_surfaces/map/widgets/cell_detail_sheet.dart';
import 'package:earth_nova/ui/product_surfaces/map/widgets/discovery_notification.dart';
import 'package:earth_nova/ui/product_surfaces/map/widgets/map_status_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/living_world/data/living_world_test_data.dart';
import 'phase_seven_capture_support.dart';

const _gameplayAssets = <String>[
  'gameplay/cell-shrouded-390x844.png',
  'gameplay/cell-shrouded-1440x900.png',
  'gameplay/cell-informed-390x844.png',
  'gameplay/cell-informed-1440x900.png',
  'gameplay/cell-explored-390x844.png',
  'gameplay/cell-explored-1440x900.png',
  'gameplay/cell-present-venue-390x844.png',
  'gameplay/cell-present-venue-1440x900.png',
  'gameplay/encounter-pending-390x844.png',
  'gameplay/encounter-pending-1440x900.png',
  'gameplay/encounter-resolving-390x844.png',
  'gameplay/encounter-resolving-1440x900.png',
  'gameplay/encounter-failed-retry-390x844.png',
  'gameplay/encounter-failed-retry-1440x900.png',
  'gameplay/encounter-completed-390x844.png',
  'gameplay/encounter-completed-1440x900.png',
  'gameplay/boundary-first-eligible-390x844.png',
  'gameplay/boundary-persistence-queued-390x844.png',
];

void main() {
  group('Phase seven gameplay fixtures', () {
    test('declares only reachable gameplay assets', () {
      expect(_gameplayAssets, hasLength(18));
      expect(_gameplayAssets.toSet(), hasLength(18));
      expect(
        _gameplayAssets,
        equals(const <String>[
          'gameplay/cell-shrouded-390x844.png',
          'gameplay/cell-shrouded-1440x900.png',
          'gameplay/cell-informed-390x844.png',
          'gameplay/cell-informed-1440x900.png',
          'gameplay/cell-explored-390x844.png',
          'gameplay/cell-explored-1440x900.png',
          'gameplay/cell-present-venue-390x844.png',
          'gameplay/cell-present-venue-1440x900.png',
          'gameplay/encounter-pending-390x844.png',
          'gameplay/encounter-pending-1440x900.png',
          'gameplay/encounter-resolving-390x844.png',
          'gameplay/encounter-resolving-1440x900.png',
          'gameplay/encounter-failed-retry-390x844.png',
          'gameplay/encounter-failed-retry-1440x900.png',
          'gameplay/encounter-completed-390x844.png',
          'gameplay/encounter-completed-1440x900.png',
          'gameplay/boundary-first-eligible-390x844.png',
          'gameplay/boundary-persistence-queued-390x844.png',
        ]),
      );
    });

    test('keeps a revisit visually silent', () {
      final mapScreen = File(
        'lib/ui/product_surfaces/map/screens/map_screen.dart',
      ).readAsStringSync();

      expect(
        mapScreen,
        contains(
          'if (isFirstVisit) {\n'
          '        _showDiscoveryNotification(enteredCellId);',
        ),
      );
      expect(
        _gameplayAssets.where((asset) => asset.contains('boundary-revisit')),
        isEmpty,
      );
    });

    for (final viewport in const [
      (size: phaseSevenMobileSize, suffix: '390x844'),
      (size: phaseSevenDesktopSize, suffix: '1440x900'),
    ]) {
      for (final fixture in [
        (
          name: 'cell-shrouded',
          child: _shroudedCell(),
          verify: _verifyShroudedCell,
        ),
        (
          name: 'cell-informed',
          child: _informedCell(),
          verify: _verifyInformedCell,
        ),
        (
          name: 'cell-explored',
          child: _exploredCell(),
          verify: _verifyExploredCell,
        ),
        (
          name: 'cell-present-venue',
          child: _presentCell(),
          verify: _verifyPresentCell,
        ),
      ]) {
        testWidgets(
          'captures gameplay/${fixture.name}-${viewport.suffix}.png',
          (tester) => _captureGameplay(
            tester,
            size: viewport.size,
            name: 'gameplay/${fixture.name}-${viewport.suffix}.png',
            child: fixture.child,
            verify: fixture.verify,
          ),
          skip: !phaseSevenCaptureEnabled,
        );
      }

      for (final fixture in [
        (
          name: 'encounter-pending',
          child: _pendingLayer(PendingEncounterReady(_pendingEncounter())),
          verify: _verifyPendingEncounter,
        ),
        (
          name: 'encounter-resolving',
          child: _pendingLayer(
            PendingEncounterResolving(
              _pendingEncounter(),
              _pendingEncounter().options.first.id,
            ),
          ),
          verify: _verifyResolvingEncounter,
        ),
        (
          name: 'encounter-failed-retry',
          child: _pendingLayer(
            PendingEncounterFailure(
              pendingEncounter: _pendingEncounter(),
              optionId: _pendingEncounter().options.first.id,
            ),
          ),
          verify: _verifyFailedEncounter,
        ),
        (
          name: 'encounter-completed',
          child: buildDiscoveryRewardModalForTesting(
            encounter: _completedEncounter(),
            onContinue: () {},
          ),
          verify: _verifyCompletedEncounter,
        ),
      ]) {
        testWidgets(
          'captures gameplay/${fixture.name}-${viewport.suffix}.png',
          (tester) => _captureGameplay(
            tester,
            size: viewport.size,
            name: 'gameplay/${fixture.name}-${viewport.suffix}.png',
            child: fixture.child,
            verify: fixture.verify,
          ),
          skip: !phaseSevenCaptureEnabled,
        );
      }
    }

    testWidgets(
      'captures gameplay/boundary-first-eligible-390x844.png',
      (tester) => _captureGameplay(
        tester,
        size: phaseSevenMobileSize,
        name: 'gameplay/boundary-first-eligible-390x844.png',
        child: const SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: DiscoveryNotification(cellName: 'cell-B'),
          ),
        ),
        verify: (tester) {
          expect(find.text('New cell'), findsOneWidget);
          expect(find.text('cell-B'), findsOneWidget);
          expect(
            find.bySemanticsLabel('success: New cell. cell-B'),
            findsOneWidget,
          );
        },
      ),
      skip: !phaseSevenCaptureEnabled,
    );

    testWidgets(
      'captures gameplay/boundary-persistence-queued-390x844.png',
      (tester) => _captureGameplay(
        tester,
        size: phaseSevenMobileSize,
        name: 'gameplay/boundary-persistence-queued-390x844.png',
        child: const SafeArea(
          child: MapStatusBar(
            cellsObserved: 4,
            totalSteps: 1200,
            streakDays: 2,
            pendingVisits: 1,
            paddingTop: 0,
          ),
        ),
        verify: (tester) {
          expect(find.text('syncing'), findsOneWidget);
          expect(find.bySemanticsLabel('1 visits syncing'), findsOneWidget);
        },
      ),
      skip: !phaseSevenCaptureEnabled,
    );
  });
}

Future<void> _captureGameplay(
  WidgetTester tester, {
  required Size size,
  required String name,
  required Widget child,
  required void Function(WidgetTester tester) verify,
}) {
  return capturePhaseSevenFixture(
    tester,
    size: size,
    name: name,
    child: Scaffold(body: child),
    prepare: (tester) async => verify(tester),
  );
}

Widget _shroudedCell() => CellDetailSheet(
  cell: _cell(habitats: const [Habitat.forest]),
  visitCount: 4,
  isFirstVisit: true,
  currentRelationship: CellRelationship.unknown,
  knowledgeState: CellKnowledgeState.shrouded,
  knownVenues: [_venue()],
);

Widget _informedCell() => CellDetailSheet(
  cell: _cell(habitats: const [Habitat.forest]),
  visitCount: 4,
  isFirstVisit: true,
  currentRelationship: CellRelationship.frontier,
  knowledgeState: CellKnowledgeState.informed,
  category: 'fauna',
  knownVenues: [_venue()],
);

Widget _exploredCell() => CellDetailSheet(
  cell: _cell(
    habitats: const [Habitat.plains],
    habitatConfidence: 'legacy_unverified',
  ),
  visitCount: 4,
  isFirstVisit: false,
  currentRelationship: CellRelationship.explored,
  knowledgeState: CellKnowledgeState.explored,
);

Widget _presentCell() => CellDetailSheet(
  cell: _cell(habitats: const [Habitat.urban]),
  visitCount: 1,
  isFirstVisit: true,
  currentRelationship: CellRelationship.present,
  knowledgeState: CellKnowledgeState.present,
  knownVenues: [_venue()],
);

void _verifyShroudedCell(WidgetTester tester) {
  expect(find.text('Shrouded'), findsOneWidget);
  expect(find.text('Unrevealed area'), findsOneWidget);
  expect(find.textContaining('Cell v_'), findsNothing);
  expect(find.text('Forest'), findsNothing);
  expect(find.text('Visits'), findsNothing);
  expect(find.text('First discovery!'), findsNothing);
  expect(find.text('Harbor Current'), findsNothing);
}

void _verifyInformedCell(WidgetTester tester) {
  expect(find.text('Informed'), findsOneWidget);
  expect(find.text('Fauna'), findsOneWidget);
  expect(find.textContaining('Cell v_'), findsNothing);
  expect(find.text('Visits'), findsNothing);
  expect(find.text('First discovery!'), findsNothing);
  expect(find.text('Harbor Current'), findsNothing);
  for (final forbidden in [
    'Encounter',
    'Amberwing Warbler',
    'Outcome',
    'Reward',
  ]) {
    expect(find.textContaining(forbidden), findsNothing);
  }
}

void _verifyExploredCell(WidgetTester tester) {
  expect(find.text('Explored'), findsOneWidget);
  expect(find.text('Terrain unclassified'), findsOneWidget);
  expect(find.text('Visits'), findsOneWidget);
  expect(find.text('4 times'), findsOneWidget);
}

void _verifyPresentCell(WidgetTester tester) {
  expect(find.text('Present'), findsOneWidget);
  expect(find.text('Urban'), findsOneWidget);
  expect(find.text('Visits'), findsOneWidget);
  expect(find.text('1 time'), findsOneWidget);
  expect(find.text('Status'), findsOneWidget);
  expect(find.text('First discovery!'), findsOneWidget);
  expect(find.text('Harbor Current'), findsOneWidget);
  expect(find.bySemanticsLabel('Open Harbor Current'), findsOneWidget);
}

Widget _pendingLayer(PendingEncounterState state) {
  final notifier = _StaticPendingEncounterNotifier(state);
  return ProviderScope(
    overrides: [
      appObservabilityProvider.overrideWithValue(
        ObservabilityService(sessionId: 'phase-seven-gameplay'),
      ),
      appReadinessProvider.overrideWith(
        () => _StaticReadinessNotifier(AppReadinessPhase.usable),
      ),
      pendingEncounterProvider.overrideWith(() => notifier),
    ],
    child: const Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: Colors.transparent),
        Positioned.fill(child: PendingEncounterLayer()),
      ],
    ),
  );
}

void _verifyPendingEncounter(WidgetTester tester) {
  final action = find.byKey(const Key('resolve-present-encounter'));
  expect(find.text('Red Fox'), findsOneWidget);
  expect(find.text('Observe quietly'), findsOneWidget);
  expect(action, findsOneWidget);
  expect(
    tester.getSemantics(action),
    matchesSemantics(
      label: 'Pending encounter: Red Fox. Option: Observe quietly.',
      isButton: true,
      hasEnabledState: true,
      isEnabled: true,
      hasTapAction: true,
    ),
  );
}

void _verifyResolvingEncounter(WidgetTester tester) {
  final action = find.byKey(const Key('resolve-present-encounter'));
  expect(action, findsOneWidget);
  expect(find.text('Resolving…'), findsOneWidget);
  expect(
    tester.getSemantics(action),
    matchesSemantics(
      label: 'Resolving pending encounter: Red Fox. Option: Observe quietly.',
      isButton: true,
      hasEnabledState: true,
      isEnabled: false,
      isLiveRegion: true,
      hasTapAction: false,
    ),
  );
}

void _verifyFailedEncounter(WidgetTester tester) {
  final action = find.byKey(const Key('resolve-present-encounter'));
  expect(action, findsOneWidget);
  expect(find.text('Retry'), findsOneWidget);
  expect(
    tester.getSemantics(action),
    matchesSemantics(
      label: 'Pending encounter: Red Fox. Option: Observe quietly.',
      isButton: true,
      hasEnabledState: true,
      isEnabled: true,
      hasTapAction: true,
    ),
  );
}

void _verifyCompletedEncounter(WidgetTester tester) {
  expect(find.byKey(const Key('discovery-reward-modal')), findsOneWidget);
  expect(find.text('Added to Pack'), findsOneWidget);
  expect(
    find.text('Identify this specimen later to reveal the species.'),
    findsOneWidget,
  );
  expect(find.text('Unidentified fauna specimen'), findsOneWidget);
  expect(find.text('Return to Map'), findsOneWidget);
  expect(
    find.bySemanticsLabel(
      'Discovery reward: Unidentified fauna specimen. Added to Pack.',
    ),
    findsOneWidget,
  );
}

Cell _cell({
  required List<Habitat> habitats,
  String habitatConfidence = 'classified',
}) => Cell(
  id: 'v_22982_-33322',
  habitats: habitats,
  polygons: const [],
  districtId: 'district_ca_downtown',
  cityId: 'city_fredericton',
  stateId: 'state_new_brunswick',
  countryId: 'country_canada',
  habitatConfidence: habitatConfidence,
);

TownVenue _venue() => LivingWorldTownDto.fromJson(
  town(withVillager: true),
  playerId: playerId,
).toDomain().venues.single;

PendingEncounter _pendingEncounter() => PendingEncounter(
  cellId: 'cell-red-fox',
  encounter: EncounterOccurrence(
    id: EncounterId('encounter-red-fox'),
    cellVisitId: CellVisitId('visit-red-fox'),
    cellVisitResolutionId: CellVisitResolutionId('resolution-red-fox'),
    definitionVersion: ExactVersionRef<EncounterContent>(
      stableId: StableContentId<EncounterContent>('encounter:red_fox'),
      versionId: ContentVersionId<EncounterContent>('red-fox-r2'),
      revision: 2,
    ),
    status: EncounterResolutionStatus.pending,
    createdAt: DateTime.utc(2026, 8, 16),
  ),
  definitionDisplayName: 'Red Fox',
  options: [
    PendingEncounterOption(
      id: EncounterOptionId('observe-quietly'),
      ordinal: 0,
      displayName: 'Observe quietly',
    ),
  ],
);

Encounter _completedEncounter() => Encounter(
  type: EncounterType.species,
  speciesId: 'red-fox',
  cellId: 'cell-red-fox',
  seed: 'phase-seven-red-fox',
  acquiredItem: Item(
    id: 'item-red-fox',
    displayName: 'Red Fox',
    category: ItemCategory.fauna,
    acquiredAt: DateTime.utc(2026, 8, 16),
    status: ItemStatus.active,
    identificationState: ItemIdentificationState.unidentified,
  ),
);

final class _StaticReadinessNotifier extends AppReadinessNotifier {
  _StaticReadinessNotifier(this.phase);

  final AppReadinessPhase phase;

  @override
  AppReadinessState build() => AppReadinessState(
    phase: phase,
    completedCheckpoints: AppReadinessState.requiredCheckpoints,
  );

  @override
  Future<void> start(String userId) async {}
}

final class _StaticPendingEncounterNotifier extends PendingEncounterNotifier {
  _StaticPendingEncounterNotifier(this.value);

  final PendingEncounterState value;

  @override
  PendingEncounterState build() => value;

  @override
  Future<void> resolve(
    EncounterOptionId optionId, {
    TraceContext? parent,
  }) async {}

  @override
  Future<void> retryResolution({TraceContext? parent}) async {}
}
