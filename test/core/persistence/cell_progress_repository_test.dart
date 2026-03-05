import 'package:flutter_test/flutter_test.dart';
import 'package:fog_of_world/core/models/fog_state.dart';
import 'package:fog_of_world/core/persistence/cell_progress_repository.dart';
import 'test_helpers.dart';

void main() {
  group('CellProgressRepository', () {
    late CellProgressRepository repo;

    setUp(() async {
      final db = createTestDatabase();
      repo = CellProgressRepository(db);
    });

    test('create and read cell progress', () async {
      const userId = 'user123';
      const cellId = 'cell456';

      // Create
      await repo.create(
        id: 'progress1',
        userId: userId,
        cellId: cellId,
        fogState: FogState.undetected,
        distanceWalked: 0.0,
        visitCount: 0,
      );

      // Read
      final progress = await repo.read(userId, cellId);

      expect(progress, isNotNull);
      expect(progress!.userId, userId);
      expect(progress.cellId, cellId);
      expect(progress.fogState, 'undetected');
      expect(progress.distanceWalked, 0.0);
      expect(progress.visitCount, 0);
    });

    test('update cell progress fog state', () async {
      const userId = 'user123';
      const cellId = 'cell456';

      // Create
      await repo.create(
        id: 'progress1',
        userId: userId,
        cellId: cellId,
        fogState: FogState.undetected,
      );

      // Update fog state
      await repo.updateFogState(userId, cellId, FogState.unexplored);

      // Verify
      final progress = await repo.read(userId, cellId);
      expect(progress!.fogState, 'unexplored');
    });

    test('add distance to cell progress', () async {
      const userId = 'user123';
      const cellId = 'cell456';

      // Create
      await repo.create(
        id: 'progress1',
        userId: userId,
        cellId: cellId,
        fogState: FogState.undetected,
        distanceWalked: 10.0,
      );

      // Add distance
      await repo.addDistance(userId, cellId, 5.0);

      // Verify
      final progress = await repo.read(userId, cellId);
      expect(progress!.distanceWalked, 15.0);
    });

    test('increment visit count', () async {
      const userId = 'user123';
      const cellId = 'cell456';

      // Create
      await repo.create(
        id: 'progress1',
        userId: userId,
        cellId: cellId,
        fogState: FogState.undetected,
        visitCount: 0,
      );

      // Increment
      await repo.incrementVisitCount(userId, cellId);
      await repo.incrementVisitCount(userId, cellId);

      // Verify
      final progress = await repo.read(userId, cellId);
      expect(progress!.visitCount, 2);
    });

    test('delete cell progress', () async {
      const userId = 'user123';
      const cellId = 'cell456';

      // Create
      await repo.create(
        id: 'progress1',
        userId: userId,
        cellId: cellId,
        fogState: FogState.undetected,
      );

      // Delete
      final deleted = await repo.delete(userId, cellId);

      // Verify
      expect(deleted, 1);
      final progress = await repo.read(userId, cellId);
      expect(progress, isNull);
    });

    test('read all cell progress by user', () async {
      const userId = 'user123';

      // Create multiple records
      await repo.create(
        id: 'progress1',
        userId: userId,
        cellId: 'cell1',
        fogState: FogState.undetected,
      );
      await repo.create(
        id: 'progress2',
        userId: userId,
        cellId: 'cell2',
        fogState: FogState.unexplored,
      );
      await repo.create(
        id: 'progress3',
        userId: 'other_user',
        cellId: 'cell3',
        fogState: FogState.hidden,
      );

      // Read by user
      final userProgress = await repo.readByUser(userId);

      expect(userProgress.length, 2);
      expect(userProgress.map((p) => p.cellId).toList(), ['cell1', 'cell2']);
    });

    test('get cells by fog state', () async {
      const userId = 'user123';

      // Create cells with different fog states
      await repo.create(
        id: 'progress1',
        userId: userId,
        cellId: 'cell1',
        fogState: FogState.undetected,
      );
      await repo.create(
        id: 'progress2',
        userId: userId,
        cellId: 'cell2',
        fogState: FogState.unexplored,
      );
      await repo.create(
        id: 'progress3',
        userId: userId,
        cellId: 'cell3',
        fogState: FogState.unexplored,
      );

      // Query by state
      final unexploredCells =
          await repo.getCellsByFogState(userId, FogState.unexplored);

      expect(unexploredCells.length, 2);
    });

    test('get cell count by fog state', () async {
      const userId = 'user123';

      // Create cells with different fog states
      await repo.create(
        id: 'progress1',
        userId: userId,
        cellId: 'cell1',
        fogState: FogState.undetected,
      );
      await repo.create(
        id: 'progress2',
        userId: userId,
        cellId: 'cell2',
        fogState: FogState.unexplored,
      );
      await repo.create(
        id: 'progress3',
        userId: userId,
        cellId: 'cell3',
        fogState: FogState.unexplored,
      );
      await repo.create(
        id: 'progress4',
        userId: userId,
        cellId: 'cell4',
        fogState: FogState.observed,
      );

      // Get counts
      final counts = await repo.getCellCountByFogState(userId);

      expect(counts[FogState.undetected], 1);
      expect(counts[FogState.unexplored], 2);
      expect(counts[FogState.hidden], 0);
      expect(counts[FogState.concealed], 0);
      expect(counts[FogState.observed], 1);
    });

    test('concurrent writes do not lose data', () async {
      const userId = 'user123';

      // Create 100 cell progress records concurrently
      final futures = <Future<void>>[];
      for (int i = 0; i < 100; i++) {
        futures.add(
          repo.create(
            id: 'progress$i',
            userId: userId,
            cellId: 'cell$i',
            fogState: FogState.undetected,
          ),
        );
      }

      await Future.wait(futures);

      // Verify all records were created
      final allProgress = await repo.readByUser(userId);
      expect(allProgress.length, 100);
    });

    test('fog state progression is correct', () async {
      const userId = 'user123';
      const cellId = 'cell456';

      // Create with undetected
      await repo.create(
        id: 'progress1',
        userId: userId,
        cellId: cellId,
        fogState: FogState.undetected,
      );

      // Progress through states
      for (final state in [
        FogState.unexplored,
        FogState.hidden,
        FogState.concealed,
        FogState.observed,
      ]) {
        await repo.updateFogState(userId, cellId, state);
        final progress = await repo.read(userId, cellId);
        expect(progress!.fogState, state.name);
      }
    });

    test('get fog state returns correct enum', () async {
      const userId = 'user123';
      const cellId = 'cell456';

      // Create
      await repo.create(
        id: 'progress1',
        userId: userId,
        cellId: cellId,
        fogState: FogState.hidden,
      );

      // Get fog state
      final state = await repo.getFogState(userId, cellId);

      expect(state, FogState.hidden);
      expect(state!.density, 0.5);
    });
  });
}
