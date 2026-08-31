import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

enum AppButtonVariant { primary, secondary, outline, destructive, ghost }

class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.leading,
    this.trailing,
    this.isLoading = false,
    this.expand = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final Widget? leading;
  final Widget? trailing;
  final bool isLoading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;

    return Semantics(
      button: true,
      enabled: enabled,
      label: isLoading ? '$label loading' : label,
      onTap: enabled ? onPressed : null,
      child: ExcludeSemantics(
        child: ShadButton.raw(
          variant: _variant,
          height: 44,
          expands: expand,
          enabled: enabled,
          onPressed: enabled ? onPressed : null,
          leading: isLoading ? null : leading,
          trailing: isLoading ? null : trailing,
          child: Text(isLoading ? 'Loading' : label),
        ),
      ),
    );
  }

  ShadButtonVariant get _variant => switch (variant) {
    AppButtonVariant.primary => ShadButtonVariant.primary,
    AppButtonVariant.secondary => ShadButtonVariant.secondary,
    AppButtonVariant.outline => ShadButtonVariant.outline,
    AppButtonVariant.destructive => ShadButtonVariant.destructive,
    AppButtonVariant.ghost => ShadButtonVariant.ghost,
  };
}
