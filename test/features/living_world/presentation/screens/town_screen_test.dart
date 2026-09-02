import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:earth_nova/core/domain/entities/auth_state.dart';
import 'package:earth_nova/core/domain/entities/user_profile.dart';
import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/auth/presentation/providers/auth_provider.dart';
import 'package:earth_nova/features/living_world/data/dtos/living_world_dto.dart';
import 'package:earth_nova/features/living_world/domain/entities/living_world_knowledge.dart';
import 'package:earth_nova/features/living_world/domain/entities/town_projection.dart';
import 'package:earth_nova/features/living_world/domain/repositories/living_world_repository.dart';
import 'package:earth_nova/features/living_world/presentation/providers/town_provider.dart';
import 'package:earth_nova/features/living_world/presentation/screens/town_screen.dart';

import '../../data/living_world_test_data.dart';

const _secondVenueVersionId = '00000000-0000-4000-8000-000000000011';
const _secondFirstVenueVersionId = '00000000-0000-4000-8000-000000000012';
const _secondOutcomeId = '00000000-0000-4000-8000-000000000013';
const _secondEncounterId = '00000000-0000-4000-8000-000000000014';

void main() {
  testWidgets('shows loading while Town projection read is pending', (
    tester,
  ) async {
    final pending = Completer<TownProjection>();
    await _pumpTown(tester, onRead: (_) => pending.future, settle: false);

    expect(find.text('Loading Town'), findsOneWidget);
    expect(
      find.text('Gathering the places and people you know.'),
      findsOneWidget,
    );

    pending.complete(_projection([]));
    await tester.pumpAndSettle();
    expect(find.text('No Venues known yet'), findsOneWidget);
  });

  testWidgets('shows error state and retries the Town projection read', (
    tester,
  ) async {
    var attempts = 0;
    final repository = await _pumpTown(
      tester,
      onRead: (_) {
        attempts += 1;
        if (attempts == 1) {
          return Future<TownProjection>.error(
            const LivingWorldFailure.unavailable(),
          );
        }
        return Future.value(_projection([]));
      },
    );

    expect(find.text('Town could not load'), findsOneWidget);
    expect(find.text('Unable to load your Town. Try again.'), findsOneWidget);

    await tester.tap(find.text('Retry Town load'));
    await tester.pumpAndSettle();

    expect(repository.reads, 2);
    expect(find.text('No Venues known yet'), findsOneWidget);
  });

  testWidgets('shows empty Town before any Venue reveal', (tester) async {
    final repository = await _pumpTown(
      tester,
      onRead: (_) async => _projection([]),
    );

    expect(find.text('Town'), findsOneWidget);
    expect(find.text('No Venues known yet'), findsOneWidget);
    expect(
      find.text('Known Venues appear here as the Map reveals them.'),
      findsOneWidget,
    );
    expect(repository.records, 0);
    expect(find.textContaining('NPC'), findsNothing);
    expect(find.textContaining('Character'), findsNothing);
    expect(find.textContaining('Feature'), findsNothing);
    expect(find.textContaining('Place'), findsNothing);
  });

  testWidgets('shows a known Venue with zero Villagers before introduction', (
    tester,
  ) async {
    await _pumpTown(
      tester,
      onRead: (_) async => _projection([_venueJson(villagers: const [])]),
    );

    expect(find.text('Harbor Current'), findsOneWidget);
    expect(find.text('No Villagers introduced here yet'), findsOneWidget);
    expect(
      find.text(
        'This Venue is known. Town will update when Villagers are introduced here.',
      ),
      findsOneWidget,
    );
    expect(find.text('0 Villagers'), findsOneWidget);
    expect(find.text('0 Services'), findsOneWidget);
    expect(find.text('Repairs'), findsNothing);
  });

  testWidgets('shows multiple Venue groups', (tester) async {
    await _pumpTown(
      tester,
      onRead: (_) async => _projection([
        _secondVenueJson(villagers: [_villagerJson()]),
        _venueJson(villagers: const []),
      ]),
    );

    expect(find.text('Harbor Current'), findsOneWidget);
    expect(find.text('Canopy Observatory'), findsOneWidget);
  });

  testWidgets('shows a shared known Villager under two visited Venues', (
    tester,
  ) async {
    await _pumpTown(
      tester,
      onRead: (_) async => _projection([
        _secondVenueJson(
          villagers: [_villagerJson(firstVenueId: 'venue:harbor')],
        ),
        _venueJson(villagers: [_villagerJson()]),
      ]),
    );

    expect(find.text('Marin Current'), findsNWidgets(2));
    expect(find.text('Repairs — Opening soon'), findsNWidgets(2));
  });

  testWidgets('opens Venue detail with action evidence and records no Visit', (
    tester,
  ) async {
    final repository = await _pumpTown(
      tester,
      onRead: (_) async => _projection([
        _venueJson(villagers: [_villagerJson()]),
      ]),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TownScreen)),
    );
    final obs = container.read(appObservabilityProvider);

    expect(find.text('Repairs — Opening soon'), findsOneWidget);
    await tester.tap(find.text('Harbor Current'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Back'), findsOneWidget);
    expect(find.text('Villagers and Services'), findsOneWidget);
    expect(find.text('Repairs'), findsOneWidget);
    expect(find.text('Restore worn gear.'), findsOneWidget);
    expect(find.text('Opening soon'), findsOneWidget);
    expect(repository.records, 0);

    final action = obs.pendingLogRecords.lastWhere(
      (record) =>
          record['event_name'] == 'interaction.action' &&
          (record['attributes'] as Map<String, dynamic>)['action_type'] ==
              'open_venue_detail',
    );
    final attributes = action['attributes'] as Map<String, dynamic>;
    expect(attributes['player_action_id'], 'open-npc-venue-detail');
    expect(attributes['venue_id'], 'venue:harbor');
    expect(attributes['villager_count'], 1);
    expect(attributes['service_count'], 1);
  });
}

