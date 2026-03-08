import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart' hide Durations;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/core/models/discovery_event.dart';
import 'package:earth_nova/features/discovery/providers/discovery_provider.dart';
import 'package:earth_nova/shared/design_tokens.dart';
import 'package:earth_nova/shared/earth_nova_theme.dart';
import 'package:earth_nova/shared/widgets/frosted_glass_container.dart';
import 'package:earth_nova/shared/widgets/rarity_badge.dart';

/// Maximum number of stacked cards rendered simultaneously.
const _kMaxVisibleCards = 3;

/// Vertical offset between stacked cards (in logical pixels).
const _kStackOffsetY = 8.0;

/// Horizontal padding increase per stack level (each side).
const _kStackPaddingX = 4.0;

/// Opacity reduction per stack level.
const _kStackOpacityStep = 0.15;

/// Animated overlay that slides in from above when species are discovered.
///
/// ## Queue-based stacking
///
/// Multiple discoveries queue up and render as a visual stack (up to
/// [_kMaxVisibleCards] cards). The top card auto-dismisses after
/// [Durations.discoveryToast], then the next card promotes to the top.
///
/// ## Usage
///
/// Add between StatusBar (layer 4) and DebugHud (layer 5) in `MapScreen`:
///
/// ```dart
/// Positioned(
///   top: MediaQuery.of(context).padding.top + 64,
///   left: 16,
///   right: 16,
///   child: const DiscoveryNotificationOverlay(),
/// )
/// ```
class DiscoveryNotificationOverlay extends ConsumerStatefulWidget {
  const DiscoveryNotificationOverlay({super.key});

  @override
  ConsumerState<DiscoveryNotificationOverlay> createState() =>
      _DiscoveryNotificationOverlayState();
}

class _DiscoveryNotificationOverlayState
    extends ConsumerState<DiscoveryNotificationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _opacityAnimation;

  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: Durations.slow,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: AppCurves.slideIn));

    _opacityAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: AppCurves.fadeIn));
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startDismissTimer() {
    _dismissTimer?.cancel();
    _dismissTimer = Timer(Durations.discoveryToast, () {
      if (mounted) {
        ref.read(discoveryProvider.notifier).dismissNotification();
      }
    });
  }

  void _showStack() {
    _controller.forward(from: 0);
    _startDismissTimer();
  }

  void _hideStack() {
    _dismissTimer?.cancel();
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<DiscoveryState>(discoveryProvider, (previous, next) {
      final wasActive = previous?.hasActiveNotification ?? false;
      final isActive = next.hasActiveNotification;

      if (isActive && !wasActive) {
        // Queue went from empty → non-empty: slide in.
        _showStack();
      } else if (!isActive && wasActive) {
        // Queue went from non-empty → empty: slide out.
        _hideStack();
      } else if (isActive && wasActive) {
        // Queue still non-empty but top card may have changed (dismiss or new
        // item added). Reset the auto-dismiss timer for the new top card.
        final prevTop = previous?.currentNotification;
        final nextTop = next.currentNotification;
        if (prevTop != nextTop) {
          _startDismissTimer();
        }
      }
    });

    final state = ref.watch(discoveryProvider);
    final queue = state.notificationQueue;

    if (queue.isEmpty) return const SizedBox.shrink();

    final visibleCount = math.min(queue.length, _kMaxVisibleCards);

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _opacityAnimation,
        child: _NotificationStack(
          queue: queue,
          visibleCount: visibleCount,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stack layout
// ---------------------------------------------------------------------------

/// Renders up to [visibleCount] cards from [queue] as a visual stack.
///
/// Cards are painted bottom-to-top (deepest card first) so the top card
/// renders on top. Each deeper card gets:
/// - A downward Y offset ([_kStackOffsetY] per level)
/// - Increased horizontal padding ([_kStackPaddingX] per level each side)
/// - Reduced opacity ([_kStackOpacityStep] per level)
class _NotificationStack extends StatelessWidget {
  final List<DiscoveryEvent> queue;
  final int visibleCount;

  const _NotificationStack({
    required this.queue,
    required this.visibleCount,
  });

  @override
  Widget build(BuildContext context) {
    // Build cards bottom-to-top so the deepest card paints first.
    final children = <Widget>[];
    for (var i = visibleCount - 1; i >= 0; i--) {
      final event = queue[i];
      final opacity = (1.0 - i * _kStackOpacityStep).clamp(0.0, 1.0);
      final yOffset = i * _kStackOffsetY;
      final hPadding = i * _kStackPaddingX;

      children.add(
        Transform.translate(
          offset: Offset(0, yOffset),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: hPadding),
            child: Opacity(
              opacity: opacity,
              child: _DiscoveryCard(
                key: ValueKey(event.hashCode),
                event: event,
              ),
            ),
          ),
        ),
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: children,
    );
  }
}

// ---------------------------------------------------------------------------
// Card
// ---------------------------------------------------------------------------

class _DiscoveryCard extends StatelessWidget {
  final DiscoveryEvent event;

  const _DiscoveryCard({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final item = event.item;
    final rarity = item.rarity;
    final rarityColor = rarity != null
        ? EarthNovaTheme.rarityColor(rarity)
        : Theme.of(context).colorScheme.outline;

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return FrostedGlassContainer(
      isNotification: true,
      child: Row(
        children: [
          // Species icon placeholder
          Container(
            width: ComponentSizes.notificationIcon,
            height: ComponentSizes.notificationIcon,
            decoration: BoxDecoration(
              color: rarityColor.withValues(alpha: Opacities.badgeBackground),
              borderRadius: Radii.borderLg,
            ),
            child: const Center(
              child: Text(
                '🦎',
                style: TextStyle(fontSize: ComponentSizes.notificationEmoji),
              ),
            ),
          ),
          Spacing.gapHMd,

          // Species info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.displayName,
                  style: tt.titleSmall?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: Spacing.xxs),
                Text(
                  item.scientificName ?? '',
                  style: tt.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: cs.onSurfaceVariant,
                    letterSpacing: 0.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          Spacing.gapHSm,

          // Right column: rarity badge + collection status
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Rarity badge (hidden for items without conservation status)
              if (rarity != null)
                RarityBadge(status: rarity, size: RarityBadgeSize.medium),
              Spacing.gapXs,

              // Collection status
              Text(
                event.isNew ? 'NEW!' : 'Already collected',
                style: tt.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: event.isNew
                      ? Theme.of(context).colorScheme.tertiary
                      : cs.onSurfaceVariant,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
