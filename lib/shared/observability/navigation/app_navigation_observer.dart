import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef NavigationLogEvent = void Function(
  String event,
  String category, {
  Map<String, dynamic>? data,
});

String normalizeScreenNameForTelemetry(String screenName) {
  final trimmed = screenName.trim();
  if (trimmed.isEmpty) return 'unknown';
  if (trimmed == '/') return 'loading_screen';

  const aliases = {
    'loading': 'loading_screen',
    'login': 'login_screen',
    'home': 'tab_shell',
    'map': 'map_root_screen',
    'pack': 'pack_screen',
    'sanctuary': 'stub_screen',
    'settings': 'settings_screen',
    'map.cell': 'map_screen',
    'map.district': 'district_screen',
    'map.city': 'city_screen',
    'map.state': 'province_screen',
    'map.province': 'province_screen',
    'map.country': 'country_screen',
    'map.world': 'world_screen',
  };

  final alias = aliases[trimmed];
  if (alias != null) return alias;

  if (trimmed.startsWith('/')) {
    final routeAlias = aliases[trimmed.substring(1)];
    if (routeAlias != null) return routeAlias;
  }

  return trimmed;
}

Map<String, dynamic> _screenChangedPayload({
  required String source,
  required String rawFromScreen,
  required String rawToScreen,
}) {
  final fromScreen = normalizeScreenNameForTelemetry(rawFromScreen);
  final toScreen = normalizeScreenNameForTelemetry(rawToScreen);
  return {
    'source': source,
    'from_screen': fromScreen,
    'to_screen': toScreen,
    if (fromScreen != rawFromScreen) 'raw_from_screen': rawFromScreen,
    if (toScreen != rawToScreen) 'raw_to_screen': rawToScreen,
  };
}

Map<String, dynamic> _expectedScreenPayload({
  required String source,
  required String rawFromScreen,
  required String rawToScreen,
}) {
  final fromScreen = normalizeScreenNameForTelemetry(rawFromScreen);
  final toScreen = normalizeScreenNameForTelemetry(rawToScreen);
  return {
    'source': source,
    'screen_name': toScreen,
    'from_screen': fromScreen,
    if (toScreen != rawToScreen) 'raw_screen_name': rawToScreen,
    if (fromScreen != rawFromScreen) 'raw_from_screen': rawFromScreen,
  };
}

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
      data: _screenChangedPayload(
        source: source,
        rawFromScreen: fromScreen,
        rawToScreen: toScreen,
      ),
    );
    _safeLog(
      'ui.screen.expected',
      category: 'ui',
      data: _expectedScreenPayload(
        source: source,
        rawFromScreen: fromScreen,
        rawToScreen: toScreen,
      ),
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
        data: _expectedScreenPayload(
          source: routeEventSource,
          rawFromScreen: fromName,
          rawToScreen: toName,
        ),
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
