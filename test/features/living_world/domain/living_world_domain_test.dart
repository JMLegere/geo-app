import 'package:earth_nova/core/domain/content/content_identity.dart';
import 'package:earth_nova/core/domain/content/venue_content.dart';
import 'package:earth_nova/core/domain/entities/venue_id.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/living_world/domain/entities/authored_living_world_entities.dart';
import 'package:earth_nova/features/living_world/domain/entities/living_world_knowledge.dart';
import 'package:earth_nova/features/living_world/domain/entities/town_projection.dart';
import 'package:earth_nova/features/living_world/domain/repositories/living_world_repository.dart';
import 'package:earth_nova/features/living_world/domain/use_cases/record_venue_visit.dart';
import 'package:earth_nova/features/map/domain/entities/cell_visit.dart';
import 'package:flutter_test/flutter_test.dart';

final _rowanVenueId = VenueId('venue-rowan');
final _rowanVenue = Venue(id: _rowanVenueId);
final _rowanVenueV1 = ExactVersionRef<VenueContent>(
  stableId: StableContentId<VenueContent>('venue-rowan'),
  versionId: ContentVersionId<VenueContent>('venue-rowan-v1'),
  revision: 1,
);
final _rowanVenueV2 = ExactVersionRef<VenueContent>(
  stableId: StableContentId<VenueContent>('venue-rowan'),
  versionId: ContentVersionId<VenueContent>('venue-rowan-v2'),
  revision: 2,
);
final _badVenueVersion = ExactVersionRef<VenueContent>(
  stableId: StableContentId<VenueContent>('venue-other'),
  versionId: ContentVersionId<VenueContent>('venue-other-v1'),
  revision: 1,
);
final _rowanId = VillagerId('villager-rowan');
final _rowan = Villager(id: _rowanId);
final _rowanV1 = ExactVersionRef<VillagerContent>(
  stableId: StableContentId<VillagerContent>('villager-rowan'),
  versionId: ContentVersionId<VillagerContent>('villager-rowan-v1'),
  revision: 1,
);
final _miraId = VillagerId('villager-mira');
final _miraV1 = ExactVersionRef<VillagerContent>(
  stableId: StableContentId<VillagerContent>('villager-mira'),
  versionId: ContentVersionId<VillagerContent>('villager-mira-v1'),
  revision: 1,
);
final _releaseId = ServiceId('service-release-to-wild');
final _release = Service(id: _releaseId);
final _releaseV1 = ExactVersionRef<ServiceContent>(
  stableId: StableContentId<ServiceContent>('service-release-to-wild'),
  versionId: ContentVersionId<ServiceContent>('service-release-to-wild-v1'),
  revision: 1,
);

CellVisit _cellVisit(
        {String userId = 'player-1', String id = 'cell-visit-1'}) =>
    CellVisit(
      id: id,
      userId: userId,
      cellId: 'v_22982_-33322',
      visitedAt: DateTime.utc(2026, 7, 21),
    );

KnownVenue _knownVenue({String playerId = 'player-1'}) => KnownVenue(
      playerId: playerId,
      venueId: _rowanVenueId,
      venueVersion: _rowanVenueV1,
      revealedAt: DateTime.utc(2026, 7, 20),
      provenance: RevealVenueProvenance(
        encounterId: 'encounter-1',
        outcomeResultId: 'outcome-result-1',
      ),
    );

VenueVersion _venueVersion(
        {Iterable<VenueVillagerAssociation> villagers = const []}) =>
    VenueVersion(
      venue: _rowanVenue,
      version: _rowanVenueV2,
      kind: 'wildlifeRehabilitationCenter',
      displayName: "Rowan's Rehab Center",
      cityId: 'city_fredericton',
      anchorCellId: 'v_22982_-33322',
      villagers: villagers,
    );

VillagerVersion _rowanVersion(
        {Iterable<VillagerServiceAssociation> services = const []}) =>
    VillagerVersion(
      villager: _rowan,
      version: _rowanV1,
      displayName: 'Rowan',
      role: 'Wildlife Rehabilitator',
      services: services,
    );

