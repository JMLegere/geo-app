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
    final habitatDisplay = _habitatDisplayFor(cell);
    final primaryHabitat = habitatDisplay.primaryHabitat;
    final disclosureState = knowledgeState == CellKnowledgeState.informed &&
            (category == null || category!.isEmpty)
        ? CellKnowledgeState.shrouded
        : knowledgeState;
    final restrictsDetail = disclosureState == CellKnowledgeState.shrouded ||
        disclosureState == CellKnowledgeState.informed;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(color: Color(0xFF333333), width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF555555),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (restrictsDetail) ...[
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppTheme.tertiary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          disclosureState == CellKnowledgeState.informed
                              ? Icons.category_outlined
                              : Icons.visibility_off_outlined,
                          color: AppTheme.tertiary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              disclosureState == CellKnowledgeState.informed
                                  ? 'Informed'
                                  : 'Shrouded',
                              style: const TextStyle(
                                color: AppTheme.onSurface,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              disclosureState == CellKnowledgeState.informed
                                  ? _categoryLabel(category!)
                                  : 'Unrevealed area',
                              style: const TextStyle(
                                color: AppTheme.tertiary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: habitatDisplay.color.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _getHabitatIcon(primaryHabitat),
                          color: habitatDisplay.color,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cell ${_truncateId(cell.id)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              habitatDisplay.label,
                              style: TextStyle(
                                color: habitatDisplay.color,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildInfoRow(
                    icon: Icons.explore,
                    label: 'Visits',
                    value: '$visitCount ${visitCount == 1 ? 'time' : 'times'}',
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    icon: Icons.layers,
                    label: 'Cell state',
                    value: _stateLabel(disclosureState),
                    valueColor: _relationshipColor(currentRelationship),
                  ),
                  if (isFirstVisit) ...[
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      icon: Icons.auto_awesome,
                      label: 'Status',
                      value: 'First discovery!',
                      valueColor: const Color(0xFF4CAF50),
                    ),
                  ],
                  if (knownVenues.isNotEmpty) ...[
                    const SizedBox(height: Spacing.lg),
                    const Divider(color: AppTheme.outline, height: 1),
                    const SizedBox(height: Spacing.lg),
                    for (final venue in knownVenues) ...[
                      ProductActionSurface(
                        actionId: PlayerActions.openNpcVenueDetail,
                        child: GestureDetector(
                          onTap: () => _openVenueDetail(context, venue),
                          child: _VenueSheetRow(venue: venue),
                        ),
                      ),
                      if (venue != knownVenues.last)
                        const SizedBox(height: Spacing.sm),
                    ],
                  ],
                ],
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
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
      MaterialPageRoute<void>(
        builder: (_) => VenueDetailScreen(venue: venue),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF888888), size: 20),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF888888),
            fontSize: 14,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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

  Color _relationshipColor(CellRelationship relationship) {
    return switch (relationship) {
      CellRelationship.present => const Color(0xFF4CAF50),
      CellRelationship.explored => const Color(0xFFF1DEC0),
      CellRelationship.frontier => const Color(0xFFFFC857),
      CellRelationship.unknown => const Color(0xFFB0B0B0),
    };
  }

  _HabitatDisplay _habitatDisplayFor(Cell cell) {
    final habitats = cell.habitats;
    final isLegacyPlainsFallback = !cell.hasVerifiedHabitat &&
        habitats.length == 1 &&
        habitats.single == Habitat.plains;
    if (habitats.isEmpty || isLegacyPlainsFallback) {
      return const _HabitatDisplay(
        label: 'Terrain unclassified',
        color: Colors.grey,
        primaryHabitat: null,
      );
    }

    return _HabitatDisplay(
      label: habitats.map((h) => h.label).join(' / '),
      color: Color(habitats.first.colorValue),
      primaryHabitat: habitats.first,
    );
  }

  IconData _getHabitatIcon(Habitat? habitat) {
    return switch (habitat) {
      Habitat.forest => Icons.forest,
      Habitat.ocean => Icons.water,
      Habitat.freshwater => Icons.water_drop,
      Habitat.swamp => Icons.grass,
      Habitat.desert => Icons.wb_sunny,
      Habitat.plains => Icons.landscape,
      Habitat.urban => Icons.location_city,
      Habitat.mountain => Icons.terrain,
      null => Icons.help_outline,
    };
  }

  String _truncateId(String id) {
    if (id.length <= 8) return id;
    return '${id.substring(0, 4)}...${id.substring(id.length - 4)}';
  }
}

class _VenueSheetRow extends StatelessWidget {
  const _VenueSheetRow({required this.venue});

  final TownVenue venue;

  @override
  Widget build(BuildContext context) {
    final villagerCount = venue.villagers.length;
    final serviceCount = _serviceCountFor(venue);
    final summary = villagerCount == 0
        ? 'No Villagers introduced here yet'
        : '${_countLabel(villagerCount, 'Villager')}  •  '
            '${_countLabel(serviceCount, 'Service')}  •  Opening soon';

    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: Spacing.sm,
        horizontal: Spacing.md,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerHigh.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: AppTheme.outline.withValues(alpha: 0.62)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.tertiary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: Center(
              child: Text(
                _initialsFor(venue.venue.displayName),
                style: const TextStyle(
                  color: AppTheme.tertiary,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  venue.venue.displayName,
                  style: const TextStyle(
                    color: AppTheme.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  summary,
                  style: TextStyle(
                    color: AppTheme.onSurfaceVariant.withValues(alpha: 0.78),
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: AppTheme.onSurfaceVariant.withValues(alpha: 0.55),
            size: 20,
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

String _countLabel(int count, String label) {
  if (count == 1) return '1 $label';
  return '$count ${label}s';
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

class _HabitatDisplay {
  const _HabitatDisplay({
    required this.label,
    required this.color,
    required this.primaryHabitat,
  });

  final String label;
  final Color color;
  final Habitat? primaryHabitat;
}
