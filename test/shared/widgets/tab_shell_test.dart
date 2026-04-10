import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/map/domain/repositories/wake_lock_repository.dart';
import 'package:earth_nova/features/map/presentation/providers/wake_lock_provider.dart';
import 'package:earth_nova/shared/debug/debug_mode_provider.dart';
import 'package:earth_nova/shared/observability/navigation/app_navigation_observer.dart';
import 'package:earth_nova/shared/widgets/tab_shell.dart';

class _FakeWakeLockRepository implements WakeLockRepository {
  @override
  Future<void> acquire() async {}

  @override
  Future<void> release() async {}
}

class _TestObservabilityService extends ObservabilityService {
  _TestObservabilityService() : super(sessionId: 'test-session');
}

class _FalseDebugMode extends DebugModeNotifier {
  @override
  bool build() => false;
}

void main() {
  group('TabShell navigation observability', () {
    testWidgets('logs tab screen changes exactly once per transition',
        (tester) async {
      final transitions =
          <({String event, String category, Map<String, dynamic>? data})>[];
      final navigation = NavigationScreenTransitionLogger(
        logEvent: (event, category, {data}) {
          transitions.add((event: event, category: category, data: data));
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            wakeLockRepositoryProvider
                .overrideWithValue(_FakeWakeLockRepository()),
            wakeLockObservabilityProvider
                .overrideWithValue(_TestObservabilityService()),
            appObservabilityProvider
                .overrideWithValue(_TestObservabilityService()),
            navigationScreenTransitionLoggerProvider
                .overrideWithValue(navigation),
            debugModeProvider.overrideWith(() => _FalseDebugMode()),
          ],
          child: const MaterialApp(
            home: TabShell(
              screens: [
                SizedBox.shrink(),
                SizedBox.shrink(),
                SizedBox.shrink(),
                SizedBox.shrink(),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.text('Pack'));
      await tester.pump();

      await tester.tap(find.text('Pack'));
      await tester.pump();

      final screenChangedEvents = transitions
          .where((event) => event.event == 'navigation.screen_changed')
          .toList();
      expect(screenChangedEvents.length, 1);
      expect(screenChangedEvents.single.category, 'navigation');
      expect(screenChangedEvents.single.data, {
        'source': 'tab_shell',
        'from_screen': 'map',
        'to_screen': 'pack',
      });
    });
  });

  test('tab shell keeps cached IndexedStack screen list', () {
    final source = File('lib/shared/widgets/tab_shell.dart').readAsStringSync();

    expect(source, contains('IndexedStack('));
    expect(source, contains('late final List<Widget> _screens;'));
    expect(source, contains('children: _screens'));
  });

  group('TabShell MapRootScreen wiring', () {
    test('imports MapRootScreen', () {
      final source =
          File('lib/shared/widgets/tab_shell.dart').readAsStringSync();

      expect(
        source,
        contains(
            "import 'package:earth_nova/features/map/presentation/screens/map_root_screen.dart';"),
      );
    });

    test('instantiates MapRootScreen as first tab in default screens', () {
      final source =
          File('lib/shared/widgets/tab_shell.dart').readAsStringSync();

      // Verify MapRootScreen is instantiated in default screens list
      expect(source, contains('const MapRootScreen()'));
      // Verify it's the first screen in the list
      final mapRootScreenIndex = source.indexOf('const MapRootScreen()');
      final packScreenIndex = source.indexOf('const PackScreen()');
      expect(mapRootScreenIndex, lessThan(packScreenIndex));
    });

    test('does not instantiate MapScreen directly in TabShell', () {
      final source =
          File('lib/shared/widgets/tab_shell.dart').readAsStringSync();

      // MapScreen should NOT be instantiated directly in TabShell
      // It should only be inside MapRootScreen
      expect(source, isNot(contains('const MapScreen()')));
      expect(source, isNot(contains('MapScreen()')));
    });

    testWidgets('renders injected screens correctly', (tester) async {
      // Use injected screens to avoid complex dependencies
      final screenKeys = [
        const ValueKey('screen-0'),
        const ValueKey('screen-1'),
        const ValueKey('screen-2'),
        const ValueKey('screen-3'),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            wakeLockRepositoryProvider
                .overrideWithValue(_FakeWakeLockRepository()),
            wakeLockObservabilityProvider
                .overrideWithValue(_TestObservabilityService()),
            appObservabilityProvider
                .overrideWithValue(_TestObservabilityService()),
            navigationScreenTransitionLoggerProvider.overrideWithValue(
              NavigationScreenTransitionLogger(logEvent: (_, __, {data}) {}),
            ),
            debugModeProvider.overrideWith(() => _FalseDebugMode()),
          ],
          child: MaterialApp(
            home: TabShell(
              screens: [
                SizedBox(key: screenKeys[0]),
                SizedBox(key: screenKeys[1]),
                SizedBox(key: screenKeys[2]),
                SizedBox(key: screenKeys[3]),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // First screen should be visible (onstage in IndexedStack)
      expect(find.byKey(screenKeys[0]), findsOneWidget);
      // Verify IndexedStack is present
      expect(find.byType(IndexedStack), findsOneWidget);
    });

    testWidgets('tab switching works with IndexedStack', (tester) async {
      final transitions = <Map<String, dynamic>>[];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            wakeLockRepositoryProvider
                .overrideWithValue(_FakeWakeLockRepository()),
            wakeLockObservabilityProvider
                .overrideWithValue(_TestObservabilityService()),
            appObservabilityProvider
                .overrideWithValue(_TestObservabilityService()),
            navigationScreenTransitionLoggerProvider.overrideWithValue(
              NavigationScreenTransitionLogger(
                logEvent: (event, category, {data}) {
                  if (event == 'navigation.screen_changed') {
                    transitions.add(data ?? {});
                  }
                },
              ),
            ),
            debugModeProvider.overrideWith(() => _FalseDebugMode()),
          ],
          child: const MaterialApp(
            home: TabShell(
              screens: [
                SizedBox.shrink(),
                SizedBox.shrink(),
                SizedBox.shrink(),
                SizedBox.shrink(),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify IndexedStack is present
      expect(find.byType(IndexedStack), findsOneWidget);

      // Tap on Pack tab (index 1)
      await tester.tap(find.text('Pack'));
      await tester.pumpAndSettle();

      // Should have logged the transition
      expect(transitions.length, 1);
      expect(transitions.last['from_screen'], 'map');
      expect(transitions.last['to_screen'], 'pack');

      // Tap on Sanctuary tab (index 2)
      await tester.tap(find.text('Sanctuary'));
      await tester.pumpAndSettle();

      expect(transitions.length, 2);
      expect(transitions.last['from_screen'], 'pack');
      expect(transitions.last['to_screen'], 'sanctuary');

      // Tap back to Map tab (index 0)
      await tester.tap(find.text('Map'));
      await tester.pumpAndSettle();

      expect(transitions.length, 3);
      expect(transitions.last['from_screen'], 'sanctuary');
      expect(transitions.last['to_screen'], 'map');
    });

    testWidgets('tapping same tab does not trigger transition', (tester) async {
      final transitions = <Map<String, dynamic>>[];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            wakeLockRepositoryProvider
                .overrideWithValue(_FakeWakeLockRepository()),
            wakeLockObservabilityProvider
                .overrideWithValue(_TestObservabilityService()),
            appObservabilityProvider
                .overrideWithValue(_TestObservabilityService()),
            navigationScreenTransitionLoggerProvider.overrideWithValue(
              NavigationScreenTransitionLogger(
                logEvent: (event, category, {data}) {
                  if (event == 'navigation.screen_changed') {
                    transitions.add(data ?? {});
                  }
                },
              ),
            ),
            debugModeProvider.overrideWith(() => _FalseDebugMode()),
          ],
          child: const MaterialApp(
            home: TabShell(
              screens: [
                SizedBox.shrink(),
                SizedBox.shrink(),
                SizedBox.shrink(),
                SizedBox.shrink(),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap same tab multiple times
      await tester.tap(find.text('Map'));
      await tester.pump();
      await tester.tap(find.text('Map'));
      await tester.pump();
      await tester.tap(find.text('Map'));
      await tester.pump();

      // Should have no transitions (already on Map tab)
      expect(transitions.where((t) => t['from_screen'] == 'map').length, 0);
    });
  });
}
