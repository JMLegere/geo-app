import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/models/animal_class.dart';
import 'package:earth_nova/core/models/climate.dart';
import 'package:earth_nova/core/models/food_type.dart';
import 'package:earth_nova/core/models/species_enrichment.dart';

SpeciesEnrichment makeEnrichment({
  String definitionId = 'fauna_vulpes_vulpes',
  AnimalClass animalClass = AnimalClass.carnivore,
  FoodType foodPreference = FoodType.critter,
  Climate climate = Climate.temperate,
  int brawn = 30,
  int wit = 40,
  int speed = 20,
  String? artUrl,
  DateTime? enrichedAt,
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
      enrichedAt: enrichedAt ?? DateTime(2026, 3, 7, 12),
    );

void main() {
  group('SpeciesEnrichment', () {
    test('constructs with valid stats summing to 90', () {
      final e = makeEnrichment(brawn: 30, wit: 40, speed: 20);
      expect(e.brawn + e.wit + e.speed, 90);
    });

    test('fromJson parses Supabase snake_case response', () {
      final json = {
        'definition_id': 'fauna_vulpes_vulpes',
        'animal_class': 'carnivore',
        'food_preference': 'critter',
        'climate': 'temperate',
        'brawn': 30,
        'wit': 40,
        'speed': 20,
        'art_url': null,
        'enriched_at': '2026-03-07T12:00:00.000Z',
      };
      final e = SpeciesEnrichment.fromJson(json);
      expect(e.definitionId, 'fauna_vulpes_vulpes');
      expect(e.animalClass, AnimalClass.carnivore);
      expect(e.foodPreference, FoodType.critter);
      expect(e.climate, Climate.temperate);
      expect(e.brawn, 30);
      expect(e.wit, 40);
      expect(e.speed, 20);
      expect(e.artUrl, isNull);
    });

    test('toJson produces snake_case keys', () {
      final e = makeEnrichment(artUrl: 'https://example.com/art.png');
      final json = e.toJson();
      expect(json['definition_id'], 'fauna_vulpes_vulpes');
      expect(json['animal_class'], 'carnivore');
      expect(json['food_preference'], 'critter');
      expect(json['climate'], 'temperate');
      expect(json['brawn'], 30);
      expect(json['wit'], 40);
      expect(json['speed'], 20);
      expect(json['art_url'], 'https://example.com/art.png');
    });

    test('fromJson → toJson round-trip preserves all fields', () {
      final json = {
        'definition_id': 'fauna_panthera_leo',
        'animal_class': 'carnivore',
        'food_preference': 'critter',
        'climate': 'tropic',
        'brawn': 50,
        'wit': 25,
        'speed': 15,
        'art_url': null,
        'enriched_at': '2026-03-07T12:00:00.000Z',
      };
      final e = SpeciesEnrichment.fromJson(json);
      final out = e.toJson();
      expect(out['definition_id'], json['definition_id']);
      expect(out['animal_class'], json['animal_class']);
      expect(out['food_preference'], json['food_preference']);
      expect(out['climate'], json['climate']);
      expect(out['brawn'], json['brawn']);
      expect(out['wit'], json['wit']);
      expect(out['speed'], json['speed']);
    });

    test('equality is by definitionId', () {
      final a = makeEnrichment(definitionId: 'fauna_x', brawn: 30, wit: 30, speed: 30);
      final b = makeEnrichment(definitionId: 'fauna_x', brawn: 10, wit: 40, speed: 40);
      final c = makeEnrichment(definitionId: 'fauna_y', brawn: 30, wit: 30, speed: 30);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('hashCode matches equality', () {
      final a = makeEnrichment(definitionId: 'fauna_x', brawn: 30, wit: 30, speed: 30);
      final b = makeEnrichment(definitionId: 'fauna_x', brawn: 10, wit: 40, speed: 40);
      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString contains definitionId', () {
      final e = makeEnrichment();
      expect(e.toString(), contains('fauna_vulpes_vulpes'));
    });

    test('copyWith replaces only specified fields', () {
      final original = makeEnrichment();
      final modified = original.copyWith(climate: Climate.tropic, brawn: 40, wit: 30, speed: 20);
      expect(modified.climate, Climate.tropic);
      expect(modified.brawn, 40);
      expect(modified.definitionId, original.definitionId);
      expect(modified.animalClass, original.animalClass);
    });

    test('fromJson handles all AnimalClass values', () {
      for (final ac in AnimalClass.values) {
        final json = {
          'definition_id': 'fauna_test',
          'animal_class': ac.name,
          'food_preference': 'critter',
          'climate': 'temperate',
          'brawn': 30,
          'wit': 30,
          'speed': 30,
          'art_url': null,
          'enriched_at': '2026-03-07T12:00:00.000Z',
        };
        final e = SpeciesEnrichment.fromJson(json);
        expect(e.animalClass, ac);
      }
    });

    test('fromJson handles all FoodType values', () {
      for (final ft in FoodType.values) {
        final json = {
          'definition_id': 'fauna_test',
          'animal_class': 'carnivore',
          'food_preference': ft.name,
          'climate': 'temperate',
          'brawn': 30,
          'wit': 30,
          'speed': 30,
          'art_url': null,
          'enriched_at': '2026-03-07T12:00:00.000Z',
        };
        final e = SpeciesEnrichment.fromJson(json);
        expect(e.foodPreference, ft);
      }
    });

    test('fromJson handles all Climate values', () {
      for (final cl in Climate.values) {
        final json = {
          'definition_id': 'fauna_test',
          'animal_class': 'carnivore',
          'food_preference': 'critter',
          'climate': cl.name,
          'brawn': 30,
          'wit': 30,
          'speed': 30,
          'art_url': null,
          'enriched_at': '2026-03-07T12:00:00.000Z',
        };
        final e = SpeciesEnrichment.fromJson(json);
        expect(e.climate, cl);
      }
    });
  });
}
