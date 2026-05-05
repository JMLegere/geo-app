import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/shared/observability/widgets/observable_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ObservableScreen', () {
    late _TestObservabilityService observability;

    setUp(() {
      observability = _TestObservabilityService();
    });

    testWidgets('emits screen and widget lifecycle events on init and dispose',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ObservableScreen(
            screenName: 'LoginScreen',
            observability: observability,
            builder: (_) => const SizedBox.shrink(),
          ),
        ),
      );

      expect(observability.findEvent('ui.widget.init'), isNotNull);
      expect(observability.findEvent('ui.screen.mounted'), isNotNull);
      expect(observability.findEvent('ui.screen.first_build'), isNotNull);
      expect(observability.findEvent('ui.screen.ready'), isNotNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      expect(observability.findEvent('ui.widget.dispose'), isNotNull);
      expect(observability.findEvent('ui.screen.disposed'), isNotNull);
      expect(observability.findEvent('ui.screen.disposed_before_ready'), isNull);
    });

    testWidgets('emits build jank event for 101ms build', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ObservableScreen(
            screenName: 'MapScreen',
            observability: observability,
            buildDurationOverride: () => const Duration(milliseconds: 101),
            builder: (_) => const SizedBox.shrink(),
          ),
        ),
      );

      final jankEvent = observability.findEvent('ui.widget.build_jank');
      expect(jankEvent, isNotNull);
      expect(jankEvent?['data']?['duration_ms'], 101);
      expect(jankEvent?['data']?['threshold_ms'], 100);
    });

    testWidgets('does not emit jank event for 99ms and 100ms builds',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ObservableScreen(
            screenName: 'PackScreen',
            observability: observability,
            buildDurationOverride: () => const Duration(milliseconds: 99),
            builder: (_) => const SizedBox.shrink(),
          ),
        ),
      );

      expect(observability.findEvent('ui.widget.build_jank'), isNull);

      observability.events.clear();

      await tester.pumpWidget(
        MaterialApp(
          home: ObservableScreen(
            screenName: 'PackScreen',
            observability: observability,
            buildDurationOverride: () => const Duration(milliseconds: 100),
            builder: (_) => const SizedBox.shrink(),
          ),
        ),
      );

      expect(observability.findEvent('ui.widget.build_jank'), isNull);
    });

    testWidgets('renders fallback and executes retry callback after error',
        (tester) async {
      var shouldThrow = true;
      var retryCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: ObservableScreen(
            screenName: 'SettingsScreen',
            observability: observability,
            onRetry: () {
              retryCount += 1;
              shouldThrow = false;
            },
            builder: (_) {
              if (shouldThrow) {
                throw StateError('boom');
              }
              return const Text('Recovered');
            },
          ),
        ),
      );

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Retry'), findsOneWidget);

      final boundaryEvent =
          observability.findEvent('error.screen_boundary_caught');
      expect(boundaryEvent, isNotNull);
      expect(boundaryEvent?['data']?['screen_name'], 'SettingsScreen');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Retry'));
      await tester.pump();

      expect(retryCount, 1);
      expect(find.text('Recovered'), findsOneWidget);
    });

    testWidgets('emits load_timeout and disposed_before_ready when screen never becomes ready',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ObservableScreen(
            screenName: 'BrokenScreen',
            observability: observability,
            readyTimeoutOverride: const Duration(milliseconds: 1),
            builder: (_) => throw StateError('boom'),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 2));

      final timeout = observability.findEvent('ui.screen.load_timeout');
      expect(timeout, isNotNull);
      expect(timeout?['data']?['screen_name'], 'BrokenScreen');
      expect(timeout?['data']?['timeout_ms'], 1);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      expect(
        observability.findEvent('ui.screen.disposed_before_ready'),
        isNotNull,
      );
    });
  });
}

class _TestObservabilityService extends ObservabilityService {
  _TestObservabilityService() : super(sessionId: 'test-session');

  final List<Map<String, dynamic>> events = [];

  @override
  void log(String event, String category, {Map<String, dynamic>? data}) {
    events.add({
      'event': event,
      'category': category,
      'data': data ?? <String, dynamic>{},
    });
  }

  Map<String, dynamic>? findEvent(String event) {
    for (final entry in events) {
      if (entry['event'] == event) {
        return entry;
      }
    }
    return null;
  }
}
