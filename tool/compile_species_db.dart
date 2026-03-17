// tool/compile_species_db.dart
//
// BUILD TOOL — runs on developer machine, not on device.
// Compiles assets/species_data.json → assets/species.db (SQLite).
//
// Usage:
//   dart run tool/compile_species_db.dart

import 'dart:convert';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

void main() {
  final stopwatch = Stopwatch()..start();

  // Paths relative to project root (run from project root)
  final jsonFile = File('assets/species_data.json');
  final dbFile = File('assets/species.db');

  if (!jsonFile.existsSync()) {
    stderr.writeln('ERROR: assets/species_data.json not found.');
    stderr.writeln('Run this script from the project root directory.');
    exit(1);
  }

  // ── 1. Read JSON ──────────────────────────────────────────────────────────
  stdout.writeln('Reading ${jsonFile.path}...');
  final jsonBytes = jsonFile.readAsBytesSync();
  final List<dynamic> records =
      jsonDecode(utf8.decode(jsonBytes)) as List<dynamic>;
  stdout.writeln(
      '  ${records.length} records loaded (${(jsonBytes.length / 1024 / 1024).toStringAsFixed(1)} MB)');

  // ── 2. Delete existing DB ─────────────────────────────────────────────────
  if (dbFile.existsSync()) {
    dbFile.deleteSync();
    stdout.writeln('Deleted existing ${dbFile.path}');
  }

  // ── 3. Open SQLite ────────────────────────────────────────────────────────
  stdout.writeln('Creating ${dbFile.path}...');
  final db = sqlite3.open(dbFile.path);

  try {
    // Tune for bulk insert performance
    db.execute('PRAGMA journal_mode = WAL;');
    db.execute('PRAGMA synchronous = NORMAL;');
    db.execute('PRAGMA temp_store = MEMORY;');
    db.execute('PRAGMA cache_size = -64000;'); // 64 MB cache

    // ── 4. Create table ───────────────────────────────────────────────────
    db.execute('''
      CREATE TABLE species_definitions (
        scientific_name  TEXT PRIMARY KEY,
        common_name      TEXT NOT NULL,
        taxonomic_class  TEXT NOT NULL,
        iucn_status      TEXT NOT NULL,
        habitats_json    TEXT NOT NULL,
        continents_json  TEXT NOT NULL
      )
    ''');

    // ── 5. Bulk insert in a single transaction ────────────────────────────
    stdout.writeln('Inserting records...');
    final stmt = db.prepare('''
      INSERT OR IGNORE INTO species_definitions
        (scientific_name, common_name, taxonomic_class, iucn_status, habitats_json, continents_json)
      VALUES (?, ?, ?, ?, ?, ?)
    ''');

    db.execute('BEGIN');
    int inserted = 0;
    int skipped = 0;

    for (final raw in records) {
      final rec = raw as Map<String, dynamic>;

      final scientificName = rec['scientificName'] as String?;
      final commonName = rec['commonName'] as String?;
      final taxonomicClass = rec['taxonomicClass'] as String?;
      final iucnStatus = rec['iucnStatus'] as String?;
      final habitats = rec['habitats'];
      final continents = rec['continents'];

      if (scientificName == null ||
          commonName == null ||
          taxonomicClass == null ||
          iucnStatus == null ||
          habitats == null ||
          continents == null) {
        skipped++;
        continue;
      }

      stmt.execute([
        scientificName,
        commonName,
        taxonomicClass,
        iucnStatus,
        jsonEncode(habitats),
        jsonEncode(continents),
      ]);
      inserted++;
    }

    db.execute('COMMIT');
    stmt.dispose();

    // ── 6. Indexes ────────────────────────────────────────────────────────
    stdout.writeln('Creating indexes...');
    db.execute(
        'CREATE INDEX idx_species_iucn ON species_definitions(iucn_status)');
    db.execute(
        'CREATE INDEX idx_species_class ON species_definitions(taxonomic_class)');

    // Vacuum to compact
    db.execute('ANALYZE');

    // ── 7. Summary ────────────────────────────────────────────────────────
    final rowCount = (db
        .select('SELECT COUNT(*) as c FROM species_definitions')
        .first['c'] as int);
    stopwatch.stop();
    final dbSize = dbFile.lengthSync();

    stdout.writeln('');
    stdout.writeln('✅ Done!');
    stdout.writeln('   Rows inserted : $inserted');
    if (skipped > 0)
      stdout.writeln('   Rows skipped  : $skipped (missing fields)');
    stdout.writeln('   DB row count  : $rowCount');
    stdout.writeln(
        '   DB file size  : ${(dbSize / 1024 / 1024).toStringAsFixed(2)} MB  (${dbFile.path})');
    stdout.writeln('   Elapsed       : ${stopwatch.elapsedMilliseconds} ms');
  } catch (e) {
    db.execute('ROLLBACK');
    db.dispose();
    stderr.writeln('ERROR: $e');
    // Clean up partial DB
    if (dbFile.existsSync()) dbFile.deleteSync();
    exit(1);
  }

  db.dispose();
}
