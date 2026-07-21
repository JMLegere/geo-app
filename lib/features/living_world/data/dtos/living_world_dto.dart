import 'package:earth_nova/core/domain/content/content_version_id.dart';
import 'package:earth_nova/core/domain/content/exact_version_ref.dart';
import 'package:earth_nova/core/domain/content/stable_content_id.dart';
import 'package:earth_nova/core/domain/content/venue_content.dart' as content;
import 'package:earth_nova/core/domain/entities/venue_id.dart';
import 'package:earth_nova/features/living_world/domain/entities/authored_living_world_entities.dart';
import 'package:earth_nova/features/living_world/domain/entities/living_world_knowledge.dart';
import 'package:earth_nova/features/living_world/domain/entities/town_projection.dart';
import 'package:earth_nova/features/living_world/domain/repositories/living_world_repository.dart';
import 'package:earth_nova/features/map/domain/entities/cell_visit.dart';

/// Strict boundary parser for the frozen Town and Venue Visit RPC payloads.
///
/// RPC output is untrusted. This parser accepts only the complete documented
/// shape and proves that returned command evidence belongs to the submitted
/// Cell Visit, Venue, Version, and player before materializing domain state.
final class LivingWorldTownDto {
  const LivingWorldTownDto._(this._town);

  final TownProjection _town;

  factory LivingWorldTownDto.fromJson(Object? json,
      {required String playerId}) {
    try {
      final expectedPlayerId = _uuid(playerId);
      return LivingWorldTownDto._(_parseTown(json, playerId: expectedPlayerId));
    } on LivingWorldFailure {
      rethrow;
    } on ArgumentError {
      throw const LivingWorldFailure.malformedPayload();
    } on FormatException {
      throw const LivingWorldFailure.malformedPayload();
    } on StateError {
      throw const LivingWorldFailure.malformedPayload();
    } on TypeError {
      throw const LivingWorldFailure.malformedPayload();
    }
  }

  TownProjection toDomain() => _town;

  /// Validates the local owner used to verify server-derived Town evidence.
  static void validatePlayerId(String playerId) => _uuid(playerId);
}

/// Strict parser for `record_v3_venue_visit` output.
final class LivingWorldVenueVisitResultDto {
  const LivingWorldVenueVisitResultDto._(this._result);

  final VenueVisitResult _result;

  factory LivingWorldVenueVisitResultDto.fromJson(
    Object? json, {
    required RecordVenueVisitCommand command,
  }) {
    try {
      _validateCommand(command);
      final response = _object(json);
      _exactKeys(response, const ['visit', 'introduced_villagers', 'town']);
      final visit = _parseVisit(response['visit'], command);
      final town = _parseTown(response['town'], playerId: command.playerId);
      final introduced =
          _parseIntroduced(response['introduced_villagers'], visit);
      _validateReturnedTown(town, command, introduced);
      return LivingWorldVenueVisitResultDto._(
        VenueVisitResult(
          visit: visit,
          town: town,
          isIdempotentRetry:
              _bool(_object(response['visit'])['is_idempotent_retry']),
          introducedVillagers: introduced,
        ),
      );
    } on LivingWorldFailure {
      rethrow;
    } on ArgumentError {
      throw const LivingWorldFailure.malformedPayload();
    } on FormatException {
      throw const LivingWorldFailure.malformedPayload();
    } on StateError {
      throw const LivingWorldFailure.malformedPayload();
    } on TypeError {
      throw const LivingWorldFailure.malformedPayload();
    }
  }

  /// Validates exact command evidence before it crosses the RPC boundary.
  static void validateCommand(RecordVenueVisitCommand command) =>
      _validateCommand(command);

  VenueVisitResult toDomain() => _result;
}

