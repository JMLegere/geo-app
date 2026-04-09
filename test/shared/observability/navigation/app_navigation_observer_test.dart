import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/shared/observability/navigation/app_navigation_observer.dart';

void main() {
  group('AppNavigationObserver', () {
    test('logs push, pop, replace, and remove route events', () {
      final events =
          <({String event, String category, Map<String, dynamic>? data})>[];
      final observer = AppNavigationObserver(
        logEvent: (event, category, {data}) {
          events.add((event: event, category: category, data: data));
        },
      );

      final fromRoute = MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/from'),
        builder: (_) => const SizedBox.shrink(),
      );
      final toRoute = MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/to'),
        builder: (_) => const SizedBox.shrink(),
      );
      final replacementRoute = MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/replacement'),
        builder: (_) => const SizedBox.shrink(),
      );

      observer.didPush(toRoute, fromRoute);
      observer.didPop(toRoute, fromRoute);
      observer.didReplace(newRoute: replacementRoute, oldRoute: toRoute);
      observer.didRemove(replacementRoute, fromRoute);

      expect(events.map((event) => event.event), <String>[
        'navigation.route.push',
        'navigation.route.pop',
        'navigation.route.replace',
        'navigation.route.remove',
      ]);
      for (final event in events) {
        expect(event.category, 'navigation');
      }

      expect(events[0].data, {
        'from_route': '/from',
        'to_route': '/to',
      });
      expect(events[1].data, {
        'from_route': '/to',
        'to_route': '/from',
      });
      expect(events[2].data, {
        'from_route': '/to',
        'to_route': '/replacement',
      });
      expect(events[3].data, {
        'from_route': '/replacement',
        'to_route': '/from',
      });
    });

    test('does not block navigation when log callback throws', () {
      final observer = AppNavigationObserver(
        logEvent: (_, __, {data}) => throw StateError('log failed'),
      );
      final route = MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/screen'),
        builder: (_) => const SizedBox.shrink(),
      );

      expect(() => observer.didPush(route, null), returnsNormally);
    });
  });
}
