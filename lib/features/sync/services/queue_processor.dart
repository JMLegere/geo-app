import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'package:earth_nova/core/models/item_instance.dart';
import 'package:earth_nova/core/models/write_queue_entry.dart';
import 'package:earth_nova/core/persistence/item_instance_repository.dart';
import 'package:earth_nova/core/persistence/write_queue_repository.dart';
import 'package:earth_nova/features/sync/services/supabase_persistence.dart';
import 'package:earth_nova/shared/constants.dart';

/// Result of a single queue entry flush attempt.
sealed class FlushResult {
  const FlushResult();
}

class FlushConfirmed extends FlushResult {
  final String? awardedFirstBadgeItemId;
  const FlushConfirmed({this.awardedFirstBadgeItemId});
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
  final List<String> firstBadgeItemIds;

  const FlushSummary({
    this.confirmed = 0,
    this.retried = 0,
    this.rejected = 0,
    this.staleDeleted = 0,
    this.firstBadgeItemIds = const [],
  });

  int get total => confirmed + retried + rejected;
  bool get hasRejections => rejected > 0;
  bool get hasFirstBadges => firstBadgeItemIds.isNotEmpty;

  @override
  String toString() => 'FlushSummary(confirmed: $confirmed, retried: $retried, '
      'rejected: $rejected, staleDeleted: $staleDeleted, '
      'firstBadges: ${firstBadgeItemIds.length})';
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
  final ItemInstanceRepository _itemRepo;

  /// Guards against concurrent flush() calls.
  bool _flushing = false;

  QueueProcessor({
    required WriteQueueRepository queueRepo,
    required SupabasePersistence? persistence,
    required ItemInstanceRepository itemRepo,
  })  : _queueRepo = queueRepo,
        _persistence = persistence,
        _itemRepo = itemRepo;

  /// Whether Supabase is available for syncing.
  bool get canSync => _persistence != null;

  /// Whether a flush is currently in progress.
  bool get isFlushing => _flushing;

  /// Flush pending queue entries to Supabase.
  ///
  /// When [userId] is provided, only flushes entries belonging to that user —
  /// prevents sending another user's queued writes after an account switch on
  /// the same device.
  ///
  /// Returns a summary of what happened. Safe to call when offline —
  /// returns immediately if Supabase is not configured. Returns empty
  /// summary if a flush is already in progress (no-op).
  Future<FlushSummary> flush({String? userId}) async {
    if (_flushing) return const FlushSummary();

    final persistence = _persistence;
    if (persistence == null) {
      return const FlushSummary();
    }

    _flushing = true;
    try {
      return await _flushInternal(persistence, userId: userId);
    } finally {
      _flushing = false;
    }
  }

  Future<FlushSummary> _flushInternal(
    SupabasePersistence persistence, {
    String? userId,
  }) async {
    // Clean up stale entries first.
    final cutoff = DateTime.now().subtract(
      const Duration(hours: kWriteQueueStaleAgeHours),
    );
    final staleDeleted = await _queueRepo.deleteStale(cutoff);

    // Fetch pending batch — scoped to current user if provided.
    final pending = await _queueRepo.getPending(
      limit: kWriteQueueFlushBatchSize,
      userId: userId,
    );

    if (pending.isEmpty) {
      return FlushSummary(staleDeleted: staleDeleted);
    }

    var confirmed = 0;
    var retried = 0;
    var rejected = 0;
    final firstBadgeItemIds = <String>[];

    for (final entry in pending) {
      final result = await _processEntry(entry, persistence);

      switch (result) {
        case FlushConfirmed(:final awardedFirstBadgeItemId):
          await _queueRepo.deleteEntry(entry.id!);
          confirmed++;
          if (awardedFirstBadgeItemId != null) {
            firstBadgeItemIds.add(awardedFirstBadgeItemId);
          }

        case FlushRejected(:final error):
          await _queueRepo.markRejected(entry.id!, error);
          rejected++;

        case FlushRetryable(:final error):
          if (entry.attempts + 1 >= kWriteQueueMaxRetries) {
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
      firstBadgeItemIds: firstBadgeItemIds,
    );
  }

  Future<FlushResult> _processEntry(
    WriteQueueEntry entry,
    SupabasePersistence persistence,
  ) async {
    try {
      String? awardedItemId;
      switch (entry.entityType) {
        case WriteQueueEntityType.itemInstance:
          awardedItemId = await _processItemInstance(entry, persistence);
        case WriteQueueEntityType.cellProgress:
          await _processCellProgress(entry, persistence);
        case WriteQueueEntityType.profile:
          await _processProfile(entry, persistence);
      }
      return FlushConfirmed(awardedFirstBadgeItemId: awardedItemId);
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

  /// Returns the item ID if a first-discovery badge was awarded, null otherwise.
  Future<String?> _processItemInstance(
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
          badgesJson: data['badges_json'] as String?,
          parentAId: data['parent_a_id'] as String?,
          parentBId: data['parent_b_id'] as String?,
          acquiredAt: DateTime.parse(data['acquired_at'] as String),
          acquiredInCellId: data['acquired_in_cell_id'] as String?,
          dailySeed: data['daily_seed'] as String?,
          status: data['status'] as String,
        );

        final result = await _validateEncounter(entry, data, persistence);

        if (result.isFirstGlobal) {
          final itemId = data['id'] as String;
          await _awardFirstBadge(itemId, entry.userId, persistence);
          return itemId;
        }

        return null;

      case WriteQueueOperation.delete:
        await persistence.deleteItemInstance(id: entry.entityId);
        return null;
    }
  }

  Future<EncounterValidationResult> _validateEncounter(
    WriteQueueEntry entry,
    Map<String, dynamic> data,
    SupabasePersistence persistence,
  ) async {
    try {
      return await persistence.validateEncounter(
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

  Future<void> _awardFirstBadge(
    String itemId,
    String userId,
    SupabasePersistence persistence,
  ) async {
    try {
      final item = await _itemRepo.getItem(itemId);
      if (item == null) return;
      if (item.isFirstDiscovery) return;

      final updated = item.copyWith(
        badges: {...item.badges, kBadgeFirstDiscovery},
      );
      await _itemRepo.updateItem(updated, userId);

      // Sync updated badges back to Supabase.
      await persistence.upsertItemInstance(
        id: updated.id,
        userId: userId,
        definitionId: updated.definitionId,
        affixes: updated.affixesToJson(),
        badgesJson: updated.badgesToJson(),
        parentAId: updated.parentAId,
        parentBId: updated.parentBId,
        acquiredAt: updated.acquiredAt,
        acquiredInCellId: updated.acquiredInCellId,
        dailySeed: updated.dailySeed,
        status: updated.status.name,
      );
    } catch (e) {
      debugPrint(
          '[QueueProcessor] failed to award first badge for $itemId: $e');
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
          totalDistanceKm: (data['total_distance_km'] as num?)?.toDouble(),
          currentSeason: data['current_season'] as String?,
          hasCompletedOnboarding: data['has_completed_onboarding'] as bool?,
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
