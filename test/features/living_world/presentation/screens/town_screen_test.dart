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
        venueName: "Rowan's Rehab Center",
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

  testWidgets('opens a dedicated NPC-first venue page after NPC discovery',
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

    expect(find.text("Rowan's Rehab Center"), findsOneWidget);
    expect(
      find.text('Rowan  •  Release to Wild  •  Coming soon'),
      findsOneWidget,
    );
    expect(find.text('Wildlife Rehabilitator'), findsNothing);
    expect(find.text('Not yet accepting releases.'), findsNothing);

    await tester.tap(find.text("Rowan's Rehab Center"));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Back'), findsOneWidget);
    expect(find.text("Rowan's Rehab Center"), findsOneWidget);
    expect(find.text('Rowan'), findsOneWidget);
    expect(find.text('Wildlife Rehabilitator'), findsOneWidget);
    expect(find.text('Features'), findsOneWidget);
    expect(find.text('Release to Wild'), findsOneWidget);
    expect(find.text('Coming soon'), findsOneWidget);
    expect(
      find.text(
        'Rowan is preparing local release programs for animals that are ready to return to the wild.',
      ),
      findsOneWidget,
    );
  });
}
