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
        'ui.screen.expected',
        'navigation.route.pop',
        'ui.screen.expected',
        'navigation.route.replace',
        'ui.screen.expected',
        'navigation.route.remove',
        'ui.screen.expected',
      ]);
      expect(
          events
              .where((event) => event.event.startsWith('navigation.'))
              .map((event) => event.category)
              .toSet(),
          {'navigation'});
      expect(
          events
              .where((event) => event.event == 'ui.screen.expected')
              .map((event) => event.category)
              .toSet(),
          {'ui'});

      expect(events[0].data, {
        'from_route': '/from',
        'to_route': '/to',
      });
      expect(events[1].data, {
        'source': 'route.push',
        'screen_name': '/to',
        'from_screen': '/from',
      });
      expect(events[2].data, {
        'from_route': '/to',
        'to_route': '/from',
      });
      expect(events[3].data, {
        'source': 'route.pop',
        'screen_name': '/from',
        'from_screen': '/to',
      });
      expect(events[4].data, {
        'from_route': '/to',
        'to_route': '/replacement',
      });
      expect(events[5].data, {
        'source': 'route.replace',
        'screen_name': '/replacement',
        'from_screen': '/to',
      });
      expect(events[6].data, {
        'from_route': '/replacement',
        'to_route': '/from',
      });
      expect(events[7].data, {
        'source': 'route.remove',
        'screen_name': '/from',
        'from_screen': '/replacement',
      });
    });

    test('screen transition logger emits expected screen load event', () {
      final events =
          <({String event, String category, Map<String, dynamic>? data})>[];
      final logger = NavigationScreenTransitionLogger(
        logEvent: (event, category, {data}) {
          events.add((event: event, category: category, data: data));
        },
      );

      logger.logScreenChanged(
        source: 'tab_shell',
        fromScreen: 'pack_screen',
        toScreen: 'map_root_screen',
      );

      expect(events.map((event) => event.event), [
        'navigation.screen_changed',
        'ui.screen.expected',
      ]);
      expect(events.last.category, 'ui');
      expect(events.last.data, {
        'source': 'tab_shell',
        'screen_name': 'map_root_screen',
        'from_screen': 'pack_screen',
      });
    });

    test('normalizes expected screen names to ObservableScreen names', () {
      final events =
          <({String event, String category, Map<String, dynamic>? data})>[];
      final logger = NavigationScreenTransitionLogger(
        logEvent: (event, category, {data}) {
          events.add((event: event, category: category, data: data));
        },
      );

      logger.logScreenChanged(
        source: 'map_level',
        fromScreen: 'map.cell',
        toScreen: 'map.district',
      );

      expect(events.first.data, {
        'source': 'map_level',
        'from_screen': 'map_screen',
        'to_screen': 'district_screen',
        'raw_from_screen': 'map.cell',
        'raw_to_screen': 'map.district',
      });
      expect(events.last.data, {
        'source': 'map_level',
        'screen_name': 'district_screen',
        'from_screen': 'map_screen',
        'raw_screen_name': 'map.district',
        'raw_from_screen': 'map.cell',
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
