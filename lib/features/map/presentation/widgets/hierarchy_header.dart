import 'package:earth_nova/shared/design.dart';
import 'package:earth_nova/shared/observability/widgets/observable_interaction.dart';
import 'package:earth_nova/shared/product/player_actions.dart';
import 'package:flutter/material.dart';

class HierarchyHeader extends StatelessWidget {
  const HierarchyHeader({
    super.key,
    required this.scopeLevel,
    required this.scopeName,
    required this.scopeCode,
    required this.cellsVisited,
    required this.cellsTotal,
    required this.progressPercent,
    required this.rank,
    required this.explorerCount,
    this.cellsTotalKnown = true,
    this.parentScopeName,
    this.onBackTap,
    this.interactionLogger,
  });

  final String scopeLevel;
  final String scopeName;
  final String scopeCode;
  final int cellsVisited;
  final int cellsTotal;
  final double progressPercent;
  final int rank;
  final bool cellsTotalKnown;
  final int explorerCount;
  final String? parentScopeName;
  final VoidCallback? onBackTap;
  final InteractionLogger? interactionLogger;

  @override
  Widget build(BuildContext context) {
    final pct = progressPercent.toStringAsFixed(0);
    final useCompactStats = MediaQuery.textScalerOf(context).scale(1) >= 1.5;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.lg,
        vertical: Spacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onBackTap != null) ...[
            _BackButton(
              parentScopeName: parentScopeName,
              onBackTap: onBackTap!,
              interactionLogger: interactionLogger,
            ),
            const SizedBox(height: Spacing.sm),
          ],
          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AppBadge(
                label: scopeLevel,
                leading: const Icon(Icons.map_outlined, size: 16),
              ),
              AppBadge(label: scopeCode, variant: AppBadgeVariant.outline),
              AppBadge(
                label: rank == 0 ? 'Unranked' : 'Rank #$rank',
                variant: AppBadgeVariant.outline,
                leading: const Icon(Icons.leaderboard_outlined, size: 16),
              ),
            ],
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            scopeName,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: Spacing.xs),
          if (useCompactStats)
            _CompactStats(
              progressPercent: pct,
              cellsVisited: cellsVisited,
              cellsTotal: cellsTotal,
              cellsTotalKnown: cellsTotalKnown,
              rank: rank,
              explorerCount: explorerCount,
            )
          else
            AppStatGrid(
              items: [
                AppStatItem(
                  label: 'Explored',
                  value: cellsTotalKnown
                      ? '$pct%'
                      : '$cellsVisited cells explored; total unavailable',
                  helper: cellsTotalKnown
                      ? '$cellsVisited / $cellsTotal cells'
                      : 'Authoritative total unavailable',
                ),
                AppStatItem(
                  label: 'Rank',
                  value: rank == 0 ? '—' : '#$rank',
                  helper: rank == 0
                      ? 'No visits yet'
                      : '$explorerCount explorers',
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _CompactStats extends StatelessWidget {
  const _CompactStats({
    required this.progressPercent,
    required this.cellsVisited,
    required this.cellsTotal,
    required this.cellsTotalKnown,
    required this.rank,
    required this.explorerCount,
  });

  final String progressPercent;
  final int cellsVisited;
  final int cellsTotal;
  final bool cellsTotalKnown;
  final int rank;
  final int explorerCount;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Spacing.sm,
      runSpacing: Spacing.xs,
      children: [
        AppBadge(
          label: cellsTotalKnown
              ? 'Explored $progressPercent%'
              : '$cellsVisited cells explored; total unavailable',
        ),
        if (cellsTotalKnown)
          AppBadge(
            label: '$cellsVisited / $cellsTotal cells',
            variant: AppBadgeVariant.outline,
          ),
        AppBadge(label: rank == 0 ? 'Rank —' : 'Rank #$rank'),
        AppBadge(
          label: rank == 0 ? 'No visits yet' : '$explorerCount explorers',
          variant: AppBadgeVariant.outline,
        ),
      ],
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({
    required this.parentScopeName,
    required this.onBackTap,
    required this.interactionLogger,
  });

  final String? parentScopeName;
  final VoidCallback onBackTap;
  final InteractionLogger? interactionLogger;

  @override
  Widget build(BuildContext context) {
    final logger =
        interactionLogger ??
        ({
          required String event,
          required String category,
          Map<String, dynamic>? data,
        }) {};
    final wrappedOnTap = ObservableInteraction.wrapVoidCallback(
      logger: logger,
      screenName: 'hierarchy_header',
      widgetName: 'back_navigation_row',
      actionType: 'back_tap',
      playerActionId: PlayerActions.changeTerritoryScale,
      callback: onBackTap,
    );
    final parent = parentScopeName?.trim();

    // eac-clickable-owner-logs: HierarchyHeader logs before the back callback.
    return AppButton(
      label: parent == null || parent.isEmpty ? 'Back' : 'Back to $parent',
      variant: AppButtonVariant.ghost,
      leading: const Icon(Icons.arrow_back),
      onPressed: wrappedOnTap,
    );
  }
}
