
/// Activity types that determine eligible loot categories during cell visits.
enum ActivityType {
  explore,
  forage,
  dig,
  survey;

  String get displayName => switch (this) {
        ActivityType.explore => 'Explore',
        ActivityType.forage => 'Forage',
        ActivityType.dig => 'Dig',
        ActivityType.survey => 'Survey',
      };

  static ActivityType fromString(String value) {
    return ActivityType.values.firstWhere(
      (t) => t.name == value,
      orElse: () => throw ArgumentError('Unknown ActivityType: $value'),
    );
  }

  @override
  String toString() => name;
}
