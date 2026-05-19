import 'dart:async';

import 'package:earth_nova/shared/product/player_actions.dart';
import 'package:flutter/material.dart';

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
