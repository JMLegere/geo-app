import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:earth_nova/models/affix.dart';
import 'package:earth_nova/models/continent.dart';
import 'package:earth_nova/models/habitat.dart';
import 'package:earth_nova/models/item_category.dart';
import 'package:earth_nova/models/iucn_status.dart';

/// A unique discovered item. Every discovery creates a new instance.
///
/// PoE / CryptoKitty model: no stacking. Two Red Foxes found in different
/// cells have different randomly-rolled affixes. Each instance has its own
/// UUID.
///
/// ## Denormalized identity fields
///
/// [displayName], [scientificName], [category], [rarity], [habitats],
/// [continents], and [taxonomicClass] are snapshotted from the
/// [ItemDefinition] at discovery time. This makes each instance fully
/// self-contained — the definition registry is not required to render
/// basic item identity. [definitionId] is still kept for lookups
/// (enrichment, species service).
///
/// Lifecycle: active → donated | placed | released | traded.
@immutable
class ItemInstance {
  /// Globally unique ID (UUID v4).
  final String id;

  /// References [ItemDefinition.id] — the static blueprint for this item.
  /// Kept for enrichment lookups and species service access.
  final String definitionId;

  // ---------------------------------------------------------------------------
  // Denormalized identity fields (snapshotted from definition at discovery)
  // ---------------------------------------------------------------------------

  /// Human-readable name (e.g. "Red Fox"). Snapshotted from definition.
  final String displayName;

  /// Scientific name for biological items. Null for minerals/artifacts/etc.
  final String? scientificName;

  /// Which of the 7 item categories this belongs to. Snapshotted from definition.
  final ItemCategory category;

  /// IUCN rarity tier. Null for items without conservation status.
  final IucnStatus? rarity;

  /// Habitats where this item spawns. Snapshotted from definition.
  final List<Habitat> habitats;

  /// Geographic regions where this item appears. Snapshotted from definition.
  final List<Continent> continents;

  /// Taxonomic class string (e.g. "Mammalia", "Aves"). Fauna only — null for
  /// all other categories.
  final String? taxonomicClass;

  // ---------------------------------------------------------------------------
  // Instance-specific fields
  // ---------------------------------------------------------------------------

  /// Item modifiers: one intrinsic (base stats) + rolled prefix/suffix.
  ///
  /// Every wild-caught instance has exactly one [AffixType.intrinsic] affix
  /// containing speed, brawn, and wit stats.
  /// Rarity gates prefix/suffix pool depth: LC=0-1, NT=1-2, VU=2-3, EN=3-4, CR=4-5, EX=5+.
  final List<Affix> affixes;

  /// Instance-level badges / flags assigned at creation time.
  ///
  /// Badges are simple string identifiers (e.g. 'first_discovery', 'beta',
  /// 'pioneer', 'art_winner'). They grant visual treatment (borders, icons)
  /// but carry no stat values — that's what [affixes] are for.
  ///
  /// Stored as a JSON array in the database.
  final Set<String> badges;

  /// Instance-level icon override. Null = use species default.
  final String? iconUrl;

  /// Instance-level illustration override. Null = use species default.
  final String? artUrl;

  // ---------------------------------------------------------------------------
  // Denormalized enrichment fields (snapshotted at discovery or lazily enriched)
  // ---------------------------------------------------------------------------

  // --- Species enrichment (base stats from FaunaDefinition) ---

  /// AI-determined animal class name (e.g. "Carnivore"). Fauna only.
  final String? animalClassName;

  /// AI-determined food preference name (e.g. "food-critter"). Fauna only.
  final String? foodPreferenceName;

  /// Climate zone name (e.g. "temperate"). Derived from species range.
  final String? climateName;

  /// AI-canonical brawn stat (contributes to stat total of 90).
  final int? brawn;

  /// AI-canonical wit stat (contributes to stat total of 90).
  final int? wit;

  /// AI-canonical speed stat (contributes to stat total of 90).
  final int? speed;

  /// AI-canonical size category name (e.g. "medium").
  final String? sizeName;

  // --- Cell properties (from CellProperties at discovery) ---

  /// Habitat name of the cell where this item was discovered.
  final String? cellHabitatName;

  /// Climate name of the cell where this item was discovered.
  final String? cellClimateName;

  /// Continent name of the cell where this item was discovered.
  final String? cellContinentName;

