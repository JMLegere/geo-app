import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/features/living_world/domain/entities/npc_venue.dart';
import 'package:earth_nova/features/living_world/presentation/providers/npc_venue_provider.dart';
import 'package:earth_nova/features/living_world/presentation/widgets/npc_venue_detail_sheet.dart';
import 'package:earth_nova/shared/observability/widgets/observable_interaction.dart';
import 'package:earth_nova/shared/product/player_actions.dart';
import 'package:earth_nova/shared/observability/widgets/observable_screen.dart';
import 'package:earth_nova/shared/theme/app_theme.dart';

class TownScreen extends ConsumerStatefulWidget {
  const TownScreen({super.key});

  @override
  ConsumerState<TownScreen> createState() => _TownScreenState();
}

class _TownScreenState extends ConsumerState<TownScreen> {
  @override
  Widget build(BuildContext context) {
    final obs = ref.watch(appObservabilityProvider);
    final npcVenueState = ref.watch(npcVenueProvider);

    return ObservableScreen(
      screenName: 'town_screen',
      observability: obs,
      builder: (_) => Scaffold(
        backgroundColor: AppTheme.surface,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Town',
                  style: TextStyle(
                    color: AppTheme.onSurface,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'People and places you have found while exploring.',
                  style: TextStyle(
                    color: AppTheme.onSurfaceVariant.withValues(alpha: 0.86),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                if (npcVenueState.discoveredVenue == null)
                  const _TownEmptyState()
                else
                  _TownVenueRow(
                    venue: npcVenueState.discoveredVenue!,
                    logger: ({required event, required category, data}) {
                      ref.read(appObservabilityProvider).log(
                            event,
                            category,
                            data: data,
                          );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TownEmptyState extends StatelessWidget {
  const _TownEmptyState();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'No local places discovered yet',
              style: TextStyle(
                color: AppTheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Explore the map to meet local characters and uncover their places.',
              style: TextStyle(
                color: AppTheme.onSurfaceVariant.withValues(alpha: 0.84),
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TownVenueRow extends StatelessWidget {
  const _TownVenueRow({required this.venue, required this.logger});

  final NpcVenue venue;
  final InteractionLogger logger;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: ObservableInteraction.wrapVoidCallback(
        logger: logger,
        screenName: 'town_screen',
        widgetName: 'town_venue_row',
        actionType: 'open_npc_led_feature',
        playerActionId: PlayerActions.openNpcLedFeature,
        payload: {
          'venue_id': venue.id,
          'venue_kind': venue.kind.name,
          'feature_name': venue.featureName,
        },
        callback: () {
          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            builder: (ctx) => NpcVenueDetailSheet(venue: venue),
          );
        },
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.outline),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.tertiary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text(
                  'WR',
                  style: TextStyle(
                    color: AppTheme.tertiary,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    venue.venueName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${venue.npcName}  •  ${venue.featureName}  •  Coming soon',
                    style: TextStyle(
                      color: AppTheme.onSurfaceVariant.withValues(alpha: 0.72),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: AppTheme.onSurfaceVariant.withValues(alpha: 0.5),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
