import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/features/map/data/dtos/cell_dto.dart';
import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/core/domain/entities/habitat.dart';

void main() {
  group('CellDto.fromJson → toDomain', () {
    test('round-trip with all fields', () {
      final json = {
        'cell_id': 'cell-abc',
        'habitats': ['forest', 'freshwater'],
        'polygon': [
          {'lat': 1.0, 'lng': 2.0},
          {'lat': 3.0, 'lng': 4.0},
          {'lat': 5.0, 'lng': 6.0},
        ],
        'district_id': 'district-1',
        'city_id': 'city-1',
        'state_id': 'state-1',
        'country_id': 'country-1',
      };

      final dto = CellDto.fromJson(json);
      final cell = dto.toDomain();

      expect(cell.id, 'cell-abc');
      expect(cell.habitats, [Habitat.forest, Habitat.freshwater]);
      expect(cell.polygon.length, 3);
      expect(cell.polygon[0].lat, 1.0);
      expect(cell.polygon[0].lng, 2.0);
      expect(cell.districtId, 'district-1');
      expect(cell.cityId, 'city-1');
      expect(cell.stateId, 'state-1');
      expect(cell.countryId, 'country-1');
    });

    test('unknown habitat is skipped', () {
      final json = {
        'cell_id': 'cell-xyz',
        'habitats': ['forest', 'unknown_habitat'],
        'polygon': <Map<String, dynamic>>[],
        'district_id': '',
        'city_id': '',
        'state_id': '',
        'country_id': '',
      };

      final dto = CellDto.fromJson(json);
      final cell = dto.toDomain();

      expect(cell.habitats, [Habitat.forest]);
    });

    test('empty habitats list', () {
      final json = {
        'cell_id': 'cell-empty',
        'habitats': <String>[],
        'polygon': <Map<String, dynamic>>[],
        'district_id': '',
        'city_id': '',
        'state_id': '',
        'country_id': '',
      };

      final dto = CellDto.fromJson(json);
      final cell = dto.toDomain();

      expect(cell.habitats, isEmpty);
    });

    test('null optional location ids default to empty string', () {
      final json = {
        'cell_id': 'cell-null-loc',
        'habitats': <String>[],
        'polygon': <Map<String, dynamic>>[],
        'district_id': null,
        'city_id': null,
        'state_id': null,
        'country_id': null,
      };

      final dto = CellDto.fromJson(json);
      final cell = dto.toDomain();

      expect(cell.districtId, '');
      expect(cell.cityId, '');
      expect(cell.stateId, '');
      expect(cell.countryId, '');
    });

    test('polygon with no points', () {
      final json = {
        'cell_id': 'cell-no-poly',
        'habitats': <String>[],
        'polygon': <Map<String, dynamic>>[],
        'district_id': '',
        'city_id': '',
        'state_id': '',
        'country_id': '',
      };

      final dto = CellDto.fromJson(json);
      final cell = dto.toDomain();

      expect(cell.polygon, isEmpty);
    });

    test('toDomain returns Cell instance', () {
      final json = {
        'cell_id': 'cell-type',
        'habitats': <String>[],
        'polygon': <Map<String, dynamic>>[],
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
