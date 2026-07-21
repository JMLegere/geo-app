import 'package:earth_nova/features/living_world/data/dtos/living_world_dto.dart';
import 'package:earth_nova/features/living_world/domain/repositories/living_world_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../living_world_test_data.dart';

void main() {
  group('LivingWorldTownDto', () {
    test('retains empty known Venue and exact first/current version separation',
        () {
      final parsed = LivingWorldTownDto.fromJson(town(withVillager: false),
              playerId: playerId)
          .toDomain();

      final venue = parsed.venues.single;
      expect(venue.villagers, isEmpty);
      expect(
          venue.knownVenue.venueVersion.versionId.value, firstVenueVersionId);
      expect(venue.knownVenue.venueVersion.revision, 1);
      expect(venue.venue.version.versionId.value, venueVersionId);
      expect(venue.venue.version.revision, 2);
      expect(venue.venue.displayName, 'Harbor Current');
    });

    test('keeps first provenance separate from current roster presentation',
        () {
      final payload = town();
      final rawVillager = ((payload['venues'] as List<Object?>).single
          as Map<String, Object?>)['villagers'] as List<Object?>;
      (rawVillager.single as Map<String, Object?>)['first_venue_id'] =
          'venue:original';

      final parsed =
          LivingWorldTownDto.fromJson(payload, playerId: playerId).toDomain();

      expect(
          parsed.venues.single.villagers.single.knownVillager
              .introducedAtVenueId.value,
          'venue:original');
    });

    test(
        'rejects extra fields, invalid UUIDs, and duplicate or unordered roster entries',
        () {
      final extra = town();
      ((extra['venues'] as List<Object?>).single
          as Map<String, Object?>)['untrusted'] = true;
      final invalidUuid = town();
      ((invalidUuid['venues'] as List<Object?>).single
          as Map<String, Object?>)['venue_version_id'] = 'not-a-uuid';
      final unordered = town();
      final rawVillager = ((unordered['venues'] as List<Object?>).single
          as Map<String, Object?>)['villagers'] as List<Object?>;
      rawVillager.add({
        ...villager(),
        'villager_id': 'villager:other',
        'venue_association_ordinal': 1
      });

      for (final payload in [extra, invalidUuid, unordered]) {
        expect(
          () => LivingWorldTownDto.fromJson(payload, playerId: playerId),
          throwsA(isA<LivingWorldFailure>().having(
            (failure) => failure.kind,
            'kind',
            LivingWorldFailureKind.malformedPayload,
          )),
        );
      }
    });
  });

  group('LivingWorldVenueVisitResultDto', () {
    test('accepts exact post-commit result and rejects foreign evidence', () {
      final result = LivingWorldVenueVisitResultDto.fromJson(
        recordResponse(),
        command: command(),
      ).toDomain();
      expect(result.visit.id.value, venueVisitId);
      expect(
          result.town.venues.single.villagers.single.knownVillager
              .villagerVersion.versionId.value,
          firstVillagerVersionId);
      expect(
          result.town.venues.single.villagers.single.villager.version.versionId
              .value,
          villagerVersionId);

      final foreign = recordResponse();
      ((foreign['visit'] as Map<String, Object?>))['user_id'] =
          '00000000-0000-4000-8000-000000000099';
      expect(
        () => LivingWorldVenueVisitResultDto.fromJson(foreign,
            command: command()),
        throwsA(isA<LivingWorldFailure>()),
      );
    });

    test('fails closed on malformed idempotent replay', () {
      expect(
        () => LivingWorldVenueVisitResultDto.fromJson(
          recordResponse(retry: true, withIntroduction: true),
          command: command(),
        ),
        throwsA(isA<LivingWorldFailure>().having(
          (failure) => failure.kind,
          'kind',
          LivingWorldFailureKind.malformedPayload,
        )),
      );
    });
  });
}
