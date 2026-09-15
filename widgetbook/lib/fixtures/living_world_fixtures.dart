import 'dart:async';

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
import 'package:riverpod/misc.dart';
import 'package:earth_nova_widgetbook/fixtures/auth_fixtures.dart';

final storyTownPlayer = UserProfile(
  id: storyPlayerId,
  phone: '5065550101',
  displayName: 'Explorer',
  createdAt: DateTime.utc(2026, 7, 21),
);

final storyTownEmpty = _town(const []);
final storyTownVenueWithoutVillagers = _town([_harbor()]);
final storyTownVenueWithServices = _town([
  _harbor(villagers: [_marin()]),
]);
final storyTownMultipleVenues = _town([
  _canopy(villagers: [_marin(firstVenueId: 'venue:harbor')]),
  _harbor(villagers: [_marin()]),
]);

List<Override> townStoryOverrides(Future<TownProjection> Function() read) {
  final observability = ObservabilityService(sessionId: 'widgetbook-town');
  return [
    appObservabilityProvider.overrideWithValue(observability),
    livingWorldObservabilityProvider.overrideWithValue(observability),
    authProvider.overrideWith(
      () => StoryAuthNotifier(AuthState.authenticated(storyTownPlayer)),
    ),
    livingWorldRepositoryProvider.overrideWithValue(
      StoryLivingWorldRepository(read),
    ),
  ];
}

final class StoryLivingWorldRepository implements LivingWorldRepository {
  StoryLivingWorldRepository(this._read);

  final Future<TownProjection> Function() _read;

  @override
  Future<TownProjection> readTown(String playerId, {required String traceId}) =>
      _read();

  @override
  Future<VenueVisitResult> recordVenueVisit(
    RecordVenueVisitCommand command, {
    required String traceId,
  }) => Future<VenueVisitResult>.error(const LivingWorldFailure.unavailable());
}

Future<TownProjection> storyTownLoading() => Completer<TownProjection>().future;

Future<TownProjection> storyTownUnavailable() =>
    Future<TownProjection>.error(const LivingWorldFailure.unavailable());

TownProjection _town(List<Map<String, Object?>> venues) =>
    LivingWorldTownDto.fromJson({
      'venues': venues,
    }, playerId: storyPlayerId).toDomain();

Map<String, Object?> _harbor({
  List<Map<String, Object?>> villagers = const [],
}) => {
  'venue_id': 'venue:harbor',
  'venue_version_id': '00000000-0000-4000-8000-000000000003',
  'venue_version_revision': 2,
  'first_venue_version_id': '00000000-0000-4000-8000-000000000004',
  'first_venue_version_revision': 1,
  'reveal_outcome_result_id': '00000000-0000-4000-8000-000000000005',
  'encounter_id': '00000000-0000-4000-8000-000000000006',
  'known_at': '2026-07-20T12:00:00Z',
  'kind': 'harbor',
  'display_name': 'Harbor Current',
  'city_id': 'city:bay',
  'anchor_cell_id': 'cell:harbor',
  'villagers': villagers,
};

Map<String, Object?> _canopy({
  List<Map<String, Object?>> villagers = const [],
}) => {
  'venue_id': 'venue:canopy',
  'venue_version_id': '00000000-0000-4000-8000-000000000011',
  'venue_version_revision': 1,
  'first_venue_version_id': '00000000-0000-4000-8000-000000000012',
  'first_venue_version_revision': 1,
  'reveal_outcome_result_id': '00000000-0000-4000-8000-000000000013',
  'encounter_id': '00000000-0000-4000-8000-000000000014',
  'known_at': '2026-07-20T13:00:00Z',
  'kind': 'canopy-observatory',
  'display_name': 'Canopy Observatory',
  'city_id': 'city:bay',
  'anchor_cell_id': 'cell:canopy',
  'villagers': villagers,
};

Map<String, Object?> _marin({String firstVenueId = 'venue:harbor'}) => {
  'villager_id': 'villager:marin',
  'villager_version_id': '00000000-0000-4000-8000-000000000008',
  'villager_version_revision': 3,
  'first_villager_version_id': '00000000-0000-4000-8000-000000000009',
  'first_villager_version_revision': 1,
  'first_venue_visit_id': '00000000-0000-4000-8000-000000000007',
  'first_venue_id': firstVenueId,
  'first_venue_version_id': '00000000-0000-4000-8000-000000000003',
  'first_venue_version_revision': 2,
  'known_at': '2026-07-21T12:01:00Z',
  'display_name': 'Marin Current',
  'role_name': 'Mechanic',
  'venue_association_ordinal': 1,
  'services': [
    {
      'service_id': 'service:repairs',
      'service_version_id': '00000000-0000-4000-8000-000000000010',
      'service_version_revision': 4,
      'display_name': 'Repairs',
      'description': 'Restore worn gear.',
      'service_association_ordinal': 1,
    },
  ],
};
