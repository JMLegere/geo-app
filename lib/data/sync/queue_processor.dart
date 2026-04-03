import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'package:earth_nova/data/database.dart';
import 'package:earth_nova/data/repos/cell_visit_repo.dart';
import 'package:earth_nova/data/repos/item_repo.dart';
import 'package:earth_nova/data/repos/write_queue_repo.dart';
import 'package:earth_nova/data/sync/supabase_persistence.dart';
import 'package:earth_nova/shared/constants.dart';

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
  String toString() => 'FlushSummary(confirmed: $confirmed, retried: $retried, '
      'rejected: $rejected, staleDeleted: $staleDeleted)';
}

/// Processes the local write queue by flushing pending entries to Supabase.
///
/// Pure Dart service — receives dependencies via constructor. No Riverpod.
class QueueProcessor {
  final WriteQueueRepo _queueRepo;
  final SupabasePersistence? _persistence;
  final ItemRepo _itemRepo;
  final CellVisitRepo _cellVisitRepo;

  bool _flushing = false;
  Timer? _autoFlushTimer;

  void Function(FlushSummary summary)? onAutoFlushComplete;

  QueueProcessor({
    required WriteQueueRepo queueRepo,
    required SupabasePersistence? persistence,
    required ItemRepo itemRepo,
    required CellVisitRepo cellVisitRepo,
  })  : _queueRepo = queueRepo,
        _persistence = persistence,
        _itemRepo = itemRepo,
        _cellVisitRepo = cellVisitRepo;

  bool get canSync => _persistence != null;
  bool get isFlushing => _flushing;

  /// Add an entry to the write queue and auto-schedule a flush.
  Future<int> enqueue({
    required String entityType,
    required String entityId,
    required String operation,
    required String payload,
    required String userId,
  }) async {
    final id = await _queueRepo.enqueue(WriteQueueTableCompanion.insert(
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      payload: payload,
      userId: userId,
    ));
    _scheduleFlush(userId: userId);
    return id;
  }

  /// Flush immediately, bypassing the debounce timer.
  Future<FlushSummary> flushNow({String? userId}) async {
    _autoFlushTimer?.cancel();
    _autoFlushTimer = null;
    final summary = await flush(userId: userId);
    onAutoFlushComplete?.call(summary);
    return summary;
  }

  void _scheduleFlush({String? userId}) {
    if (!canSync) return;
    if (_autoFlushTimer?.isActive ?? false) return;
    _autoFlushTimer = Timer(
      const Duration(seconds: kWriteQueueAutoFlushDelaySeconds),
      () async {
        final summary = await flush(userId: userId);
        onAutoFlushComplete?.call(summary);
      },
    );
  }

  void dispose() {
    _autoFlushTimer?.cancel();
    _autoFlushTimer = null;
  }

  Future<void> clearUser(String userId) => _queueRepo.clearUser(userId);

