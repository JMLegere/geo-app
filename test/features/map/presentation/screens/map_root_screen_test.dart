import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/domain/entities/habitat.dart';
import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/features/map/domain/entities/location_state.dart';
import 'package:earth_nova/features/map/domain/entities/map_level.dart';
import 'package:earth_nova/features/map/presentation/providers/exploration_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/map_provider.dart';
import 'package:earth_nova/features/map/presentation/screens/map_root_screen.dart';

void main() {
  group('MapRootScreen HitTestBehavior', () {
    test(
        'source uses HitTestBehavior.translucent so injected pointer events '
        'reach the GestureDetector when a hierarchy screen is mounted', () {
      final source = File(
        'lib/features/map/presentation/screens/map_root_screen.dart',
      ).readAsStringSync();

      expect(
        source,
        contains('HitTestBehavior.translucent'),
        reason: 'GestureDetector must use translucent so pointer-injected '
            'scale events reach the recognizer even when Positioned.fill '
            'hierarchy child is mounted on top.',
      );
      expect(
        source,
        isNot(contains('HitTestBehavior.deferToChild')),
        reason: 'deferToChild causes hierarchy screen to swallow hit tests.',
      );
    });
  });

  group('MapLibre platform-view visibility', () {
    test('source hides the web platform view when hierarchy screens are active',
        () {
      final source = File(
        'lib/features/map/presentation/screens/map_root_screen.dart',
      ).readAsStringSync();

      expect(source, contains('MapLibrePlatformViewVisibilityBridge'));
      expect(source, contains('setVisible(level == MapLevel.cell)'));
      expect(
        source,
        contains(
            'MapScreen stays mounted at all times so WebGL context is preserved'),
      );
    });
  });

  group('hierarchyScopeIdForLevel', () {
    final mapState = MapStateReady(
      cells: [
        _cell(
          id: 'current-cell',
          districtId: 'district-active',
          cityId: 'city-active',
          stateId: 'state-active',
          countryId: 'country-active',
        ),
        _cell(
          id: 'other-cell',
          districtId: 'district-other',
          cityId: 'city-other',
          stateId: 'state-other',
          countryId: 'country-other',
        ),
      ],
      visitedCellIds: const {},
      location: LocationState(
        lat: 45.9636,
        lng: -66.6431,
        accuracy: 5,
        timestamp: DateTime.utc(2026, 5, 5),
        isConfident: true,
      ),
    );

    test('maps current cell hierarchy IDs into the active hierarchy level', () {
      const explorationState = ExplorationStateData(
        currentCellId: 'current-cell',
      );

      expect(
        hierarchyScopeIdForLevel(
          level: MapLevel.district,
          mapState: mapState,
          explorationState: explorationState,
        ),
        'district-active',
      );
      expect(
        hierarchyScopeIdForLevel(
          level: MapLevel.city,
          mapState: mapState,
          explorationState: explorationState,
        ),
        'city-active',
      );
      expect(
        hierarchyScopeIdForLevel(
          level: MapLevel.state,
          mapState: mapState,
          explorationState: explorationState,
        ),
        'state-active',
      );
      expect(
        hierarchyScopeIdForLevel(
          level: MapLevel.country,
          mapState: mapState,
          explorationState: explorationState,
        ),
        'country-active',
      );
    });

    test('falls back to last entered cell when current cell is not set', () {
      const explorationState = ExplorationStateData(
        lastEnteredCellId: 'current-cell',
      );

      expect(
        hierarchyScopeIdForLevel(
          level: MapLevel.district,
          mapState: mapState,
          explorationState: explorationState,
        ),
        'district-active',
      );
    });

    test('returns null for world, cell, missing map data, or blank scope IDs',
        () {
      const explorationState = ExplorationStateData(
        currentCellId: 'current-cell',
      );

      expect(
        hierarchyScopeIdForLevel(
          level: MapLevel.world,
          mapState: mapState,
          explorationState: explorationState,
        ),
        isNull,
      );
      expect(
        hierarchyScopeIdForLevel(
          level: MapLevel.cell,
          mapState: mapState,
          explorationState: explorationState,
        ),
        isNull,
      );
      expect(
        hierarchyScopeIdForLevel(
          level: MapLevel.district,
          mapState: const MapStateLoading(),
          explorationState: explorationState,
        ),
        isNull,
      );
      expect(
        hierarchyScopeIdForLevel(
          level: MapLevel.district,
          mapState: MapStateReady(
            cells: [
              _cell(
                id: 'current-cell',
                districtId: ' ',
                cityId: 'city-active',
                stateId: 'state-active',
                countryId: 'country-active',
              ),
            ],
            visitedCellIds: const {},
            location: mapState.location,
          ),
          explorationState: explorationState,
        ),
        isNull,
      );
    });
  });
}

Cell _cell({
  required String id,
  required String districtId,
  required String cityId,
  required String stateId,
  required String countryId,
}) {
  return Cell(
    id: id,
    habitats: const [Habitat.forest],
    polygons: const [
      [
        [
          (lat: 0.0, lng: 0.0),
          (lat: 0.0, lng: 1.0),
          (lat: 1.0, lng: 0.0),
        ],
      ],
    ],
    districtId: districtId,
    cityId: cityId,
    stateId: stateId,
    countryId: countryId,
  );
}
