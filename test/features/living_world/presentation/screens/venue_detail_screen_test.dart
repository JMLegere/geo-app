import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/living_world/data/dtos/living_world_dto.dart';
import 'package:earth_nova/features/living_world/domain/entities/town_projection.dart';
import 'package:earth_nova/ui/product_surfaces/living_world/screens/venue_detail_screen.dart';

import '../../data/living_world_test_data.dart';

void main() {
  testWidgets('shows provenance-safe Venue roster and preserves back action', (
    tester,
  ) async {
    final obs = await _openVenueDetail(tester, _venue(withVillager: true));

    expect(find.text('Harbor Current'), findsOneWidget);
    expect(find.text('Venue • Harbor'), findsOneWidget);
    expect(find.text('First known'), findsOneWidget);
    expect(find.text('7/20/2026 • Version 1'), findsOneWidget);
    expect(find.text('cell:harbor'), findsNothing);
    expect(
      find.text(
        'This Venue shows its introduced Villagers and current Services.',
      ),
      findsOneWidget,
    );
    expect(find.text('1 known Villager'), findsOneWidget);
    expect(find.text('1 current Service'), findsOneWidget);
    expect(find.text('Marin Current'), findsOneWidget);
    expect(find.text('Villager • Mechanic'), findsOneWidget);
    expect(find.text('Repairs'), findsOneWidget);
    expect(find.text('Restore worn gear.'), findsOneWidget);
    expect(find.text('Opening soon'), findsOneWidget);
    expect(find.textContaining('Visit'), findsNothing);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Open Venue'), findsOneWidget);
    final backAction = obs.pendingLogRecords.lastWhere(
      (record) =>
          record['event_name'] == 'interaction.action' &&
          (record['attributes'] as Map<String, dynamic>)['action_type'] ==
              'navigate_back',
    );
    final attributes = backAction['attributes'] as Map<String, dynamic>;
    expect(attributes['player_action_id'], 'open-town');
  });

  testWidgets('shows a safe known-empty Venue roster', (tester) async {
    await _openVenueDetail(tester, _venue(withVillager: false));

    expect(find.text('Harbor Current'), findsOneWidget);
    expect(find.text('0 known Villagers'), findsOneWidget);
    expect(find.text('0 current Services'), findsOneWidget);
    expect(find.text('No Villagers introduced here yet'), findsOneWidget);
    expect(
      find.text(
        'This Venue is known. Town will update when Villagers are introduced here.',
      ),
      findsOneWidget,
    );
    expect(find.text('Marin Current'), findsNothing);
    expect(find.text('Repairs'), findsNothing);
    expect(find.textContaining('Visit'), findsNothing);
  });
}

Future<ObservabilityService> _openVenueDetail(
  WidgetTester tester,
  TownVenue venue,
) async {
  final obs = ObservabilityService(sessionId: 'venue-detail-test');
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appObservabilityProvider.overrideWithValue(obs)],
      child: ShadApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => VenueDetailScreen(venue: venue),
                  ),
                ),
                child: const Text('Open Venue'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open Venue'));
  await tester.pumpAndSettle();
  return obs;
}

TownVenue _venue({required bool withVillager}) {
  return LivingWorldTownDto.fromJson(
    town(withVillager: withVillager),
    playerId: playerId,
  ).toDomain().venues.single;
}