TownProjection _parseTown(Object? value, {required String playerId}) {
  final json = _object(value);
  _exactKeys(json, const ['venues']);
  final venues = <TownVenue>[];
  final seenVenueIds = <String>{};
  _VenueSortKey? previous;
  for (final rawVenue in _list(json['venues'])) {
    final venue = _parseTownVenue(rawVenue, playerId: playerId);
    if (!seenVenueIds.add(venue.venue.venue.id.value)) _malformed();
    final key =
        _VenueSortKey(venue.venue.displayName, venue.venue.venue.id.value);
    if (previous != null && previous.compareTo(key) >= 0) _malformed();
    previous = key;
    venues.add(venue);
  }
  return TownProjection(playerId: playerId, venues: venues);
}

TownVenue _parseTownVenue(Object? value, {required String playerId}) {
  final json = _object(value);
  _exactKeys(json, const [
    'venue_id',
    'venue_version_id',
    'venue_version_revision',
    'first_venue_version_id',
    'first_venue_version_revision',
    'reveal_outcome_result_id',
    'encounter_id',
    'known_at',
    'kind',
    'display_name',
    'city_id',
    'anchor_cell_id',
    'villagers',
  ]);
  final venueId = VenueId(_text(json['venue_id']));
  final venue = Venue(id: venueId);
  final knownVenue = KnownVenue(
    playerId: playerId,
    venueId: venueId,
    venueVersion: _venueVersionRef(
      venueId.value,
      json['first_venue_version_id'],
      json['first_venue_version_revision'],
    ),
    revealedAt: _timestamp(json['known_at']),
    provenance: RevealVenueProvenance(
      encounterId: _uuid(json['encounter_id']),
      outcomeResultId: _uuid(json['reveal_outcome_result_id']),
    ),
  );
  final villagers = <TownVillager>[];
  final seenVillagerIds = <String>{};
  var previousOrdinal = 0;
  for (final rawVillager in _list(json['villagers'])) {
    final villager = _parseTownVillager(rawVillager, playerId: playerId);
    if (!seenVillagerIds.add(villager.villager.villager.id.value) ||
        villager.venueAssociationOrdinal <= previousOrdinal) {
      _malformed();
    }
    previousOrdinal = villager.venueAssociationOrdinal;
    villagers.add(villager);
  }
  final currentVenue = VenueVersion(
    venue: venue,
    version: _venueVersionRef(
      venueId.value,
      json['venue_version_id'],
      json['venue_version_revision'],
    ),
    kind: _text(json['kind']),
    displayName: _text(json['display_name']),
    cityId: _text(json['city_id']),
    anchorCellId: _text(json['anchor_cell_id']),
    villagers: [
      for (final villager in villagers)
        VenueVillagerAssociation(
          venueId: venueId,
          villagerId: villager.villager.villager.id,
          ordinal: villager.venueAssociationOrdinal,
        ),
    ],
  );
  return TownVenue(
      knownVenue: knownVenue, venue: currentVenue, villagers: villagers);
}

TownVillager _parseTownVillager(Object? value, {required String playerId}) {
  final json = _object(value);
  _exactKeys(json, const [
    'villager_id',
    'villager_version_id',
    'villager_version_revision',
    'first_villager_version_id',
    'first_villager_version_revision',
    'first_venue_visit_id',
    'first_venue_id',
    'first_venue_version_id',
    'first_venue_version_revision',
    'known_at',
    'display_name',
    'role_name',
    'venue_association_ordinal',
    'services',
  ]);
  final villagerId = VillagerId(_text(json['villager_id']));
  final firstVenueId = VenueId(_text(json['first_venue_id']));
  final services = _parseServices(json['services'], villagerId);
  final currentVillager = VillagerVersion(
    villager: Villager(id: villagerId),
    version: _villagerVersionRef(
      villagerId.value,
      json['villager_version_id'],
      json['villager_version_revision'],
    ),
    displayName: _text(json['display_name']),
    role: _text(json['role_name']),
    services: [
      for (final service in services)
        VillagerServiceAssociation(
          villagerId: villagerId,
          serviceId: service.service.service.id,
          ordinal: service.associationOrdinal,
        ),
    ],
  );
  final knownVillager = KnownVillager(
    playerId: playerId,
    villagerId: villagerId,
    villagerVersion: _villagerVersionRef(
      villagerId.value,
      json['first_villager_version_id'],
      json['first_villager_version_revision'],
    ),
    introducedAtVenueId: firstVenueId,
    introducedByVenueVisitId: VenueVisitId(_uuid(json['first_venue_visit_id'])),
    introducedAt: _timestamp(json['known_at']),
  );
  return TownVillager(
    knownVillager: knownVillager,
    villager: currentVillager,
    venueAssociationOrdinal: _positiveInt(json['venue_association_ordinal']),
    services: services,
  );
}

