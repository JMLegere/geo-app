import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/core/domain/entities/auth_state.dart';
import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/features/auth/presentation/providers/auth_provider.dart';
import 'package:earth_nova/features/living_world/domain/entities/town_projection.dart';
import 'package:earth_nova/features/living_world/presentation/providers/town_provider.dart';
import 'package:earth_nova/features/living_world/presentation/screens/venue_detail_screen.dart';
import 'package:earth_nova/shared/design.dart';
import 'package:earth_nova/shared/observability/widgets/observable_interaction.dart';
import 'package:earth_nova/shared/observability/widgets/observable_screen.dart';
import 'package:earth_nova/shared/product/player_actions.dart';

class TownScreen extends ConsumerStatefulWidget {
  const TownScreen({super.key});

  @override
  ConsumerState<TownScreen> createState() => _TownScreenState();
}

class _TownScreenState extends ConsumerState<TownScreen> {
  @override
  Widget build(BuildContext context) {
    final obs = ref.watch(appObservabilityProvider);
    final authState = ref.watch(authProvider);
    final townState = ref.watch(townProvider);
    _syncTownProjection(authState, townState);

    return ObservableScreen(
      screenName: 'town_screen',
      observability: obs,
      builder: (_) => Scaffold(
        backgroundColor: AppTheme.surface,
        body: SafeArea(
          child: RefreshIndicator(
            color: AppTheme.tertiary,
            backgroundColor: AppTheme.surfaceContainerHigh,
            onRefresh: () => _refreshTown(authState),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                Spacing.xl,
                Spacing.xxl,
                Spacing.xl,
                Spacing.huge,
              ),
              children: [
                Text(
                  'Town',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppTheme.onSurface,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.7,
                      ),
                ),
                const SizedBox(height: Spacing.sm),
                Text(
                  'Known Venues, introduced Villagers, and current Services.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                ),
                const SizedBox(height: Spacing.xxl),
                _TownBody(
                  authState: authState,
                  state: townState,
                  onRetry: () => _refreshTown(authState),
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

  void _syncTownProjection(AuthState authState, TownState townState) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (authState.status == AuthStatus.authenticated) {
        final playerId = authState.user!.id;
        if (ref.read(townProvider).shouldLoadFor(playerId)) {
          unawaited(ref.read(townProvider.notifier).load(playerId));
        }
        return;
      }
      if (townState.playerId != null || townState.town != null) {
        ref.read(townProvider.notifier).invalidate();
      }
    });
  }

  Future<void> _refreshTown(AuthState authState) async {
    if (authState.status != AuthStatus.authenticated) return;
    await ref.read(townProvider.notifier).refresh(authState.user!.id);
  }
}

class _TownBody extends StatelessWidget {
  const _TownBody({
    required this.authState,
    required this.state,
    required this.onRetry,
    required this.logger,
  });

  final AuthState authState;
  final TownState state;
  final Future<void> Function() onRetry;
  final InteractionLogger logger;

  @override
  Widget build(BuildContext context) {
    if (authState.status == AuthStatus.loading) {
      return const _TownLoadingState();
    }
    if (authState.status != AuthStatus.authenticated) {
      return const EarthNotice(
        title: 'Town unavailable',
        message: 'Sign in to view known Venues, Villagers, and Services.',
      );
    }

    final town = state.town;
    if (state.isLoading && town == null) {
      return const _TownLoadingState();
    }
    if (state.error != null && town == null) {
      return _TownErrorState(message: state.error!, onRetry: onRetry);
    }
    if (town == null || town.venues.isEmpty) {
      return const _TownEmptyState();
    }

    return _TownVenueList(town: town, logger: logger);
  }
}

class _TownLoadingState extends StatelessWidget {
  const _TownLoadingState();

  @override
  Widget build(BuildContext context) {
    return EarthPanel(
      title: 'Loading Town',
      eyebrow: 'Town projection',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gathering the places and people you know.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.onSurfaceVariant,
                  height: 1.4,
                ),
          ),
          const SizedBox(height: Spacing.md),
          const LoadingDots(),
        ],
      ),
    );
  }
}

