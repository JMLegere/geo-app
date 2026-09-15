import 'package:flutter/material.dart';

import 'app_card.dart';
import '../foundations/app_design_theme.dart';
import '../foundations/spacing.dart';

class AppStatItem {
  const AppStatItem({
    required this.label,
    required this.value,
    this.helper,
    this.icon,
  });

  final String label;
  final String value;
  final String? helper;
  final Widget? icon;
}

class AppStatGrid extends StatelessWidget {
  const AppStatGrid({required this.items, this.inspection = false, super.key});

  final List<AppStatItem> items;
  final bool inspection;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final hasBoundedWidth = constraints.hasBoundedWidth;
        final availableWidth = hasBoundedWidth ? constraints.maxWidth : 320.0;
        final twoColumns = hasBoundedWidth && availableWidth >= 480;
        final itemWidth = inspection
            ? (availableWidth - 24) / 3
            : twoColumns
            ? (availableWidth - 12) / 2
            : availableWidth;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final (index, item) in items.indexed)
              SizedBox(
                key: ValueKey('app-stat-$index'),
                width: itemWidth,
                child: inspection
                    ? _inspectionStat(item, index)
                    : AppCard(
                        tone: inspection
                            ? AppSurfaceTone.inset
                            : AppSurfaceTone.raised,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.label,
                              style: inspection ? DesignTypography.label : null,
                            ),
                            const SizedBox(height: 4),
                            if (item.icon != null)
                              IconTheme(
                                data: const IconThemeData(
                                  size: DesignMetrics.statIcon,
                                  color: DesignPalette.emphasis,
                                ),
                                child: item.icon!,
                              ),
                            Text(
                              item.value,
                              style: inspection ? DesignTypography.value : null,
                            ),
                            if (item.helper != null) ...[
                              const SizedBox(height: 4),
                              Text(item.helper!),
                            ],
                          ],
                        ),
                      ),
              ),
          ],
        );
      },
    );
  }

  Widget _inspectionStat(AppStatItem item, int index) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: DesignMetrics.statIcon),
        child: Text(item.label, style: DesignTypography.label),
      ),
      const SizedBox(height: Spacing.xs),
      Stack(
        alignment: Alignment.centerLeft,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: Spacing.md),
            child: Container(
              key: ValueKey('app-stat-value-$index'),
              constraints: const BoxConstraints(
                minHeight: DesignMetrics.touchTarget,
              ),
              decoration: DesignSurfaces.panel(AppSurfaceTone.inset),
              padding: const EdgeInsets.fromLTRB(
                Spacing.lg,
                Spacing.xs,
                Spacing.xs,
                Spacing.xs,
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.value,
                    textAlign: TextAlign.center,
                    style: DesignTypography.value,
                  ),
                  if (item.helper != null)
                    Text(
                      item.helper!,
                      textAlign: TextAlign.center,
                      style: DesignTypography.compact,
                    ),
                ],
              ),
            ),
          ),
          if (item.icon != null)
            IconTheme(
              data: const IconThemeData(
                size: DesignMetrics.statIcon,
                color: DesignPalette.emphasis,
              ),
              child: item.icon!,
            ),
        ],
      ),
    ],
  );
}
