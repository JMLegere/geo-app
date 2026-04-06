import 'package:earth_nova/core/domain/entities/taxonomic_group.dart';

enum ItemCategory {
  fauna('Fauna'),
  flora('Flora'),
  mineral('Mineral'),
  fossil('Fossil'),
  artifact('Artifact'),
  food('Food'),
  orb('Orb');

  const ItemCategory(this.label);

  final String label;

  static ItemCategory fromString(String? value) {
    if (value == null) return ItemCategory.fauna;
    for (final cat in ItemCategory.values) {
      if (cat.name.toLowerCase() == value.toLowerCase()) return cat;
    }
    return ItemCategory.fauna;
  }
}

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
  final String? taxonomicClass;
  final List<String> habitats;
  final List<String> continents;

  TaxonomicGroup get taxonomicGroup =>
      TaxonomicGroup.fromTaxonomicClass(taxonomicClass);

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

bool _listEquals(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
