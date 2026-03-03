import 'package:fog_of_world/core/database/app_database.dart';
import 'package:fog_of_world/core/persistence/sync_queue_repository.dart';
import 'package:fog_of_world/features/sync/models/sync_exception.dart';
import 'package:fog_of_world/features/sync/models/sync_result.dart';
import 'package:fog_of_world/features/sync/services/cloud_sync_client.dart';

/// Orchestrates upload/download between local SQLite and the cloud.
///
/// Upload flow:
///   1. Drain the [SyncQueueRepository] and group events by target table.
///   2. Call the appropriate [CloudSyncClient.upload*] method per table.
///   3. Dequeue successfully uploaded events.
///
/// Download flow (runs even if upload had partial errors):
///   4. Fetch remote data per table for `userId`.
///   5. Merge into local DB with server-wins conflict resolution.
class SyncService {
  SyncService({
    required CloudSyncClient cloudClient,
    required SyncQueueRepository syncQueueRepository,
    required AppDatabase db,
  })  : _cloudClient = cloudClient,
        _syncQueueRepository = syncQueueRepository,
        _db = db;

  final CloudSyncClient _cloudClient;
  final SyncQueueRepository _syncQueueRepository;
  final AppDatabase _db;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Sync all pending local changes to the cloud, then pull remote data.
  ///
  /// Returns a [SyncResult] summarising what was uploaded, downloaded, and
  /// any errors encountered. Errors are caught and recorded — this method
  /// never throws [SyncException].
  Future<SyncResult> syncAll(String userId) async {
    int uploadedCount = 0;
    int downloadedCount = 0;
    int errorCount = 0;
    String? errorMessage;

    // ── Upload ──────────────────────────────────────────────────────────────
    try {
      final pending = await _syncQueueRepository.getPending();

      // Group events by targetTable.
      final grouped = <String, List<SyncQueueEntry>>{};
      for (final event in pending) {
        grouped.putIfAbsent(event.targetTable, () => []).add(event);
      }

      for (final entry in grouped.entries) {
        final table = entry.key;
        final events = entry.value;
        final rows =
            events.map(SyncQueueRepository.parseData).toList();

        try {
          switch (table) {
            case 'cell_progress':
              await _cloudClient.uploadCellProgress(rows);
            case 'collected_species':
              await _cloudClient.uploadCollectedSpecies(rows);
            case 'profiles':
              for (final row in rows) {
                await _cloudClient.uploadProfile(row);
              }
            default:
              // Unknown table — skip without dequeuing.
              continue;
          }

          // Dequeue only after a successful upload.
          await _syncQueueRepository
              .dequeueBatch(events.map((e) => e.id).toList());
          uploadedCount += events.length;
        } on SyncException catch (e) {
          errorCount++;
          errorMessage = e.message;
        }
      }
    } on SyncException catch (e) {
      errorCount++;
      errorMessage = e.message;
    }

    // ── Download ─────────────────────────────────────────────────────────────

    // Cell progress
    try {
      final rows = await _cloudClient.downloadCellProgress(userId);
      for (final row in rows) {
        await _db.upsertCellProgress(_mapToCellProgress(row));
        downloadedCount++;
      }
    } on SyncException catch (e) {
      errorCount++;
      errorMessage = e.message;
    }

    // Collected species
    try {
      final rows = await _cloudClient.downloadCollectedSpecies(userId);
      for (final row in rows) {
        final species = _mapToCollectedSpecies(row);
        final alreadyExists = await _db.isSpeciesCollected(
          species.userId,
          species.speciesId,
          species.cellId,
        );
        if (!alreadyExists) {
          await _db.insertCollectedSpecies(species);
          downloadedCount++;
        }
      }
    } on SyncException catch (e) {
      errorCount++;
      errorMessage = e.message;
    }

    // Player profile
    try {
      final row = await _cloudClient.downloadProfile(userId);
      if (row != null) {
        await _db.upsertPlayerProfile(_mapToPlayerProfile(row));
        downloadedCount++;
      }
    } on SyncException catch (e) {
      errorCount++;
      errorMessage = e.message;
    }

    return SyncResult(
      uploadedCount: uploadedCount,
      downloadedCount: downloadedCount,
      errorCount: errorCount,
      errorMessage: errorMessage,
    );
  }

  /// Returns the current number of items in the local sync queue.
  Future<int> getPendingCount() => _syncQueueRepository.getSize();

  // ---------------------------------------------------------------------------
  // Private conversion helpers
  // ---------------------------------------------------------------------------

  LocalCellProgress _mapToCellProgress(Map<String, dynamic> row) {
    return LocalCellProgress(
      id: row['id'] as String,
      userId: row['userId'] as String,
      cellId: row['cellId'] as String,
      fogState: row['fogState'] as String,
      distanceWalked: (row['distanceWalked'] as num).toDouble(),
      visitCount: (row['visitCount'] as num).toInt(),
      restorationLevel: (row['restorationLevel'] as num).toDouble(),
      lastVisited: row['lastVisited'] != null
          ? DateTime.parse(row['lastVisited'] as String)
          : null,
      createdAt: DateTime.parse(row['createdAt'] as String),
      updatedAt: DateTime.parse(row['updatedAt'] as String),
    );
  }

  LocalCollectedSpecies _mapToCollectedSpecies(Map<String, dynamic> row) {
    return LocalCollectedSpecies(
      id: row['id'] as String,
      userId: row['userId'] as String,
      speciesId: row['speciesId'] as String,
      cellId: row['cellId'] as String,
      collectedAt: DateTime.parse(row['collectedAt'] as String),
    );
  }

  LocalPlayerProfile _mapToPlayerProfile(Map<String, dynamic> row) {
    return LocalPlayerProfile(
      id: row['id'] as String,
      displayName: row['displayName'] as String,
      currentStreak: (row['currentStreak'] as num).toInt(),
      longestStreak: (row['longestStreak'] as num).toInt(),
      totalDistanceKm: (row['totalDistanceKm'] as num).toDouble(),
      currentSeason: row['currentSeason'] as String,
      createdAt: DateTime.parse(row['createdAt'] as String),
      updatedAt: DateTime.parse(row['updatedAt'] as String),
    );
  }
}
