import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/models/animal_type.dart';

void main() {
  group('AnimalType', () {
    test('all 5 values exist', () {
      expect(AnimalType.values.length, equals(5));
      expect(AnimalType.values, contains(AnimalType.mammal));
      expect(AnimalType.values, contains(AnimalType.bird));
      expect(AnimalType.values, contains(AnimalType.fish));
      expect(AnimalType.values, contains(AnimalType.reptile));
      expect(AnimalType.values, contains(AnimalType.bug));
    });

    test('displayName returns human-readable names', () {
      expect(AnimalType.mammal.displayName, equals('Mammal'));
      expect(AnimalType.bird.displayName, equals('Bird'));
      expect(AnimalType.fish.displayName, equals('Fish'));
      expect(AnimalType.reptile.displayName, equals('Reptile'));
      expect(AnimalType.bug.displayName, equals('Bug'));
    });

    group('fromTaxonomicClass', () {
      test('Mammalia → mammal (title case)', () {
        expect(AnimalType.fromTaxonomicClass('Mammalia'), equals(AnimalType.mammal));
      });

      test('MAMMALIA → mammal (upper case)', () {
        expect(AnimalType.fromTaxonomicClass('MAMMALIA'), equals(AnimalType.mammal));
      });

      test('Aves → bird (title case)', () {
        expect(AnimalType.fromTaxonomicClass('Aves'), equals(AnimalType.bird));
      });

      test('AVES → bird (upper case)', () {
        expect(AnimalType.fromTaxonomicClass('AVES'), equals(AnimalType.bird));
      });

      test('Actinopterygii → fish', () {
        expect(AnimalType.fromTaxonomicClass('Actinopterygii'), equals(AnimalType.fish));
        expect(AnimalType.fromTaxonomicClass('ACTINOPTERYGII'), equals(AnimalType.fish));
      });

      test('Chondrichthyes → fish', () {
        expect(AnimalType.fromTaxonomicClass('Chondrichthyes'), equals(AnimalType.fish));
        expect(AnimalType.fromTaxonomicClass('CHONDRICHTHYES'), equals(AnimalType.fish));
      });

      test('Cephalaspidomorphi → fish', () {
        expect(AnimalType.fromTaxonomicClass('Cephalaspidomorphi'), equals(AnimalType.fish));
        expect(AnimalType.fromTaxonomicClass('CEPHALASPIDOMORPHI'), equals(AnimalType.fish));
      });

      test('Myxini → fish', () {
        expect(AnimalType.fromTaxonomicClass('Myxini'), equals(AnimalType.fish));
        expect(AnimalType.fromTaxonomicClass('MYXINI'), equals(AnimalType.fish));
      });

      test('Sarcopterygii → fish', () {
        expect(AnimalType.fromTaxonomicClass('Sarcopterygii'), equals(AnimalType.fish));
        expect(AnimalType.fromTaxonomicClass('SARCOPTERYGII'), equals(AnimalType.fish));
      });

      test('Reptilia → reptile', () {
        expect(AnimalType.fromTaxonomicClass('Reptilia'), equals(AnimalType.reptile));
        expect(AnimalType.fromTaxonomicClass('REPTILIA'), equals(AnimalType.reptile));
      });

      test('Amphibia → reptile', () {
        expect(AnimalType.fromTaxonomicClass('Amphibia'), equals(AnimalType.reptile));
        expect(AnimalType.fromTaxonomicClass('AMPHIBIA'), equals(AnimalType.reptile));
      });

      test('Insecta → bug', () {
        expect(AnimalType.fromTaxonomicClass('Insecta'), equals(AnimalType.bug));
        expect(AnimalType.fromTaxonomicClass('INSECTA'), equals(AnimalType.bug));
      });

      test('Arachnida → bug', () {
        expect(AnimalType.fromTaxonomicClass('Arachnida'), equals(AnimalType.bug));
        expect(AnimalType.fromTaxonomicClass('ARACHNIDA'), equals(AnimalType.bug));
      });

      test('Gastropoda → bug', () {
        expect(AnimalType.fromTaxonomicClass('Gastropoda'), equals(AnimalType.bug));
        expect(AnimalType.fromTaxonomicClass('GASTROPODA'), equals(AnimalType.bug));
      });

      test('Malacostraca → bug', () {
        expect(AnimalType.fromTaxonomicClass('Malacostraca'), equals(AnimalType.bug));
        expect(AnimalType.fromTaxonomicClass('MALACOSTRACA'), equals(AnimalType.bug));
      });

      test('Chilopoda → bug', () {
        expect(AnimalType.fromTaxonomicClass('Chilopoda'), equals(AnimalType.bug));
        expect(AnimalType.fromTaxonomicClass('CHILOPODA'), equals(AnimalType.bug));
      });

      test('Diplopoda → bug', () {
        expect(AnimalType.fromTaxonomicClass('Diplopoda'), equals(AnimalType.bug));
        expect(AnimalType.fromTaxonomicClass('DIPLOPODA'), equals(AnimalType.bug));
      });

      test('Cephalopoda → fish', () {
        expect(AnimalType.fromTaxonomicClass('Cephalopoda'), equals(AnimalType.fish));
        expect(AnimalType.fromTaxonomicClass('CEPHALOPODA'), equals(AnimalType.fish));
      });

      test('Bivalvia → bug', () {
        expect(AnimalType.fromTaxonomicClass('Bivalvia'), equals(AnimalType.bug));
        expect(AnimalType.fromTaxonomicClass('BIVALVIA'), equals(AnimalType.bug));
      });

      test('Anthozoa → bug', () {
        expect(AnimalType.fromTaxonomicClass('Anthozoa'), equals(AnimalType.bug));
        expect(AnimalType.fromTaxonomicClass('ANTHOZOA'), equals(AnimalType.bug));
      });

      test('Clitellata → bug', () {
        expect(AnimalType.fromTaxonomicClass('Clitellata'), equals(AnimalType.bug));
        expect(AnimalType.fromTaxonomicClass('CLITELLATA'), equals(AnimalType.bug));
      });

      test('Holothuroidea → bug', () {
        expect(AnimalType.fromTaxonomicClass('Holothuroidea'), equals(AnimalType.bug));
        expect(AnimalType.fromTaxonomicClass('HOLOTHUROIDEA'), equals(AnimalType.bug));
      });

      test('Branchiopoda → bug', () {
        expect(AnimalType.fromTaxonomicClass('Branchiopoda'), equals(AnimalType.bug));
        expect(AnimalType.fromTaxonomicClass('BRANCHIOPODA'), equals(AnimalType.bug));
      });

      test('Merostomata → bug', () {
        expect(AnimalType.fromTaxonomicClass('Merostomata'), equals(AnimalType.bug));
        expect(AnimalType.fromTaxonomicClass('MEROSTOMATA'), equals(AnimalType.bug));
      });

      test('unknown class → null', () {
        expect(AnimalType.fromTaxonomicClass('PLANTAE'), isNull);
        expect(AnimalType.fromTaxonomicClass(''), isNull);
        expect(AnimalType.fromTaxonomicClass('Unidentified'), isNull);
      });
    });

    group('fromString', () {
      test('parses each enum name', () {
        for (final t in AnimalType.values) {
          expect(AnimalType.fromString(t.name), equals(t));
        }
      });

      test('throws on unknown value', () {
        expect(() => AnimalType.fromString('dragon'), throwsArgumentError);
      });
    });

    test('toString returns name', () {
      expect(AnimalType.mammal.toString(), equals('mammal'));
      expect(AnimalType.bird.toString(), equals('bird'));
    });
  });
}
