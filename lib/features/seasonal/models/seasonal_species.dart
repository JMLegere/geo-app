import 'package:earth_nova/core/models/season.dart';

/// Describes whether a species is available all year or only in one season.
///
/// Assignment is deterministic via `SeasonService.getAvailability` — the same
/// species always maps to the same availability bucket across runs.
enum SeasonAvailability {
  /// Available in both summer and winter (80% of species).
  yearRound,

  /// Available only during summer (May–October, Northern hemisphere) — 10%.
  summerOnly,

  /// Available only during winter (November–April, Northern hemisphere) — 10%.
  winterOnly;

  /// Returns `true` if this availability allows the species during [season].
  bool isAvailableIn(Season season) => switch (this) {
    SeasonAvailability.yearRound => true,
    SeasonAvailability.summerOnly => season.isSummer,
    SeasonAvailability.winterOnly => season.isWinter,
  };
}
