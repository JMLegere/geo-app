import 'package:earth_nova/core/domain/entities/item.dart';

enum EncounterType {
  species,
  critter,
  loot,
}

class Encounter {
  const Encounter({
    required this.type,
    required this.speciesId,
    this.displayName = 'Unknown Discovery',
    required this.cellId,
    required this.seed,
    this.scientificName,
    this.rarity,
    this.taxonomicClass,
    this.habitats = const [],
    this.continents = const [],
    this.acquiredItem,
  });

  final EncounterType type;
  final String speciesId;
  final String displayName;
  final String cellId;
  final String seed;
  final String? scientificName;
  final String? rarity;
  final String? taxonomicClass;
  final List<String> habitats;
  final List<String> continents;
  final Item? acquiredItem;

  Encounter copyWith({
    EncounterType? type,
    String? speciesId,
    String? displayName,
    String? cellId,
    String? seed,
    String? scientificName,
    String? rarity,
    String? taxonomicClass,
    List<String>? habitats,
    List<String>? continents,
    Item? acquiredItem,
  }) {
    return Encounter(
      type: type ?? this.type,
      speciesId: speciesId ?? this.speciesId,
      displayName: displayName ?? this.displayName,
      cellId: cellId ?? this.cellId,
      seed: seed ?? this.seed,
      scientificName: scientificName ?? this.scientificName,
      rarity: rarity ?? this.rarity,
      taxonomicClass: taxonomicClass ?? this.taxonomicClass,
      habitats: habitats ?? this.habitats,
      continents: continents ?? this.continents,
      acquiredItem: acquiredItem ?? this.acquiredItem,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Encounter &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          speciesId == other.speciesId &&
          displayName == other.displayName &&
          cellId == other.cellId &&
          seed == other.seed &&
          scientificName == other.scientificName &&
          rarity == other.rarity &&
          taxonomicClass == other.taxonomicClass &&
          _listEquals(habitats, other.habitats) &&
          _listEquals(continents, other.continents) &&
          acquiredItem == other.acquiredItem;

  @override
  int get hashCode => Object.hashAll([
        type,
        speciesId,
        displayName,
        cellId,
        seed,
        scientificName,
        rarity,
        taxonomicClass,
        habitats.join(','),
        continents.join(','),
        acquiredItem,
      ]);
}

bool _listEquals(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
