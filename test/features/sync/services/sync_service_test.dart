import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fog_of_world/core/database/app_database.dart';
import 'package:fog_of_world/core/persistence/sync_queue_repository.dart';
import 'package:fog_of_world/features/sync/services/mock_cloud_sync_client.dart';
import 'package:fog_of_world/features/sync/services/sync_service.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

AppDatabase _createTestDatabase() => AppDatabase(NativeDatabase.memory());

SyncService _makeService({
  MockCloudSyncClient? client,
  SyncQueueRepository? repo,
  AppDatabase? db,
}) {
  final testDb = db ?? _createTestDatabase();
  return SyncService(
    cloudClient: client ?? MockCloudSyncClient(),
    syncQueueRepository: repo ?? SyncQueueRepository(testDb),
    db: testDb,
  );
}

Map<String, dynamic> _cellProgressRow({
  String id = 'cp1',
  String userId = 'user1',
  String cellId = 'cell1',
  String fogState = 'observed',
}) => {
      'id': id,
      'userId': userId,
      'cellId': cellId,
      'fogState': fogState,
      'distanceWalked': 50.0,
      'visitCount': 2,
      'restorationLevel': 0.3,
      'lastVisited': null,
      'createdAt': '2026-01-01T00:00:00.000Z',
      'updatedAt': '2026-01-02T00:00:00.000Z',
    };

Map<String, dynamic> _speciesRow({
  String id = 'cs1',
  String userId = 'user1',
  String speciesId = 'sp1',
  String cellId = 'cell1',
}) => {
      'id': id,
      'userId': userId,
      'speciesId': speciesId,
      'cellId': cellId,
      'collectedAt': '2026-01-01T10:00:00.000Z',
    };

