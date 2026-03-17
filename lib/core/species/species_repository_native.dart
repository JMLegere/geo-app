import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:earth_nova/core/models/continent.dart';
import 'package:earth_nova/core/models/habitat.dart';
import 'package:earth_nova/core/models/item_definition.dart';
import 'package:earth_nova/core/species/species_repository.dart';

Future<SpeciesRepository> createRepository() async {
  final data = await rootBundle.load('assets/species.db');
  final bytes = data.buffer.asUint8List();
  final tempFile = File('${Directory.systemTemp.path}/earth_nova_species.db');
  await tempFile.writeAsBytes(bytes, flush: true);
  final db = sqlite3.open(tempFile.path, mode: OpenMode.readOnly);
  return NativeSpeciesRepository(db);
}

/// SQLite-backed species repository using sqlite3 FFI.
///
/// The DB schema (created by tool/compile_species_db.dart):
/// ```sql
/// CREATE TABLE species_definitions (
///   scientific_name  TEXT PRIMARY KEY,
///   common_name      TEXT NOT NULL,
///   taxonomic_class  TEXT NOT NULL,
///   iucn_status      TEXT NOT NULL,
///   habitats_json    TEXT NOT NULL,   -- e.g. '["Forest","Mountain"]'
///   continents_json  TEXT NOT NULL    -- e.g. '["North America"]'
/// )
/// ```
class NativeSpeciesRepository implements SpeciesRepository {
  final Database _db;

  /// Creates a [NativeSpeciesRepository] wrapping an already-opened sqlite3 [Database].
  ///
  /// The repository takes ownership of [db] — call [dispose] when done.
  NativeSpeciesRepository(this._db);

  // ── Query methods ─────────────────────────────────────────────────────────

  /// Returns species matching ANY of [habitats] AND the given [continent].
  ///
  /// Builds an OR clause for habitats, ANDed with the continent filter.
  /// Silently skips rows with unrecognised habitat/continent/IUCN values.
  /// Returns an empty list if [habitats] is empty.
  @override
  Future<List<FaunaDefinition>> getCandidates({
    required Set<Habitat> habitats,
    required Continent continent,
  }) async {
    if (habitats.isEmpty) return const [];

    // Each habitat becomes: habitats_json LIKE '%"Forest"%'
    // The JSON array uses quoted strings, so we match the exact quoted token
    // to avoid false positives (e.g. "Forest" ≠ "Rainforest").
    final habitatClauses =
        List.filled(habitats.length, 'habitats_json LIKE ?').join(' OR ');

    final sql = '''
      SELECT * FROM species_definitions
      WHERE ($habitatClauses)
        AND continents_json LIKE ?
    ''';

    final params = [
      ...habitats.map((h) => '%"${h.displayName}"%'),
      '%"${continent.displayName}"%',
    ];

    final rows = _db.select(sql, params);
    return _parseRows(rows);
  }

  /// Returns a single [FaunaDefinition] by scientific name, or null if missing.
  @override
  Future<FaunaDefinition?> getByScientificName(String name) async {
    final rows = _db.select(
      'SELECT * FROM species_definitions WHERE scientific_name = ?',
      [name],
    );
    if (rows.isEmpty) return null;
    try {
      return _parseRow(rows.first);
    } on ArgumentError {
      return null;
    }
  }

  /// Returns the total count of rows in the database.
  @override
  Future<int> count() async {
    final rows = _db.select('SELECT COUNT(*) as c FROM species_definitions');
    return rows.first['c'] as int;
  }

  /// Loads ALL species — fallback for web or when on-demand isn't needed.
  @override
  Future<List<FaunaDefinition>> getAll() async {
    final rows = _db.select('SELECT * FROM species_definitions');
    return _parseRows(rows);
  }

  /// Releases the underlying database connection.
  @override
  void dispose() => _db.dispose();

  // ── Parsing ───────────────────────────────────────────────────────────────

  List<FaunaDefinition> _parseRows(ResultSet rows) {
    final result = <FaunaDefinition>[];
    for (final row in rows) {
      try {
        result.add(_parseRow(row));
      } on ArgumentError {
        // Skip rows with unrecognised habitat, continent, or IUCN status.
        // Mirrors SpeciesDataLoader.fromJsonString() silent-skip behaviour.
      }
    }
    return result;
  }

  /// Maps a DB row to a [FaunaDefinition] via [FaunaDefinition.fromJson].
  ///
  /// Column → JSON key mapping:
  /// - scientific_name → scientificName
  /// - common_name     → commonName
  /// - taxonomic_class → taxonomicClass
  /// - iucn_status     → iucnStatus
  /// - habitats_json   → habitats (decoded list of strings)
  /// - continents_json → continents (decoded list of strings)
  FaunaDefinition _parseRow(Row row) {
    final habitats =
        (jsonDecode(row['habitats_json'] as String) as List).cast<String>();
    final continents =
        (jsonDecode(row['continents_json'] as String) as List).cast<String>();

    return FaunaDefinition.fromJson({
      'scientificName': row['scientific_name'] as String,
      'commonName': row['common_name'] as String,
      'taxonomicClass': row['taxonomic_class'] as String,
      'iucnStatus': row['iucn_status'] as String,
      'habitats': habitats,
      'continents': continents,
    });
  }
}
