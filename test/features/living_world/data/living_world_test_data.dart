import 'package:earth_nova/core/domain/content/content_version_id.dart';
import 'package:earth_nova/core/domain/content/exact_version_ref.dart';
import 'package:earth_nova/core/domain/content/stable_content_id.dart';
import 'package:earth_nova/core/domain/content/venue_content.dart' as content;
import 'package:earth_nova/core/domain/entities/venue_id.dart';
import 'package:earth_nova/features/living_world/domain/entities/living_world_knowledge.dart';
import 'package:earth_nova/features/map/domain/entities/cell_visit.dart';

const playerId = '00000000-0000-4000-8000-000000000001';
const cellVisitId = '00000000-0000-4000-8000-000000000002';
const venueVersionId = '00000000-0000-4000-8000-000000000003';
const firstVenueVersionId = '00000000-0000-4000-8000-000000000004';
const outcomeId = '00000000-0000-4000-8000-000000000005';
const encounterId = '00000000-0000-4000-8000-000000000006';
const venueVisitId = '00000000-0000-4000-8000-000000000007';
const villagerVersionId = '00000000-0000-4000-8000-000000000008';
const firstVillagerVersionId = '00000000-0000-4000-8000-000000000009';
const serviceVersionId = '00000000-0000-4000-8000-000000000010';

RecordVenueVisitCommand command() {
  final venueId = VenueId('venue:harbor');
  return RecordVenueVisitCommand(
    cellVisit: CellVisit(
      id: cellVisitId,
      cellId: 'cell:harbor',
      userId: playerId,
      visitedAt: DateTime.utc(2026, 7, 21, 12),
    ),
    venueId: venueId,
    venueVersion: ExactVersionRef<content.VenueContent>(
      stableId: StableContentId<content.VenueContent>(venueId.value),
      versionId: ContentVersionId<content.VenueContent>(venueVersionId),
      revision: 2,
    ),
  );
}

Map<String, Object?> service() => {
      'service_id': 'service:repairs',
      'service_version_id': serviceVersionId,
      'service_version_revision': 4,
      'display_name': 'Repairs',
      'description': 'Restore worn gear.',
      'service_association_ordinal': 1,
    };

Map<String, Object?> villager() => {
      'villager_id': 'villager:marin',
      'villager_version_id': villagerVersionId,
      'villager_version_revision': 3,
      'first_villager_version_id': firstVillagerVersionId,
      'first_villager_version_revision': 1,
      'first_venue_visit_id': venueVisitId,
      'first_venue_id': 'venue:harbor',
      'first_venue_version_id': venueVersionId,
      'first_venue_version_revision': 2,
      'known_at': '2026-07-21T12:01:00Z',
      'display_name': 'Marin Current',
      'role_name': 'Mechanic',
      'venue_association_ordinal': 1,
      'services': [service()],
    };

Map<String, Object?> town({bool withVillager = true}) => {
      'venues': [
        {
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
          'villagers': withVillager ? [villager()] : <Object?>[],
        },
      ],
    };

Map<String, Object?> introducedVillager() => {
      'villager_id': 'villager:marin',
      'villager_version_id': villagerVersionId,
      'villager_version_revision': 3,
      'known_at': '2026-07-21T12:01:00Z',
      'display_name': 'Marin Current',
      'role_name': 'Mechanic',
      'venue_association_ordinal': 1,
      'services': [service()],
    };

Map<String, Object?> recordResponse({
  bool retry = false,
  bool withIntroduction = true,
}) =>
    {
      'visit': {
        'id': venueVisitId,
        'user_id': playerId,
        'cell_visit_id': cellVisitId,
        'cell_id': 'cell:harbor',
        'venue_id': 'venue:harbor',
        'venue_version_id': venueVersionId,
        'venue_version_revision': 2,
        'visited_at': '2026-07-21T12:00:00Z',
        'is_idempotent_retry': retry,
      },
      'introduced_villagers':
          withIntroduction ? [introducedVillager()] : <Object?>[],
      'town': town(),
    };
