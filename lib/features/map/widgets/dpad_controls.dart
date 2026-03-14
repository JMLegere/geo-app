import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/core/state/location_provider.dart';
import 'package:earth_nova/features/location/services/keyboard_location_service.dart';
import 'package:earth_nova/shared/constants.dart';

/// On-screen directional pad for mobile web users who have no physical keyboard.
///
/// Renders a diamond/cross layout (Up on top, Left-Down-Right in a row below)
/// with 48×48 circular buttons matching the MapControls styling.
///
/// Tapping a button fires a single 10-metre step. Long-pressing starts a
/// periodic timer at 100 ms intervals (the same cadence as the keyboard
/// ticker) so sustained movement feels identical to holding a key.
///
/// Only shown on web — guard the instantiation site with kIsWeb.
class DPadControls extends ConsumerStatefulWidget {
  /// The keyboard service that receives [KeyboardLocationService.moveStep]
  /// calls. On web this is always non-null.
  final KeyboardLocationService keyboardService;

  const DPadControls({super.key, required this.keyboardService});

  @override
  ConsumerState<DPadControls> createState() => _DPadControlsState();
}

class _DPadControlsState extends ConsumerState<DPadControls> {
  static const _stepMeters = kWebKeyboardStepMeters;
  static const _earthRadius = 6371000.0;
  static const _tickInterval =
      Duration(milliseconds: kWebKeyboardTickIntervalMs);

  Timer? _longPressTimer;

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }

  void _step(double dLatSign, double dLonSign) {
    HapticFeedback.selectionClick();
    final currentLat =
        ref.read(locationProvider).currentPosition?.lat ?? 45.9636;
    final metersPerDegLat = _earthRadius * (pi / 180.0);
    final metersPerDegLon = metersPerDegLat * cos(currentLat * pi / 180.0);
    final dLat = dLatSign * _stepMeters / metersPerDegLat;
    final dLon = dLonSign * _stepMeters / metersPerDegLon;
    widget.keyboardService.moveStep(dLat, dLon);
  }

  void _startLongPress(double dLatSign, double dLonSign) {
    _longPressTimer?.cancel();
    _longPressTimer = Timer.periodic(_tickInterval, (_) {
      _step(dLatSign, dLonSign);
    });
  }

  void _stopLongPress() {
    _longPressTimer?.cancel();
    _longPressTimer = null;
  }

  Widget _dirButton(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required double dLatSign,
    required double dLonSign,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: () => _step(dLatSign, dLonSign),
        onLongPressStart: (_) => _startLongPress(dLatSign, dLonSign),
        onLongPressEnd: (_) => _stopLongPress(),
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(24),
          color: cs.surfaceContainerHigh.withValues(alpha: 0.85),
          shadowColor: cs.shadow.withValues(alpha: 0.4),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(
              icon,
              size: 22,
              color: cs.primary,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const gap = 4.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Top row: empty | Up | empty
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 48 + gap),
            _dirButton(
              context,
              icon: Icons.arrow_upward,
              tooltip: 'Move north',
              dLatSign: 1,
              dLonSign: 0,
            ),
            const SizedBox(width: 48 + gap),
          ],
        ),
        const SizedBox(height: gap),
        // Bottom row: Left | Down | Right
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dirButton(
              context,
              icon: Icons.arrow_back,
              tooltip: 'Move west',
              dLatSign: 0,
              dLonSign: -1,
            ),
            const SizedBox(width: gap),
            _dirButton(
              context,
              icon: Icons.arrow_downward,
              tooltip: 'Move south',
              dLatSign: -1,
              dLonSign: 0,
            ),
            const SizedBox(width: gap),
            _dirButton(
              context,
              icon: Icons.arrow_forward,
              tooltip: 'Move east',
              dLatSign: 0,
              dLonSign: 1,
            ),
          ],
        ),
      ],
    );
  }
}
