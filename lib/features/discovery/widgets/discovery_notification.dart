import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fog_of_world/core/models/iucn_status.dart';
import 'package:fog_of_world/features/discovery/models/discovery_event.dart';
import 'package:fog_of_world/features/discovery/providers/discovery_provider.dart';

/// Duration the discovery card is visible before auto-dismissing.
const _kAutoDissmissDuration = Duration(seconds: 3);

/// Duration of the slide-in / slide-out animation.
const _kAnimationDuration = Duration(milliseconds: 350);

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
/// - Auto-dismisses after [_kAutoDissmissDuration] by calling
///   [DiscoveryNotifier.dismissNotification].
/// - Apple Maps aesthetic: rounded corners, frosted glass, soft shadow.
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
      duration: _kAnimationDuration,
    );

    // Slides in from above: starts translated -100% (its own height) upward.
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _opacityAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
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
    _dismissTimer = Timer(_kAutoDissmissDuration, () {
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
    final rarityColor = _rarityColor(species.iucnStatus);
    final rarityLabel = _rarityLabel(species.iucnStatus);

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
              // Species icon placeholder
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: rarityColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    '🦎',
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Species info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      species.commonName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A2E),
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      species.scientificName,
                      style: const TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
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

              // Right column: rarity badge + collection status
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Rarity badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: rarityColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      rarityLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: rarityColor == const Color(0xFFFFEB3B)
                            ? const Color(0xFF1A1A2E)
                            : Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Collection status
                  Text(
                    event.isNew ? 'NEW!' : 'Already collected',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: event.isNew
                          ? const Color(0xFF16A34A)
                          : const Color(0xFF9CA3AF),
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Rarity badge colors per task spec: LC=green, NT=yellow, VU=orange,
  /// EN=red, CR=darkRed, EX=black.
  Color _rarityColor(IucnStatus status) => switch (status) {
        IucnStatus.leastConcern => const Color(0xFF4CAF50),
        IucnStatus.nearThreatened => const Color(0xFFFFEB3B),
        IucnStatus.vulnerable => const Color(0xFFFF9800),
        IucnStatus.endangered => const Color(0xFFF44336),
        IucnStatus.criticallyEndangered => const Color(0xFFB71C1C),
        IucnStatus.extinct => const Color(0xFF000000),
      };

  /// Short IUCN code for the badge label.
  String _rarityLabel(IucnStatus status) => switch (status) {
        IucnStatus.leastConcern => 'LC',
        IucnStatus.nearThreatened => 'NT',
        IucnStatus.vulnerable => 'VU',
        IucnStatus.endangered => 'EN',
        IucnStatus.criticallyEndangered => 'CR',
        IucnStatus.extinct => 'EX',
      };
}
