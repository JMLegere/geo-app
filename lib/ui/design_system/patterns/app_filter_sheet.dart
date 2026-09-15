import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../foundations/app_design_theme.dart';
import '../primitives/app_icon_button.dart';

class AppFilterSheet extends StatelessWidget {
  const AppFilterSheet({required this.child, super.key});

  final Widget child;

  static Future<void> show(BuildContext context, WidgetBuilder builder) =>
      showShadSheet<void>(
        context: context,
        side: ShadSheetSide.bottom,
        barrierLabel: 'Close filters',
        barrierColor: DesignPalette.shadow,
        animateIn: const [],
        animateOut: const [],
        builder: builder,
      );

  @override
  Widget build(BuildContext context) => ShadSheet(
    title: const Text('Filters'),
    closeIcon: AppIconButton(
      key: const Key('close-filters'),
      label: 'Close filters',
      icon: Icons.close,
      onPressed: () => Navigator.of(context).pop(),
    ),
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * .8,
      maxWidth: DesignMetrics.inspectionMaxWidth,
    ),
    child: child,
  );
}
