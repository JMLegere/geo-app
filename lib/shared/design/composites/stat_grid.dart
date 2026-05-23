import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/design_tokens.dart';
import '../primitives/meta_text.dart';

class EarthStatItem {
  const EarthStatItem({
    required this.label,
    required this.value,
    this.helper,
  });

  final String label;
  final String value;
  final String? helper;
}

class EarthStatGrid extends StatelessWidget {
  const EarthStatGrid({
    required this.items,
    super.key,
  });

  final List<EarthStatItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumn = constraints.maxWidth >= 420;
        final itemWidth = twoColumn
            ? (constraints.maxWidth - Spacing.md) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: Spacing.md,
          runSpacing: Spacing.md,
          children: [
            for (final item in items)
              SizedBox(
                width: itemWidth,
                child: _EarthStatCard(item: item),
              ),
          ],
        );
      },
    );
  }
}

class _EarthStatCard extends StatelessWidget {
  const _EarthStatCard({required this.item});

  final EarthStatItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(Radii.xl),
        border: Border.all(color: AppTheme.outline.withValues(alpha: 0.48)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EarthMetaText(item.label),
            const SizedBox(height: Spacing.xs),
            Text(
              item.value,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: AppTheme.onSurface,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
              ),
            ),
            if (item.helper != null) ...[
              const SizedBox(height: Spacing.xs),
              Text(
                item.helper!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.3,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
