import 'package:flutter/material.dart';

import 'app_card.dart';

class AppStatItem {
  const AppStatItem({required this.label, required this.value, this.helper});

  final String label;
  final String value;
  final String? helper;
}

class AppStatGrid extends StatelessWidget {
  const AppStatGrid({required this.items, super.key});

  final List<AppStatItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final hasBoundedWidth = constraints.hasBoundedWidth;
        final availableWidth = hasBoundedWidth ? constraints.maxWidth : 320.0;
        final twoColumns = hasBoundedWidth && availableWidth >= 480;
        final itemWidth = twoColumns
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
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.label),
                      const SizedBox(height: 4),
                      Text(item.value),
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
}
