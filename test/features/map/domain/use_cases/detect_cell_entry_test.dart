import 'dart:collection';

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
    test('checks the current cell before overlapping neighbors', () {
      const polygon = <GeoPolygon>[
        [
          [
            (lat: 0.0, lng: 0.0),
            (lat: 1.0, lng: 0.0),
            (lat: 1.0, lng: 1.0),
            (lat: 0.0, lng: 1.0),
          ],
        ],
      ];
      Cell cell(String id) => Cell(
        id: id,
        habitats: const [],
        polygons: polygon,
        districtId: 'district',
        cityId: 'city',
        stateId: 'state',
        countryId: 'country',
      );

      final result = useCase.detectCell(
        cells: [cell('neighbor'), cell('current')],
        point: (lat: 0.5, lng: 0.5),
        preferredCellId: 'current',
      );

      expect(result?.id, 'current');
    });

    test(
      'execute returns null when current point is outside all cells',
      () async {
        final result = await useCase.execute((
          cells: const [],
          previousCellId: null,
          currentPoint: (lat: 10.0, lng: 10.0),
        ), 'trace-1');

        expect(result, isNull);
      },
    );

    test(
      'execute returns first cell id when entering any cell initially',
      () async {
        final result = await useCase.execute((
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
        ), 'trace-2');

        expect(result, 'cell-1');
      },
    );

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

      final unchanged = await useCase.execute((
        cells: [cell],
        previousCellId: 'cell-1',
        currentPoint: (lat: 0.5, lng: 0.5),
      ), 'trace-3');
      final changed = await useCase.execute((
        cells: [cell],
        previousCellId: 'other-cell',
        currentPoint: (lat: 0.5, lng: 0.5),
      ), 'trace-4');

      expect(unchanged, isNull);
      expect(changed, 'cell-1');
    });
  });

  group('DetectCellEntry working set lookup', () {
    test(
      '1000 cells: reentry and adjacent moves do not scan the working set',
      () async {
        final detector = _CountingDetector();
        final cells = _CountingCells([
          for (var i = 0; i < 1000; i++)
            _cell('cell-$i', [
              [_square((i ~/ 40) * .01, (i % 40) * .01, .01)],
            ]),
        ]);
        const current = (lat: .245, lng: .385);
        const adjacent = (lat: .245, lng: .395);
        expect(
          detector.detectCell(cells: cells, point: current)?.id,
          'cell-998',
        );
        cells.reads = 0;
        detector.pointTests = 0;

        for (var tick = 0; tick < 20; tick++) {
          expect(
            await detector.execute((
              cells: cells,
              previousCellId: 'cell-998',
              currentPoint: current,
            ), 'same-cell-$tick'),
            isNull,
          );
        }
        expect(
          cells.reads,
          0,
          reason: 'current-cell lookup must use the ID index',
        );
        expect(detector.pointTests, 20);

        detector.pointTests = 0;
        expect(
          await detector.execute((
            cells: cells,
            previousCellId: 'cell-998',
            currentPoint: adjacent,
          ), 'adjacent'),
          'cell-999',
        );
        expect(
          cells.reads,
          0,
          reason: 'shared-edge neighbours are already indexed',
        );
        expect(detector.pointTests, lessThanOrEqualTo(2));

        detector.pointTests = 0;
        expect(
          detector
              .detectCell(
                cells: cells,
                point: (lat: .005, lng: .005),
                preferredCellId: 'cell-999',
              )
              ?.id,
          'cell-0',
        );
        expect(
          detector.pointTests,
          lessThanOrEqualTo(2),
          reason: 'teleports test only bounding-box candidates',
        );
        detector.pointTests = 0;
        expect(
          detector
              .detectCell(
                cells: cells,
                point: current,
                preferredCellId: 'not-loaded',
              )
              ?.id,
          'cell-998',
        );
        expect(detector.pointTests, 1);
      },
    );

    test(
      'replacement invalidates IDs, bounds and neighbours, not other lists',
      () {
        final detector = _CountingDetector();
        final original = _CountingCells([
          _cell('a', [
            [_square(0, 0, 1)],
          ]),
          _cell('b', [
            [_square(0, 1, 1)],
          ]),
        ]);
        detector.detectCell(cells: original, point: (lat: .5, lng: .5));
        final replacement = _CountingCells([
          _cell('a', [
            [_square(10, 10, 1)],
          ]),
          _cell('c', [
            [_square(10, 11, 1)],
          ]),
        ]);
        expect(
          detector.detectCell(
            cells: replacement,
            point: (lat: .5, lng: .5),
            preferredCellId: 'a',
          ),
          isNull,
        );
        expect(
          detector.detectCell(
            cells: replacement,
            point: (lat: 10.5, lng: 10.5),
            preferredCellId: 'b',
          ),
          same(replacement[0]),
        );
        replacement.reads = 0;
        expect(
          detector
              .detectCell(
                cells: replacement,
                point: (lat: 10.5, lng: 11.5),
                preferredCellId: 'a',
              )
              ?.id,
          'c',
        );
        expect(replacement.reads, 0);
        original.reads = 0;
        expect(
          detector
              .detectCell(
                cells: original,
                point: (lat: .5, lng: 1.5),
                preferredCellId: 'a',
              )
              ?.id,
          'b',
        );
        expect(original.reads, 0);
      },
    );

    test(
      'bounds preserve holes, disconnected components and ray-cast edges',
      () {
        final detector = _CountingDetector();
        final cells = [
          _cell('islands', [
            [_square(0, 0, 4), _square(1, 1, 2)],
            [_square(10, 10, 1)],
          ]),
          _cell('hole', [
            [_square(1, 1, 2)],
          ]),
          _cell('triangle', [
            [
              [(lat: 20, lng: 20), (lat: 22, lng: 20), (lat: 20, lng: 22)],
            ],
          ]),
        ];
        for (final point in <GeoCoord>[
          (lat: .5, lng: .5),
          (lat: 2, lng: 2),
          (lat: 10.5, lng: 10.5),
          (lat: 7, lng: 7),
          (lat: 21.5, lng: 21.5),
          (lat: 20.2, lng: 20.2),
          (lat: 0, lng: 0),
          (lat: 4, lng: 4),
          (lat: 1, lng: 2),
          (lat: 3, lng: 2),
        ]) {
          // The unchanged exact geometry predicate remains the boundary oracle.
          final expected = cells.where(
            (cell) => detector.pointInMultiPolygon(
              point: point,
              polygons: cell.polygons,
            ),
          );
          expect(
            detector.detectCell(
              cells: cells,
              point: point,
              preferredCellId: 'islands',
            ),
            expected.firstOrNull,
            reason: 'containment parity at $point',
          );
        }
      },
    );
  });
}

