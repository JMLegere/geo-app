import 'dart:io';
import 'dart:ui' as ui;
import 'dart:ui' show Size;

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

    test('can use a caller-provided exact screen projector', () {
      final painter = CellOverlayPainter(
        cellsWithStates: [],
        project: (_) => const Offset(12, 34),
        projectionRevision: 7,
      );

      expect(painter.project, isNotNull);
      expect(painter.projectionRevision, 7);
    });

    test('shouldRepaint returns true when cells change', () {
      final cell = _createTestCell('cell-1');
      final state = const CellState(
        relationship: CellRelationship.frontier,
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
        relationship: CellRelationship.frontier,
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

    test('paints an unknown backdrop layer behind fetched cell fills', () {
      final source = File(
        'lib/features/map/presentation/painters/cell_overlay_painter.dart',
      ).readAsStringSync();

      expect(source, contains('canvas.saveLayer'));
      expect(source, contains('CellRelationship.unknown'));
      expect(source, contains('BlendMode.src'));
      expect(source, contains('canvas.restore'));
    });

    test(
        'Informed paints exactly one category cue with category-only semantics',
        () async {
      final informed = _knowledgeState(
        CellKnowledgeState.informed,
        category: 'fauna',
      );
      final painter = CellOverlayPainter(
        cellsWithStates: [
          (cell: _createTestCell('informed-cell'), state: informed),
        ],
        project: _testProjector,
      );

      final semanticsBuilder = painter.semanticsBuilder;
      expect(semanticsBuilder, isNotNull);
      final semantics = semanticsBuilder(const Size(64, 64));
      final labels = semantics
          .map((node) => node.properties.label)
          .whereType<String>()
          .toList();

      expect(labels, ['Informed: fauna']);
      expect(
        labels.join(' '),
        isNot(matches(
          RegExp(
            r'encounter|amberwing|outcome|reward',
            caseSensitive: false,
          ),
        )),
      );
      expect(
        await _paintBytes(informed),
        isNot(await _paintBytes(_knowledgeState(CellKnowledgeState.explored))),
        reason: 'The one category cue is the only visual delta from Explored.',
      );
    });

    test('legacy hasLoot paints no star or other compatibility decoration',
        () async {
      final emptyBytes = await _paintBytes(
        _knowledgeState(CellKnowledgeState.explored),
      );
      final legacyLootBytes = await _paintBytes(
        _knowledgeState(
          CellKnowledgeState.explored,
          contents: CellContents.hasLoot,
        ),
      );

      expect(legacyLootBytes, emptyBytes);
    });
  });
}

Cell _createTestCell(String id) {
  return Cell(
    id: id,
    habitats: [Habitat.forest],
    polygons: const [
      [
        [
          (lat: 0.0, lng: 0.0),
          (lat: 0.001, lng: 0.0),
          (lat: 0.001, lng: 0.001),
          (lat: 0.0, lng: 0.001),
        ],
      ],
    ],
    districtId: 'district-1',
    cityId: 'city-1',
    stateId: 'state-1',
    countryId: 'country-1',
  );
}

CellState _knowledgeState(
  CellKnowledgeState knowledgeState, {
  String? category,
  CellContents contents = CellContents.empty,
}) =>
    CellState(
      knowledgeState: knowledgeState,
      category: category,
      relationship: switch (knowledgeState) {
        CellKnowledgeState.present => CellRelationship.present,
        CellKnowledgeState.explored => CellRelationship.explored,
        CellKnowledgeState.informed => CellRelationship.frontier,
        CellKnowledgeState.shrouded => CellRelationship.unknown,
      },
      contents: contents,
    );

Offset _testProjector(({double lat, double lng}) coord) {
  return Offset(12 + coord.lng * 40000, 12 + coord.lat * 40000);
}

Future<List<int>> _paintBytes(CellState state) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  CellOverlayPainter(
    cellsWithStates: [(cell: _createTestCell('paint-cell'), state: state)],
    project: _testProjector,
  ).paint(canvas, const Size(64, 64));
  final image = await recorder.endRecording().toImage(64, 64);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    return data!.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}
