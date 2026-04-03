import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geobase/geobase.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class MapState {
  /// Current camera center. Null until the first GPS fix.
  final Geographic? center;

  /// Current map zoom level.
  final double zoom;

  /// Cell ID the user last tapped, or null.
  final String? selectedCellId;

  /// When true, the camera follows the player's GPS position.
  final bool followMode;

  const MapState({
    this.center,
    this.zoom = 14.0,
    this.selectedCellId,
    this.followMode = true,
  });

  MapState copyWith({
    Geographic? center,
    double? zoom,
    String? selectedCellId,
    bool? followMode,
    bool clearSelectedCell = false,
  }) =>
      MapState(
        center: center ?? this.center,
        zoom: zoom ?? this.zoom,
        selectedCellId:
            clearSelectedCell ? null : (selectedCellId ?? this.selectedCellId),
        followMode: followMode ?? this.followMode,
      );
}

// ---------------------------------------------------------------------------
// Provider + Notifier
// ---------------------------------------------------------------------------

final mapStateProvider =
    NotifierProvider<MapStateNotifier, MapState>(MapStateNotifier.new);

class MapStateNotifier extends Notifier<MapState> {
  @override
  MapState build() => const MapState();

  void updateCamera({required Geographic center, double? zoom}) =>
      state = state.copyWith(center: center, zoom: zoom);

  void setZoom(double zoom) => state = state.copyWith(zoom: zoom);

  void selectCell(String cellId) =>
      state = state.copyWith(selectedCellId: cellId);

  void clearSelectedCell() => state = state.copyWith(clearSelectedCell: true);

  void setFollowMode(bool follow) => state = state.copyWith(followMode: follow);
}
