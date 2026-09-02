import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/features/living_world/domain/entities/town_projection.dart';
import 'package:earth_nova/shared/design.dart';
import 'package:earth_nova/shared/observability/widgets/observable_interaction.dart';
import 'package:earth_nova/shared/observability/widgets/observable_screen.dart';
import 'package:earth_nova/shared/product/player_actions.dart';

/// Read-only Venue page for a known Town projection group.
class VenueDetailScreen extends ConsumerWidget {
  const VenueDetailScreen({super.key, required this.venue});

  final TownVenue venue;

  static const _screenName = 'venue_detail_screen';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final obs = ref.watch(appObservabilityProvider);

    return ObservableScreen(
      screenName: _screenName,
      observability: obs,
      builder: (_) => Scaffold(
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 48),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          IconButton(
                            tooltip: 'Back',
                            onPressed: ObservableInteraction.wrapVoidCallback(
                              logger:
                                  ({required event, required category, data}) =>
                                      obs.log(event, category, data: data),
                              screenName: _screenName,
                              widgetName: 'back_button',
                              actionType: 'navigate_back',
                              playerActionId: PlayerActions.openTown,
                              callback: () => Navigator.of(context).pop(),
                            ),
                            icon: const Icon(Icons.arrow_back),
                          ),
                          const SizedBox(height: 8),
                          _VenueHero(venue: venue),
                          const SizedBox(height: 32),
                          Text(
                            'Villagers and Services',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          if (venue.villagers.isEmpty)
                            const AppEmptyState(
                              title: 'No Villagers introduced here yet',
                              message:
                                  'This Venue is known. Town will update when Villagers are introduced here.',
                            )
                          else
                            _VillagerGroups(villagers: venue.villagers),
                        ],
                      ),
                    ),
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

  final TownVenue venue;

  @override
  Widget build(BuildContext context) {
    final serviceCount = _serviceCountFor(venue);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          title: venue.venue.displayName,
          description: 'Venue • ${_humanizeKind(venue.venue.kind)}',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppFieldRow(
                label: 'First known',
                value:
                    '${MaterialLocalizations.of(context).formatCompactDate(venue.knownVenue.revealedAt.toLocal())} • Version ${venue.knownVenue.venueVersion.revision}',
              ),
              const SizedBox(height: 8),
              Text(
                'This Venue shows its introduced Villagers and current Services.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppStatGrid(
          items: [
            AppStatItem(
              label: 'Villagers',
              value: '${venue.villagers.length}',
              helper: _plural(venue.villagers.length, 'known Villager'),
            ),
            AppStatItem(
              label: 'Services',
              value: '$serviceCount',
              helper: _plural(serviceCount, 'current Service'),
            ),
          ],
        ),
      ],
    );
  }
}

class _VillagerGroups extends StatelessWidget {
  const _VillagerGroups({required this.villagers});

  final List<TownVillager> villagers;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final villager in villagers) ...[
          _VillagerPanel(villager: villager),
          if (villager != villagers.last) const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _VillagerPanel extends StatelessWidget {
  const _VillagerPanel({required this.villager});

  final TownVillager villager;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      title: villager.villager.displayName,
      description: 'Villager • ${villager.villager.role}',
      child: villager.services.isEmpty
          ? const AppNotice(
              title: 'No Services visible yet',
              message:
                  'Services appear here when this Villager currently provides one at this Venue.',
            )
          : Column(
              children: [
                for (final service in villager.services) ...[
                  _ServiceTile(service: service),
                  if (service != villager.services.last) const Divider(),
                ],
              ],
            ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.service});

  final TownService service;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.room_service_outlined, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  service.service.displayName,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            service.service.description,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          const AppBadge(
            label: 'Opening soon',
            variant: AppBadgeVariant.outline,
          ),
        ],
      ),
    );
  }
}

int _serviceCountFor(TownVenue venue) {
  var count = 0;
  for (final villager in venue.villagers) {
    count += villager.services.length;
  }
  return count;
}

String _plural(int count, String label) {
  if (count == 1) return '1 $label';
  return '$count ${label}s';
}

String _humanizeKind(String kind) {
  final words = kind
      .replaceAll('_', '-')
      .split('-')
      .where((word) => word.trim().isNotEmpty)
      .toList(growable: false);
  if (words.isEmpty) return 'Venue';
  return words
      .map(
        (word) => '${word.characters.first.toUpperCase()}${word.substring(1)}',
      )
      .join(' ');
}
