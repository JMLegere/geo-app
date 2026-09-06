import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../foundations/app_design_theme.dart';
import '../foundations/spacing.dart';

class AppNavButton extends StatelessWidget {
  const AppNavButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.selected = false,
    this.compact = false,
    this.showLabel = false,
    this.buttonKey,
    this.labelKey,
    this.selectionKey,
    super.key,
  });
  final String label;
  final Widget icon;
  final VoidCallback onPressed;
  final bool selected;
  final bool compact;
  final bool showLabel;
  final Key? buttonKey;
  final Key? labelKey;
  final Key? selectionKey;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: DesignTypography.compact),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      );
      painter.layout(
        maxWidth: math.max(
          1,
          (constraints.hasBoundedWidth ? constraints.maxWidth : 120) -
              (compact ? 0 : 2 * Spacing.xxs) -
              2 * Spacing.xs -
              4 * DesignMetrics.outline,
        ),
      );
      final height = math.max(
        68.0,
        DesignMetrics.navigationIcon +
            (showLabel ? painter.height : 0) +
            2 * Spacing.xs +
            4 * DesignMetrics.outline,
      );
      painter.dispose();
      return Semantics(
        label: label,
        button: true,
        selected: selected,
        onTap: onPressed,
        child: ExcludeSemantics(
          child: Padding(
            padding: compact
                ? EdgeInsets.zero
                : const EdgeInsets.all(Spacing.xxs),
            child: DecoratedBox(
              key: selected ? selectionKey : null,
              decoration: DesignSurfaces.panel(
                AppSurfaceTone.raised,
                selected: selected,
              ),
              child: ShadButton.ghost(
                key: buttonKey,
                height: height,
                expands: true,
                padding: const EdgeInsets.all(Spacing.xs),
                foregroundColor: DesignPalette.text,
                onPressed: onPressed,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconTheme(
                      data: const IconThemeData(
                        size: DesignMetrics.navigationIcon,
                        color: DesignPalette.text,
                      ),
                      child: icon,
                    ),
                    if (showLabel)
                      Text(
                        label,
                        key: labelKey,
                        style: DesignTypography.compact,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
