import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/domain/entities/habitat.dart';
import 'package:earth_nova/features/map/domain/entities/cell.dart';

void main() {
  group('Cell', () {
    const id = 'cell-001';
    const habitats = [Habitat.forest, Habitat.freshwater];
    const polygon = [
      (lat: 44.6488, lng: -63.5752),
      (lat: 44.6490, lng: -63.5750),
      (lat: 44.6492, lng: -63.5755),
    ];

    test('constructs with required fields', () {
      const cell = Cell(
        id: id,
        habitats: habitats,
        polygon: polygon,
        districtId: 'district-1',
        cityId: 'city-1',
        stateId: 'state-1',
        countryId: 'country-1',
      );
      expect(cell.id, id);
      expect(cell.habitats, habitats);
      expect(cell.polygon, polygon);
      expect(cell.districtId, 'district-1');
      expect(cell.cityId, 'city-1');
      expect(cell.stateId, 'state-1');
      expect(cell.countryId, 'country-1');
    });

    test('equality by id', () {
      const a = Cell(
        id: id,
        habitats: habitats,
        polygon: polygon,
        districtId: 'd',
        cityId: 'c',
        stateId: 's',
        countryId: 'co',
      );
      const b = Cell(
        id: id,
        habitats: habitats,
        polygon: polygon,
        districtId: 'd',
        cityId: 'c',
        stateId: 's',
        countryId: 'co',
      );
      expect(a, equals(b));
    });

    test('inequality when ids differ', () {
      const a = Cell(
        id: 'cell-001',
        habitats: habitats,
        polygon: polygon,
        districtId: 'd',
        cityId: 'c',
        stateId: 's',
        countryId: 'co',
      );
      const b = Cell(
        id: 'cell-002',
        habitats: habitats,
        polygon: polygon,
        districtId: 'd',
        cityId: 'c',
        stateId: 's',
        countryId: 'co',
      );
      expect(a, isNot(equals(b)));
    });

    test('blendedColor returns habitat blend', () {
      const cell = Cell(
        id: id,
        habitats: [Habitat.forest, Habitat.freshwater],
        polygon: polygon,
        districtId: 'd',
        cityId: 'c',
        stateId: 's',
        countryId: 'co',
      );
      final expected =
          Habitat.blendHabitats([Habitat.forest, Habitat.freshwater]);
      expect(cell.blendedColor, expected);
    });

    test('blendedColor with single habitat returns that habitat color', () {
      const cell = Cell(
        id: id,
        habitats: [Habitat.ocean],
        polygon: polygon,
        districtId: 'd',
        cityId: 'c',
        stateId: 's',
        countryId: 'co',
      );
      expect(cell.blendedColor, Habitat.ocean.color);
    });

    test('hashCode is consistent for equal cells', () {
      const a = Cell(
        id: id,
        habitats: habitats,
        polygon: polygon,
        districtId: 'd',
        cityId: 'c',
        stateId: 's',
        countryId: 'co',
      );
      const b = Cell(
        id: id,
        habitats: habitats,
        polygon: polygon,
        districtId: 'd',
        cityId: 'c',
        stateId: 's',
        countryId: 'co',
      );
      expect(a.hashCode, equals(b.hashCode));
    });

    test('inequality when habitats differ', () {
      const a = Cell(
        id: id,
        habitats: [Habitat.forest],
        polygon: polygon,
        districtId: 'd',
        cityId: 'c',
        stateId: 's',
        countryId: 'co',
      );
      const b = Cell(
        id: id,
        habitats: [Habitat.ocean],
        polygon: polygon,
        districtId: 'd',
        cityId: 'c',
        stateId: 's',
        countryId: 'co',
      );
      expect(a, isNot(equals(b)));
    });

    test('inequality when polygon differs', () {
      const a = Cell(
        id: id,
        habitats: habitats,
        polygon: [(lat: 0.0, lng: 0.0)],
        districtId: 'd',
        cityId: 'c',
        stateId: 's',
        countryId: 'co',
      );
      const b = Cell(
        id: id,
        habitats: habitats,
        polygon: polygon,
        districtId: 'd',
        cityId: 'c',
        stateId: 's',
        countryId: 'co',
      );
      expect(a, isNot(equals(b)));
    });

    test('inequality when districtId differs', () {
      const a = Cell(
        id: id,
        habitats: habitats,
        polygon: polygon,
        districtId: 'district-a',
        cityId: 'c',
        stateId: 's',
        countryId: 'co',
      );
      const b = Cell(
        id: id,
        habitats: habitats,
        polygon: polygon,
        districtId: 'district-b',
        cityId: 'c',
        stateId: 's',
        countryId: 'co',
      );
      expect(a, isNot(equals(b)));
    });
  });
}