Future<_ScreenRepository> _pumpTown(
  WidgetTester tester, {
  required Future<TownProjection> Function(String playerId) onRead,
  bool settle = true,
}) async {
  final repository = _ScreenRepository(onRead: onRead);
  final obs = ObservabilityService(sessionId: 'test-session');

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appObservabilityProvider.overrideWithValue(obs),
        livingWorldObservabilityProvider.overrideWithValue(obs),
        livingWorldRepositoryProvider.overrideWithValue(repository),
        authProvider.overrideWith(() => _FakeAuthNotifier(_authenticated())),
      ],
      child: const ShadApp(home: TownScreen()),
    ),
  );
  await tester.pump();
  if (settle) {
    await tester.pumpAndSettle();
  }
  return repository;
}

AuthState _authenticated() {
  return AuthState.authenticated(
    UserProfile(
      id: playerId,
      phone: '5065550101',
      displayName: 'Tester',
      createdAt: DateTime.utc(2026, 7, 21),
    ),
  );
}

TownProjection _projection(List<Map<String, Object?>> venues) {
  return LivingWorldTownDto.fromJson({
    'venues': venues,
  }, playerId: playerId).toDomain();
}

Map<String, Object?> _venueJson({
  List<Map<String, Object?>> villagers = const [],
}) {
  return {
    'venue_id': 'venue:harbor',
    'venue_version_id': venueVersionId,
    'venue_version_revision': 2,
    'first_venue_version_id': firstVenueVersionId,
    'first_venue_version_revision': 1,
    'reveal_outcome_result_id': outcomeId,
    'encounter_id': encounterId,
    'known_at': '2026-07-20T12:00:00Z',
    'kind': 'harbor',
    'display_name': 'Harbor Current',
    'city_id': 'city:bay',
    'anchor_cell_id': 'cell:harbor',
    'villagers': villagers,
  };
}

Map<String, Object?> _secondVenueJson({
  List<Map<String, Object?>> villagers = const [],
}) {
  return {
    'venue_id': 'venue:canopy',
    'venue_version_id': _secondVenueVersionId,
    'venue_version_revision': 1,
    'first_venue_version_id': _secondFirstVenueVersionId,
    'first_venue_version_revision': 1,
    'reveal_outcome_result_id': _secondOutcomeId,
    'encounter_id': _secondEncounterId,
    'known_at': '2026-07-20T13:00:00Z',
    'kind': 'canopy-observatory',
    'display_name': 'Canopy Observatory',
    'city_id': 'city:bay',
    'anchor_cell_id': 'cell:canopy',
    'villagers': villagers,
  };
}

Map<String, Object?> _villagerJson({String firstVenueId = 'venue:harbor'}) {
  return {
    'villager_id': 'villager:marin',
    'villager_version_id': villagerVersionId,
    'villager_version_revision': 3,
    'first_villager_version_id': firstVillagerVersionId,
    'first_villager_version_revision': 1,
    'first_venue_visit_id': venueVisitId,
    'first_venue_id': firstVenueId,
    'first_venue_version_id': venueVersionId,
    'first_venue_version_revision': 2,
    'known_at': '2026-07-21T12:01:00Z',
    'display_name': 'Marin Current',
    'role_name': 'Mechanic',
    'venue_association_ordinal': 1,
    'services': [
      {
        'service_id': 'service:repairs',
        'service_version_id': serviceVersionId,
        'service_version_revision': 4,
        'display_name': 'Repairs',
        'description': 'Restore worn gear.',
        'service_association_ordinal': 1,
      },
    ],
  };
}

final class _ScreenRepository implements LivingWorldRepository {
  _ScreenRepository({required this.onRead});

  final Future<TownProjection> Function(String playerId) onRead;
  int reads = 0;
  int records = 0;

  @override
  Future<TownProjection> readTown(
    String playerId, {
    required String traceId,
  }) async {
    reads += 1;
    return onRead(playerId);
  }

  @override
  Future<VenueVisitResult> recordVenueVisit(
    RecordVenueVisitCommand command, {
    required String traceId,
  }) async {
    records += 1;
    throw const LivingWorldFailure.unavailable();
  }
}

final class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this._state);

  final AuthState _state;

  @override
  AuthState build() => _state;
}
