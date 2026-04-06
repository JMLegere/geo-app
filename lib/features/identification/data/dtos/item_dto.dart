import 'dart:convert';

import 'package:earth_nova/core/domain/entities/item.dart';

class ItemDto {
  const ItemDto({
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
  final String category;
  final String? rarity;
  final String? iconUrl;
  final String? iconUrlFrame2;
  final String? artUrl;
  final DateTime acquiredAt;
  final String? acquiredInCellId;
  final String status;
  final String? taxonomicClass;
  final List<String> habitats;
  final List<String> continents;

  factory ItemDto.fromJson(Map<String, dynamic> json) => ItemDto(
        id: json['id'] as String,
        definitionId: json['definition_id'] as String,
        displayName:
            json['display_name'] as String? ?? json['definition_id'] as String,
        scientificName: json['scientific_name'] as String?,
        category: json['category'] as String? ?? 'fauna',
        rarity: json['rarity'] as String?,
        iconUrl: json['icon_url'] as String?,
        iconUrlFrame2: json['icon_url_frame2'] as String?,
        artUrl: json['art_url'] as String?,
        acquiredAt: DateTime.parse(json['acquired_at'] as String),
        acquiredInCellId: json['acquired_in_cell_id'] as String?,
        status: json['status'] as String? ?? 'active',
        taxonomicClass: json['taxonomic_class'] as String?,
        habitats: _parseJsonArray(json['habitats_json'] as String?),
        continents: _parseJsonArray(json['continents_json'] as String?),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'definition_id': definitionId,
        'display_name': displayName,
        'scientific_name': scientificName,
        'category': category,
        'rarity': rarity,
        'icon_url': iconUrl,
        'icon_url_frame2': iconUrlFrame2,
        'art_url': artUrl,
        'acquired_at': acquiredAt.toIso8601String(),
        'acquired_in_cell_id': acquiredInCellId,
        'status': status,
        'taxonomic_class': taxonomicClass,
        'habitats_json': jsonEncode(habitats),
        'continents_json': jsonEncode(continents),
      };

  Item toDomain() => Item(
        id: id,
        definitionId: definitionId,
        displayName: displayName,
        scientificName: scientificName,
        category: ItemCategory.fromString(category),
        rarity: rarity,
        iconUrl: iconUrl,
        iconUrlFrame2: iconUrlFrame2,
        artUrl: artUrl,
        acquiredAt: acquiredAt,
        acquiredInCellId: acquiredInCellId,
        status: ItemStatus.fromString(status),
        taxonomicClass: taxonomicClass,
        habitats: habitats,
        continents: continents,
      );

  factory ItemDto.fromDomain(Item item) => ItemDto(
        id: item.id,
        definitionId: item.definitionId,
        displayName: item.displayName,
        scientificName: item.scientificName,
        category: item.category.name,
        rarity: item.rarity,
        iconUrl: item.iconUrl,
        iconUrlFrame2: item.iconUrlFrame2,
        artUrl: item.artUrl,
        acquiredAt: item.acquiredAt,
        acquiredInCellId: item.acquiredInCellId,
        status: item.status.name,
        taxonomicClass: item.taxonomicClass,
        habitats: item.habitats,
        continents: item.continents,
      );
}

List<String> _parseJsonArray(String? json) {
  if (json == null || json.isEmpty || json == '[]') return const [];
  try {
    return List<String>.from(jsonDecode(json) as List);
  } catch (_) {
    return const [];
  }
}
