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
        backgroundColor: AppTheme.surface,
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Spacing.lg,
                    Spacing.sm,
                    Spacing.xl,
                    Spacing.xxl,
                  ),
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
                        icon: const Icon(
                          Icons.arrow_back,
                          color: AppTheme.onSurface,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
                      ),
                      const SizedBox(height: Spacing.sm),
                      _VenueHero(venue: venue),
                      const SizedBox(height: Spacing.xxl),
                      Text(
                        'Villagers and Services',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: AppTheme.onSurface,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                      ),
                      const SizedBox(height: Spacing.md),
                      if (venue.villagers.isEmpty)
                        const EarthNotice(
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

    return EarthPanel(
      title: venue.venue.displayName,
      eyebrow: 'Venue',
      tone: EarthPanelTone.accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppTheme.tertiary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(Radii.xxxl),
                  border: Border.all(
                    color: AppTheme.tertiary.withValues(alpha: 0.38),
                  ),
                ),
                child: SizedBox(
                  width: 54,
                  height: 54,
                  child: Center(
                    child: Text(
                      _initialsFor(venue.venue.displayName),
                      style: const TextStyle(
                        color: AppTheme.tertiary,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: Spacing.sm,
                      runSpacing: Spacing.sm,
                      children: [
                        EarthTag(label: _humanizeKind(venue.venue.kind)),
                        EarthTag(
                          label: venue.venue.anchorCellId,
                          tone: EarthTagTone.accent,
                        ),
                      ],
                    ),
                    const SizedBox(height: Spacing.sm),
                    Text(
                      'Town shows known Venues, introduced Villagers, and current Services.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.lg),
          EarthStatGrid(
            items: [
              EarthStatItem(
                label: 'Villagers',
                value: '${venue.villagers.length}',
                helper: _plural(venue.villagers.length, 'known Villager'),
              ),
              EarthStatItem(
                label: 'Services',
                value: '$serviceCount',
                helper: _plural(serviceCount, 'current Service'),
              ),
            ],
          ),
        ],
      ),
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
          if (villager != villagers.last) const SizedBox(height: Spacing.md),
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
    return EarthPanel(
      title: villager.villager.displayName,
      eyebrow: 'Villager • ${villager.villager.role}',
      child: villager.services.isEmpty
          ? const EarthNotice(
              title: 'No Services visible yet',
              message:
                  'Services appear here when this Villager currently provides one at this Venue.',
            )
          : Column(
              children: [
                for (final service in villager.services) ...[
                  _ServiceTile(service: service),
                  if (service != villager.services.last)
                    const SizedBox(height: Spacing.sm),
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHigh
            .withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(Radii.xl),
        border: Border.all(color: AppTheme.outline.withValues(alpha: 0.48)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(Radii.lg),
              ),
              child: const SizedBox(
                width: 38,
                height: 38,
                child: Icon(
                  Icons.room_service,
                  color: AppTheme.tertiary,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          service.service.displayName,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: AppTheme.onSurface,
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                      ),
                      const SizedBox(width: Spacing.sm),
                      const EarthTag(
                        label: 'Opening soon',
                        tone: EarthTagTone.warning,
                      ),
                    ],
                  ),
                  const SizedBox(height: Spacing.xs),
                  Text(
                    service.service.description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.onSurfaceVariant,
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
      .map((word) =>
          '${word.characters.first.toUpperCase()}${word.substring(1)}')
      .join(' ');
}

String _initialsFor(String value) {
  final words = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList(growable: false);
  if (words.isEmpty) return 'V';
  if (words.length == 1) {
    return words.single.characters.take(2).toString().toUpperCase();
  }
  return words
      .take(2)
      .map((word) => word.characters.first)
      .join()
      .toUpperCase();
}
