import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../foundations/app_design_theme.dart';
import 'app_icon_button.dart';

class AppSearchField extends StatefulWidget {
  const AppSearchField({
    required this.query,
    required this.onChanged,
    this.hint = 'Search...',
    super.key,
  });
  final String query;
  final String hint;
  final ValueChanged<String> onChanged;
  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  late final _controller = TextEditingController(text: widget.query);
  @override
  void didUpdateWidget(AppSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.text != widget.query) {
      _controller.value = TextEditingValue(
        text: widget.query,
        selection: TextSelection.collapsed(offset: widget.query.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ShadInput(
    controller: _controller,
    onChanged: widget.onChanged,
    placeholder: Text(
      widget.hint,
      style: DesignTypography.body.copyWith(color: DesignPalette.unavailable),
    ),
    style: DesignTypography.body.copyWith(color: DesignPalette.outline),
    cursorColor: DesignPalette.outline,
    decoration: ShadDecoration(
      color: DesignPalette.text,
      border: ShadBorder.all(
        color: DesignPalette.outline,
        width: DesignMetrics.outline,
        radius: DesignMetrics.radius,
      ),
    ),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.query.isNotEmpty)
          AppIconButton(
            label: 'Clear search',
            icon: Icons.close,
            onPressed: () => widget.onChanged(''),
            onLight: true,
          ),
        const Icon(Icons.search, color: DesignPalette.outline),
      ],
    ),
  );
}
