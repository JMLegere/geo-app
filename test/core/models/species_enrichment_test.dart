import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/database/app_database.dart';
import 'package:earth_nova/core/models/animal_class.dart';
import 'package:earth_nova/core/models/animal_size.dart';
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
  AnimalSize? size,
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
      size: size,
      artUrl: artUrl,
      enrichedAt: enrichedAt ?? DateTime(2026, 3, 7, 12),
    );

/// Minimal helper to build a LocalSpeciesEnrichment row directly.
LocalSpeciesEnrichment makeRow({
  String definitionId = 'fauna_vulpes_vulpes',
  String animalClass = 'carnivore',
  String foodPreference = 'critter',
  String climate = 'temperate',
  int brawn = 30,
  int wit = 40,
  int speed = 20,
  String? size,
  String? artUrl,
  DateTime? enrichedAt,
}) =>
    LocalSpeciesEnrichment(
      definitionId: definitionId,
      animalClass: animalClass,
      foodPreference: foodPreference,
      climate: climate,
      brawn: brawn,
      wit: wit,
      speed: speed,
      size: size,
      artUrl: artUrl,
      enrichedAt: enrichedAt ?? DateTime(2026, 3, 7, 12),
    );

void main() {
  group('SpeciesEnrichment', () {
    test('constructs with valid stats summing to 90', () {
      final e = makeEnrichment(brawn: 30, wit: 40, speed: 20);
      expect(e.brawn + e.wit + e.speed, 90);
    });

    test('constructs with size field set', () {
      final e = makeEnrichment(size: AnimalSize.medium);
      expect(e.size, AnimalSize.medium);
    });

    test('constructs with null size field', () {
      final e = makeEnrichment();
      expect(e.size, isNull);
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
      expect(e.size, isNull);
    });

    test('fromJson parses size field when present', () {
      final json = {
        'definition_id': 'fauna_vulpes_vulpes',
        'animal_class': 'carnivore',
        'food_preference': 'critter',
        'climate': 'temperate',
        'brawn': 30,
        'wit': 40,
        'speed': 20,
        'size': 'small',
        'art_url': null,
        'enriched_at': '2026-03-07T12:00:00.000Z',
      };
      final e = SpeciesEnrichment.fromJson(json);
      expect(e.size, AnimalSize.small);
    });

    test('fromJson treats missing size key as null', () {
      final json = {
        'definition_id': 'fauna_test',
        'animal_class': 'carnivore',
        'food_preference': 'critter',
        'climate': 'temperate',
        'brawn': 30,
        'wit': 30,
        'speed': 30,
        'enriched_at': '2026-03-07T12:00:00.000Z',
      };
      final e = SpeciesEnrichment.fromJson(json);
      expect(e.size, isNull);
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

    test('toJson includes size name when size is set', () {
      final e = makeEnrichment(size: AnimalSize.colossal);
      final json = e.toJson();
      expect(json['size'], 'colossal');
    });

    test('toJson includes null size when size is null', () {
      final e = makeEnrichment();
      final json = e.toJson();
      expect(json.containsKey('size'), isTrue);
      expect(json['size'], isNull);
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
        'size': 'large',
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
      expect(out['size'], 'large');
    });

    test('fromJson → toJson round-trip with null size', () {
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
      expect(out['size'], isNull);
    });

    // -------------------------------------------------------------------------
    // fromDrift
    // -------------------------------------------------------------------------

    test('fromDrift parses row without size', () {
      final row = makeRow();
      final e = SpeciesEnrichment.fromDrift(row);
      expect(e.definitionId, 'fauna_vulpes_vulpes');
      expect(e.animalClass, AnimalClass.carnivore);
      expect(e.foodPreference, FoodType.critter);
      expect(e.climate, Climate.temperate);
      expect(e.brawn, 30);
      expect(e.wit, 40);
      expect(e.speed, 20);
      expect(e.size, isNull);
      expect(e.artUrl, isNull);
    });

    test('fromDrift parses row with size', () {
      final row = makeRow(size: 'medium');
      final e = SpeciesEnrichment.fromDrift(row);
      expect(e.size, AnimalSize.medium);
    });

    test('fromDrift parses all AnimalSize values', () {
      for (final size in AnimalSize.values) {
        final row = makeRow(size: size.name);
        final e = SpeciesEnrichment.fromDrift(row);
        expect(e.size, size,
            reason: '${size.name} should round-trip via fromDrift');
      }
    });

    // -------------------------------------------------------------------------
    // toDriftRow
    // -------------------------------------------------------------------------

    test('toDriftRow produces row without size', () {
      final e = makeEnrichment();
      final row = e.toDriftRow();
      expect(row.definitionId, 'fauna_vulpes_vulpes');
      expect(row.animalClass, 'carnivore');
      expect(row.size, isNull);
    });

    test('toDriftRow includes size name when set', () {
      final e = makeEnrichment(size: AnimalSize.huge);
      final row = e.toDriftRow();
      expect(row.size, 'huge');
    });

    test('toDriftRow → fromDrift round-trip preserves size', () {
      final original = makeEnrichment(size: AnimalSize.gargantuan);
      final row = original.toDriftRow();
      final restored = SpeciesEnrichment.fromDrift(row);
      expect(restored.size, AnimalSize.gargantuan);
    });

    test('toDriftRow → fromDrift round-trip preserves null size', () {
      final original = makeEnrichment();
      final row = original.toDriftRow();
      final restored = SpeciesEnrichment.fromDrift(row);
      expect(restored.size, isNull);
    });

    // -------------------------------------------------------------------------
    // toDriftCompanion
    // -------------------------------------------------------------------------

    test('toDriftCompanion wraps size name in Value when set', () {
      final e = makeEnrichment(size: AnimalSize.tiny);
      final companion = e.toDriftCompanion();
      expect(companion.size, Value<String?>('tiny'));
    });

    test('toDriftCompanion wraps null size in Value(null)', () {
      final e = makeEnrichment();
      final companion = e.toDriftCompanion();
      expect(companion.size, const Value<String?>(null));
    });

    test('toDriftCompanion includes all required fields', () {
      final e = makeEnrichment(size: AnimalSize.fine);
      final companion = e.toDriftCompanion();
      expect(companion.definitionId, const Value('fauna_vulpes_vulpes'));
      expect(companion.animalClass, const Value('carnivore'));
      expect(companion.foodPreference, const Value('critter'));
      expect(companion.climate, const Value('temperate'));
      expect(companion.brawn, const Value(30));
      expect(companion.wit, const Value(40));
      expect(companion.speed, const Value(20));
      expect(companion.size, Value<String?>('fine'));
    });

    // -------------------------------------------------------------------------
    // Existing tests
    // -------------------------------------------------------------------------

    test('equality is by definitionId', () {
      final a = makeEnrichment(
          definitionId: 'fauna_x', brawn: 30, wit: 30, speed: 30);
      final b = makeEnrichment(
          definitionId: 'fauna_x', brawn: 10, wit: 40, speed: 40);
      final c = makeEnrichment(
          definitionId: 'fauna_y', brawn: 30, wit: 30, speed: 30);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('hashCode matches equality', () {
      final a = makeEnrichment(
          definitionId: 'fauna_x', brawn: 30, wit: 30, speed: 30);
      final b = makeEnrichment(
          definitionId: 'fauna_x', brawn: 10, wit: 40, speed: 40);
      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString contains definitionId', () {
      final e = makeEnrichment();
      expect(e.toString(), contains('fauna_vulpes_vulpes'));
    });

    test('toString contains size when set', () {
      final e = makeEnrichment(size: AnimalSize.diminutive);
      expect(e.toString(), contains('diminutive'));
    });

    test('copyWith replaces only specified fields', () {
      final original = makeEnrichment();
      final modified = original.copyWith(
          climate: Climate.tropic, brawn: 40, wit: 30, speed: 20);
      expect(modified.climate, Climate.tropic);
      expect(modified.brawn, 40);
      expect(modified.definitionId, original.definitionId);
      expect(modified.animalClass, original.animalClass);
    });

    test('copyWith can set size', () {
      final original = makeEnrichment();
      final modified = original.copyWith(size: AnimalSize.large);
      expect(modified.size, AnimalSize.large);
      expect(original.size, isNull); // immutable
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

    test('fromJson handles all AnimalSize values', () {
      for (final sz in AnimalSize.values) {
        final json = {
          'definition_id': 'fauna_test',
          'animal_class': 'carnivore',
          'food_preference': 'critter',
          'climate': 'temperate',
          'brawn': 30,
          'wit': 30,
          'speed': 30,
          'size': sz.name,
          'art_url': null,
          'enriched_at': '2026-03-07T12:00:00.000Z',
        };
        final e = SpeciesEnrichment.fromJson(json);
        expect(e.size, sz);
      }
    });
  });
}