KnownVillager _knownRowan({
  String playerId = 'player-1',
  String visitId = 'venue-visit-1',
}) =>
    KnownVillager(
      playerId: playerId,
      villagerId: _rowanId,
      villagerVersion: _rowanV1,
      introducedAtVenueId: _rowanVenueId,
      introducedByVenueVisitId: VenueVisitId(visitId),
      introducedAt: DateTime.utc(2026, 7, 21),
    );

VenueVisit _visit({
  String userId = 'player-1',
  String id = 'venue-visit-1',
  String cellVisitId = 'cell-visit-1',
}) =>
    VenueVisit(
      id: VenueVisitId(id),
      cellVisit: _cellVisit(userId: userId, id: cellVisitId),
      venueId: _rowanVenueId,
      venueVersion: _rowanVenueV2,
      visitedAt: DateTime.utc(2026, 7, 21),
    );

final class _RecordingCommandRepository
    implements LivingWorldCommandRepository {
  _RecordingCommandRepository(this.result);

  final VenueVisitResult result;
  RecordVenueVisitCommand? received;
  String? receivedTraceId;

  @override
  Future<VenueVisitResult> recordVenueVisit(
    RecordVenueVisitCommand command, {
    required String traceId,
  }) async {
    received = command;
    receivedTraceId = traceId;
    return result;
  }
}

