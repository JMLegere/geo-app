import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/models/animal_class.dart';
import 'package:earth_nova/core/models/climate.dart';
import 'package:earth_nova/core/models/food_type.dart';
import 'package:earth_nova/core/models/species_enrichment.dart';
import 'package:earth_nova/core/persistence/enrichment_repository.dart';

import 'test_helpers.dart';

SpeciesEnrichment makeEnrichment({
  String definitionId = 'fauna_vulpes_vulpes',
  AnimalClass animalClass = AnimalClass.carnivore,
  FoodType foodPreference = FoodType.critter,
  Climate climate = Climate.temperate,
  int brawn = 30,
  int wit = 40,
  int speed = 20,
  String? artUrl,
}) =>
    SpeciesEnrichment(
      definitionId: definitionId,
      animalClass: animalClass,
      foodPreference: foodPreference,
      climate: climate,
      brawn: brawn,
      wit: wit,
      speed: speed,
      artUrl: artUrl,
      enrichedAt: DateTime(2026, 3, 7, 12),
    );

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('EnrichmentRepository', () {
    late EnrichmentRepository repo;

    setUp(() {
      repo = EnrichmentRepository(createTestDatabase());
    });

    test('getEnrichment returns null for unknown definitionId', () async {
      final result = await repo.getEnrichment('fauna_unknown');
      expect(result, isNull);
    });

    test('upsertEnrichment inserts and getEnrichment retrieves', () async {
      final e = makeEnrichment();
      await repo.upsertEnrichment(e);
      final result = await repo.getEnrichment(e.definitionId);
      expect(result, isNotNull);
      expect(result!.definitionId, e.definitionId);
      expect(result.animalClass, AnimalClass.carnivore);
      expect(result.foodPreference, FoodType.critter);
      expect(result.climate, Climate.temperate);
      expect(result.brawn, 30);
      expect(result.wit, 40);
      expect(result.speed, 20);
    });

    test('upsertEnrichment updates existing row (upsert semantics)', () async {
      await repo.upsertEnrichment(makeEnrichment(brawn: 30, wit: 40, speed: 20));
      await repo.upsertEnrichment(makeEnrichment(brawn: 50, wit: 25, speed: 15));

      final result = await repo.getEnrichment('fauna_vulpes_vulpes');
      expect(result, isNotNull);
      expect(result!.brawn, 50);
      expect(result.wit, 25);
      expect(result.speed, 15);
    });

    test('getAllEnrichments returns all rows', () async {
      await repo.upsertEnrichment(makeEnrichment(definitionId: 'fauna_a', brawn: 30, wit: 30, speed: 30));
      await repo.upsertEnrichment(makeEnrichment(definitionId: 'fauna_b', brawn: 20, wit: 40, speed: 30));
      await repo.upsertEnrichment(makeEnrichment(definitionId: 'fauna_c', brawn: 40, wit: 30, speed: 20));

      final all = await repo.getAllEnrichments();
      expect(all.length, 3);
    });

    test('upsertAll inserts multiple enrichments atomically', () async {
      final enrichments = [
        makeEnrichment(definitionId: 'fauna_a', brawn: 30, wit: 30, speed: 30),
        makeEnrichment(definitionId: 'fauna_b', brawn: 20, wit: 40, speed: 30),
        makeEnrichment(definitionId: 'fauna_c', brawn: 40, wit: 30, speed: 20),
      ];
      await repo.upsertAll(enrichments);

      final all = await repo.getAllEnrichments();
      expect(all.length, 3);
      final ids = all.map((e) => e.definitionId).toSet();
      expect(ids, containsAll(['fauna_a', 'fauna_b', 'fauna_c']));
    });

    test('getEnrichmentsSince returns only newer rows', () async {
      final cutoff = DateTime(2026, 3, 1);

      final old = SpeciesEnrichment(
        definitionId: 'fauna_old',
        animalClass: AnimalClass.carnivore,
        foodPreference: FoodType.critter,
        climate: Climate.temperate,
        brawn: 30,
        wit: 30,
        speed: 30,
        enrichedAt: DateTime(2026, 2, 1),
      );
      final fresh = SpeciesEnrichment(
        definitionId: 'fauna_fresh',
        animalClass: AnimalClass.rodent,
        foodPreference: FoodType.grub,
        climate: Climate.boreal,
        brawn: 20,
        wit: 50,
        speed: 20,
        enrichedAt: DateTime(2026, 3, 7),
      );

      await repo.upsertEnrichment(old);
      await repo.upsertEnrichment(fresh);

      final results = await repo.getEnrichmentsSince(cutoff);
      expect(results.length, 1);
      expect(results.first.definitionId, 'fauna_fresh');
    });

    test('artUrl is persisted correctly (null and non-null)', () async {
      await repo.upsertEnrichment(makeEnrichment(artUrl: 'https://example.com/fox.png'));
      final result = await repo.getEnrichment('fauna_vulpes_vulpes');
      expect(result!.artUrl, 'https://example.com/fox.png');

      await repo.upsertEnrichment(makeEnrichment(artUrl: null));
      final updated = await repo.getEnrichment('fauna_vulpes_vulpes');
      expect(updated!.artUrl, isNull);
    });
  });
}
