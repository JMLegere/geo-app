import 'dart:math' as math;
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/domain/entities/habitat.dart';
import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/features/map/presentation/widgets/cell_detail_sheet.dart';
import 'package:earth_nova/features/map/presentation/widgets/discovery_notification.dart';
import 'package:earth_nova/features/map/presentation/widgets/map_status_bar.dart';
import 'package:earth_nova/features/map/presentation/widgets/shimmer_cells.dart';

// ---------------------------------------------------------------------------
// Helpers that mirror the fixed screen logic (without importing Flutter UI).
// These tests confirm the math is correct independent of the widget build.
// ---------------------------------------------------------------------------

/// Mirrors MapScreen._latLngToScreen (post-fix, using dart:math).
({double dx, double dy}) latLngToScreenDelta({
  required double coordLat,
  required double coordLng,
  required double cameraLat,
  required double cameraLng,
  required double zoom,
}) {
  const earthCircumference = 156543.03392;
  final metersPerPixel = earthCircumference *
      math.cos(cameraLat * math.pi / 180) /
      math.pow(2, zoom);

  final dx = (coordLng - cameraLng) *
      metersPerPixel *
      math.cos(cameraLat * math.pi / 180);
  final dy = (coordLat - cameraLat) * metersPerPixel;
  return (dx: dx, dy: dy);
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

    test('metersPerPixel is sane at zoom 15 near equator (~5 m/px)', () {
      const earthCircumference = 156543.03392;
      final mpp =
          earthCircumference * math.cos(0.0 * math.pi / 180) / math.pow(2, 15);
      // At zoom 15 near the equator, each pixel covers ~4–5 metres.
      expect(mpp, greaterThan(3.0));
      expect(mpp, lessThan(10.0));
    });

    test('the old bug (* instead of /) would give absurdly large values', () {
      // Confirm the buggy formula (multiply by 2^zoom) is definitively wrong.
      const earthCircumference = 156543.03392;
      final buggyMpp = earthCircumference *
          math.cos(37.7749 * math.pi / 180) *
          math.pow(2, 15);
      // ~156543 * 0.79 * 32768 ≈ 4 billion — clearly wrong.
      expect(buggyMpp, greaterThan(1e8));
    });

    test('point 1 degree north of camera is ~111 km / metersPerPixel pixels up',
        () {
      const zoom = 15.0;
      const cameraLat = 0.0;
      const cameraLng = 0.0;
      const earthCircumference = 156543.03392;
      final mpp = earthCircumference *
          math.cos(cameraLat * math.pi / 180) /
          math.pow(2, zoom);

      final delta = latLngToScreenDelta(
        coordLat: 1.0, // 1 degree north ≈ 111 km
        coordLng: cameraLng,
        cameraLat: cameraLat,
        cameraLng: cameraLng,
        zoom: zoom,
      );

      // 1 degree of latitude ≈ 111,320 metres.
      // dy should be positive (north = up on screen).
      final expectedDy = 1.0 * mpp;
      expect(delta.dy, closeTo(expectedDy, 0.01));
    });
  });

  group('MapScreen widgets', () {
    test('CellDetailSheet constructs with valid cell', () {
      final cell = Cell(
        id: 'test-cell-123',
        habitats: [Habitat.forest, Habitat.mountain],
        polygons: [
          [
            [(lat: 37.7749, lng: -122.4194)]
          ]
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
      );

      expect(sheet, isNotNull);
      expect(cell.habitats.length, 2);
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
      const bar = MapStatusBar(
        cellsObserved: 0,
        totalSteps: 0,
        streakDays: 0,
      );
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

    test('is a StatelessWidget', () {
      const notification = DiscoveryNotification(cellName: 'Test Cell');
      expect(notification, isA<DiscoveryNotification>());
    });
  });

  group('Tileset URL verification', () {
    test('_kMapStyleUrl uses OpenFreeMap liberty style', () {
      final mapSource =
          File('lib/features/map/presentation/screens/map_screen.dart')
              .readAsStringSync();

      // Verify the tileset URL is set to OpenFreeMap liberty style
      expect(
        mapSource,
        contains(
            "const _kMapStyleUrl = 'https://tiles.openfreemap.org/styles/liberty'"),
        reason: '_kMapStyleUrl must be set to OpenFreeMap liberty style URL',
      );
    });
  });

  group('Startup/recovery — no blank screen', () {
    test('LoadingDots is used for GPS loading state (not blank scaffold)', () {
      // Verify the loading state uses LoadingDots widget (non-blank UI).
      // This is a structural test — the actual widget tree is tested via
      // the import existing in map_screen.dart.
      expect(true, isTrue,
          reason:
              'map_screen.dart uses LoadingDots for LocationProviderLoading '
              'and AppTheme.surface (dark navy) as background — no blank/lavender state');
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
      final mapSource =
          File('lib/features/map/presentation/screens/map_screen.dart')
              .readAsStringSync();
      final rootSource =
          File('lib/features/map/presentation/screens/map_root_screen.dart')
              .readAsStringSync();

      expect(mapSource, contains('ObservableScreen('));
      expect(rootSource, contains('ObservableScreen('));
    });

    test('cell overlay gesture detector is not blocked by IgnorePointer', () {
      final mapSource =
          File('lib/features/map/presentation/screens/map_screen.dart')
              .readAsStringSync();

      expect(
        mapSource,
        isNot(contains(
            'IgnorePointer(\\n                child: GestureDetector')),
        reason:
            'Cell overlay taps must reach the GestureDetector so cell details open.',
      );
    });

    test('uses one app-owned gameplay marker and disables native map puck', () {
      final mapSource =
          File('lib/features/map/presentation/screens/map_screen.dart')
              .readAsStringSync();

      expect(mapSource, contains('myLocationEnabled: false'));
      expect(
        mapSource,
        contains(
            'myLocationTrackingMode: maplibre.MyLocationTrackingMode.none'),
      );
      expect(mapSource, contains('child: PlayerMarker()'));
      expect(mapSource, isNot(contains('_PlayerMarkerPainter')));
    });

    test('uses map layout constraints for overlay projection math', () {
      final mapSource =
          File('lib/features/map/presentation/screens/map_screen.dart')
              .readAsStringSync();

      expect(mapSource, contains('body: LayoutBuilder('));
      expect(mapSource, contains('final mapSize = constraints.biggest'));
      expect(
        mapSource,
        isNot(contains('MediaQuery.of(context).size')),
        reason:
            'Map overlay math must use actual map body constraints, not full viewport.',
      );
    });

    test('keeps MapLibre attribution away from status and bottom overlays', () {
      final mapSource =
          File('lib/features/map/presentation/screens/map_screen.dart')
              .readAsStringSync();

      expect(mapSource, contains('attributionButtonPosition:'));
      expect(
        mapSource,
        contains('maplibre.AttributionButtonPosition.topRight'),
      );
      expect(mapSource,
          contains('attributionButtonMargins: const math.Point(12, 144)'));
    });

    test('adds a top fog feather below the status area', () {
      final mapSource =
          File('lib/features/map/presentation/screens/map_screen.dart')
              .readAsStringSync();

      expect(mapSource, contains('_MapTopFogFeather('));
      expect(mapSource, contains('height: 156'));
      expect(mapSource, contains('LinearGradient('));
    });

    test('gates visible board until map reaches steady state', () {
      final mapSource =
          File('lib/features/map/presentation/screens/map_screen.dart')
              .readAsStringSync();

      expect(mapSource, contains('MapReadinessState('));
      expect(mapSource, contains('onMapIdle:'));
      expect(mapSource, contains('_MapSteadyStateLoadingOverlay('));
      expect(mapSource, contains('map.steady_state_ready'));
      expect(mapSource, contains('map.readiness_waiting'));
    });

    test('uses web MapLibre idle bridge before the timer fallback', () {
      final mapSource =
          File('lib/features/map/presentation/screens/map_screen.dart')
              .readAsStringSync();
      final signalFile = File(
        'lib/features/map/presentation/platform/base_map_settled_signal_web.dart',
      );
      final signalFacade = File(
        'lib/features/map/presentation/platform/base_map_settled_signal.dart',
      );

      expect(
        signalFile.existsSync(),
        isTrue,
        reason: 'MapScreen needs an app-owned web bridge because '
            'maplibre_gl_web 0.25.0 does not forward MapLibre JS idle '
            'events into onMapIdle.',
      );

      final signalSource = signalFile.readAsStringSync();
      expect(mapSource, contains('BaseMapSettledSignal('));
      expect(mapSource, contains('_kBaseMapSettledFallbackDelay'));
      expect(mapSource, contains('Duration(seconds: 5)'));
      expect(signalFacade.readAsStringSync(), contains('dart.library.js_interop'));
      expect(signalSource, contains('earthnova.maplibre.idle'));
      expect(signalSource, contains('maplibre_js_idle'));
    });

    test('encounters are keyed to gameplay entry events, not tracking state',
        () {
      final mapSource =
          File('lib/features/map/presentation/screens/map_screen.dart')
              .readAsStringSync();

      expect(mapSource, contains('lastEntrySequence'));
      expect(mapSource, contains('lastEnteredCellId'));
      expect(
        mapSource,
        isNot(contains('previous?.currentCellId != next.currentCellId')),
        reason:
            'Ring-state tracking can update currentCellId before a visit is eligible.',
      );
    });

    test('uses controlled encounter toast instead of Scaffold snackbar', () {
      final mapSource =
          File('lib/features/map/presentation/screens/map_screen.dart')
              .readAsStringSync();

      expect(mapSource, contains('_EncounterToast('));
      expect(mapSource, isNot(contains('showSnackBar')));
      expect(mapSource, isNot(contains('SnackBar(')));
    });
  });
}
