import 'dart:async';

import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/core/observability/trace_context.dart';
import 'package:earth_nova/shared/product/player_actions.dart';
import 'package:flutter/material.dart';

/// One Player-input correlation, completed at the first meaningful local
/// transition. Child operations receive [context] rather than opening roots.
class ObservableInteractionTrace {
  ObservableInteractionTrace._({
    required ObservabilityService observability,
    required TelemetrySpan span,
    required this.interaction,
    required this.surface,
    required this.readinessState,
  })  : _observability = observability,
        _span = span;

  final ObservabilityService _observability;
  final TelemetrySpan _span;
  final PlayerActionId interaction;
  final String surface;
  final String readinessState;
  bool _completed = false;

  TraceContext get context => _span.context;

  static ObservableInteractionTrace start({
    required ObservabilityService observability,
    required PlayerActionId interaction,
    required String surface,
    required String readinessState,
    required String screenName,
    required String widgetName,
    required String actionType,
    Map<String, dynamic>? payload,
  }) {
    final knownInteraction = PlayerActions.requireKnown(interaction);
    final common = _commonAttributes(
      observability: observability,
      interaction: knownInteraction,
      surface: surface,
      readinessState: readinessState,
    );
    final span = observability.startSpan(
      'interaction.$knownInteraction',
      spanKind: 'client',
      attributes: {
        ...common,
        'transition': 'input_received',
        'outcome': 'pending',
      },
    );
    ObservableInteraction.log(
      logger: ({required event, required category, data}) =>
          observability.log(event, category, data: data),
      screenName: screenName,
      widgetName: widgetName,
      actionType: actionType,
      playerActionId: knownInteraction,
      payload: {
        ...common,
        'trace_id': span.traceId,
        'span_id': span.spanId,
        ...?payload,
      },
    );
    return ObservableInteractionTrace._(
      observability: observability,
      span: span,
      interaction: knownInteraction,
      surface: surface,
      readinessState: readinessState,
    );
  }

  /// Ends exactly once; later transitions belong to the already-correlated
  /// operation and must not create a second Player interaction.
  void complete({
    required String transition,
    String outcome = 'success',
    String? readinessState,
  }) {
    if (_completed) return;
    _completed = true;
    final attributes = {
      ..._commonAttributes(
        observability: _observability,
        interaction: interaction,
        surface: surface,
        readinessState: readinessState ?? this.readinessState,
      ),
      'transition': transition,
      'outcome': outcome,
      'latency_ms': _span.context.elapsed.inMilliseconds,
    };
    _observability.log(
      'interaction.transition',
      'ui',
      data: {
        ...attributes,
        'trace_id': _span.traceId,
        'span_id': _span.spanId,
      },
    );
    _observability.endSpan(
      _span,
      statusCode: outcome == 'success'
          ? TelemetrySpanStatus.ok
          : TelemetrySpanStatus.error,
      attributes: attributes,
    );
  }

  static Map<String, dynamic> _commonAttributes({
    required ObservabilityService observability,
    required String interaction,
    required String surface,
    required String readinessState,
  }) =>
      {
        'interaction': interaction,
        'surface': surface,
        'readiness_state': readinessState,
        'platform': observability.platform,
        'app_version': observability.serviceVersion,
        'deployment_environment': observability.deploymentEnvironment,
      };
}

typedef InteractionLogger = void Function({
  required String event,
  required String category,
  Map<String, dynamic>? data,
});

typedef PlayerActionIdBuilder<T> = PlayerActionId? Function(T value);
typedef TelemetryOnlyReasonBuilder<T> = String? Function(T value);

class ObservableInteraction {
  static const String _event = 'interaction.action';
  static const String _category = 'ui';

  static Map<String, dynamic> payload({
    required String actionType,
    required String screenName,
    required String widgetName,
    PlayerActionId? playerActionId,
    String? telemetryOnlyReason,
    Map<String, dynamic>? extra,
  }) {
    return {
      'action_type': actionType,
      'screen_name': screenName,
      'widget_name': widgetName,
      ..._actionDefinitionPayload(
        playerActionId: playerActionId,
        telemetryOnlyReason: telemetryOnlyReason,
      ),
      ...?extra,
    };
  }

  static Map<String, dynamic> _actionDefinitionPayload({
    PlayerActionId? playerActionId,
    String? telemetryOnlyReason,
  }) {
    final reason = telemetryOnlyReason?.trim();
    final hasPlayerAction = playerActionId != null;
    final hasTelemetryOnlyReason = reason != null && reason.isNotEmpty;

    if (hasPlayerAction == hasTelemetryOnlyReason) {
      throw ArgumentError(
        'Interaction must declare exactly one of playerActionId or '
        'telemetryOnlyReason.',
      );
    }

    if (playerActionId != null) {
      return {'player_action_id': PlayerActions.requireKnown(playerActionId)};
    }

    return {'telemetry_only_reason': reason};
  }

