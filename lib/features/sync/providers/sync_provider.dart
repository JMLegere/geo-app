import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fog_of_world/core/database/app_database.dart';
import 'package:fog_of_world/core/persistence/sync_queue_repository.dart';
import 'package:fog_of_world/features/auth/models/auth_state.dart';
import 'package:fog_of_world/features/auth/providers/auth_provider.dart';
import 'package:fog_of_world/features/sync/models/sync_exception.dart';
import 'package:fog_of_world/features/sync/models/sync_status.dart';
import 'package:fog_of_world/features/sync/services/mock_cloud_sync_client.dart';
import 'package:fog_of_world/features/sync/services/sync_service.dart';

// ── Infrastructure providers (dev defaults, override in production) ──────────

/// In-memory database for development. Override with a file-backed
/// [AppDatabase] in production so data persists across restarts.
final _appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase(NativeDatabase.memory());
  ref.onDispose(db.close);
  return db;
});

final _syncQueueRepositoryProvider = Provider<SyncQueueRepository>((ref) {
  return SyncQueueRepository(ref.watch(_appDatabaseProvider));
});

/// [SyncService] wired up with [MockCloudSyncClient] for development.
///
/// Override this provider with a [SyncService] backed by
/// `SupabaseCloudSyncClient` when Supabase credentials are available.
final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(
    cloudClient: MockCloudSyncClient(),
    syncQueueRepository: ref.watch(_syncQueueRepositoryProvider),
    db: ref.watch(_appDatabaseProvider),
  );
});

// ── SyncNotifier ─────────────────────────────────────────────────────────────

/// Manages all sync state transitions for the UI.
///
/// Call [syncNow] to trigger a manual upload/download cycle.
/// Call [refreshPendingCount] to update [SyncStatus.pendingChanges].
class SyncNotifier extends Notifier<SyncStatus> {
  late SyncService _syncService;

  @override
  SyncStatus build() {
    _syncService = ref.watch(syncServiceProvider);
    return const SyncStatus(type: SyncStatusType.idle);
  }

  /// Uploads all pending local changes and pulls remote data.
  ///
  /// Transitions: idle → syncing → success | error.
  /// Returns immediately with an error state if the user is not authenticated.
  Future<void> syncNow() async {
    final authState = ref.read(authProvider);

    if (authState.status != AuthStatus.authenticated ||
        authState.user == null) {
      state = SyncStatus(
        type: SyncStatusType.error,
        lastSyncedAt: state.lastSyncedAt,
        errorMessage: 'Sign in to enable cloud sync',
        pendingChanges: state.pendingChanges,
      );
      return;
    }

    state = SyncStatus(
      type: SyncStatusType.syncing,
      lastSyncedAt: state.lastSyncedAt,
      pendingChanges: state.pendingChanges,
    );

    try {
      final result = await _syncService.syncAll(authState.user!.id);

      if (result.isSuccess) {
        state = SyncStatus(
          type: SyncStatusType.success,
          lastSyncedAt: DateTime.now(),
          pendingChanges: 0,
        );
      } else {
        state = SyncStatus(
          type: SyncStatusType.error,
          lastSyncedAt: state.lastSyncedAt,
          errorMessage: result.errorMessage ?? 'Sync failed',
          pendingChanges: state.pendingChanges,
        );
      }
    } on SyncException catch (e) {
      state = SyncStatus(
        type: SyncStatusType.error,
        lastSyncedAt: state.lastSyncedAt,
        errorMessage: e.message,
        pendingChanges: state.pendingChanges,
      );
    } catch (_) {
      state = SyncStatus(
        type: SyncStatusType.error,
        lastSyncedAt: state.lastSyncedAt,
        errorMessage: 'An unexpected error occurred during sync',
        pendingChanges: state.pendingChanges,
      );
    }

    await refreshPendingCount();
  }

  /// Refreshes [SyncStatus.pendingChanges] from the sync queue.
  Future<void> refreshPendingCount() async {
    final count = await _syncService.getPendingCount();
    state = state.copyWith(pendingChanges: count);
  }
}

/// The primary sync provider consumed by the sync screen and any widget that
/// needs sync status.
final syncProvider = NotifierProvider<SyncNotifier, SyncStatus>(
  SyncNotifier.new,
);
