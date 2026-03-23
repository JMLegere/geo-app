import 'dart:convert';

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

  /// IDs of adjacent location nodes at the same admin level.
  /// Populated by server-side enrichment. Used for detection zone expansion.
  final List<String>? adjacentLocationIds;

  /// Pre-computed cell IDs within this location's boundary.
  /// Populated client-side after flood-fill from geometryJson.
  final List<String>? cellIds;

  const LocationNode({
    required this.id,
    required this.osmId,
    required this.name,
    required this.adminLevel,
    required this.parentId,
    required this.colorHex,
    required this.geometryJson,
    this.adjacentLocationIds,
    this.cellIds,
  });

  LocationNode copyWith({
    String? id,
    int? osmId,
    String? name,
    AdminLevel? adminLevel,
    String? parentId,
    String? colorHex,
    String? Function()? geometryJson,
    List<String>? adjacentLocationIds,
    List<String>? cellIds,
  }) {
    return LocationNode(
      id: id ?? this.id,
      osmId: osmId ?? this.osmId,
      name: name ?? this.name,
      adminLevel: adminLevel ?? this.adminLevel,
      parentId: parentId ?? this.parentId,
      colorHex: colorHex ?? this.colorHex,
      geometryJson: geometryJson != null ? geometryJson() : this.geometryJson,
      adjacentLocationIds: adjacentLocationIds ?? this.adjacentLocationIds,
      cellIds: cellIds ?? this.cellIds,
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
      'adjacentLocationIds': adjacentLocationIds,
      'cellIds': cellIds,
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
      geometryJson: row.geometryJson,
      adjacentLocationIds: row.adjacentLocationIds != null
          ? (jsonDecode(row.adjacentLocationIds!) as List)
              .map((e) => e as String)
              .toList()
          : null,
      cellIds: row.cellIds != null
          ? (jsonDecode(row.cellIds!) as List).map((e) => e as String).toList()
          : null,
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
      geometryJson: geometryJson,
      adjacentLocationIds:
          adjacentLocationIds != null ? jsonEncode(adjacentLocationIds) : null,
      cellIds: cellIds != null ? jsonEncode(cellIds) : null,
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
      geometryJson: Value(geometryJson),
      adjacentLocationIds: Value(
          adjacentLocationIds != null ? jsonEncode(adjacentLocationIds) : null),
      cellIds: Value(cellIds != null ? jsonEncode(cellIds) : null),
    );
  }

  static LocationNode fromJson(Map<String, dynamic> json) {
    return LocationNode(
      id: json['id'] as String,
      osmId: json['osmId'] as int?,
      name: json['name'] as String,
      adminLevel: AdminLevel.fromString(json['adminLevel'] as String),
      parentId: json['parentId'] as String?,
      colorHex: json['colorHex'] as String?,
      geometryJson: json['geometryJson'] as String?,
      adjacentLocationIds: (json['adjacentLocationIds'] as List?)
          ?.map((e) => e as String)
          .toList(),
      cellIds: (json['cellIds'] as List?)?.map((e) => e as String).toList(),
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
        other.geometryJson == geometryJson &&
        _listEquals(other.adjacentLocationIds, adjacentLocationIds) &&
        _listEquals(other.cellIds, cellIds);
  }

  static bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
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
      Object.hashAll(adjacentLocationIds ?? []),
      Object.hashAll(cellIds ?? []),
    );
  }

  @override
  String toString() {
    return 'LocationNode(id: $id, osmId: $osmId, name: $name, '
        'adminLevel: $adminLevel, parentId: $parentId, colorHex: $colorHex, '
        'geometryJson: ${geometryJson != null ? "present" : "null"}, '
        'adjacentLocationIds: ${adjacentLocationIds?.length ?? 0} items, '
        'cellIds: ${cellIds?.length ?? 0} items)';
  }
}
