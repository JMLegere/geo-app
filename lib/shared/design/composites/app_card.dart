import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../foundations/app_design_theme.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.title,
    this.description,
    this.footer,
    this.tone = AppSurfaceTone.raised,
    super.key,
  });

  final Widget child;
  final String? title;
  final String? description;
  final Widget? footer;
  final AppSurfaceTone tone;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: DesignSurfaces.panel(tone),
      child: ShadCard(
        backgroundColor: Colors.transparent,
        title: title == null ? null : Text(title!),
        description: description == null ? null : Text(description!),
        footer: footer,
        child: child,
      ),
    );
  }
}
