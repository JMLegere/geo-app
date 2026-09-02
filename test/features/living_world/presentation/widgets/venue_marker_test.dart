import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:earth_nova/features/living_world/data/dtos/living_world_dto.dart';
import 'package:earth_nova/features/living_world/domain/entities/town_projection.dart';
import 'package:earth_nova/features/living_world/presentation/widgets/venue_marker.dart';

import '../../data/living_world_test_data.dart';

void main() {
  testWidgets('renders a known Town Venue as a compact cue', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      ShadApp(
        home: Scaffold(body: VenueMarker(venue: _venue(withVillager: false))),
      ),
    );

    expect(find.text('HC'), findsOneWidget);
    expect(find.text('Harbor'), findsOneWidget);
    expect(find.text('Harbor Current'), findsNothing);
    expect(find.bySemanticsLabel('Harbor Current, Venue'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(VenueMarker),
        matching: find.byType(IgnorePointer),
      ),
      findsNothing,
    );
    expect(find.textContaining('NPC'), findsNothing);
    semantics.dispose();
  });

  testWidgets(
    'renders an introduced Villager name in glyph-only marker semantics',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        ShadApp(
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
      expect(
        find.bySemanticsLabel('Harbor Current, Venue with Marin Current'),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(VenueMarker),
          matching: find.byType(IgnorePointer),
        ),
        findsNothing,
      );
      semantics.dispose();
    },
  );
}

TownVenue _venue({required bool withVillager}) {
  return LivingWorldTownDto.fromJson(
    town(withVillager: withVillager),
    playerId: playerId,
  ).toDomain().venues.single;
}
