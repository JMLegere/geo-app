import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/features/living_world/domain/entities/npc_venue.dart';
import 'package:earth_nova/features/living_world/presentation/providers/npc_venue_provider.dart';
import 'package:earth_nova/shared/observability/widgets/observable_screen.dart';
import 'package:earth_nova/shared/design.dart';
import 'package:earth_nova/shared/theme/app_theme.dart';

class TownScreen extends ConsumerWidget {
  const TownScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                const SizedBox(height: 24),
                if (npcVenueState.discoveredVenue == null)
                  const _TownEmptyState()
                else
                  _DiscoveredVenueCard(
                    venue: npcVenueState.discoveredVenue!,
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

class _DiscoveredVenueCard extends StatelessWidget {
  const _DiscoveredVenueCard({required this.venue});

  final NpcVenue venue;

  @override
  Widget build(BuildContext context) {
    return EarthPanel(
      eyebrow: 'Discovered place',
      title: venue.venueName,
      tone: EarthPanelTone.success,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EarthFieldRow(
            label: 'Caretaker',
            value: venue.npcName,
            helper: venue.npcRole,
          ),
          EarthFieldRow(
            label: 'Service',
            value: venue.featureName,
            helper: 'Not yet accepting releases.',
            trailing: const EarthTag(
              label: 'Opening soon',
              tone: EarthTagTone.warning,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${venue.npcName} is preparing local release programs for animals '
            'that are ready to return to the wild.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.onSurfaceVariant.withValues(alpha: 0.86),
                  height: 1.35,
                ),
          ),
        ],
      ),
    );
  }
}
