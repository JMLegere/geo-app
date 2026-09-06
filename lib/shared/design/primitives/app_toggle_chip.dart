import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../foundations/app_design_theme.dart';
import '../foundations/spacing.dart';

class AppToggleChip extends StatelessWidget {
  const AppToggleChip({
    required this.label,
    required this.selected,
    required this.onChanged,
    this.explanation,
    super.key,
  });
  final String label;
  final bool selected;
  final ValueChanged<bool> onChanged;
  final String? explanation;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: DesignTypography.compact),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      );
      const inset = 2 * Spacing.sm + 4 * DesignMetrics.outline;
      painter.layout(maxWidth: math.max(1, constraints.maxWidth - inset));
      final width = math.min(
        constraints.maxWidth,
        math.max(DesignMetrics.touchTarget, painter.width + inset),
      );
      final height = math.max(
        DesignMetrics.touchTarget,
        painter.height + Spacing.sm,
      );
      painter.dispose();
      return Semantics(
        label: explanation ?? label,
        button: true,
        selected: selected,
        onTap: () => onChanged(!selected),
        child: ExcludeSemantics(
          child: ShadButton.outline(
            width: width,
            height: height,
            padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
            backgroundColor: selected
                ? DesignPalette.primary
                : DesignPalette.inset,
            onPressed: () => onChanged(!selected),
            child: SizedBox(
              width: math.max(1, width - inset),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: DesignTypography.compact.copyWith(
                  color: selected ? DesignPalette.outline : DesignPalette.text,
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