  static void log({
    required InteractionLogger logger,
    required String screenName,
    required String widgetName,
    required String actionType,
    PlayerActionId? playerActionId,
    String? telemetryOnlyReason,
    Map<String, dynamic>? payload,
  }) {
    logger(
      event: _event,
      category: _category,
      data: ObservableInteraction.payload(
        actionType: actionType,
        screenName: screenName,
        widgetName: widgetName,
        playerActionId: playerActionId,
        telemetryOnlyReason: telemetryOnlyReason,
        extra: payload,
      ),
    );
  }

  static VoidCallback wrapVoidCallback({
    required InteractionLogger logger,
    required String screenName,
    required String widgetName,
    required String actionType,
    PlayerActionId? playerActionId,
    String? telemetryOnlyReason,
    Map<String, dynamic>? payload,
    required VoidCallback callback,
  }) {
    return () {
      logger(
        event: _event,
        category: _category,
        data: ObservableInteraction.payload(
          actionType: actionType,
          screenName: screenName,
          widgetName: widgetName,
          playerActionId: playerActionId,
          telemetryOnlyReason: telemetryOnlyReason,
          extra: payload,
        ),
      );
      callback();
    };
  }

  static VoidCallback wrapAsyncCallback({
    required InteractionLogger logger,
    required String screenName,
    required String widgetName,
    required String actionType,
    PlayerActionId? playerActionId,
    String? telemetryOnlyReason,
    Map<String, dynamic>? payload,
    required Future<void> Function() callback,
  }) {
    return () {
      logger(
        event: _event,
        category: _category,
        data: ObservableInteraction.payload(
          actionType: actionType,
          screenName: screenName,
          widgetName: widgetName,
          playerActionId: playerActionId,
          telemetryOnlyReason: telemetryOnlyReason,
          extra: payload,
        ),
      );
      unawaited(callback());
    };
  }

  static ValueChanged<T> wrapValueChanged<T>({
    required InteractionLogger logger,
    required String screenName,
    required String widgetName,
    required String actionType,
    PlayerActionId? playerActionId,
    PlayerActionIdBuilder<T>? playerActionIdBuilder,
    String? telemetryOnlyReason,
    TelemetryOnlyReasonBuilder<T>? telemetryOnlyReasonBuilder,
    Map<String, dynamic> Function(T value)? payloadBuilder,
    required ValueChanged<T> callback,
  }) {
    return (value) {
      logger(
        event: _event,
        category: _category,
        data: ObservableInteraction.payload(
          actionType: actionType,
          screenName: screenName,
          widgetName: widgetName,
          playerActionId: playerActionIdBuilder?.call(value) ?? playerActionId,
          telemetryOnlyReason:
              telemetryOnlyReasonBuilder?.call(value) ?? telemetryOnlyReason,
          extra: payloadBuilder?.call(value),
        ),
      );
      callback(value);
    };
  }

  static GestureTapUpCallback wrapTapUp({
    required InteractionLogger logger,
    required String screenName,
    required String widgetName,
    required String actionType,
    PlayerActionId? playerActionId,
    PlayerActionIdBuilder<TapUpDetails>? playerActionIdBuilder,
    String? telemetryOnlyReason,
    TelemetryOnlyReasonBuilder<TapUpDetails>? telemetryOnlyReasonBuilder,
    Map<String, dynamic> Function(TapUpDetails details)? payloadBuilder,
    required GestureTapUpCallback callback,
  }) {
    return (details) {
      logger(
        event: _event,
        category: _category,
        data: ObservableInteraction.payload(
          actionType: actionType,
          screenName: screenName,
          widgetName: widgetName,
          playerActionId:
              playerActionIdBuilder?.call(details) ?? playerActionId,
          telemetryOnlyReason:
              telemetryOnlyReasonBuilder?.call(details) ?? telemetryOnlyReason,
          extra: payloadBuilder?.call(details),
        ),
      );
      callback(details);
    };
  }

  static GestureScaleEndCallback wrapScaleEnd({
    required InteractionLogger logger,
    required String screenName,
    required String widgetName,
    required String actionType,
    PlayerActionId? playerActionId,
    PlayerActionIdBuilder<ScaleEndDetails>? playerActionIdBuilder,
    String? telemetryOnlyReason,
    TelemetryOnlyReasonBuilder<ScaleEndDetails>? telemetryOnlyReasonBuilder,
    Map<String, dynamic> Function(ScaleEndDetails details)? payloadBuilder,
    required GestureScaleEndCallback callback,
  }) {
    return (details) {
      logger(
        event: _event,
        category: _category,
        data: ObservableInteraction.payload(
          actionType: actionType,
          screenName: screenName,
          widgetName: widgetName,
          playerActionId:
              playerActionIdBuilder?.call(details) ?? playerActionId,
          telemetryOnlyReason:
              telemetryOnlyReasonBuilder?.call(details) ?? telemetryOnlyReason,
          extra: payloadBuilder?.call(details),
        ),
      );
      callback(details);
    };
  }
}