class _CountingDetector extends DetectCellEntry {
  _CountingDetector() : super(ObservabilityService(sessionId: 'lookup-test'));

  int pointTests = 0;

  @override
  bool pointInMultiPolygon({
    required GeoCoord point,
    required GeoMultiPolygon polygons,
  }) {
    pointTests++;
    return super.pointInMultiPolygon(point: point, polygons: polygons);
  }
}

class _CountingCells extends ListBase<Cell> {
  _CountingCells(this._cells);
  final List<Cell> _cells;
  int reads = 0;

  @override
  int get length => _cells.length;

  @override
  set length(int value) => throw UnsupportedError('Immutable working set');

  @override
  Cell operator [](int index) {
    reads++;
    return _cells[index];
  }

  @override
  void operator []=(int index, Cell value) =>
      throw UnsupportedError('Immutable working set');
}

Cell _cell(String id, GeoMultiPolygon polygons) => Cell(
  id: id,
  habitats: const [],
  polygons: polygons,
  districtId: 'district',
  cityId: 'city',
  stateId: 'state',
  countryId: 'country',
);

GeoRing _square(double lat, double lng, double size) => [
  (lat: lat, lng: lng),
  (lat: lat + size, lng: lng),
  (lat: lat + size, lng: lng + size),
  (lat: lat, lng: lng + size),
];
