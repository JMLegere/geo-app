import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:earth_nova/core/database/app_database.dart';
import 'package:earth_nova/core/models/continent.dart';
import 'package:earth_nova/core/models/habitat.dart';
import 'package:earth_nova/core/species/drift_species_repository.dart';
import 'package:earth_nova/core/species/species_cache.dart';
import 'package:earth_nova/core/species/species_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Opens a DriftSpeciesRepository seeded from assets/species_data.json.
///
/// Tests run from the project root (flutter test), so the relative path works.
Future<(SpeciesRepository, AppDatabase)> openRealDb() async {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final db = AppDatabase(NativeDatabase.memory());
  final jsonStr = File('assets/species_data.json').readAsStringSync();
  final data = jsonDecode(jsonStr) as List;
  await db.batch((b) {
    for (final item in data) {
      final m = item as Map<String, dynamic>;
      final sciName = m['scientificName'] as String;
      final defId = 'fauna_${sciName.toLowerCase().replaceAll(' ', '_')}';
      b.insert(
        db.localSpeciesTable,
        LocalSpeciesTableCompanion.insert(
          definitionId: defId,
          scientificName: sciName,
          commonName: m['commonName'] as String,
          taxonomicClass: m['taxonomicClass'] as String,
          iucnStatus: m['iucnStatus'] as String,
          habitatsJson: jsonEncode(m['habitats']),
          continentsJson: jsonEncode(m['continents']),
        ),
      );
    }
  });
  return (DriftSpeciesRepository(db), db);
}

