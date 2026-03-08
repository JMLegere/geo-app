import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:fog_of_world/core/models/write_queue_entry.dart';
import 'package:fog_of_world/core/state/inventory_provider.dart';
import 'package:fog_of_world/core/state/item_instance_repository_provider.dart';
import 'package:fog_of_world/core/state/supabase_bootstrap_provider.dart';
import 'package:fog_of_world/core/state/write_queue_repository_provider.dart';
import 'package:fog_of_world/features/sync/providers/queue_processor_provider.dart';
import 'package:fog_of_world/features/sync/services/supabase_persistence.dart';
import 'package:fog_of_world/features/sync/models/sync_status.dart';

// ── Infrastructure providers ──────────────────────────────────────────────────

/// Resolves to `true` once Supabase bootstrap is complete (success or failure).
///
/// Downstream providers that `ref.watch` this will automatically rebuild once
/// the bootstrap future settles, solving the timing race where providers are
/// first read before `Supabase.initialize()` finishes.
final _supabaseReadyProvider = FutureProvider<bool>((ref) async {
  final bootstrap = ref.watch(supabaseBootstrapProvider);
  await bootstrap.ready;
  return bootstrap.initialized;
});

/// Returns the [SupabaseClient] when Supabase is initialised, or null when
/// credentials are missing, init failed, or bootstrap hasn't completed yet.
///
/// Watches [_supabaseReadyProvider] so it rebuilds after bootstrap settles.
/// This is the single allowed entry point for Supabase client access outside
/// of [supabase_auth_service.dart]. Features that need the client (e.g.
/// enrichment) must import this provider rather than importing
/// `supabase_flutter` directly.
final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  final ready = ref.watch(_supabaseReadyProvider);
  final initialized = ready.when(
    data: (v) => v,
    loading: () => false,
    error: (_, __) => false,
  );
  if (!initialized) return null;
  return Supabase.instance.client;
});

/// Returns a [SupabasePersistence] instance when Supabase actually initialised,
/// or null when credentials are missing or init failed (e.g. web locale crash).
final supabasePersistenceProvider = Provider<SupabasePersistence?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return null;
  return SupabasePersistence(client);
});

// ── SyncNotifier ─────────────────────────────────────────────────────────────

class SyncNotifier extends Notifier<SyncStatus> {
  @override
  SyncStatus build() {
    final isConnected = ref.watch(supabasePersistenceProvider) != null;

    // Initialize pending count from write queue.
    _refreshPendingCount();

    return SyncStatus(
      type: isConnected ? SyncStatusType.idle : SyncStatusType.error,
      errorMessage: isConnected ? null : 'Supabase not configured',
    );
  }

  /// Triggers a manual sync: flushes the write queue to Supabase.
  ///
  /// Updates state to reflect progress and surfaces user-friendly error
  /// messages on failure without exposing raw exceptions.
  Future<void> syncNow() async {
    final processor = ref.read(queueProcessorProvider);
    if (!processor.canSync) {
      state = state.copyWith(
        type: SyncStatusType.error,
        errorMessage: 'Sync unavailable: Supabase not configured.',
      );
      return;
    }

    state = state.copyWith(type: SyncStatusType.syncing, errorMessage: null);

    try {
      final summary = await processor.flush();
      final pending =
          await ref.read(writeQueueRepositoryProvider).countPending();

      // Process rollbacks for rejected entries.
      if (summary.hasRejections) {
        await _processRejections();
      }

      // Propagate server-awarded first-discovery badges to in-memory inventory.
      if (summary.hasFirstBadges) {
        await _applyFirstBadges(summary.firstBadgeItemIds);
      }

      if (summary.hasRejections) {
        state = SyncStatus(
          type: SyncStatusType.success,
          lastSyncedAt: DateTime.now(),
          pendingChanges: pending,
          errorMessage: '${summary.rejected} item(s) rejected by server.',
        );
      } else {
        state = SyncStatus(
          type: SyncStatusType.success,
          lastSyncedAt: DateTime.now(),
          pendingChanges: pending,
        );
      }
    } on SyncException catch (e) {
      debugPrint('[SyncNotifier] sync failed: $e');
      state = state.copyWith(
        type: SyncStatusType.error,
        errorMessage: e.message,
      );
    } catch (e) {
      debugPrint('[SyncNotifier] unexpected sync error: $e');
      state = state.copyWith(
        type: SyncStatusType.error,
        errorMessage:
            'Sync failed. Please check your connection and try again.',
      );
    }
  }

  /// Process rejected queue entries: rollback local state.
  ///
  /// For item instances: remove from in-memory inventory + delete from SQLite.
  /// For cell progress / profile: log only (no local rollback — server is
  /// source of truth, next full sync will reconcile).
  ///
  /// After processing, rejected entries are deleted from the queue.
  Future<void> _processRejections() async {
    final writeQueueRepo = ref.read(writeQueueRepositoryProvider);
    final rejected = await writeQueueRepo.getRejected();

    for (final entry in rejected) {
      switch (entry.entityType) {
        case WriteQueueEntityType.itemInstance:
          // Remove from in-memory inventory.
          ref.read(inventoryProvider.notifier).removeItem(entry.entityId);

          // Remove from SQLite.
          try {
            final itemRepo = ref.read(itemInstanceRepositoryProvider);
            await itemRepo.deleteItem(entry.entityId);
          } catch (e) {
            debugPrint(
              '[SyncNotifier] failed to delete rejected item '
              '${entry.entityId}: $e',
            );
          }

        case WriteQueueEntityType.cellProgress:
        case WriteQueueEntityType.profile:
          // No local rollback for cell progress or profile — server
          // reconciliation on next full sync will handle these.
          debugPrint(
            '[SyncNotifier] rejected ${entry.entityType.name}: '
            '${entry.entityId} — ${entry.lastError}',
          );
      }

      // Remove the rejected entry from the queue.
      try {
        await writeQueueRepo.deleteEntry(entry.id!);
      } catch (e) {
        debugPrint(
          '[SyncNotifier] failed to cleanup rejected entry '
          '${entry.id}: $e',
        );
      }
    }
  }

  /// Apply server-awarded first-discovery badges to in-memory inventory.
  Future<void> _applyFirstBadges(List<String> itemIds) async {
    final itemRepo = ref.read(itemInstanceRepositoryProvider);
    final inventory = ref.read(inventoryProvider.notifier);

    for (final itemId in itemIds) {
      try {
        final item = await itemRepo.getItem(itemId);
        if (item != null) {
          inventory.updateItem(item);
        }
      } catch (e) {
        debugPrint('[SyncNotifier] failed to apply badge for $itemId: $e');
      }
    }
  }

  /// Refresh the pending changes count from the write queue.
  Future<void> _refreshPendingCount() async {
    try {
      final count = await ref.read(writeQueueRepositoryProvider).countPending();
      if (state.pendingChanges != count) {
        state = state.copyWith(pendingChanges: count);
      }
    } catch (e) {
      // Non-critical — don't crash the UI.
      debugPrint('[SyncNotifier] failed to refresh pending count: $e');
    }
  }
}

/// The primary sync provider consumed by the sync screen.
final syncProvider = NotifierProvider<SyncNotifier, SyncStatus>(
  SyncNotifier.new,
);
