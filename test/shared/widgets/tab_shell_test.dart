import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/map/domain/repositories/wake_lock_repository.dart';
import 'package:earth_nova/features/map/presentation/providers/wake_lock_provider.dart';
import 'package:earth_nova/shared/debug/debug_gesture_overlay.dart';
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

class _TrueDebugMode extends DebugModeNotifier {
  @override
  bool build() => true;
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
        'from_screen': 'map_root_screen',
        'to_screen': 'pack_screen',
        'raw_from_screen': 'map',
        'raw_to_screen': 'pack',
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
      // Verify PackScreen is instantiated (with injected controller)
      expect(source, contains('PackScreen('));
      // Verify it's the first screen in the list
      final mapRootScreenIndex = source.indexOf('const MapRootScreen()');
      final packScreenIndex = source.indexOf('PackScreen(');
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
      expect(transitions.last['from_screen'], 'map_root_screen');
      expect(transitions.last['to_screen'], 'pack_screen');

      // Tap on Sanctuary tab (index 2)
      await tester.tap(find.text('Sanctuary'));
      await tester.pumpAndSettle();

      expect(transitions.length, 2);
      expect(transitions.last['from_screen'], 'pack_screen');
      expect(transitions.last['to_screen'], 'stub_screen');

      // Tap back to Map tab (index 0)
      await tester.tap(find.text('Map'));
      await tester.pumpAndSettle();

      expect(transitions.length, 3);
      expect(transitions.last['from_screen'], 'stub_screen');
      expect(transitions.last['to_screen'], 'map_root_screen');
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
      expect(
          transitions
              .where((t) => t['from_screen'] == 'map_root_screen')
              .length,
          0);
    });

    testWidgets(
        'debug nav button appears when debug mode is on and toggles overlay',
        (tester) async {
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
            debugModeProvider.overrideWith(() => _TrueDebugMode()),
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

      // Bug icon button is present when debug mode is on.
      expect(find.byKey(const Key('debug_nav_button')), findsOneWidget);

      // Overlay is hidden initially.
      expect(find.byType(DebugGestureOverlay), findsNothing);

      // Tap the bug icon — overlay appears.
      await tester.tap(find.byKey(const Key('debug_nav_button')));
      await tester.pump();
      expect(find.byType(DebugGestureOverlay), findsOneWidget);

      // Tap again — overlay disappears.
      await tester.tap(find.byKey(const Key('debug_nav_button')));
      await tester.pump();
      expect(find.byType(DebugGestureOverlay), findsNothing);
    });

    testWidgets('debug nav button is absent when debug mode is off',
        (tester) async {
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

      expect(find.byKey(const Key('debug_nav_button')), findsNothing);
      expect(find.byType(DebugGestureOverlay), findsNothing);
    });

    testWidgets('releases wake lock when app is paused', (tester) async {
      final wakeLockCalls = <String>[];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            wakeLockRepositoryProvider.overrideWithValue(
              _TrackingWakeLockRepository(wakeLockCalls),
            ),
            wakeLockObservabilityProvider
                .overrideWithValue(_TestObservabilityService()),
            appObservabilityProvider
                .overrideWithValue(_TestObservabilityService()),
            navigationScreenTransitionLoggerProvider.overrideWithValue(
              NavigationScreenTransitionLogger(logEvent: (_, __, {data}) {}),
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
      wakeLockCalls.clear(); // ignore the initial acquire on init

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      expect(wakeLockCalls, contains('release'));
    });

    testWidgets('re-acquires wake lock when app resumes on map tab',
        (tester) async {
      final wakeLockCalls = <String>[];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            wakeLockRepositoryProvider.overrideWithValue(
              _TrackingWakeLockRepository(wakeLockCalls),
            ),
            wakeLockObservabilityProvider
                .overrideWithValue(_TestObservabilityService()),
            appObservabilityProvider
                .overrideWithValue(_TestObservabilityService()),
            navigationScreenTransitionLoggerProvider.overrideWithValue(
              NavigationScreenTransitionLogger(logEvent: (_, __, {data}) {}),
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
      wakeLockCalls.clear();

      // Pause then resume while on map tab (index 0)
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(wakeLockCalls, containsAllInOrder(['release', 'acquire']));
    });
  });

  // ─── Cross-tab swipe ───────────────────────────────────────────────────────

  group('TabShell cross-tab swipe', () {
    // Source-level wiring checks — no widget pump needed.
    test('source: TabShell injects PageController into PackScreen', () {
      final source =
          File('lib/shared/widgets/tab_shell.dart').readAsStringSync();
      expect(source, contains('_packPageController'));
      expect(source, contains('PackScreen('));
      expect(source, contains('pageController:'));
      expect(source, contains('onEdgeSwipe:'));
    });

    test('source: TabShell handles EdgeSwipeDirection.left → map tab', () {
      final source =
          File('lib/shared/widgets/tab_shell.dart').readAsStringSync();
      expect(source, contains('EdgeSwipeDirection.left'));
      expect(source, contains('_mapTabIndex'));
    });

    test('source: TabShell handles EdgeSwipeDirection.right → sanctuary tab',
        () {
      final source =
          File('lib/shared/widgets/tab_shell.dart').readAsStringSync();
      expect(source, contains('EdgeSwipeDirection.right'));
      expect(source, contains('_sanctuaryTabIndex'));
    });

    test('source: TabShell wraps IndexedStack in GestureDetector for map swipe',
        () {
      final source =
          File('lib/shared/widgets/tab_shell.dart').readAsStringSync();
      // A GestureDetector with onHorizontalDragEnd (or onPanEnd) must wrap the
      // IndexedStack so a leftward swipe on the map tab navigates to Pack.
      expect(source, contains('onHorizontalDragEnd'));
      expect(source, contains('_packTabIndex'));
    });
  }); // end cross-tab swipe group

  group('TabShell swipe-from-map', () {
    Future<void> pumpShellWithFakeScreens(
      WidgetTester tester, {
      required List<String> transitions,
    }) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

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
                    transitions
                        .add('${data?['from_screen']}→${data?['to_screen']}');
                  }
                },
              ),
            ),
            debugModeProvider.overrideWith(() => _FalseDebugMode()),
          ],
          child: MaterialApp(
            home: TabShell(
              screens: const [
                // Use SizedBox.expand so the GestureDetector has a hit area.
                SizedBox.expand(), // map
                SizedBox.expand(), // pack
                SizedBox.expand(), // sanctuary
                SizedBox.expand(), // settings
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('leftward fling on map tab navigates to Pack tab',
        (tester) async {
      final transitions = <String>[];
      await pumpShellWithFakeScreens(tester, transitions: transitions);

      // We are on Map (index 0). Fling leftward (negative x velocity) to
      // trigger onHorizontalDragEnd with primaryVelocity < 0 → Pack tab.
      // Matches the natural "next page" swipe convention (right→left).
      // Use the GestureDetector directly — IndexedStack children are SizedBox.expand()
      // and have a hit area.
      await tester.fling(
        find.byType(GestureDetector).first,
        const Offset(-300, 0), // negative x = leftward fling
        800, // px/s — enough to produce negative primaryVelocity
      );
      await tester.pumpAndSettle();

      expect(transitions, contains('map_root_screen→pack_screen'));
    });
  }); // end swipe-from-map group
} // end main()

class _TrackingWakeLockRepository implements WakeLockRepository {
  _TrackingWakeLockRepository(this._calls);
  final List<String> _calls;

  @override
  Future<void> acquire() async => _calls.add('acquire');

  @override
  Future<void> release() async => _calls.add('release');
}