List<TownService> _parseServices(Object? value, VillagerId owner) {
  final services = <TownService>[];
  final ids = <String>{};
  var previousOrdinal = 0;
  for (final rawService in _list(value)) {
    final service = _parseService(rawService, owner);
    if (!ids.add(service.service.service.id.value) ||
        service.associationOrdinal <= previousOrdinal) {
      _malformed();
    }
    previousOrdinal = service.associationOrdinal;
    services.add(service);
  }
  return services;
}

TownService _parseService(Object? value, VillagerId owner) {
  final json = _object(value);
  _exactKeys(json, const [
    'service_id',
    'service_version_id',
    'service_version_revision',
    'display_name',
    'description',
    'service_association_ordinal',
  ]);
  final serviceId = ServiceId(_text(json['service_id']));
  return TownService(
    service: ServiceVersion(
      service: Service(id: serviceId),
      version: _serviceVersionRef(
        serviceId.value,
        json['service_version_id'],
        json['service_version_revision'],
      ),
      displayName: _text(json['display_name']),
      description: _text(json['description']),
    ),
    associationOrdinal: _positiveInt(json['service_association_ordinal']),
  );
}

VenueVisit _parseVisit(Object? value, RecordVenueVisitCommand command) {
  final json = _object(value);
  _exactKeys(json, const [
    'id',
    'user_id',
    'cell_visit_id',
    'cell_id',
    'venue_id',
    'venue_version_id',
    'venue_version_revision',
    'visited_at',
    'is_idempotent_retry',
  ]);
  final userId = _uuid(json['user_id']);
  final cellVisitId = _uuid(json['cell_visit_id']);
  final cellId = _text(json['cell_id']);
  final venueId = VenueId(_text(json['venue_id']));
  final version = _venueVersionRef(
    venueId.value,
    json['venue_version_id'],
    json['venue_version_revision'],
  );
  if (userId != command.playerId ||
      cellVisitId != command.cellVisit.id ||
      cellId != command.cellVisit.cellId ||
      venueId != command.venueId ||
      version != command.venueVersion) {
    _malformed();
  }
  return VenueVisit(
    id: VenueVisitId(_uuid(json['id'])),
    cellVisit: CellVisit(
      id: cellVisitId,
      cellId: cellId,
      userId: userId,
      visitedAt: command.cellVisit.visitedAt,
      clientEventId: command.cellVisit.clientEventId,
    ),
    venueId: venueId,
    venueVersion: version,
    visitedAt: _timestamp(json['visited_at']),
  );
}

List<IntroducedVillager> _parseIntroduced(Object? value, VenueVisit visit) {
  final introduced = <IntroducedVillager>[];
  final ids = <String>{};
  var previousOrdinal = 0;
  for (final rawVillager in _list(value)) {
    final json = _object(rawVillager);
    _exactKeys(json, const [
      'villager_id',
      'villager_version_id',
      'villager_version_revision',
      'known_at',
      'display_name',
      'role_name',
      'venue_association_ordinal',
      'services',
    ]);
    final villagerId = VillagerId(_text(json['villager_id']));
    final services = _parseServices(json['services'], villagerId);
    final ordinal = _positiveInt(json['venue_association_ordinal']);
    if (!ids.add(villagerId.value) || ordinal <= previousOrdinal) _malformed();
    previousOrdinal = ordinal;
    final version = _villagerVersionRef(
      villagerId.value,
      json['villager_version_id'],
      json['villager_version_revision'],
    );
    final known = KnownVillager(
      playerId: visit.playerId,
      villagerId: villagerId,
      villagerVersion: version,
      introducedAtVenueId: visit.venueId,
      introducedByVenueVisitId: visit.id,
      introducedAt: _timestamp(json['known_at']),
    );
    introduced.add(
      IntroducedVillager(
        villager: known,
        ordinal: ordinal,
        services: [
          for (final service in services)
            IntroducedService(
                service: service.service, ordinal: service.associationOrdinal),
        ],
      ),
    );
  }
  return introduced;
}

