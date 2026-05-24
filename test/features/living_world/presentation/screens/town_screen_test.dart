import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/living_world/domain/entities/npc_venue.dart';
import 'package:earth_nova/features/living_world/presentation/providers/npc_venue_provider.dart';
import 'package:earth_nova/features/living_world/presentation/screens/town_screen.dart';

class _DiscoveredNpcVenueNotifier extends NpcVenueNotifier {
  @override
  NpcVenueState build() {
    return const NpcVenueState(
      discoveredVenue: NpcVenue(
        id: 'wildlife-rehabilitation-center:city-a',
        kind: NpcVenueKind.wildlifeRehabilitationCenter,
        venueName: "Rowan's Wildlife Rehab Center",
        npcName: 'Rowan',
        npcRole: 'Wildlife Rehabilitator',
        featureName: 'Release to Wild',
        cellId: 'cell-a',
        cityId: 'city-a',
        position: (lat: 45.0, lng: -66.0),
      ),
    );
  }
}

void main() {
  testWidgets('shows map exploration empty state before NPC discovery',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appObservabilityProvider.overrideWithValue(
            ObservabilityService(sessionId: 'test-session'),
          ),
        ],
        child: const MaterialApp(home: TownScreen()),
      ),
    );

    expect(find.text('Town'), findsOneWidget);
    expect(find.text('No local places discovered yet'), findsOneWidget);
    expect(
      find.text(
        'Explore the map to meet local characters and uncover their places.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
      'shows a character-owned Wildlife Rehab Center after NPC discovery',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appObservabilityProvider.overrideWithValue(
            ObservabilityService(sessionId: 'test-session'),
          ),
          npcVenueProvider.overrideWith(() => _DiscoveredNpcVenueNotifier()),
        ],
        child: const MaterialApp(home: TownScreen()),
      ),
    );

    expect(find.text("Rowan's Wildlife Rehab Center"), findsOneWidget);
    expect(find.text('Rowan'), findsOneWidget);
    expect(find.text('Wildlife Rehabilitator'), findsOneWidget);
    expect(find.text('Release to Wild'), findsOneWidget);
    expect(find.text('OPENING SOON'), findsOneWidget);
    expect(find.text('Not yet accepting releases.'), findsOneWidget);
  });
}
