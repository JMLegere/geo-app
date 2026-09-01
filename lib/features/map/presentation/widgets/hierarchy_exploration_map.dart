import 'package:flutter/material.dart';

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

/// Neutral exploration scale — consistent across all hierarchy levels.
/// At district/city scale, thresholds are absolute cell counts.
/// At province/country/world scale, thresholds are relative percentages.
Color explorationColor(double progressPercent, int cellsVisited) {
  if (cellsVisited == 0) return const Color(0xFF181818);
  if (cellsVisited <= 5) return const Color(0xFF282828);
  if (cellsVisited <= 15) return const Color(0xFF383838);
  if (cellsVisited <= 30) return const Color(0xFF484848);
  if (cellsVisited <= 50) return const Color(0xFF606060);
  if (progressPercent < 70) return const Color(0xFF6E6E6E);
  if (progressPercent < 85) return const Color(0xFFAFAFAF);
  return const Color(0xFFD9D9D9);
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
    return ColoredBox(
      color: const Color(0xFF0A0A0A),
      child: Stack(
        children: [
          if (children.isEmpty)
            const Center(
              child: Text(
                'Explore your first cell to see this map',
                style: TextStyle(color: Color(0xFFB0B0B0), fontSize: 13),
                textAlign: TextAlign.center,
              ),
            )
          else
            _ChildAreaGrid(children: children),
          if (playerLat != null && playerLng != null)
            const Positioned(bottom: 40, right: 40, child: _PlayerDot()),
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
    final countColor = color.computeLuminance() > 0.3
        ? const Color(0xFF181818)
        : const Color(0xFFF2F2F2);

    return Semantics(
      container: true,
      label:
          '${area.name}, ${area.cellsVisited} of ${area.cellsTotal} cells visited, '
          '${area.progressPercent.toStringAsFixed(0)}% explored',
      child: ExcludeSemantics(
        child: Container(
          width: 80,
          height: 60,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(
            child: Text(
              '${area.cellsVisited}',
              style: TextStyle(
                color: countColor,
                fontSize: 11,
                fontFamily: Theme.of(context).textTheme.labelSmall?.fontFamily,
              ),
            ),
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
    return Semantics(
      container: true,
      label: 'Player location',
      child: ExcludeSemantics(
        child: Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: const Color(0xFFF2F2F2),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF606060), width: 2.5),
          ),
        ),
      ),
    );
  }
}
