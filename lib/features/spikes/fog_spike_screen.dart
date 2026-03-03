import 'package:flutter/material.dart';
import 'package:maplibre/maplibre.dart';

import 'fog_shader_spike.dart';

/// Hardcoded player geographic position for the spike demo.
///
/// Centred on San Francisco for convenience — any tile provider works.
final Position _kPlayerPosition = Position(-122.4194, 37.7749);

/// Full spike screen: MapLibre map with fog-of-war overlay.
///
/// This widget is for **device testing only** — it requires a real GPU and a
/// connected network. It will not render correctly in headless CI.
///
/// Architecture:
/// ```
/// Scaffold
///  └── Stack
///       ├── MapLibreMap  (bottom — native platform view)
///       └── FogOverlayWidget  (top — Flutter CustomPaint, IgnorePointer)
/// ```
///
/// Camera sync strategy:
///   On every [MapEventMoveCamera] event the player's geographic position is
///   re-projected to screen coordinates via [MapController.toScreenLocation].
///   The [FogOverlayWidget] is rebuilt with the updated [Offset] so that the
///   clear region tracks the player as the camera moves.
class FogSpikeScreen extends StatefulWidget {
  /// Creates the [FogSpikeScreen].
  const FogSpikeScreen({super.key});

  @override
  State<FogSpikeScreen> createState() => _FogSpikeScreenState();
}

class _FogSpikeScreenState extends State<FogSpikeScreen> {
  MapController? _mapController;

  /// Player position in screen-pixel coordinates — updated on every camera
  /// move so the fog clear region stays pinned to the player.
  Offset _playerScreenPosition = Offset.zero;

  /// Whether the map + fog overlay are ready to render.
  bool _mapReady = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fog Shader Spike'),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // ── Map layer ──────────────────────────────────────────────────
          MapLibreMap(
            options: MapOptions(
              initStyle: 'https://demotiles.maplibre.org/style.json',
              initZoom: 13,
              initCenter: _kPlayerPosition,
            ),
            onMapCreated: _onMapCreated,
            onStyleLoaded: _onStyleLoaded,
            onEvent: _onMapEvent,
          ),

          // ── Fog overlay ────────────────────────────────────────────────
          if (_mapReady)
            FogOverlayWidget(
              playerScreenPosition: _playerScreenPosition,
              revealRadius: 150.0,
              fogDensity: 1.0,
            ),

          // ── Debug HUD ──────────────────────────────────────────────────
          Positioned(
            left: 8,
            bottom: 8,
            child: _DebugHud(
              playerScreenPosition: _playerScreenPosition,
              mapReady: _mapReady,
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Map callbacks
  // -------------------------------------------------------------------------

  void _onMapCreated(MapController controller) {
    _mapController = controller;
  }

  void _onStyleLoaded() {
    // Style loaded — now safe to project coordinates.
    _updatePlayerScreenPosition();
    setState(() => _mapReady = true);
  }

  Future<void> _onMapEvent(MapEvent event) async {
    if (event is MapEventMoveCamera) {
      await _updatePlayerScreenPosition();
    }
  }

  /// Projects the hardcoded player geographic position to screen coordinates
  /// and triggers a rebuild with the new [_playerScreenPosition].
  Future<void> _updatePlayerScreenPosition() async {
    final controller = _mapController;
    if (controller == null) return;

    final screenOffset =
        await controller.toScreenLocation(_kPlayerPosition);

    if (mounted) {
      setState(() => _playerScreenPosition = screenOffset);
    }
  }
}

// ---------------------------------------------------------------------------
// Debug HUD
// ---------------------------------------------------------------------------

/// Small semi-transparent debug panel showing live screen coordinates.
class _DebugHud extends StatelessWidget {
  const _DebugHud({
    required this.playerScreenPosition,
    required this.mapReady,
  });

  final Offset playerScreenPosition;
  final bool mapReady;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(153),
        borderRadius: BorderRadius.circular(4),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.white, fontSize: 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Map ready: $mapReady'),
            Text(
              'Player screen: '
              '(${playerScreenPosition.dx.toStringAsFixed(1)}, '
              '${playerScreenPosition.dy.toStringAsFixed(1)})',
            ),
            const Text('Reveal radius: 150 px'),
            const Text('Fog density: 1.0'),
          ],
        ),
      ),
    );
  }
}
