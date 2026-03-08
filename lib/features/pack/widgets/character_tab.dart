import 'package:flutter/material.dart' hide Durations;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/core/models/item_category.dart';
import 'package:earth_nova/features/pack/providers/pack_provider.dart';
import 'package:earth_nova/shared/design_tokens.dart';
import 'package:earth_nova/shared/game_icons.dart';

/// Character overview tab — shows player stats and per-category inventory
/// counts.
///
/// Reads [PackState.playerStats] for streak, distance, cells. Reads
/// [PackState.totalItems] and [PackState.countForCategory] for inventory
/// breakdown.
class CharacterTab extends ConsumerWidget {
  const CharacterTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(packProvider);
    final stats = state.playerStats;
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.lg,
        vertical: Spacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Character avatar ─────────────────────────────────────────────
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  cs.primaryContainer,
                  cs.tertiaryContainer,
                ],
              ),
              boxShadow: Shadows.medium,
            ),
            child: const Center(
              child: Text(
                GameIcons.character,
                style: TextStyle(fontSize: 44),
              ),
            ),
          ),

          Spacing.gapXl,

          // ── Adventure stats card ─────────────────────────────────────────
          _SectionLabel(label: 'Adventure', cs: cs),
          Spacing.gapSm,
          _StatsCard(
            cs: cs,
            rows: [
              _StatRow(
                icon: GameIcons.streak,
                label: 'Streak',
                value: '${stats.currentStreak} day${stats.currentStreak == 1 ? '' : 's'}',
                cs: cs,
              ),
              _StatRow(
                icon: GameIcons.streak,
                label: 'Best streak',
                value:
                    '${stats.longestStreak} day${stats.longestStreak == 1 ? '' : 's'}',
                cs: cs,
              ),
              _StatRow(
                icon: GameIcons.distance,
                label: 'Distance',
                value: '${stats.totalDistanceKm.toStringAsFixed(1)} km',
                cs: cs,
              ),
              _StatRow(
                icon: GameIcons.cellsExplored,
                label: 'Cells observed',
                value: '${stats.cellsObserved}',
                cs: cs,
                isLast: true,
              ),
            ],
          ),

          Spacing.gapLg,

          // ── Inventory summary card ───────────────────────────────────────
          _SectionLabel(label: 'Inventory', cs: cs),
          Spacing.gapSm,
          _StatsCard(
            cs: cs,
            rows: [
              _StatRow(
                icon: GameIcons.totalItems,
                label: 'Total items',
                value: '${state.totalItems}',
                cs: cs,
                isHighlighted: true,
              ),
              ...ItemCategory.values.map(
                (cat) => _StatRow(
                  icon: GameIcons.category(cat),
                  label: cat.displayName,
                  value: '${state.countForCategory(cat)}',
                  cs: cs,
                  isLast: cat == ItemCategory.values.last,
                ),
              ),
            ],
          ),

          Spacing.gapXxl,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.cs});

  final String label;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: cs.onSurfaceVariant,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.rows, required this.cs});

  final List<Widget> rows;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: Radii.borderXxl,
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: Opacities.borderSubtle),
          width: 1,
        ),
        boxShadow: Shadows.soft,
      ),
      child: Column(
        children: rows,
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.cs,
    this.isLast = false,
    this.isHighlighted = false,
  });

  final String icon;
  final String label;
  final String value;
  final ColorScheme cs;
  final bool isLast;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.lg,
            vertical: Spacing.md,
          ),
          child: Row(
            children: [
              // Icon
              Text(icon, style: const TextStyle(fontSize: 16)),
              Spacing.gapHMd,
              // Label
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                ),
              ),
              // Value
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.w600,
                  color:
                      isHighlighted ? cs.primary : cs.onSurface,
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            indent: Spacing.lg,
            endIndent: Spacing.lg,
            color: cs.outlineVariant.withValues(alpha: 0.4),
          ),
      ],
    );
  }
}
