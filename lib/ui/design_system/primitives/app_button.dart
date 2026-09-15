import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../foundations/app_design_theme.dart';
import '../foundations/spacing.dart';

enum AppButtonVariant { primary, secondary, outline, destructive, ghost }

class AppResourceAmount {
  const AppResourceAmount({
    required this.amount,
    required this.label,
    required this.icon,
  });
  final String amount;
  final String label;
  final Widget icon;
}

class AppButton extends StatefulWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.leading,
    this.trailing,
    this.isLoading = false,
    this.expand = false,
    this.unavailableReason,
    this.cost,
    this.reward,
    super.key,
  });
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final Widget? leading;
  final Widget? trailing;
  final bool isLoading;
  final bool expand;
  final String? unavailableReason;
  final AppResourceAmount? cost;
  final AppResourceAmount? reward;
  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _pressed = false;
  bool _explanation = false;
  bool get _available =>
      widget.onPressed != null &&
      widget.unavailableReason == null &&
      !widget.isLoading;
  bool get _interactive =>
      !widget.isLoading && (_available || widget.unavailableReason != null);
  void _activate() {
    if (!_interactive) return;
    if (widget.unavailableReason != null) {
      setState(() => _explanation = true);
    } else {
      widget.onPressed?.call();
    }
  }

  void _release() {
    if (_pressed) setState(() => _pressed = false);
  }

  Widget _amount(AppResourceAmount amount) => Semantics(
    label: '${amount.amount} ${amount.label}',
    child: ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text(amount.amount, style: DesignTypography.cost)),
          const SizedBox(width: Spacing.xs),
          IconTheme(
            data: const IconThemeData(size: 18, color: DesignPalette.emphasis),
            child: amount.icon,
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final maxWidth = constraints.hasBoundedWidth
          ? constraints.maxWidth
          : 480.0;
      final painter =
          TextPainter(
            text: TextSpan(text: widget.label, style: DesignTypography.action),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout(
            maxWidth: math.max(
              1,
              maxWidth -
                  (Spacing.xxxl + 2 * DesignMetrics.outline) -
                  (widget.leading == null ? 0 : Spacing.xxxl) -
                  (widget.trailing == null ? 0 : Spacing.xxxl),
            ),
          );
      final labelWidth = painter.width;
      final labelHeight = painter.height;
      painter.dispose();
      final width = widget.expand
          ? maxWidth
          : math.min(
              maxWidth,
              math.max(
                DesignMetrics.touchTarget,
                labelWidth +
                    (Spacing.xxxl + 2 * DesignMetrics.outline) +
                    (widget.leading == null ? 0 : Spacing.xxxl) +
                    (widget.trailing == null ? 0 : Spacing.xxxl),
              ),
            );
      final height = math.max(
        DesignMetrics.touchTarget,
        labelHeight +
            Spacing.lg +
            (widget.cost == null
                ? 0
                : MediaQuery.textScalerOf(context).scale(20)),
      );
      final semantics = widget.isLoading
          ? '${widget.label} loading'
          : widget.label;
      final tone = _available
          ? (widget.variant == AppButtonVariant.primary
                ? DesignPalette.primary
                : DesignPalette.raised)
          : DesignPalette.unavailable;
      return SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_explanation && widget.unavailableReason != null)
              Padding(
                padding: const EdgeInsets.only(bottom: Spacing.sm),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    widget.unavailableReason!,
                    style: DesignTypography.body,
                  ),
                ),
              ),
            Listener(
              onPointerDown: (_) {
                if (_available) setState(() => _pressed = true);
              },
              onPointerUp: (_) => _release(),
              onPointerCancel: (_) => _release(),
              child: AnimatedContainer(
                key: const Key('app-button-depth'),
                duration: DesignMotion.of(
                  context,
                  _pressed ? DesignMotion.press : DesignMotion.release,
                ),
                curve: Curves.easeOut,
                transform: Matrix4.translationValues(
                  0,
                  _pressed ? DesignMetrics.bevel : 0,
                  0,
                ),
                decoration: BoxDecoration(
                  borderRadius: DesignMetrics.radius,
                  boxShadow: _pressed
                      ? const []
                      : const [
                          BoxShadow(
                            color: DesignPalette.outline,
                            offset: Offset(0, DesignMetrics.bevel),
                          ),
                        ],
                ),
                child: Semantics(
                  button: true,
                  enabled: _interactive,
                  label: semantics,
                  hint: widget.unavailableReason == null
                      ? null
                      : 'Unavailable. Activate to learn why.',
                  onTap: _interactive ? _activate : null,
                  child: ExcludeSemantics(
                    child: ShadButton.raw(
                      variant: switch (widget.variant) {
                        AppButtonVariant.primary => ShadButtonVariant.primary,
                        AppButtonVariant.secondary =>
                          ShadButtonVariant.secondary,
                        AppButtonVariant.outline => ShadButtonVariant.outline,
                        AppButtonVariant.destructive =>
                          ShadButtonVariant.destructive,
                        AppButtonVariant.ghost => ShadButtonVariant.ghost,
                      },
                      height: height,
                      width: width,
                      enabled: _interactive,
                      backgroundColor:
                          widget.variant == AppButtonVariant.destructive &&
                              _available
                          ? null
                          : tone,
                      foregroundColor: DesignPalette.text,
                      onPressed: _interactive ? _activate : null,
                      leading: widget.leading,
                      trailing: widget.trailing,
                      child: SizedBox(
                        width: math.max(
                          1,
                          width -
                              (Spacing.xxxl + 2 * DesignMetrics.outline) -
                              (widget.leading == null ? 0 : Spacing.xxxl) -
                              (widget.trailing == null ? 0 : Spacing.xxxl),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.label,
                                  textAlign: TextAlign.center,
                                  style: _available || widget.isLoading
                                      ? DesignTypography.action
                                      : DesignTypography.action.copyWith(
                                          color: DesignPalette.muted,
                                        ),
                                ),
                                if (widget.cost != null) _amount(widget.cost!),
                              ],
                            ),
                            if (widget.isLoading)
                              const Align(
                                alignment: Alignment.centerRight,
                                child: SizedBox.square(
                                  dimension: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (widget.reward != null)
              Padding(
                padding: const EdgeInsets.only(top: Spacing.md),
                child: _amount(widget.reward!),
              ),
          ],
        ),
      );
    },
  );
}
