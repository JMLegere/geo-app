import 'package:earth_nova/features/identification/data/dtos/identification_wire_validation.dart';
import 'package:flutter_test/flutter_test.dart';

const _uuid = '11111111-1111-4111-8111-111111111111';

void main() {
  group('IdentificationWireValidation object boundaries', () {
    test('accepts an exact string-keyed schema and rejects shape drift', () {
      expect(
        IdentificationWireValidation.object({'id': _uuid}, const {'id'}),
        {'id': _uuid},
      );

      expect(
        () => IdentificationWireValidation.object(const [], const {'id'}),
        throwsStateError,
      );
      expect(
        () => IdentificationWireValidation.object({1: _uuid}, const {'id'}),
        throwsStateError,
      );
      expect(
        () => IdentificationWireValidation.object(
          {'id': _uuid, 'extra': true},
          const {'id'},
        ),
        throwsStateError,
      );
      expect(
        () => IdentificationWireValidation.object(const {}, const {'id'}),
        throwsStateError,
      );
    });

    test('returns an immutable array only for list wire values', () {
      final values = IdentificationWireValidation.array(['one']);

      expect(values, ['one']);
      expect(() => values.add('two'), throwsUnsupportedError);
      expect(
        () => IdentificationWireValidation.array({'zero': 'one'}),
        throwsStateError,
      );
    });
  });

  group('IdentificationWireValidation scalar boundaries', () {
    test(
        'requires trimmed text, RFC UUIDs, positive integer ordinals, and weights',
        () {
      expect(IdentificationWireValidation.string('text'), 'text');
      expect(IdentificationWireValidation.uuid(_uuid), _uuid);
      expect(IdentificationWireValidation.positiveInt(1), 1);
      expect(IdentificationWireValidation.ordinal(2, 2), 2);
      expect(IdentificationWireValidation.positiveWeight(0.5), 0.5);

      expect(
          () => IdentificationWireValidation.string(' text'), throwsStateError);
      expect(() => IdentificationWireValidation.uuid('not-a-uuid'),
          throwsStateError);
      expect(
          () => IdentificationWireValidation.positiveInt(0), throwsStateError);
      expect(
          () => IdentificationWireValidation.ordinal(1, 2), throwsStateError);
      expect(
        () => IdentificationWireValidation.positiveWeight(double.infinity),
        throwsStateError,
      );
    });

    test('requires timezone-bearing timestamps and returns the parsed instant',
        () {
      expect(
        IdentificationWireValidation.timestamp('2026-01-02T03:04:05.6+00:00'),
        DateTime.parse('2026-01-02T03:04:05.6+00:00'),
      );

      expect(
        () => IdentificationWireValidation.timestamp('2026-01-02T03:04:05'),
        throwsStateError,
      );
    });

    test('enforces nullable and JSON-array fields at the wire boundary', () {
      IdentificationWireValidation.nullableString(null);
      IdentificationWireValidation.nullableString('optional');
      IdentificationWireValidation.nullableUuid(null);
      IdentificationWireValidation.nullableUuid(_uuid);
      IdentificationWireValidation.jsonStringArray('["forest", "coast"]');

      expect(
        () => IdentificationWireValidation.nullableString(1),
        throwsStateError,
      );
      expect(
        () => IdentificationWireValidation.nullableUuid('not-a-uuid'),
        throwsStateError,
      );
      expect(
        () => IdentificationWireValidation.jsonStringArray('["forest", 2]'),
        throwsStateError,
      );
      expect(
        () => IdentificationWireValidation.jsonStringArray(
            '{"habitat":"forest"}'),
        throwsStateError,
      );
      expect(
        () => IdentificationWireValidation.jsonStringArray('not-json'),
        throwsStateError,
      );
    });
  });
}
