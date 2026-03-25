import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:earth_nova/core/models/write_queue_entry.dart';
import 'package:earth_nova/core/models/fog_state.dart';
import 'package:earth_nova/core/state/cell_progress_repository_provider.dart';
import 'package:earth_nova/core/state/fog_provider.dart';
import 'package:earth_nova/features/items/providers/items_provider.dart';
import 'package:earth_nova/core/state/item_instance_repository_provider.dart';
import 'package:earth_nova/core/state/supabase_bootstrap_provider.dart';
import 'package:earth_nova/core/state/write_queue_repository_provider.dart';
import 'package:earth_nova/features/auth/providers/auth_provider.dart';
import 'package:earth_nova/features/sync/providers/queue_processor_provider.dart';
import 'package:earth_nova/features/sync/services/supabase_persistence.dart';
import 'package:earth_nova/features/sync/models/sync_status.dart';

// ── Infrastructure providers ──────────────────────────────────────────────────

/// Whether Supabase is ready for use.
///
/// Delegates to [supabaseBootstrapProvider]. Bootstrap is awaited in `main()`
/// before `runApp()`, so by the time any provider runs the result is settled.
final _supabaseReadyProvider = Provider<bool>((ref) {
  return ref.watch(supabaseBootstrapProvider);
});

/// Returns the [SupabaseClient] when Supabase is initialised, or null when
/// credentials are missing or init failed.
///
/// This is the single allowed entry point for Supabase client access outside
/// of [supabase_auth_service.dart]. Features that need the client (e.g.
/// enrichment) must import this provider rather than importing
/// `supabase_flutter` directly.
final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  final initialized = ref.watch(_supabaseReadyProvider);
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
    refreshPendingCount();

    return SyncStatus(
      type: isConnected ? SyncStatusType.idle : SyncStatusType.error,
      errorMessage: isConnected ? null : 'Supabase not configured',
    );
  }

  /// Returns the current user's ID, or null if not authenticated.
  String? get _currentUserId => ref.read(authProvider).user?.id;

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

    final userId = _currentUserId;

    state = state.copyWith(type: SyncStatusType.syncing, errorMessage: null);

    try {
      final summary = await processor.flush(userId: userId);
      final pending = await ref
          .read(writeQueueRepositoryProvider)
          .countPending(userId: userId);

      // Process rollbacks for rejected entries.
      if (summary.hasRejections) {
        await processRejections();
      }

      // Propagate server-awarded first-discovery badges to in-memory inventory.
      if (summary.hasFirstBadges) {
        await applyFirstBadges(summary.firstBadgeItemIds);
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
  Future<void> processRejections() async {
    final writeQueueRepo = ref.read(writeQueueRepositoryProvider);
    final rejected = await writeQueueRepo.getRejected(
      userId: _currentUserId,
    );

    for (final entry in rejected) {
      switch (entry.entityType) {
        case WriteQueueEntityType.itemInstance:
          // Remove from in-memory inventory.
          ref.read(itemsProvider.notifier).removeItem(entry.entityId);

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
          // entityId format: '$userId:$cellId' (see _persistCellVisit).
          // Rollback: remove the local cell progress record so fog state
          // reverts to unvisited on next render. The cell visit was
          // rejected by the server — it shouldn't be reflected locally.
          final colonIdx = entry.entityId.indexOf(':');
          if (colonIdx > 0) {
            final uid = entry.entityId.substring(0, colonIdx);
            final cellId = entry.entityId.substring(colonIdx + 1);
            try {
              final cellProgressRepo = ref.read(cellProgressRepositoryProvider);
              await cellProgressRepo.delete(uid, cellId);
              // Also reset in-memory fog state so the map reverts to
              // undetected on the next render cycle.
              ref
                  .read(fogProvider.notifier)
                  .updateCellFogState(cellId, FogState.unknown);
              debugPrint(
                '[SyncNotifier] rolled back cell progress: $cellId',
              );
            } catch (e) {
              debugPrint(
                '[SyncNotifier] failed to rollback cell progress '
                '${entry.entityId}: $e',
              );
            }
          } else {
            debugPrint(
              '[SyncNotifier] rejected cellProgress (malformed entityId): '
              '${entry.entityId} — ${entry.lastError}',
            );
          }

        case WriteQueueEntityType.profile:
          // Profile rollbacks are not safe to do locally — we don't know
          // which previous values to restore. Log the rejection clearly so
          // developers can investigate; the user's profile will reconcile
          // on next full hydration (app restart → hydrateFromSupabase).
          debugPrint(
            '[SyncNotifier] rejected profile: ${entry.entityId} — '
            '${entry.lastError} (will reconcile on next app start)',
          );

        case WriteQueueEntityType.cellProperties:
          // Cell properties are globally shared and geo-derived; rejection
          // is extremely unlikely. Log only — no rollback needed.
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
  Future<void> applyFirstBadges(List<String> itemIds) async {
    final itemRepo = ref.read(itemInstanceRepositoryProvider);
    final inventory = ref.read(itemsProvider.notifier);

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
  Future<void> refreshPendingCount() async {
    try {
      final count = await ref
          .read(writeQueueRepositoryProvider)
          .countPending(userId: _currentUserId);
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