  // --- Location hierarchy (lazily enriched from LocationNode chain) ---

  /// District-level location name (admin level 6 or equivalent).
  final String? locationDistrict;

  /// City-level location name.
  final String? locationCity;

  /// State/province-level location name.
  final String? locationState;

  /// Country name.
  final String? locationCountry;

  /// ISO 3166-1 alpha-2 country code (e.g. "CA").
  final String? locationCountryCode;

  /// Null for wild-caught. Set for bred offspring.
  final String? parentAId;

  /// Null for wild-caught. Set for bred offspring.
  final String? parentBId;

  /// When the player acquired this item.
  final DateTime acquiredAt;

  /// Cell where this item was found. Null for bred items.
  final String? acquiredInCellId;

  /// Daily seed used for this roll (for server-side re-derivation).
  final String? dailySeed;

  /// Current lifecycle status.
  final ItemInstanceStatus status;

  const ItemInstance({
    required this.id,
    required this.definitionId,
    required this.displayName,
    this.scientificName,
    required this.category,
    this.rarity,
    this.habitats = const [],
    this.continents = const [],
    this.taxonomicClass,
    this.affixes = const [],
    this.badges = const {},
    this.iconUrl,
    this.artUrl,
    this.animalClassName,
    this.foodPreferenceName,
    this.climateName,
    this.brawn,
    this.wit,
    this.speed,
    this.sizeName,
    this.cellHabitatName,
    this.cellClimateName,
    this.cellContinentName,
    this.locationDistrict,
    this.locationCity,
    this.locationState,
    this.locationCountry,
    this.locationCountryCode,
    this.parentAId,
    this.parentBId,
    required this.acquiredAt,
    this.acquiredInCellId,
    this.dailySeed,
    this.status = ItemInstanceStatus.active,
  });

  /// Count of non-null enrichable data fields.
  int get enrichedFieldCount {
    int count = 0;
    if (animalClassName != null) count++;
    if (foodPreferenceName != null) count++;
    if (climateName != null) count++;
    if (brawn != null) count++;
    if (wit != null) count++;
    if (speed != null) count++;
    if (sizeName != null) count++;
    if (iconUrl != null) count++;
    if (artUrl != null) count++;
    if (cellHabitatName != null) count++;
    if (cellClimateName != null) count++;
    if (cellContinentName != null) count++;
    if (locationDistrict != null) count++;
    if (locationCity != null) count++;
    if (locationState != null) count++;
    if (locationCountry != null) count++;
    if (locationCountryCode != null) count++;
    return count;
  }

  static const int totalEnrichableFields = 17;

  /// Whether this item was caught in the wild (not bred).
  bool get isWildCaught => parentAId == null && parentBId == null;

  /// Whether this item was bred from two parents.
  bool get isBred => parentAId != null && parentBId != null;

  /// Whether this instance has the first-discovery badge (shiny foil).
  bool get isFirstDiscovery => badges.contains('first_discovery');

