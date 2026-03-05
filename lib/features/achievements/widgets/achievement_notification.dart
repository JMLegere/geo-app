import 'dart:async';

import 'package:flutter/material.dart' hide Durations;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fog_of_world/features/achievements/models/achievement.dart';
import 'package:fog_of_world/features/achievements/providers/achievement_provider.dart';
import 'package:fog_of_world/shared/design_tokens.dart';
import 'package:fog_of_world/shared/earth_nova_theme.dart';
import 'package:fog_of_world/shared/widgets/frosted_glass_container.dart';

/// Animated overlay toast that slides in from above when an achievement unlocks.
///
/// ## Usage
///
/// Add to the widget stack above the map layer (e.g. in `MapScreen`):
///
/// ```dart
/// Positioned(
///   top: MediaQuery.of(context).padding.top + 64,
///   left: 16,
///   right: 16,
///   child: const AchievementNotificationOverlay(),
/// )
/// ```
///
/// ## Behaviour
/// - Watches [achievementNotificationProvider] for active notifications.
/// - Slides in from above when a notification becomes active.
/// - Auto-dismisses after [Durations.achievementToast].
/// - Frosted-glass Apple Maps aesthetic, consistent with `DiscoveryNotificationOverlay`.
class AchievementNotificationOverlay extends ConsumerStatefulWidget {
  const AchievementNotificationOverlay({super.key});

  @override
  ConsumerState<AchievementNotificationOverlay> createState() =>
      _AchievementNotificationOverlayState();
}

class _AchievementNotificationOverlayState
    extends ConsumerState<AchievementNotificationOverlay>
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
    ).animate(
      CurvedAnimation(parent: _controller, curve: AppCurves.slideIn),
    );

    _opacityAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(
      CurvedAnimation(parent: _controller, curve: AppCurves.fadeIn),
    );
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
    _dismissTimer = Timer(Durations.achievementToast, () {
      if (mounted) {
        ref
            .read(achievementNotificationProvider.notifier)
            .dismissNotification();
      }
    });
  }

  void _hideNotification() {
    _dismissTimer?.cancel();
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AchievementNotificationState>(
      achievementNotificationProvider,
      (previous, next) {
        final wasActive = previous?.hasActiveNotification ?? false;
        final isActive = next.hasActiveNotification;

        if (isActive && !wasActive) {
          _showNotification();
        } else if (!isActive && wasActive) {
          _hideNotification();
        }
      },
    );

    final notifState = ref.watch(achievementNotificationProvider);
    final currentId = notifState.currentNotification;

    if (currentId == null) return const SizedBox.shrink();

    final def = kAchievementDefinitions[currentId];
    if (def == null) return const SizedBox.shrink();

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _opacityAnimation,
        child: _AchievementToast(definition: def),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Toast card
// ---------------------------------------------------------------------------

class _AchievementToast extends StatelessWidget {
  final AchievementDefinition definition;

  const _AchievementToast({required this.definition});

  @override
  Widget build(BuildContext context) {
    return FrostedGlassContainer(
      isNotification: true,
      child: Row(
        children: [
          // Emoji icon
          Container(
            width: ComponentSizes.notificationIcon,
            height: ComponentSizes.notificationIcon,
            decoration: BoxDecoration(
              color: context.earthNova.successContainerColor,
              borderRadius: Radii.borderLg,
            ),
            child: Center(
              child: Text(
                definition.emoji,
                style: const TextStyle(fontSize: ComponentSizes.notificationEmoji),
              ),
            ),
          ),
          Spacing.gapHMd,

          // Achievement info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  definition.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: Spacing.xxs),
                Text(
                  definition.description,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    letterSpacing: 0.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          Spacing.gapHSm,

          // "Achievement Unlocked!" badge
          Container(
            padding: EdgeInsets.symmetric(horizontal: Spacing.md, vertical: 5),
            decoration: BoxDecoration(
              color: context.earthNova.successColor,
              borderRadius: Radii.borderMd,
            ),
            child: const Text(
              'Achievement\nUnlocked!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.3,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
