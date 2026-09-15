import 'package:flutter/material.dart';
import '../foundations/app_design_theme.dart';
import '../foundations/spacing.dart';

/// Collection geometry is shared, including extra height for larger text.
class AppCollectionGrid extends StatelessWidget {
  const AppCollectionGrid({
    required this.itemCount,
    required this.itemBuilder,
    this.storageKey,
    this.controller,
    super.key,
  });
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final PageStorageKey<String>? storageKey;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
      return ScrollbarTheme(
        data: const ScrollbarThemeData(
          thickness: WidgetStatePropertyAll(Spacing.xs),
          thumbColor: WidgetStatePropertyAll(DesignPalette.emphasis),
          trackColor: WidgetStatePropertyAll(DesignPalette.inset),
          radius: Radius.circular(Spacing.xs),
        ),
        child: Scrollbar(
          controller: controller,
          thumbVisibility: controller != null,
          trackVisibility: controller != null,
          child: GridView.builder(
            key: storageKey ?? const Key('pack-grid'),
            controller: controller,
            padding: const EdgeInsets.all(Spacing.sm),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: DesignMetrics.packColumns(constraints.maxWidth),
              childAspectRatio: .78 / scale.clamp(1, double.infinity),
              crossAxisSpacing: Spacing.xs,
              mainAxisSpacing: Spacing.sm,
            ),
            itemCount: itemCount,
            itemBuilder: itemBuilder,
          ),
        ),
      );
    },
  );
}