  // TODO(phase5): copyWith cannot null out optional fields (parentAId,
  // parentBId, acquiredInCellId, dailySeed). When breeding needs to clear
  // parentage, adopt a sentinel pattern (e.g. Value<T> wrappers or
  // nullable Function() closures).
  ItemInstance copyWith({
    String? id,
    String? definitionId,
    String? displayName,
    String? scientificName,
    ItemCategory? category,
    IucnStatus? rarity,
    List<Habitat>? habitats,
    List<Continent>? continents,
    String? taxonomicClass,
    List<Affix>? affixes,
    Set<String>? badges,
    String? iconUrl,
    String? artUrl,
    String? animalClassName,
    String? foodPreferenceName,
    String? climateName,
    int? brawn,
    int? wit,
    int? speed,
    String? sizeName,
    String? cellHabitatName,
    String? cellClimateName,
    String? cellContinentName,
    String? locationDistrict,
    String? locationCity,
    String? locationState,
    String? locationCountry,
    String? locationCountryCode,
    String? parentAId,
    String? parentBId,
    DateTime? acquiredAt,
    String? acquiredInCellId,
    String? dailySeed,
    ItemInstanceStatus? status,
  }) {
    return ItemInstance(
      id: id ?? this.id,
      definitionId: definitionId ?? this.definitionId,
      displayName: displayName ?? this.displayName,
      scientificName: scientificName ?? this.scientificName,
      category: category ?? this.category,
      rarity: rarity ?? this.rarity,
      habitats: habitats ?? this.habitats,
      continents: continents ?? this.continents,
      taxonomicClass: taxonomicClass ?? this.taxonomicClass,
      affixes: affixes ?? this.affixes,
      badges: badges ?? this.badges,
      iconUrl: iconUrl ?? this.iconUrl,
      artUrl: artUrl ?? this.artUrl,
      animalClassName: animalClassName ?? this.animalClassName,
      foodPreferenceName: foodPreferenceName ?? this.foodPreferenceName,
      climateName: climateName ?? this.climateName,
      brawn: brawn ?? this.brawn,
      wit: wit ?? this.wit,
      speed: speed ?? this.speed,
      sizeName: sizeName ?? this.sizeName,
      cellHabitatName: cellHabitatName ?? this.cellHabitatName,
      cellClimateName: cellClimateName ?? this.cellClimateName,
      cellContinentName: cellContinentName ?? this.cellContinentName,
      locationDistrict: locationDistrict ?? this.locationDistrict,
      locationCity: locationCity ?? this.locationCity,
      locationState: locationState ?? this.locationState,
      locationCountry: locationCountry ?? this.locationCountry,
      locationCountryCode: locationCountryCode ?? this.locationCountryCode,
      parentAId: parentAId ?? this.parentAId,
      parentBId: parentBId ?? this.parentBId,
      acquiredAt: acquiredAt ?? this.acquiredAt,
      acquiredInCellId: acquiredInCellId ?? this.acquiredInCellId,
      dailySeed: dailySeed ?? this.dailySeed,
      status: status ?? this.status,
    );
  }

  /// Serialize affixes list to JSON string for database storage.
  String affixesToJson() => jsonEncode(affixes.map((a) => a.toJson()).toList());

  /// Deserialize affixes list from JSON string (database storage).
  static List<Affix> affixesFromJson(String json) {
    final list = jsonDecode(json) as List;
    return list.map((a) => Affix.fromJson(a as Map<String, dynamic>)).toList();
  }

  /// Serialize badges set to JSON string for database storage.
  String badgesToJson() => jsonEncode(badges.toList());

  /// Deserialize badges set from JSON string (database storage).
  static Set<String> badgesFromJson(String json) {
    final list = jsonDecode(json) as List;
    return list.cast<String>().toSet();
  }

  /// Serialize habitats list to JSON string for database storage.
  String habitatsToJson() => jsonEncode(habitats.map((h) => h.name).toList());

  /// Deserialize habitats list from JSON string (database storage).
  static List<Habitat> habitatsFromJson(String? json) {
    if (json == null || json.isEmpty) return const [];
    try {
      final list = jsonDecode(json) as List;
      return list
          .whereType<String>()
          .map((s) => Habitat.values.firstWhere(
                (h) => h.name == s,
                orElse: () => Habitat.forest,
              ))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Serialize continents list to JSON string for database storage.
  String continentsToJson() =>
      jsonEncode(continents.map((c) => c.name).toList());

  /// Deserialize continents list from JSON string (database storage).
  static List<Continent> continentsFromJson(String? json) {
    if (json == null || json.isEmpty) return const [];
    try {
      final list = jsonDecode(json) as List;
      return list
          .whereType<String>()
          .map((s) => Continent.values.firstWhere(
                (c) => c.name == s,
                orElse: () => Continent.asia,
              ))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ItemInstance && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ItemInstance(id: $id, definitionId: $definitionId, '
      'displayName: $displayName, category: $category, rarity: $rarity, '
      'affixes: ${affixes.length}, status: $status, '
      'enrichedFields: $enrichedFieldCount/$totalEnrichableFields)';
}

/// Lifecycle status of an item instance.
enum ItemInstanceStatus {
  /// In player's active inventory.
  active,

  /// Permanently donated to museum.
  donated,

  /// Placed in sanctuary.
  placed,

  /// Released back to the wild.
  released,

  /// Traded to another player.
  traded;

  static ItemInstanceStatus fromString(String value) {
    return ItemInstanceStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => throw ArgumentError('Unknown ItemInstanceStatus: $value'),
    );
  }

  @override
  String toString() => name;
}
