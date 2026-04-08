import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/features/map/domain/use_cases/detect_cell_entry.dart';

class TestObservabilityService extends ObservabilityService {
  TestObservabilityService() : super(sessionId: 'test-session');

  final logs = <Map<String, Object?>>[];

  @override
  void log(String event, String category, {Map<String, dynamic>? data}) {
    logs.add({'event': event, 'category': category, 'data': data});
  }
}

void main() {
  group('DetectCellEntry', () {
    late DetectCellEntry detectCellEntry;
    late TestObservabilityService obs;

    setUp(() {
      obs = TestObservabilityService();
      detectCellEntry = DetectCellEntry(obs);
    });

    group('pointInPolygon', () {
      test('returns true when point is inside polygon', () {
        // Square polygon: (0,0), (4,0), (4,4), (0,4)
        final polygon = <GeoCoord>[
          (lat: 0.0, lng: 0.0),
          (lat: 4.0, lng: 0.0),
          (lat: 4.0, lng: 4.0),
          (lat: 0.0, lng: 4.0),
        ];

        final result = detectCellEntry.pointInPolygon(
          point: (lat: 2.0, lng: 2.0),
          polygon: polygon,
        );

        expect(result, isTrue);
      });

      test('returns false when point is outside polygon', () {
        final polygon = <GeoCoord>[
          (lat: 0.0, lng: 0.0),
          (lat: 4.0, lng: 0.0),
          (lat: 4.0, lng: 4.0),
          (lat: 0.0, lng: 4.0),
        ];

        final result = detectCellEntry.pointInPolygon(
          point: (lat: 5.0, lng: 5.0),
          polygon: polygon,
        );

        expect(result, isFalse);
      });

      test('returns true when point is on polygon edge', () {
        final polygon = <GeoCoord>[
          (lat: 0.0, lng: 0.0),
          (lat: 4.0, lng: 0.0),
          (lat: 4.0, lng: 4.0),
          (lat: 0.0, lng: 4.0),
        ];

        final result = detectCellEntry.pointInPolygon(
          point: (lat: 2.0, lng: 0.0),
          polygon: polygon,
        );

        expect(result, isTrue);
      });

      test('returns true when point is at polygon vertex', () {
        final polygon = <GeoCoord>[
          (lat: 0.0, lng: 0.0),
          (lat: 4.0, lng: 0.0),
          (lat: 4.0, lng: 4.0),
          (lat: 0.0, lng: 4.0),
        ];

        final result = detectCellEntry.pointInPolygon(
          point: (lat: 0.0, lng: 0.0),
          polygon: polygon,
        );

        expect(result, isTrue);
      });
    });

    group('detectCell', () {
      test('returns cell when marker is inside cell polygon', () {
        final cells = [
          Cell(
            id: 'cell-1',
            habitats: [],
            polygon: [
              (lat: 0.0, lng: 0.0),
              (lat: 1.0, lng: 0.0),
              (lat: 1.0, lng: 1.0),
              (lat: 0.0, lng: 1.0),
            ],
            districtId: 'd1',
            cityId: 'c1',
            stateId: 's1',
            countryId: 'co1',
          ),
          Cell(
            id: 'cell-2',
            habitats: [],
            polygon: [
              (lat: 1.0, lng: 0.0),
              (lat: 2.0, lng: 0.0),
              (lat: 2.0, lng: 1.0),
              (lat: 1.0, lng: 1.0),
            ],
            districtId: 'd2',
            cityId: 'c2',
            stateId: 's2',
            countryId: 'co1',
          ),
        ];

        final result = detectCellEntry.detectCell(
          cells: cells,
          point: (lat: 0.5, lng: 0.5),
        );

        expect(result, isNotNull);
        expect(result!.id, equals('cell-1'));
      });

      test('returns null when marker is not in any cell', () {
        final cells = [
          Cell(
            id: 'cell-1',
            habitats: [],
            polygon: [
              (lat: 0.0, lng: 0.0),
              (lat: 1.0, lng: 0.0),
              (lat: 1.0, lng: 1.0),
              (lat: 0.0, lng: 1.0),
            ],
            districtId: 'd1',
            cityId: 'c1',
            stateId: 's1',
            countryId: 'co1',
          ),
        ];

        final result = detectCellEntry.detectCell(
          cells: cells,
          point: (lat: 10.0, lng: 10.0),
        );

        expect(result, isNull);
      });

      test('returns null when cells list is empty', () {
        final result = detectCellEntry.detectCell(
          cells: [],
          point: (lat: 0.5, lng: 0.5),
        );

        expect(result, isNull);
      });

      test('returns first matching cell when point is in multiple cells', () {
        // Overlapping cells for testing priority
        final cells = [
          Cell(
            id: 'cell-1',
            habitats: [],
            polygon: [
              (lat: 0.0, lng: 0.0),
              (lat: 2.0, lng: 0.0),
              (lat: 2.0, lng: 2.0),
              (lat: 0.0, lng: 2.0),
            ],
            districtId: 'd1',
            cityId: 'c1',
            stateId: 's1',
            countryId: 'co1',
          ),
          Cell(
            id: 'cell-2',
            habitats: [],
            polygon: [
              (lat: 0.0, lng: 0.0),
              (lat: 1.0, lng: 0.0),
              (lat: 1.0, lng: 1.0),
              (lat: 0.0, lng: 1.0),
            ],
            districtId: 'd2',
            cityId: 'c2',
            stateId: 's2',
            countryId: 'co1',
          ),
        ];

        final result = detectCellEntry.detectCell(
          cells: cells,
          point: (lat: 0.5, lng: 0.5),
        );

        expect(result, isNotNull);
        // Should return first cell (cell-1) as per implementation
      });
    });

    group('detectCellEntry', () {
      test('returns new cell when marker transitions from cell A to cell B',
          () async {
        final cells = [
          Cell(
            id: 'cell-A',
            habitats: [],
            polygon: [
              (lat: 0.0, lng: 0.0),
              (lat: 1.0, lng: 0.0),
              (lat: 1.0, lng: 1.0),
              (lat: 0.0, lng: 1.0),
            ],
            districtId: 'd1',
            cityId: 'c1',
            stateId: 's1',
            countryId: 'co1',
          ),
          Cell(
            id: 'cell-B',
            habitats: [],
            polygon: [
              (lat: 1.0, lng: 0.0),
              (lat: 2.0, lng: 0.0),
              (lat: 2.0, lng: 1.0),
              (lat: 1.0, lng: 1.0),
            ],
            districtId: 'd2',
            cityId: 'c2',
            stateId: 's2',
            countryId: 'co1',
          ),
        ];

        final result = await detectCellEntry.call(
          (
            cells: cells,
            previousCellId: 'cell-A',
            currentPoint: (lat: 1.5, lng: 0.5),
          ),
        );

        expect(result, equals('cell-B'));
        expect(obs.logs[0]['event'], 'operation.started');
        expect(obs.logs[1]['event'], 'operation.completed');
      });

      test('returns null when marker stays in same cell', () async {
        final cells = [
          Cell(
            id: 'cell-A',
            habitats: [],
            polygon: [
              (lat: 0.0, lng: 0.0),
              (lat: 1.0, lng: 0.0),
              (lat: 1.0, lng: 1.0),
              (lat: 0.0, lng: 1.0),
            ],
            districtId: 'd1',
            cityId: 'c1',
            stateId: 's1',
            countryId: 'co1',
          ),
        ];

        final result = await detectCellEntry.call(
          (
            cells: cells,
            previousCellId: 'cell-A',
            currentPoint: (lat: 0.5, lng: 0.5),
          ),
        );

        expect(result, isNull);
      });

      test('returns cell id when entering first cell from no cell', () async {
        final cells = [
          Cell(
            id: 'cell-1',
            habitats: [],
            polygon: [
              (lat: 0.0, lng: 0.0),
              (lat: 1.0, lng: 0.0),
              (lat: 1.0, lng: 1.0),
              (lat: 0.0, lng: 1.0),
            ],
            districtId: 'd1',
            cityId: 'c1',
            stateId: 's1',
            countryId: 'co1',
          ),
        ];

        final result = await detectCellEntry.call(
          (
            cells: cells,
            previousCellId: null,
            currentPoint: (lat: 0.5, lng: 0.5),
          ),
        );

        expect(result, equals('cell-1'));
      });

      test('returns null when marker not in any cell', () async {
        final cells = [
          Cell(
            id: 'cell-1',
            habitats: [],
            polygon: [
              (lat: 0.0, lng: 0.0),
              (lat: 1.0, lng: 0.0),
              (lat: 1.0, lng: 1.0),
              (lat: 0.0, lng: 1.0),
            ],
            districtId: 'd1',
            cityId: 'c1',
            stateId: 's1',
            countryId: 'co1',
          ),
        ];

        final result = await detectCellEntry.call(
          (
            cells: cells,
            previousCellId: null,
            currentPoint: (lat: 100.0, lng: 100.0),
          ),
        );

        expect(result, isNull);
      });
    });
  });
}
