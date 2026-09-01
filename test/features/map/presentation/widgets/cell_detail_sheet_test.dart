import 'dart:ui' show SemanticsAction;

import 'package:earth_nova/core/domain/entities/habitat.dart';
import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/living_world/data/dtos/living_world_dto.dart';
import 'package:earth_nova/features/living_world/domain/entities/town_projection.dart';
import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/features/map/domain/entities/cell_state.dart';
import 'package:earth_nova/features/map/presentation/widgets/cell_detail_sheet.dart';
import 'package:earth_nova/shared/design.dart';
import 'package:earth_nova/shared/product/player_actions.dart';
import 'package:earth_nova/shared/product/product_action_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../living_world/data/living_world_test_data.dart';

void main() {
  group('CellDetailSheet neutral composition', () {
    testWidgets('uses the neutral design system for detail and Venue actions', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          CellDetailSheet(
            cell: _cell(habitats: const [Habitat.urban]),
            visitCount: 1,
            isFirstVisit: false,
            currentRelationship: CellRelationship.present,
            knowledgeState: CellKnowledgeState.present,
            knownVenues: [_venue()],
          ),
        ),
      );

      expect(find.byType(AppCard), findsOneWidget);
      expect(find.byType(AppBadge), findsOneWidget);
      expect(find.byType(AppFieldRow), findsNWidgets(2));
      expect(find.byType(AppButton), findsOneWidget);

      final evidence = tester.widget<ProductActionSurface>(
        find.byType(ProductActionSurface),
      );
      expect(evidence.actionId, PlayerActions.openNpcVenueDetail);
    });

    testWidgets(
      'Venue action remains semantic, 44px, and reachable at 200% text',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          _modalHost(
            CellDetailSheet(
              cell: _cell(habitats: const [Habitat.urban]),
              visitCount: 1,
              isFirstVisit: false,
              currentRelationship: CellRelationship.present,
              knowledgeState: CellKnowledgeState.present,
              knownVenues: [_venue()],
            ),
            textScale: 2,
          ),
        );

        await tester.tap(find.byKey(const Key('open-cell-sheet')));
        await tester.pumpAndSettle();

        final action = find.bySemanticsLabel('Open Harbor Current');
        await tester.ensureVisible(action);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(action, findsOneWidget);
        expect(tester.getSize(action).height, greaterThanOrEqualTo(44));
        expect(
          tester
              .getSemantics(action)
              .getSemanticsData()
              .hasAction(SemanticsAction.tap),
          isTrue,
        );
      },
    );
  });

  group('CellDetailSheet habitat display', () {
    testWidgets(
      'does not present single legacy Plains fallback as verified terrain',
      (tester) async {
        await tester.pumpWidget(
          _host(
            CellDetailSheet(
              cell: _cell(
                habitats: const [Habitat.plains],
                habitatConfidence: 'legacy_unverified',
              ),
              visitCount: 1,
              isFirstVisit: false,
              currentRelationship: CellRelationship.explored,
            ),
          ),
        );

        expect(find.text('Terrain unclassified'), findsOneWidget);
        expect(find.text('Plains'), findsNothing);
      },
    );

    testWidgets(
      'shows classified plains when provenance verifies the terrain',
      (tester) async {
        await tester.pumpWidget(
          _host(
            CellDetailSheet(
              cell: _cell(
                habitats: const [Habitat.plains],
                habitatConfidence: 'classified',
              ),
              visitCount: 1,
              isFirstVisit: false,
              currentRelationship: CellRelationship.explored,
            ),
          ),
        );

        expect(find.text('Plains'), findsOneWidget);
        expect(find.text('Terrain unclassified'), findsNothing);
      },
    );

    testWidgets(
      'shows urban when backend classification normalizes built-up terrain',
      (tester) async {
        await tester.pumpWidget(
          _host(
            CellDetailSheet(
              cell: _cell(
                habitats: const [Habitat.urban],
                habitatConfidence: 'classified',
              ),
              visitCount: 1,
              isFirstVisit: false,
              currentRelationship: CellRelationship.present,
            ),
          ),
        );

        expect(find.text('Urban'), findsOneWidget);
      },
    );

    testWidgets('preserves specific multi-habitat labels when available', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          CellDetailSheet(
            cell: _cell(habitats: const [Habitat.forest, Habitat.freshwater]),
            visitCount: 2,
            isFirstVisit: false,
            currentRelationship: CellRelationship.explored,
          ),
        ),
      );

      expect(find.text('Forest / Freshwater'), findsOneWidget);
    });
  });

  group('CellDetailSheet canonical knowledge disclosure', () {
    testWidgets('Shrouded is generic and exposes no Cell detail', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          CellDetailSheet(
            cell: _cell(habitats: const [Habitat.forest]),
            visitCount: 4,
            isFirstVisit: true,
            currentRelationship: CellRelationship.unknown,
            knowledgeState: CellKnowledgeState.shrouded,
            knownVenues: [_venue()],
          ),
        ),
      );

      expect(find.text('Shrouded'), findsOneWidget);
      expect(find.text('Unrevealed area'), findsOneWidget);
      expect(find.textContaining('Cell v_'), findsNothing);
      expect(find.text('Forest'), findsNothing);
      expect(find.text('Visits'), findsNothing);
      expect(find.text('First discovery!'), findsNothing);
      expect(find.text('Harbor Current'), findsNothing);
    });

    testWidgets('Informed discloses exactly one category label', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          CellDetailSheet(
            cell: _cell(habitats: const [Habitat.forest]),
            visitCount: 4,
            isFirstVisit: true,
            currentRelationship: CellRelationship.frontier,
            knowledgeState: CellKnowledgeState.informed,
            category: 'fauna',
            knownVenues: [_venue()],
          ),
        ),
      );

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
    });

    testWidgets('Informed without a category falls back to Shrouded', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          CellDetailSheet(
            cell: _cell(habitats: const [Habitat.forest]),
            visitCount: 4,
            isFirstVisit: true,
            currentRelationship: CellRelationship.frontier,
            knowledgeState: CellKnowledgeState.informed,
            category: '',
          ),
        ),
      );

      expect(find.text('Shrouded'), findsOneWidget);
      expect(find.text('Unrevealed area'), findsOneWidget);
      expect(find.text('Informed'), findsNothing);
      expect(find.text('Forest'), findsNothing);
    });

    testWidgets('Explored keeps known visit and terrain provenance context', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          CellDetailSheet(
            cell: _cell(
              habitats: const [Habitat.plains],
              habitatConfidence: 'legacy_unverified',
            ),
            visitCount: 4,
            isFirstVisit: false,
            currentRelationship: CellRelationship.explored,
            knowledgeState: CellKnowledgeState.explored,
          ),
        ),
      );

      expect(find.text('Explored'), findsOneWidget);
      expect(find.text('Terrain unclassified'), findsOneWidget);
      expect(find.text('Visits'), findsOneWidget);
      expect(find.text('4 times'), findsOneWidget);
    });

    testWidgets('Present keeps first-visit and eligible Venue context', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          CellDetailSheet(
            cell: _cell(habitats: const [Habitat.urban]),
            visitCount: 1,
            isFirstVisit: true,
            currentRelationship: CellRelationship.present,
            knowledgeState: CellKnowledgeState.present,
            knownVenues: [_venue()],
          ),
        ),
      );

      expect(find.text('Present'), findsOneWidget);
      expect(find.text('Urban'), findsOneWidget);
      expect(find.text('Visits'), findsOneWidget);
      expect(find.text('1 time'), findsOneWidget);
      expect(find.text('Status'), findsOneWidget);
      expect(find.text('First discovery!'), findsOneWidget);
      expect(find.text('Harbor Current'), findsOneWidget);
    });
  });

  testWidgets('Venue action dismisses the sheet and opens the Venue route', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appObservabilityProvider.overrideWithValue(
            ObservabilityService(sessionId: 'test-session'),
          ),
        ],
        child: _modalHost(
          CellDetailSheet(
            cell: _cell(habitats: const [Habitat.urban]),
            visitCount: 1,
            isFirstVisit: false,
            currentRelationship: CellRelationship.present,
            knowledgeState: CellKnowledgeState.present,
            knownVenues: [_venue()],
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open-cell-sheet')));
    await tester.pumpAndSettle();

    expect(find.text('Harbor Current'), findsOneWidget);
    expect(
      find.text('1 Villager  •  1 Service  •  Opening soon'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Harbor Current'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Harbor Current'));
    await tester.pumpAndSettle();

    expect(find.byType(CellDetailSheet), findsNothing);
    expect(find.byTooltip('Back'), findsOneWidget);
    expect(find.text('Villagers and Services'), findsOneWidget);
    expect(find.text('Repairs'), findsOneWidget);
    expect(find.text('OPENING SOON'), findsOneWidget);
    expect(find.textContaining('NPC'), findsNothing);
  });
}

Widget _host(Widget child, {double textScale = 1}) => ShadApp(
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(body: child),
    ),
  ),
);

Widget _modalHost(CellDetailSheet sheet, {double textScale = 1}) => ShadApp(
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(
        body: Center(
          child: AppButton(
            key: const Key('open-cell-sheet'),
            label: 'Inspect cell',
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              backgroundColor: Colors.transparent,
              builder: (_) => sheet,
            ),
          ),
        ),
      ),
    ),
  ),
);

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

TownVenue _venue() {
  return LivingWorldTownDto.fromJson(
    town(withVillager: true),
    playerId: playerId,
  ).toDomain().venues.single;
}
