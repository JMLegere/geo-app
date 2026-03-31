import 'package:flutter/material.dart' hide Durations;
import 'package:flutter/services.dart';

import 'package:earth_nova/features/map/models/hierarchy_level.dart';
import 'package:earth_nova/shared/constants.dart';
import 'package:earth_nova/shared/design_tokens.dart';

/// Placeholder hierarchy screen for levels that aren't fully implemented yet.
///
/// Shows the level name, a "Coming soon" message, and navigation controls.
/// Pinch out navigates to the level above, pinch in or back button navigates down.
class HierarchyStubOverlay extends StatefulWidget {
  const HierarchyStubOverlay({
    required this.level,
    required this.onNavigate,
    required this.onDismiss,
    super.key,
  });

  final HierarchyLevel level;

  /// Called when the user wants to navigate to a different level.
  /// Pass null to return to the map.
  final void Function(HierarchyLevel?) onNavigate;

  /// Called when dismissing (animation complete).
  final VoidCallback onDismiss;

  @override
  State<HierarchyStubOverlay> createState() => _HierarchyStubOverlayState();
}

class _HierarchyStubOverlayState extends State<HierarchyStubOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;
  bool _isDismissing = false;

  // Same colors as district infographic for visual consistency.
  static const _screenBg = Color(0xFF050C15);
  static const _heroPct = Color(0xFF83C5BE);
  static const _statLabel = Color(0xFFADB5BD);

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: Durations.slow, // 350ms
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: AppCurves.fadeIn);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _navigateDown() {
    if (_isDismissing) return;
    _isDismissing = true;
    HapticFeedback.mediumImpact();
    _fadeCtrl.reverse().then((_) {
      if (mounted) widget.onNavigate(widget.level.below);
    });
  }

  void _navigateUp() {
    final above = widget.level.above;
    if (above == null || _isDismissing) return;
    HapticFeedback.mediumImpact();
    widget.onNavigate(above);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return FadeTransition(
      opacity: _fadeAnim,
      child: GestureDetector(
        onScaleUpdate: (details) {
          // Pinch in → navigate down
          if (details.scale > kInfographicPinchInThreshold) {
            _navigateDown();
          }
          // Pinch out → navigate up (only if not at top)
          if (details.pointerCount >= 2 &&
              details.scale < kInfographicPinchOutThreshold &&
              widget.level.above != null) {
            _navigateUp();
          }
        },
        child: Container(
          color: _screenBg,
          child: SafeArea(
            child: Column(
              children: [
                // Header with back button
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: _navigateDown,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: Radii.borderXl,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                          ),
                          child: const Icon(Icons.arrow_back,
                              color: Colors.white70, size: 20),
                        ),
                      ),
                      Spacing.gapHSm,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.level.label,
                              style: theme.headlineSmall
                                  ?.copyWith(color: Colors.white),
                            ),
                            Text(
                              '${widget.level.label.toUpperCase()} VIEW',
                              style: theme.bodySmall?.copyWith(
                                color: _statLabel,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Center content
                const Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '🗺',
                          style: TextStyle(fontSize: 48),
                        ),
                        SizedBox(height: Spacing.lg),
                        Text(
                          'Coming soon',
                          style: TextStyle(
                            color: _heroPct,
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: Spacing.sm),
                        Text(
                          'Pinch in to go back',
                          style: TextStyle(
                            color: _statLabel,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
