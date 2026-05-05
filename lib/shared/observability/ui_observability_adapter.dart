import 'package:earth_nova/core/observability/observability_service.dart';

class UiObservabilityAdapter {
  UiObservabilityAdapter(this._obs);

  static const int jankThresholdMs = 100;

  static const String uiCategory = 'ui';
  static const String interactionCategory = 'interaction';
  static const String navigationCategory = 'navigation';
  static const String errorCategory = 'error';

  final ObservabilityService _obs;

  void logBuildJank({
    required String screenName,
    required String widgetName,
    required Duration buildDuration,
  }) {
    final durationMs = buildDuration.inMilliseconds;
    if (durationMs <= jankThresholdMs) return;

    _obs.log('ui.widget.build_jank', uiCategory, data: {
      'screen_name': screenName,
      'widget_name': widgetName,
      'duration_ms': durationMs,
      'build_duration_ms': durationMs,
    });
  }

  void logInteraction({
    required String actionType,
    required String widgetName,
    required String screenName,
    Map<String, dynamic>? data,
  }) {
    _obs.log('interaction.action', interactionCategory, data: {
      'action_type': actionType,
      'widget_name': widgetName,
      'screen_name': screenName,
      ...?data,
    });
  }

  void logNavigation({
    required String fromScreenName,
    required String toScreenName,
    Map<String, dynamic>? data,
  }) {
    _obs.log('navigation.screen_changed', navigationCategory, data: {
      'from_screen': fromScreenName,
      'to_screen': toScreenName,
      ...?data,
    });
  }

  void logError({
    required String event,
    required String screenName,
    required Object error,
    Map<String, dynamic>? data,
  }) {
    _obs.log(event, errorCategory, data: {
      'screen_name': screenName,
      'error_type': error.runtimeType.toString(),
      'error_message': error.toString(),
      ...?data,
    });
  }
}
