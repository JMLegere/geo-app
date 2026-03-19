import 'package:flutter/foundation.dart';

import 'animal_class.dart';
import 'animal_type.dart';
import 'climate.dart';
import 'continent.dart';
import 'food_type.dart';
import 'habitat.dart';
import 'item_category.dart';
import 'iucn_status.dart';
import 'orb_dimension.dart';
import 'season.dart';

/// Static blueprint for an item type. Loaded from bundled asset data.
///
/// Every discoverable thing in EarthNova has an [ItemDefinition] that
/// describes what it IS. Individual discoveries create [ItemInstance]s
/// that reference back to a definition.
///
/// Sealed class — exhaustive pattern matching over all 7 item categories.
/// Phase 1 implements [FaunaDefinition]. Other subtypes are stubs for
/// future phases.
@immutable
sealed class ItemDefinition {
  /// Unique ID (e.g. "fauna_vulpes_vulpes", "flora_quercus_robur").
  final String id;

  /// Human-readable name (e.g. "Red Fox", "English Oak").
  final String displayName;

  /// Scientific name for biological items. Null for minerals/artifacts.
  final String? scientificName;

  /// Optional flavor text.
  final String? description;

  /// Which of the 7 item categories this belongs to.
  final ItemCategory category;

  /// IUCN rarity tier. Gates affix pool depth on discovery.
  /// Null for items without conservation status (some artifacts).
  final IucnStatus? rarity;

  /// Habitats where this item spawns.
  final List<Habitat> habitats;

  /// Geographic regions where this item appears.
  final List<Continent> continents;

  /// Null = year-round. Non-null = only available in that season.
  final Season? seasonRestriction;

  /// Flexible metadata tags for filtering and bundle matching.
  final List<String> contextTags;

