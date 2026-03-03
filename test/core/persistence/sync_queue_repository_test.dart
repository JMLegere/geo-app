import 'package:flutter_test/flutter_test.dart';
import 'package:fog_of_world/core/persistence/sync_queue_repository.dart';
import 'test_helpers.dart';

void main() {
  group('SyncQueueRepository', () {
    late SyncQueueRepository repo;

    setUp(() async {
      final db = createTestDatabase();
      repo = SyncQueueRepository(db);
    });

    test('enqueue insert action', () async {
      final data = {'id': 'cell1', 'userId': 'user1', 'fogState': 'undetected'};

      // Enqueue
      final eventId = await repo.enqueueInsert(
        tableName: 'cell_progress',
        data: data,
      );

      expect(eventId, greaterThan(0));

      // Verify
      final pending = await repo.getPending();
      expect(pending.length, 1);
      expect(pending.first.action, 'insert');
      expect(pending.first.targetTable, 'cell_progress');
    });

    test('enqueue update action', () async {
      final data = {'id': 'cell1', 'fogState': 'unexplored'};

      // Enqueue
      final eventId = await repo.enqueueUpdate(
        tableName: 'cell_progress',
        data: data,
      );

      expect(eventId, greaterThan(0));

      // Verify
      final pending = await repo.getPending();
      expect(pending.first.action, 'update');
    });

    test('enqueue delete action', () async {
      final data = {'id': 'cell1'};

      // Enqueue
      final eventId = await repo.enqueueDelete(
        tableName: 'cell_progress',
        data: data,
      );

      expect(eventId, greaterThan(0));

      // Verify
      final pending = await repo.getPending();
      expect(pending.first.action, 'delete');
    });

    test('dequeue removes event', () async {
      final data = {'id': 'cell1'};

      // Enqueue
      final eventId = await repo.enqueueInsert(
        tableName: 'cell_progress',
        data: data,
      );

      // Dequeue
      final deleted = await repo.dequeue(eventId);

      expect(deleted, 1);

      // Verify
      final pending = await repo.getPending();
      expect(pending.length, 0);
    });

    test('dequeue batch removes multiple events', () async {
      // Enqueue multiple events
      final id1 = await repo.enqueueInsert(
        tableName: 'cell_progress',
        data: {'id': 'cell1'},
      );
      final id2 = await repo.enqueueInsert(
        tableName: 'cell_progress',
        data: {'id': 'cell2'},
      );
      final id3 = await repo.enqueueInsert(
        tableName: 'cell_progress',
        data: {'id': 'cell3'},
      );

      // Dequeue batch
      final deleted = await repo.dequeueBatch([id1, id3]);

      expect(deleted, 2);

      // Verify
      final pending = await repo.getPending();
      expect(pending.length, 1);
      expect(pending.first.id, id2);
    });

    test('clear removes all events', () async {
      // Enqueue multiple events
      await repo.enqueueInsert(
        tableName: 'cell_progress',
        data: {'id': 'cell1'},
      );
      await repo.enqueueInsert(
        tableName: 'cell_progress',
        data: {'id': 'cell2'},
      );

      // Clear
      final deleted = await repo.clear();

      expect(deleted, 2);

      // Verify
      final pending = await repo.getPending();
      expect(pending.length, 0);
    });

    test('get size returns queue size', () async {
      // Enqueue events
      await repo.enqueueInsert(
        tableName: 'cell_progress',
        data: {'id': 'cell1'},
      );
      await repo.enqueueInsert(
        tableName: 'cell_progress',
        data: {'id': 'cell2'},
      );

      // Get size
      final size = await repo.getSize();

      expect(size, 2);
    });

    test('is empty returns correct status', () async {
      // Initially empty
      var isEmpty = await repo.isEmpty();
      expect(isEmpty, true);

      // Enqueue event
      await repo.enqueueInsert(
        tableName: 'cell_progress',
        data: {'id': 'cell1'},
      );

      // Not empty
      isEmpty = await repo.isEmpty();
      expect(isEmpty, false);
    });

    test('get by action filters correctly', () async {
      // Enqueue different actions
      await repo.enqueueInsert(
        tableName: 'cell_progress',
        data: {'id': 'cell1'},
      );
      await repo.enqueueUpdate(
        tableName: 'cell_progress',
        data: {'id': 'cell2'},
      );
      await repo.enqueueInsert(
        tableName: 'cell_progress',
        data: {'id': 'cell3'},
      );

      // Get by action
      final inserts = await repo.getByAction('insert');
      final updates = await repo.getByAction('update');

      expect(inserts.length, 2);
      expect(updates.length, 1);
    });

    test('get pending by table filters correctly', () async {
      // Enqueue for different tables
      await repo.enqueueInsert(
        tableName: 'cell_progress',
        data: {'id': 'cell1'},
      );
      await repo.enqueueInsert(
        tableName: 'collected_species',
        data: {'id': 'species1'},
      );
      await repo.enqueueInsert(
        tableName: 'cell_progress',
        data: {'id': 'cell2'},
      );

      // Get by table
      final cellProgress = await repo.getPendingByTable('cell_progress');
      final species = await repo.getPendingByTable('collected_species');

      expect(cellProgress.length, 2);
      expect(species.length, 1);
    });

    test('parse data decodes JSON correctly', () async {
      final data = {'id': 'cell1', 'fogState': 'undetected', 'distance': 10.5};

      // Enqueue
      await repo.enqueueInsert(
        tableName: 'cell_progress',
        data: data,
      );

      // Get and parse
      final pending = await repo.getPending();
      final parsed = SyncQueueRepository.parseData(pending.first);

      expect(parsed['id'], 'cell1');
      expect(parsed['fogState'], 'undetected');
      expect(parsed['distance'], 10.5);
    });

    test('get summary counts actions by table', () async {
      // Enqueue various events
      await repo.enqueueInsert(
        tableName: 'cell_progress',
        data: {'id': 'cell1'},
      );
      await repo.enqueueInsert(
        tableName: 'cell_progress',
        data: {'id': 'cell2'},
      );
      await repo.enqueueUpdate(
        tableName: 'cell_progress',
        data: {'id': 'cell3'},
      );
      await repo.enqueueInsert(
        tableName: 'collected_species',
        data: {'id': 'species1'},
      );

      // Get summary
      final summary = await repo.getSummary();

      expect(summary['insert_cell_progress'], 2);
      expect(summary['update_cell_progress'], 1);
      expect(summary['insert_collected_species'], 1);
    });

    test('concurrent enqueues do not lose data', () async {
      // Enqueue 100 events concurrently
      final futures = <Future<int>>[];
      for (int i = 0; i < 100; i++) {
        futures.add(
          repo.enqueueInsert(
            tableName: 'cell_progress',
            data: {'id': 'cell$i'},
          ),
        );
      }

      await Future.wait(futures);

      // Verify all were enqueued
      final size = await repo.getSize();
      expect(size, 100);
    });

    test('complex data structures are preserved', () async {
      final complexData = {
        'id': 'cell1',
        'userId': 'user123',
        'metadata': {
          'fogState': 'undetected',
          'distance': 10.5,
          'visited': true,
        },
        'tags': ['forest', 'explored'],
      };

      // Enqueue
      await repo.enqueueInsert(
        tableName: 'cell_progress',
        data: complexData,
      );

      // Get and parse
      final pending = await repo.getPending();
      final parsed = SyncQueueRepository.parseData(pending.first);

      expect(parsed['id'], 'cell1');
      expect(parsed['metadata']['fogState'], 'undetected');
      expect(parsed['metadata']['distance'], 10.5);
      expect(parsed['tags'], ['forest', 'explored']);
    });

    test('get oldest returns null when queue is empty', () async {
      final oldest = await repo.getOldest();
      expect(oldest, isNull);
    });
  });
}
