import 'package:flutter/material.dart';

import 'package:earth_nova/core/domain/entities/habitat.dart';
import 'package:earth_nova/features/living_world/domain/entities/npc_venue.dart';
import 'package:earth_nova/features/living_world/presentation/screens/npc_venue_detail_screen.dart';
import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/features/map/domain/entities/cell_state.dart';
import 'package:earth_nova/shared/theme/app_theme.dart';

class CellDetailSheet extends StatelessWidget {
  const CellDetailSheet({
    super.key,
    required this.cell,
    required this.visitCount,
    required this.isFirstVisit,
    required this.currentRelationship,
    this.npcVenue,
  });

  final Cell cell;
  final int visitCount;
  final bool isFirstVisit;
  final CellRelationship currentRelationship;
  final NpcVenue? npcVenue;

  @override
  Widget build(BuildContext context) {
    final habitatDisplay = _habitatDisplayFor(cell);
    final primaryHabitat = habitatDisplay.primaryHabitat;

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
                  value: _relationshipLabel(currentRelationship),
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
                if (npcVenue != null) ...[
                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFF333333), height: 1),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => _openVenueDetail(context, npcVenue!),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF3A3A3A)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppTheme.tertiary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: Text(
                                'WR',
                                style: TextStyle(
                                  color: AppTheme.tertiary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  npcVenue!.venueName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${npcVenue!.npcName}  •  '
                                  '${npcVenue!.featureName}',
                                  style: TextStyle(
                                    color: AppTheme.onSurfaceVariant
                                        .withValues(alpha: 0.72),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: AppTheme.onSurfaceVariant
                                .withValues(alpha: 0.5),
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openVenueDetail(BuildContext context, NpcVenue venue) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => NpcVenueDetailScreen(venue: venue),
          ),
        );
      });
      return;
    }

    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => NpcVenueDetailScreen(venue: venue),
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
      color: habitats.first.color,
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
