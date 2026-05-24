import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:earth_nova/features/living_world/domain/entities/npc_venue.dart';
import 'package:earth_nova/features/living_world/presentation/widgets/npc_venue_marker.dart';

const _venue = NpcVenue(
  id: 'wildlife-rehabilitation-center:city-a',
  kind: NpcVenueKind.wildlifeRehabilitationCenter,
  venueName: 'Wildlife Rehabilitation Center',
  npcRole: 'Wildlife Rehabilitator',
  featureName: 'Release to Wild',
  cellId: 'cell-a',
  cityId: 'city-a',
  position: (lat: 45.0, lng: -66.0),
);

void main() {
  testWidgets('renders discovered NPC venue marker on the map', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: NpcVenueMarker(venue: _venue),
        ),
      ),
    );

    expect(find.text('Wildlife Rehabilitation Center'), findsOneWidget);
    expect(find.text('Release to Wild — Coming soon'), findsOneWidget);
  });
}
