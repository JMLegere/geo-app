import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/map/presentation/providers/map_controller_provider.dart';

class _TestObservabilityService extends ObservabilityService {
  _TestObservabilityService() : super(sessionId: 'test-session');
}

ProviderContainer _makeContainer() {
  return ProviderContainer(
    overrides: [
      appObservabilityProvider.overrideWithValue(_TestObservabilityService()),
    ],
  );
}

void main() {
  group('MapControllerNotifier', () {
    test('initial state is null', () {
      final container = _makeContainer();
      addTearDown(container.dispose);

      expect(container.read(mapControllerProvider), isNull);
    });

    test('clear() transitions state back to null', () {
      final container = _makeContainer();
      addTearDown(container.dispose);

      // clear() when already null should stay null without throwing.
      container.read(mapControllerProvider.notifier).clear();
      expect(container.read(mapControllerProvider), isNull);
    });

    test('uses category map_controller', () {
      final container = _makeContainer();
      addTearDown(container.dispose);

      final notifier = container.read(mapControllerProvider.notifier);
      expect(notifier.category, 'map_controller');
    });
  });
}
