/// Geographic hierarchy levels for the exploration view system.
///
/// Pinch out navigates up (district→city→state→country→world).
/// Pinch in or back navigates down (world→country→state→city→district→map).
enum HierarchyLevel {
  district,
  city,
  state,
  country,
  world;

  /// The level above this one (pinch out destination).
  /// Returns null for world (top of hierarchy).
  HierarchyLevel? get above => switch (this) {
        HierarchyLevel.district => HierarchyLevel.city,
        HierarchyLevel.city => HierarchyLevel.state,
        HierarchyLevel.state => HierarchyLevel.country,
        HierarchyLevel.country => HierarchyLevel.world,
        HierarchyLevel.world => null,
      };

  /// The level below this one (pinch in destination).
  /// Returns null for district (bottom — goes to map).
  HierarchyLevel? get below => switch (this) {
        HierarchyLevel.district => null,
        HierarchyLevel.city => HierarchyLevel.district,
        HierarchyLevel.state => HierarchyLevel.city,
        HierarchyLevel.country => HierarchyLevel.state,
        HierarchyLevel.world => HierarchyLevel.country,
      };

  /// Human-readable label for display.
  String get label => switch (this) {
        HierarchyLevel.district => 'District',
        HierarchyLevel.city => 'City',
        HierarchyLevel.state => 'State',
        HierarchyLevel.country => 'Country',
        HierarchyLevel.world => 'World',
      };
}
