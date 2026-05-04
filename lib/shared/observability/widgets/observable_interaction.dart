import 'package:flutter/material.dart';

typedef InteractionLogger = void Function({
  required String event,
  required String category,
  Map<String, dynamic>? data,
});

class ObservableInteraction {
  static const String _event = 'interaction.action';
  static const String _category = 'ui';

  static Map<String, dynamic> payload({
    required String actionType,
    required String screenName,
    required String widgetName,
    Map<String, dynamic>? extra,
  }) {
    return {
      'action_type': actionType,
      'screen_name': screenName,
      'widget_name': widgetName,
      ...?extra,
    };
  }

  static void log({
    required InteractionLogger logger,
    required String screenName,
    required String widgetName,
    required String actionType,
    Map<String, dynamic>? payload,
  }) {
    logger(
      event: _event,
      category: _category,
      data: ObservableInteraction.payload(
        actionType: actionType,
        screenName: screenName,
        widgetName: widgetName,
        extra: payload,
      ),
    );
  }

  static VoidCallback wrapVoidCallback({
    required InteractionLogger logger,
    required String screenName,
    required String widgetName,
    required String actionType,
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
          extra: payload,
        ),
      );
      callback();
    };
  }

  static ValueChanged<T> wrapValueChanged<T>({
    required InteractionLogger logger,
    required String screenName,
    required String widgetName,
    required String actionType,
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
          extra: payloadBuilder?.call(details),
        ),
      );
      callback(details);
    };
  }
}