void main() {
  group('SpeciesRepository', () {
    late SpeciesRepository repo;
    late AppDatabase db;

    setUp(() async {
      (repo, db) = await openRealDb();
    });

    tearDown(() async {
      repo.dispose();
      await db.close();
    });

    // ── count() ─────────────────────────────────────────────────────────────

    test('count() returns 32752', () async {
      final n = await repo.count();
      expect(n, equals(32752));
    });

    // ── getCandidates() ─────────────────────────────────────────────────────

    test('getCandidates returns non-empty list for forest+northAmerica',
        () async {
      final results = await repo.getCandidates(
        habitats: {Habitat.forest},
        continent: Continent.northAmerica,
      );
      expect(results, isNotEmpty);
    });

    test('getCandidates returns only species with matching habitat', () async {
      final results = await repo.getCandidates(
        habitats: {Habitat.forest},
        continent: Continent.northAmerica,
      );
      // Every returned species must have Forest in its habitat list
      for (final species in results) {
        expect(species.habitats, contains(Habitat.forest),
            reason: '${species.scientificName} missing Forest habitat');
      }
    });

    test('getCandidates returns only species with matching continent',
        () async {
      final results = await repo.getCandidates(
        habitats: {Habitat.forest},
        continent: Continent.northAmerica,
      );
      for (final species in results) {
        expect(species.continents, contains(Continent.northAmerica),
            reason: '${species.scientificName} missing NorthAmerica continent');
      }
    });

    test('getCandidates with multiple habitats returns union', () async {
      final forestOnly = await repo.getCandidates(
        habitats: {Habitat.forest},
        continent: Continent.asia,
      );
      final mountainOnly = await repo.getCandidates(
        habitats: {Habitat.mountain},
        continent: Continent.asia,
      );
      final combined = await repo.getCandidates(
        habitats: {Habitat.forest, Habitat.mountain},
        continent: Continent.asia,
      );

      // Combined must have at least as many as either set alone
      expect(combined.length, greaterThanOrEqualTo(forestOnly.length));
      expect(combined.length, greaterThanOrEqualTo(mountainOnly.length));
    });

    test('getCandidates with empty habitat set returns empty list', () async {
      final results = await repo.getCandidates(
        habitats: {},
        continent: Continent.northAmerica,
      );
      expect(results, isEmpty);
    });

    test('getCandidates returns valid FaunaDefinitions', () async {
      final results = await repo.getCandidates(
        habitats: {Habitat.freshwater},
        continent: Continent.europe,
      );
      expect(results, isNotEmpty);
      for (final f in results.take(5)) {
        expect(f.id, startsWith('fauna_'));
        expect(f.displayName, isNotEmpty);
        expect(f.scientificName, isNotEmpty);
        expect(f.rarity, isNotNull);
        expect(f.habitats, isNotEmpty);
        expect(f.continents, isNotEmpty);
      }
    });

    // ── getByScientificName() ────────────────────────────────────────────────

    test('getByScientificName returns known species', () async {
      // "Acris crepitans" is in the DB (Northern Cricket Frog, NA, Forest)
      final result = await repo.getByScientificName('Acris crepitans');
      expect(result, isNotNull);
      expect(result!.scientificName, equals('Acris crepitans'));
      expect(result.displayName, isNotEmpty);
      expect(result.rarity, isNotNull);
    });

    test('getByScientificName returns null for unknown species', () async {
      final result =
          await repo.getByScientificName('Definitely notareal species');
      expect(result, isNull);
    });

    // ── getAll() ─────────────────────────────────────────────────────────────

    test(
        'getAll returns a large number of species (silently skips unparseable rows)',
        () async {
      final all = await repo.getAll();
      // The DB has 32752 raw rows; some have unrecognised habitats/continents
      // and are silently skipped (same behaviour as SpeciesDataLoader).
      expect(all.length, greaterThan(28000));
    });
  });

  // ── SpeciesCache ──────────────────────────────────────────────────────────

  group('SpeciesCache', () {
    late SpeciesRepository repo;
    late AppDatabase db;
    late SpeciesCache cache;

    setUp(() async {
      (repo, db) = await openRealDb();
      cache = SpeciesCache(repo);
    });

    tearDown(() async {
      cache.clear();
      repo.dispose();
      await db.close();
    });

    test('getCandidatesSync returns empty list before warmUp', () {
      final results = cache.getCandidatesSync(
        habitats: {Habitat.forest},
        continent: Continent.northAmerica,
      );
      expect(results, isEmpty);
    });

    test('warmUp + getCandidatesSync round-trip returns candidates', () async {
      await cache.warmUp(
        habitats: {Habitat.forest},
        continent: Continent.northAmerica,
      );
      final results = cache.getCandidatesSync(
        habitats: {Habitat.forest},
        continent: Continent.northAmerica,
      );
      expect(results, isNotEmpty);
      for (final f in results.take(3)) {
        expect(f.habitats, contains(Habitat.forest));
        expect(f.continents, contains(Continent.northAmerica));
      }
    });

    test('warmUp is idempotent — second call is a no-op', () async {
      await cache.warmUp(
        habitats: {Habitat.desert},
        continent: Continent.africa,
      );
      final first = cache.getCandidatesSync(
        habitats: {Habitat.desert},
        continent: Continent.africa,
      );
      // Warm again — should not change the result
      await cache.warmUp(
        habitats: {Habitat.desert},
        continent: Continent.africa,
      );
      final second = cache.getCandidatesSync(
        habitats: {Habitat.desert},
        continent: Continent.africa,
      );
      expect(second.length, equals(first.length));
    });

    test('clear() removes cached candidates', () async {
      await cache.warmUp(
        habitats: {Habitat.forest},
        continent: Continent.europe,
      );
      cache.clear();
      final results = cache.getCandidatesSync(
        habitats: {Habitat.forest},
        continent: Continent.europe,
      );
      expect(results, isEmpty);
    });

    test('totalSpeciesCount returns 0 before loadTotalCount', () {
      expect(cache.totalSpeciesCount, equals(0));
    });

    test('loadTotalCount caches correct count', () async {
      await cache.loadTotalCount();
      expect(cache.totalSpeciesCount, equals(32752));
    });
  });

  // ── SpeciesCache.empty() ─────────────────────────────────────────────────

  group('SpeciesCache.empty', () {
    test('getCandidatesSync returns empty list', () {
      final empty = SpeciesCache.empty();
      expect(
        empty.getCandidatesSync(
          habitats: {Habitat.forest},
          continent: Continent.asia,
        ),
        isEmpty,
      );
    });

    test('warmUp is a no-op and does not throw', () async {
      final empty = SpeciesCache.empty();
      await expectLater(
        empty.warmUp(
          habitats: {Habitat.forest},
          continent: Continent.asia,
        ),
        completes,
      );
    });

    test('totalSpeciesCount is 0', () {
      expect(SpeciesCache.empty().totalSpeciesCount, equals(0));
    });
  });
}
