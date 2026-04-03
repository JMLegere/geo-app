import 'package:flutter/material.dart';

import 'package:earth_nova/providers/map_state_provider.dart';

/// Toggle-able debug overlay for the map screen.
///
/// Displays a semi-transparent terminal-style panel with live diagnostics:
/// camera position, zoom level, follow/free mode, visible cell count,
/// visited cell count, and map readiness state.
///
/// The container background derives from
/// [ColorScheme.surfaceContainerHighest] at high opacity so it integrates
/// with both dark and light themes.  Text uses the classic terminal
/// spring-green (`#00FF7F`) for instant visual distinction from game UI.
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

  const DebugHud({
    super.key,
    required this.mapState,
    required this.visibleCells,
    required this.visitedCells,
  });

  @override
  Widget build(BuildContext context) {
    final lat = mapState.center?.lat.toStringAsFixed(4) ?? '—';
    final lon = mapState.center?.lon.toStringAsFixed(4) ?? '—';
    final zoom = mapState.zoom.toStringAsFixed(1);
    final ready = mapState.center != null ? 'ready' : 'waiting';

    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF00FF7F).withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 11,
          color: Color(0xFF00FF7F), // spring green — intentional terminal look
          height: 1.6,
          decoration: TextDecoration.none,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('cam: ($lat, $lon)'),
            Text('zoom: $zoom'),
            const Text('mode: free'),
            Text('visible: $visibleCells cells'),
            Text('visited: $visitedCells cells'),
            Text('map: $ready'),
          ],
        ),
      ),
    );
  }
}
