import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as maplibre;
import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/core/observability/observable_notifier.dart';
import 'package:earth_nova/core/observability/observability_service.dart';

/// Holds the active MapLibreMapController.
///
/// Set by MapScreen when the map is created, cleared on dispose.
/// Consumed by DebugGestureOverlay to issue programmatic camera moves
/// (e.g. swipe-to-pan) without relying on Flutter pointer injection, which
/// does not reach the MapLibre WebGL canvas.
class MapControllerNotifier
    extends ObservableNotifier<maplibre.MapLibreMapController?> {
  @override
  ObservabilityService get obs => ref.watch(appObservabilityProvider);

  @override
  String get category => 'map_controller';

  @override
  maplibre.MapLibreMapController? build() => null;

  void set(maplibre.MapLibreMapController controller) {
    transition(controller, 'map_controller.set');
  }

  void clear() {
    transition(null, 'map_controller.clear');
  }
}

final mapControllerProvider =
    NotifierProvider<MapControllerNotifier, maplibre.MapLibreMapController?>(
  MapControllerNotifier.new,
  name: 'mapControllerProvider',
);
