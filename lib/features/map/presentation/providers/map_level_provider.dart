import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/core/observability/observable_notifier.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/map/domain/entities/map_level.dart';

final mapLevelObservabilityProvider = Provider<ObservabilityService>((ref) {
  throw UnimplementedError('Must be overridden with overrideWithValue');
});

final mapLevelProvider =
    NotifierProvider<MapLevelNotifier, MapLevel>(MapLevelNotifier.new);

class MapLevelNotifier extends ObservableNotifier<MapLevel> {
  @override
  ObservabilityService get obs => ref.watch(mapLevelObservabilityProvider);

  @override
  String get category => 'map.level';

  @override
  MapLevel build() => MapLevel.cell;

  void pinchClose() {
    final nextIndex = state.index + 1;
    if (nextIndex >= MapLevel.values.length) return;

    final next = MapLevel.values[nextIndex];
    transition(
      next,
      'map.level.pinch_close',
      data: {
        'from': state.name,
        'to': next.name,
      },
    );
  }

  void pinchSpread() {
    final nextIndex = state.index - 1;
    if (nextIndex < 0) return;

    final next = MapLevel.values[nextIndex];
    transition(
      next,
      'map.level.pinch_spread',
      data: {
        'from': state.name,
        'to': next.name,
      },
    );
  }

  void jumpTo(MapLevel level) {
    if (state == level) return;
    transition(
      level,
      'map.level.jump_to',
      data: {'from': state.name, 'to': level.name},
    );
  }
}
