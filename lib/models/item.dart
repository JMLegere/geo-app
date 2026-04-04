import 'dart:convert';

import 'package:earth_nova/shared/iconography.dart';

/// Item category — what type of discovery this is.
///
/// Emoji icons are sourced from [AppIcons] — never hardcoded.
enum ItemCategory {
  fauna(AppIcons.fauna, 'Fauna'),
  flora(AppIcons.flora, 'Flora'),
  mineral(AppIcons.mineral, 'Mineral'),
  fossil(AppIcons.fossil, 'Fossil'),
  artifact(AppIcons.artifact, 'Artifact'),
  food(AppIcons.food, 'Food'),
  orb(AppIcons.orb, 'Orb');

  const ItemCategory(this.emoji, this.label);
  final String emoji;
  final String label;

  static ItemCategory fromString(String? value) {
    if (value == null) return ItemCategory.fauna;
    for (final cat in ItemCategory.values) {
      if (cat.name.toLowerCase() == value.toLowerCase()) return cat;
    }
    return ItemCategory.fauna;
  }
}

/// Item status — what state this item is in.
enum ItemStatus {
  active,
  donated,
  placed,
  released,
  traded;

  static ItemStatus fromString(String? value) {
    if (value == null) return ItemStatus.active;
    for (final s in ItemStatus.values) {
      if (s.name.toLowerCase() == value.toLowerCase()) return s;
    }
    return ItemStatus.active;
  }
}

/// A collected item instance — a species discovery.
class Item {
  const Item({
    required this.id,
    required this.definitionId,
    required this.displayName,
    this.scientificName,
    required this.category,
    this.rarity,
    this.iconUrl,
    this.iconUrlFrame2,
    this.artUrl,
    required this.acquiredAt,
    this.acquiredInCellId,
    required this.status,
    this.taxonomicClass,
    this.habitats = const [],
    this.continents = const [],
  });

  final String id;
  final String definitionId;
  final String displayName;
  final String? scientificName;
  final ItemCategory category;
  final String? rarity;
  final String? iconUrl;
  final String? iconUrlFrame2;
  final String? artUrl;
  final DateTime acquiredAt;
  final String? acquiredInCellId;
  final ItemStatus status;

  /// Raw IUCN taxonomic class (e.g. "MAMMALIA"). Null for non-species items.
  final String? taxonomicClass;

  /// Parsed habitat names (e.g. ["Forest", "Mountain"]). Empty for non-species.
  final List<String> habitats;

  /// Parsed continent names (e.g. ["Africa", "Asia"]). Empty for non-species.
  final List<String> continents;

  /// Convenience getter: maps [taxonomicClass] to a user-facing group.
  TaxonomicGroup get taxonomicGroup =>
      TaxonomicGroup.fromTaxonomicClass(taxonomicClass);

  factory Item.fromJson(Map<String, dynamic> json) => Item(
        id: json['id'] as String,
        definitionId: json['definition_id'] as String,
        displayName:
            json['display_name'] as String? ?? json['definition_id'] as String,
        scientificName: json['scientific_name'] as String?,
        category: ItemCategory.fromString(json['category'] as String?),
        rarity: json['rarity'] as String?,
        iconUrl: json['icon_url'] as String?,
        iconUrlFrame2: json['icon_url_frame2'] as String?,
        artUrl: json['art_url'] as String?,
        acquiredAt: DateTime.parse(json['acquired_at'] as String),
        acquiredInCellId: json['acquired_in_cell_id'] as String?,
        status: ItemStatus.fromString(json['status'] as String?),
        taxonomicClass: json['taxonomic_class'] as String?,
        habitats: _parseJsonArray(json['habitats_json'] as String?),
        continents: _parseJsonArray(json['continents_json'] as String?),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'definition_id': definitionId,
        'display_name': displayName,
        'scientific_name': scientificName,
        'category': category.name,
        'rarity': rarity,
        'icon_url': iconUrl,
        'icon_url_frame2': iconUrlFrame2,
        'art_url': artUrl,
        'acquired_at': acquiredAt.toIso8601String(),
        'acquired_in_cell_id': acquiredInCellId,
        'status': status.name,
        'taxonomic_class': taxonomicClass,
        'habitats_json': jsonEncode(habitats),
        'continents_json': jsonEncode(continents),
      };

  Item copyWith({
    String? id,
    String? definitionId,
    String? displayName,
    String? scientificName,
    ItemCategory? category,
    String? rarity,
    String? iconUrl,
    String? iconUrlFrame2,
    String? artUrl,
    DateTime? acquiredAt,
    String? acquiredInCellId,
    ItemStatus? status,
    String? taxonomicClass,
    List<String>? habitats,
    List<String>? continents,
  }) =>
      Item(
        id: id ?? this.id,
        definitionId: definitionId ?? this.definitionId,
        displayName: displayName ?? this.displayName,
        scientificName: scientificName ?? this.scientificName,
        category: category ?? this.category,
        rarity: rarity ?? this.rarity,
        iconUrl: iconUrl ?? this.iconUrl,
        iconUrlFrame2: iconUrlFrame2 ?? this.iconUrlFrame2,
        artUrl: artUrl ?? this.artUrl,
        acquiredAt: acquiredAt ?? this.acquiredAt,
        acquiredInCellId: acquiredInCellId ?? this.acquiredInCellId,
        status: status ?? this.status,
        taxonomicClass: taxonomicClass ?? this.taxonomicClass,
        habitats: habitats ?? this.habitats,
        continents: continents ?? this.continents,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Item &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          definitionId == other.definitionId &&
          displayName == other.displayName &&
          scientificName == other.scientificName &&
          category == other.category &&
          rarity == other.rarity &&
          iconUrl == other.iconUrl &&
          iconUrlFrame2 == other.iconUrlFrame2 &&
          artUrl == other.artUrl &&
          acquiredAt == other.acquiredAt &&
          acquiredInCellId == other.acquiredInCellId &&
          status == other.status &&
          taxonomicClass == other.taxonomicClass &&
          _listEquals(habitats, other.habitats) &&
          _listEquals(continents, other.continents);

  @override
  int get hashCode => Object.hashAll([
        id,
        definitionId,
        displayName,
        scientificName,
        category,
        rarity,
        iconUrl,
        iconUrlFrame2,
        artUrl,
        acquiredAt,
        acquiredInCellId,
        status,
        taxonomicClass,
        habitats.join(','),
        continents.join(','),
      ]);
}

/// Parse a JSON-encoded string array (e.g. '["Forest","Mountain"]').
/// Returns empty list for null, empty, or malformed input.
List<String> _parseJsonArray(String? json) {
  if (json == null || json.isEmpty || json == '[]') return const [];
  try {
    return List<String>.from(jsonDecode(json) as List);
  } catch (_) {
    return const [];
  }
}

/// Element-wise list equality (order-sensitive).
bool _listEquals(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
