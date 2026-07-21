import 'package:earth_nova/core/domain/entities/venue_id.dart';
import 'package:earth_nova/features/living_world/domain/entities/authored_living_world_entities.dart';
import 'package:earth_nova/features/living_world/domain/entities/town_projection.dart';
import 'package:earth_nova/features/map/domain/entities/cell_visit.dart';

/// Immutable evidence for the committed Reveal Venue outcome that first made a
/// Venue known. The evidence is intentionally opaque at this boundary; the
/// Encounter domain owns the referenced records.
final class RevealVenueProvenance {
  RevealVenueProvenance({
    required String encounterId,
    required String outcomeResultId,
  })  : encounterId = _nonBlank(encounterId, 'encounterId'),
        outcomeResultId = _nonBlank(outcomeResultId, 'outcomeResultId');

  final String encounterId;
  final String outcomeResultId;
}

/// Player-scoped durable knowledge of a stable Venue.
///
/// Revealing a Venue binds this exact authored Version, but intentionally does
/// not imply that any Villager is known.
final class KnownVenue {
  factory KnownVenue({
    required String playerId,
    required VenueId venueId,
    required VenueVersionRef venueVersion,
    required DateTime revealedAt,
    required RevealVenueProvenance provenance,
  }) {
    _requireVersionOwner(
        venueId.value, venueVersion.stableId.value, 'venueVersion');
    return KnownVenue._(
      playerId: _nonBlank(playerId, 'playerId'),
      venueId: venueId,
      venueVersion: venueVersion,
      revealedAt: revealedAt,
      provenance: provenance,
    );
  }

  const KnownVenue._({
    required this.playerId,
    required this.venueId,
    required this.venueVersion,
    required this.revealedAt,
    required this.provenance,
  });

  final String playerId;
  final VenueId venueId;

  /// The exact Version that was published when this knowledge was first made.
  final VenueVersionRef venueVersion;
  final DateTime revealedAt;
  final RevealVenueProvenance provenance;
}

/// A durable Visit identity.
final class VenueVisitId extends LivingWorldId {
  VenueVisitId(super.value);
}

/// One recorded player visit to a known Venue anchored by an exact Cell Visit.
final class VenueVisit {
  factory VenueVisit({
    required VenueVisitId id,
    required CellVisit cellVisit,
    required VenueId venueId,
    required VenueVersionRef venueVersion,
    required DateTime visitedAt,
  }) {
    _requireVersionOwner(
        venueId.value, venueVersion.stableId.value, 'venueVersion');
    _nonBlank(cellVisit.id, 'cellVisit.id');
    _nonBlank(cellVisit.userId, 'cellVisit.userId');
    _nonBlank(cellVisit.cellId, 'cellVisit.cellId');
    return VenueVisit._(
      id: id,
      cellVisit: cellVisit,
      venueId: venueId,
      venueVersion: venueVersion,
      visitedAt: visitedAt,
    );
  }

  const VenueVisit._({
    required this.id,
    required this.cellVisit,
    required this.venueId,
    required this.venueVersion,
    required this.visitedAt,
  });

  final VenueVisitId id;

  /// The already persisted Cell Visit that authorizes this Venue Visit.
  final CellVisit cellVisit;
  final VenueId venueId;

  /// The exact Venue Version current when the Visit was committed.
  final VenueVersionRef venueVersion;
  final DateTime visitedAt;

  String get playerId => cellVisit.userId;
}

/// Player-scoped durable knowledge of a Villager first met on a Venue Visit.
final class KnownVillager {
  factory KnownVillager({
    required String playerId,
    required VillagerId villagerId,
    required VillagerVersionRef villagerVersion,
    required VenueId introducedAtVenueId,
    required VenueVisitId introducedByVenueVisitId,
    required DateTime introducedAt,
  }) {
    _requireVersionOwner(
      villagerId.value,
      villagerVersion.stableId.value,
      'villagerVersion',
    );
    return KnownVillager._(
      playerId: _nonBlank(playerId, 'playerId'),
      villagerId: villagerId,
      villagerVersion: villagerVersion,
      introducedAtVenueId: introducedAtVenueId,
      introducedByVenueVisitId: introducedByVenueVisitId,
      introducedAt: introducedAt,
    );
  }

  const KnownVillager._({
    required this.playerId,
    required this.villagerId,
    required this.villagerVersion,
    required this.introducedAtVenueId,
    required this.introducedByVenueVisitId,
    required this.introducedAt,
  });

  final String playerId;
  final VillagerId villagerId;
  final VillagerVersionRef villagerVersion;
  final VenueId introducedAtVenueId;
  final VenueVisitId introducedByVenueVisitId;
  final DateTime introducedAt;
}

