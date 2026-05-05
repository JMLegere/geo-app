import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/shared/observability/widgets/error_boundary_retry.dart';
import 'package:flutter/material.dart';

class ObservableScreen extends StatefulWidget {
  const ObservableScreen({
    super.key,
    required this.screenName,
    required this.observability,
    required this.builder,
    this.onRetry,
    this.buildDurationOverride,
  });

  final String screenName;
  final ObservabilityService observability;
  final WidgetBuilder builder;
  final VoidCallback? onRetry;
  final Duration Function()? buildDurationOverride;

  @override
  State<ObservableScreen> createState() => _ObservableScreenState();
}

class _ObservableScreenState extends State<ObservableScreen> {
  static const _jankThresholdMs = 100;
  bool _showFallback = false;

  @override
  void initState() {
    super.initState();
    widget.observability.log(
      'ui.widget.init',
      'ui',
      data: _payload(),
    );
  }

  @override
  void dispose() {
    widget.observability.log(
      'ui.widget.dispose',
      'ui',
      data: _payload(),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stopwatch = Stopwatch()..start();

    Widget screen;
    if (_showFallback) {
      screen = ErrorBoundaryRetry(onRetry: _handleRetry);
    } else {
      try {
        screen = widget.builder(context);
      } catch (error, stackTrace) {
        _showFallback = true;
        widget.observability.log(
          'error.screen_boundary_caught',
          'error',
          data: {
            'screen_name': widget.screenName,
            'error_type': error.runtimeType.toString(),
            'error_message': error.toString(),
            'stack_trace': stackTrace.toString(),
          },
        );
        screen = ErrorBoundaryRetry(onRetry: _handleRetry);
      }
    }

    stopwatch.stop();

    final duration = widget.buildDurationOverride?.call() ?? stopwatch.elapsed;

    widget.observability.log(
      'ui.widget.build',
      'ui',
      data: {
        ..._payload(),
        'duration_ms': duration.inMilliseconds,
      },
    );

    if (duration.inMilliseconds > _jankThresholdMs) {
      widget.observability.log(
        'ui.widget.build_jank',
        'ui',
        data: {
          ..._payload(),
          'duration_ms': duration.inMilliseconds,
          'threshold_ms': _jankThresholdMs,
          'build_duration_ms': duration.inMilliseconds,
        },
      );
    }

    return screen;
  }

  Map<String, dynamic> _payload() {
    return {
      'widget_name': widget.runtimeType.toString(),
      'screen_name': widget.screenName,
    };
  }

  void _handleRetry() {
    widget.onRetry?.call();
    if (!mounted) return;
    setState(() {
      _showFallback = false;
    });
  }
}
