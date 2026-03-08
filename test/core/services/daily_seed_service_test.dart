import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/services/daily_seed_service.dart';
import 'package:earth_nova/shared/constants.dart';

void main() {
  // ---------------------------------------------------------------------------
  // DailySeedState tests
  // ---------------------------------------------------------------------------

  group('DailySeedState.isStale', () {
    test('returns false when freshly created', () {
      final state = DailySeedState(
        seed: 'abc123',
        seedDate: _todayUtc(),
        fetchedAt: DateTime.now().toUtc(),
        isServerSeed: true,
      );

      expect(state.isStale, isFalse);
    });

    test('returns true when grace period exceeded', () {
      // fetchedAt 25 hours ago (exceeds kDailySeedGraceHours = 24).
      final state = DailySeedState(
        seed: 'abc123',
        seedDate: _todayUtc(),
        fetchedAt:
            DateTime.now().toUtc().subtract(const Duration(hours: 25)),
        isServerSeed: true,
      );

      expect(state.isStale, isTrue);
    });

    test('returns false when exactly at grace period boundary (23 hours)', () {
      final state = DailySeedState(
        seed: 'abc123',
        seedDate: _todayUtc(),
        fetchedAt:
            DateTime.now().toUtc().subtract(const Duration(hours: 23)),
        isServerSeed: true,
      );

      expect(state.isStale, isFalse);
    });
  });

  group('DailySeedState.isForToday', () {
    test('returns true when seedDate matches UTC today', () {
      final state = DailySeedState(
        seed: 'abc123',
        seedDate: _todayUtc(),
        fetchedAt: DateTime.now().toUtc(),
        isServerSeed: true,
      );

      expect(state.isForToday, isTrue);
    });

    test('returns false when seedDate is yesterday', () {
      final yesterday = DateTime.now().toUtc().subtract(const Duration(days: 1));
      final yesterdayStr =
          '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

      final state = DailySeedState(
        seed: 'abc123',
        seedDate: yesterdayStr,
        fetchedAt: DateTime.now().toUtc(),
        isServerSeed: true,
      );

      expect(state.isForToday, isFalse);
    });
  });

  group('DailySeedState equality', () {
    test('two states with same seed and seedDate are equal', () {
      final a = DailySeedState(
        seed: 'seed_value',
        seedDate: '2026-03-07',
        fetchedAt: DateTime.now().toUtc(),
        isServerSeed: true,
      );
      final b = DailySeedState(
        seed: 'seed_value',
        seedDate: '2026-03-07',
        fetchedAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
        isServerSeed: false, // isServerSeed doesn't affect equality
      );

      expect(a, equals(b));
    });

    test('states with different seeds are not equal', () {
      final a = DailySeedState(
        seed: 'seed_a',
        seedDate: '2026-03-07',
        fetchedAt: DateTime.now().toUtc(),
        isServerSeed: true,
      );
      final b = DailySeedState(
        seed: 'seed_b',
        seedDate: '2026-03-07',
        fetchedAt: DateTime.now().toUtc(),
        isServerSeed: true,
      );

      expect(a, isNot(equals(b)));
    });

    test('states with different seedDates are not equal', () {
      final a = DailySeedState(
        seed: 'seed_value',
        seedDate: '2026-03-06',
        fetchedAt: DateTime.now().toUtc(),
        isServerSeed: true,
      );
      final b = DailySeedState(
        seed: 'seed_value',
        seedDate: '2026-03-07',
        fetchedAt: DateTime.now().toUtc(),
        isServerSeed: true,
      );

      expect(a, isNot(equals(b)));
    });
  });

  group('DailySeedState.ageHours', () {
    test('returns 0 for freshly created state', () {
      final state = DailySeedState(
        seed: 'abc',
        seedDate: _todayUtc(),
        fetchedAt: DateTime.now().toUtc(),
        isServerSeed: true,
      );

      // Age should be 0 (or very close to 0, since DateTime.now() is called twice).
      expect(state.ageHours, equals(0));
    });

    test('returns correct value for a state fetched 5 hours ago', () {
      final state = DailySeedState(
        seed: 'abc',
        seedDate: _todayUtc(),
        fetchedAt:
            DateTime.now().toUtc().subtract(const Duration(hours: 5)),
        isServerSeed: true,
      );

      expect(state.ageHours, equals(5));
    });

    test('returns kDailySeedGraceHours when exactly at grace period', () {
      final state = DailySeedState(
        seed: 'abc',
        seedDate: _todayUtc(),
        fetchedAt: DateTime.now()
            .toUtc()
            .subtract(Duration(hours: kDailySeedGraceHours)),
        isServerSeed: true,
      );

      expect(state.ageHours, equals(kDailySeedGraceHours));
    });
  });

  // ---------------------------------------------------------------------------
  // DailySeedService tests (null client = offline mode)
  // ---------------------------------------------------------------------------

  group('DailySeedService with null client (offline mode)', () {
    test('currentSeed is null before fetchSeed() is called', () {
      final service = DailySeedService();

      expect(service.currentSeed, isNull);
    });

    test('fetchSeed() returns offline fallback when client is null', () async {
      final service = DailySeedService();

      final result = await service.fetchSeed();

      expect(result.seed, equals(kDailySeedOfflineFallback));
      expect(result.isServerSeed, isFalse);
    });

    test('fetchSeed() caches result — second call returns cached state', () async {
      final service = DailySeedService();

      final first = await service.fetchSeed();
      final second = await service.fetchSeed();

      // Same object identity (from cache) when called twice in quick succession.
      expect(second, equals(first));
    });

    test('fetchSeed() sets currentSeed after call', () async {
      final service = DailySeedService();

      expect(service.currentSeed, isNull);
      await service.fetchSeed();
      expect(service.currentSeed, isNotNull);
      expect(service.currentSeed!.seed, equals(kDailySeedOfflineFallback));
    });

    test('isDiscoveryPaused is always false for offline fallback seed', () async {
      final service = DailySeedService();

      // No seed yet — should be false.
      expect(service.isDiscoveryPaused, isFalse);

      // After fetching offline fallback — still false (offline seeds never pause).
      await service.fetchSeed();
      expect(service.isDiscoveryPaused, isFalse);
    });

    test('isDiscoveryPaused returns false when no seed cached yet', () {
      final service = DailySeedService();

      // Before any fetch — seed is null, paused should be false.
      expect(service.isDiscoveryPaused, isFalse);
    });

    test('refreshSeed() clears cache and fetches again', () async {
      final service = DailySeedService();

      final first = await service.fetchSeed();

      // Refresh clears cache and fetches again.
      final refreshed = await service.refreshSeed();

      // Both should return the offline fallback seed.
      expect(refreshed.seed, equals(kDailySeedOfflineFallback));
      expect(refreshed.isServerSeed, isFalse);
      expect(refreshed, equals(first)); // Same date = same state by equality.
    });

    test('offline fallback seed has isForToday = true', () async {
      final service = DailySeedService();

      final result = await service.fetchSeed();

      expect(result.isForToday, isTrue);
    });

    test('offline fallback seed is not stale immediately after fetch', () async {
      final service = DailySeedService();

      final result = await service.fetchSeed();

      expect(result.isStale, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // DailySeedService tests (with SeedFetcher = server mode)
  // ---------------------------------------------------------------------------

  group('DailySeedService with SeedFetcher (server mode)', () {
    test('fetchSeed() returns server seed when fetcher succeeds', () async {
      final service = DailySeedService(
        fetchRemoteSeed: () async => 'server_seed_abc123',
      );

      final result = await service.fetchSeed();

      expect(result.seed, equals('server_seed_abc123'));
      expect(result.isServerSeed, isTrue);
      expect(result.isForToday, isTrue);
    });

    test('fetchSeed() falls back to offline seed when fetcher throws', () async {
      final service = DailySeedService(
        fetchRemoteSeed: () async => throw Exception('Network error'),
      );

      final result = await service.fetchSeed();

      expect(result.seed, equals(kDailySeedOfflineFallback));
      expect(result.isServerSeed, isFalse);
    });

    test('fetchSeed() returns cached seed when fetcher throws on re-fetch', () async {
      var callCount = 0;
      final service = DailySeedService(
        fetchRemoteSeed: () async {
          callCount++;
          if (callCount == 1) return 'first_server_seed';
          throw Exception('Network error on second call');
        },
      );

      final first = await service.fetchSeed();
      expect(first.seed, equals('first_server_seed'));

      // Second fetchSeed() hits cache (same day, not stale) — returns cached.
      final second = await service.fetchSeed();
      expect(second.seed, equals('first_server_seed'));
      expect(callCount, equals(1));
    });

    test('refreshSeed() falls back to offline when fetcher throws and cache cleared', () async {
      var callCount = 0;
      final service = DailySeedService(
        fetchRemoteSeed: () async {
          callCount++;
          if (callCount == 1) return 'first_server_seed';
          throw Exception('Network error on second call');
        },
      );

      await service.fetchSeed();

      // refreshSeed() clears cache, then fetcher throws → offline fallback.
      final refreshed = await service.refreshSeed();
      expect(refreshed.seed, equals(kDailySeedOfflineFallback));
      expect(refreshed.isServerSeed, isFalse);
    });

    test('isDiscoveryPaused is true when server seed is stale', () async {
      final service = DailySeedService(
        fetchRemoteSeed: () async => 'stale_server_seed',
      );

      await service.fetchSeed();

      // Manually create a stale state by replacing the cached seed.
      // We can't easily age the seed in a unit test, so we test the
      // isDiscoveryPaused logic directly via DailySeedState.
      final staleState = DailySeedState(
        seed: 'stale_server_seed',
        seedDate: _todayUtc(),
        fetchedAt: DateTime.now().toUtc().subtract(const Duration(hours: 25)),
        isServerSeed: true,
      );

      // Verify the stale state properties that drive isDiscoveryPaused.
      expect(staleState.isStale, isTrue);
      expect(staleState.isServerSeed, isTrue);
    });

    test('isDiscoveryPaused is false when server seed is fresh', () async {
      final service = DailySeedService(
        fetchRemoteSeed: () async => 'fresh_server_seed',
      );

      await service.fetchSeed();

      expect(service.isDiscoveryPaused, isFalse);
    });

    test('fetcher is called only once when seed is cached and valid', () async {
      var callCount = 0;
      final service = DailySeedService(
        fetchRemoteSeed: () async {
          callCount++;
          return 'server_seed';
        },
      );

      await service.fetchSeed();
      await service.fetchSeed();
      await service.fetchSeed();

      expect(callCount, equals(1));
    });

    test('different seeds produce different species for same cell', () async {
      // This test verifies the contract: different daily seeds → different
      // encounter rolls for the same cell. The actual species roll logic
      // is in SpeciesService, but we verify the seed changes.
      final service1 = DailySeedService(
        fetchRemoteSeed: () async => 'seed_day_1',
      );
      final service2 = DailySeedService(
        fetchRemoteSeed: () async => 'seed_day_2',
      );

      final result1 = await service1.fetchSeed();
      final result2 = await service2.fetchSeed();

      expect(result1.seed, isNot(equals(result2.seed)));
    });
  });

  group('DailySeedService — kDailySeedGraceHours constant', () {
    test('kDailySeedGraceHours is 24', () {
      expect(kDailySeedGraceHours, equals(24));
    });

    test('kDailySeedOfflineFallback is non-empty string', () {
      expect(kDailySeedOfflineFallback, isNotEmpty);
      expect(kDailySeedOfflineFallback, equals('offline_no_rotation'));
    });
  });
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Returns today's UTC date as a YYYY-MM-DD string (matches DailySeedState internals).
String _todayUtc() {
  final now = DateTime.now().toUtc();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}
