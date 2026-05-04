import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/features/map/data/dtos/cell_dto.dart';
import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/core/domain/entities/habitat.dart';

void main() {
  group('CellDto.fromJson → toDomain', () {
    test('round-trip with nested polygons and all fields', () {
      final json = {
        'cell_id': 'cell-abc',
        'habitats': ['forest', 'freshwater'],
        'polygons': [
          [
            [
              {'lat': 1.0, 'lng': 2.0},
              {'lat': 3.0, 'lng': 4.0},
              {'lat': 5.0, 'lng': 6.0},
            ],
          ],
          [
            [
              {'lat': 7.0, 'lng': 8.0},
              {'lat': 9.0, 'lng': 10.0},
              {'lat': 11.0, 'lng': 12.0},
            ],
          ],
        ],
        'district_id': 'district-1',
        'city_id': 'city-1',
        'state_id': 'state-1',
        'country_id': 'country-1',
        'geometry_source_version': 'organic-voronoi-beta-v1',
        'geometry_generation_mode':
            'db-deterministic-jittered-centroid-voronoi',
        'centroid_dataset_version': 'earthnova-organic-centroids-beta-v1',
        'geometry_contract': 'true-voronoi-clipped-to-lattice-coverage',
      };

      final dto = CellDto.fromJson(json);
      final cell = dto.toDomain();

      expect(cell.id, 'cell-abc');
      expect(cell.habitats, [Habitat.forest, Habitat.freshwater]);
      expect(cell.polygons.length, 2);
      expect(cell.polygons[0][0][0].lat, 1.0);
      expect(cell.polygons[0][0][0].lng, 2.0);
      expect(cell.polygons[1][0][1].lat, 9.0);
      expect(cell.districtId, 'district-1');
      expect(cell.cityId, 'city-1');
      expect(cell.stateId, 'state-1');
      expect(cell.countryId, 'country-1');
      expect(cell.geometrySourceVersion, 'organic-voronoi-beta-v1');
      expect(cell.geometryGenerationMode,
          'db-deterministic-jittered-centroid-voronoi');
      expect(
          cell.centroidDatasetVersion, 'earthnova-organic-centroids-beta-v1');
      expect(cell.geometryContract, 'true-voronoi-clipped-to-lattice-coverage');
    });

    test('falls back from legacy polygon field to canonical polygons', () {
      final json = {
        'cell_id': 'cell-legacy',
        'habitats': ['forest'],
        'polygon': [
          {'lat': 1.0, 'lng': 2.0},
          {'lat': 3.0, 'lng': 4.0},
          {'lat': 5.0, 'lng': 6.0},
        ],
      };

      final cell = CellDto.fromJson(json).toDomain();

      expect(cell.polygons, [
        [
          [
            (lat: 1.0, lng: 2.0),
            (lat: 3.0, lng: 4.0),
            (lat: 5.0, lng: 6.0),
          ],
        ],
      ]);
    });

    test('unknown habitat is skipped', () {
      final json = {
        'cell_id': 'cell-xyz',
        'habitats': ['forest', 'unknown_habitat'],
        'polygons': const [],
        'district_id': '',
        'city_id': '',
        'state_id': '',
        'country_id': '',
      };

      final cell = CellDto.fromJson(json).toDomain();

      expect(cell.habitats, [Habitat.forest]);
    });

    test('null optional location ids default to empty string', () {
      final json = {
        'cell_id': 'cell-null-loc',
        'habitats': <String>[],
        'polygons': const [],
        'district_id': null,
        'city_id': null,
        'state_id': null,
        'country_id': null,
      };

      final cell = CellDto.fromJson(json).toDomain();

      expect(cell.districtId, '');
      expect(cell.cityId, '');
      expect(cell.stateId, '');
      expect(cell.countryId, '');
    });

    test('empty geometry becomes empty polygons', () {
      final json = {
        'cell_id': 'cell-no-poly',
        'habitats': <String>[],
        'polygons': const [],
        'district_id': '',
        'city_id': '',
        'state_id': '',
        'country_id': '',
      };

      final cell = CellDto.fromJson(json).toDomain();

      expect(cell.polygons, isEmpty);
    });

    test('toDomain returns Cell instance', () {
      final json = {
        'cell_id': 'cell-type',
        'habitats': <String>[],
        'polygons': const [],
        'district_id': '',
        'city_id': '',
        'state_id': '',
        'country_id': '',
      };

      final cell = CellDto.fromJson(json).toDomain();
      expect(cell, isA<Cell>());
    });
  });
}
