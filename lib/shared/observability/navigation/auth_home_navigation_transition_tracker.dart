import 'package:earth_nova/shared/observability/navigation/app_navigation_observer.dart';

class AuthHomeNavigationTransitionTracker {
  AuthHomeNavigationTransitionTracker({
    required NavigationScreenTransitionLogger logger,
  }) : _logger = logger;

  final NavigationScreenTransitionLogger _logger;
  String? _lastScreen;

  void onScreenVisible(String screenName) {
    final previous = _lastScreen;
    _lastScreen = screenName;
    if (previous == null) return;

    _logger.logScreenChanged(
      source: 'auth_state',
      fromScreen: previous,
      toScreen: screenName,
    );
  }
}
