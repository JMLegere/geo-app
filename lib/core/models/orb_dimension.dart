
/// The 3 dimensions that define an orb's type.
///
/// Every orb belongs to exactly one dimension:
/// - [habitat]: tied to a biome (forest, plains, etc.)
/// - [animalClass]: tied to a fauna class (carnivore, songbird, etc.)
/// - [climate]: tied to a climate zone (tropic, temperate, etc.)
enum OrbDimension {
  habitat,
  animalClass,
  climate;

  String get displayName => switch (this) {
        OrbDimension.habitat => 'Habitat',
        OrbDimension.animalClass => 'Animal Class',
        OrbDimension.climate => 'Climate',
      };

  static OrbDimension fromString(String value) {
    return OrbDimension.values.firstWhere(
      (d) => d.name == value,
      orElse: () => throw ArgumentError('Unknown OrbDimension: $value'),
    );
  }

  @override
  String toString() => name;
}
