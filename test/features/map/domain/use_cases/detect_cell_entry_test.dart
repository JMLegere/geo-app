import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/domain/entities/habitat.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/features/map/domain/use_cases/detect_cell_entry.dart';

void main() {
  group('DetectCellEntry geometry', () {
    final useCase = DetectCellEntry(
      ObservabilityService(sessionId: 'test-session'),
    );

    test('pointInRing returns true when point is inside ring', () {
      final ring = <GeoCoord>[
        (lat: 0.0, lng: 0.0),
        (lat: 4.0, lng: 0.0),
        (lat: 4.0, lng: 4.0),
        (lat: 0.0, lng: 4.0),
      ];

      expect(
        useCase.pointInRing(point: (lat: 2.0, lng: 2.0), ring: ring),
        isTrue,
      );
    });

    test('pointInPolygon excludes holes', () {
      final polygon = <GeoRing>[
        [
          (lat: 0.0, lng: 0.0),
          (lat: 4.0, lng: 0.0),
          (lat: 4.0, lng: 4.0),
          (lat: 0.0, lng: 4.0),
        ],
        [
          (lat: 1.0, lng: 1.0),
          (lat: 3.0, lng: 1.0),
          (lat: 3.0, lng: 3.0),
          (lat: 1.0, lng: 3.0),
        ],
      ];

      expect(
        useCase.pointInPolygon(point: (lat: 0.5, lng: 0.5), polygon: polygon),
        isTrue,
      );
      expect(
        useCase.pointInPolygon(point: (lat: 2.0, lng: 2.0), polygon: polygon),
        isFalse,
      );
    });

    test('pointInMultiPolygon returns true when point is in any polygon', () {
      final polygons = <GeoPolygon>[
        [
          [
            (lat: 0.0, lng: 0.0),
            (lat: 1.0, lng: 0.0),
            (lat: 1.0, lng: 1.0),
            (lat: 0.0, lng: 1.0),
          ],
        ],
        [
          [
            (lat: 5.0, lng: 5.0),
            (lat: 6.0, lng: 5.0),
            (lat: 6.0, lng: 6.0),
            (lat: 5.0, lng: 6.0),
          ],
        ],
      ];

      expect(
        useCase.pointInMultiPolygon(
          point: (lat: 5.5, lng: 5.5),
          polygons: polygons,
        ),
        isTrue,
      );
      expect(
        useCase.pointInMultiPolygon(
          point: (lat: 3.0, lng: 3.0),
          polygons: polygons,
        ),
        isFalse,
      );
    });

    test('detectCell returns containing cell from nested polygons', () {
      final cells = [
        Cell(
          id: 'cell-1',
          habitats: const [Habitat.forest],
          polygons: const [
            [
              [
                (lat: 0.0, lng: 0.0),
                (lat: 1.0, lng: 0.0),
                (lat: 1.0, lng: 1.0),
                (lat: 0.0, lng: 1.0),
              ],
            ],
          ],
          districtId: 'd1',
          cityId: 'c1',
          stateId: 's1',
          countryId: 'co1',
        ),
        Cell(
          id: 'cell-2',
          habitats: const [Habitat.ocean],
          polygons: const [
            [
              [
                (lat: 1.0, lng: 0.0),
                (lat: 2.0, lng: 0.0),
                (lat: 2.0, lng: 1.0),
                (lat: 1.0, lng: 1.0),
              ],
            ],
          ],
          districtId: 'd2',
          cityId: 'c2',
          stateId: 's2',
          countryId: 'co2',
        ),
      ];

      final result = useCase.detectCell(
        cells: cells,
        point: (lat: 0.5, lng: 0.5),
      );

      expect(result?.id, 'cell-1');
    });

    test('execute returns null when current point is outside all cells', () async {
      final result = await useCase.execute(
        (
          cells: const [],
          previousCellId: null,
          currentPoint: (lat: 10.0, lng: 10.0),
        ),
        'trace-1',
      );

      expect(result, isNull);
    });

    test('execute returns first cell id when entering any cell initially', () async {
      final result = await useCase.execute(
        (
          cells: [
            Cell(
              id: 'cell-1',
              habitats: const [],
              polygons: const [
                [
                  [
                    (lat: 0.0, lng: 0.0),
                    (lat: 1.0, lng: 0.0),
                    (lat: 1.0, lng: 1.0),
                    (lat: 0.0, lng: 1.0),
                  ],
                ],
              ],
              districtId: 'd',
              cityId: 'c',
              stateId: 's',
              countryId: 'co',
            ),
          ],
          previousCellId: null,
          currentPoint: (lat: 0.5, lng: 0.5),
        ),
        'trace-2',
      );

      expect(result, 'cell-1');
    });

    test('execute returns new id only when cell changes', () async {
      final cell = Cell(
        id: 'cell-1',
        habitats: const [],
        polygons: const [
          [
            [
              (lat: 0.0, lng: 0.0),
              (lat: 1.0, lng: 0.0),
              (lat: 1.0, lng: 1.0),
              (lat: 0.0, lng: 1.0),
            ],
          ],
        ],
        districtId: 'd',
        cityId: 'c',
        stateId: 's',
        countryId: 'co',
      );

      final unchanged = await useCase.execute(
        (
          cells: [cell],
          previousCellId: 'cell-1',
          currentPoint: (lat: 0.5, lng: 0.5),
        ),
        'trace-3',
      );
      final changed = await useCase.execute(
        (
          cells: [cell],
          previousCellId: 'other-cell',
          currentPoint: (lat: 0.5, lng: 0.5),
        ),
        'trace-4',
      );

      expect(unchanged, isNull);
      expect(changed, 'cell-1');
    });
  });
}
