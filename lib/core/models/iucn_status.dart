/// IUCN Red List conservation status, used as rarity tiers.
///
/// Weights follow a 10^x progression (Path of Exile loot table style).
/// Each tier is 10x rarer than the one above it.
enum IucnStatus {
  leastConcern(100000),
  nearThreatened(10000),
  vulnerable(1000),
  endangered(100),
  criticallyEndangered(10),
  extinct(1);

  /// Loot table weight. Higher = more common.
  final int weight;

  const IucnStatus(this.weight);

  String get displayName => switch (this) {
    IucnStatus.leastConcern => 'Least Concern',
    IucnStatus.nearThreatened => 'Near Threatened',
    IucnStatus.vulnerable => 'Vulnerable',
    IucnStatus.endangered => 'Endangered',
    IucnStatus.criticallyEndangered => 'Critically Endangered',
    IucnStatus.extinct => 'Extinct',
  };

  /// Color for UI display (conservation status indicator).
  String get colorHex => switch (this) {
    IucnStatus.leastConcern => '#4CAF50',       // Green
    IucnStatus.nearThreatened => '#8BC34A',      // Light green
    IucnStatus.vulnerable => '#FFC107',           // Amber
    IucnStatus.endangered => '#FF9800',           // Orange
    IucnStatus.criticallyEndangered => '#F44336', // Red
    IucnStatus.extinct => '#9C27B0',              // Purple
  };

  static IucnStatus fromString(String value) {
    return IucnStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => throw ArgumentError('Unknown IucnStatus: $value'),
    );
  }

  /// Parse from IUCN dataset string format.
  static IucnStatus fromIucnString(String value) {
    return switch (value) {
      'Least Concern' => IucnStatus.leastConcern,
      'Near Threatened' => IucnStatus.nearThreatened,
      'Vulnerable' => IucnStatus.vulnerable,
      'Endangered' => IucnStatus.endangered,
      'Critically Endangered' => IucnStatus.criticallyEndangered,
      'Extinct' || 'Extinct in the Wild' => IucnStatus.extinct,
      _ => throw ArgumentError('Unknown IUCN status: $value'),
    };
  }

  @override
  String toString() => name;
}