/// Exact evidence submitted at the narrow Venue Visit command boundary.
///
/// It accepts an already persisted [CellVisit], rather than a GPS event,
/// geofence, or synthetic cell identifier. Physical trigger policy belongs to
/// a future adapter.
final class RecordVenueVisitCommand {
  factory RecordVenueVisitCommand({
    required CellVisit cellVisit,
    required VenueId venueId,
    required VenueVersionRef venueVersion,
  }) {
    _nonBlank(cellVisit.id, 'cellVisit.id');
    _nonBlank(cellVisit.userId, 'cellVisit.userId');
    _nonBlank(cellVisit.cellId, 'cellVisit.cellId');
    _requireVersionOwner(
        venueId.value, venueVersion.stableId.value, 'venueVersion');
    return RecordVenueVisitCommand._(
      cellVisit: cellVisit,
      venueId: venueId,
      venueVersion: venueVersion,
    );
  }

  const RecordVenueVisitCommand._({
    required this.cellVisit,
    required this.venueId,
    required this.venueVersion,
  });

  final CellVisit cellVisit;
  final VenueId venueId;
  final VenueVersionRef venueVersion;

  String get playerId => cellVisit.userId;
}

/// One Service made visible alongside a newly introduced Villager.
final class IntroducedService {
  IntroducedService({
    required this.service,
    required this.ordinal,
  }) {
    if (ordinal <= 0) {
      throw ArgumentError.value(
          ordinal, 'ordinal', 'must be greater than zero');
    }
  }

  final ServiceVersion service;
  final int ordinal;
}

/// One Villager newly introduced by a Venue Visit and their associated Services.
final class IntroducedVillager {
  factory IntroducedVillager({
    required KnownVillager villager,
    required int ordinal,
    Iterable<IntroducedService> services = const [],
  }) {
    if (ordinal <= 0) {
      throw ArgumentError.value(
          ordinal, 'ordinal', 'must be greater than zero');
    }
    final orderedServices = List<IntroducedService>.of(services);
    final serviceIds = <ServiceId>{};
    final serviceOrdinals = <int>{};
    for (final service in orderedServices) {
      if (!serviceIds.add(service.service.service.id)) {
        throw ArgumentError.value(
            services, 'services', 'must not contain duplicate Services');
      }
      if (!serviceOrdinals.add(service.ordinal)) {
        throw ArgumentError.value(
            services, 'services', 'must not contain duplicate ordinals');
      }
    }
    orderedServices
        .sort((left, right) => left.ordinal.compareTo(right.ordinal));
    return IntroducedVillager._(
      villager: villager,
      ordinal: ordinal,
      services: List<IntroducedService>.unmodifiable(orderedServices),
    );
  }

  const IntroducedVillager._({
    required this.villager,
    required this.ordinal,
    required this.services,
  });

  final KnownVillager villager;
  final int ordinal;
  final List<IntroducedService> services;
}

/// The atomic result of a Venue Visit command.
final class VenueVisitResult {
  factory VenueVisitResult({
    required VenueVisit visit,
    required TownProjection town,
    required bool isIdempotentRetry,
    Iterable<IntroducedVillager> introducedVillagers = const [],
  }) {
    if (town.playerId != visit.playerId) {
      throw ArgumentError.value(
        town,
        'town',
        'must belong to the same player as visit',
      );
    }
    final introduced = List<IntroducedVillager>.of(introducedVillagers);
    final ids = <VillagerId>{};
    final ordinals = <int>{};
    for (final villager in introduced) {
      if (villager.villager.playerId != visit.playerId ||
          villager.villager.introducedAtVenueId != visit.venueId ||
          villager.villager.introducedByVenueVisitId != visit.id) {
        throw ArgumentError.value(
          villager,
          'introducedVillagers',
          'must be introduced by this visit for this player and Venue',
        );
      }
      if (!ids.add(villager.villager.villagerId)) {
        throw ArgumentError.value(
          introducedVillagers,
          'introducedVillagers',
          'must not contain duplicate Villagers',
        );
      }
      if (!ordinals.add(villager.ordinal)) {
        throw ArgumentError.value(
          introducedVillagers,
          'introducedVillagers',
          'must not contain duplicate ordinals',
        );
      }
    }
    if (isIdempotentRetry && introduced.isNotEmpty) {
      throw ArgumentError.value(
        introducedVillagers,
        'introducedVillagers',
        'must be empty for an idempotent retry',
      );
    }
    introduced.sort((left, right) => left.ordinal.compareTo(right.ordinal));
    return VenueVisitResult._(
      visit: visit,
      town: town,
      isIdempotentRetry: isIdempotentRetry,
      introducedVillagers: List<IntroducedVillager>.unmodifiable(introduced),
    );
  }

  const VenueVisitResult._({
    required this.visit,
    required this.town,
    required this.isIdempotentRetry,
    required this.introducedVillagers,
  });

  final VenueVisit visit;

  /// The authoritative post-commit Town projection. Consumers replace their
  /// read state with this value rather than appending speculative rows.
  final TownProjection town;
  final bool isIdempotentRetry;
  final List<IntroducedVillager> introducedVillagers;
}

String _nonBlank(String value, String name) {
  final canonical = value.trim();
  if (canonical.isEmpty) {
    throw ArgumentError.value(value, name, 'must be nonblank');
  }
  return canonical;
}

void _requireVersionOwner(String identity, String versionOwner, String name) {
  if (identity != versionOwner) {
    throw ArgumentError.value(
      versionOwner,
      name,
      'must belong to the same stable identity',
    );
  }
}
