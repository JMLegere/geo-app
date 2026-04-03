import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';

import 'package:earth_nova/data/database.dart';
import 'package:earth_nova/models/habitat.dart';
import 'package:earth_nova/models/climate.dart';
import 'package:earth_nova/models/continent.dart';

/// Permanent geo-derived properties for a Voronoi cell.
/// Resolved once when any player first makes the cell adjacent.
/// Globally shared — not per-user.
///
/// Events (rotating layer) are NOT stored here — they're deterministic
/// from daily seed + cell ID and recomputed on access via EventResolver.
@immutable
class CellProperties {
  /// Unique cell identifier (e.g., "v_42_17" for Voronoi, or hex string for H3)
  final String cellId;

  /// Set of habitats present in this cell (1+ per cell, never empty)
  /// Plains is the fallback habitat if no others are determined
  final Set<Habitat> habitats;

  /// Single climate zone derived from cell center latitude
  final Climate climate;

  /// Continent derived from cell center coordinates
  final Continent continent;

  /// Foreign key to LocationNode (null until enriched with OSM boundary data)
  final String? locationId;

  /// Timestamp when this cell's properties were first resolved
  final DateTime createdAt;

  CellProperties({
    required this.cellId,
    required Set<Habitat> habitats,
    required this.climate,
    required this.continent,
    required this.locationId,
    required this.createdAt,
  })  : assert(habitats.isNotEmpty, 'habitats must not be empty'),
        habitats = habitats;

  CellProperties copyWith({
    String? cellId,
    Set<Habitat>? habitats,
    Climate? climate,
    Continent? continent,
    String? locationId,
    DateTime? createdAt,
  }) {
    return CellProperties(
      cellId: cellId ?? this.cellId,
      habitats: habitats ?? this.habitats,
      climate: climate ?? this.climate,
      continent: continent ?? this.continent,
      locationId: locationId ?? this.locationId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Serializes to the Supabase `cell_properties` table row format.
  ///
  /// Matches the payload format used by the write queue for routing.
  Map<String, dynamic> toSupabaseMap() {
    return {
      'cell_id': cellId,
      'habitats': habitats.map((h) => h.name).toList(),
      'climate': climate.name,
      'continent': continent.name,
      'location_id': locationId,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'cellId': cellId,
      'habitats': habitats.map((h) => h.name).toList(),
      'climate': climate.name,
      'continent': continent.name,
      'locationId': locationId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory CellProperties.fromDrift(CellProperty row) {
    return CellProperties(
      cellId: row.cellId,
      habitats: (jsonDecode(row.habitatsJson) as List)
          .map((h) => Habitat.fromString(h as String))
          .toSet(),
      climate: Climate.fromString(row.climate),
      continent: Continent.fromString(row.continent),
      locationId: row.locationId,
      createdAt: row.createdAt,
    );
  }

  CellPropertiesTableCompanion toDriftCompanion() {
    return CellPropertiesTableCompanion(
      cellId: Value(cellId),
      habitatsJson: Value(jsonEncode(habitats.map((h) => h.name).toList())),
      climate: Value(climate.name),
      continent: Value(continent.name),
      locationId: Value(locationId),
      createdAt: Value(createdAt),
    );
  }

  static CellProperties fromJson(Map<String, dynamic> json) {
    return CellProperties(
      cellId: json['cellId'] as String,
      habitats: (json['habitats'] as List)
          .map((h) => Habitat.fromString(h as String))
          .toSet(),
      climate: Climate.fromString(json['climate'] as String),
      continent: Continent.fromString(json['continent'] as String),
      locationId: json['locationId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is CellProperties &&
        other.cellId == cellId &&
        setEquals(other.habitats, habitats) &&
        other.climate == climate &&
        other.continent == continent &&
        other.locationId == locationId &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      cellId,
      habitats,
      climate,
      continent,
      locationId,
      createdAt,
    );
  }

  @override
  String toString() {
    return 'CellProperties(cellId: $cellId, habitats: $habitats, '
        'climate: $climate, continent: $continent, locationId: $locationId, '
        'createdAt: $createdAt)';
  }
}
