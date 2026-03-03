import 'package:flutter/widgets.dart';

import 'package:fog_of_world/features/map/controllers/camera_controller.dart';
import 'package:fog_of_world/features/map/providers/map_state_provider.dart';

/// Toggle-able debug overlay for the map screen.
///
/// Displays a semi-transparent terminal-style panel with live diagnostics:
/// camera position, zoom level, follow/free mode, visible cell count,
/// visited cell count, and map readiness state.
///
/// Toggle visibility with the debug button in the map controls.
///
/// ## Usage
///
/// ```dart
/// if (_showDebugHud)
///   Positioned(
///     left: 8, bottom: 80,
///     child: DebugHud(
///       mapState: ref.watch(mapStateProvider),
///       visibleCells: _fogOverlayController.renderData.length,
///       visitedCells: _fogResolver.visitedCellIds.length,
///       cameraMode: ref.watch(cameraModeProvider),
///     ),
///   )
/// ```
class DebugHud extends StatelessWidget {
  /// Current map readiness and camera state.
  final MapState mapState;

  /// Number of fog cells currently projected to the viewport.
  final int visibleCells;

  /// Number of cells the player has physically visited.
  final int visitedCells;

  /// Current camera follow/free mode.
  final CameraMode cameraMode;

  const DebugHud({
    super.key,
    required this.mapState,
    required this.visibleCells,
    required this.visitedCells,
    required this.cameraMode,
  });

  @override
  Widget build(BuildContext context) {
    final lat = mapState.cameraLat?.toStringAsFixed(4) ?? '—';
    final lon = mapState.cameraLon?.toStringAsFixed(4) ?? '—';
    final zoom = mapState.zoom.toStringAsFixed(1);
    final ready = mapState.isReady ? 'ready' : 'waiting';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xE0000000),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 11,
          color: Color(0xFF00FF7F),
          height: 1.6,
          decoration: TextDecoration.none,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('cam: ($lat, $lon)'),
            Text('zoom: $zoom'),
            Text('mode: ${cameraMode.name}'),
            Text('visible: $visibleCells cells'),
            Text('visited: $visitedCells cells'),
            Text('map: $ready'),
          ],
        ),
      ),
    );
  }
}
