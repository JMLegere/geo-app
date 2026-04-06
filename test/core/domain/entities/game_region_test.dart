import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/domain/entities/game_region.dart';

void main() {
  group('GameRegion.fromString', () {
    test('parses Africa', () {
      expect(GameRegion.fromString('Africa'), GameRegion.africa);
    });

    test('parses North America with space', () {
      expect(GameRegion.fromString('North America'), GameRegion.northAmerica);
    });

    test('parses South America with space', () {
      expect(GameRegion.fromString('South America'), GameRegion.southAmerica);
    });

    test('parses case-insensitive', () {
      expect(GameRegion.fromString('africa'), GameRegion.africa);
      expect(GameRegion.fromString('ASIA'), GameRegion.asia);
    });

    test('returns null for null', () {
      expect(GameRegion.fromString(null), isNull);
    });

    test('returns null for empty string', () {
      expect(GameRegion.fromString(''), isNull);
    });

    test('returns null for unknown', () {
      expect(GameRegion.fromString('Antarctica'), isNull);
    });

    test('parses all known regions', () {
      expect(GameRegion.fromString('Asia'), GameRegion.asia);
      expect(GameRegion.fromString('Europe'), GameRegion.europe);
      expect(GameRegion.fromString('Oceania'), GameRegion.oceania);
    });
  });

  group('GameRegion enum', () {
    test('has label', () {
      expect(GameRegion.africa.label, 'Africa');
      expect(GameRegion.northAmerica.label, 'N. America');
    });
  });
}
