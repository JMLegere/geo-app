import 'package:flutter/foundation.dart';

import 'continent.dart';
import 'habitat.dart';
import 'item_category.dart';
import 'iucn_status.dart';
import 'season.dart';

/// Static blueprint for an item type. Loaded from bundled asset data.
///
/// Every discoverable thing in EarthNova has an [ItemDefinition] that
/// describes what it IS. Individual discoveries create [ItemInstance]s
/// that reference back to a definition.
///
/// Sealed class — exhaustive pattern matching over all item categories.
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

  /// Which of the 5 item categories this belongs to.
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

/// A fauna item definition — one of the 32,752 real IUCN species.
///
/// This is the only concrete [ItemDefinition] subtype in Phase 1.
/// Loaded from `assets/species_data.json` at startup.
@immutable
class FaunaDefinition extends ItemDefinition {
  /// Taxonomic class (e.g. "Mammalia", "Aves", "Reptilia").
  final String taxonomicClass;

  const FaunaDefinition({
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
  }) : super(category: ItemCategory.fauna);

  /// Parse from the IUCN JSON format used in species_data.json.
  ///
  /// Maps legacy field names to the item system:
  /// - `commonName` → `displayName`
  /// - `iucnStatus` → `rarity`
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
    );
  }

  Map<String, dynamic> toJson() => {
        'commonName': displayName,
        'scientificName': scientificName,
        'taxonomicClass': taxonomicClass,
        'continents': continents.map((c) => c.displayName).toList(),
        'habitats': habitats.map((h) => h.displayName).toList(),
        'iucnStatus': rarity!.displayName,
      };

  @override
  String toString() =>
      'FaunaDefinition(id: $id, displayName: $displayName, '
      'scientificName: $scientificName, rarity: $rarity)';
}
