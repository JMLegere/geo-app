import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geobase/geobase.dart';

import 'package:earth_nova/providers/location_provider.dart';

void main() {
  group('LocationNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
      addTearDown(container.dispose);
    });

    test('initial state has no position and unknown permission', () {
      final state = container.read(locationProvider);
      expect(state.position, isNull);
      expect(state.accuracy, 0.0);
      expect(state.permission, LocationPermissionStatus.unknown);
      expect(state.isTracking, false);
      expect(state.errorMessage, isNull);
    });

    test('updateLocation sets position and accuracy', () {
      final pos = Geographic(lat: 45.5, lon: -73.6);
      container.read(locationProvider.notifier).updateLocation(pos, 10.0);

      final state = container.read(locationProvider);
      expect(state.position, pos);
      expect(state.accuracy, 10.0);
    });

    test('updateLocation clears error', () {
      container.read(locationProvider.notifier).setError('GPS failed');
      expect(container.read(locationProvider).errorMessage, 'GPS failed');

      container
          .read(locationProvider.notifier)
          .updateLocation(Geographic(lat: 0, lon: 0), 5.0);
      expect(container.read(locationProvider).errorMessage, isNull);
    });

    test('setPermission changes permission status', () {
      container
          .read(locationProvider.notifier)
          .setPermission(LocationPermissionStatus.granted);
      expect(container.read(locationProvider).permission,
          LocationPermissionStatus.granted);
    });

    test('setPermission to denied', () {
      container
          .read(locationProvider.notifier)
          .setPermission(LocationPermissionStatus.denied);
      expect(container.read(locationProvider).permission,
          LocationPermissionStatus.denied);
    });

    test('setPermission to deniedForever', () {
      container
          .read(locationProvider.notifier)
          .setPermission(LocationPermissionStatus.deniedForever);
      expect(container.read(locationProvider).permission,
          LocationPermissionStatus.deniedForever);
    });

    test('setTracking toggles tracking state', () {
      container.read(locationProvider.notifier).setTracking(true);
      expect(container.read(locationProvider).isTracking, true);

      container.read(locationProvider.notifier).setTracking(false);
      expect(container.read(locationProvider).isTracking, false);
    });

    test('setError stores error message', () {
      container.read(locationProvider.notifier).setError('No signal');
      expect(container.read(locationProvider).errorMessage, 'No signal');
    });

    test('clearError removes error message', () {
      container.read(locationProvider.notifier).setError('No signal');
      container.read(locationProvider.notifier).clearError();
      expect(container.read(locationProvider).errorMessage, isNull);
    });
  });

  group('LocationState.copyWith', () {
    test('clearError flag clears errorMessage', () {
      const state = LocationState(errorMessage: 'err');
      final updated = state.copyWith(clearError: true);
      expect(updated.errorMessage, isNull);
    });

    test('preserves unset fields', () {
      final state = LocationState(
        position: Geographic(lat: 1, lon: 2),
        accuracy: 5.0,
        permission: LocationPermissionStatus.granted,
        isTracking: true,
        errorMessage: 'x',
      );
      final updated = state.copyWith(accuracy: 10.0);
      expect(updated.position, state.position);
      expect(updated.accuracy, 10.0);
      expect(updated.permission, LocationPermissionStatus.granted);
      expect(updated.isTracking, true);
      expect(updated.errorMessage, 'x');
    });
  });
}
