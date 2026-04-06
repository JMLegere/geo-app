enum EncounterType {
  species,
  critter,
  loot,
}

class Encounter {
  const Encounter({
    required this.type,
    required this.speciesId,
    required this.cellId,
    required this.seed,
  });

  final EncounterType type;
  final String speciesId;
  final String cellId;
  final String seed;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Encounter &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          speciesId == other.speciesId &&
          cellId == other.cellId &&
          seed == other.seed;

  @override
  int get hashCode => Object.hash(type, speciesId, cellId, seed);
}
