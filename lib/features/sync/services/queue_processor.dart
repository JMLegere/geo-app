import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'package:fog_of_world/core/models/write_queue_entry.dart';
import 'package:fog_of_world/core/persistence/write_queue_repository.dart';
import 'package:fog_of_world/features/sync/services/supabase_persistence.dart';
import 'package:fog_of_world/shared/constants.dart';

/// Result of a single queue entry flush attempt.
sealed class FlushResult {
  const FlushResult();
}

class FlushConfirmed extends FlushResult {
  const FlushConfirmed();
}

class FlushRetryable extends FlushResult {
  final String error;
  const FlushRetryable(this.error);
}

class FlushRejected extends FlushResult {
  final String error;
  const FlushRejected(this.error);
}

/// Summary returned after a flush cycle.
class FlushSummary {
  final int confirmed;
  final int retried;
  final int rejected;
  final int staleDeleted;

  const FlushSummary({
    this.confirmed = 0,
    this.retried = 0,
    this.rejected = 0,
    this.staleDeleted = 0,
  });

  int get total => confirmed + retried + rejected;
  bool get hasRejections => rejected > 0;

  @override
  String toString() =>
      'FlushSummary(confirmed: $confirmed, retried: $retried, '
      'rejected: $rejected, staleDeleted: $staleDeleted)';
}

/// Processes the local write queue by flushing pending entries to Supabase.
///
/// Pure Dart service — receives dependencies via constructor. No Riverpod.
///
/// ## Flow per entry:
/// 1. Read pending entries (oldest first, batch limited)
/// 2. For each entry, dispatch to the appropriate SupabasePersistence method
/// 3. On success → delete entry (confirmed)
/// 4. On SyncException → increment attempts; reject if max retries exceeded
/// 5. On unexpected error → increment attempts with exponential backoff
///
/// ## Rollback
/// Rejected entries (server validation failed) are marked `rejected`.
/// The provider layer reads rejected entries and triggers local rollback
/// (remove from inventory + toast).
class QueueProcessor {
  final WriteQueueRepository _queueRepo;
  final SupabasePersistence? _persistence;

  QueueProcessor({
    required WriteQueueRepository queueRepo,
    required SupabasePersistence? persistence,
  })  : _queueRepo = queueRepo,
        _persistence = persistence;

  /// Whether Supabase is available for syncing.
  bool get canSync => _persistence != null;

  /// Flush pending queue entries to Supabase.
  ///
  /// Returns a summary of what happened. Safe to call when offline —
  /// returns immediately if Supabase is not configured.
  Future<FlushSummary> flush() async {
    final persistence = _persistence;
    if (persistence == null) {
      return const FlushSummary();
    }

    // Clean up stale entries first.
    final cutoff = DateTime.now().subtract(
      const Duration(hours: kWriteQueueStaleAgeHours),
    );
    final staleDeleted = await _queueRepo.deleteStale(cutoff);

    // Fetch pending batch.
    final pending = await _queueRepo.getPending(
      limit: kWriteQueueFlushBatchSize,
    );

    if (pending.isEmpty) {
      return FlushSummary(staleDeleted: staleDeleted);
    }

    var confirmed = 0;
    var retried = 0;
    var rejected = 0;

    for (final entry in pending) {
      final result = await _processEntry(entry, persistence);

      switch (result) {
        case FlushConfirmed():
          await _queueRepo.markConfirmed(entry.id!);
          confirmed++;

        case FlushRejected(:final error):
          await _queueRepo.markRejected(entry.id!, error);
          rejected++;

        case FlushRetryable(:final error):
          if (entry.attempts + 1 >= kWriteQueueMaxRetries) {
            // Max retries exceeded — reject.
            await _queueRepo.markRejected(
              entry.id!,
              'Max retries ($kWriteQueueMaxRetries) exceeded. Last: $error',
            );
            rejected++;
          } else {
            await _queueRepo.incrementAttempts(entry.id!, error);
            retried++;
          }
      }
    }

    return FlushSummary(
      confirmed: confirmed,
      retried: retried,
      rejected: rejected,
      staleDeleted: staleDeleted,
    );
  }

