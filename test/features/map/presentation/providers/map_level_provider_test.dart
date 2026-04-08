import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/map/domain/entities/map_level.dart';
import 'package:earth_nova/features/map/presentation/providers/map_level_provider.dart';

class _TestObservabilityService extends ObservabilityService {
  _TestObservabilityService() : super(sessionId: 'test-session');
}

void main() {
  ProviderContainer makeContainer() {
    return ProviderContainer(
      overrides: [
        mapLevelObservabilityProvider.overrideWithValue(
          _TestObservabilityService(),
        ),
      ],
    );
  }

  group('MapLevelNotifier', () {
    test('starts at cell level', () {
      final container = makeContainer();
      addTearDown(container.dispose);

      expect(container.read(mapLevelProvider), MapLevel.cell);
    });

    test('pinch-close transitions cell to world and caps at world', () {
      final container = makeContainer();
      addTearDown(container.dispose);

      final notifier = container.read(mapLevelProvider.notifier);
      final levels = <MapLevel>[container.read(mapLevelProvider)];

      for (var i = 0; i < 6; i++) {
        notifier.pinchClose();
        levels.add(container.read(mapLevelProvider));
      }

      expect(
        levels,
        const [
          MapLevel.cell,
          MapLevel.district,
          MapLevel.city,
          MapLevel.state,
          MapLevel.country,
          MapLevel.world,
          MapLevel.world,
        ],
      );
    });

    test('pinch-spread transitions world to cell and caps at cell', () {
      final container = makeContainer();
      addTearDown(container.dispose);

      final notifier = container.read(mapLevelProvider.notifier);
      for (var i = 0; i < 6; i++) {
        notifier.pinchClose();
      }

      final levels = <MapLevel>[container.read(mapLevelProvider)];
      for (var i = 0; i < 6; i++) {
        notifier.pinchSpread();
        levels.add(container.read(mapLevelProvider));
      }

      expect(
        levels,
        const [
          MapLevel.world,
          MapLevel.country,
          MapLevel.state,
          MapLevel.city,
          MapLevel.district,
          MapLevel.cell,
          MapLevel.cell,
        ],
      );
    });
  });
}
