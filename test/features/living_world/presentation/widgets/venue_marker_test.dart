import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:earth_nova/features/living_world/data/dtos/living_world_dto.dart';
import 'package:earth_nova/features/living_world/domain/entities/town_projection.dart';
import 'package:earth_nova/features/living_world/presentation/widgets/venue_marker.dart';

import '../../data/living_world_test_data.dart';

void main() {
  testWidgets('renders a known Town Venue as a compact cue', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VenueMarker(venue: _venue(withVillager: false)),
        ),
      ),
    );

    expect(find.text('HC'), findsOneWidget);
    expect(find.text('Harbor'), findsOneWidget);
    expect(find.text('Harbor Current'), findsNothing);
    expect(find.textContaining('NPC'), findsNothing);
  });

  testWidgets('collapses distant known Town Venues to a glyph-only marker',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VenueMarker(
            venue: _venue(withVillager: true),
            displayMode: VenueMarkerDisplayMode.glyphOnly,
          ),
        ),
      ),
    );

    expect(find.text('HC'), findsOneWidget);
    expect(find.text('Harbor'), findsNothing);
    expect(find.text('Harbor Current'), findsNothing);
  });
}

TownVenue _venue({required bool withVillager}) {
  return LivingWorldTownDto.fromJson(
    town(withVillager: withVillager),
    playerId: playerId,
  ).toDomain().venues.single;
}
