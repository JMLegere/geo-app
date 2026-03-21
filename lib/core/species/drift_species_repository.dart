import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:earth_nova/core/database/app_database.dart';
import 'package:earth_nova/core/models/animal_class.dart';
import 'package:earth_nova/core/models/climate.dart';
import 'package:earth_nova/core/models/continent.dart';
import 'package:earth_nova/core/models/food_type.dart';
import 'package:earth_nova/core/models/habitat.dart';
import 'package:earth_nova/core/models/item_definition.dart';
import 'package:earth_nova/core/models/iucn_status.dart';
import 'package:earth_nova/core/species/species_repository.dart';

/// Species repository backed by [AppDatabase.localSpeciesTable] (Drift).
///
/// Replaces [NativeSpeciesRepository] which opened a separate `species.db`
/// SQLite file. This implementation queries the same database as the rest
/// of the app, enabling JOINs and unified schema management.
class DriftSpeciesRepository implements SpeciesRepository {
  final AppDatabase _db;

  DriftSpeciesRepository(this._db);

  @override
  Future<List<FaunaDefinition>> getCandidates({
    required Set<Habitat> habitats,
    required Continent continent,
  }) async {
    if (habitats.isEmpty) return const [];

    final habitatClauses =
        List.filled(habitats.length, 'habitats_json LIKE ?').join(' OR ');

    final sql = '''
      SELECT * FROM local_species_table
      WHERE ($habitatClauses)
        AND continents_json LIKE ?
    ''';

    final params = <Variable>[
      ...habitats.map((h) => Variable.withString('%"${h.displayName}"%')),
      Variable.withString('%"${continent.displayName}"%'),
    ];

    final rows = await _db.customSelect(sql, variables: params).get();
    return _parseRows(rows);
  }

  @override
  Future<FaunaDefinition?> getByScientificName(String name) async {
    final row = await (_db.select(_db.localSpeciesTable)
          ..where((t) => t.scientificName.equals(name)))
        .getSingleOrNull();
    if (row == null) return null;
    try {
      return FaunaDefinition.fromDrift(row);
    } on ArgumentError {
      return null;
    }
  }

  @override
  Future<List<FaunaDefinition>> getByIds(List<String> ids) async {
    if (ids.isEmpty) return const [];
    // SQLite has a variable limit (~999), batch if needed.
    final results = <FaunaDefinition>[];
    const batchSize = 500;
    for (var i = 0; i < ids.length; i += batchSize) {
      final batch = ids.sublist(
          i, i + batchSize > ids.length ? ids.length : i + batchSize);
      final rows = await (_db.select(_db.localSpeciesTable)
            ..where((t) => t.definitionId.isIn(batch)))
          .get();
      for (final row in rows) {
        try {
          results.add(FaunaDefinition.fromDrift(row));
        } on ArgumentError {
          // skip unparseable
        }
      }
    }
    return results;
  }

  @override
  Future<int> count() async {
    final result = await _db.localSpeciesTable.count().getSingle();
    return result;
  }

  @override
  Future<List<FaunaDefinition>> getAll() async {
    final rows = await _db.select(_db.localSpeciesTable).get();
    return rows
        .map((r) {
          try {
            return FaunaDefinition.fromDrift(r);
          } on ArgumentError {
            return null;
          }
        })
        .whereType<FaunaDefinition>()
        .toList();
  }

  @override
  void dispose() {
    // No-op — AppDatabase lifecycle managed by appDatabaseProvider
  }

  // -- Parsing ----------------------------------------------------------------

  List<FaunaDefinition> _parseRows(List<QueryRow> rows) {
    final result = <FaunaDefinition>[];
    for (final row in rows) {
      try {
        result.add(_parseQueryRow(row));
      } on ArgumentError {
        // Skip rows with unrecognised habitat, continent, or IUCN status
      }
    }
    return result;
  }

  FaunaDefinition _parseQueryRow(QueryRow row) {
    final habitats =
        (jsonDecode(row.read<String>('habitats_json')) as List).cast<String>();
    final continents = (jsonDecode(row.read<String>('continents_json')) as List)
        .cast<String>();

    return FaunaDefinition(
      id: row.read<String>('definition_id'),
      displayName: row.read<String>('common_name'),
      scientificName: row.read<String>('scientific_name'),
      taxonomicClass: row.read<String>('taxonomic_class'),
      rarity: IucnStatus.fromIucnString(row.read<String>('iucn_status')),
      habitats:
          habitats.map((h) => Habitat.fromString(h.toLowerCase())).toList(),
      continents: continents.map((c) => Continent.fromDataString(c)).toList(),
      animalClass: row.readNullable<String>('animal_class') != null
          ? AnimalClass.fromString(row.read<String>('animal_class'))
          : null,
      foodPreference: row.readNullable<String>('food_preference') != null
          ? FoodType.fromString(row.read<String>('food_preference'))
          : null,
      climate: row.readNullable<String>('climate') != null
          ? Climate.fromString(row.read<String>('climate'))
          : null,
      iconUrl: row.readNullable<String>('icon_url'),
      artUrl: row.readNullable<String>('art_url'),
      brawn: row.readNullable<int>('brawn'),
      wit: row.readNullable<int>('wit'),
      speed: row.readNullable<int>('speed'),
      size: row.readNullable<String>('size'),
      enrichedAt: row.readNullable<DateTime>('enriched_at'),
    );
  }
}
