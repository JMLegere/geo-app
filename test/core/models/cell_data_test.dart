import 'package:flutter_test/flutter_test.dart';
import 'package:geobase/geobase.dart';
import 'package:earth_nova/core/models/cell_data.dart';
import 'package:earth_nova/core/models/fog_state.dart';

void main() {
  group('CellData', () {
    final testLatLng = Geographic(lat: 37.7749, lon: -122.4194);
    final testDateTime = DateTime(2024, 1, 15, 10, 30);

    test('construction with all fields', () {
      final cellData = CellData(
        id: 'cell_001',
        center: testLatLng,
        fogState: FogState.unexplored,
        speciesIds: ['species_1', 'species_2'],
        restorationLevel: 0.5,
        distanceWalked: 150.0,
        visitCount: 3,
        lastVisited: testDateTime,
      );

      expect(cellData.id, equals('cell_001'));
      expect(cellData.center.lat, equals(37.7749));
      expect(cellData.center.lon, equals(-122.4194));
      expect(cellData.fogState, equals(FogState.unexplored));
      expect(cellData.speciesIds, equals(['species_1', 'species_2']));
      expect(cellData.restorationLevel, equals(0.5));
      expect(cellData.distanceWalked, equals(150.0));
      expect(cellData.visitCount, equals(3));
      expect(cellData.lastVisited, equals(testDateTime));
    });

    test('copyWith creates new instance with updated fields', () {
      final original = CellData(
        id: 'cell_001',
        center: testLatLng,
        fogState: FogState.unexplored,
        speciesIds: [],
        restorationLevel: 0.0,
        distanceWalked: 0.0,
        visitCount: 0,
        lastVisited: null,
      );

      final updated = original.copyWith(
        fogState: FogState.hidden,
        visitCount: 1,
        distanceWalked: 50.0,
        lastVisited: testDateTime,
      );

      expect(updated.id, equals(original.id));
      expect(updated.center, equals(original.center));
      expect(updated.fogState, equals(FogState.hidden));
      expect(updated.visitCount, equals(1));
      expect(updated.distanceWalked, equals(50.0));
      expect(updated.lastVisited, equals(testDateTime));
      
      // Original unchanged
      expect(original.fogState, equals(FogState.unexplored));
      expect(original.visitCount, equals(0));
    });

    test('JSON serialization round-trip preserves all data', () {
      final original = CellData(
        id: 'cell_001',
        center: testLatLng,
        fogState: FogState.concealed,
        speciesIds: ['sp_1', 'sp_2', 'sp_3'],
        restorationLevel: 0.75,
        distanceWalked: 250.5,
        visitCount: 5,
        lastVisited: testDateTime,
      );

      final json = original.toJson();
      final restored = CellData.fromJson(json);

      expect(restored.id, equals(original.id));
      expect(restored.center.lat, equals(original.center.lat));
      expect(restored.center.lon, equals(original.center.lon));
      expect(restored.fogState, equals(original.fogState));
      expect(restored.speciesIds, equals(original.speciesIds));
      expect(restored.restorationLevel, equals(original.restorationLevel));
      expect(restored.distanceWalked, equals(original.distanceWalked));
      expect(restored.visitCount, equals(original.visitCount));
      expect(restored.lastVisited, equals(original.lastVisited));
    });

    test('JSON serialization handles null lastVisited', () {
      final cellData = CellData(
        id: 'cell_002',
        center: testLatLng,
        fogState: FogState.undetected,
        speciesIds: [],
        restorationLevel: 0.0,
        distanceWalked: 0.0,
        visitCount: 0,
        lastVisited: null,
      );

      final json = cellData.toJson();
      final restored = CellData.fromJson(json);

      expect(restored.lastVisited, isNull);
    });

    test('equality comparison works correctly', () {
      final cell1 = CellData(
        id: 'cell_001',
        center: testLatLng,
        fogState: FogState.hidden,
        speciesIds: ['sp_1'],
        restorationLevel: 0.5,
        distanceWalked: 100.0,
        visitCount: 2,
        lastVisited: testDateTime,
      );

      final cell2 = CellData(
        id: 'cell_001',
        center: testLatLng,
        fogState: FogState.hidden,
        speciesIds: ['sp_1'],
        restorationLevel: 0.5,
        distanceWalked: 100.0,
        visitCount: 2,
        lastVisited: testDateTime,
      );

      final cell3 = CellData(
        id: 'cell_002',
        center: testLatLng,
        fogState: FogState.hidden,
        speciesIds: ['sp_1'],
        restorationLevel: 0.5,
        distanceWalked: 100.0,
        visitCount: 2,
        lastVisited: testDateTime,
      );

      expect(cell1, equals(cell2));
      expect(cell1, isNot(equals(cell3)));
    });

    test('restorationLevel is clamped between 0.0 and 1.0', () {
      final cellData = CellData(
        id: 'cell_001',
        center: testLatLng,
        fogState: FogState.observed,
        speciesIds: [],
        restorationLevel: 1.5, // Should be clamped to 1.0
        distanceWalked: 0.0,
        visitCount: 0,
        lastVisited: null,
      );

      expect(cellData.restorationLevel, equals(1.0));
    });

    test('speciesIds can be empty', () {
      final cellData = CellData(
        id: 'cell_001',
        center: testLatLng,
        fogState: FogState.undetected,
        speciesIds: [],
        restorationLevel: 0.0,
        distanceWalked: 0.0,
        visitCount: 0,
        lastVisited: null,
      );

      expect(cellData.speciesIds, isEmpty);
    });
  });
}
