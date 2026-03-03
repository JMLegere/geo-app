import 'package:fog_of_world/core/models/season.dart';
import 'package:fog_of_world/core/models/species.dart';
import 'package:fog_of_world/features/seasonal/models/seasonal_species.dart';

/// Determines seasonal availability for species and filters species pools.
///
/// All methods are pure and stateless — safe to call from any isolate or
/// test without a Flutter binding.
///
/// ## Deterministic assignment
///
/// [getAvailability] hashes `species.id` and takes `% 10`:
/// - bucket 0 → [SeasonAvailability.summerOnly]  (10%)
/// - bucket 1 → [SeasonAvailability.winterOnly]  (10%)
/// - buckets 2-9 → [SeasonAvailability.yearRound] (80%)
///
/// Because `species.id` is derived from `scientificName`, the mapping is
/// stable across app restarts.
class SeasonService {
  const SeasonService();

  /// Deterministically assigns [SeasonAvailability] to [species].
  ///
  /// Uses `species.id.hashCode % 10` as the bucket selector.
  /// Dart's `int %` with a positive divisor always returns a non-negative
  /// result, so the bucket is guaranteed to be in [0, 9].
  SeasonAvailability getAvailability(SpeciesRecord species) {
    final bucket = species.id.hashCode % 10;
    return switch (bucket) {
      0 => SeasonAvailability.summerOnly,
      1 => SeasonAvailability.winterOnly,
      _ => SeasonAvailability.yearRound,
    };
  }

  /// Returns the current [Season] based on [now] (defaults to [DateTime.now]).
  ///
  /// Delegates to [Season.fromDate] — Northern hemisphere month-based logic:
  /// May–October = summer, November–April = winter.
  Season getCurrentSeason({DateTime? now}) =>
      Season.fromDate(now ?? DateTime.now());

  /// Returns every species in [species] that is available in [season].
  List<SpeciesRecord> filterBySeason(
    List<SpeciesRecord> species,
    Season season,
  ) =>
      species.where((s) => isAvailable(s, season)).toList();

  /// Returns `true` if [species] is available during [season].
  bool isAvailable(SpeciesRecord species, Season season) =>
      getAvailability(species).isAvailableIn(season);
}
