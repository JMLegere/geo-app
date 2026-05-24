import 'package:earth_nova/features/map/domain/entities/cell.dart';

enum NpcVenueKind { wildlifeRehabilitationCenter }

class NpcVenue {
  const NpcVenue({
    required this.id,
    required this.kind,
    required this.venueName,
    required this.npcName,
    required this.npcRole,
    required this.featureName,
    required this.cellId,
    required this.cityId,
    required this.position,
  });

  final String id;
  final NpcVenueKind kind;
  final String venueName;
  final String npcName;
  final String npcRole;
  final String featureName;
  final String cellId;
  final String cityId;
  final GeoCoord position;
}
