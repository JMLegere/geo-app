import 'package:flutter/material.dart';

import '../composites/app_card.dart';
import '../primitives/app_button.dart';
import '../primitives/app_notice.dart';

class AppErrorState extends StatelessWidget {
  const AppErrorState({
    required this.title,
    required this.message,
    this.retryLabel = 'Try again',
    this.onRetry,
    super.key,
  });

  final String title;
  final String message;
  final String retryLabel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      footer: onRetry == null
          ? null
          : AppButton(
              label: retryLabel,
              onPressed: onRetry,
              variant: AppButtonVariant.outline,
              expand: true,
            ),
      child: AppNotice(
        title: title,
        message: message,
        tone: AppNoticeTone.error,
      ),
    );
  }
}
