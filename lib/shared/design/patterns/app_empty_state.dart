import 'package:flutter/material.dart';

import '../composites/app_card.dart';
import '../primitives/app_button.dart';

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final action = actionLabel == null
        ? null
        : AppButton(label: actionLabel!, onPressed: onAction, expand: true);

    return Semantics(
      label: '$title. $message',
      child: AppCard(
        title: title,
        description: message,
        footer: action,
        child: const SizedBox.shrink(),
      ),
    );
  }
}
