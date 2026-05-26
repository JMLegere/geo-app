import 'package:flutter/material.dart';

class ErrorBoundaryRetry extends StatelessWidget {
  const ErrorBoundaryRetry({
    super.key,
    required this.onRetry,
  });

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Something went wrong'),
              const SizedBox(height: 16),
              // eac-clickable-ignore: retry is observability/infrastructure recovery, not a gameplay product action.
              ElevatedButton(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
