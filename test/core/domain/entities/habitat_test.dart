import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/domain/entities/habitat.dart';

void main() {
  group('Habitat.fromString', () {
    test('parses Forest', () {
      expect(Habitat.fromString('Forest'), Habitat.forest);
    });

    test('parses case-insensitive', () {
      expect(Habitat.fromString('forest'), Habitat.forest);
      expect(Habitat.fromString('MOUNTAIN'), Habitat.mountain);
    });

    test('returns null for null', () {
      expect(Habitat.fromString(null), isNull);
    });

    test('returns null for empty string', () {
      expect(Habitat.fromString(''), isNull);
    });

    test('returns null for unknown', () {
      expect(Habitat.fromString('Jungle'), isNull);
    });

    test('parses all known habitats', () {
      expect(Habitat.fromString('Plains'), Habitat.plains);
      expect(Habitat.fromString('Freshwater'), Habitat.freshwater);
      expect(Habitat.fromString('Saltwater'), Habitat.saltwater);
      expect(Habitat.fromString('Swamp'), Habitat.swamp);
      expect(Habitat.fromString('Desert'), Habitat.desert);
      expect(Habitat.fromString('Unknown'), Habitat.unknown);
    });
  });

  group('Habitat enum', () {
    test('has label', () {
      expect(Habitat.forest.label, 'Forest');
      expect(Habitat.unknown.label, 'Unknown');
    });
  });
}
