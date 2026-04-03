import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/providers/tab_provider.dart';

void main() {
  group('TabIndexNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
      addTearDown(container.dispose);
    });

    test('initial state is 0 (Map tab)', () {
      expect(container.read(tabIndexProvider), 0);
    });

    test('setTab changes index', () {
      container.read(tabIndexProvider.notifier).setTab(1);
      expect(container.read(tabIndexProvider), 1);
    });

    test('setTab to 2 selects Pack tab', () {
      container.read(tabIndexProvider.notifier).setTab(2);
      expect(container.read(tabIndexProvider), 2);
    });

    test('setTab back to 0 returns to Map', () {
      container.read(tabIndexProvider.notifier).setTab(2);
      container.read(tabIndexProvider.notifier).setTab(0);
      expect(container.read(tabIndexProvider), 0);
    });
  });
}
