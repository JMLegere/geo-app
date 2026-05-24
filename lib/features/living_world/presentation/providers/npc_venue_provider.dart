import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/core/observability/observable_notifier.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/living_world/domain/entities/npc_venue.dart';
import 'package:earth_nova/features/map/domain/entities/cell.dart';

class NpcVenueState {
  const NpcVenueState({this.discoveredVenue});

  final NpcVenue? discoveredVenue;

  bool get hasDiscoveredVenue => discoveredVenue != null;
}

final npcVenueProvider =
    NotifierProvider<NpcVenueNotifier, NpcVenueState>(NpcVenueNotifier.new);

class NpcVenueNotifier extends ObservableNotifier<NpcVenueState> {
  @override
  ObservabilityService get obs => ref.watch(appObservabilityProvider);

  @override
  String get category => 'living_world';

  @override
  NpcVenueState build() => const NpcVenueState();

  void discoverWildlifeRehabilitationCenter(Cell currentCell) {
    final existing = state.discoveredVenue;
    if (existing != null) return;

    final venue = NpcVenue(
      id: 'wildlife-rehabilitation-center:${currentCell.cityId}',
      kind: NpcVenueKind.wildlifeRehabilitationCenter,
      venueName: 'Wildlife Rehabilitation Center',
      npcRole: 'Wildlife Rehabilitator',
      featureName: 'Release to Wild',
      cellId: currentCell.id,
      cityId: currentCell.cityId,
      position: _venuePositionFor(currentCell),
    );

    transition(
      NpcVenueState(discoveredVenue: venue),
      'living_world.npc_venue_discovered',
      data: {
        'venue_id': venue.id,
        'venue_kind': venue.kind.name,
        'cell_id': venue.cellId,
        'city_id': venue.cityId,
        'feature_name': venue.featureName,
      },
    );
  }
}

GeoCoord _venuePositionFor(Cell cell) {
  final ring = cell.primaryExteriorRing;
  if (ring.isEmpty) return (lat: 0, lng: 0);

  var lat = 0.0;
  var lng = 0.0;
  for (final point in ring) {
    lat += point.lat;
    lng += point.lng;
  }
  return (lat: lat / ring.length, lng: lng / ring.length);
}
