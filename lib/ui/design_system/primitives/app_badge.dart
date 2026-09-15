import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

enum AppBadgeVariant { primary, secondary, outline, destructive }

class AppBadge extends StatelessWidget {
  const AppBadge({
    required this.label,
    this.variant = AppBadgeVariant.secondary,
    this.leading,
    super.key,
  });

  final String label;
  final AppBadgeVariant variant;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: ShadBadge.raw(
          variant: _variant,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 4)],
              Text(label),
            ],
          ),
        ),
      ),
    );
  }

  ShadBadgeVariant get _variant => switch (variant) {
    AppBadgeVariant.primary => ShadBadgeVariant.primary,
    AppBadgeVariant.secondary => ShadBadgeVariant.secondary,
    AppBadgeVariant.outline => ShadBadgeVariant.outline,
    AppBadgeVariant.destructive => ShadBadgeVariant.destructive,
  };
}
