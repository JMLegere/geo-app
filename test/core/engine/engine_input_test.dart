import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/engine/engine_input.dart';

void main() {
  group('PositionUpdate', () {
    test('stores lat, lon, and accuracy', () {
      final input = PositionUpdate(45.9636, -66.6431, 5.0);

      expect(input.lat, equals(45.9636));
      expect(input.lon, equals(-66.6431));
      expect(input.accuracy, equals(5.0));
    });

    test('is a subtype of EngineInput', () {
      final EngineInput input = PositionUpdate(0, 0, 10);
      expect(input, isA<PositionUpdate>());
    });
  });

  group('CellTapped', () {
    test('stores cellId', () {
      final input = CellTapped('v_1_2');

      expect(input.cellId, equals('v_1_2'));
    });

    test('is a subtype of EngineInput', () {
      final EngineInput input = CellTapped('v_1_2');
      expect(input, isA<CellTapped>());
    });
  });

  group('AuthChanged', () {
    test('stores non-null userId', () {
      final input = AuthChanged('user-abc-123');

      expect(input.userId, equals('user-abc-123'));
    });

    test('stores null userId for sign-out', () {
      final input = AuthChanged(null);

      expect(input.userId, isNull);
    });

    test('is a subtype of EngineInput', () {
      final EngineInput input = AuthChanged('user-abc');
      expect(input, isA<AuthChanged>());
    });
  });

  group('AppBackgrounded', () {
    test('can be constructed', () {
      final input = AppBackgrounded();
      expect(input, isA<AppBackgrounded>());
    });

    test('is a subtype of EngineInput', () {
      final EngineInput input = AppBackgrounded();
      expect(input, isA<EngineInput>());
    });
  });

  group('AppResumed', () {
    test('can be constructed', () {
      final input = AppResumed();
      expect(input, isA<AppResumed>());
    });

    test('is a subtype of EngineInput', () {
      final EngineInput input = AppResumed();
      expect(input, isA<EngineInput>());
    });
  });

  group('EngineInput exhaustive switch', () {
    test('handles all subtypes in switch expression', () {
      final inputs = <EngineInput>[
        PositionUpdate(45.0, -66.0, 5.0),
        CellTapped('v_1_2'),
        AuthChanged('user-1'),
        AppBackgrounded(),
        AppResumed(),
      ];

      for (final input in inputs) {
        // If this switch is not exhaustive, the analyzer would error
        // (sealed class guarantees exhaustiveness).
        final label = switch (input) {
          PositionUpdate() => 'position',
          CellTapped() => 'cell',
          AuthChanged() => 'auth',
          AppBackgrounded() => 'background',
          AppResumed() => 'resumed',
        };

        expect(label, isNotEmpty);
      }
    });

    test('switch expression can destructure PositionUpdate fields', () {
      final EngineInput input = PositionUpdate(45.0, -66.0, 5.0);

      final result = switch (input) {
        PositionUpdate(:final lat, :final lon, :final accuracy) =>
          'lat=$lat lon=$lon acc=$accuracy',
        CellTapped() => 'cell',
        AuthChanged() => 'auth',
        AppBackgrounded() => 'bg',
        AppResumed() => 'fg',
      };

      expect(result, equals('lat=45.0 lon=-66.0 acc=5.0'));
    });

    test('switch expression can destructure CellTapped fields', () {
      final EngineInput input = CellTapped('v_3_4');

      final result = switch (input) {
        PositionUpdate() => 'pos',
        CellTapped(:final cellId) => cellId,
        AuthChanged() => 'auth',
        AppBackgrounded() => 'bg',
        AppResumed() => 'fg',
      };

      expect(result, equals('v_3_4'));
    });

    test('switch expression can destructure AuthChanged fields', () {
      final EngineInput input = AuthChanged(null);

      final result = switch (input) {
        PositionUpdate() => 'pos',
        CellTapped() => 'cell',
        AuthChanged(:final userId) => userId ?? 'signed_out',
        AppBackgrounded() => 'bg',
        AppResumed() => 'fg',
      };

      expect(result, equals('signed_out'));
    });
  });
}
