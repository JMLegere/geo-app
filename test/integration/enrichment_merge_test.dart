import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fog_of_world/core/database/app_database.dart';
import 'package:fog_of_world/core/models/animal_class.dart';
import 'package:fog_of_world/core/models/climate.dart';
import 'package:fog_of_world/core/models/food_type.dart';
import 'package:fog_of_world/core/models/item_definition.dart';
import 'package:fog_of_world/core/models/species_enrichment.dart';
import 'package:fog_of_world/core/persistence/enrichment_repository.dart';
import 'package:fog_of_world/core/species/species_service.dart';
import 'package:fog_of_world/features/sync/services/enrichment_service.dart';

import '../fixtures/species_fixture.dart';

AppDatabase makeInMemoryDb() => AppDatabase(NativeDatabase.memory());

List<FaunaDefinition> loadFixtureSpecies() {
  final List<dynamic> raw = jsonDecode(kSpeciesFixtureJson) as List<dynamic>;
  return raw
      .map((j) => FaunaDefinition.fromJson(j as Map<String, dynamic>))
      .toList();
}

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('Enrichment pipeline — merge into SpeciesService', () {
    test('unenriched fauna definitions have null animalClass/foodPreference/climate', () {
      final species = loadFixtureSpecies();
      expect(species, isNotEmpty);

      for (final def in species) {
        expect(def.animalClass, isNull,
            reason: '${def.id} should have null animalClass before enrichment');
      }
    });

    test('enrichment merge correctly populates FaunaDefinition fields', () {
      final species = loadFixtureSpecies();
      final first = species.first;

      final enrichment = SpeciesEnrichment(
        definitionId: first.id,
        animalClass: AnimalClass.carnivore,
        foodPreference: FoodType.critter,
        climate: Climate.temperate,
        brawn: 30,
        wit: 40,
        speed: 20,
        enrichedAt: DateTime(2026, 3, 7),
      );

      final enrichmentMap = {enrichment.definitionId: enrichment};

      final enriched = species.map((def) {
        final e = enrichmentMap[def.id];
        if (e != null) {
          return FaunaDefinition(
            id: def.id,
            displayName: def.displayName,
            scientificName: def.scientificName,
            taxonomicClass: def.taxonomicClass,
            rarity: def.rarity!,
            habitats: def.habitats,
            continents: def.continents,
            seasonRestriction: def.seasonRestriction,
            contextTags: def.contextTags,
            animalClass: e.animalClass,
            foodPreference: e.foodPreference,
            climate: e.climate,
          );
        }
        return def;
      }).toList();

      final enrichedDef = enriched.firstWhere((d) => d.id == first.id);
      expect(enrichedDef.animalClass, AnimalClass.carnivore);
      expect(enrichedDef.foodPreference, FoodType.critter);
      expect(enrichedDef.climate, Climate.temperate);

      final unenriched = enriched.where((d) => d.id != first.id).toList();
      for (final def in unenriched) {
        expect(def.animalClass, isNull);
      }
    });

    test('partial enrichment: only some species enriched', () {
      final species = loadFixtureSpecies();
      expect(species.length, greaterThan(5));

      final toEnrich = species.take(3).toList();
      final enrichmentMap = <String, SpeciesEnrichment>{};
      for (final (i, def) in toEnrich.indexed) {
        enrichmentMap[def.id] = SpeciesEnrichment(
          definitionId: def.id,
          animalClass: AnimalClass.values[i],
          foodPreference: FoodType.values[i % FoodType.values.length],
          climate: Climate.values[i % Climate.values.length],
          brawn: 30 + i,
          wit: 30 + i,
          speed: 30 - i * 2,
          enrichedAt: DateTime(2026, 3, 7),
        );
      }

      for (final def in species) {
        final e = enrichmentMap[def.id];
        if (e != null) {
          expect(e.definitionId, def.id);
          expect(e.brawn + e.wit + e.speed, 90);
        }
      }

      final enrichedCount = species.where((d) => enrichmentMap.containsKey(d.id)).length;
      expect(enrichedCount, 3);
    });

    test('EnrichmentRepository round-trip preserves all enum values', () async {
      final repo = EnrichmentRepository(makeInMemoryDb());
      addTearDown(() async {});

      for (final ac in AnimalClass.values) {
        final e = SpeciesEnrichment(
          definitionId: 'fauna_${ac.name}',
          animalClass: ac,
          foodPreference: FoodType.critter,
          climate: Climate.temperate,
          brawn: 30,
          wit: 30,
          speed: 30,
          enrichedAt: DateTime(2026, 3, 7),
        );
        await repo.upsertEnrichment(e);
        final loaded = await repo.getEnrichment(e.definitionId);
        expect(loaded, isNotNull);
        expect(loaded!.animalClass, ac,
            reason: 'AnimalClass ${ac.name} should survive DB round-trip');
      }
    });

    test('EnrichmentService getEnrichmentMap integrates with SpeciesService', () async {
      final db = makeInMemoryDb();
      addTearDown(db.close);
      final repo = EnrichmentRepository(db);
      final service = EnrichmentService(repository: repo, supabaseClient: null);

      final species = loadFixtureSpecies();
      final first = species.first;

      await repo.upsertEnrichment(SpeciesEnrichment(
        definitionId: first.id,
        animalClass: AnimalClass.songbird,
        foodPreference: FoodType.nectar,
        climate: Climate.tropic,
        brawn: 10,
        wit: 40,
        speed: 40,
        enrichedAt: DateTime(2026, 3, 7),
      ));

      final enrichmentMap = await service.getEnrichmentMap();
      expect(enrichmentMap.containsKey(first.id), isTrue);

      final enrichedSpecies = species.map((def) {
        final e = enrichmentMap[def.id];
        if (e != null) {
          return FaunaDefinition(
            id: def.id,
            displayName: def.displayName,
            scientificName: def.scientificName,
            taxonomicClass: def.taxonomicClass,
            rarity: def.rarity!,
            habitats: def.habitats,
            continents: def.continents,
            seasonRestriction: def.seasonRestriction,
            contextTags: def.contextTags,
            animalClass: e.animalClass,
            foodPreference: e.foodPreference,
            climate: e.climate,
          );
        }
        return def;
      }).toList();

      final speciesService = SpeciesService(enrichedSpecies);
      final enrichedDef = enrichedSpecies.firstWhere((d) => d.id == first.id);
      expect(enrichedDef.animalClass, AnimalClass.songbird);
      expect(enrichedDef.foodPreference, FoodType.nectar);
      expect(enrichedDef.climate, Climate.tropic);

      expect(speciesService, isNotNull);
    });
  });
}