void _validateReturnedTown(
  TownProjection town,
  RecordVenueVisitCommand command,
  List<IntroducedVillager> introduced,
) {
  final venue =
      town.venues.where((entry) => entry.knownVenue.venueId == command.venueId);
  if (venue.length != 1) _malformed();
  final townVillagers = venue.single.villagers
      .map((entry) => entry.knownVillager.villagerId.value)
      .toSet();
  if (introduced.any(
      (entry) => !townVillagers.contains(entry.villager.villagerId.value))) {
    _malformed();
  }
}

void _validateCommand(RecordVenueVisitCommand command) {
  _uuid(command.playerId);
  _uuid(command.cellVisit.id);
  _uuid(command.venueVersion.versionId.value);
}

VenueVersionRef _venueVersionRef(String owner, Object? id, Object? revision) =>
    ExactVersionRef<content.VenueContent>(
      stableId: StableContentId<content.VenueContent>(owner),
      versionId: ContentVersionId<content.VenueContent>(_uuid(id)),
      revision: _positiveInt(revision),
    );

VillagerVersionRef _villagerVersionRef(
        String owner, Object? id, Object? revision) =>
    ExactVersionRef<VillagerContent>(
      stableId: StableContentId<VillagerContent>(owner),
      versionId: ContentVersionId<VillagerContent>(_uuid(id)),
      revision: _positiveInt(revision),
    );

ServiceVersionRef _serviceVersionRef(
        String owner, Object? id, Object? revision) =>
    ExactVersionRef<ServiceContent>(
      stableId: StableContentId<ServiceContent>(owner),
      versionId: ContentVersionId<ServiceContent>(_uuid(id)),
      revision: _positiveInt(revision),
    );

Map<String, Object?> _object(Object? value) {
  if (value is! Map) _malformed();
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String || result.containsKey(entry.key)) _malformed();
    result[entry.key as String] = entry.value;
  }
  return result;
}

List<Object?> _list(Object? value) {
  if (value is! List) _malformed();
  return List<Object?>.unmodifiable(value);
}

void _exactKeys(Map<String, Object?> value, List<String> expected) {
  if (value.length != expected.length ||
      value.keys.any((key) => !expected.contains(key))) {
    _malformed();
  }
}

String _text(Object? value) {
  if (value is! String || value.isEmpty || value != value.trim()) _malformed();
  return value;
}

String _uuid(Object? value) {
  final result = _text(value);
  if (!_uuidPattern.hasMatch(result)) _malformed();
  return result;
}

int _positiveInt(Object? value) {
  if (value is! int || value <= 0) _malformed();
  return value;
}

bool _bool(Object? value) {
  if (value is! bool) _malformed();
  return value;
}

DateTime _timestamp(Object? value) {
  final text = _text(value);
  if (!_timestampPattern.hasMatch(text)) _malformed();
  final parsed = DateTime.tryParse(text);
  if (parsed == null) _malformed();
  return parsed.toUtc();
}

Never _malformed() => throw const LivingWorldFailure.malformedPayload();

final _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);
final _timestampPattern = RegExp(
  r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$',
);

final class _VenueSortKey implements Comparable<_VenueSortKey> {
  const _VenueSortKey(this.name, this.id);

  final String name;
  final String id;

  @override
  int compareTo(_VenueSortKey other) {
    final byName = name.compareTo(other.name);
    return byName != 0 ? byName : id.compareTo(other.id);
  }
}
