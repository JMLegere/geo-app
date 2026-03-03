import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fog_of_world/core/database/app_database.dart';
import 'package:fog_of_world/core/persistence/sync_queue_repository.dart';
import 'package:fog_of_world/features/auth/providers/auth_provider.dart';
import 'package:fog_of_world/features/sync/models/sync_status.dart';
import 'package:fog_of_world/features/sync/providers/sync_provider.dart';
import 'package:fog_of_world/features/sync/services/mock_cloud_sync_client.dart';
import 'package:fog_of_world/features/sync/services/sync_service.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

AppDatabase _testDb() => AppDatabase(NativeDatabase.memory());

SyncService _testService({
  MockCloudSyncClient? client,
  bool simulateError = false,
}) {
  final db = _testDb();
  final c = client ?? MockCloudSyncClient();
  if (simulateError) c.simulateError = true;
  return SyncService(
    cloudClient: c,
    syncQueueRepository: SyncQueueRepository(db),
    db: db,
  );
}

/// Creates a container with [syncServiceProvider] overridden and waits for
/// the auth initial session check to settle.
Future<ProviderContainer> _makeContainer(SyncService service) async {
  final container = ProviderContainer(
    overrides: [
      syncServiceProvider.overrideWithValue(service),
    ],
  );
  // Wait for AuthNotifier._checkExistingSession() to complete.
  container.read(authProvider);
  await Future<void>.delayed(Duration.zero);
  return container;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('SyncNotifier', () {
    // ── initial state ─────────────────────────────────────────────────────────

    test('initial state is idle with 0 pending changes', () async {
      final container = await _makeContainer(_testService());
      addTearDown(container.dispose);

      final state = container.read(syncProvider);

      expect(state.type, SyncStatusType.idle);
      expect(state.pendingChanges, 0);
      expect(state.lastSyncedAt, isNull);
      expect(state.errorMessage, isNull);
    });

    // ── syncNow → success ─────────────────────────────────────────────────────

    test('syncNow transitions through syncing → success for authenticated user',
        () async {
      final container = await _makeContainer(_testService());
      addTearDown(container.dispose);

      // Sign up and authenticate.
      await container.read(authProvider.notifier).signUp(
            email: 'user@example.com',
            password: 'pass123',
          );

      final states = <SyncStatusType>[];
      container.listen(syncProvider, (_, next) => states.add(next.type));

      await container.read(syncProvider.notifier).syncNow();

      expect(states, contains(SyncStatusType.syncing));
      expect(states.last, SyncStatusType.success);
    });

    test('syncNow sets lastSyncedAt on success', () async {
      final container = await _makeContainer(_testService());
      addTearDown(container.dispose);

      await container.read(authProvider.notifier).signUp(
            email: 'user@example.com',
            password: 'pass123',
          );

      await container.read(syncProvider.notifier).syncNow();

      final state = container.read(syncProvider);
      expect(state.type, SyncStatusType.success);
      expect(state.lastSyncedAt, isNotNull);
      expect(state.errorMessage, isNull);
    });

    // ── syncNow → error ───────────────────────────────────────────────────────

    test('syncNow transitions to error when sync service fails', () async {
      final container =
          await _makeContainer(_testService(simulateError: true));
      addTearDown(container.dispose);

      await container.read(authProvider.notifier).signUp(
            email: 'user@example.com',
            password: 'pass123',
          );

      await container.read(syncProvider.notifier).syncNow();

      final state = container.read(syncProvider);
      expect(state.type, SyncStatusType.error);
      expect(state.errorMessage, isNotNull);
    });

    // ── syncNow → guest ───────────────────────────────────────────────────────

    test('syncNow with guest user transitions to error state', () async {
      final container = await _makeContainer(_testService());
      addTearDown(container.dispose);

      container.read(authProvider.notifier).continueAsGuest();

      await container.read(syncProvider.notifier).syncNow();

      final state = container.read(syncProvider);
      expect(state.type, SyncStatusType.error);
      expect(state.errorMessage, contains('Sign in'));
    });

    test('syncNow with unauthenticated user transitions to error state',
        () async {
      final container = await _makeContainer(_testService());
      addTearDown(container.dispose);

      // Container starts unauthenticated after session check.
      await container.read(syncProvider.notifier).syncNow();

      final state = container.read(syncProvider);
      expect(state.type, SyncStatusType.error);
      expect(state.errorMessage, contains('Sign in'));
    });

    // ── refreshPendingCount ───────────────────────────────────────────────────

    test('refreshPendingCount updates pendingChanges in state', () async {
      final db = _testDb();
      final repo = SyncQueueRepository(db);
      final service = SyncService(
        cloudClient: MockCloudSyncClient(),
        syncQueueRepository: repo,
        db: db,
      );
      final container = await _makeContainer(service);
      addTearDown(container.dispose);

      // Seed the queue directly.
      await repo.enqueueInsert(
        tableName: 'cell_progress',
        data: {
          'id': 'cp1',
          'userId': 'user1',
          'cellId': 'cell1',
          'fogState': 'observed',
          'distanceWalked': 0.0,
          'visitCount': 1,
          'restorationLevel': 0.0,
          'createdAt': '2026-01-01T00:00:00.000Z',
          'updatedAt': '2026-01-01T00:00:00.000Z',
        },
      );

      await container.read(syncProvider.notifier).refreshPendingCount();

      final state = container.read(syncProvider);
      expect(state.pendingChanges, 1);
    });

    test('refreshPendingCount reports 0 when queue is empty', () async {
      final container = await _makeContainer(_testService());
      addTearDown(container.dispose);

      await container.read(syncProvider.notifier).refreshPendingCount();

      expect(container.read(syncProvider).pendingChanges, 0);
    });
  });
}
