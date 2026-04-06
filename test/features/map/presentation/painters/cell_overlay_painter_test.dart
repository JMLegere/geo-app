import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/domain/entities/habitat.dart';
import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/features/map/domain/entities/cell_state.dart';
import 'package:earth_nova/features/map/presentation/painters/cell_overlay_painter.dart';

void main() {
  group('CellOverlayPainter', () {
    test('should create with required parameters', () {
      final painter = CellOverlayPainter(
        cellsWithStates: [],
        cameraPosition: (lat: 0.0, lng: 0.0),
        zoom: 15.0,
        cameraPixelOffset: Offset.zero,
      );

      expect(painter, isNotNull);
      expect(painter.cellsWithStates, isEmpty);
      expect(painter.zoom, 15.0);
    });

    test('shouldRepaint returns true when cells change', () {
      final cell = _createTestCell('cell-1');
      final state = const CellState(
        relationship: CellRelationship.nearby,
        contents: CellContents.empty,
      );

      final painter1 = CellOverlayPainter(
        cellsWithStates: [(cell: cell, state: state)],
        cameraPosition: (lat: 0.0, lng: 0.0),
        zoom: 15.0,
        cameraPixelOffset: Offset.zero,
      );

      final painter2 = CellOverlayPainter(
        cellsWithStates: [],
        cameraPosition: (lat: 0.0, lng: 0.0),
        zoom: 15.0,
        cameraPixelOffset: Offset.zero,
      );

      expect(painter1.shouldRepaint(painter2), isTrue);
    });

    test('shouldRepaint returns true when camera position changes', () {
      final painter1 = CellOverlayPainter(
        cellsWithStates: [],
        cameraPosition: (lat: 0.0, lng: 0.0),
        zoom: 15.0,
        cameraPixelOffset: Offset.zero,
      );

      final painter2 = CellOverlayPainter(
        cellsWithStates: [],
        cameraPosition: (lat: 1.0, lng: 1.0),
        zoom: 15.0,
        cameraPixelOffset: Offset.zero,
      );

      expect(painter1.shouldRepaint(painter2), isTrue);
    });

    test('shouldRepaint returns true when zoom changes', () {
      final painter1 = CellOverlayPainter(
        cellsWithStates: [],
        cameraPosition: (lat: 0.0, lng: 0.0),
        zoom: 15.0,
        cameraPixelOffset: Offset.zero,
      );

      final painter2 = CellOverlayPainter(
        cellsWithStates: [],
        cameraPosition: (lat: 0.0, lng: 0.0),
        zoom: 16.0,
        cameraPixelOffset: Offset.zero,
      );

      expect(painter1.shouldRepaint(painter2), isTrue);
    });

    test('shouldRepaint returns true when camera offset changes', () {
      final painter1 = CellOverlayPainter(
        cellsWithStates: [],
        cameraPosition: (lat: 0.0, lng: 0.0),
        zoom: 15.0,
        cameraPixelOffset: Offset.zero,
      );

      final painter2 = CellOverlayPainter(
        cellsWithStates: [],
        cameraPosition: (lat: 0.0, lng: 0.0),
        zoom: 15.0,
        cameraPixelOffset: const Offset(100, 100),
      );

      expect(painter1.shouldRepaint(painter2), isTrue);
    });

    test('shouldRepaint returns false when nothing changes', () {
      final cell = _createTestCell('cell-1');
      final state = const CellState(
        relationship: CellRelationship.nearby,
        contents: CellContents.empty,
      );
      final cellsWithStates = [(cell: cell, state: state)];

      final painter1 = CellOverlayPainter(
        cellsWithStates: cellsWithStates,
        cameraPosition: (lat: 0.0, lng: 0.0),
        zoom: 15.0,
        cameraPixelOffset: Offset.zero,
      );

      final painter2 = CellOverlayPainter(
        cellsWithStates: cellsWithStates,
        cameraPosition: (lat: 0.0, lng: 0.0),
        zoom: 15.0,
        cameraPixelOffset: Offset.zero,
      );

      expect(painter1.shouldRepaint(painter2), isFalse);
    });
  });
}

Cell _createTestCell(String id) {
  return Cell(
    id: id,
    habitats: [Habitat.forest],
    polygon: const [
      (lat: 0.0, lng: 0.0),
      (lat: 0.001, lng: 0.0),
      (lat: 0.001, lng: 0.001),
      (lat: 0.0, lng: 0.001),
    ],
    districtId: 'district-1',
    cityId: 'city-1',
    stateId: 'state-1',
    countryId: 'country-1',
  );
}
