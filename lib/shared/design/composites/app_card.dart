import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.title,
    this.description,
    this.footer,
    super.key,
  });

  final Widget child;
  final String? title;
  final String? description;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return ShadCard(
      title: title == null ? null : Text(title!),
      description: description == null ? null : Text(description!),
      footer: footer,
      child: child,
    );
  }
}
