import 'package:flutter/material.dart';
import 'package:earth_nova/shared/theme/app_theme.dart';

/// Data for a single child area shown in the exploration map.
class ChildAreaData {
  const ChildAreaData({
    required this.id,
    required this.name,
    required this.cellsVisited,
    required this.cellsTotal,
    required this.progressPercent,
  });

  final String id;
  final String name;
  final int cellsVisited;
  final int cellsTotal;
  final double progressPercent;

  /// Policy: no opportunity highlight on 0%-explored areas.
  /// The map uses exploration color scale only — no amber dashed outline.
  bool get shouldShowOpportunityHighlight => false;
}

/// Exploration color scale — consistent across all hierarchy levels.
/// At district/city scale, thresholds are absolute cell counts.
/// At province/country/world scale, thresholds are relative percentages.
Color explorationColor(double progressPercent, int cellsVisited) {
  if (cellsVisited == 0) return const Color(0xFF0c1a26);
  if (cellsVisited <= 5) return const Color(0xFF111f2d);
  if (cellsVisited <= 15) return const Color(0xFF172a3a);
  if (cellsVisited <= 30) return const Color(0xFF1c3a4a);
  if (cellsVisited <= 50) return const Color(0xFF1e4e5e);
  if (progressPercent < 70) {
    return AppTheme.primary.withValues(alpha: 0.65);
  }
  if (progressPercent < 85) return AppTheme.primary;
  return AppTheme.tertiary.withValues(alpha: 0.85);
}

/// Shared exploration map widget used across all hierarchy screens.
///
/// Renders child areas as colored tiles based on exploration density.
/// Player dot is shown when [playerLat] and [playerLng] are non-null.
///
/// Policy: no 0%-region highlight overlays.
class HierarchyExplorationMap extends StatelessWidget {
  const HierarchyExplorationMap({
    super.key,
    required this.children,
    required this.playerLat,
    required this.playerLng,
  });

  final List<ChildAreaData> children;
  final double? playerLat;
  final double? playerLng;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF060f1a),
      child: Stack(
        children: [
          if (children.isEmpty)
            const Center(
              child: Text(
                'Explore your first cell to see this map',
                style: TextStyle(
                  color: AppTheme.onSurfaceVariant,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            )
          else
            _ChildAreaGrid(children: children),
          if (playerLat != null && playerLng != null)
            const Positioned(
              bottom: 40,
              right: 40,
              child: _PlayerDot(),
            ),
        ],
      ),
    );
  }
}

class _ChildAreaGrid extends StatelessWidget {
  const _ChildAreaGrid({required this.children});

  final List<ChildAreaData> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: children.map((area) => _ChildAreaTile(area: area)).toList(),
      ),
    );
  }
}

class _ChildAreaTile extends StatelessWidget {
  const _ChildAreaTile({required this.area});

  final ChildAreaData area;

  @override
  Widget build(BuildContext context) {
    final color = explorationColor(area.progressPercent, area.cellsVisited);

    return Container(
      width: 80,
      height: 60,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: Text(
          '${area.cellsVisited}',
          style: const TextStyle(
            color: AppTheme.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

class _PlayerDot extends StatelessWidget {
  const _PlayerDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: AppTheme.primary,
        shape: BoxShape.circle,
        border: Border.all(
          color: AppTheme.tertiary,
          width: 2.5,
        ),
      ),
    );
  }
}
