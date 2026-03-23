import 'package:flutter/foundation.dart';
import 'package:meta/meta.dart';

import 'package:earth_nova/shared/constants.dart';

String _todayUtcString() {
  final now = DateTime.now().toUtc();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

@immutable
class DailySeedState {
  final String seed;
  final String seedDate;
  final DateTime fetchedAt;
  final bool isServerSeed;

  const DailySeedState({
    required this.seed,
    required this.seedDate,
    required this.fetchedAt,
    required this.isServerSeed,
  });

  bool get isStale {
    final ageHours = DateTime.now().toUtc().difference(fetchedAt).inHours;
    return ageHours >= kDailySeedGraceHours;
  }

  bool get isForToday {
    return seedDate == _todayUtcString();
  }

  int get ageHours => DateTime.now().toUtc().difference(fetchedAt).inHours;

  // Equality by seed+date only — fetchedAt and isServerSeed are metadata,
  // not identity. Two states with same seed on same date are functionally equal.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailySeedState &&
          other.seed == seed &&
          other.seedDate == seedDate;

  @override
  int get hashCode => Object.hash(seed, seedDate);

  @override
  String toString() =>
      'DailySeedState(date: $seedDate, stale: $isStale, server: $isServerSeed)';
}

typedef SeedFetcher = Future<String> Function();

class DailySeedService {
  final SeedFetcher? _fetchRemoteSeed;

  DailySeedState? _cached;

  DailySeedService({SeedFetcher? fetchRemoteSeed})
      : _fetchRemoteSeed = fetchRemoteSeed;

  DailySeedState? get currentSeed => _cached;

  /// Inject a cached state for testing. Production code uses [fetchSeed].
  @visibleForTesting
  set cachedSeedForTest(DailySeedState? state) => _cached = state;

  bool get isDiscoveryPaused {
    final seed = _cached;
    if (seed == null) return false; // No seed yet — first fetch pending.
    return seed.isStale && seed.isServerSeed;
  }

  Future<DailySeedState> fetchSeed() async {
    final cached = _cached;
    if (cached != null && cached.isForToday && !cached.isStale) {
      return cached;
    }

    final fetcher = _fetchRemoteSeed;
    if (fetcher == null) {
      final state = DailySeedState(
        seed: kDailySeedOfflineFallback,
        seedDate: _todayUtcString(),
        fetchedAt: DateTime.now().toUtc(),
        isServerSeed: false,
      );
      _cached = state;
      return state;
    }

    try {
      final seedValue = await fetcher();

      final state = DailySeedState(
        seed: seedValue,
        seedDate: _todayUtcString(),
        fetchedAt: DateTime.now().toUtc(),
        isServerSeed: true,
      );
      _cached = state;
      return state;
    } catch (e) {
      debugPrint('[DailySeedService] Failed to fetch seed: $e');
      if (cached != null) {
        return cached;
      }

      final state = DailySeedState(
        seed: kDailySeedOfflineFallback,
        seedDate: _todayUtcString(),
        fetchedAt: DateTime.now().toUtc(),
        isServerSeed: false,
      );
      _cached = state;
      return state;
    }
  }

  Future<DailySeedState> refreshSeed() async {
    // Preserve the existing valid seed before clearing, so fetchSeed()'s
    // catch block can fall back to it if the server request fails — instead
    // of replacing the real seed with kDailySeedOfflineFallback.
    final previousSeed = _cached;
    _cached = null;
    final result = await fetchSeed();
    // If fetchSeed() fell back to the offline seed (fetch failed and cached
    // was null because we just cleared it), restore the previous valid seed.
    if (!result.isServerSeed && previousSeed != null) {
      _cached = previousSeed;
      return previousSeed;
    }
    return result;
  }
}