  const ItemDefinition({
    required this.id,
    required this.displayName,
    this.scientificName,
    this.description,
    required this.category,
    this.rarity,
    this.habitats = const [],
    this.continents = const [],
    this.seasonRestriction,
    this.contextTags = const [],
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ItemDefinition && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ItemDefinition($category:$id, "$displayName")';
}

// ---------------------------------------------------------------------------
// Fauna
// ---------------------------------------------------------------------------

/// A fauna item definition — one of the 32,752 real IUCN species.
///
/// This is the primary concrete [ItemDefinition] subtype.
/// Loaded from `assets/species_data.json` at startup.
@immutable
class FaunaDefinition extends ItemDefinition {
  /// Taxonomic class (e.g. "Mammalia", "Aves", "Reptilia").
  final String taxonomicClass;

  /// Computed from [taxonomicClass] via [AnimalType.fromTaxonomicClass].
  /// Null for unrecognized taxonomic classes.
  final AnimalType? animalType;

  /// AI-enriched animal class (e.g. AnimalClass.carnivore).
  /// Null until enriched on first global discovery.
  final AnimalClass? animalClass;

  /// AI-enriched food preference (e.g. FoodType.critter).
  /// Null until enriched on first global discovery.
  final FoodType? foodPreference;

  /// AI-enriched or latitude-inferred climate zone.
  /// Null until enriched or computed.
  final Climate? climate;

  /// 96x96 chibi icon URL. Null until AI enrichment completes.
  final String? iconUrl;

  /// 512x512 watercolor illustration URL. Null until AI enrichment completes.
  final String? artUrl;

  FaunaDefinition({
    required super.id,
    required super.displayName,
    required String super.scientificName,
    super.description,
    required this.taxonomicClass,
    required IucnStatus super.rarity,
    required List<Habitat> super.habitats,
    required List<Continent> super.continents,
    super.seasonRestriction,
    super.contextTags,
    this.animalClass,
    this.foodPreference,
    this.climate,
    this.iconUrl,
    this.artUrl,
  })  : animalType = AnimalType.fromTaxonomicClass(taxonomicClass),
        super(category: ItemCategory.fauna);

  /// Parse from the IUCN JSON format used in species_data.json.
  ///
  /// Maps legacy field names to the item system:
  /// - `commonName` → `displayName`
  /// - `iucnStatus` → `rarity`
  ///
  /// Computes [animalType] from [taxonomicClass] automatically.
  factory FaunaDefinition.fromJson(Map<String, dynamic> json) {
    final scientificName = json['scientificName'] as String;
    return FaunaDefinition(
      id: 'fauna_${scientificName.toLowerCase().replaceAll(' ', '_')}',
      displayName: json['commonName'] as String,
      scientificName: scientificName,
      taxonomicClass: json['taxonomicClass'] as String,
      rarity: IucnStatus.fromIucnString(json['iucnStatus'] as String),
      habitats: (json['habitats'] as List)
          .map((h) => Habitat.fromString((h as String).toLowerCase()))
          .toList(),
      continents: (json['continents'] as List)
          .map((c) => Continent.fromDataString(c as String))
          .toList(),
      animalClass: json['animalClass'] != null
          ? AnimalClass.fromString(json['animalClass'] as String)
          : null,
      foodPreference: json['foodPreference'] != null
          ? FoodType.fromString(json['foodPreference'] as String)
          : null,
      climate: json['climate'] != null
          ? Climate.fromString(json['climate'] as String)
          : null,
      iconUrl: json['icon_url'] as String?,
      artUrl: json['art_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'commonName': displayName,
        'scientificName': scientificName,
        'taxonomicClass': taxonomicClass,
        'continents': continents.map((c) => c.displayName).toList(),
        'habitats': habitats.map((h) => h.displayName).toList(),
        'iucnStatus': rarity!.displayName,
        if (animalClass != null) 'animalClass': animalClass!.name,
        if (foodPreference != null) 'foodPreference': foodPreference!.name,
        if (climate != null) 'climate': climate!.name,
        if (iconUrl != null) 'icon_url': iconUrl,
        if (artUrl != null) 'art_url': artUrl,
      };

  /// Fauna always has a scientific name — narrow the nullable base type.
  @override
  String get scientificName => super.scientificName!;

  @override
  String toString() => 'FaunaDefinition(id: $id, displayName: $displayName, '
      'scientificName: $scientificName, rarity: $rarity)';
}

// ---------------------------------------------------------------------------
// Flora
// ---------------------------------------------------------------------------

/// A flora item definition — plants, trees, fungi.
///
/// Stub for Phase 1b. No dataset yet; fromJson/toJson TBD.
@immutable
class FloraDefinition extends ItemDefinition {
  const FloraDefinition({
    required super.id,
    required super.displayName,
    super.scientificName,
    super.description,
    super.rarity,
    super.habitats,
    super.continents,
    super.seasonRestriction,
    super.contextTags,
  }) : super(category: ItemCategory.flora);

  @override
  String toString() => 'FloraDefinition(id: $id, "$displayName")';
}

// ---------------------------------------------------------------------------
// Mineral
// ---------------------------------------------------------------------------

/// A mineral item definition — rocks, crystals, gems.
///
/// Stub for Phase 1b. No dataset yet; fromJson/toJson TBD.
@immutable
class MineralDefinition extends ItemDefinition {
  const MineralDefinition({
    required super.id,
    required super.displayName,
    super.scientificName,
    super.description,
    super.rarity,
    super.habitats,
    super.continents,
    super.seasonRestriction,
    super.contextTags,
  }) : super(category: ItemCategory.mineral);

  @override
  String toString() => 'MineralDefinition(id: $id, "$displayName")';
}

// ---------------------------------------------------------------------------
// Fossil
// ---------------------------------------------------------------------------

/// A fossil item definition — ancient remains.
///
/// Stub for Phase 1b. No dataset yet; fromJson/toJson TBD.
@immutable
class FossilDefinition extends ItemDefinition {
  const FossilDefinition({
    required super.id,
    required super.displayName,
    super.scientificName,
    super.description,
    super.rarity,
    super.habitats,
    super.continents,
    super.seasonRestriction,
    super.contextTags,
  }) : super(category: ItemCategory.fossil);

  @override
  String toString() => 'FossilDefinition(id: $id, "$displayName")';
}

// ---------------------------------------------------------------------------
// Artifact
// ---------------------------------------------------------------------------

/// An artifact item definition — human-made historical objects.
///
/// Stub for Phase 1b. No dataset yet; fromJson/toJson TBD.
@immutable
class ArtifactDefinition extends ItemDefinition {
  const ArtifactDefinition({
    required super.id,
    required super.displayName,
    super.scientificName,
    super.description,
    super.rarity,
    super.habitats,
    super.continents,
    super.seasonRestriction,
    super.contextTags,
  }) : super(category: ItemCategory.artifact);

  @override
  String toString() => 'ArtifactDefinition(id: $id, "$displayName")';
}

// ---------------------------------------------------------------------------
// Food
// ---------------------------------------------------------------------------

/// A food item definition — discovered during exploration, fed to animals.
@immutable
class FoodDefinition extends ItemDefinition {
  /// The food subtype (critter, fish, fruit, grub, nectar, veg).
  final FoodType foodType;

  const FoodDefinition({
    required super.id,
    required super.displayName,
    required this.foodType,
    super.description,
    super.rarity,
    super.habitats,
    super.continents,
    super.seasonRestriction,
    super.contextTags,
  }) : super(category: ItemCategory.food);

  @override
  String toString() =>
      'FoodDefinition(id: $id, foodType: $foodType, "$displayName")';
}

// ---------------------------------------------------------------------------
// Orb
// ---------------------------------------------------------------------------

/// An orb item definition — primary currency, produced via sanctuary feeding.
///
/// Every orb has a [dimension] (habitat, animalClass, or climate) and a
/// [variant] string identifying the specific type within that dimension
/// (e.g. "forest", "carnivore", "tropic").
@immutable
class OrbDefinition extends ItemDefinition {
  /// Which dimension this orb belongs to.
  final OrbDimension dimension;

  /// The specific variant within the dimension (e.g. "forest", "carnivore").
  final String variant;

  const OrbDefinition({
    required super.id,
    required super.displayName,
    required this.dimension,
    required this.variant,
    super.description,
    super.rarity,
    super.habitats,
    super.continents,
    super.seasonRestriction,
    super.contextTags,
  }) : super(category: ItemCategory.orb);

  @override
  String toString() =>
      'OrbDefinition(id: $id, dimension: $dimension, variant: $variant, "$displayName")';
}
