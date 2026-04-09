import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/shared/observability/widgets/observable_interaction.dart';

void main() {
  group('ObservableInteraction', () {
    test('wrapVoidCallback logs action payload and executes callback', () {
      final events = <Map<String, dynamic>>[];
      var invoked = false;

      final callback = ObservableInteraction.wrapVoidCallback(
        logger: ({required event, required category, data}) {
          events.add({
            'event': event,
            'category': category,
            'data': data,
          });
        },
        screenName: 'login_screen',
        widgetName: 'continue_button',
        actionType: 'tap',
        payload: const {'entry_point': 'login'},
        callback: () => invoked = true,
      );

      callback();

      expect(invoked, isTrue);
      expect(events, hasLength(1));
      expect(events.single['event'], 'ui.interaction');
      expect(events.single['category'], 'ui');
      expect(events.single['data'], {
        'action_type': 'tap',
        'screen_name': 'login_screen',
        'widget_name': 'continue_button',
        'entry_point': 'login',
      });
    });

    test('wrapValueChanged logs action payload and forwards input value', () {
      final events = <Map<String, dynamic>>[];
      String? received;

      final callback = ObservableInteraction.wrapValueChanged<String>(
        logger: ({required event, required category, data}) {
          events.add({
            'event': event,
            'category': category,
            'data': data,
          });
        },
        screenName: 'pack_screen',
        widgetName: 'search_field',
        actionType: 'text_changed',
        payloadBuilder: (value) => {'query_length': value.length},
        callback: (value) => received = value,
      );

      callback('lynx');

      expect(received, 'lynx');
      expect(events, hasLength(1));
      expect(events.single['data'], {
        'action_type': 'text_changed',
        'screen_name': 'pack_screen',
        'widget_name': 'search_field',
        'query_length': 4,
      });
    });

    test('wrapTapUp logs action payload and forwards details', () {
      final events = <Map<String, dynamic>>[];
      TapUpDetails? received;

      final callback = ObservableInteraction.wrapTapUp(
        logger: ({required event, required category, data}) {
          events.add({
            'event': event,
            'category': category,
            'data': data,
          });
        },
        screenName: 'map_screen',
        widgetName: 'cell_overlay',
        actionType: 'tap_up',
        payloadBuilder: (_) => const {'target': 'cell_overlay'},
        callback: (details) => received = details,
      );

      final details = TapUpDetails(kind: PointerDeviceKind.touch);
      callback(details);

      expect(received, details);
      expect(events, hasLength(1));
      expect(events.single['data'], {
        'action_type': 'tap_up',
        'screen_name': 'map_screen',
        'widget_name': 'cell_overlay',
        'target': 'cell_overlay',
      });
    });

    test('wrapScaleEnd logs action payload and forwards details', () {
      final events = <Map<String, dynamic>>[];
      ScaleEndDetails? received;

      final callback = ObservableInteraction.wrapScaleEnd(
        logger: ({required event, required category, data}) {
          events.add({
            'event': event,
            'category': category,
            'data': data,
          });
        },
        screenName: 'map_root_screen',
        widgetName: 'map_level_gesture_detector',
        actionType: 'pinch_level_change',
        payloadBuilder: (_) => const {'gesture_direction': 'close'},
        callback: (details) => received = details,
      );

      final details = ScaleEndDetails(
        velocity: Velocity.zero,
      );
      callback(details);

      expect(received, details);
      expect(events, hasLength(1));
      expect(events.single['data'], {
        'action_type': 'pinch_level_change',
        'screen_name': 'map_root_screen',
        'widget_name': 'map_level_gesture_detector',
        'gesture_direction': 'close',
      });
    });

    test('log uses base payload fields when no extra payload is provided', () {
      final events = <Map<String, dynamic>>[];

      ObservableInteraction.log(
        logger: ({required event, required category, data}) {
          events.add({
            'event': event,
            'category': category,
            'data': data,
          });
        },
        screenName: 'settings_screen',
        widgetName: 'sign_out_button',
        actionType: 'tap',
      );

      expect(events, hasLength(1));
      expect(events.single['event'], 'ui.interaction');
      expect(events.single['category'], 'ui');
      expect(events.single['data'], {
        'action_type': 'tap',
        'screen_name': 'settings_screen',
        'widget_name': 'sign_out_button',
      });
    });
  });
}
