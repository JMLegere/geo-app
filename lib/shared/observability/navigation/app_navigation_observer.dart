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
    _safeLog(
      'ui.screen.expected',
      category: 'ui',
      data: {
        'source': source,
        'screen_name': toScreen,
        'from_screen': fromScreen,
      },
    );
  }

  void _safeLog(
    String event, {
    String category = 'navigation',
    Map<String, dynamic>? data,
  }) {
    try {
      _logEvent(event, category, data: data);
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
      routeEventSource: 'route.push',
      fromRoute: previousRoute,
      toRoute: route,
    );
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _safeLogRoute(
      'navigation.route.pop',
      routeEventSource: 'route.pop',
      fromRoute: route,
      toRoute: previousRoute,
    );
    super.didPop(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _safeLogRoute(
      'navigation.route.replace',
      routeEventSource: 'route.replace',
      fromRoute: oldRoute,
      toRoute: newRoute,
    );
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _safeLogRoute(
      'navigation.route.remove',
      routeEventSource: 'route.remove',
      fromRoute: route,
      toRoute: previousRoute,
    );
    super.didRemove(route, previousRoute);
  }

  void _safeLogRoute(
    String event, {
    required String routeEventSource,
    required Route<dynamic>? fromRoute,
    required Route<dynamic>? toRoute,
  }) {
    final fromName = _routeName(fromRoute);
    final toName = _routeName(toRoute);
    try {
      _logEvent(
        event,
        'navigation',
        data: {
          'from_route': fromName,
          'to_route': toName,
        },
      );
      _logEvent(
        'ui.screen.expected',
        'ui',
        data: {
          'source': routeEventSource,
          'screen_name': _routeName(toRoute),
          'from_screen': fromName,
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
