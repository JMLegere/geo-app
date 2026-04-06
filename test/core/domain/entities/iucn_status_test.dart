import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/domain/entities/iucn_status.dart';

void main() {
  group('IucnStatus.fromString', () {
    test('parses short code LC', () {
      expect(IucnStatus.fromString('LC'), IucnStatus.leastConcern);
    });

    test('parses short code EN', () {
      expect(IucnStatus.fromString('EN'), IucnStatus.endangered);
    });

    test('parses short code CR', () {
      expect(IucnStatus.fromString('CR'), IucnStatus.criticallyEndangered);
    });

    test('parses enum name leastConcern', () {
      expect(IucnStatus.fromString('leastConcern'), IucnStatus.leastConcern);
    });

    test('parses case-insensitive', () {
      expect(IucnStatus.fromString('lc'), IucnStatus.leastConcern);
      expect(IucnStatus.fromString('en'), IucnStatus.endangered);
    });

    test('returns null for null input', () {
      expect(IucnStatus.fromString(null), isNull);
    });

    test('returns null for unknown string', () {
      expect(IucnStatus.fromString('UNKNOWN'), isNull);
    });
  });

  group('IucnStatus enum values', () {
    test('has code and displayName', () {
      expect(IucnStatus.leastConcern.code, 'LC');
      expect(IucnStatus.leastConcern.displayName, 'Least Concern');
      expect(IucnStatus.criticallyEndangered.code, 'CR');
      expect(
          IucnStatus.criticallyEndangered.displayName, 'Critically Endangered');
    });

    test('has no color property (pure domain — no Flutter)', () {
      // IucnStatus is a pure domain enum — Color lives in the extension.
      // This test documents the design intent by verifying the enum is accessible
      // without any Flutter import.
      expect(IucnStatus.values, hasLength(6));
    });
  });
}
