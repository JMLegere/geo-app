import 'dart:math' as math;
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:earth_nova/core/domain/entities/habitat.dart';
import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/features/map/domain/entities/cell_state.dart';
import 'package:earth_nova/features/map/domain/entities/encounter.dart';
import 'package:earth_nova/features/map/presentation/widgets/cell_detail_sheet.dart';
import 'package:earth_nova/features/map/presentation/painters/cell_overlay_painter.dart';
import 'package:earth_nova/features/map/presentation/painters/fog_renderer.dart';
import 'package:earth_nova/features/map/presentation/screens/map_screen.dart';
import 'package:earth_nova/features/map/presentation/widgets/discovery_notification.dart';
import 'package:earth_nova/features/map/presentation/widgets/map_status_bar.dart';
import 'package:earth_nova/features/map/presentation/widgets/shimmer_cells.dart';

// ---------------------------------------------------------------------------
// Helpers that mirror the fixed screen logic (without importing Flutter UI).
// These tests confirm the math is correct independent of the widget build.
// ---------------------------------------------------------------------------

/// Mirrors MapScreen's marker/tap projection path by delegating to the same
/// Web Mercator projector used by CellOverlayPainter.
({double dx, double dy}) latLngToScreenDelta({
  required double coordLat,
  required double coordLng,
  required double cameraLat,
  required double cameraLng,
  required double zoom,
}) {
  final projected = CellOverlayPainter.projectGeoCoord(
    coord: (lat: coordLat, lng: coordLng),
    cameraPosition: (lat: cameraLat, lng: cameraLng),
    zoom: zoom,
    cameraPixelOffset: Offset.zero,
  );
  return (dx: projected.dx, dy: projected.dy);
}