void main() {
  group('authored Living World identity and Versions', () {
    test('rejects blank stable authored IDs and a cross-Venue Version', () {
      expect(() => VillagerId('  '), throwsArgumentError);
      expect(
        () => VenueVersion(
          venue: _rowanVenue,
          version: _badVenueVersion,
          kind: 'wildlifeRehabilitationCenter',
          displayName: "Rowan's Rehab Center",
          cityId: 'city_fredericton',
          anchorCellId: 'v_22982_-33322',
        ),
        throwsArgumentError,
      );
    });

    test('normalizes immutable ordered authored associations', () {
      final venue = _venueVersion(
        villagers: [
          VenueVillagerAssociation(
            venueId: _rowanVenueId,
            villagerId: _miraId,
            ordinal: 2,
          ),
          VenueVillagerAssociation(
            venueId: _rowanVenueId,
            villagerId: _rowanId,
            ordinal: 1,
          ),
        ],
      );

      expect(
          venue.villagers.map((item) => item.villagerId), [_rowanId, _miraId]);
      expect(
        () => venue.villagers.add(
          VenueVillagerAssociation(
            venueId: _rowanVenueId,
            villagerId: VillagerId('villager-new'),
            ordinal: 3,
          ),
        ),
        throwsUnsupportedError,
      );
    });
  });

  group('Town projection', () {
    test('represents a known Venue with no known Villagers', () {
      final town = TownProjection(
        playerId: 'player-1',
        venues: [TownVenue(knownVenue: _knownVenue(), venue: _venueVersion())],
      );

      expect(town.venues, hasLength(1));
      expect(town.venues.single.villagers, isEmpty);
      expect(town.venues.single.knownVenue.venueVersion, _rowanVenueV1);
      expect(town.venues.single.venue.version, _rowanVenueV2);
    });

    test('groups and orders Venue, Villager, and Service deterministically',
        () {
      final service = ServiceVersion(
        service: _release,
        version: _releaseV1,
        displayName: 'Release to Wild',
        description: 'Prepare a recovered animal for release.',
      );
      final rowan = _rowanVersion(
        services: [
          VillagerServiceAssociation(
            villagerId: _rowanId,
            serviceId: _releaseId,
            ordinal: 1,
          ),
        ],
      );
      final venue = _venueVersion(
        villagers: [
          VenueVillagerAssociation(
            venueId: _rowanVenueId,
            villagerId: _rowanId,
            ordinal: 1,
          ),
        ],
      );
      final visit = _visit();
      final townVenue = TownVenue(
        knownVenue: _knownVenue(),
        venue: venue,
        villagers: [
          TownVillager(
            knownVillager: _knownRowan(visitId: visit.id.value),
            villager: rowan,
            venueAssociationOrdinal: 1,
            services: [TownService(service: service, associationOrdinal: 1)],
          ),
        ],
      );
      final aVenueId = VenueId('venue-alder');
      final aVenue = Venue(id: aVenueId);
      final aVenueVersion = VenueVersion(
        venue: aVenue,
        version: ExactVersionRef<VenueContent>(
          stableId: StableContentId<VenueContent>('venue-alder'),
          versionId: ContentVersionId<VenueContent>('venue-alder-v1'),
          revision: 1,
        ),
        kind: 'library',
        displayName: 'Alder Library',
        cityId: 'city_fredericton',
        anchorCellId: 'v_1_2',
      );
      final aKnown = KnownVenue(
        playerId: 'player-1',
        venueId: aVenueId,
        venueVersion: aVenueVersion.version,
        revealedAt: DateTime.utc(2026, 7, 20),
        provenance: RevealVenueProvenance(
          encounterId: 'encounter-2',
          outcomeResultId: 'outcome-result-2',
        ),
      );

      final town = TownProjection(
        playerId: 'player-1',
        venues: [
          townVenue,
          TownVenue(knownVenue: aKnown, venue: aVenueVersion)
        ],
      );

      expect(town.venues.map((item) => item.venue.displayName), [
        'Alder Library',
        "Rowan's Rehab Center",
      ]);
      expect(town.venues.last.villagers.single.villager.displayName, 'Rowan');
      expect(
        town.venues.last.villagers.single.services.single.service.displayName,
        'Release to Wild',
      );
    });

    test('shows one globally known Villager at two current Venue rosters', () {
      final rowanVersion = _rowanVersion();
      final sharedRowan = TownVillager(
        knownVillager: _knownRowan(),
        villager: rowanVersion,
        venueAssociationOrdinal: 1,
      );
      final rowanVenue = TownVenue(
        knownVenue: _knownVenue(),
        venue: _venueVersion(
          villagers: [
            VenueVillagerAssociation(
              venueId: _rowanVenueId,
              villagerId: _rowanId,
              ordinal: 1,
            ),
          ],
        ),
        villagers: [sharedRowan],
      );
      final harborId = VenueId('venue-harbor');
      final harborVersion = VenueVersion(
        venue: Venue(id: harborId),
        version: ExactVersionRef<VenueContent>(
          stableId: StableContentId<VenueContent>('venue-harbor'),
          versionId: ContentVersionId<VenueContent>('venue-harbor-v1'),
          revision: 1,
        ),
        kind: 'wildlifeHarbor',
        displayName: 'Harbor House',
        cityId: 'city_fredericton',
        anchorCellId: 'v_22983_-33322',
        villagers: [
          VenueVillagerAssociation(
            venueId: harborId,
            villagerId: _rowanId,
            ordinal: 1,
          ),
        ],
      );
      final harborKnown = KnownVenue(
        playerId: 'player-1',
        venueId: harborId,
        venueVersion: harborVersion.version,
        revealedAt: DateTime.utc(2026, 7, 22),
        provenance: RevealVenueProvenance(
          encounterId: 'encounter-3',
          outcomeResultId: 'outcome-result-3',
        ),
      );

      final town = TownProjection(
        playerId: 'player-1',
        venues: [
          rowanVenue,
          TownVenue(
            knownVenue: harborKnown,
            venue: harborVersion,
            villagers: [sharedRowan],
          ),
        ],
      );

      expect(town.venues, hasLength(2));
      expect(
        town.venues.expand((venue) => venue.villagers).map(
              (villager) => villager.knownVillager.villagerId,
            ),
        [_rowanId, _rowanId],
      );
      expect(
        town.venues.last.villagers.single.knownVillager.introducedAtVenueId,
        _rowanVenueId,
      );
    });

    test('is pure and immutable when projected or navigated as a value', () {
      final town = TownProjection(
        playerId: 'player-1',
        venues: [TownVenue(knownVenue: _knownVenue(), venue: _venueVersion())],
      );

      expect(() => town.venues.clear(), throwsUnsupportedError);
      expect(
          town.venues.single.knownVenue.provenance.encounterId, 'encounter-1');
    });
  });

  group('Venue Visit', () {
    test('returns an explicit empty idempotency result shape', () {
      final result = VenueVisitResult(
        visit: _visit(),
        town: TownProjection(playerId: 'player-1'),
        isIdempotentRetry: true,
      );

      expect(result.isIdempotentRetry, isTrue);
      expect(result.introducedVillagers, isEmpty);
      expect(result.visit.cellVisit.id, 'cell-visit-1');
      expect(result.town.playerId, result.visit.playerId);
    });

    test('rejects introductions on an idempotent exact Cell Visit retry', () {
      final visit = _visit();

      expect(
        () => VenueVisitResult(
          visit: visit,
          town: TownProjection(playerId: 'player-1'),
          isIdempotentRetry: true,
          introducedVillagers: [
            IntroducedVillager(
              villager: _knownRowan(visitId: visit.id.value),
              ordinal: 1,
            ),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('represents later associations on a later exact Visit', () {
      final first = _visit();
      final later = _visit(id: 'venue-visit-2', cellVisitId: 'cell-visit-2');
      final knownMira = KnownVillager(
        playerId: 'player-1',
        villagerId: _miraId,
        villagerVersion: _miraV1,
        introducedAtVenueId: _rowanVenueId,
        introducedByVenueVisitId: later.id,
        introducedAt: DateTime.utc(2026, 7, 22),
      );
      final laterResult = VenueVisitResult(
        visit: later,
        town: TownProjection(playerId: 'player-1'),
        isIdempotentRetry: false,
        introducedVillagers: [
          IntroducedVillager(villager: knownMira, ordinal: 2),
        ],
      );

      expect(first.cellVisit.id, isNot(later.cellVisit.id));
      expect(
          laterResult.introducedVillagers.single.villager.villagerId, _miraId);
      expect(
          laterResult
              .introducedVillagers.single.villager.introducedByVenueVisitId,
          later.id);
    });

    test('rejects cross-owner and cross-Version Visit evidence', () {
      expect(
        () => RecordVenueVisitCommand(
          cellVisit: _cellVisit(),
          venueId: _rowanVenueId,
          venueVersion: _badVenueVersion,
        ),
        throwsArgumentError,
      );
      expect(
        () => VenueVisitResult(
          visit: _visit(userId: 'player-1'),
          town: TownProjection(playerId: 'player-1'),
          isIdempotentRetry: false,
          introducedVillagers: [
            IntroducedVillager(
              villager: _knownRowan(playerId: 'player-2'),
              ordinal: 1,
            ),
          ],
        ),
        throwsArgumentError,
      );
    });

    test(
        'forwards only exact persisted Visit and authored evidence to command port',
        () async {
      final command = RecordVenueVisitCommand(
        cellVisit: _cellVisit(),
        venueId: _rowanVenueId,
        venueVersion: _rowanVenueV2,
      );
      final repository = _RecordingCommandRepository(
        VenueVisitResult(
          visit: _visit(),
          town: TownProjection(playerId: 'player-1'),
          isIdempotentRetry: true,
        ),
      );
      final useCase = RecordVenueVisit(
        repository,
        ObservabilityService(sessionId: 'living-world-domain-test'),
      );

      final result = await useCase.execute(command, 'trace-venue-visit');

      expect(identical(repository.received, command), isTrue);
      expect(repository.receivedTraceId, 'trace-venue-visit');
      expect(result.isIdempotentRetry, isTrue);
    });

    test('rejects authored association and snapshot integrity violations', () {
      final validAssociation = VenueVillagerAssociation(
        venueId: _rowanVenueId,
        villagerId: _rowanId,
        ordinal: 1,
      );

      expect(
        () => VenueVersion(
          venue: _rowanVenue,
          version: _rowanVenueV2,
          kind: 'wildlifeRehabilitationCenter',
          displayName: "Rowan's Rehab Center",
          cityId: 'city_fredericton',
          anchorCellId: 'v_22982_-33322',
          villagers: [
            validAssociation,
            VenueVillagerAssociation(
              venueId: _rowanVenueId,
              villagerId: _rowanId,
              ordinal: 2,
            ),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => VenueVersion(
          venue: _rowanVenue,
          version: _rowanVenueV2,
          kind: 'wildlifeRehabilitationCenter',
          displayName: "Rowan's Rehab Center",
          cityId: 'city_fredericton',
          anchorCellId: 'v_22982_-33322',
          villagers: [
            validAssociation,
            VenueVillagerAssociation(
              venueId: _rowanVenueId,
              villagerId: _miraId,
              ordinal: 1,
            ),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => VenueVersion(
          venue: _rowanVenue,
          version: _rowanVenueV2,
          kind: 'wildlifeRehabilitationCenter',
          displayName: "Rowan's Rehab Center",
          cityId: 'city_fredericton',
          anchorCellId: 'v_22982_-33322',
          villagers: [
            VenueVillagerAssociation(
              venueId: VenueId('venue-other'),
              villagerId: _rowanId,
              ordinal: 1,
            ),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => VillagerVersion(
          villager: _rowan,
          version: _rowanV1,
          displayName: ' ',
          role: 'Wildlife Rehabilitator',
        ),
        throwsArgumentError,
      );
      expect(
        () => ServiceVersion(
          service: _release,
          version: ExactVersionRef<ServiceContent>(
            stableId: StableContentId<ServiceContent>('service-other'),
            versionId: ContentVersionId<ServiceContent>('service-other-v1'),
            revision: 1,
          ),
          displayName: 'Release to Wild',
          description: 'Prepare a recovered animal for release.',
        ),
        throwsArgumentError,
      );
      expect(
        () => VenueVillagerAssociation(
          venueId: _rowanVenueId,
          villagerId: _rowanId,
          ordinal: 0,
        ),
        throwsArgumentError,
      );
    });

    test('rejects projections that violate authored roster or player ownership',
        () {
      final service = ServiceVersion(
        service: _release,
        version: _releaseV1,
        displayName: 'Release to Wild',
        description: 'Prepare a recovered animal for release.',
      );
      final villager = _rowanVersion(
        services: [
          VillagerServiceAssociation(
            villagerId: _rowanId,
            serviceId: _releaseId,
            ordinal: 1,
          ),
        ],
      );
      final venue = _venueVersion(
        villagers: [
          VenueVillagerAssociation(
            venueId: _rowanVenueId,
            villagerId: _rowanId,
            ordinal: 1,
          ),
        ],
      );
      final playerTwoVillager = TownVillager(
        knownVillager: _knownRowan(playerId: 'player-2'),
        villager: villager,
        venueAssociationOrdinal: 1,
      );
      final playerOneVenue = TownVenue(
        knownVenue: _knownVenue(),
        venue: venue,
      );

      expect(
        () => TownService(service: service, associationOrdinal: 0),
        throwsArgumentError,
      );
      expect(
        () => TownVillager(
          knownVillager: _knownRowan(),
          villager: villager,
          venueAssociationOrdinal: 1,
          services: [TownService(service: service, associationOrdinal: 2)],
        ),
        throwsArgumentError,
      );
      expect(
        () => TownVenue(
          knownVenue: _knownVenue(),
          venue: venue,
          villagers: [playerTwoVillager],
        ),
        throwsArgumentError,
      );
      expect(
        () => TownProjection(
          playerId: 'player-1',
          venues: [
            TownVenue(
              knownVenue: _knownVenue(playerId: 'player-2'),
              venue: venue,
            ),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => TownProjection(
          playerId: 'player-1',
          venues: [playerOneVenue, playerOneVenue],
        ),
        throwsArgumentError,
      );
    });

    test('rejects invalid introduction evidence and orders valid outcomes', () {
      final visit = _visit();
      final knownMira = KnownVillager(
        playerId: 'player-1',
        villagerId: _miraId,
        villagerVersion: _miraV1,
        introducedAtVenueId: _rowanVenueId,
        introducedByVenueVisitId: visit.id,
        introducedAt: DateTime.utc(2026, 7, 21),
      );
      final otherVenueVillager = KnownVillager(
        playerId: 'player-1',
        villagerId: _miraId,
        villagerVersion: _miraV1,
        introducedAtVenueId: VenueId('venue-other'),
        introducedByVenueVisitId: visit.id,
        introducedAt: DateTime.utc(2026, 7, 21),
      );

      expect(
        () => IntroducedService(
          service: ServiceVersion(
            service: _release,
            version: _releaseV1,
            displayName: 'Release to Wild',
            description: 'Prepare a recovered animal for release.',
          ),
          ordinal: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => VenueVisitResult(
          visit: visit,
          town: TownProjection(playerId: 'player-1'),
          isIdempotentRetry: false,
          introducedVillagers: [
            IntroducedVillager(villager: otherVenueVillager, ordinal: 1),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => VenueVisitResult(
          visit: visit,
          town: TownProjection(playerId: 'player-1'),
          isIdempotentRetry: false,
          introducedVillagers: [
            IntroducedVillager(
              villager: _knownRowan(visitId: 'other-visit'),
              ordinal: 1,
            ),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => VenueVisitResult(
          visit: visit,
          town: TownProjection(playerId: 'player-1'),
          isIdempotentRetry: false,
          introducedVillagers: [
            IntroducedVillager(
              villager: _knownRowan(visitId: visit.id.value),
              ordinal: 1,
            ),
            IntroducedVillager(
              villager: _knownRowan(visitId: visit.id.value),
              ordinal: 2,
            ),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => VenueVisitResult(
          visit: visit,
          town: TownProjection(playerId: 'player-1'),
          isIdempotentRetry: false,
          introducedVillagers: [
            IntroducedVillager(
              villager: _knownRowan(visitId: visit.id.value),
              ordinal: 1,
            ),
            IntroducedVillager(villager: knownMira, ordinal: 1),
          ],
        ),
        throwsArgumentError,
      );

      final result = VenueVisitResult(
        visit: visit,
        town: TownProjection(playerId: 'player-1'),
        isIdempotentRetry: false,
        introducedVillagers: [
          IntroducedVillager(
            villager: _knownRowan(visitId: visit.id.value),
            ordinal: 2,
          ),
          IntroducedVillager(villager: knownMira, ordinal: 1),
        ],
      );
      expect(
        result.introducedVillagers.map((entry) => entry.villager.villagerId),
        [_miraId, _rowanId],
      );
      expect(
        () => result.introducedVillagers.clear(),
        throwsUnsupportedError,
      );
    });

    test('emits exact visit provenance in the observable use-case trace',
        () async {
      final command = RecordVenueVisitCommand(
        cellVisit: _cellVisit(),
        venueId: _rowanVenueId,
        venueVersion: _rowanVenueV2,
      );
      final result = VenueVisitResult(
        visit: _visit(),
        town: TownProjection(playerId: 'player-1'),
        isIdempotentRetry: true,
      );
      final observability = ObservabilityService(
        sessionId: 'living-world-trace-contract',
      );
      final useCase = RecordVenueVisit(
        _RecordingCommandRepository(result),
        observability,
      );

      await useCase(command);

      final started = observability.pendingLogRecords.first['attributes']
          as Map<String, dynamic>;
      final completed = observability.pendingLogRecords.last['attributes']
          as Map<String, dynamic>;
      expect(started['input'], {
        'cell_visit_id': 'cell-visit-1',
        'venue_id': 'venue-rowan',
        'venue_version_id': 'venue-rowan-v2',
      });
      expect(completed['output'], {
        'venue_visit_id': 'venue-visit-1',
        'idempotent_retry': true,
        'introduced_villager_count': 0,
      });
    });
  });
}
