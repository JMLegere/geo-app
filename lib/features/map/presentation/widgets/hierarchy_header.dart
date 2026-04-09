import 'package:flutter/material.dart';
import 'package:earth_nova/shared/observability/widgets/observable_interaction.dart';
import 'package:earth_nova/shared/theme/app_theme.dart';

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
  final int explorerCount;
  final String? parentScopeName;
  final VoidCallback? onBackTap;
  final InteractionLogger? interactionLogger;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.surfaceContainer,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _BackNavRow(
            parentScopeName: parentScopeName,
            onBackTap: onBackTap,
            interactionLogger: interactionLogger,
          ),
          const SizedBox(height: 8),
          _ScopeRow(
            scopeLevel: scopeLevel,
            scopeName: scopeName,
            scopeCode: scopeCode,
          ),
          const SizedBox(height: 8),
          _RankChip(
            rank: rank,
            scopeName: scopeName,
          ),
          const SizedBox(height: 8),
          _StatChipsRow(
            cellsVisited: cellsVisited,
            cellsTotal: cellsTotal,
            progressPercent: progressPercent,
            rank: rank,
            explorerCount: explorerCount,
          ),
        ],
      ),
    );
  }
}

class _BackNavRow extends StatelessWidget {
  const _BackNavRow({
    this.parentScopeName,
    this.onBackTap,
    this.interactionLogger,
  });

  final String? parentScopeName;
  final VoidCallback? onBackTap;
  final InteractionLogger? interactionLogger;

  @override
  Widget build(BuildContext context) {
    final logger = interactionLogger ??
        (
            {required String event,
            required String category,
            Map<String, dynamic>? data}) {};

    final wrappedOnTap = onBackTap == null
        ? null
        : ObservableInteraction.wrapVoidCallback(
            logger: logger,
            screenName: 'hierarchy_header',
            widgetName: 'back_navigation_row',
            actionType: 'back_tap',
            callback: onBackTap!,
          );

    return GestureDetector(
      onTap: wrappedOnTap,
      child: Row(
        children: [
          const Icon(
            Icons.arrow_back_ios,
            size: 14,
            color: AppTheme.primary,
          ),
          const SizedBox(width: 4),
          Text(
            parentScopeName ?? '',
            style: const TextStyle(
              color: AppTheme.primary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScopeRow extends StatelessWidget {
  const _ScopeRow({
    required this.scopeLevel,
    required this.scopeName,
    required this.scopeCode,
  });

  final String scopeLevel;
  final String scopeName;
  final String scopeCode;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                scopeLevel,
                style: const TextStyle(
                  color: AppTheme.onSurfaceVariant,
                  fontSize: 10,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                scopeName,
                style: const TextStyle(
                  color: AppTheme.onSurface,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        Text(
          scopeCode,
          style: const TextStyle(
            color: AppTheme.primary,
            fontSize: 58,
            fontWeight: FontWeight.w900,
            height: 1.0,
          ).copyWith(
            color: AppTheme.primary.withValues(alpha: 0.15),
          ),
        ),
      ],
    );
  }
}

class _RankChip extends StatelessWidget {
  const _RankChip({required this.rank, required this.scopeName});

  final int rank;
  final String scopeName;

  @override
  Widget build(BuildContext context) {
    final label =
        rank == 0 ? 'Unranked' : '🏅 #$rank most explored in $scopeName';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.15),
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: 0.3),
        ),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.tertiary,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _StatChipsRow extends StatelessWidget {
  const _StatChipsRow({
    required this.cellsVisited,
    required this.cellsTotal,
    required this.progressPercent,
    required this.rank,
    required this.explorerCount,
  });

  final int cellsVisited;
  final int cellsTotal;
  final double progressPercent;
  final int rank;
  final int explorerCount;

  @override
  Widget build(BuildContext context) {
    final pct = progressPercent.toStringAsFixed(0);

    return Row(
      children: [
        Expanded(
          child: _StatChip(
            value: '$pct%',
            label: 'EXPLORED',
            sub: '$cellsVisited / $cellsTotal cells',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatChip(
            value: rank == 0 ? '—' : '#$rank',
            label: 'RANK',
            sub: rank == 0 ? 'No visits yet' : '$explorerCount explorers',
          ),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.value,
    required this.label,
    required this.sub,
  });

  final String value;
  final String label;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        border: Border.all(
          color: AppTheme.surfaceContainerHigh,
          width: 0.5,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.onSurfaceVariant,
              fontSize: 10,
              letterSpacing: 1.0,
            ),
          ),
          Text(
            sub,
            style: const TextStyle(
              color: AppTheme.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