class _TownErrorState extends StatelessWidget {
  const _TownErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EarthNotice(
          title: 'Town could not load',
          message: message,
          tone: EarthNoticeTone.warning,
        ),
        const SizedBox(height: Spacing.md),
        EarthActionButton(
          label: 'Retry Town load',
          actionId: null,
          icon: Icons.refresh,
          tone: EarthActionTone.secondary,
          onPressed: () => unawaited(onRetry()),
        ),
      ],
    );
  }
}

class _TownEmptyState extends StatelessWidget {
  const _TownEmptyState();

  @override
  Widget build(BuildContext context) {
    return const EarthNotice(
      title: 'No Venues known yet',
      message: 'Explore the Map to reveal a Venue.',
    );
  }
}

class _TownVenueList extends StatelessWidget {
  const _TownVenueList({required this.town, required this.logger});

  final TownProjection town;
  final InteractionLogger logger;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final venue in town.venues) ...[
          _TownVenueCard(venue: venue, logger: logger),
          if (venue != town.venues.last) const SizedBox(height: Spacing.md),
        ],
      ],
    );
  }
}

class _TownVenueCard extends StatelessWidget {
  const _TownVenueCard({required this.venue, required this.logger});

  final TownVenue venue;
  final InteractionLogger logger;

  @override
  Widget build(BuildContext context) {
    final serviceCount = _serviceCountFor(venue);

    return Semantics(
      button: true,
      label: 'Open ${venue.venue.displayName} Venue detail',
      child: GestureDetector(
        onTap: ObservableInteraction.wrapVoidCallback(
          logger: logger,
          screenName: 'town_screen',
          widgetName: 'town_venue_card',
          actionType: 'open_venue_detail',
          playerActionId: PlayerActions.openNpcVenueDetail,
          payload: {
            'venue_id': venue.venue.venue.id.value,
            'venue_kind': venue.venue.kind,
            'villager_count': venue.villagers.length,
            'service_count': serviceCount,
          },
          callback: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => VenueDetailScreen(venue: venue),
              ),
            );
          },
        ),
        child: EarthPanel(
          title: venue.venue.displayName,
          eyebrow: 'Venue • ${_humanizeKind(venue.venue.kind)}',
          actions: [
            EarthTag(label: '${venue.villagers.length} Villagers'),
            EarthTag(
                label: '$serviceCount Services', tone: EarthTagTone.accent),
          ],
          child: venue.villagers.isEmpty
              ? const EarthNotice(
                  title: 'No Villagers introduced here yet',
                  message:
                      'This Venue is known. Town will update when Villagers are introduced here.',
                )
              : _TownVillagerPreviewList(villagers: venue.villagers),
        ),
      ),
    );
  }
}

class _TownVillagerPreviewList extends StatelessWidget {
  const _TownVillagerPreviewList({required this.villagers});

  final List<TownVillager> villagers;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final villager in villagers) ...[
          _TownVillagerPreview(villager: villager),
          if (villager != villagers.last)
            const Divider(color: AppTheme.outline),
        ],
      ],
    );
  }
}

class _TownVillagerPreview extends StatelessWidget {
  const _TownVillagerPreview({required this.villager});

  final TownVillager villager;

  @override
  Widget build(BuildContext context) {
    final serviceSummary = villager.services.isEmpty
        ? 'No Services visible yet'
        : villager.services
            .map((service) => '${service.service.displayName} — Opening soon')
            .join('\n');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  villager.villager.displayName,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppTheme.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              const SizedBox(width: Spacing.sm),
              const EarthTag(label: 'Villager', tone: EarthTagTone.success),
            ],
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            villager.villager.role,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            serviceSummary,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.onSurface,
                  height: 1.35,
                ),
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
