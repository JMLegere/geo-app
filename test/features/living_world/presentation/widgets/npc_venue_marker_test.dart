import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:earth_nova/features/living_world/domain/entities/npc_venue.dart';
import 'package:earth_nova/features/living_world/presentation/widgets/npc_venue_marker.dart';

const _venue = NpcVenue(
  id: 'wildlife-rehabilitation-center:city-a',
  kind: NpcVenueKind.wildlifeRehabilitationCenter,
  venueName: "Rowan's Rehab Center",
  npcName: 'Rowan',
  npcRole: 'Wildlife Rehabilitator',
  featureName: 'Release to Wild',
  cellId: 'cell-a',
  cityId: 'city-a',
  position: (lat: 45.0, lng: -66.0),
);

void main() {
  testWidgets('renders discovered NPC venue as a compact place cue',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: NpcVenueMarker(venue: _venue),
        ),
      ),
    );

    expect(find.text('WR'), findsOneWidget);
    expect(find.text('Wildlife Rehab'), findsOneWidget);
    expect(find.text("Rowan's Rehab Center"), findsNothing);
    expect(find.text('Rowan • Wildlife Rehabilitator'), findsNothing);
    expect(find.text('Release to Wild — Coming soon'), findsNothing);
  });

  testWidgets('collapses distant discovered NPC venues to a glyph-only marker',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: NpcVenueMarker(
            venue: _venue,
            displayMode: NpcVenueMarkerDisplayMode.glyphOnly,
          ),
        ),
      ),
    );

    expect(find.text('WR'), findsOneWidget);
    expect(find.text('Wildlife Rehab'), findsNothing);
    expect(find.text("Rowan's Rehab Center"), findsNothing);
  });
}
