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
        Habitat.forest => '#2D7A2D',
        Habitat.plains => '#D4C44A',
        Habitat.freshwater => '#3C7AD4',
        Habitat.saltwater => '#2AB5B5',
        Habitat.swamp => '#7A3CB5',
        Habitat.mountain => '#C43C3C',
        Habitat.desert => '#D4872A',
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
