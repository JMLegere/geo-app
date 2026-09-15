import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../foundations/app_design_theme.dart';
import '../foundations/spacing.dart';

class AppProgress extends StatelessWidget {
  const AppProgress({
    required this.current,
    required this.requirement,
    required this.label,
    this.icon,
    super.key,
  }) : assert(current >= 0),
       assert(requirement > 0);
  final int current;
  final int requirement;
  final String label;
  final Widget? icon;
  @override
  Widget build(BuildContext context) => Semantics(
    label:
        '$label: $current of $requirement${current >= requirement ? ', complete' : ''}',
    child: ExcludeSemantics(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: EdgeInsets.only(left: icon == null ? 0 : Spacing.lg),
            child: ClipRRect(
              borderRadius: DesignMetrics.cardRadius,
              child: ColoredBox(
                color: DesignPalette.inset,
                child: ShaderMask(
                  blendMode: BlendMode.srcATop,
                  shaderCallback: (rect) =>
                      DesignSurfaces.progressGloss.createShader(rect),
                  child: ShadProgress(
                    value: (current / requirement).clamp(0, 1),
                    minHeight: Spacing.xl,
                    backgroundColor: Colors.transparent,
                  ),
                ),
              ),
            ),
          ),
          Text('$current / $requirement', style: DesignTypography.cost),
          if (icon != null)
            Align(
              alignment: Alignment.centerLeft,
              child: IconTheme(
                data: const IconThemeData(
                  size: DesignMetrics.statIcon,
                  color: DesignPalette.emphasis,
                ),
                child: icon!,
              ),
            ),
        ],
      ),
    ),
  );
}
