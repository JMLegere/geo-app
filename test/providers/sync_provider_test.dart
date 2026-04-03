import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/data/database.dart';
import 'package:earth_nova/data/repos/write_queue_repo.dart';
import 'package:earth_nova/providers/database_provider.dart';
import 'package:earth_nova/providers/sync_provider.dart';

void main() {
  group('SyncNotifier — state transitions', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
      addTearDown(container.dispose);
    });

    test('initial state is idle with 0 pending and no error', () {
      final state = container.read(syncProvider);
      expect(state.status, SyncStatus.idle);
      expect(state.pendingCount, 0);
      expect(state.lastError, isNull);
    });

    test('setSyncing transitions to syncing status', () {
      container.read(syncProvider.notifier).setSyncing();
      expect(container.read(syncProvider).status, SyncStatus.syncing);
    });

    test('setIdle transitions back to idle and clears error', () {
      container.read(syncProvider.notifier).setSyncing();
      container.read(syncProvider.notifier).setError('something bad');
      container.read(syncProvider.notifier).setIdle();

      final state = container.read(syncProvider);
      expect(state.status, SyncStatus.idle);
      expect(state.lastError, isNull);
    });

    test('setError stores error message and transitions to error status', () {
      container.read(syncProvider.notifier).setError('Network timeout');

      final state = container.read(syncProvider);
      expect(state.status, SyncStatus.error);
      expect(state.lastError, 'Network timeout');
    });

    test('setIdle with pendingCount updates pending count', () {
      container.read(syncProvider.notifier).setIdle(pendingCount: 7);

      final state = container.read(syncProvider);
      expect(state.status, SyncStatus.idle);
      expect(state.pendingCount, 7);
    });
  });

  group('SyncNotifier — refreshPendingCount', () {
    late ProviderContainer container;

    setUp(() {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final repo = WriteQueueRepo(db);

      container = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
        writeQueueRepoProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);
    });

    test('refreshPendingCount reflects real queue count', () async {
      // Initially no pending entries.
      await container
          .read(syncProvider.notifier)
          .refreshPendingCount(userId: 'u_1');
      expect(container.read(syncProvider).pendingCount, 0);
    });
  });
}
