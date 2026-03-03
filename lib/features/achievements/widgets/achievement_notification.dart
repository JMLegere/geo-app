import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fog_of_world/features/achievements/models/achievement.dart';
import 'package:fog_of_world/features/achievements/providers/achievement_provider.dart';

/// Duration the achievement toast is visible before auto-dismissing.
const _kAutoDismissDuration = Duration(seconds: 4);

/// Duration of the slide-in / slide-out animation.
const _kAnimationDuration = Duration(milliseconds: 350);

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
/// - Auto-dismisses after [_kAutoDismissDuration].
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
      duration: _kAnimationDuration,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _opacityAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
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
    _dismissTimer = Timer(_kAutoDismissDuration, () {
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.6),
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              // Emoji icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    definition.emoji,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Achievement info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      definition.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A2E1B),
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      definition.description,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6B7280),
                        letterSpacing: 0.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // "Achievement Unlocked!" badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(8),
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
        ),
      ),
    );
  }
}
