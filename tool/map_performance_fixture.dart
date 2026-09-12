import 'dart:math' as math;

import 'package:earth_nova/core/domain/entities/habitat.dart';
import 'package:earth_nova/features/map/data/repositories/mock_cell_repository.dart';
import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/features/map/domain/entities/cell_knowledge_projection.dart';
import 'package:earth_nova/features/map/domain/entities/cell_state.dart';
import 'package:earth_nova/features/map/domain/repositories/cell_knowledge_repository.dart';

/// Local-only deterministic shared-vertex tessellation, deliberately not labeled
/// Voronoi. Integer vertex keys preserve exact seams after the nonlinear warp.
class MapPerformanceFixture implements CellKnowledgeRepository {
  MapPerformanceFixture() {
    final vertices = <(int, int), GeoCoord>{};
    GeoCoord vertex(int x, int y) => vertices.putIfAbsent((x, y), () {
      final jitter = math.Random(x * 73856093 ^ y * 19349663 ^ 605);
      final east =
          (x - 60) * 18.0 +
          math.sin(y * .47) * 15 +
          (jitter.nextDouble() - .5) * 12;
      final north =
          (y - 25) * math.sqrt(3) * 18.0 +
          math.sin(x * .23) * 15 +
          (jitter.nextDouble() - .5) * 12;
      return (
        lat: 45.9636 + north / 111320,
        lng: -66.6431 + east / (111320 * math.cos(45.9636 * math.pi / 180)),
      );
    });
    cells = [
      for (var row = 0; row < 25; row++)
        for (var column = 0; column < 40; column++)
          Cell(
            id: 'perf-$row-$column',
            habitats: [Habitat.values[(row + column) % Habitat.values.length]],
            polygons: [
              [
                [
                  for (final delta in const [
                    (2, 0),
                    (1, 1),
                    (-1, 1),
                    (-2, 0),
                    (-1, -1),
                    (1, -1),
                  ])
                    vertex(
                      3 * column + delta.$1,
                      2 * row + column % 2 + delta.$2,
                    ),
                ],
              ],
            ],
            districtId: 'perf-district',
            cityId: 'perf-city',
            stateId: 'perf-state',
            countryId: 'perf-country',
            geometryGenerationMode: 'shared_vertex_warped_hex',
            geometrySourceVersion: 'local-perf-605-v1',
            habitatConfidence: 'manual_override',
          ),
    ];
    repository = MockCellRepository(cells: cells);
    exploredCellIds = {
      for (var row = 9; row <= 15; row++)
        for (var column = 17; column <= 22; column++) 'perf-$row-$column',
    };
    knowledgeByCellId = {
      for (var row = 10; row <= 14; row++)
        'perf-$row-24': CellKnowledgeProjection(
          cellId: 'perf-$row-24',
          state: CellKnowledgeState.informed,
          category: 'flora',
        ),
    };
    final ring = cells
        .firstWhere((cell) => cell.id == currentCellId)
        .primaryExteriorRing;
    start = (
      lat: ring.fold(0.0, (sum, point) => sum + point.lat) / ring.length,
      lng: ring.fold(0.0, (sum, point) => sum + point.lng) / ring.length,
    );
  }

  final String userId = 'mock_0000000605';
  final String currentCellId = 'perf-12-20';
  late final GeoCoord start;
  late final List<Cell> cells;
  late final Set<String> exploredCellIds;
  late final Map<String, CellKnowledgeProjection> knowledgeByCellId;
  late final MockCellRepository repository;

  Future<void> seedVisits() async {
    for (final id in exploredCellIds) {
      await repository.recordVisit(userId, id, 'seed-$id');
    }
  }

  @override
  Future<Map<String, CellKnowledgeProjection>> fetchForCells(
    Iterable<String> cellIds, {
    String? traceId,
  }) async => {
    for (final id in cellIds)
      if (knowledgeByCellId[id] case final projection?) id: projection,
  };
}