  /// Process a single queue entry.
  Future<FlushResult> _processEntry(
    WriteQueueEntry entry,
    SupabasePersistence persistence,
  ) async {
    try {
      switch (entry.entityType) {
        case WriteQueueEntityType.itemInstance:
          await _processItemInstance(entry, persistence);
        case WriteQueueEntityType.cellProgress:
          await _processCellProgress(entry, persistence);
        case WriteQueueEntityType.profile:
          await _processProfile(entry, persistence);
      }
      return const FlushConfirmed();
    } on SyncRejectedException catch (e) {
      debugPrint('[QueueProcessor] rejected ${entry.id}: ${e.reason}');
      return FlushRejected(e.reason);
    } on SyncException catch (e) {
      debugPrint('[QueueProcessor] sync error for ${entry.id}: $e');
      return FlushRetryable(e.message);
    } catch (e) {
      debugPrint('[QueueProcessor] unexpected error for ${entry.id}: $e');
      return FlushRetryable(e.toString());
    }
  }

  // ── Entity-specific dispatch ───────────────────────────────────────────────

  Future<void> _processItemInstance(
    WriteQueueEntry entry,
    SupabasePersistence persistence,
  ) async {
    switch (entry.operation) {
      case WriteQueueOperation.upsert:
        final data = jsonDecode(entry.payload) as Map<String, dynamic>;

        await persistence.upsertItemInstance(
          id: data['id'] as String,
          userId: entry.userId,
          definitionId: data['definition_id'] as String,
          affixes: data['affixes'] as String,
          parentAId: data['parent_a_id'] as String?,
          parentBId: data['parent_b_id'] as String?,
          acquiredAt: DateTime.parse(data['acquired_at'] as String),
          acquiredInCellId: data['acquired_in_cell_id'] as String?,
          dailySeed: data['daily_seed'] as String?,
          status: data['status'] as String,
        );

        await _validateEncounter(entry, data, persistence);

      case WriteQueueOperation.delete:
        await persistence.deleteItemInstance(id: entry.entityId);
    }
  }

  Future<void> _validateEncounter(
    WriteQueueEntry entry,
    Map<String, dynamic> data,
    SupabasePersistence persistence,
  ) async {
    try {
      await persistence.validateEncounter(
        itemId: data['id'] as String,
        userId: entry.userId,
        definitionId: data['definition_id'] as String,
        cellId: data['acquired_in_cell_id'] as String? ?? '',
        dailySeed: data['daily_seed'] as String?,
        acquiredAt: data['acquired_at'] as String,
      );
    } on SyncValidationRejectedException catch (e) {
      throw SyncRejectedException(e.reason);
    }
  }

  Future<void> _processCellProgress(
    WriteQueueEntry entry,
    SupabasePersistence persistence,
  ) async {
    switch (entry.operation) {
      case WriteQueueOperation.upsert:
        final data = jsonDecode(entry.payload) as Map<String, dynamic>;
        await persistence.upsertCellProgress(
          userId: entry.userId,
          cellId: data['cell_id'] as String,
          fogState: data['fog_state'] as String,
          distanceWalked: (data['distance_walked'] as num?)?.toDouble() ?? 0,
          visitCount: (data['visit_count'] as num?)?.toInt() ?? 0,
          restorationLevel:
              (data['restoration_level'] as num?)?.toDouble() ?? 0,
          lastVisited: data['last_visited'] != null
              ? DateTime.parse(data['last_visited'] as String)
              : null,
        );
      case WriteQueueOperation.delete:
        // Cell progress delete not currently used — no-op.
        debugPrint(
          '[QueueProcessor] cell progress delete not implemented: '
          '${entry.entityId}',
        );
    }
  }

  Future<void> _processProfile(
    WriteQueueEntry entry,
    SupabasePersistence persistence,
  ) async {
    switch (entry.operation) {
      case WriteQueueOperation.upsert:
        final data = jsonDecode(entry.payload) as Map<String, dynamic>;
        await persistence.upsertProfile(
          userId: entry.userId,
          displayName: data['display_name'] as String?,
          currentStreak: (data['current_streak'] as num?)?.toInt(),
          longestStreak: (data['longest_streak'] as num?)?.toInt(),
          totalDistanceKm:
              (data['total_distance_km'] as num?)?.toDouble(),
          currentSeason: data['current_season'] as String?,
        );
      case WriteQueueOperation.delete:
        // Profile delete not currently used — no-op.
        debugPrint(
          '[QueueProcessor] profile delete not implemented: '
          '${entry.entityId}',
        );
    }
  }

  /// Calculate exponential backoff delay for a given attempt count.
  ///
  /// Not currently used for scheduling (flush is manual via SyncNotifier),
  /// but available for future auto-retry scheduling.
  static Duration backoffDelay(int attempts) {
    final seconds = kWriteQueueRetryBaseSeconds * pow(2, attempts);
    return Duration(seconds: seconds.toInt());
  }
}