void main() {
  group('MapScreen projection math', () {
    test('same position produces zero offset', () {
      final delta = latLngToScreenDelta(
        coordLat: 37.7749,
        coordLng: -122.4194,
        cameraLat: 37.7749,
        cameraLng: -122.4194,
        zoom: 15,
      );
      expect(delta.dx, closeTo(0.0, 1e-9));
      expect(delta.dy, closeTo(0.0, 1e-9));
    });

    test('one degree longitude uses MapLibre 512px world scale', () {
      final delta = latLngToScreenDelta(
        coordLat: 0.0,
        coordLng: 1.0,
        cameraLat: 0.0,
        cameraLng: 0.0,
        zoom: 15,
      );

      // MapLibre GL uses a 512px world tile scale:
      // 512 * 2^15 / 360 ≈ 46,603 px per degree.
      expect(delta.dx, greaterThan(46000));
      expect(delta.dx, lessThan(47000));
      expect(delta.dy, closeTo(0.0, 1e-9));
    });

    test('old degrees-times-meters-per-pixel formula would flatten offsets', () {
      const earthCircumference = 156543.03392;
      final metersPerPixel = earthCircumference / math.pow(2, 15);
      final buggyDelta = 1.0 * metersPerPixel;

      expect(
        buggyDelta,
        lessThan(10),
        reason:
            'A one-degree offset cannot project to single-digit pixels at GPS zoom.',
      );
    });

    test('point 1 degree north of camera is projected far above center', () {
      final delta = latLngToScreenDelta(
        coordLat: 1.0,
        coordLng: 0.0,
        cameraLat: 0.0,
        cameraLng: 0.0,
        zoom: 15,
      );

      // North is negative y in Web Mercator screen coordinates.
      expect(delta.dy, lessThan(-46000));
      expect(delta.dy, greaterThan(-47000));
      expect(delta.dx, closeTo(0.0, 1e-9));
    });
  });

  group('MapScreen widgets', () {
    test('CellDetailSheet constructs with valid cell', () {
      final cell = Cell(
        id: 'test-cell-123',
        habitats: [Habitat.forest, Habitat.mountain],
        polygons: [
          [
            [(lat: 37.7749, lng: -122.4194)],
          ],
        ],
        districtId: 'd1',
        cityId: 'c1',
        stateId: 's1',
        countryId: 'co1',
      );

      final sheet = CellDetailSheet(
        cell: cell,
        visitCount: 3,
        isFirstVisit: false,
        currentRelationship: CellRelationship.explored,
      );

      expect(sheet, isNotNull);
      expect(cell.habitats.length, 2);
    });

    testWidgets('CellDetailSheet shows current cell state', (tester) async {
      final cell = Cell(
        id: 'test-cell-frontier',
        habitats: [Habitat.freshwater],
        polygons: [
          [
            [(lat: 45.0, lng: -66.0)],
          ],
        ],
        districtId: 'd1',
        cityId: 'c1',
        stateId: 's1',
        countryId: 'co1',
      );

      await tester.pumpWidget(
        ShadApp(
          home: Scaffold(
            body: CellDetailSheet(
              cell: cell,
              visitCount: 0,
              isFirstVisit: true,
              currentRelationship: CellRelationship.frontier,
            ),
          ),
        ),
      );

      expect(find.text('Cell state'), findsOneWidget);
      expect(find.text('Frontier'), findsOneWidget);
    });

    test('ShimmerCells is a StatefulWidget', () {
      final shimmer = ShimmerCells(
        cameraPosition: (lat: 37.7749, lng: -122.4194),
        zoom: 15.0,
      );
      expect(shimmer, isA<ShimmerCells>());
    });
  });

  group('MapStatusBar', () {
    test('constructs with required stat values', () {
      const bar = MapStatusBar(
        cellsObserved: 247,
        totalSteps: 15200,
        streakDays: 4,
      );
      expect(bar, isNotNull);
      expect(bar.cellsObserved, 247);
      expect(bar.totalSteps, 15200);
      expect(bar.streakDays, 4);
    });

    test('can expose subtle pending visit sync state', () {
      const bar = MapStatusBar(
        cellsObserved: 3,
        totalSteps: 0,
        streakDays: 0,
        pendingVisits: 2,
      );

      expect(bar.pendingVisits, 2);
    });

    test('constructs with zero values', () {
      const bar = MapStatusBar(cellsObserved: 0, totalSteps: 0, streakDays: 0);
      expect(bar, isNotNull);
      expect(bar.cellsObserved, 0);
    });

    test('is a StatelessWidget', () {
      const bar = MapStatusBar(
        cellsObserved: 10,
        totalSteps: 500,
        streakDays: 1,
      );
      expect(bar, isA<MapStatusBar>());
    });
  });

  group('DiscoveryNotification', () {
    test('constructs with cell name', () {
      const notification = DiscoveryNotification(cellName: 'Forest Cell');
      expect(notification, isNotNull);
      expect(notification.cellName, 'Forest Cell');
    });

    test('constructs with empty cell name', () {
      const notification = DiscoveryNotification(cellName: '');
      expect(notification, isNotNull);
    });

    testWidgets(
      'labels first-visit map cell feedback without claiming Discovery',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          const ShadApp(
            home: Scaffold(
              body: DiscoveryNotification(cellName: 'v_22995_-33325'),
            ),
          ),
        );

        expect(find.text('New cell'), findsOneWidget);
        expect(find.text('NEW DISCOVERY'), findsNothing);
        expect(
          find.bySemanticsLabel('success: New cell. v_22995_-33325'),
          findsOneWidget,
        );
        semantics.dispose();
      },
    );

    test('is a StatelessWidget', () {
      const notification = DiscoveryNotification(cellName: 'Test Cell');
      expect(notification, isA<DiscoveryNotification>());
    });
  });

  group('Tileset URL verification', () {
    test(
      'uses a repo-owned raster basemap style on web and keeps native OpenFreeMap style elsewhere',
      () {
        final mapSource = File(
          'lib/features/map/presentation/screens/map_screen.dart',
        ).readAsStringSync();
        final styleFile = File('web/base-map-style.json');

        expect(
          mapSource,
          contains("const _kWebMapStyleUrl = 'base-map-style.json'"),
        );
        expect(
          mapSource,
          contains(
            "const _kNativeMapStyleUrl = 'https://tiles.openfreemap.org/styles/liberty'",
          ),
        );
        expect(
          mapSource,
          matches(
            RegExp(
              r'styleString:\s*kIsWeb\s*\?\s*_kWebMapStyleUrl\s*:\s*_kNativeMapStyleUrl',
            ),
          ),
          reason:
              'Web should use the repo-owned browser-safe raster style while native builds keep the existing vector style.',
        );
        expect(styleFile.existsSync(), isTrue);
        final styleJson = styleFile.readAsStringSync();
        expect(styleJson, contains('"type": "raster"'));
        expect(styleJson, contains('"glyphs"'));
        expect(styleJson, contains('light_nolabels'));
        expect(
          styleJson,
          isNot(contains('"url": "https://tiles.openfreemap.org/planet"')),
        );
      },
    );
  });

  test('Desktop Mode leaves native map pointer gestures available', () {
    final source = File(
      'lib/features/map/presentation/screens/map_screen.dart',
    ).readAsStringSync();

    expect(source, contains('scrollGesturesEnabled: desktopTraversalEnabled'));
    expect(source, contains('zoomGesturesEnabled: desktopTraversalEnabled'));
    expect(source, contains('dragEnabled: desktopTraversalEnabled'));
    expect(source, contains('onMapClick: desktopTraversalEnabled'));
    expect(source, contains('ignoring: desktopTraversalEnabled'));
  });

  group('MapScreen canonical Cell knowledge chrome', () {
    testWidgets('legend exposes exactly the four canonical labels and keys', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ShadApp(home: Scaffold(body: MapCellKnowledgeLegend())),
      );

      expect(
        find.byKey(const ValueKey('map-cell-knowledge-legend')),
        findsOneWidget,
      );
      for (final state in ['shrouded', 'informed', 'explored', 'present']) {
        expect(find.byKey(ValueKey('cell-knowledge-$state')), findsOneWidget);
      }
      expect(find.text('Shrouded'), findsOneWidget);
      expect(find.text('Informed'), findsOneWidget);
      expect(find.text('Explored'), findsOneWidget);
      expect(find.text('Present'), findsOneWidget);
      expect(find.text('Frontier'), findsNothing);
      expect(find.text('Unknown'), findsNothing);
    });

    testWidgets('legend layers semantic fills over one neutral map substrate', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ShadApp(home: Scaffold(body: MapCellKnowledgeLegend())),
      );
      final colorScheme = Theme.of(
        tester.element(find.byType(MapCellKnowledgeLegend)),
      ).colorScheme;
      const states = [
        CellState(
          knowledgeState: CellKnowledgeState.shrouded,
          relationship: CellRelationship.unknown,
          contents: CellContents.empty,
        ),
        CellState(
          knowledgeState: CellKnowledgeState.informed,
          category: 'category',
          relationship: CellRelationship.explored,
          contents: CellContents.empty,
        ),
        CellState(
          knowledgeState: CellKnowledgeState.explored,
          relationship: CellRelationship.explored,
          contents: CellContents.empty,
        ),
        CellState(
          knowledgeState: CellKnowledgeState.present,
          relationship: CellRelationship.present,
          contents: CellContents.empty,
        ),
      ];

      for (final state in states) {
        final name = state.knowledgeState.name;
        final substrate = tester.widget<Container>(
          find.byKey(ValueKey('cell-knowledge-$name-map-substrate')),
        );
        final swatch = tester.widget<DecoratedBox>(
          find.byKey(ValueKey('cell-knowledge-$name-swatch')),
        );
        expect(
          (substrate.decoration! as BoxDecoration).color,
          colorScheme.surfaceContainerHighest,
        );
        expect(
          (swatch.decoration as BoxDecoration).color,
          FogRenderer.fillColor(state),
        );
      }
    });

    testWidgets('legend exposes category and player shape cues', (
      tester,
    ) async {
      final semanticsHandle = tester.ensureSemantics();

      await tester.pumpWidget(
        const ShadApp(home: Scaffold(body: MapCellKnowledgeLegend())),
      );
      final legendSemantics = tester.widget<Semantics>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'Cell knowledge',
        ),
      );
      expect(legendSemantics.explicitChildNodes, isTrue);

      final informedItem = find.byKey(
        const ValueKey('cell-knowledge-informed'),
      );
      final categoryCue = find.descendant(
        of: informedItem,
        matching: find.byKey(
          const ValueKey('cell-knowledge-informed-category-cue'),
        ),
      );
      expect(categoryCue, findsOneWidget);
      expect(tester.widget<Icon>(categoryCue).icon, Icons.category);
      expect(
        find.bySemanticsLabel('Informed Cell, category known'),
        findsOneWidget,
      );

      final presentItem = find.byKey(const ValueKey('cell-knowledge-present'));
      final playerMarker = find.descendant(
        of: presentItem,
        matching: find.byKey(
          const ValueKey('cell-knowledge-present-player-marker'),
        ),
      );
      final playerDot = find.descendant(
        of: playerMarker,
        matching: find.byKey(
          const ValueKey('cell-knowledge-present-player-dot'),
        ),
      );
      expect(playerMarker, findsOneWidget);
      expect(playerDot, findsOneWidget);

      final markerDecoration =
          tester.widget<Container>(playerMarker).decoration! as BoxDecoration;
      final markerBorder = markerDecoration.border! as Border;
      final dotDecoration =
          tester.widget<Container>(playerDot).decoration! as BoxDecoration;
      final colorScheme = Theme.of(tester.element(playerMarker)).colorScheme;
      expect(markerDecoration.shape, BoxShape.circle);
      expect(markerDecoration.color, colorScheme.onSurface);
      expect(markerBorder.top.color, colorScheme.surface);
      expect(dotDecoration.shape, BoxShape.circle);
      expect(dotDecoration.color, colorScheme.surface);
      expect(
        find.bySemanticsLabel('Present Cell, player here'),
        findsOneWidget,
      );

      semanticsHandle.dispose();
    });

    testWidgets('paused banner is a live semantic status', (tester) async {
      final semanticsHandle = tester.ensureSemantics();

      await tester.pumpWidget(
        const ShadApp(home: Scaffold(body: DiscoveryPausedBanner())),
      );

      final status = tester.getSemantics(
        find.byKey(const ValueKey('discovery-paused-status')),
      );
      expect(status.label, 'Discovery paused');
      expect(status.flagsCollection.isLiveRegion, isTrue);
      expect(find.text('Discovery paused'), findsOneWidget);
      semanticsHandle.dispose();
    });
  });

  group('MapScreen neutral Phase 3 chrome', () {
    test('uses neutral composition without legacy reward or glow styling', () {
      final mapSource = File(
        'lib/features/map/presentation/screens/map_screen.dart',
      ).readAsStringSync();
      final statusSource = File(
        'lib/features/map/presentation/widgets/map_status_bar.dart',
      ).readAsStringSync();
      final notificationSource = File(
        'lib/features/map/presentation/widgets/discovery_notification.dart',
      ).readAsStringSync();

      for (final source in [mapSource, statusSource, notificationSource]) {
        expect(source, isNot(contains('AppTheme.')));
        expect(source, isNot(matches(RegExp(r'\bEarth[A-Z]'))));
        expect(source, isNot(contains('BackdropFilter(')));
        expect(source, isNot(contains('BoxShadow(')));
        expect(source, isNot(contains('LinearGradient(')));
      }
      expect(mapSource, isNot(contains('rarity.toUpperCase()')));
      expect(mapSource, isNot(contains('FilledButton(')));
      expect(mapSource, contains('AppCard('));
      expect(mapSource, contains('AppButton('));
      expect(mapSource, contains('AppNotice('));
      expect(statusSource, contains('ShadCard('));
      expect(notificationSource, contains('AppNotice('));
    });

    test('keeps every reward action target at least 44 logical pixels', () {
      final buttonSource = File(
        'lib/shared/design/primitives/app_button.dart',
      ).readAsStringSync();

      expect(buttonSource, contains('height: 44'));
    });

    test(
      'keeps reward continuation, stable key, and queue ownership boundary',
      () {
        final mapSource = File(
          'lib/features/map/presentation/screens/map_screen.dart',
        ).readAsStringSync();

        expect(mapSource, contains("key: const Key('discovery-reward-modal')"));
        expect(mapSource, contains("actionType: 'continue_discovery_reward'"));
        expect(
          mapSource,
          contains('playerActionId: PlayerActions.continueDiscoveryReward'),
        );
        expect(mapSource, contains('.continueDiscoveryReward();'));
        expect(mapSource, contains('encounterState.currentEncounter'));
        expect(
          mapSource,
          isNot(contains('encounterState.queuedRewards')),
          reason: 'Reward plurality and sequencing remain provider-owned.',
        );
      },
    );

    test('pins live error, paused, and map-readiness semantics', () {
      final mapSource = File(
        'lib/features/map/presentation/screens/map_screen.dart',
      ).readAsStringSync();

      expect(mapSource, contains("ValueKey('discovery-paused-status')"));
      expect(mapSource, contains("ValueKey('map-readiness-cover')"));
      expect(mapSource, contains('liveRegion: true'));
      expect(mapSource, contains('AppNoticeTone.error'));
      expect(mapSource, contains("'Revealing map...'"));
    });

    test('stacks status safely and hides the legend on hard Map errors', () {
      final mapSource = File(
        'lib/features/map/presentation/screens/map_screen.dart',
      ).readAsStringSync();

      expect(
        mapSource,
        matches(RegExp(r'MapStatusBar\([\s\S]*?DiscoveryPausedBanner\(\)')),
      );
      expect(
        mapSource,
        isNot(
          matches(
            RegExp(
              r'if \(explorationEligibility\.isPaused\)[\s\S]{0,80}Positioned\(',
            ),
          ),
        ),
      );
      expect(mapSource, contains('if (mapState is! MapStateError)'));
      expect(
        RegExp(r'right: Spacing\.giant').allMatches(mapSource).length,
        2,
        reason: 'Discovery and paused notices reserve the Map control inset.',
      );
      expect(
        mapSource,
        matches(
          RegExp(
            r'if \(mapState is MapStateError\)[\s\S]*?AppCard\([\s\S]*?AppNotice\(',
          ),
        ),
      );
      expect(
        mapSource,
        matches(
          RegExp(
            r'class DiscoveryPausedBanner[\s\S]*?AppCard\([\s\S]*?AppNotice\(',
          ),
        ),
      );
    });

    test('keeps status errors scrollable and reward feedback modal', () {
      final mapSource = File(
        'lib/features/map/presentation/screens/map_screen.dart',
      ).readAsStringSync();

      expect(
        mapSource,
        matches(
          RegExp(
            r'class _MapStatusScaffold[\s\S]*?SafeArea\([\s\S]*?SingleChildScrollView\(',
          ),
        ),
      );
      expect(mapSource, contains('BlockSemantics('));
      expect(mapSource, contains('scopesRoute: true'));
      expect(mapSource, contains('namesRoute: true'));
      expect(mapSource, matches(RegExp(r'Focus\(\s*autofocus: true')));
      expect(
        mapSource,
        contains(
          'const SingleActivator(LogicalKeyboardKey.escape): onContinue',
        ),
      );
      expect(mapSource, contains('explicitChildNodes: true'));
    });

    testWidgets(
      'reward modal exposes live content without semantics assertions',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          ShadApp(
            home: Scaffold(
              body: buildDiscoveryRewardModalForTesting(
                encounter: const Encounter(
                  type: EncounterType.species,
                  speciesId: 'species-1',
                  displayName: 'Unknown Discovery',
                  cellId: 'cell-1',
                  seed: 'seed-1',
                ),
                onContinue: () {},
              ),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.text('Added to Pack'), findsOneWidget);
        expect(find.text('Unidentified fauna specimen'), findsOneWidget);
        expect(find.text('Return to Map'), findsOneWidget);
        expect(
          find.bySemanticsLabel(
            'Discovery reward: Unidentified fauna specimen. Added to Pack.',
          ),
          findsOneWidget,
        );
        expect(tester.binding.focusManager.primaryFocus, isNotNull);
        semantics.dispose();
      },
    );
  });

  group('MapScreen encounter boundary', () {
    test(
      'does not trigger encounters from optimistic exploration while retaining first-discovery notification',
      () {
        final mapSource = File(
          'lib/features/map/presentation/screens/map_screen.dart',
        ).readAsStringSync();

        expect(
          mapSource,
          isNot(contains('onCellEntered(')),
          reason:
              'Encounter entry is invoked only after RecordCellVisit returns the exact CellVisit.',
        );
        expect(
          mapSource,
          contains('ref.listen<ExplorationStateData>(explorationProvider'),
          reason: 'The screen still reacts to entry state for non-mutating UI.',
        );
        expect(
          mapSource,
          contains('_showDiscoveryNotification(enteredCellId)'),
          reason:
              'First-visit discovery feedback remains owned by the Map screen.',
        );
        expect(mapSource, contains("'map.discovery_notification_shown'"));
      },
    );

    test(
      'does not record Venue Visits from UI, map taps, or location events',
      () {
        final mapSource = File(
          'lib/features/map/presentation/screens/map_screen.dart',
        ).readAsStringSync();
        final locationSource = File(
          'lib/features/map/presentation/providers/location_provider.dart',
        ).readAsStringSync();
        final cellSheetSource = File(
          'lib/features/map/presentation/widgets/cell_detail_sheet.dart',
        ).readAsStringSync();
        final townSource = File(
          'lib/features/living_world/presentation/screens/town_screen.dart',
        ).readAsStringSync();

        expect(mapSource, isNot(contains('recordVenueVisit')));
        expect(locationSource, isNot(contains('recordVenueVisit')));
        expect(cellSheetSource, isNot(contains('recordVenueVisit')));
        expect(townSource, isNot(contains('recordVenueVisit')));
      },
    );
  });

  group('Startup/recovery — no blank screen', () {
    test('LoadingDots is used for GPS loading state (not blank scaffold)', () {
      final mapSource = File(
        'lib/features/map/presentation/screens/map_screen.dart',
      ).readAsStringSync();

      expect(
        mapSource,
        contains('LocationProviderLoading() => const _MapLoadingScaffold()'),
      );
      expect(mapSource, contains("label: 'Finding your location'"));
      expect(mapSource, contains('child: LoadingDots()'));
    });

    test('MapStatusBar padding-top accounts for system status bar (44px)', () {
      const bar = MapStatusBar(
        cellsObserved: 10,
        totalSteps: 500,
        streakDays: 1,
      );
      // The status bar must have paddingTop >= 44 to clear the iOS status bar.
      expect(bar.paddingTop, greaterThanOrEqualTo(44.0));
    });

    test('map and root screen are wrapped with ObservableScreen', () {
      final mapSource = File(
        'lib/features/map/presentation/screens/map_screen.dart',
      ).readAsStringSync();
      final rootSource = File(
        'lib/features/map/presentation/screens/map_root_screen.dart',
      ).readAsStringSync();

      expect(mapSource, contains('ObservableScreen('));
      expect(rootSource, contains('ObservableScreen('));
    });

    test('cell overlay gesture detector is not blocked by IgnorePointer', () {
      final mapSource = File(
        'lib/features/map/presentation/screens/map_screen.dart',
      ).readAsStringSync();

      expect(
        mapSource,
        isNot(
          contains('IgnorePointer(\\n                child: GestureDetector'),
        ),
        reason:
            'Cell overlay taps must reach the GestureDetector so cell details open.',
      );
    });

    test('uses one app-owned gameplay marker and disables native map puck', () {
      final mapSource = File(
        'lib/features/map/presentation/screens/map_screen.dart',
      ).readAsStringSync();

      expect(mapSource, contains('myLocationEnabled: false'));
      expect(
        mapSource,
        matches(
          RegExp(
            r'myLocationTrackingMode:\s*maplibre\.MyLocationTrackingMode\.none',
          ),
        ),
      );
      expect(RegExp(r'\bPlayerMarker\(').allMatches(mapSource), hasLength(1));
      expect(mapSource, contains('trust: markerTrust'));
      expect(
        mapSource,
        contains('final markerShowsRing = playerMarkerShowsRing('),
      );
      expect(mapSource, contains('markerShowsRing: markerShowsRing'));
      expect(
        mapSource,
        contains('markerState: ref.read(playerMarkerProvider)'),
      );
      expect(
        mapSource,
        contains('explorationEligibility: explorationEligibility'),
      );
      expect(mapSource, isNot(contains('playerMarkerProvider.notifier')));
      expect(mapSource, isNot(contains('_PlayerMarkerPainter')));
    });

    test('uses smoothed camera follow instead of raw GPS camera snaps', () {
      final mapSource = File(
        'lib/features/map/presentation/screens/map_screen.dart',
      ).readAsStringSync();

      expect(mapSource, contains('ref.watch(cameraFollowProvider)'));
      expect(mapSource, contains('ref.listen(cameraFollowProvider'));
      expect(
        mapSource,
        isNot(contains('ref.listen<LocationProviderState>(locationProvider')),
        reason:
            'Camera movement should follow the fast smoothed camera state, not every raw GPS update.',
      );
    });

    test('uses map layout constraints for overlay projection math', () {
      final mapSource = File(
        'lib/features/map/presentation/screens/map_screen.dart',
      ).readAsStringSync();

      expect(mapSource, contains('body: LayoutBuilder('));
      expect(mapSource, contains('final mapSize = constraints.biggest'));
      expect(
        mapSource,
        isNot(contains('MediaQuery.of(context).size')),
        reason:
            'Map overlay math must use actual map body constraints, not full viewport.',
      );
    });

    test('marker, tap hit testing, and cells share one projection source', () {
      final mapSource = File(
        'lib/features/map/presentation/screens/map_screen.dart',
      ).readAsStringSync();

      expect(
        mapSource,
        contains('_projectGeoCoordToScreen('),
        reason:
            'Marker placement, cell tap hit testing, and rendered polygons must share one projection helper.',
      );
      expect(
        mapSource,
        contains('_exactScreenProjectionProjector('),
        reason:
            'Map overlays should use MapLibre-provided screen coordinates when available.',
      );
      expect(
        mapSource,
        contains('_fallbackProjectGeoCoordToScreen('),
        reason:
            'A synchronous fallback keeps the map usable before exact projection is ready.',
      );
      expect(
        mapSource,
        isNot(contains('_latLngToScreen(')),
        reason:
            'The old degree delta approximation flattens GPS offsets and drifts from rendered cells.',
      );
    });

    test('keeps MapLibre attribution away from status and bottom overlays', () {
      final mapSource = File(
        'lib/features/map/presentation/screens/map_screen.dart',
      ).readAsStringSync();

      expect(mapSource, contains('attributionButtonPosition:'));
      expect(
        mapSource,
        contains('maplibre.AttributionButtonPosition.topRight'),
      );
      expect(
        mapSource,
        contains('attributionButtonMargins: const math.Point(12, 144)'),
      );
    });

    test('renders known Town Venues as anchored compact glyph cues', () {
      final mapSource = File(
        'lib/features/map/presentation/screens/map_screen.dart',
      ).readAsStringSync();
      final compactMapSource = mapSource.replaceAll(RegExp(r'\s+'), ' ');

      expect(mapSource, contains('TownProjection? town'));
      expect(
        mapSource,
        contains(
          'final venueAnchors = _knownVenueAnchors(town, cellsWithStates)',
        ),
      );
      expect(mapSource, contains('venue.venue.anchorCellId'));
      expect(mapSource, contains('final position = _cellCenter(entry.cell)'));
      expect(mapSource, contains('VenueMarkerDisplayMode.compactLabel'));
      expect(mapSource, contains('VenueMarkerDisplayMode.glyphOnly'));
      expect(
        mapSource,
        contains('knownVenues: switch (cellState.knowledgeState)'),
      );
      expect(
        compactMapSource,
        contains(
          'CellKnowledgeState.explored || CellKnowledgeState.present => knownVenues',
        ),
      );
      expect(
        compactMapSource,
        contains(
          'CellKnowledgeState.informed || CellKnowledgeState.shrouded => const []',
        ),
      );
      expect(
        mapSource,
        contains('left: projectGeoCoord(venueAnchor.position).dx - 16'),
      );
      expect(
        mapSource,
        contains('top: projectGeoCoord(venueAnchor.position).dy - 16'),
      );
      expect(mapSource, isNot(contains('npcVenueProvider')));
      expect(
        mapSource,
        isNot(contains('discoverWildlifeRehabilitationCenter')),
      );
    });

    test('keeps the Map edge-to-edge without a legacy fog feather', () {
      final mapSource = File(
        'lib/features/map/presentation/screens/map_screen.dart',
      ).readAsStringSync();

      expect(mapSource, isNot(contains('_MapTopFogFeather(')));
      expect(mapSource, isNot(contains('LinearGradient(')));
    });

    test('gates visible board until map reaches steady state', () {
      final mapSource = File(
        'lib/features/map/presentation/screens/map_screen.dart',
      ).readAsStringSync();

      expect(mapSource, contains('ref.watch(mapReadinessProvider)'));
      expect(mapSource, contains('onMapIdle:'));
      expect(mapSource, contains('_MapSteadyStateLoadingOverlay('));
      expect(mapSource, contains('map.steady_state_ready'));
      expect(mapSource, contains('map.readiness_waiting'));
      expect(mapSource, contains('TelemetryFlowPhase.waitingOn'));
      expect(mapSource, contains('TelemetryFlowPhase.dependencyReady'));
      expect(mapSource, contains('map.overlay_frame_painted'));
      expect(mapSource, contains('map.bootstrap.cancelled'));
      expect(mapSource, contains('MapRenderDiagnosticsService'));
      expect(mapSource, contains('map.geometry_rendered'));
      expect(mapSource, contains('renderDiagnostics: renderDiagnostics'));
    });

    test('defers initial readiness mutations until after widget build', () {
      final mapSource = File(
        'lib/features/map/presentation/screens/map_screen.dart',
      ).readAsStringSync();

      expect(mapSource, contains('_scheduleInitialMapReadiness();'));
      expect(
        mapSource,
        contains('WidgetsBinding.instance.addPostFrameCallback'),
      );
      expect(mapSource, isNot(contains('fireImmediately: true')));
    });

    test('terminates map bootstrap if steady state never completes', () {
      final mapSource = File(
        'lib/features/map/presentation/screens/map_screen.dart',
      ).readAsStringSync();
      final readinessSource = File(
        'lib/features/map/presentation/providers/map_readiness_provider.dart',
      ).readAsStringSync();

      expect(readinessSource, contains('kMapBootstrapTimeout'));
      expect(readinessSource, contains('Timer? _bootstrapTimeoutTimer'));
      expect(mapSource, contains('_handleMapBootstrapTimeout'));
      expect(mapSource, contains("eventName: 'map.bootstrap.timed_out'"));
      expect(mapSource, contains('TelemetryFlowPhase.timedOut'));
      expect(mapSource, contains("'waiting_for': readiness.waitingFor"));
    });

    test('bootstrap timeout includes location diagnostics', () {
      final mapSource = File(
        'lib/features/map/presentation/screens/map_screen.dart',
      ).readAsStringSync();

      expect(mapSource, contains('_locationStateDiagnostics'));
      expect(mapSource, contains("'location_state':"));
      expect(mapSource, contains("'location_error_message':"));
    });

    test('pins overlay projection to actual MapLibre camera movement', () {
      final mapSource = File(
        'lib/features/map/presentation/screens/map_screen.dart',
      ).readAsStringSync();

      expect(mapSource, contains('onCameraMove: (cameraPosition)'));
      expect(mapSource, contains('_updateRenderCamera(cameraPosition)'));
      expect(mapSource, contains('final renderCameraPosition ='));
      expect(
        mapSource,
        contains('_renderCameraPosition ?? desiredCameraPosition'),
      );
      expect(
        mapSource,
        contains('final renderZoom = _renderCameraZoom ?? _kGpsZoom'),
      );
    });

    test('hides base-map text labels after style load', () {
      final mapSource = File(
        'lib/features/map/presentation/screens/map_screen.dart',
      ).readAsStringSync();

      expect(mapSource, contains('_hideBaseMapTextLabels('));
      expect(mapSource, contains('baseMapTextLabelLayerIdsFromStyle'));
      expect(mapSource, contains('setLayerVisibility(layerId, false)'));
      expect(mapSource, contains('map.base_map_labels_hidden'));
    });
    test('uses MapLibre exact screen-coordinate batch projection', () {
      final mapSource = File(
        'lib/features/map/presentation/screens/map_screen.dart',
      ).readAsStringSync();

      expect(mapSource, contains('toScreenLocationBatch('));
      expect(mapSource, contains('_scheduleExactScreenProjection('));
      expect(mapSource, contains("'projection_mode': projectionMode"));
      expect(mapSource, contains("projectionMode = exactProjectionReady"));
    });
    test(
      'rejects exact MapLibre projections when the camera target is not at the Flutter viewport center',
      () {
        final mapSource = File(
          'lib/features/map/presentation/screens/map_screen.dart',
        ).readAsStringSync();

        expect(mapSource, contains('_kExactProjectionCenterTolerancePx'));
        expect(mapSource, contains('exactProjectedCameraPosition'));
        expect(mapSource, contains('effectiveExactProjector'));
        expect(
          mapSource,
          contains("'mercator_fallback_misaligned_exact'"),
          reason:
              'Mobile Safari can leave MapLibre with a stale internal viewport; if project(cameraTarget) is not near the Flutter viewport center, overlays must fall back to Flutter-owned projection math.',
        );
        expect(mapSource, contains("reason: 'misaligned_exact_projection'"));
        expect(mapSource, contains('cameraCoordKey'));
      },
    );
    test('resizes web MapLibre when the Flutter map viewport changes', () {
      final mapSource = File(
        'lib/features/map/presentation/screens/map_screen.dart',
      ).readAsStringSync();

      expect(mapSource, contains('with WidgetsBindingObserver'));
      expect(mapSource, contains('WidgetsBinding.instance.addObserver(this)'));
      expect(mapSource, contains('void didChangeMetrics()'));
      expect(mapSource, contains('_syncWebMapLayoutSize(mapSize)'));
      expect(mapSource, contains('forceResizeWebMap()'));
      expect(mapSource, contains('_clearExactScreenProjection()'));
      expect(mapSource, contains("eventName: 'map.web_viewport_resized'"));
    });
    test('keeps a safety fallback for missing base-map settled signal', () {
      final readinessSource = File(
        'lib/features/map/presentation/providers/map_readiness_provider.dart',
      ).readAsStringSync();

      expect(readinessSource, contains('kBaseMapSettledFallbackDelay'));
      expect(readinessSource, contains("source: 'readiness_safety_fallback'"));
      expect(readinessSource, contains('state.styleLoaded'));
      expect(readinessSource, contains('state.cellsFetched'));
    });

    test('uses web MapLibre idle bridge before the timer fallback', () {
      final mapSource = File(
        'lib/features/map/presentation/screens/map_screen.dart',
      ).readAsStringSync();
      final readinessSource = File(
        'lib/features/map/presentation/providers/map_readiness_provider.dart',
      ).readAsStringSync();
      final signalFile = File(
        'lib/features/map/presentation/platform/base_map_settled_signal_web.dart',
      );
      final signalFacade = File(
        'lib/features/map/presentation/platform/base_map_settled_signal.dart',
      );

      expect(
        signalFile.existsSync(),
        isTrue,
        reason:
            'MapScreen needs an app-owned web bridge because '
            'maplibre_gl_web 0.25.0 does not forward MapLibre JS idle '
            'events into onMapIdle.',
      );

      final signalSource = signalFile.readAsStringSync();
      expect(mapSource, contains('BaseMapSettledSignal('));
      expect(readinessSource, contains('kBaseMapSettledFallbackDelay'));
      expect(readinessSource, contains('Duration(seconds: 5)'));
      expect(
        signalFacade.readAsStringSync(),
        contains('dart.library.js_interop'),
      );
      expect(signalSource, contains('earthnova.maplibre.idle'));
      expect(signalSource, contains('maplibre_js_idle'));
    });

    test(
      'uses web MapLibre load bridge before relying on plugin style callback',
      () {
        final mapSource = File(
          'lib/features/map/presentation/screens/map_screen.dart',
        ).readAsStringSync();
        final signalFile = File(
          'lib/features/map/presentation/platform/base_map_style_loaded_signal_web.dart',
        );
        final signalFacade = File(
          'lib/features/map/presentation/platform/base_map_style_loaded_signal.dart',
        );

        expect(
          signalFile.existsSync(),
          isTrue,
          reason:
              'MapScreen needs an app-owned web bridge because style readiness '
              'must not depend only on the plugin web callback.',
        );

        final signalSource = signalFile.readAsStringSync();
        expect(mapSource, contains('BaseMapStyleLoadedSignal('));
        expect(
          signalFacade.readAsStringSync(),
          contains('dart.library.js_interop'),
        );
        expect(signalSource, contains('earthnova.maplibre.load'));
        expect(signalSource, contains('maplibre_js_load'));
      },
    );

    test(
      'encounters use persisted entry handler rather than optimistic map listener',
      () {
        final mapSource = File(
          'lib/features/map/presentation/screens/map_screen.dart',
        ).readAsStringSync();
        final entrySource = File(
          'lib/features/encounters/presentation/providers/encounter_entry_provider.dart',
        ).readAsStringSync();

        expect(mapSource, contains('lastBorderCrossingEvent'));
        expect(mapSource, isNot(contains('.onCellEntered(')));
        expect(
          entrySource,
          contains('persistedCellVisitEncounterHandlerProvider'),
        );
        expect(
          entrySource,
          contains('mapEntryId: borderCrossingEvent.mapCellEntryId'),
        );
        expect(
          mapSource,
          isNot(contains('next.lastEntrySequence > previousEntrySequence')),
          reason:
              'Gameplay entry should follow exact persisted/border identities, not a generic sequence counter.',
        );
      },
    );

    test(
      'uses discovery reward modal instead of toast or Scaffold snackbar',
      () {
        final mapSource = File(
          'lib/features/map/presentation/screens/map_screen.dart',
        ).readAsStringSync();
        final tabShellSource = File(
          'lib/shared/widgets/tab_shell.dart',
        ).readAsStringSync();

        expect(mapSource, contains('_DiscoveryRewardModal('));
        expect(mapSource, contains('continueDiscoveryReward'));
        expect(tabShellSource, contains('addPostFrameCallback'));
        expect(tabShellSource, contains('completeRewardFlight'));
        expect(tabShellSource, isNot(contains('_PackRewardFlightOverlay(')));
        expect(tabShellSource, isNot(contains('_PackRewardImpactOverlay(')));
        expect(mapSource, isNot(contains('_EncounterToast(')));
        expect(mapSource, isNot(contains('showSnackBar')));
        expect(mapSource, isNot(contains('SnackBar(')));
      },
    );
  });
}
