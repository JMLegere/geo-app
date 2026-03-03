import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Immutable snapshot of the map's readiness and camera state.
///
/// [isReady] is false until the MapLibre controller fires onMapCreated.
/// [cameraLat] and [cameraLon] are null until the first GPS update or
/// forced start position is applied.
class MapState {
  /// Whether the MapLibre controller is initialised and ready for commands.
  final bool isReady;

  /// Camera center latitude in degrees, or null before first location update.
  final double? cameraLat;

  /// Camera center longitude in degrees, or null before first location update.
  final double? cameraLon;

  /// Current map zoom level. Defaults to `kDefaultZoom` (15.0).
  final double zoom;

  const MapState({
    required this.isReady,
    required this.zoom,
    this.cameraLat,
    this.cameraLon,
  });

  /// Returns a copy of this state with the given fields replaced.
  MapState copyWith({
    bool? isReady,
    double? zoom,
    double? cameraLat,
    double? cameraLon,
  }) {
    return MapState(
      isReady: isReady ?? this.isReady,
      zoom: zoom ?? this.zoom,
      cameraLat: cameraLat ?? this.cameraLat,
      cameraLon: cameraLon ?? this.cameraLon,
    );
  }

  @override
  String toString() => 'MapState(isReady: $isReady, '
      'camera: ($cameraLat, $cameraLon), zoom: $zoom)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MapState &&
          other.isReady == isReady &&
          other.cameraLat == cameraLat &&
          other.cameraLon == cameraLon &&
          other.zoom == zoom;

  @override
  int get hashCode => Object.hash(isReady, cameraLat, cameraLon, zoom);
}

/// Notifier that manages [MapState] mutations.
///
/// Exposes targeted mutation methods rather than exposing state replacement
/// directly, so callers cannot accidentally clear unrelated fields.
class MapStateNotifier extends Notifier<MapState> {
  @override
  MapState build() {
    return const MapState(isReady: false, zoom: 15.0);
  }

  /// Called when the MapLibre controller fires onMapCreated.
  void markReady() {
    state = state.copyWith(isReady: true);
  }

  /// Updates the camera position, typically from a GPS or follow-mode update.
  void updateCameraPosition(double lat, double lon) {
    state = state.copyWith(cameraLat: lat, cameraLon: lon);
  }

  /// Updates the current zoom level, typically from user pinch or programmatic zoom.
  void updateZoom(double zoom) {
    state = state.copyWith(zoom: zoom);
  }

  /// Resets the map to its initial unready state. Used on dispose or re-init.
  void reset() {
    state = const MapState(isReady: false, zoom: 15.0);
  }
}

/// Riverpod provider for [MapState].
///
/// Access via:
/// - `ref.watch(mapStateProvider)` — reactive [MapState] snapshot
/// - `ref.read(mapStateProvider.notifier)` — [MapStateNotifier] for mutations
final mapStateProvider = NotifierProvider<MapStateNotifier, MapState>(
  MapStateNotifier.new,
);
