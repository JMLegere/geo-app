enum Continent {
  asia,
  northAmerica,
  southAmerica,
  africa,
  oceania,
  europe;

  String get displayName => switch (this) {
    Continent.asia => 'Asia',
    Continent.northAmerica => 'North America',
    Continent.southAmerica => 'South America',
    Continent.africa => 'Africa',
    Continent.oceania => 'Oceania',
    Continent.europe => 'Europe',
  };

  static Continent fromString(String value) {
    return Continent.values.firstWhere(
      (c) => c.name == value,
      orElse: () => throw ArgumentError('Unknown Continent: $value'),
    );
  }

  /// Parse from IUCN dataset string format or enum name.
  static Continent fromDataString(String value) {
    // Try enum name first (e.g. "northAmerica" from DB storage)
    for (final c in Continent.values) {
      if (c.name == value) return c;
    }
    // Fall back to display name (e.g. "North America" from IUCN data)
    return switch (value) {
      'Asia' => Continent.asia,
      'North America' => Continent.northAmerica,
      'South America' => Continent.southAmerica,
      'Africa' => Continent.africa,
      'Oceania' => Continent.oceania,
      'Europe' => Continent.europe,
      _ => throw ArgumentError('Unknown continent: $value'),
    };
  }

  @override
  String toString() => name;
}
