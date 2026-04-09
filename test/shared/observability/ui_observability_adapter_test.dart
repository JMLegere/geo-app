import 'package:flutter_test/flutter_test.dart';

import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/shared/observability/ui_observability_adapter.dart';

class _LoggedEvent {
  const _LoggedEvent({
    required this.event,
    required this.category,
    required this.data,
  });

  final String event;
  final String category;
  final Map<String, dynamic> data;
}

class _FakeObservabilityService extends ObservabilityService {
  _FakeObservabilityService() : super(sessionId: 'test-session');

  final List<_LoggedEvent> events = [];

  @override
  void log(String event, String category, {Map<String, dynamic>? data}) {
    events.add(_LoggedEvent(
      event: event,
      category: category,
      data: data ?? const {},
    ));
  }
}

void main() {
  group('UiObservabilityAdapter', () {
    late _FakeObservabilityService obs;
    late UiObservabilityAdapter adapter;

    setUp(() {
      obs = _FakeObservabilityService();
      adapter = UiObservabilityAdapter(obs);
    });

    test('exposes jank threshold constant as 100ms', () {
      expect(UiObservabilityAdapter.jankThresholdMs, 100);
    });

    test('logBuildJank emits ui event only when duration is above threshold',
        () {
      adapter.logBuildJank(
        screenName: 'map',
        widgetName: 'MapScreen',
        buildDuration: const Duration(milliseconds: 100),
      );
      adapter.logBuildJank(
        screenName: 'map',
        widgetName: 'MapScreen',
        buildDuration: const Duration(milliseconds: 101),
      );

      expect(obs.events.length, 1);
      expect(obs.events.single.event, 'ui.build_jank');
      expect(obs.events.single.category, UiObservabilityAdapter.uiCategory);
      expect(obs.events.single.data, {
        'screen_name': 'map',
        'widget_name': 'MapScreen',
        'build_duration_ms': 101,
      });
    });

    test('logInteraction emits normalized payload including screen_name', () {
      adapter.logInteraction(
        actionType: 'tap',
        widgetName: 'IdentifyButton',
        screenName: 'map',
        data: {'result': 'success'},
      );

      expect(obs.events.single.event, 'interaction.user_action');
      expect(
        obs.events.single.category,
        UiObservabilityAdapter.interactionCategory,
      );
      expect(obs.events.single.data, {
        'action_type': 'tap',
        'widget_name': 'IdentifyButton',
        'screen_name': 'map',
        'result': 'success',
      });
    });

    test('logNavigation emits normalized navigation payload', () {
      adapter.logNavigation(
        fromScreenName: 'login',
        toScreenName: 'pack',
        data: {'trigger': 'auth_success'},
      );

      expect(obs.events.single.event, 'navigation.screen_changed');
      expect(obs.events.single.category,
          UiObservabilityAdapter.navigationCategory);
      expect(obs.events.single.data, {
        'from_screen_name': 'login',
        'to_screen_name': 'pack',
        'trigger': 'auth_success',
      });
    });

    test('logError emits normalized error payload with screen_name', () {
      adapter.logError(
        event: 'ui.render_error',
        screenName: 'pack',
        error: StateError('bad ui state'),
        data: {'component': 'PackScreen'},
      );

      expect(obs.events.single.event, 'ui.render_error');
      expect(obs.events.single.category, UiObservabilityAdapter.errorCategory);
      expect(obs.events.single.data, {
        'screen_name': 'pack',
        'error_type': 'StateError',
        'error_message': 'Bad state: bad ui state',
        'component': 'PackScreen',
      });
    });
  });
}