Map<String, dynamic> _profileRow({
  String id = 'user1',
  String displayName = 'Explorer',
}) => {
      'id': id,
      'displayName': displayName,
      'currentStreak': 3,
      'longestStreak': 7,
      'totalDistanceKm': 12.5,
      'currentSeason': 'summer',
      'createdAt': '2026-01-01T00:00:00.000Z',
      'updatedAt': '2026-01-05T00:00:00.000Z',
    };

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('SyncService', () {
    // ── empty queue ───────────────────────────────────────────────────────────

    test('syncAll with empty queue returns success with 0 uploaded', () async {
      final service = _makeService();

      final result = await service.syncAll('user1');

      expect(result.isSuccess, isTrue);
      expect(result.uploadedCount, 0);
      expect(result.errorCount, 0);
    });

    // ── upload ────────────────────────────────────────────────────────────────

    test('syncAll uploads pending cell_progress events', () async {
      final client = MockCloudSyncClient();
      final db = _createTestDatabase();
      final repo = SyncQueueRepository(db);
      final service =
          _makeService(client: client, repo: repo, db: db);

      await repo.enqueueUpdate(
        tableName: 'cell_progress',
        data: _cellProgressRow(),
      );

      final result = await service.syncAll('user1');

      expect(result.uploadedCount, 1);
      expect(result.isSuccess, isTrue);
      final cloudData = await client.downloadCellProgress('user1');
      expect(cloudData, hasLength(1));
      expect(cloudData.first['id'], 'cp1');
    });

    test('syncAll uploads pending collected_species events', () async {
      final client = MockCloudSyncClient();
      final db = _createTestDatabase();
      final repo = SyncQueueRepository(db);
      final service =
          _makeService(client: client, repo: repo, db: db);

      await repo.enqueueInsert(
        tableName: 'collected_species',
        data: _speciesRow(),
      );

      final result = await service.syncAll('user1');

      expect(result.uploadedCount, 1);
      final cloudData = await client.downloadCollectedSpecies('user1');
      expect(cloudData, hasLength(1));
      expect(cloudData.first['speciesId'], 'sp1');
    });

    test('syncAll uploads pending profiles events', () async {
      final client = MockCloudSyncClient();
      final db = _createTestDatabase();
      final repo = SyncQueueRepository(db);
      final service =
          _makeService(client: client, repo: repo, db: db);

      await repo.enqueueInsert(
        tableName: 'profiles',
        data: _profileRow(),
      );

      final result = await service.syncAll('user1');

      expect(result.uploadedCount, 1);
      final profile = await client.downloadProfile('user1');
      expect(profile, isNotNull);
      expect(profile!['displayName'], 'Explorer');
    });

    // ── queue cleared after upload ────────────────────────────────────────────

    test('syncAll clears queue after successful upload', () async {
      final db = _createTestDatabase();
      final repo = SyncQueueRepository(db);
      final service = _makeService(repo: repo, db: db);

      await repo.enqueueUpdate(
        tableName: 'cell_progress',
        data: _cellProgressRow(),
      );
      expect(await repo.getSize(), 1);

      await service.syncAll('user1');

      expect(await repo.getSize(), 0);
    });

    // ── download + merge ──────────────────────────────────────────────────────

    test('syncAll downloads and merges cell progress into local DB', () async {
      final client = MockCloudSyncClient();
      await client.uploadCellProgress([_cellProgressRow()]);

      final db = _createTestDatabase();
      final service = _makeService(client: client, db: db);

      final result = await service.syncAll('user1');

      expect(result.downloadedCount, greaterThanOrEqualTo(1));
      final local = await db.getCellProgress('user1', 'cell1');
      expect(local, isNotNull);
      expect(local!.fogState, 'observed');
    });

    test('syncAll downloads and merges player profile into local DB', () async {
      final client = MockCloudSyncClient();
      await client.uploadProfile(_profileRow());

      final db = _createTestDatabase();
      final service = _makeService(client: client, db: db);

      await service.syncAll('user1');

      final profile = await db.getPlayerProfile('user1');
      expect(profile, isNotNull);
      expect(profile!.displayName, 'Explorer');
    });

    test('syncAll downloads and merges collected species into local DB',
        () async {
      final client = MockCloudSyncClient();
      await client.uploadCollectedSpecies([_speciesRow()]);

      final db = _createTestDatabase();
      final service = _makeService(client: client, db: db);

      await service.syncAll('user1');

      final species = await db.getCollectedSpeciesByUser('user1');
      expect(species, hasLength(1));
      expect(species.first.speciesId, 'sp1');
    });

    // ── upload error handling ─────────────────────────────────────────────────

    test('syncAll handles upload error gracefully — returns error result',
        () async {
      final client = MockCloudSyncClient()..simulateError = true;
      final db = _createTestDatabase();
      final repo = SyncQueueRepository(db);
      final service =
          _makeService(client: client, repo: repo, db: db);

      await repo.enqueueUpdate(
        tableName: 'cell_progress',
        data: _cellProgressRow(),
      );

      final result = await service.syncAll('user1');

      expect(result.isSuccess, isFalse);
      expect(result.errorCount, greaterThan(0));
      expect(result.errorMessage, isNotNull);
    });

    test('upload error does not crash — queue is preserved', () async {
      final client = MockCloudSyncClient()..simulateError = true;
      final db = _createTestDatabase();
      final repo = SyncQueueRepository(db);
      final service =
          _makeService(client: client, repo: repo, db: db);

      await repo.enqueueUpdate(
        tableName: 'cell_progress',
        data: _cellProgressRow(),
      );

      // Should not throw.
      await service.syncAll('user1');

      // Queue is NOT cleared when upload fails.
      expect(await repo.getSize(), 1);
    });

    // ── download error handling ───────────────────────────────────────────────

    test('syncAll handles download error gracefully — returns error result',
        () async {
      // Upload succeeds, downloads fail.
      final client = MockCloudSyncClient();
      final db = _createTestDatabase();
      final service = _makeService(client: client, db: db);

      // Enable errors only after we've already pre-seeded cloud data for
      // the upload phase (no upload events here, so upload phase is a no-op).
      client.simulateError = true;

      final result = await service.syncAll('user1');

      // Downloads fail → error result but no crash.
      expect(result.isSuccess, isFalse);
      expect(result.errorCount, greaterThan(0));
    });

    // ── getPendingCount ───────────────────────────────────────────────────────

    test('getPendingCount returns 0 when queue is empty', () async {
      final service = _makeService();

      final count = await service.getPendingCount();

      expect(count, 0);
    });

    test('getPendingCount returns queue size', () async {
      final db = _createTestDatabase();
      final repo = SyncQueueRepository(db);
      final service = _makeService(repo: repo, db: db);

      await repo.enqueueInsert(
        tableName: 'cell_progress',
        data: _cellProgressRow(id: 'cp1'),
      );
      await repo.enqueueInsert(
        tableName: 'cell_progress',
        data: _cellProgressRow(id: 'cp2', cellId: 'cell2'),
      );

      expect(await service.getPendingCount(), 2);
    });
  });
}
