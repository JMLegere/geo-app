import 'package:flutter_test/flutter_test.dart';

import 'package:earth_nova/features/map/domain/services/explored_footprint_service.dart';

void main() {
  group('ExploredFootprintService', () {
    test('projects persisted and optimistic visits into one unique footprint', () {
      const service = ExploredFootprintService();

      final projection = service.project(
        persistedVisitedCellIds: {'cell-a', 'cell-b'},
        optimisticVisitedCellIds: {'cell-b', 'cell-c'},
      );

      expect(projection.visitedCellIds, {'cell-a', 'cell-b', 'cell-c'});
      expect(projection.uniqueCount, 3);
      expect(projection.persistedCount, 2);
      expect(projection.optimisticCount, 2);
      expect(projection.overlapCount, 1);
    });

    test('does not let callers mutate projected footprint state', () {
      const service = ExploredFootprintService();

      final projection = service.project(
        persistedVisitedCellIds: {'cell-a'},
        optimisticVisitedCellIds: {'cell-b'},
      );

      expect(
        () => projection.visitedCellIds.add('cell-c'),
        throwsUnsupportedError,
      );
    });

    test('wouldAddToFootprint describes derived unique footprint membership', () {
      const service = ExploredFootprintService();

      final projection = service.project(
        persistedVisitedCellIds: {'persisted-cell'},
        optimisticVisitedCellIds: {'optimistic-cell'},
      );

      expect(projection.wouldAddToFootprint('persisted-cell'), isFalse);
      expect(projection.wouldAddToFootprint('optimistic-cell'), isFalse);
      expect(projection.wouldAddToFootprint('new-cell'), isTrue);
    });

    test('exposes log data for QA count reconciliation', () {
      const service = ExploredFootprintService();

      final projection = service.project(
        persistedVisitedCellIds: {'cell-a', 'cell-b'},
        optimisticVisitedCellIds: {'cell-b', 'cell-c'},
      );

      expect(projection.toLogData(), {
        'footprint_unique_count': 3,
        'footprint_persisted_count': 2,
        'footprint_optimistic_count': 2,
        'footprint_overlap_count': 1,
      });
    });
  });
}
