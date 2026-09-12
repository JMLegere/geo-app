import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/features/map/domain/entities/cell_state.dart';
import 'package:earth_nova/features/map/domain/services/fog_state_service.dart';

import '../../tool/map_performance_fixture.dart';

void main() {
  test('deterministic organic cells share exact two-owner seams', () {
    final fixture = MapPerformanceFixture();
    expect(fixture.cells, hasLength(1000));
    expect(MapPerformanceFixture().cells, fixture.cells);
    final edges = <String, int>{};
    String coord(GeoCoord p) => '${p.lat},${p.lng}';
    for (final cell in fixture.cells) {
      final ring = cell.primaryExteriorRing;
      expect(ring.toSet().length, greaterThan(4));
      expect(cell.geometryGenerationMode, 'shared_vertex_warped_hex');
      for (var i = 0; i < ring.length; i++) {
        final endpoints = [coord(ring[i]), coord(ring[(i + 1) % ring.length])]
          ..sort();
        final edge = endpoints.join('|');
        edges[edge] = (edges[edge] ?? 0) + 1;
      }
    }
    expect(edges.values.every((count) => count <= 2), isTrue);
    expect(edges.values.where((count) => count == 2).length, greaterThan(2700));
  });

  test(
    'fixture seeds real visits and all four canonical knowledge states',
    () async {
      final fixture = MapPerformanceFixture();
      await fixture.seedVisits();
      final visits = await fixture.repository.getVisitedCellIds(fixture.userId);
      expect(visits, fixture.exploredCellIds);
      final states = const FogStateService().compute(
        cells: fixture.cells,
        currentCellId: fixture.currentCellId,
        exploredCellIds: visits,
        knowledgeByCellId: fixture.knowledgeByCellId,
      );
      expect(
        states.map((entry) => entry.state.knowledgeState).toSet(),
        CellKnowledgeState.values.toSet(),
      );
      expect(
        states
            .where(
              (entry) =>
                  entry.state.knowledgeState == CellKnowledgeState.present,
            )
            .single
            .cell
            .id,
        fixture.currentCellId,
      );
      final unvisited = fixture.cells.firstWhere(
        (cell) => !visits.contains(cell.id),
      );
      await fixture.repository.recordVisit(
        fixture.userId,
        unvisited.id,
        'fixture-new-visit',
      );
      expect(
        await fixture.repository.isFirstVisit(fixture.userId, unvisited.id),
        isFalse,
      );
      expect(await fixture.repository.getVisitedCellIds(fixture.userId), {
        ...fixture.exploredCellIds,
        unvisited.id,
      });
    },
  );
}
