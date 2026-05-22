import 'package:earth_nova/core/domain/entities/item.dart';

class DiscoveryItemDraft {
  const DiscoveryItemDraft({
    required this.userId,
    required this.definitionId,
    required this.displayName,
    required this.category,
    required this.acquiredInCellId,
    required this.mapCellEntryId,
    this.scientificName,
    this.rarity,
    this.taxonomicClass,
    this.habitats = const [],
    this.continents = const [],
  });

  final String userId;
  final String definitionId;
  final String displayName;
  final ItemCategory category;
  final String acquiredInCellId;
  final String mapCellEntryId;
  final String? scientificName;
  final String? rarity;
  final String? taxonomicClass;
  final List<String> habitats;
  final List<String> continents;
}
