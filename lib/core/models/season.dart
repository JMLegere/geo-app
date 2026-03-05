/// Represents the 2 seasons in the game world.
/// 
/// Seasons affect species availability — some species are only available
/// in summer, others only in winter.
enum Season {
  summer,
  winter;

  /// Returns the display name for this season.
  String get displayName => switch (this) {
    Season.summer => 'Summer',
    Season.winter => 'Winter',
  };

  /// Returns the season from a string value.
  /// 
  /// Throws [ArgumentError] if the string doesn't match any season.
  static Season fromString(String value) {
    return Season.values.firstWhere(
      (season) => season.name == value,
      orElse: () => throw ArgumentError('Unknown Season: $value'),
    );
  }

  /// Returns the string representation of this season (e.g., 'summer').
  @override
  String toString() => name;

  /// Determines the current season based on the given date.
  /// 
  /// Uses Northern Hemisphere conventions:
  /// - Summer: June 21 - September 20
  /// - Winter: December 21 - March 20
  /// - Transitions: March 21 - June 20 (summer), September 21 - December 20 (winter)
  /// 
  /// For simplicity in MVP, we use a simple month-based approach:
  /// - Summer: May - October (months 5-10)
  /// - Winter: November - April (months 11-4)
  static Season fromDate(DateTime date) {
    final month = date.month;
    // Summer: May (5) through October (10)
    if (month >= 5 && month <= 10) {
      return Season.summer;
    }
    return Season.winter;
  }

  /// Returns the other season (summer → winter, winter → summer).
  Season get opposite => switch (this) {
    Season.summer => Season.winter,
    Season.winter => Season.summer,
  };

  /// Returns true if this is the summer season.
  bool get isSummer => this == Season.summer;

  /// Returns true if this is the winter season.
  bool get isWinter => this == Season.winter;
}
