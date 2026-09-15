import 'package:earth_nova/ui/design_system.dart';
import 'package:flutter/material.dart';

class PinchHint extends StatelessWidget {
  const PinchHint({
    super.key,
    required this.lowerLevelLabel,
    required this.upperLevelLabel,
    this.onLowerLevelTap,
    this.onUpperLevelTap,
  });

  final String lowerLevelLabel;
  final String? upperLevelLabel;
  final VoidCallback? onLowerLevelTap;
  final VoidCallback? onUpperLevelTap;

  @override
  Widget build(BuildContext context) {
    final upper = upperLevelLabel;
    final hasControls = onLowerLevelTap != null || onUpperLevelTap != null;
    if (hasControls) {
      return Semantics(
        container: true,
        label: 'Map scale',
        explicitChildNodes: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (onLowerLevelTap != null)
                AppButton(
                  key: const ValueKey('pinch_hint_lower_control'),
                  label: lowerLevelLabel,
                  variant: AppButtonVariant.outline,
                  expand: true,
                  onPressed: onLowerLevelTap,
                ),
              if (onLowerLevelTap != null &&
                  upper != null &&
                  onUpperLevelTap != null)
                const SizedBox(height: Spacing.xs),
              if (upper != null && onUpperLevelTap != null)
                AppButton(
                  key: const ValueKey('pinch_hint_upper_control'),
                  label: upper,
                  variant: AppButtonVariant.outline,
                  expand: true,
                  onPressed: onUpperLevelTap,
                ),
            ],
          ),
        ),
      );
    }

    final text = upper == null
        ? 'Pinch out for $lowerLevelLabel.'
        : 'Pinch out for $lowerLevelLabel. Pinch in for $upper.';
    return Semantics(
      container: true,
      label: text,
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.pinch_outlined),
              const SizedBox(width: Spacing.sm),
              Expanded(child: Text(text)),
            ],
          ),
        ),
      ),
    );
  }
}
