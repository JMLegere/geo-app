import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fog_of_world/features/navigation/providers/tab_index_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('TabIndexNotifier', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('initial state is 0 (Map tab)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(tabIndexProvider), 0);
    });

    test('setTab(2) updates state to 2', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(tabIndexProvider.notifier).setTab(2);

      expect(container.read(tabIndexProvider), 2);
    });

    test('setTab(0) sets Map tab', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(tabIndexProvider.notifier).setTab(1);
      await container.read(tabIndexProvider.notifier).setTab(0);

      expect(container.read(tabIndexProvider), 0);
    });

    test('setTab(3) sets Pack tab (last valid index)', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(tabIndexProvider.notifier).setTab(3);

      expect(container.read(tabIndexProvider), 3);
    });

    test('out-of-range index -1 is rejected', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(tabIndexProvider.notifier).setTab(2);
      await container.read(tabIndexProvider.notifier).setTab(-1);

      // State stays at 2 — out-of-range was ignored
      expect(container.read(tabIndexProvider), 2);
    });

    test('out-of-range index 4 is rejected', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(tabIndexProvider.notifier).setTab(1);
      await container.read(tabIndexProvider.notifier).setTab(4);

      // State stays at 1 — out-of-range was ignored
      expect(container.read(tabIndexProvider), 1);
    });

    test('persists to SharedPreferences', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(tabIndexProvider.notifier).setTab(3);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('selected_tab_index'), 3);
    });

    test('restores persisted value on new container build', () async {
      // Write a value directly into SharedPreferences
      SharedPreferences.setMockInitialValues({'selected_tab_index': 2});

      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Read initial state (synchronously = 0, the default)
      // Then wait for the async _loadState to complete
      container.read(tabIndexProvider);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(tabIndexProvider), 2);
    });

    test('ignores persisted value outside valid range', () async {
      // Corrupt / out-of-range value in prefs
      SharedPreferences.setMockInitialValues({'selected_tab_index': 99});

      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(tabIndexProvider);
      await Future<void>.delayed(Duration.zero);

      // Falls back to default 0
      expect(container.read(tabIndexProvider), 0);
    });
  });
}
