import 'package:flutter_test/flutter_test.dart';
import 'package:fog_of_world/features/sync/models/sync_exception.dart';
import 'package:fog_of_world/features/sync/services/mock_cloud_sync_client.dart';

void main() {
  group('MockCloudSyncClient', () {
    late MockCloudSyncClient client;

    setUp(() {
      client = MockCloudSyncClient();
    });

    // ── uploadCellProgress ────────────────────────────────────────────────────

    test('uploadCellProgress stores rows and downloadCellProgress returns them',
        () async {
      final rows = [
        {
          'id': 'cp1',
          'userId': 'user1',
          'cellId': 'cell1',
          'fogState': 'observed',
          'distanceWalked': 100.0,
          'visitCount': 3,
          'restorationLevel': 0.5,
          'lastVisited': null,
          'createdAt': '2026-01-01T00:00:00.000Z',
          'updatedAt': '2026-01-01T00:00:00.000Z',
        },
      ];

      await client.uploadCellProgress(rows);
      final downloaded = await client.downloadCellProgress('user1');

      expect(downloaded, hasLength(1));
      expect(downloaded.first['id'], 'cp1');
      expect(downloaded.first['userId'], 'user1');
    });

    test('downloadCellProgress filters by userId', () async {
      await client.uploadCellProgress([
        {
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
        {
          'id': 'cp2',
          'userId': 'user2',
          'cellId': 'cell2',
          'fogState': 'undetected',
          'distanceWalked': 0.0,
          'visitCount': 0,
          'restorationLevel': 0.0,
          'createdAt': '2026-01-01T00:00:00.000Z',
          'updatedAt': '2026-01-01T00:00:00.000Z',
        },
      ]);

      final user1Data = await client.downloadCellProgress('user1');
      final user2Data = await client.downloadCellProgress('user2');

      expect(user1Data, hasLength(1));
      expect(user1Data.first['id'], 'cp1');
      expect(user2Data, hasLength(1));
      expect(user2Data.first['id'], 'cp2');
    });

    // ── uploadCollectedSpecies ────────────────────────────────────────────────

    test('uploadCollectedSpecies stores rows and download returns them',
        () async {
      final rows = [
        {
          'id': 'cs1',
          'userId': 'user1',
          'speciesId': 'sp1',
          'cellId': 'cell1',
          'collectedAt': '2026-01-01T10:00:00.000Z',
        },
      ];

      await client.uploadCollectedSpecies(rows);
      final downloaded = await client.downloadCollectedSpecies('user1');

      expect(downloaded, hasLength(1));
      expect(downloaded.first['speciesId'], 'sp1');
    });

    // ── uploadProfile ─────────────────────────────────────────────────────────

    test('uploadProfile stores profile and downloadProfile returns it',
        () async {
      final profile = {
        'id': 'user1',
        'displayName': 'Explorer',
        'currentStreak': 5,
        'longestStreak': 10,
        'totalDistanceKm': 12.5,
        'currentSeason': 'summer',
        'createdAt': '2026-01-01T00:00:00.000Z',
        'updatedAt': '2026-01-02T00:00:00.000Z',
      };

      await client.uploadProfile(profile);
      final downloaded = await client.downloadProfile('user1');

      expect(downloaded, isNotNull);
      expect(downloaded!['displayName'], 'Explorer');
      expect(downloaded['currentStreak'], 5);
    });

    test('uploadProfile updates existing profile on second upload', () async {
      final v1 = {
        'id': 'user1',
        'displayName': 'Old Name',
        'currentStreak': 1,
        'longestStreak': 1,
        'totalDistanceKm': 0.0,
        'currentSeason': 'summer',
        'createdAt': '2026-01-01T00:00:00.000Z',
        'updatedAt': '2026-01-01T00:00:00.000Z',
      };
      final v2 = Map<String, dynamic>.from(v1)
        ..['displayName'] = 'New Name'
        ..['currentStreak'] = 7;

      await client.uploadProfile(v1);
      await client.uploadProfile(v2);

      final downloaded = await client.downloadProfile('user1');
      expect(downloaded!['displayName'], 'New Name');
      expect(downloaded['currentStreak'], 7);
    });

    test('downloadProfile returns null when profile does not exist', () async {
      final result = await client.downloadProfile('ghost-user');
      expect(result, isNull);
    });

    // ── simulateError ─────────────────────────────────────────────────────────

    test('simulateError causes uploadCellProgress to throw SyncException',
        () async {
      client.simulateError = true;

      await expectLater(
        client.uploadCellProgress([]),
        throwsA(isA<SyncException>()),
      );
    });

    test('simulateError causes uploadCollectedSpecies to throw SyncException',
        () async {
      client.simulateError = true;

      await expectLater(
        client.uploadCollectedSpecies([]),
        throwsA(isA<SyncException>()),
      );
    });

    test('simulateError causes uploadProfile to throw SyncException', () async {
      client.simulateError = true;

      await expectLater(
        client.uploadProfile({}),
        throwsA(isA<SyncException>()),
      );
    });

    test('simulateError causes downloadCellProgress to throw SyncException',
        () async {
      client.simulateError = true;

      await expectLater(
        client.downloadCellProgress('user1'),
        throwsA(isA<SyncException>()),
      );
    });

    test('simulateError causes downloadCollectedSpecies to throw SyncException',
        () async {
      client.simulateError = true;

      await expectLater(
        client.downloadCollectedSpecies('user1'),
        throwsA(isA<SyncException>()),
      );
    });

    test('simulateError causes downloadProfile to throw SyncException',
        () async {
      client.simulateError = true;

      await expectLater(
        client.downloadProfile('user1'),
        throwsA(isA<SyncException>()),
      );
    });

    // ── latency simulation ────────────────────────────────────────────────────

    test('upload completes after simulated 200 ms latency', () async {
      final stopwatch = Stopwatch()..start();
      await client.uploadCellProgress([]);
      stopwatch.stop();

      // Allow some tolerance around the 200 ms delay.
      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(150));
    });

    test('download completes after simulated 200 ms latency', () async {
      final stopwatch = Stopwatch()..start();
      await client.downloadCellProgress('user1');
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(150));
    });
  });
}
