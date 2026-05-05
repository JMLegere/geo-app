import 'dart:async';
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
    this.readyTimeoutOverride,
  });

  final String screenName;
  final ObservabilityService observability;
  final WidgetBuilder builder;
  final VoidCallback? onRetry;
  final Duration Function()? buildDurationOverride;
  final Duration? readyTimeoutOverride;

  @override
  State<ObservableScreen> createState() => _ObservableScreenState();
}

class _ObservableScreenState extends State<ObservableScreen> {
  static const _jankThresholdMs = 100;
  static const _defaultReadyTimeout = Duration(seconds: 3);
  bool _showFallback = false;
  bool _firstBuildLogged = false;
  bool _ready = false;
  bool _loadTimeoutLogged = false;
  Timer? _readyTimer;
  @override
  void initState() {
    super.initState();
    widget.observability.log(
      'ui.widget.init',
      'ui',
      data: _payload(),
    );
    widget.observability.log(
      'ui.screen.mounted',
      'ui',
      data: _payload(),
    );
    _readyTimer = Timer(
      widget.readyTimeoutOverride ?? _defaultReadyTimeout,
      _handleReadyTimeout,
    );
  }

  @override
  void dispose() {
    _readyTimer?.cancel();
    if (!_ready) {
      widget.observability.log(
        'ui.screen.disposed_before_ready',
        'ui',
        data: _payload(),
      );
    }
    widget.observability.log(
      'ui.screen.disposed',
      'ui',
      data: {
        ..._payload(),
        'ready': _ready,
      },
    );
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
    var builderSucceeded = false;
    if (_showFallback) {
      screen = ErrorBoundaryRetry(onRetry: _handleRetry);
    } else {
      try {
        screen = widget.builder(context);
        builderSucceeded = true;
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

    if (builderSucceeded && !_firstBuildLogged) {
      _firstBuildLogged = true;
      widget.observability.log(
        'ui.screen.first_build',
        'ui',
        data: {
          ..._payload(),
          'duration_ms': duration.inMilliseconds,
        },
      );
    }

    if (builderSucceeded && !_ready) {
      _ready = true;
      _readyTimer?.cancel();
      widget.observability.log(
        'ui.screen.ready',
        'ui',
        data: {
          ..._payload(),
          'duration_ms': duration.inMilliseconds,
        },
      );
    }

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

  void _handleReadyTimeout() {
    if (!mounted || _ready || _loadTimeoutLogged) return;
    _loadTimeoutLogged = true;
    final timeout = widget.readyTimeoutOverride ?? _defaultReadyTimeout;
    widget.observability.log(
      'ui.screen.load_timeout',
      'ui',
      data: {
        ..._payload(),
        'timeout_ms': timeout.inMilliseconds,
        'ready': _ready,
      },
    );
  }


  void _handleRetry() {
    widget.onRetry?.call();
    if (!mounted) return;
    setState(() {
      _showFallback = false;
    });
  }
}
