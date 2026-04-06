import 'package:flutter/material.dart';
import 'package:earth_nova/core/domain/entities/habitat.dart';
import 'package:earth_nova/features/map/domain/entities/cell.dart';

class CellDetailSheet extends StatelessWidget {
  const CellDetailSheet({
    super.key,
    required this.cell,
    required this.visitCount,
    required this.isFirstVisit,
  });

  final Cell cell;
  final int visitCount;
  final bool isFirstVisit;

  @override
  Widget build(BuildContext context) {
    final habitats = cell.habitats;
    final primaryHabitat = habitats.isNotEmpty ? habitats.first : null;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(
          color: const Color(0xFF333333),
          width: 1,
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
                        color: (primaryHabitat?.color ?? Colors.grey)
                            .withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getHabitatIcon(primaryHabitat),
                        color: primaryHabitat?.color ?? Colors.grey,
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
                            habitats.map((h) => h.label).join(' / '),
                            style: TextStyle(
                              color: primaryHabitat?.color ?? Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildInfoRow(
                  icon: Icons.explore,
                  label: 'Visits',
                  value: '$visitCount ${visitCount == 1 ? 'time' : 'times'}',
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
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
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
        Icon(
          icon,
          color: const Color(0xFF888888),
          size: 20,
        ),
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

  IconData _getHabitatIcon(Habitat? habitat) {
    return switch (habitat) {
      Habitat.forest => Icons.forest,
      Habitat.ocean => Icons.water,
      Habitat.freshwater => Icons.water_drop,
      Habitat.swamp => Icons.grass,
      Habitat.desert => Icons.wb_sunny,
      Habitat.plains => Icons.landscape,
      Habitat.mountain => Icons.terrain,
      null => Icons.help_outline,
    };
  }

  String _truncateId(String id) {
    if (id.length <= 8) return id;
    return '${id.substring(0, 4)}...${id.substring(id.length - 4)}';
  }
}
