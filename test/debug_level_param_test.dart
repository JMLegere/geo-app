import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/features/map/domain/entities/map_level.dart';
import 'package:earth_nova/shared/debug/debug_level_param.dart';

void main() {
  group('debugLevelFromParam', () {
    test('returns null for null param', () {
      expect(debugLevelFromParam(null), isNull);
    });

    test('returns null for empty string', () {
      expect(debugLevelFromParam(''), isNull);
    });

    test('returns null for unknown value', () {
      expect(debugLevelFromParam('galaxy'), isNull);
    });

    test('returns MapLevel.cell for "cell"', () {
      expect(debugLevelFromParam('cell'), MapLevel.cell);
    });

    test('returns MapLevel.district for "district"', () {
      expect(debugLevelFromParam('district'), MapLevel.district);
    });

    test('returns MapLevel.city for "city"', () {
      expect(debugLevelFromParam('city'), MapLevel.city);
    });

    test('returns MapLevel.state for "state"', () {
      expect(debugLevelFromParam('state'), MapLevel.state);
    });

    test('returns MapLevel.country for "country"', () {
      expect(debugLevelFromParam('country'), MapLevel.country);
    });

    test('returns MapLevel.world for "world"', () {
      expect(debugLevelFromParam('world'), MapLevel.world);
    });

    test('is case-sensitive — "District" returns null', () {
      expect(debugLevelFromParam('District'), isNull);
    });
  });
}
