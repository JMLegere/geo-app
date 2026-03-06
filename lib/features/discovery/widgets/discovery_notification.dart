import 'dart:async';

import 'package:flutter/material.dart' hide Durations;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fog_of_world/features/discovery/models/discovery_event.dart';
import 'package:fog_of_world/features/discovery/providers/discovery_provider.dart';
import 'package:fog_of_world/shared/design_tokens.dart';
import 'package:fog_of_world/shared/earth_nova_theme.dart';
import 'package:fog_of_world/shared/widgets/frosted_glass_container.dart';
import 'package:fog_of_world/shared/widgets/rarity_badge.dart';

/// Animated overlay card that slides in from above when a species is discovered.
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
///
/// ## Behaviour
/// - Watches [discoveryProvider] for [DiscoveryState.hasActiveNotification].
/// - Slides in (from above) when a notification becomes active.
/// - Auto-dismisses after [Durations.discoveryToast] by calling
///   [DiscoveryNotifier.dismissNotification].
/// - Frosted-glass aesthetic adapts to the active theme — dark surface tint
///   in dark mode, white tint in light mode.
/// - Rarity badge colours come from [EarthNovaTheme.rarityColor] for consistency.
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

    // Slides in from above: starts translated -100% (its own height) upward.
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

  void _showNotification() {
    _dismissTimer?.cancel();
    _controller.forward(from: 0);
    _dismissTimer = Timer(Durations.discoveryToast, () {
      if (mounted) {
        ref.read(discoveryProvider.notifier).dismissNotification();
      }
    });
  }

  void _hideNotification() {
    _dismissTimer?.cancel();
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<DiscoveryState>(discoveryProvider, (previous, next) {
      final wasActive = previous?.hasActiveNotification ?? false;
      final isActive = next.hasActiveNotification;

      if (isActive && !wasActive) {
        _showNotification();
      } else if (!isActive && wasActive) {
        _hideNotification();
      }
    });

    final state = ref.watch(discoveryProvider);
    final notification = state.currentNotification;

    if (notification == null) return const SizedBox.shrink();

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _opacityAnimation,
        child: _DiscoveryCard(event: notification),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Card
// ---------------------------------------------------------------------------

class _DiscoveryCard extends StatelessWidget {
  final DiscoveryEvent event;

  const _DiscoveryCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final species = event.species;
    final rarityColor = EarthNovaTheme.rarityColor(species.rarity!);

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
                  species.displayName,
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
                  species.scientificName!,
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
              // Rarity badge
              RarityBadge(status: species.rarity!, size: RarityBadgeSize.medium),
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
