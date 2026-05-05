import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/shared/observability/navigation/auth_home_navigation_transition_tracker.dart';
import 'package:earth_nova/shared/observability/navigation/app_navigation_observer.dart';

void main() {
  group('AuthHomeNavigationTransitionTracker', () {
    test('logs auth->home screen transitions and dedups repeated targets', () {
      final events =
          <({String event, String category, Map<String, dynamic>? data})>[];
      final logger = NavigationScreenTransitionLogger(
        logEvent: (event, category, {data}) {
          events.add((event: event, category: category, data: data));
        },
      );
      final tracker = AuthHomeNavigationTransitionTracker(logger: logger);

      tracker.onScreenVisible('loading');
      tracker.onScreenVisible('login');
      tracker.onScreenVisible('login');
      tracker.onScreenVisible('home');

      final screenChangedEvents = events
          .where((event) => event.event == 'navigation.screen_changed')
          .toList();
      expect(screenChangedEvents.length, 2);
      expect(screenChangedEvents[0].data, {
        'source': 'auth_state',
        'from_screen': 'loading_screen',
        'to_screen': 'login_screen',
        'raw_from_screen': 'loading',
        'raw_to_screen': 'login',
      });
      expect(screenChangedEvents[1].data, {
        'source': 'auth_state',
        'from_screen': 'login_screen',
        'to_screen': 'tab_shell',
        'raw_from_screen': 'login',
        'raw_to_screen': 'home',
      });
    });
  });
}
