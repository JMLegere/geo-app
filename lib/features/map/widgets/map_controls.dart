import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Floating action buttons for the map screen.
///
/// Stacked vertically with 8 px gap:
/// - Recenter button (always visible): compass/crosshair icon snaps camera
///   back to the player and resumes follow mode.
/// - Debug toggle (kDebugMode only): opens/closes the debug HUD overlay.
///
/// Colours adapt to the active theme via [Theme.of] — primary colour for
/// icons, surfaceContainer for the button background.
///
/// ## Usage
///
/// ```dart
/// Positioned(
///   right: 16, bottom: 16,
///   child: MapControls(
///     onRecenter: _cameraController.recenter,
///     onToggleDebug: () => setState(() => _showDebug = !_showDebug),
///   ),
/// )
/// ```
class MapControls extends StatelessWidget {
  /// Called when the recenter button is tapped.
  final VoidCallback onRecenter;

  /// Called when the debug toggle button is tapped. Only visible in debug builds.
  final VoidCallback onToggleDebug;

  /// Called when the zoom level toggle is tapped.
  final VoidCallback onToggleZoom;

  /// Whether the current zoom preset is world (true) or player (false).
  final bool isWorldZoom;

  const MapControls({
    super.key,
    required this.onRecenter,
    required this.onToggleDebug,
    required this.onToggleZoom,
    this.isWorldZoom = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (kDebugMode) ...[
          _ControlButton(
            icon: Icons.bug_report_outlined,
            tooltip: 'Toggle debug HUD',
            onPressed: onToggleDebug,
          ),
          const SizedBox(height: 8),
        ],
        _ControlButton(
          icon: isWorldZoom ? Icons.person_pin_circle : Icons.public,
          tooltip: isWorldZoom ? 'Zoom to player' : 'Zoom to world',
          onPressed: onToggleZoom,
        ),
        const SizedBox(height: 8),
        _ControlButton(
          icon: Icons.my_location,
          tooltip: 'Recenter map',
          onPressed: onRecenter,
        ),
      ],
    );
  }
}

/// A single circular floating control button.
class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _ControlButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(28),
        color: cs.surfaceContainerHigh,
        shadowColor: cs.shadow.withValues(alpha: 0.4),
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onPressed();
          },
          borderRadius: BorderRadius.circular(28),
          child: SizedBox(
            width: 56,
            height: 56,
            child: Icon(
              icon,
              size: 24,
              color: cs.primary,
            ),
          ),
        ),
      ),
    );
  }
}
