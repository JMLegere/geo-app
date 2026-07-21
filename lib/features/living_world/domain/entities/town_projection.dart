import 'package:earth_nova/core/domain/entities/venue_id.dart';
import 'package:earth_nova/features/living_world/domain/entities/authored_living_world_entities.dart';
import 'package:earth_nova/features/living_world/domain/entities/living_world_knowledge.dart';

/// A read-only Service row within one Villager group in Town.
final class TownService {
  TownService({
    required this.service,
    required this.associationOrdinal,
  }) {
    if (associationOrdinal <= 0) {
      throw ArgumentError.value(
        associationOrdinal,
        'associationOrdinal',
        'must be greater than zero',
      );
    }
  }

  final ServiceVersion service;
  final int associationOrdinal;
}

/// A read-only Villager group within one Venue in Town.
final class TownVillager {
  factory TownVillager({
    required KnownVillager knownVillager,
    required VillagerVersion villager,
    required int venueAssociationOrdinal,
    Iterable<TownService> services = const [],
  }) {
    if (knownVillager.villagerId != villager.villager.id) {
      throw ArgumentError.value(
        villager,
        'villager',
        'must have the same stable identity as knownVillager',
      );
    }
    if (venueAssociationOrdinal <= 0) {
      throw ArgumentError.value(
        venueAssociationOrdinal,
        'venueAssociationOrdinal',
        'must be greater than zero',
      );
    }
    final orderedServices = List<TownService>.of(services);
    final ids = <ServiceId>{};
    final ordinals = <int>{};
    final authoredAssociations = {
      for (final association in villager.services)
        association.serviceId: association.ordinal,
    };
    for (final service in orderedServices) {
      final expectedOrdinal = authoredAssociations[service.service.service.id];
      if (expectedOrdinal == null ||
          expectedOrdinal != service.associationOrdinal) {
        throw ArgumentError.value(
          service,
          'services',
          'must match a current Villager Service association',
        );
      }
      if (!ids.add(service.service.service.id)) {
        throw ArgumentError.value(
            services, 'services', 'must not contain duplicate Services');
      }
      if (!ordinals.add(service.associationOrdinal)) {
        throw ArgumentError.value(
            services, 'services', 'must not contain duplicate ordinals');
      }
    }
    orderedServices.sort(
      (left, right) =>
          left.associationOrdinal.compareTo(right.associationOrdinal),
    );
    return TownVillager._(
      knownVillager: knownVillager,
      villager: villager,
      venueAssociationOrdinal: venueAssociationOrdinal,
      services: List<TownService>.unmodifiable(orderedServices),
    );
  }

  const TownVillager._({
    required this.knownVillager,
    required this.villager,
    required this.venueAssociationOrdinal,
    required this.services,
  });

  final KnownVillager knownVillager;
  final VillagerVersion villager;
  final int venueAssociationOrdinal;
  final List<TownService> services;
}

/// A read-only Venue group in Town.
final class TownVenue {
  factory TownVenue({
    required KnownVenue knownVenue,
    required VenueVersion venue,
    Iterable<TownVillager> villagers = const [],
  }) {
    if (knownVenue.venueId != venue.venue.id) {
      throw ArgumentError.value(
        venue,
        'venue',
        'must have the same stable identity as knownVenue',
      );
    }
    final orderedVillagers = List<TownVillager>.of(villagers);
    final ids = <VillagerId>{};
    final ordinals = <int>{};
    final authoredAssociations = {
      for (final association in venue.villagers)
        association.villagerId: association.ordinal,
    };
    for (final villager in orderedVillagers) {
      final expectedOrdinal =
          authoredAssociations[villager.villager.villager.id];
      if (villager.knownVillager.playerId != knownVenue.playerId ||
          expectedOrdinal == null ||
          expectedOrdinal != villager.venueAssociationOrdinal) {
        throw ArgumentError.value(
          villager,
          'villagers',
          'must be a known player Villager in a current Venue association',
        );
      }
      if (!ids.add(villager.villager.villager.id)) {
        throw ArgumentError.value(
            villagers, 'villagers', 'must not contain duplicate Villagers');
      }
      if (!ordinals.add(villager.venueAssociationOrdinal)) {
        throw ArgumentError.value(
            villagers, 'villagers', 'must not contain duplicate ordinals');
      }
    }
    orderedVillagers.sort(
      (left, right) =>
          left.venueAssociationOrdinal.compareTo(right.venueAssociationOrdinal),
    );
    return TownVenue._(
      knownVenue: knownVenue,
      venue: venue,
      villagers: List<TownVillager>.unmodifiable(orderedVillagers),
    );
  }

  const TownVenue._({
    required this.knownVenue,
    required this.venue,
    required this.villagers,
  });

  final KnownVenue knownVenue;

  /// Current published authored content, intentionally distinct from the exact
  /// Version first bound by [knownVenue].
  final VenueVersion venue;
  final List<TownVillager> villagers;
}

/// A pure, read-only player-facing projection of known world content.
///
/// Town has no identity or mutation behavior. Reconstructing or navigating it
/// cannot reveal Venues, create Visits, introduce Villagers, or touch Items.
final class TownProjection {
  factory TownProjection({
    required String playerId,
    Iterable<TownVenue> venues = const [],
  }) {
    final canonicalPlayerId = _nonBlank(playerId, 'playerId');
    final orderedVenues = List<TownVenue>.of(venues);
    final ids = <VenueId>{};
    for (final venue in orderedVenues) {
      if (venue.knownVenue.playerId != canonicalPlayerId) {
        throw ArgumentError.value(
          venue,
          'venues',
          'must belong to playerId',
        );
      }
      if (!ids.add(venue.venue.venue.id)) {
        throw ArgumentError.value(
            venues, 'venues', 'must not contain duplicate Venues');
      }
    }
    orderedVenues.sort(_compareVenues);
    return TownProjection._(
      playerId: canonicalPlayerId,
      venues: List<TownVenue>.unmodifiable(orderedVenues),
    );
  }

  const TownProjection._({required this.playerId, required this.venues});

  final String playerId;
  final List<TownVenue> venues;
}

int _compareVenues(TownVenue left, TownVenue right) {
  final byName = left.venue.displayName.compareTo(right.venue.displayName);
  if (byName != 0) return byName;
  return left.venue.venue.id.value.compareTo(right.venue.venue.id.value);
}

String _nonBlank(String value, String name) {
  final canonical = value.trim();
  if (canonical.isEmpty) {
    throw ArgumentError.value(value, name, 'must be nonblank');
  }
  return canonical;
}
