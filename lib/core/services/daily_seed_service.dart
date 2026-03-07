import 'package:flutter/foundation.dart';

import 'package:fog_of_world/shared/constants.dart';

/// Cached daily seed with metadata for staleness detection.
@immutable
class DailySeedState {
  /// The seed value (32-char hex string from server, or fallback).
  final String seed;

  /// UTC date this seed is valid for (YYYY-MM-DD).
  final String seedDate;

  /// When this seed was fetched from the server (or generated locally).
  final DateTime fetchedAt;

  /// Whether this seed came from the server (vs offline fallback).
  final bool isServerSeed;

  const DailySeedState({
    required this.seed,
    required this.seedDate,
    required this.fetchedAt,
    required this.isServerSeed,
  });

  /// Whether the cached seed has exceeded the grace period.
  bool get isStale {
    final ageHours =
        DateTime.now().toUtc().difference(fetchedAt).inHours;
    return ageHours >= kDailySeedGraceHours;
  }

  /// Whether the seed date matches today (UTC).
  bool get isForToday {
    return seedDate == _todayUtcString();
  }

  /// Age of the seed in hours.
  int get ageHours =>
      DateTime.now().toUtc().difference(fetchedAt).inHours;

  static String _todayUtcString() {
    final now = DateTime.now().toUtc();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

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

/// Callback type for fetching the daily seed from a remote server.
///
/// Returns the seed value string. Throwing indicates failure.
typedef SeedFetcher = Future<String> Function();

/// Fetches and caches the daily seed for encounter determinism.
///
/// Pure Dart class — no Riverpod or network dependency. Accepts an optional
/// [SeedFetcher] callback to support server-backed mode. When the callback
/// is null, returns a static fallback seed that never rotates.
///
/// ## Lifecycle
/// 1. Call [fetchSeed] on app open.
/// 2. Read [currentSeed] whenever encounters need the seed.
/// 3. Call [fetchSeed] again if seed becomes stale.
///
/// ## Offline mode
/// When [_fetchRemoteSeed] is null, returns a static fallback seed that never
/// rotates. Encounters still work but aren't daily-deterministic.
class DailySeedService {
  final SeedFetcher? _fetchRemoteSeed;

  DailySeedState? _cached;

  DailySeedService({SeedFetcher? fetchRemoteSeed})
      : _fetchRemoteSeed = fetchRemoteSeed;

  /// The currently cached seed, or null if [fetchSeed] hasn't been called.
  DailySeedState? get currentSeed => _cached;

  /// Whether discoveries should be paused (stale seed, can't refresh).
  bool get isDiscoveryPaused {
    final seed = _cached;
    if (seed == null) return false; // No seed yet — first fetch pending.
    return seed.isStale && seed.isServerSeed;
  }

  /// Fetch today's seed from the remote server, or return offline fallback.
  ///
  /// Returns the seed state. Caches the result internally.
  /// If already cached for today and not stale, returns cached value.
  Future<DailySeedState> fetchSeed() async {
    // Check if cached seed is still valid (same day, not stale).
    final cached = _cached;
    if (cached != null && cached.isForToday && !cached.isStale) {
      return cached;
    }

    final fetcher = _fetchRemoteSeed;
    if (fetcher == null) {
      // Offline mode — static fallback seed, never stale.
      final state = DailySeedState(
        seed: kDailySeedOfflineFallback,
        seedDate: _todayUtcString(),
        fetchedAt: DateTime.now().toUtc(),
        isServerSeed: false,
      );
      _cached = state;
      return state;
    }

    // Fetch from remote server via the injected callback.
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

      // If we have any cached seed (even stale), keep using it.
      if (cached != null) {
        return cached;
      }

      // No cached seed and can't reach server — use offline fallback.
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

  /// Force-refresh the seed, ignoring cache.
  Future<DailySeedState> refreshSeed() async {
    _cached = null;
    return fetchSeed();
  }

  static String _todayUtcString() {
    final now = DateTime.now().toUtc();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
