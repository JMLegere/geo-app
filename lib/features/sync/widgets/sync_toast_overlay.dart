import 'dart:async';

import 'package:flutter/material.dart' hide Durations;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/features/sync/providers/sync_toast_provider.dart';
import 'package:earth_nova/shared/design_tokens.dart';
import 'package:earth_nova/shared/earth_nova_theme.dart';
import 'package:earth_nova/shared/widgets/frosted_glass_container.dart';

/// Animated pill toast that slides in from the bottom after a write queue
/// auto-flush completes.
///
/// ## Usage
///
/// Add to the map stack positioned above the tab bar:
///
/// ```dart
/// Positioned(
///   bottom: 72,
///   left: 0,
///   right: 0,
///   child: Center(
///     child: const SyncToastOverlay(),
///   ),
/// )
/// ```
///
/// ## Behaviour
/// - Watches [syncToastProvider] for active toast state.
/// - Slides in from below when a toast becomes active.
/// - Auto-dismisses after [Durations.syncToast] (2 seconds).
/// - Frosted-glass pill shape, consistent with other toast overlays.
class SyncToastOverlay extends ConsumerStatefulWidget {
  const SyncToastOverlay({super.key});

  @override
  ConsumerState<SyncToastOverlay> createState() => _SyncToastOverlayState();
}

class _SyncToastOverlayState extends ConsumerState<SyncToastOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _opacityAnimation;

  Timer? _dismissTimer;

  /// Tracks the last shown toast so the widget tree stays intact while
  /// the exit animation plays (provider state is already null by then).
  SyncToastType? _lastToastType;
  String _lastMessage = '';

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: Durations.slow,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: AppCurves.slideIn),
    );

    _opacityAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(
      CurvedAnimation(parent: _controller, curve: AppCurves.fadeIn),
    );

    _controller.addStatusListener((status) {
      // Once the exit animation finishes, clear local + provider state so
      // the widget tree collapses to SizedBox.shrink on the next frame.
      if (status == AnimationStatus.dismissed && mounted) {
        setState(() => _lastToastType = null);
        ref.read(syncToastProvider.notifier).dismiss();
      }
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _showToast(SyncToastState toastState) {
    _dismissTimer?.cancel();
    setState(() {
      _lastToastType = toastState.activeToast;
      _lastMessage = toastState.message ?? '';
    });
    _controller.forward(from: 0);
    _dismissTimer = Timer(Durations.syncToast, _beginDismiss);
  }

  /// Starts the exit animation, then clears provider state once complete.
  void _beginDismiss() {
    _controller.reverse();
    // Provider cleanup happens in the AnimationStatus.dismissed listener.
    // Clearing provider state here (not before reverse) ensures the widget
    // tree remains intact throughout the exit animation.
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<SyncToastState>(syncToastProvider, (previous, next) {
      final wasActive = previous?.hasActiveToast ?? false;
      final isActive = next.hasActiveToast;

      if (isActive && !wasActive) {
        _showToast(next);
      } else if (!isActive && wasActive) {
        // External dismiss (not from our timer) — animate out.
        _dismissTimer?.cancel();
        _controller.reverse();
      }
    });

    // Stay subscribed to provider changes but render from local state so
    // the widget tree survives through the exit animation.
    ref.watch(syncToastProvider);

    if (_lastToastType == null) return const SizedBox.shrink();

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _opacityAnimation,
        child: _SyncToastPill(
          type: _lastToastType!,
          message: _lastMessage,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Toast pill card
// ---------------------------------------------------------------------------

class _SyncToastPill extends StatelessWidget {
  final SyncToastType type;
  final String message;

  const _SyncToastPill({required this.type, required this.message});

  @override
  Widget build(BuildContext context) {
    final isSuccess = type == SyncToastType.success;
    final iconColor = isSuccess
        ? context.earthNova.successColor
        : Theme.of(context).colorScheme.error;

    return FrostedGlassContainer(
      isNotification: true,
      padding: EdgeInsets.symmetric(
        horizontal: Spacing.lg,
        vertical: Spacing.sm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSuccess ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
            size: 18,
            color: iconColor,
          ),
          SizedBox(width: Spacing.sm),
          Text(
            message,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}
