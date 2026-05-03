import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/domain/entities/habitat.dart';
import 'package:earth_nova/features/map/domain/entities/cell.dart';

void main() {
  group('Cell', () {
    const id = 'cell-001';
    const habitats = [Habitat.forest, Habitat.freshwater];
    const polygons = [
      [
        [
          (lat: 44.6488, lng: -63.5752),
          (lat: 44.6490, lng: -63.5750),
          (lat: 44.6492, lng: -63.5755),
        ],
      ],
    ];

    const multiPolygons = [
      [
        [
          (lat: 44.6488, lng: -63.5752),
          (lat: 44.6490, lng: -63.5750),
          (lat: 44.6492, lng: -63.5755),
        ],
      ],
      [
        [
          (lat: 44.6500, lng: -63.5760),
          (lat: 44.6502, lng: -63.5760),
          (lat: 44.6502, lng: -63.5762),
        ],
      ],
    ];

    test('constructs with required fields', () {
      const cell = Cell(
        id: id,
        habitats: habitats,
        polygons: polygons,
        districtId: 'district-1',
        cityId: 'city-1',
        stateId: 'state-1',
        countryId: 'country-1',
      );
      expect(cell.id, id);
      expect(cell.habitats, habitats);
      expect(cell.polygons, polygons);
      expect(cell.primaryExteriorRing, polygons.first.first);
      expect(cell.hasRenderableGeometry, isTrue);
      expect(cell.districtId, 'district-1');
      expect(cell.cityId, 'city-1');
      expect(cell.stateId, 'state-1');
      expect(cell.countryId, 'country-1');
    });

    test('exteriorPoints flattens exterior rings across polygons', () {
      const cell = Cell(
        id: id,
        habitats: habitats,
        polygons: multiPolygons,
        districtId: 'd',
        cityId: 'c',
        stateId: 's',
        countryId: 'co',
      );

      expect(cell.exteriorPoints, [
        ...multiPolygons[0][0],
        ...multiPolygons[1][0],
      ]);
    });

    test('equality by full value', () {
      const a = Cell(
        id: id,
        habitats: habitats,
        polygons: polygons,
        districtId: 'd',
        cityId: 'c',
        stateId: 's',
        countryId: 'co',
      );
      const b = Cell(
        id: id,
        habitats: habitats,
        polygons: polygons,
        districtId: 'd',
        cityId: 'c',
        stateId: 's',
        countryId: 'co',
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('inequality when polygons differ', () {
      const a = Cell(
        id: id,
        habitats: habitats,
        polygons: [
          [
            [(lat: 0.0, lng: 0.0), (lat: 1.0, lng: 0.0), (lat: 1.0, lng: 1.0)],
          ],
        ],
        districtId: 'd',
        cityId: 'c',
        stateId: 's',
        countryId: 'co',
      );
      const b = Cell(
        id: id,
        habitats: habitats,
        polygons: polygons,
        districtId: 'd',
        cityId: 'c',
        stateId: 's',
        countryId: 'co',
      );
      expect(a, isNot(equals(b)));
    });

    test('hasRenderableGeometry is false when no exterior ring has 3 points', () {
      const cell = Cell(
        id: id,
        habitats: habitats,
        polygons: [
          [
            [(lat: 0.0, lng: 0.0), (lat: 1.0, lng: 1.0)],
          ],
        ],
        districtId: 'd',
        cityId: 'c',
        stateId: 's',
        countryId: 'co',
      );

      expect(cell.hasRenderableGeometry, isFalse);
      expect(cell.primaryExteriorRing, isEmpty);
    });

    test('blendedColor returns habitat blend', () {
      const cell = Cell(
        id: id,
        habitats: [Habitat.forest, Habitat.freshwater],
        polygons: polygons,
        districtId: 'd',
        cityId: 'c',
        stateId: 's',
        countryId: 'co',
      );
      final expected =
          Habitat.blendHabitats([Habitat.forest, Habitat.freshwater]);
      expect(cell.blendedColor, expected);
    });
  });
}
