import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:earth_nova/core/observability/observable_notifier.dart';
import 'package:earth_nova/core/observability/observability_service.dart';

const _kDebugModeKey = 'debug_mode_enabled';

final debugModeObservabilityProvider = Provider<ObservabilityService>((ref) {
  throw UnimplementedError('Must be overridden with overrideWithValue');
});

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Must be overridden with overrideWithValue');
});

final debugModeProvider =
    NotifierProvider<DebugModeNotifier, bool>(DebugModeNotifier.new);

class DebugModeNotifier extends ObservableNotifier<bool> {
  @override
  ObservabilityService get obs => ref.watch(debugModeObservabilityProvider);

  @override
  String get category => 'debug';

  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getBool(_kDebugModeKey) ?? false;
  }

  void toggle() {
    final prefs = ref.read(sharedPreferencesProvider);
    final next = !state;
    prefs.setBool(_kDebugModeKey, next);
    transition(next, 'debug.toggle');
  }
}
