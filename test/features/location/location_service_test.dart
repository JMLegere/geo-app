import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fog_of_world/features/location/services/gps_filter.dart';
import 'package:fog_of_world/features/location/services/location_service.dart';
import 'package:fog_of_world/features/location/services/location_simulator.dart';
import 'package:fog_of_world/core/state/location_provider.dart';

LocationService _testService({int seed = 1}) => LocationService(
      simulator: LocationSimulator(
        updateInterval: const Duration(milliseconds: 50),
        seed: seed,
      ),
      filter: GpsFilter(minDistanceMeters: 0.0),
    );

void main() {
  group('LocationService', () {
    test('starts in simulation mode by default', () {
      final service = LocationService();
      expect(service.mode, LocationMode.simulation);
      expect(service.simulator, isNotNull);
    });

    test('isTracking is false before start', () {
      final service = LocationService();
      expect(service.isTracking, isFalse);
    });

    test('isTracking is true after start', () {
      final service = _testService(seed: 1);
      service.start();
      expect(service.isTracking, isTrue);
      service.stop();
    });

    test('produces filtered location updates in simulation mode', () async {
      final service = _testService(seed: 2);

      service.start();
      final updates = await service.filteredLocationStream
          .take(3)
          .toList()
          .timeout(const Duration(seconds: 2));
      service.stop();

      expect(updates.length, 3);
      for (final loc in updates) {
        expect(loc.accuracy, lessThanOrEqualTo(50.0));
      }
    });

    test('stopping the service stops updates', () async {
      final service = _testService(seed: 4);

      service.start();
      await service.filteredLocationStream.first.timeout(const Duration(seconds: 1));
      service.stop();

      expect(service.isTracking, isFalse);

      final count = await service.filteredLocationStream
          .take(3)
          .timeout(
            const Duration(milliseconds: 300),
            onTimeout: (sink) => sink.close(),
          )
          .length;

      expect(count, 0);
    });

    test('calling start twice does not double-subscribe', () async {
      final service = _testService(seed: 6);

      service.start();
      service.start();

      final locs = await service.filteredLocationStream
          .take(3)
          .toList()
          .timeout(const Duration(seconds: 2));
      service.stop();

      expect(locs.length, 3);
    });
  });

  group('LocationNotifier.connectToService', () {
    test('updates provider state when service emits locations', () async {
      final service = _testService(seed: 10);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(locationProvider.notifier);
      notifier.connectToService(service);
      service.start();

      await Future<void>.delayed(const Duration(milliseconds: 300));

      final state = container.read(locationProvider);
      expect(state.currentPosition, isNotNull);
      expect(state.accuracy, isNotNull);

      service.stop();
    });
  });
}
