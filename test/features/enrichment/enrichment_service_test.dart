import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fog_of_world/core/database/app_database.dart';
import 'package:fog_of_world/core/models/animal_class.dart';
import 'package:fog_of_world/core/models/climate.dart';
import 'package:fog_of_world/core/models/food_type.dart';
import 'package:fog_of_world/core/models/species_enrichment.dart';
import 'package:fog_of_world/core/persistence/enrichment_repository.dart';
import 'package:fog_of_world/features/sync/services/enrichment_service.dart';

AppDatabase makeInMemoryDb() => AppDatabase(NativeDatabase.memory());

SpeciesEnrichment makeEnrichment({
  String definitionId = 'fauna_vulpes_vulpes',
  AnimalClass animalClass = AnimalClass.carnivore,
  FoodType foodPreference = FoodType.critter,
  Climate climate = Climate.temperate,
  int brawn = 30,
  int wit = 40,
  int speed = 20,
}) =>
    SpeciesEnrichment(
      definitionId: definitionId,
      animalClass: animalClass,
      foodPreference: foodPreference,
      climate: climate,
      brawn: brawn,
      wit: wit,
      speed: speed,
      enrichedAt: DateTime(2026, 3, 7),
    );

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('EnrichmentService (offline — no Supabase client)', () {
    late EnrichmentService service;
    late EnrichmentRepository repo;

    setUp(() {
      repo = EnrichmentRepository(makeInMemoryDb());
      service = EnrichmentService(repository: repo, supabaseClient: null);
    });

    test('requestEnrichment is a no-op when supabaseClient is null', () async {
      await service.requestEnrichment(
        definitionId: 'fauna_vulpes_vulpes',
        scientificName: 'Vulpes vulpes',
        commonName: 'Red Fox',
        taxonomicClass: 'Mammalia',
      );
      final map = await service.getEnrichmentMap();
      expect(map, isEmpty);
    });

    test('syncEnrichments returns 0 when supabaseClient is null', () async {
      final count = await service.syncEnrichments();
      expect(count, 0);
    });

    test('getEnrichmentMap returns empty map when no enrichments cached', () async {
      final map = await service.getEnrichmentMap();
      expect(map, isEmpty);
    });

    test('getEnrichmentMap returns enrichments seeded directly into repo', () async {
      await repo.upsertEnrichment(makeEnrichment(definitionId: 'fauna_a', brawn: 30, wit: 30, speed: 30));
      await repo.upsertEnrichment(makeEnrichment(definitionId: 'fauna_b', brawn: 20, wit: 40, speed: 30));

      final map = await service.getEnrichmentMap();
      expect(map.keys, containsAll(['fauna_a', 'fauna_b']));
      expect(map['fauna_a']!.animalClass, AnimalClass.carnivore);
    });
  });

  group('EnrichmentService — merge logic via getEnrichmentMap', () {
    late EnrichmentService service;
    late EnrichmentRepository repo;

    setUp(() {
      repo = EnrichmentRepository(makeInMemoryDb());
      service = EnrichmentService(repository: repo, supabaseClient: null);
    });

    test('getEnrichmentMap keys by definitionId', () async {
      final enrichments = [
        makeEnrichment(definitionId: 'fauna_a', brawn: 30, wit: 30, speed: 30),
        makeEnrichment(definitionId: 'fauna_b', brawn: 40, wit: 30, speed: 20),
        makeEnrichment(definitionId: 'fauna_c', brawn: 20, wit: 50, speed: 20),
      ];
      await repo.upsertAll(enrichments);

      final map = await service.getEnrichmentMap();
      expect(map.length, 3);
      for (final e in enrichments) {
        expect(map.containsKey(e.definitionId), isTrue);
        expect(map[e.definitionId]!.definitionId, e.definitionId);
      }
    });

    test('getEnrichmentMap reflects latest upserted values', () async {
      await repo.upsertEnrichment(makeEnrichment(brawn: 30, wit: 40, speed: 20));
      var map = await service.getEnrichmentMap();
      expect(map['fauna_vulpes_vulpes']!.brawn, 30);

      await repo.upsertEnrichment(makeEnrichment(brawn: 50, wit: 25, speed: 15));
      map = await service.getEnrichmentMap();
      expect(map['fauna_vulpes_vulpes']!.brawn, 50);
    });
  });
}
