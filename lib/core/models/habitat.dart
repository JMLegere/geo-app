/// The 7 habitat types from the IUCN species dataset.
enum Habitat {
  forest,
  plains,
  freshwater,
  saltwater,
  swamp,
  mountain,
  desert;

  String get displayName => switch (this) {
    Habitat.forest => 'Forest',
    Habitat.plains => 'Plains',
    Habitat.freshwater => 'Freshwater',
    Habitat.saltwater => 'Saltwater',
    Habitat.swamp => 'Swamp',
    Habitat.mountain => 'Mountain',
    Habitat.desert => 'Desert',
  };

  String get colorHex => switch (this) {
    Habitat.forest => '#2D5016',
    Habitat.plains => '#C4B454',
    Habitat.freshwater => '#3C5AA6',
    Habitat.saltwater => '#1F7F8F',
    Habitat.swamp => '#4A6741',
    Habitat.mountain => '#8B7355',
    Habitat.desert => '#D2B48C',
  };

  static Habitat fromString(String value) {
    return Habitat.values.firstWhere(
      (h) => h.name == value,
      orElse: () => throw ArgumentError('Unknown Habitat: $value'),
    );
  }

  @override
  String toString() => name;
}
