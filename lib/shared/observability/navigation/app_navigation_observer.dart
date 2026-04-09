import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef NavigationLogEvent = void Function(
  String event,
  String category, {
  Map<String, dynamic>? data,
});

final navigationScreenTransitionLoggerProvider =
    Provider<NavigationScreenTransitionLogger>((ref) {
  return NavigationScreenTransitionLogger(
    logEvent: (_, __, {data}) {},
  );
});

class NavigationScreenTransitionLogger {
  NavigationScreenTransitionLogger({required NavigationLogEvent logEvent})
      : _logEvent = logEvent;

  final NavigationLogEvent _logEvent;
  String? _lastSignature;

  void logScreenChanged({
    required String source,
    required String fromScreen,
    required String toScreen,
  }) {
    if (fromScreen == toScreen) return;

    final signature = '$source:$fromScreen->$toScreen';
    if (_lastSignature == signature) return;
    _lastSignature = signature;

    _safeLog(
      'navigation.screen_changed',
      data: {
        'source': source,
        'from_screen': fromScreen,
        'to_screen': toScreen,
      },
    );
  }

  void _safeLog(String event, {Map<String, dynamic>? data}) {
    try {
      _logEvent(event, 'navigation', data: data);
    } catch (_) {}
  }
}

class AppNavigationObserver extends NavigatorObserver {
  AppNavigationObserver({required NavigationLogEvent logEvent})
      : _logEvent = logEvent;

  final NavigationLogEvent _logEvent;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _safeLogRoute(
      'navigation.route.push',
      fromRoute: previousRoute,
      toRoute: route,
    );
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _safeLogRoute(
      'navigation.route.pop',
      fromRoute: route,
      toRoute: previousRoute,
    );
    super.didPop(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _safeLogRoute(
      'navigation.route.replace',
      fromRoute: oldRoute,
      toRoute: newRoute,
    );
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _safeLogRoute(
      'navigation.route.remove',
      fromRoute: route,
      toRoute: previousRoute,
    );
    super.didRemove(route, previousRoute);
  }

  void _safeLogRoute(
    String event, {
    required Route<dynamic>? fromRoute,
    required Route<dynamic>? toRoute,
  }) {
    try {
      _logEvent(
        event,
        'navigation',
        data: {
          'from_route': _routeName(fromRoute),
          'to_route': _routeName(toRoute),
        },
      );
    } catch (_) {}
  }

  String _routeName(Route<dynamic>? route) {
    if (route == null) return 'none';
    final routeName = route.settings.name;
    if (routeName != null && routeName.isNotEmpty) return routeName;
    return route.runtimeType.toString();
  }
}
