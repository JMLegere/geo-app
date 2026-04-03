import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:earth_nova/data/database.dart';
import 'package:earth_nova/data/repos/species_repo.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late SpeciesRepo repo;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = SpeciesRepo(db);

    // Insert test species
    await db.into(db.speciesTable).insert(SpeciesTableCompanion.insert(
          definitionId: 'fauna_vulpes_vulpes',
          scientificName: 'Vulpes vulpes',
          commonName: 'Red Fox',
          taxonomicClass: 'Mammalia',
          iucnStatus: 'Least Concern',
          habitatsJson: '["forest","plains"]',
          continentsJson: '["europe","asia"]',
        ));

    await db.into(db.speciesTable).insert(SpeciesTableCompanion.insert(
          definitionId: 'fauna_ursus_arctos',
          scientificName: 'Ursus arctos',
          commonName: 'Brown Bear',
          taxonomicClass: 'Mammalia',
          iucnStatus: 'Least Concern',
          habitatsJson: '["forest","mountain"]',
          continentsJson: '["europe","northAmerica"]',
        ));

    await db.into(db.speciesTable).insert(SpeciesTableCompanion.insert(
          definitionId: 'fauna_salmo_salar',
          scientificName: 'Salmo salar',
          commonName: 'Atlantic Salmon',
          taxonomicClass: 'Actinopterygii',
          iucnStatus: 'Least Concern',
          habitatsJson: '["freshwater","saltwater"]',
          continentsJson: '["europe","northAmerica"]',
        ));
  });

  tearDown(() => db.close());

  group('SpeciesRepo', () {
    test('getById returns species by definitionId', () async {
      final result = await repo.getById('fauna_vulpes_vulpes');
      expect(result, isNotNull);
      expect(result!.commonName, 'Red Fox');
    });

    test('getById returns null for unknown ID', () async {
      final result = await repo.getById('fauna_unknown');
      expect(result, isNull);
    });

    test('getAll returns all species', () async {
      final all = await repo.getAll();
      expect(all.length, 3);
    });

    test('count returns correct count', () async {
      final n = await repo.count();
      expect(n, 3);
    });

    test('getCandidates filters by habitat — forest returns fox and bear',
        () async {
      final results = await repo.getCandidates(
        habitats: ['forest'],
        continent: 'europe',
      );
      final ids = results.map((s) => s.definitionId).toSet();
      expect(ids, containsAll(['fauna_vulpes_vulpes', 'fauna_ursus_arctos']));
      expect(ids, isNot(contains('fauna_salmo_salar')));
    });

    test('getCandidates filters by continent — northAmerica excludes fox',
        () async {
      final results = await repo.getCandidates(
        habitats: ['forest'],
        continent: 'northAmerica',
      );
      final ids = results.map((s) => s.definitionId).toSet();
      expect(ids, contains('fauna_ursus_arctos'));
      expect(ids, isNot(contains('fauna_salmo_salar')));
    });

    test('getCandidates returns empty for non-matching criteria', () async {
      final results = await repo.getCandidates(
        habitats: ['desert'],
        continent: 'oceania',
      );
      expect(results, isEmpty);
    });

    test('getCandidates handles multiple habitats in JSON array', () async {
      // Salmon matches freshwater; asking for [freshwater, forest] should return it
      final results = await repo.getCandidates(
        habitats: ['freshwater', 'forest'],
        continent: 'europe',
      );
      final ids = results.map((s) => s.definitionId).toSet();
      expect(
          ids,
          containsAll([
            'fauna_vulpes_vulpes',
            'fauna_ursus_arctos',
            'fauna_salmo_salar',
          ]));
    });

    test('getCandidates requires both habitat AND continent match', () async {
      // Salmon is in freshwater but NOT in asia
      final results = await repo.getCandidates(
        habitats: ['freshwater'],
        continent: 'asia',
      );
      expect(results, isEmpty);
    });
  });
}
