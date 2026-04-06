import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/features/map/domain/entities/location_state.dart';

void main() {
  group('LocationState', () {
    final now = DateTime(2026, 4, 6, 12, 0, 0);

    test('constructs with required fields', () {
      final state = LocationState(
        lat: 44.6488,
        lng: -63.5752,
        accuracy: 10.0,
        timestamp: now,
        isConfident: true,
      );
      expect(state.lat, 44.6488);
      expect(state.lng, -63.5752);
      expect(state.accuracy, 10.0);
      expect(state.timestamp, now);
      expect(state.isConfident, true);
    });

    test('equality', () {
      final a = LocationState(
        lat: 44.6488,
        lng: -63.5752,
        accuracy: 10.0,
        timestamp: now,
        isConfident: true,
      );
      final b = LocationState(
        lat: 44.6488,
        lng: -63.5752,
        accuracy: 10.0,
        timestamp: now,
        isConfident: true,
      );
      expect(a, equals(b));
    });

    test('inequality when lat differs', () {
      final a = LocationState(
        lat: 44.6488,
        lng: -63.5752,
        accuracy: 10.0,
        timestamp: now,
        isConfident: true,
      );
      final b = LocationState(
        lat: 44.0000,
        lng: -63.5752,
        accuracy: 10.0,
        timestamp: now,
        isConfident: true,
      );
      expect(a, isNot(equals(b)));
    });

    test('inequality when lng differs', () {
      final a = LocationState(
        lat: 44.6488,
        lng: -63.5752,
        accuracy: 10.0,
        timestamp: now,
        isConfident: true,
      );
      final b = LocationState(
        lat: 44.6488,
        lng: -64.0000,
        accuracy: 10.0,
        timestamp: now,
        isConfident: true,
      );
      expect(a, isNot(equals(b)));
    });

    test('inequality when accuracy differs', () {
      final a = LocationState(
        lat: 44.6488,
        lng: -63.5752,
        accuracy: 10.0,
        timestamp: now,
        isConfident: true,
      );
      final b = LocationState(
        lat: 44.6488,
        lng: -63.5752,
        accuracy: 20.0,
        timestamp: now,
        isConfident: true,
      );
      expect(a, isNot(equals(b)));
    });

    test('inequality when timestamp differs', () {
      final a = LocationState(
        lat: 44.6488,
        lng: -63.5752,
        accuracy: 10.0,
        timestamp: now,
        isConfident: true,
      );
      final b = LocationState(
        lat: 44.6488,
        lng: -63.5752,
        accuracy: 10.0,
        timestamp: DateTime(2026, 4, 7),
        isConfident: true,
      );
      expect(a, isNot(equals(b)));
    });

    test('inequality when isConfident differs', () {
      final a = LocationState(
        lat: 44.6488,
        lng: -63.5752,
        accuracy: 10.0,
        timestamp: now,
        isConfident: true,
      );
      final b = LocationState(
        lat: 44.6488,
        lng: -63.5752,
        accuracy: 10.0,
        timestamp: now,
        isConfident: false,
      );
      expect(a, isNot(equals(b)));
    });

    test('hashCode is consistent for equal states', () {
      final a = LocationState(
        lat: 44.6488,
        lng: -63.5752,
        accuracy: 10.0,
        timestamp: now,
        isConfident: true,
      );
      final b = LocationState(
        lat: 44.6488,
        lng: -63.5752,
        accuracy: 10.0,
        timestamp: now,
        isConfident: true,
      );
      expect(a.hashCode, equals(b.hashCode));
    });
  });
}
