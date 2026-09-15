import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../foundations/app_design_theme.dart';
import '../foundations/spacing.dart';

class AppIconButton extends StatelessWidget {
  const AppIconButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.onLight = false,
    this.badgeCount,
    super.key,
  });
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool onLight;
  final int? badgeCount;
  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    button: true,
    onTap: onPressed,
    child: ExcludeSemantics(
      child: Stack(
        children: [
          ShadButton.ghost(
            width: DesignMetrics.touchTarget,
            height: DesignMetrics.touchTarget,
            padding: EdgeInsets.zero,
            onPressed: onPressed,
            child: Icon(
              icon,
              color: onLight ? DesignPalette.outline : DesignPalette.text,
            ),
          ),
          if ((badgeCount ?? 0) > 0)
            Positioned(
              top: 0,
              right: 0,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: DesignPalette.emphasis,
                    borderRadius: DesignMetrics.cardRadius,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.xxs,
                    ),
                    child: Text(
                      '$badgeCount',
                      style: DesignTypography.compact.copyWith(
                        color: DesignPalette.outline,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
