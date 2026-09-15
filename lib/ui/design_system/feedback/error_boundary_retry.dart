import 'package:flutter/material.dart';

import '../foundations/spacing.dart';
import '../patterns/app_error_state.dart';

class ErrorBoundaryRetry extends StatelessWidget {
  const ErrorBoundaryRetry({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(Spacing.xxl),
            // eac-clickable-ignore: retry is observability/infrastructure recovery, not a gameplay product action.
            child: AppErrorState(
              title: 'Something went wrong',
              message: 'Please try again.',
              retryLabel: 'Retry',
              onRetry: onRetry,
            ),
          ),
        ),
      ),
    );
  }
}
