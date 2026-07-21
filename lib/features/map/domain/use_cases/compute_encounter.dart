import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:earth_nova/core/observability/observable_use_case.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/map/domain/entities/encounter.dart';
import 'package:earth_nova/features/map/domain/rules/legacy_encounter_eligibility.dart';

typedef ComputeEncounterInput = ({
  String cellId,
  String seed,
  bool isFirstVisit,
  bool hasLoot,
});

class ComputeEncounter
    extends ObservableUseCase<ComputeEncounterInput, Encounter?> {
  ComputeEncounter(this._obs);

  final ObservabilityService _obs;

  @override
  ObservabilityService get obs => _obs;

  @override
  String get operationName => 'compute_encounter';

  /// Computes an encounter based on cellId and seed.
  ///
  /// Uses SHA-256(seed + "_" + cellId) to pick a deterministic catalog entry.
  /// The definition id may include a hash shard, but player-visible fields are
  /// readable and Pack-ready.
  ///
  /// Returns:
  /// - Species encounter on first visit
  /// - Critter encounter on revisit with loot (daily repopulated)
  /// - Null if no loot on revisit
  @override
  Future<Encounter?> execute(
      ComputeEncounterInput input, String traceId) async {
    final eligibility = legacyEncounterEligibilityCondition();
    final context = LegacyEncounterEligibilityContext(
      isFirstVisit: input.isFirstVisit,
      hasLegacyLoot: input.hasLoot,
    );
    if (!eligibility.evaluate(context)) return null;

    final hashInput = '${input.seed}_${input.cellId}';
    final hashText = sha256.convert(utf8.encode(hashInput)).toString();
    final hashShard = hashText.substring(0, 8);
    final hashValue = int.parse(hashShard, radix: 16);
    final entry = _speciesCatalog[hashValue % _speciesCatalog.length];

    final encounterType =
        input.isFirstVisit ? EncounterType.species : EncounterType.critter;

    return Encounter(
      type: encounterType,
      speciesId: 'species.${entry.slug}.$hashShard',
      displayName: entry.displayName,
      scientificName: entry.scientificName,
      rarity: _rarityFor(hashValue),
      taxonomicClass: entry.taxonomicClass,
      habitats: entry.habitats,
      continents: entry.continents,
      cellId: input.cellId,
      seed: input.seed,
    );
  }
}

String _rarityFor(int hashValue) {
  final roll = hashValue % 100;
  if (roll >= 97) return 'legendary';
  if (roll >= 90) return 'epic';
  if (roll >= 75) return 'rare';
  if (roll >= 45) return 'uncommon';
  return 'common';
}

class _SpeciesCatalogEntry {
  const _SpeciesCatalogEntry({
    required this.slug,
    required this.displayName,
    required this.scientificName,
    required this.taxonomicClass,
    required this.habitats,
    required this.continents,
  });

  final String slug;
  final String displayName;
  final String scientificName;
  final String taxonomicClass;
  final List<String> habitats;
  final List<String> continents;
}

const _speciesCatalog = [
  _SpeciesCatalogEntry(
    slug: 'amberwing_warbler',
    displayName: 'Amberwing Warbler',
    scientificName: 'Setophaga aestiva',
    taxonomicClass: 'Aves',
    habitats: ['forest', 'wetland'],
    continents: ['North America'],
  ),
  _SpeciesCatalogEntry(
    slug: 'red_fox',
    displayName: 'Red Fox',
    scientificName: 'Vulpes vulpes',
    taxonomicClass: 'Mammalia',
    habitats: ['forest', 'grassland', 'urban'],
    continents: ['North America', 'Europe', 'Asia'],
  ),
  _SpeciesCatalogEntry(
    slug: 'monarch_butterfly',
    displayName: 'Monarch Butterfly',
    scientificName: 'Danaus plexippus',
    taxonomicClass: 'Insecta',
    habitats: ['grassland', 'urban'],
    continents: ['North America'],
  ),
  _SpeciesCatalogEntry(
    slug: 'painted_turtle',
    displayName: 'Painted Turtle',
    scientificName: 'Chrysemys picta',
    taxonomicClass: 'Reptilia',
    habitats: ['freshwater', 'wetland'],
    continents: ['North America'],
  ),
  _SpeciesCatalogEntry(
    slug: 'snowshoe_hare',
    displayName: 'Snowshoe Hare',
    scientificName: 'Lepus americanus',
    taxonomicClass: 'Mammalia',
    habitats: ['forest'],
    continents: ['North America'],
  ),
  _SpeciesCatalogEntry(
    slug: 'brook_trout',
    displayName: 'Brook Trout',
    scientificName: 'Salvelinus fontinalis',
    taxonomicClass: 'Actinopterygii',
    habitats: ['freshwater'],
    continents: ['North America'],
  ),
  _SpeciesCatalogEntry(
    slug: 'great_blue_heron',
    displayName: 'Great Blue Heron',
    scientificName: 'Ardea herodias',
    taxonomicClass: 'Aves',
    habitats: ['freshwater', 'wetland', 'coastal'],
    continents: ['North America'],
  ),
  _SpeciesCatalogEntry(
    slug: 'eastern_chipmunk',
    displayName: 'Eastern Chipmunk',
    scientificName: 'Tamias striatus',
    taxonomicClass: 'Mammalia',
    habitats: ['forest', 'urban'],
    continents: ['North America'],
  ),
];
