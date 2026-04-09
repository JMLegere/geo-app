import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/shared/debug/debug_mode_provider.dart';

class _TestObservabilityService extends ObservabilityService {
  _TestObservabilityService() : super(sessionId: 'test-session');

  final List<String> events = [];

  @override
  void log(String event, String category, {Map<String, dynamic>? data}) {
    events.add(event);
    super.log(event, category, data: data);
  }
}

ProviderContainer makeContainer({
  required SharedPreferences prefs,
  _TestObservabilityService? obs,
}) {
  return ProviderContainer(
    overrides: [
      debugModeObservabilityProvider.overrideWithValue(
        obs ?? _TestObservabilityService(),
      ),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
  );
}

void main() {
  group('DebugModeNotifier', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('default state is false', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = makeContainer(prefs: prefs);
      addTearDown(container.dispose);

      expect(container.read(debugModeProvider), false);
    });

    test('toggle() changes state to true', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = makeContainer(prefs: prefs);
      addTearDown(container.dispose);

      container.read(debugModeProvider.notifier).toggle();
      await Future<void>.delayed(Duration.zero);

      expect(container.read(debugModeProvider), true);
    });

    test('second toggle() changes state back to false', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = makeContainer(prefs: prefs);
      addTearDown(container.dispose);

      container.read(debugModeProvider.notifier).toggle();
      await Future<void>.delayed(Duration.zero);
      container.read(debugModeProvider.notifier).toggle();
      await Future<void>.delayed(Duration.zero);

      expect(container.read(debugModeProvider), false);
    });

    test('toggle() persists — fresh notifier with same prefs reads true',
        () async {
      final prefs = await SharedPreferences.getInstance();

      final container1 = makeContainer(prefs: prefs);
      container1.read(debugModeProvider.notifier).toggle();
      await Future<void>.delayed(Duration.zero);
      container1.dispose();

      final container2 = makeContainer(prefs: prefs);
      addTearDown(container2.dispose);

      expect(container2.read(debugModeProvider), true);
    });

    test('toggle() calls transition() — observability event emitted', () async {
      final prefs = await SharedPreferences.getInstance();
      final obs = _TestObservabilityService();
      final container = makeContainer(prefs: prefs, obs: obs);
      addTearDown(container.dispose);

      container.read(debugModeProvider.notifier).toggle();
      await Future<void>.delayed(Duration.zero);

      expect(obs.events, contains('debug.toggle'));
    });
  });
}
