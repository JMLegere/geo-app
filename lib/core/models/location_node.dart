import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';

import 'package:earth_nova/core/database/app_database.dart';

/// 6-level administrative hierarchy for location nodes.
/// World > Continent > Country > State > City > District.
enum AdminLevel {
  /// Synthetic root node — the entire world
  world,

  /// admin_level 1 — Continent (implicit from country)
  continent,

  /// admin_level 2 — Country
  country,

  /// admin_level 4 — State/Province
  state,

  /// admin_level 6-8 — City/Town
  city,

  /// admin_level 9-10 — District/Neighborhood
  district;

  String get displayName => switch (this) {
        AdminLevel.world => 'World',
        AdminLevel.continent => 'Continent',
        AdminLevel.country => 'Country',
        AdminLevel.state => 'State/Province',
        AdminLevel.city => 'City',
        AdminLevel.district => 'District',
      };

  static AdminLevel fromString(String value) {
    return AdminLevel.values.firstWhere(
      (level) => level.name == value,
      orElse: () => throw ArgumentError('Unknown AdminLevel: $value'),
    );
  }

  @override
  String toString() => name;
}

/// A node in the administrative location hierarchy.
/// Represents a geographic boundary (country, state, city, etc.).
///
/// LocationNodes form a tree structure via parentId foreign key.
/// Globally shared — not per-user.
@immutable
class LocationNode {
  /// Unique identifier (UUID)
  final String id;

  /// OpenStreetMap relation ID (null for synthetic nodes like world/continent)
  final int? osmId;

  /// Display name (e.g., "Fredericton", "New Brunswick", "Canada")
  final String name;

  /// Administrative level in the hierarchy
  final AdminLevel adminLevel;

  /// Foreign key to parent LocationNode (null for root nodes like continents)
  final String? parentId;

  /// Territory color derived from flag or other source (hex format, e.g., "#FF0000")
  /// Null if no color is available
  final String? colorHex;

  /// Simplified GeoJSON polygon string for the boundary
  /// Null if geometry has not been fetched from Nominatim
  final String? geometryJson;

  const LocationNode({
    required this.id,
    required this.osmId,
    required this.name,
    required this.adminLevel,
    required this.parentId,
    required this.colorHex,
    required this.geometryJson,
  });

  LocationNode copyWith({
    String? id,
    int? osmId,
    String? name,
    AdminLevel? adminLevel,
    String? parentId,
    String? colorHex,
    String? Function()? geometryJson,
  }) {
    return LocationNode(
      id: id ?? this.id,
      osmId: osmId ?? this.osmId,
      name: name ?? this.name,
      adminLevel: adminLevel ?? this.adminLevel,
      parentId: parentId ?? this.parentId,
      colorHex: colorHex ?? this.colorHex,
      geometryJson: geometryJson != null ? geometryJson() : this.geometryJson,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'osmId': osmId,
      'name': name,
      'adminLevel': adminLevel.name,
      'parentId': parentId,
      'colorHex': colorHex,
      'geometryJson': geometryJson,
    };
  }

  factory LocationNode.fromDrift(LocalLocationNode row) {
    return LocationNode(
      id: row.id,
      osmId: row.osmId,
      name: row.name,
      adminLevel: AdminLevel.fromString(row.adminLevel),
      parentId: row.parentId,
      colorHex: row.colorHex,
      geometryJson:
          null, // geometryJson column will be added in a future migration
    );
  }

  LocalLocationNode toDriftRow() {
    return LocalLocationNode(
      id: id,
      osmId: osmId,
      name: name,
      adminLevel: adminLevel.name,
      parentId: parentId,
      colorHex: colorHex,
      createdAt: DateTime.now(),
    );
  }

  LocalLocationNodeTableCompanion toDriftCompanion() {
    return LocalLocationNodeTableCompanion(
      id: Value(id),
      osmId: Value(osmId),
      name: Value(name),
      adminLevel: Value(adminLevel.name),
      parentId: Value(parentId),
      colorHex: Value(colorHex),
    );
  }

  static LocationNode fromJson(Map<String, dynamic> json) {
    return LocationNode(
      id: json['id'] as String,
      osmId: json['osmId'] as int,
      name: json['name'] as String,
      adminLevel: AdminLevel.fromString(json['adminLevel'] as String),
      parentId: json['parentId'] as String?,
      colorHex: json['colorHex'] as String?,
      geometryJson: json['geometryJson'] as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is LocationNode &&
        other.id == id &&
        other.osmId == osmId &&
        other.name == name &&
        other.adminLevel == adminLevel &&
        other.parentId == parentId &&
        other.colorHex == colorHex &&
        other.geometryJson == geometryJson;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      osmId,
      name,
      adminLevel,
      parentId,
      colorHex,
      geometryJson,
    );
  }

  @override
  String toString() {
    return 'LocationNode(id: $id, osmId: $osmId, name: $name, '
        'adminLevel: $adminLevel, parentId: $parentId, colorHex: $colorHex, '
        'geometryJson: $geometryJson)';
  }
}
