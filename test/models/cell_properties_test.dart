import 'package:flutter_test/flutter_test.dart';

import 'package:earth_nova/models/cell_properties.dart';
import 'package:earth_nova/models/habitat.dart';
import 'package:earth_nova/models/climate.dart';
import 'package:earth_nova/models/continent.dart';

void main() {
  group('CellProperties', () {
    final props = CellProperties(
      cellId: 'v_42_17',
      habitats: {Habitat.forest, Habitat.plains},
      climate: Climate.temperate,
      continent: Continent.northAmerica,
      locationId: 'district_1',
      createdAt: DateTime(2026, 1, 1),
    );

    test('constructor stores all fields', () {
      expect(props.cellId, 'v_42_17');
      expect(props.habitats, {Habitat.forest, Habitat.plains});
      expect(props.climate, Climate.temperate);
      expect(props.continent, Continent.northAmerica);
      expect(props.locationId, 'district_1');
    });

    test('constructor asserts on empty habitats', () {
      expect(
        () => CellProperties(
          cellId: 'v_0_0',
          habitats: {},
          climate: Climate.tropic,
          continent: Continent.asia,
          locationId: null,
          createdAt: DateTime(2026, 1, 1),
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('copyWith overrides specified fields', () {
      final updated = props.copyWith(climate: Climate.boreal);
      expect(updated.climate, Climate.boreal);
      expect(updated.cellId, 'v_42_17');
    });

    test('toJson and fromJson round-trip', () {
      final json = props.toJson();
      final restored = CellProperties.fromJson(json);
      expect(restored, props);
    });

    test('toSupabaseMap contains correct keys', () {
      final map = props.toSupabaseMap();
      expect(map['cell_id'], 'v_42_17');
      expect(map['climate'], 'temperate');
      expect(map['continent'], 'northAmerica');
      expect(map['location_id'], 'district_1');
      expect((map['habitats'] as List).length, 2);
    });

    test('equality by all fields including set comparison', () {
      final other = CellProperties(
        cellId: 'v_42_17',
        habitats: {Habitat.plains, Habitat.forest},
        climate: Climate.temperate,
        continent: Continent.northAmerica,
        locationId: 'district_1',
        createdAt: DateTime(2026, 1, 1),
      );
      expect(other, props);
    });

    test('not equal when cellId differs', () {
      final other = props.copyWith(cellId: 'v_0_0');
      expect(other == props, false);
    });

    test('locationId can be null', () {
      final fresh = CellProperties(
        cellId: 'v_0_0',
        habitats: {Habitat.plains},
        climate: Climate.tropic,
        continent: Continent.asia,
        locationId: null,
        createdAt: DateTime(2026, 1, 1),
      );
      expect(fresh.locationId, isNull);
    });

    test('toString contains cellId', () {
      expect(props.toString(), contains('v_42_17'));
    });
  });
}
