import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/features/living_world/domain/entities/npc_venue.dart';
import 'package:earth_nova/shared/observability/widgets/observable_interaction.dart';
import 'package:earth_nova/shared/observability/widgets/observable_screen.dart';
import 'package:earth_nova/shared/product/player_actions.dart';
import 'package:earth_nova/shared/theme/app_theme.dart';

/// Dedicated NPC-first place page for a discovered venue and its authored services.
class NpcVenueDetailScreen extends ConsumerWidget {
  const NpcVenueDetailScreen({super.key, required this.venue});

  final NpcVenue venue;

  static const _screenName = 'npc_venue_detail_screen';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final obs = ref.watch(appObservabilityProvider);

    return ObservableScreen(
      screenName: _screenName,
      observability: obs,
      builder: (_) => Scaffold(
        backgroundColor: AppTheme.surface,
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        tooltip: 'Back',
                        onPressed: ObservableInteraction.wrapVoidCallback(
                          logger: ({required event, required category, data}) =>
                              obs.log(event, category, data: data),
                          screenName: _screenName,
                          widgetName: 'back_button',
                          actionType: 'navigate_back',
                          playerActionId: PlayerActions.openTown,
                          callback: () => Navigator.of(context).pop(),
                        ),
                        icon: const Icon(Icons.arrow_back,
                            color: AppTheme.onSurface),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _VenueHero(venue: venue),
                      const SizedBox(height: 24),
                      const Text(
                        'Features',
                        style: TextStyle(
                          color: AppTheme.onSurface,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _VenueFeatureCard(venue: venue),
                      const SizedBox(height: 24),
                      const Text(
                        'About this place',
                        style: TextStyle(
                          color: AppTheme.onSurface,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${venue.npcName} is preparing local release programs for animals that are ready to return to the wild.',
                        style: TextStyle(
                          color:
                              AppTheme.onSurfaceVariant.withValues(alpha: 0.82),
                          fontSize: 14,
                          height: 1.45,
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
    );
  }
}

class _VenueHero extends StatelessWidget {
  const _VenueHero({required this.venue});

  final NpcVenue venue;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: AppTheme.tertiary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Center(
                    child: Text(
                      _initialsFor(venue),
                      style: const TextStyle(
                        color: AppTheme.tertiary,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        venue.venueName,
                        style: const TextStyle(
                          color: AppTheme.onSurface,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          height: 1.05,
                          letterSpacing: -0.7,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        venue.npcName,
                        style: const TextStyle(
                          color: AppTheme.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        venue.npcRole,
                        style: TextStyle(
                          color:
                              AppTheme.onSurfaceVariant.withValues(alpha: 0.78),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VenueFeatureCard extends StatelessWidget {
  const _VenueFeatureCard({required this.venue});

  final NpcVenue venue;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(
                Icons.pets,
                color: AppTheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          venue.featureName,
                          style: const TextStyle(
                            color: AppTheme.onSurface,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const _ComingSoonPill(),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'One-off releases and local conservation programs will live here.',
                    style: TextStyle(
                      color: AppTheme.onSurfaceVariant.withValues(alpha: 0.76),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComingSoonPill extends StatelessWidget {
  const _ComingSoonPill();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFC857).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border:
            Border.all(color: const Color(0xFFFFC857).withValues(alpha: 0.4)),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          'Coming soon',
          style: TextStyle(
            color: Color(0xFFFFC857),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

String _initialsFor(NpcVenue venue) {
  final words = venue.npcName.trim().split(RegExp(r'\s+'));
  if (words.isEmpty || words.first.isEmpty) return 'NPC';
  return words.first.characters.take(2).toString().toUpperCase();
}