  /// Flush pending queue entries to Supabase.
  Future<FlushSummary> flush({String? userId}) async {
    if (_flushing) return const FlushSummary();
    final persistence = _persistence;
    if (persistence == null) return const FlushSummary();

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
    final cutoff = DateTime.now().subtract(
      const Duration(hours: kWriteQueueStaleAgeHours),
    );
    final staleDeleted = await _queueRepo.deleteStale(cutoff);

    final pending = await _queueRepo.getPending(
      limit: kWriteQueueFlushBatchSize,
      userId: userId,
    );
    if (pending.isEmpty) return FlushSummary(staleDeleted: staleDeleted);

    // Coalesce: keep only the latest entry per (entityType, entityId, operation).
    final coalescedEntries = <WriteQueueEntry>[];
    final supersededIds = <int>[];
    final grouped = <String, List<WriteQueueEntry>>{};
    for (final entry in pending) {
      final key = '${entry.entityType}:${entry.entityId}:${entry.operation}';
      (grouped[key] ??= []).add(entry);
    }
    for (final group in grouped.values) {
      coalescedEntries.add(group.last);
      for (var i = 0; i < group.length - 1; i++) {
        supersededIds.add(group[i].id);
      }
    }
    if (supersededIds.isNotEmpty) {
      await _queueRepo.deleteEntries(supersededIds);
    }
    coalescedEntries.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    var confirmed = 0;
    var retried = 0;
    var rejected = 0;

    for (final entry in coalescedEntries) {
      final result = await _processEntry(entry, persistence);
      switch (result) {
        case FlushConfirmed():
          await _queueRepo.confirmEntry(entry.id);
          confirmed++;
        case FlushRejected(:final error):
          await _queueRepo.rejectEntry(entry.id, error);
          rejected++;
        case FlushRetryable(:final error):
          if (entry.attempts + 1 >= kWriteQueueMaxRetries) {
            await _queueRepo.rejectEntry(
              entry.id,
              'Max retries ($kWriteQueueMaxRetries) exceeded. Last: $error',
            );
            rejected++;
          } else {
            await _queueRepo.incrementAttempts(entry.id, error);
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

  Future<FlushResult> _processEntry(
    WriteQueueEntry entry,
    SupabasePersistence persistence,
  ) async {
    try {
      switch (entry.entityType) {
        case 'itemInstance':
          await _processItemInstance(entry, persistence);
        case 'cellProgress':
          await _processCellProgress(entry, persistence);
        case 'profile':
          await _processProfile(entry, persistence);
        case 'cellProperties':
          await _processCellProperties(entry, persistence);
        default:
          debugPrint('[SYNC] unknown entity type: ${entry.entityType}');
      }
      return const FlushConfirmed();
    } on SyncRejectedException catch (e) {
      debugPrint('[SYNC] rejected ${entry.id}: ${e.reason}');
      return FlushRejected(e.reason);
    } on SyncException catch (e) {
      debugPrint('[SYNC] sync error for ${entry.id}: $e');
      return FlushRetryable(e.message);
    } catch (e) {
      debugPrint('[SYNC] unexpected error for ${entry.id}: $e');
      return FlushRetryable(e.toString());
    }
  }

  Future<void> _processItemInstance(
    WriteQueueEntry entry,
    SupabasePersistence persistence,
  ) async {
    switch (entry.operation) {
      case 'upsert':
        final item = await _itemRepo.get(entry.entityId);
        if (item == null) {
          debugPrint('[SYNC] item not found locally: ${entry.entityId}');
          return;
        }
        await persistence.upsertItemInstance(
          id: item.id,
          userId: entry.userId,
          definitionId: item.definitionId,
          affixes: item.affixesJson,
          displayName: item.displayName,
          scientificName: item.scientificName,
          categoryName: item.categoryName,
          rarityName: item.rarityName,
          habitatsJson: item.habitatsJson,
          continentsJson: item.continentsJson,
          taxonomicClass: item.taxonomicClass,
          badgesJson: item.badgesJson,
          parentAId: item.parentAId,
          parentBId: item.parentBId,
          acquiredAt: item.acquiredAt,
          acquiredInCellId: item.acquiredInCellId,
          dailySeed: item.dailySeed,
          status: item.status,
          animalClassName: item.animalClassName,
          foodPreferenceName: item.foodPreferenceName,
          climateName: item.climateName,
          brawn: item.brawn,
          wit: item.wit,
          speed: item.speed,
          sizeName: item.sizeName,
          cellHabitatName: item.cellHabitatName,
          cellClimateName: item.cellClimateName,
          cellContinentName: item.cellContinentName,
          locationDistrict: item.locationDistrict,
          locationCity: item.locationCity,
          locationState: item.locationState,
          locationCountry: item.locationCountry,
          locationCountryCode: item.locationCountryCode,
        );

        // Validate encounter with server.
        try {
          await persistence.validateEncounter(
            itemId: item.id,
            userId: entry.userId,
            definitionId: item.definitionId,
            cellId: item.acquiredInCellId ?? '',
            dailySeed: item.dailySeed,
            acquiredAt: item.acquiredAt.toIso8601String(),
          );
        } on SyncValidationRejectedException catch (e) {
          throw SyncRejectedException(e.reason);
        }

      case 'delete':
        await persistence.deleteItemInstance(id: entry.entityId);
    }
  }

  Future<void> _processCellProgress(
    WriteQueueEntry entry,
    SupabasePersistence persistence,
  ) async {
    if (entry.operation == 'upsert') {
      final data = jsonDecode(entry.payload) as Map<String, dynamic>;
      final cellId = data['cell_id'] as String;
      final visit = await _cellVisitRepo.get(entry.userId, cellId);
      await persistence.upsertCellProgress(
        userId: entry.userId,
        cellId: cellId,
        fogState: 'explored',
        distanceWalked: visit?.distanceWalked ?? 0,
        visitCount: visit?.visitCount ?? 1,
        lastVisited: visit?.lastVisited,
      );
    }
  }

  Future<void> _processProfile(
    WriteQueueEntry entry,
    SupabasePersistence persistence,
  ) async {
    if (entry.operation == 'upsert') {
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
    }
  }

  Future<void> _processCellProperties(
    WriteQueueEntry entry,
    SupabasePersistence persistence,
  ) async {
    if (entry.operation == 'upsert') {
      final data = jsonDecode(entry.payload) as Map<String, dynamic>;
      final habitatsRaw = data['habitats'];
      final List<String> habitats = habitatsRaw is List
          ? List<String>.from(habitatsRaw)
          : List<String>.from(
              jsonDecode(habitatsRaw as String) as List<dynamic>);
      await persistence.upsertCellProperties(
        cellId: data['cell_id'] as String,
        userId: entry.userId,
        habitats: habitats,
        climate: data['climate'] as String,
        continent: data['continent'] as String,
        locationId: data['location_id'] as String?,
      );
    }
  }

  /// Pulls updated item data from server after successful sync.
  /// Server-side enrichment may have added location data the client didn't have.
  Future<void> pullEnrichedItems(String userId) async {
    if (_persistence == null) return;
    try {
      // Fetch items that have location data from server
      final response = await _persistence!.client
          .from('item_instances')
          .select(
              'id, location_district, location_city, location_state, location_country, location_country_code')
          .eq('user_id', userId)
          .not('location_country', 'is', null);

      final items = List<Map<String, dynamic>>.from(response as List);
      for (final item in items) {
        await _itemRepo.updateLocation(
          item['id'] as String,
          district: item['location_district'] as String?,
          city: item['location_city'] as String?,
          state: item['location_state'] as String?,
          country: item['location_country'] as String?,
          countryCode: item['location_country_code'] as String?,
        );
      }
      if (items.isNotEmpty) {
        debugPrint('[SYNC] pulled ${items.length} enriched items from server');
      }
    } catch (e) {
      debugPrint('[SYNC] enrichment pull failed: $e');
    }
  }

  /// Exponential backoff delay for a given attempt count.
  static Duration backoffDelay(int attempts) {
    final seconds = kWriteQueueRetryBaseSeconds * pow(2, attempts);
    return Duration(seconds: seconds.toInt());
  }
}
