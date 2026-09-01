import 'package:flutter/material.dart';

import 'package:earth_nova/core/domain/entities/habitat.dart';
import 'package:earth_nova/features/living_world/domain/entities/town_projection.dart';
import 'package:earth_nova/features/living_world/presentation/screens/venue_detail_screen.dart';
import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/features/map/domain/entities/cell_state.dart';
import 'package:earth_nova/shared/design.dart';
import 'package:earth_nova/shared/product/player_actions.dart';
import 'package:earth_nova/shared/product/product_action_surface.dart';

class CellDetailSheet extends StatelessWidget {
  const CellDetailSheet({
    super.key,
    required this.cell,
    required this.visitCount,
    required this.isFirstVisit,
    required this.currentRelationship,
    this.knowledgeState,
    this.category,
    this.knownVenues = const [],
  });

  final Cell cell;
  final int visitCount;
  final bool isFirstVisit;
  final CellRelationship currentRelationship;
  final CellKnowledgeState? knowledgeState;
  final String? category;
  final List<TownVenue> knownVenues;

  @override
  Widget build(BuildContext context) {
    final disclosureState =
        knowledgeState == CellKnowledgeState.informed &&
            (category == null || category!.isEmpty)
        ? CellKnowledgeState.shrouded
        : knowledgeState;
    final restrictsDetail =
        disclosureState == CellKnowledgeState.shrouded ||
        disclosureState == CellKnowledgeState.informed;
    final habitatLabel = _habitatLabelFor(cell);

    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(Radii.xxl),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Spacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(
                child: ExcludeSemantics(child: Icon(Icons.drag_handle)),
              ),
              const SizedBox(height: Spacing.sm),
              AppCard(
                title: restrictsDetail
                    ? 'Cell details'
                    : 'Cell ${_truncateId(cell.id)}',
                description: restrictsDetail
                    ? disclosureState == CellKnowledgeState.informed
                          ? _categoryLabel(category!)
                          : 'Unrevealed area'
                    : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: AppBadge(
                        label: restrictsDetail
                            ? _stateLabel(disclosureState)
                            : habitatLabel,
                        variant: AppBadgeVariant.outline,
                      ),
                    ),
                    if (!restrictsDetail) ...[
                      const SizedBox(height: Spacing.sm),
                      AppFieldRow(
                        label: 'Visits',
                        value:
                            '$visitCount ${visitCount == 1 ? 'time' : 'times'}',
                      ),
                      AppFieldRow(
                        label: 'Cell state',
                        value: _stateLabel(disclosureState),
                      ),
                      if (isFirstVisit)
                        const AppFieldRow(
                          label: 'Status',
                          value: 'First discovery!',
                        ),
                      if (knownVenues.isNotEmpty) ...[
                        const SizedBox(height: Spacing.sm),
                        const Divider(),
                        const SizedBox(height: Spacing.lg),
                        Text(
                          'Known Venues',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: Spacing.md),
                        for (final venue in knownVenues) ...[
                          ProductActionSurface(
                            actionId: PlayerActions.openNpcVenueDetail,
                            child: _VenueSheetRow(
                              venue: venue,
                              onOpen: () => _openVenueDetail(context, venue),
                            ),
                          ),
                          if (venue != knownVenues.last)
                            const Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: Spacing.md,
                              ),
                              child: Divider(),
                            ),
                        ],
                      ],
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openVenueDetail(BuildContext context, TownVenue venue) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => VenueDetailScreen(venue: venue),
          ),
        );
      });
      return;
    }

    navigator.push(
      MaterialPageRoute<void>(builder: (_) => VenueDetailScreen(venue: venue)),
    );
  }

  String _stateLabel(CellKnowledgeState? state) {
    return switch (state) {
      CellKnowledgeState.present => 'Present',
      CellKnowledgeState.informed => 'Informed',
      CellKnowledgeState.explored => 'Explored',
      CellKnowledgeState.shrouded => 'Shrouded',
      null => _relationshipLabel(currentRelationship),
    };
  }

  String _categoryLabel(String value) {
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }

  String _relationshipLabel(CellRelationship relationship) {
    return switch (relationship) {
      CellRelationship.present => 'Present',
      CellRelationship.explored => 'Explored',
      CellRelationship.frontier => 'Frontier',
      CellRelationship.unknown => 'Unknown',
    };
  }

  String _habitatLabelFor(Cell cell) {
    final habitats = cell.habitats;
    final isLegacyPlainsFallback =
        !cell.hasVerifiedHabitat &&
        habitats.length == 1 &&
        habitats.single == Habitat.plains;
    if (habitats.isEmpty || isLegacyPlainsFallback) {
      return 'Terrain unclassified';
    }
    return habitats.map((habitat) => habitat.label).join(' / ');
  }

  String _truncateId(String id) {
    if (id.length <= 8) return id;
    return '${id.substring(0, 4)}...${id.substring(id.length - 4)}';
  }
}

class _VenueSheetRow extends StatelessWidget {
  const _VenueSheetRow({required this.venue, required this.onOpen});

  final TownVenue venue;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final villagerCount = venue.villagers.length;
    final serviceCount = _serviceCountFor(venue);
    final summary = villagerCount == 0
        ? 'No Villagers introduced here yet'
        : '${_countLabel(villagerCount, 'Villager')}  •  '
              '${_countLabel(serviceCount, 'Service')}  •  Opening soon';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          label: '${venue.venue.displayName}. $summary',
          onTap: onOpen,
          child: ExcludeSemantics(
            // eac-clickable-owner-logs: enclosing ProductActionSurface(PlayerActions.openNpcVenueDetail) owns both this label InkWell and the AppButton action evidence.
            child: InkWell(
              borderRadius: BorderRadius.circular(Radii.sm),
              onTap: onOpen,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: kMinInteractiveDimension,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        venue.venue.displayName,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: Spacing.xs),
                      Text(summary),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: Spacing.sm),
        AppButton(
          label: 'Open ${venue.venue.displayName}',
          expand: true,
          onPressed: onOpen,
        ),
      ],
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

String _countLabel(int count, String label) {
  if (count == 1) return '1 $label';
  return '$count ${label}s';
}
