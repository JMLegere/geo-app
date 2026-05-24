import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/core/domain/entities/habitat.dart';
import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/living_world/presentation/providers/npc_venue_provider.dart';
import 'package:earth_nova/features/map/domain/entities/cell.dart';

Cell _cell(String id, String cityId) {
  return Cell(
    id: id,
    habitats: const [Habitat.forest],
    polygons: const [
      [
        [
          (lat: 45.0, lng: -66.0),
          (lat: 45.0, lng: -65.9),
          (lat: 45.1, lng: -65.9),
          (lat: 45.1, lng: -66.0),
        ],
      ],
    ],
    districtId: 'district',
    cityId: cityId,
    stateId: 'state',
    countryId: 'country',
  );
}

void main() {
  test('starts with no discovered NPC venue', () {
    final container = ProviderContainer(
      overrides: [
        appObservabilityProvider.overrideWithValue(
          ObservabilityService(sessionId: 'test-session'),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(npcVenueProvider).discoveredVenue, isNull);
  });

  test('discovers the Wildlife Rehabilitation Center from the current map cell',
      () {
    final container = ProviderContainer(
      overrides: [
        appObservabilityProvider.overrideWithValue(
          ObservabilityService(sessionId: 'test-session'),
        ),
      ],
    );
    addTearDown(container.dispose);

    container
        .read(npcVenueProvider.notifier)
        .discoverWildlifeRehabilitationCenter(_cell('cell-a', 'city-a'));

    final venue = container.read(npcVenueProvider).discoveredVenue;
    expect(venue, isNotNull);
    expect(venue!.venueName, "Rowan's Wildlife Rehab Center");
    expect(venue.npcName, 'Rowan');
    expect(venue.npcRole, 'Wildlife Rehabilitator');
    expect(venue.featureName, 'Release to Wild');
    expect(venue.cellId, 'cell-a');
    expect(venue.cityId, 'city-a');
  });
}
