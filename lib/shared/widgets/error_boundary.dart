import 'package:flutter/material.dart';
import 'package:earth_nova/shared/design_tokens.dart';

/// An error boundary that catches Flutter framework errors in its subtree
/// and displays fallback UI instead of a red crash screen.
///
/// Wraps major screens to gracefully degrade on unexpected widget errors:
/// ```dart
/// ErrorBoundary(
///   onError: (details) => const _ErrorFallback(),
///   child: MyComplexScreen(),
/// )
/// ```
///
/// The boundary installs a temporary [FlutterError.onError] handler while
/// mounted. Errors are logged via [FlutterError.dumpErrorToConsole] before
/// switching to the fallback widget — raw exceptions are never shown to users.
///
/// **Limitation**: Only one ErrorBoundary per active route should intercept
/// errors this way, since [FlutterError.onError] is global. For most apps,
/// wrapping the top-level route is sufficient.
class ErrorBoundary extends StatefulWidget {
  const ErrorBoundary({
    required this.child,
    required this.onError,
    super.key,
  });

  /// The widget subtree to guard.
  final Widget child;

  /// Called with error details when the subtree throws a build error.
  /// Should return a friendly fallback widget (no stack traces, no raw
  /// exception messages).
  final Widget Function(FlutterErrorDetails details) onError;

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  FlutterErrorDetails? _errorDetails;
  void Function(FlutterErrorDetails)? _previousOnError;

  @override
  void initState() {
    super.initState();
    _previousOnError = FlutterError.onError;

    FlutterError.onError = (FlutterErrorDetails details) {
      // Always dump to console so developers can diagnose the issue.
      FlutterError.dumpErrorToConsole(details);

      // Schedule state update — cannot call setState during build.
      if (mounted) {
        setState(() => _errorDetails = details);
      }
    };
  }

  @override
  void dispose() {
    FlutterError.onError = _previousOnError;
    super.dispose();
  }

  /// Clears the error and attempts to re-render the child. Useful for a
  /// "Try again" button in the fallback widget.
  void reset() {
    if (mounted) {
      setState(() => _errorDetails = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final details = _errorDetails;
    if (details != null) {
      return widget.onError(details);
    }
    return widget.child;
  }
}

/// Default fallback widget used when wrapping screens with [ErrorBoundary].
///
/// Shows a friendly "Something went wrong" message with a retry button.
/// Never exposes raw exception details to the user.
class DefaultErrorFallback extends StatelessWidget {
  const DefaultErrorFallback({
    required this.onRetry,
    super.key,
  });

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: Spacing.huge),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('😕', style: TextStyle(fontSize: ComponentSizes.emptyStateEmoji)),
              Spacing.gapXl,
              Text(
                'Something went wrong',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              Spacing.gapSm,
              Text(
                "We hit an unexpected error. Your progress is safe.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              SizedBox(height: Spacing.xxl + Spacing.xs),
              FilledButton(
                onPressed: onRetry,
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: Spacing.xxl + Spacing.xs,
                    vertical: Spacing.md,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: Radii.borderLg,
                  ),
                ),
                child: const Text(
                  'Try Again',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
