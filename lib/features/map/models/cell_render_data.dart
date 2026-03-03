import 'dart:ui';

import 'package:fog_of_world/core/models/fog_state.dart';

/// Immutable data class for passing cell rendering data to the fog painter.
///
/// Screen vertices are pre-projected to viewport coordinates by
/// `FogOverlayController` so the painter performs zero geo math at draw time.
class CellRenderData {
  /// Unique identifier for the Voronoi cell.
  final String cellId;

  /// Current fog visibility state for this cell.
  final FogState fogState;

  /// Polygon vertices in screen coordinates (viewport-relative pixels).
  /// Already projected by `MercatorProjection.geoToScreen`.
  /// Must contain at least 3 points to form a valid polygon.
  final List<Offset> screenVertices;

  const CellRenderData({
    required this.cellId,
    required this.fogState,
    required this.screenVertices,
  });

  @override
  String toString() =>
      'CellRenderData(cellId: $cellId, fogState: $fogState, '
      'vertices: ${screenVertices.length})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CellRenderData &&
          other.cellId == cellId &&
          other.fogState == fogState &&
          other.screenVertices == screenVertices;

  @override
  int get hashCode => Object.hash(cellId, fogState, screenVertices);
}
