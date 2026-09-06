import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../foundations/app_design_theme.dart';
import '../foundations/spacing.dart';

class AppChoice<T> {
  const AppChoice({required this.value, required this.label});
  final T value;
  final String label;
}

class AppChoiceMenu<T> extends StatefulWidget {
  const AppChoiceMenu({
    required this.label,
    required this.value,
    required this.choices,
    required this.onChanged,
    super.key,
  });
  final String label;
  final T value;
  final List<AppChoice<T>> choices;
  final ValueChanged<T> onChanged;
  @override
  State<AppChoiceMenu<T>> createState() => _AppChoiceMenuState<T>();
}

class _AppChoiceMenuState<T> extends State<AppChoiceMenu<T>> {
  final _controller = ShadPopoverController();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ShadPopover(
    controller: _controller,
    effects: const [], // Retrieval changes are immediate; no animation gate.
    reverseDuration: Duration.zero,
    popover: (_) => IntrinsicWidth(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final choice in widget.choices)
            ShadButton.ghost(
              expands: true,
              onPressed: () {
                _controller.hide();
                widget.onChanged(choice.value);
              },
              child: Text(choice.label, style: DesignTypography.body),
            ),
        ],
      ),
    ),
    child: Semantics(
      label: widget.label,
      child: ShadButton.outline(
        height: DesignMetrics.touchTarget,
        padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
        onPressed: _controller.toggle,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.choices
                  .firstWhere((choice) => choice.value == widget.value)
                  .label,
              style: DesignTypography.compact,
            ),
            const Icon(Icons.arrow_drop_down, color: DesignPalette.emphasis),
          ],
        ),
      ),
    ),
  );
}
