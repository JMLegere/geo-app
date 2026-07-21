import 'package:earth_nova/core/domain/content/content_identity.dart';
import 'package:earth_nova/core/domain/content/venue_content.dart';
import 'package:earth_nova/core/domain/entities/venue_id.dart';

/// Type marker for immutable authored Villager snapshots.
final class VillagerContent {
  const VillagerContent._();
}

/// Type marker for immutable authored Service snapshots.
final class ServiceContent {
  const ServiceContent._();
}

/// An exact immutable Venue Version binding.
typedef VenueVersionRef = ExactVersionRef<VenueContent>;

/// An exact immutable Villager Version binding.
typedef VillagerVersionRef = ExactVersionRef<VillagerContent>;

/// An exact immutable Service Version binding.
typedef ServiceVersionRef = ExactVersionRef<ServiceContent>;

/// A stable authored Venue identity.
///
/// [VenueId] is shared with Reveal Venue outcome evidence. It is deliberately
/// stable across immutable [VenueVersion] revisions.
final class Venue {
  const Venue({required this.id});

  final VenueId id;
}

/// An immutable authored Venue snapshot and its current roster associations.
final class VenueVersion {
  factory VenueVersion({
    required Venue venue,
    required VenueVersionRef version,
    required String kind,
    required String displayName,
    required String cityId,
    required String anchorCellId,
    Iterable<VenueVillagerAssociation> villagers = const [],
  }) {
    _requireVersionOwner(venue.id.value, version.stableId.value, 'version');
    final orderedVillagers = _orderedUnique(
      villagers,
      (association) => association.villagerId.value,
      (association) => association.ordinal,
      'villagers',
    );
    for (final association in orderedVillagers) {
      if (association.venueId != venue.id) {
        throw ArgumentError.value(
          association,
          'villagers',
          'must belong to venue.id',
        );
      }
    }
    return VenueVersion._(
      venue: venue,
      version: version,
      kind: _nonBlank(kind, 'kind'),
      displayName: _nonBlank(displayName, 'displayName'),
      cityId: _nonBlank(cityId, 'cityId'),
      anchorCellId: _nonBlank(anchorCellId, 'anchorCellId'),
      villagers: orderedVillagers,
    );
  }

  const VenueVersion._({
    required this.venue,
    required this.version,
    required this.kind,
    required this.displayName,
    required this.cityId,
    required this.anchorCellId,
    required this.villagers,
  });

  final Venue venue;
  final VenueVersionRef version;
  final String kind;
  final String displayName;
  final String cityId;
  final String anchorCellId;

  /// Ordered, immutable current Venue-to-Villager associations.
  final List<VenueVillagerAssociation> villagers;
}

/// A stable authored Villager identity.
final class Villager {
  const Villager({required this.id});

  final VillagerId id;
}

/// An immutable authored Villager snapshot and its current Service associations.
final class VillagerVersion {
  factory VillagerVersion({
    required Villager villager,
    required VillagerVersionRef version,
    required String displayName,
    required String role,
    Iterable<VillagerServiceAssociation> services = const [],
  }) {
    _requireVersionOwner(villager.id.value, version.stableId.value, 'version');
    final orderedServices = _orderedUnique(
      services,
      (association) => association.serviceId.value,
      (association) => association.ordinal,
      'services',
    );
    for (final association in orderedServices) {
      if (association.villagerId != villager.id) {
        throw ArgumentError.value(
          association,
          'services',
          'must belong to villager.id',
        );
      }
    }
    return VillagerVersion._(
      villager: villager,
      version: version,
      displayName: _nonBlank(displayName, 'displayName'),
      role: _nonBlank(role, 'role'),
      services: orderedServices,
    );
  }

  const VillagerVersion._({
    required this.villager,
    required this.version,
    required this.displayName,
    required this.role,
    required this.services,
  });

  final Villager villager;
  final VillagerVersionRef version;
  final String displayName;
  final String role;

  /// Ordered, immutable current Villager-to-Service associations.
  final List<VillagerServiceAssociation> services;
}

/// A stable authored Service identity.
final class Service {
  const Service({required this.id});

  final ServiceId id;
}

/// An immutable authored Service snapshot.
final class ServiceVersion {
  factory ServiceVersion({
    required Service service,
    required ServiceVersionRef version,
    required String displayName,
    required String description,
  }) {
    _requireVersionOwner(service.id.value, version.stableId.value, 'version');
    return ServiceVersion._(
      service: service,
      version: version,
      displayName: _nonBlank(displayName, 'displayName'),
      description: _nonBlank(description, 'description'),
    );
  }

  const ServiceVersion._({
    required this.service,
    required this.version,
    required this.displayName,
    required this.description,
  });

  final Service service;
  final ServiceVersionRef version;
  final String displayName;
  final String description;
}

/// Current ordered membership of one Villager at one Venue.
final class VenueVillagerAssociation {
  VenueVillagerAssociation({
    required this.venueId,
    required this.villagerId,
    required this.ordinal,
  }) {
    _positiveOrdinal(ordinal, 'ordinal');
  }

  final VenueId venueId;
  final VillagerId villagerId;
  final int ordinal;
}

/// Current ordered availability of one Service from one Villager.
final class VillagerServiceAssociation {
  VillagerServiceAssociation({
    required this.villagerId,
    required this.serviceId,
    required this.ordinal,
  }) {
    _positiveOrdinal(ordinal, 'ordinal');
  }

  final VillagerId villagerId;
  final ServiceId serviceId;
  final int ordinal;
}

/// Immutable nonblank identity used by durable Living World records.
abstract class LivingWorldId {
  LivingWorldId(String value) : value = _nonBlank(value, 'value');

  final String value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other.runtimeType == runtimeType &&
          other is LivingWorldId &&
          value == other.value;

  @override
  int get hashCode => Object.hash(runtimeType, value);

  @override
  String toString() => value;
}

/// Stable authored Villager identity.
final class VillagerId extends LivingWorldId {
  VillagerId(super.value);
}

/// Stable authored Service identity.
final class ServiceId extends LivingWorldId {
  ServiceId(super.value);
}

List<T> _orderedUnique<T>(
  Iterable<T> source,
  String Function(T value) identity,
  int Function(T value) ordinal,
  String name,
) {
  final values = List<T>.of(source);
  final identities = <String>{};
  final ordinals = <int>{};
  for (final value in values) {
    final id = identity(value);
    if (!identities.add(id)) {
      throw ArgumentError.value(source, name, 'must not contain duplicate IDs');
    }
    final index = ordinal(value);
    _positiveOrdinal(index, '$name.ordinal');
    if (!ordinals.add(index)) {
      throw ArgumentError.value(
          source, name, 'must not contain duplicate ordinals');
    }
  }
  values.sort((left, right) => ordinal(left).compareTo(ordinal(right)));
  return List<T>.unmodifiable(values);
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

String _nonBlank(String value, String name) {
  final canonical = value.trim();
  if (canonical.isEmpty) {
    throw ArgumentError.value(value, name, 'must be nonblank');
  }
  return canonical;
}

void _positiveOrdinal(int value, String name) {
  if (value <= 0) {
    throw ArgumentError.value(value, name, 'must be greater than zero');
  }
}
