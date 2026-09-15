import 'dart:io';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/core/domain/entities/habitat.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/map/domain/repositories/wake_lock_repository.dart';
import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/features/map/domain/entities/encounter.dart';
import 'package:earth_nova/features/map/domain/entities/location_state.dart';
import 'package:earth_nova/features/map/domain/entities/player_marker_state.dart';
import 'package:earth_nova/features/map/presentation/providers/wake_lock_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/encounter_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/desktop_controls_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/exploration_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/location_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/map_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/player_marker_provider.dart';
import 'package:earth_nova/ui/product_surfaces/debug/debug_gesture_overlay.dart';
import 'package:earth_nova/shared/debug/debug_mode_provider.dart';
import 'package:earth_nova/shared/observability/navigation/app_navigation_observer.dart';
import 'package:earth_nova/shared/product/player_actions.dart';
import 'package:earth_nova/ui/product_surfaces/app/tab_shell.dart';

class _FakeWakeLockRepository implements WakeLockRepository {
  @override
  Future<void> acquire() async {}

  @override
  Future<void> release() async {}
}

class _TestObservabilityService extends ObservabilityService {
  _TestObservabilityService() : super(sessionId: 'test-session');

  final List<({String event, String category, Map<String, dynamic>? data})>
  events = [];

  @override
  void log(String event, String category, {Map<String, dynamic>? data}) {
    events.add((event: event, category: category, data: data));
    super.log(event, category, data: data);
  }
}

class _TrueDebugMode extends DebugModeNotifier {
  @override
  bool build() => true;
}

class _FalseDebugMode extends DebugModeNotifier {
  @override
  bool build() => false;
}

Cell _cell(String id, double centerLat, double centerLng) {
  const half = 0.0001;
  return Cell(
    id: id,
    habitats: const [Habitat.forest],
    polygons: [
      [
        [
          (lat: centerLat - half, lng: centerLng - half),
          (lat: centerLat - half, lng: centerLng + half),
          (lat: centerLat + half, lng: centerLng + half),
          (lat: centerLat + half, lng: centerLng - half),
        ],
      ],
    ],
    districtId: 'district',
    cityId: 'city',
    stateId: 'state',
    countryId: 'country',
  );
}

class _ReadyMapNotifier extends MapNotifier {
  @override
  MapState build() {
    return MapStateReady(
      cells: [
        _cell('current', 0, 0),
        _cell('backend-visited', 0, 0.001),
        _cell('target', 0, 0.002),
      ],
      visitedCellIds: const {'backend-visited'},
      location: LocationState(
        lat: 0,
        lng: 0,
        accuracy: 1,
        timestamp: DateTime(2026),
        isConfident: true,
      ),
    );
  }
}

class _ReadyExplorationNotifier extends ExplorationNotifier {
  @override
  ExplorationStateData build() {
    return const ExplorationStateData(
      currentCellId: 'current',
      visitedCellIds: {'session-visited'},
    );
  }
}

class _ReadyPlayerMarkerNotifier extends PlayerMarkerNotifier {
  @override
  PlayerMarkerState build() {
    return const PlayerMarkerState(
      lat: 0,
      lng: 0,
      isRing: false,
      gapDistance: 0,
    );
  }
}

class _PackImpactEncounterNotifier extends EncounterNotifier {
  @override
  EncounterState build() => const EncounterState(packImpactCount: 1);
}

const _testFlyingReward = Encounter(
  type: EncounterType.species,
  speciesId: 'reward-1',
  displayName: 'Monarch Butterfly',
  cellId: 'cell-1',
  seed: 'seed-1',
  rarity: 'rare',
);

class _FlyingRewardEncounterNotifier extends EncounterNotifier {
  _FlyingRewardEncounterNotifier(this.completions);

  final List<String> completions;

  @override
  EncounterState build() =>
      const EncounterState(flyingReward: _testFlyingReward);

  @override
  void completeRewardFlight() {
    final completedReward = state.flyingReward;
    if (completedReward == null) return;
    completions.add(completedReward.speciesId);
    transition(
      state.copyWith(
        flyingReward: null,
        packImpactCount: state.packImpactCount + 1,
      ),
      'discovery.reward_flight_completed',
      data: {'completed_result_id': completedReward.speciesId},
    );
  }
}

class _TrackingLocationNotifier extends LocationNotifier {
  _TrackingLocationNotifier(this.calls);

  final List<({double lat, double lng, String? targetCellId, String reason})>
  calls;

  @override
  LocationProviderState build() {
    return LocationProviderActive(
      LocationState(
        lat: 0,
        lng: 0,
        accuracy: 1,
        timestamp: DateTime(2026),
        isConfident: true,
      ),
    );
  }

  @override
  void moveDebugLocation(DebugLocationMoveDirection direction) {}

  @override
  void moveDebugLocationTo({
    required double lat,
    required double lng,
    String? targetCellId,
    String reason = 'explicit_target',
  }) {
    calls.add((lat: lat, lng: lng, targetCellId: targetCellId, reason: reason));
  }

  @override
  void resumeGps() {}
}

void main() {
  Future<void> pumpNeutralShell(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          wakeLockRepositoryProvider.overrideWithValue(
            _FakeWakeLockRepository(),
          ),
          wakeLockObservabilityProvider.overrideWithValue(
            _TestObservabilityService(),
          ),
          appObservabilityProvider.overrideWithValue(
            _TestObservabilityService(),
          ),
          navigationScreenTransitionLoggerProvider.overrideWithValue(
            NavigationScreenTransitionLogger(logEvent: (_, __, {data}) {}),
          ),
          debugModeProvider.overrideWith(() => _FalseDebugMode()),
        ],
        child: const ShadApp(
          home: TabShell(screens: [SizedBox.shrink(), SizedBox.shrink()]),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Help labels are explicit, persistent, and dismissed by a destination',
    (tester) async {
      await pumpNeutralShell(tester);
      expect(find.text('Map'), findsNothing);
      expect(find.text('Pack'), findsNothing);
      await tester.tap(find.byKey(const Key('tab-shell-nav-help')));
      await tester.pumpAndSettle();
      expect(find.text('Map'), findsOneWidget);
      expect(find.text('Pack'), findsOneWidget);
      await tester.pump(const Duration(minutes: 1));
      expect(find.text('Pack'), findsOneWidget);
      await tester.tap(find.byKey(const Key('tab-shell-nav-button-map')));
      await tester.pumpAndSettle();
      expect(find.text('Map'), findsNothing);
    },
  );

  group('TabShell navigation observability', () {
    testWidgets('logs tab screen changes exactly once per transition', (
      tester,
    ) async {
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
            wakeLockRepositoryProvider.overrideWithValue(
              _FakeWakeLockRepository(),
            ),
            wakeLockObservabilityProvider.overrideWithValue(
              _TestObservabilityService(),
            ),
            appObservabilityProvider.overrideWithValue(
              _TestObservabilityService(),
            ),
            navigationScreenTransitionLoggerProvider.overrideWithValue(
              navigation,
            ),
            debugModeProvider.overrideWith(() => _FalseDebugMode()),
          ],
          child: const ShadApp(
            home: TabShell(screens: [SizedBox.shrink(), SizedBox.shrink()]),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('tab-shell-nav-button-pack')));
      await tester.pump();

      await tester.tap(find.byKey(const Key('tab-shell-nav-button-pack')));
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

    testWidgets('logs Pack tab selection as an open-pack player action', (
      tester,
    ) async {
      final interactions = _TestObservabilityService();
      final navigation = NavigationScreenTransitionLogger(
        logEvent: (event, category, {data}) {},
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            wakeLockRepositoryProvider.overrideWithValue(
              _FakeWakeLockRepository(),
            ),
            wakeLockObservabilityProvider.overrideWithValue(interactions),
            appObservabilityProvider.overrideWithValue(interactions),
            navigationScreenTransitionLoggerProvider.overrideWithValue(
              navigation,
            ),
            debugModeProvider.overrideWith(() => _FalseDebugMode()),
          ],
          child: const ShadApp(
            home: TabShell(screens: [SizedBox.shrink(), SizedBox.shrink()]),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('tab-shell-nav-button-pack')));
      await tester.pump();

      final tabSelectionEvents = interactions.events
          .where(
            (event) =>
                event.event == 'interaction.action' &&
                event.data?['widget_name'] == 'bottom_navigation_bar',
          )
          .toList();

      expect(tabSelectionEvents, hasLength(1));
      expect(
        tabSelectionEvents.single.data,
        containsPair('action_type', 'tab_selected'),
      );
      expect(
        tabSelectionEvents.single.data,
        containsPair('screen_name', 'tab_shell'),
      );
      expect(
        tabSelectionEvents.single.data,
        containsPair('widget_name', 'bottom_navigation_bar'),
      );
      expect(
        tabSelectionEvents.single.data,
        containsPair('player_action_id', PlayerActions.openPack),
      );
      expect(tabSelectionEvents.single.data, containsPair('tab_index', 1));
    });
  });

  test('tab shell keeps cached IndexedStack screen list', () {
    final source = File(
      'lib/ui/product_surfaces/app/tab_shell.dart',
    ).readAsStringSync();

    expect(source, contains('IndexedStack('));
    expect(source, contains('late final List<Widget> _screens;'));
    expect(source, contains('children: _screens'));
  });

  group('TabShell MapRootScreen wiring', () {
    test('imports MapRootScreen', () {
      final source = File(
        'lib/ui/product_surfaces/app/tab_shell.dart',
      ).readAsStringSync();

      expect(
        source,
        contains(
          "import 'package:earth_nova/ui/product_surfaces/map/screens/map_root_screen.dart';",
        ),
      );
    });

    test('instantiates MapRootScreen as first tab in default screens', () {
      final source = File(
        'lib/ui/product_surfaces/app/tab_shell.dart',
      ).readAsStringSync();

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
      final source = File(
        'lib/ui/product_surfaces/app/tab_shell.dart',
      ).readAsStringSync();

      // MapScreen should NOT be instantiated directly in TabShell
      // It should only be inside MapRootScreen
      expect(source, isNot(contains('const MapScreen()')));
      expect(source, isNot(contains('MapScreen()')));
    });

    test(
      'declares Map and Pack as the only bottom navigation destinations',
      () {
        final source = File(
          'lib/ui/product_surfaces/app/tab_shell.dart',
        ).readAsStringSync();

        expect(source, contains("label: 'Map'"));
        expect(source, contains("label: 'Pack'"));
        expect(source, isNot(contains("label: 'Player'")));
        expect(source, isNot(contains("label: 'Town'")));
        expect(source, isNot(contains("label: 'Home'")));
        expect(source, isNot(contains('NavigationRail')));
      },
    );
    testWidgets('renders injected screens correctly', (tester) async {
      // Use injected screens to avoid complex dependencies
      final screenKeys = [
        const ValueKey('screen-0'),
        const ValueKey('screen-1'),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            wakeLockRepositoryProvider.overrideWithValue(
              _FakeWakeLockRepository(),
            ),
            wakeLockObservabilityProvider.overrideWithValue(
              _TestObservabilityService(),
            ),
            appObservabilityProvider.overrideWithValue(
              _TestObservabilityService(),
            ),
            navigationScreenTransitionLoggerProvider.overrideWithValue(
              NavigationScreenTransitionLogger(logEvent: (_, __, {data}) {}),
            ),
            debugModeProvider.overrideWith(() => _FalseDebugMode()),
          ],
          child: ShadApp(
            home: TabShell(
              screens: [
                SizedBox(key: screenKeys[0]),
                SizedBox(key: screenKeys[1]),
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

    testWidgets(
      'Map starts selected, Pack mounts once, and returning to Map reacquires the wake lock',
      (tester) async {
        final wakeLockCalls = <String>[];
        final semantics = tester.ensureSemantics();
        const mapScreenKey = Key('map-screen');
        const packScreenKey = Key('pack-screen');

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              wakeLockRepositoryProvider.overrideWithValue(
                _TrackingWakeLockRepository(wakeLockCalls),
              ),
              wakeLockObservabilityProvider.overrideWithValue(
                _TestObservabilityService(),
              ),
              appObservabilityProvider.overrideWithValue(
                _TestObservabilityService(),
              ),
              navigationScreenTransitionLoggerProvider.overrideWithValue(
                NavigationScreenTransitionLogger(logEvent: (_, __, {data}) {}),
              ),
              debugModeProvider.overrideWith(() => _FalseDebugMode()),
            ],
            child: const ShadApp(
              home: TabShell(
                screens: [
                  SizedBox.expand(key: mapScreenKey),
                  SizedBox.expand(key: packScreenKey),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        wakeLockCalls.clear();

        expect(find.byKey(mapScreenKey), findsOneWidget);
        expect(find.byKey(packScreenKey), findsNothing);
        expect(
          tester
                  .getSemantics(find.byKey(const Key('tab-shell-nav-item-map')))
                  .flagsCollection
                  .isSelected ==
              Tristate.isTrue,
          isTrue,
        );

        await tester.tap(find.byKey(const Key('tab-shell-nav-item-pack')));
        await tester.pumpAndSettle();

        expect(find.byKey(mapScreenKey), findsNothing);
        expect(find.byKey(packScreenKey), findsOneWidget);
        expect(
          tester
                  .getSemantics(
                    find.byKey(const Key('tab-shell-nav-item-pack')),
                  )
                  .flagsCollection
                  .isSelected ==
              Tristate.isTrue,
          isTrue,
        );
        expect(wakeLockCalls, ['release']);

        await tester.tap(find.byKey(const Key('tab-shell-nav-item-map')));
        await tester.pumpAndSettle();

        expect(find.byKey(mapScreenKey), findsOneWidget);
        expect(wakeLockCalls, ['release', 'acquire']);
        semantics.dispose();
      },
    );

    testWidgets('does not overlay Pack icon when a reward lands', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            wakeLockRepositoryProvider.overrideWithValue(
              _FakeWakeLockRepository(),
            ),
            wakeLockObservabilityProvider.overrideWithValue(
              _TestObservabilityService(),
            ),
            appObservabilityProvider.overrideWithValue(
              _TestObservabilityService(),
            ),
            navigationScreenTransitionLoggerProvider.overrideWithValue(
              NavigationScreenTransitionLogger(logEvent: (_, __, {data}) {}),
            ),
            debugModeProvider.overrideWith(() => _FalseDebugMode()),
            encounterProvider.overrideWith(
              () => _PackImpactEncounterNotifier(),
            ),
          ],
          child: const ShadApp(
            home: TabShell(screens: [SizedBox.shrink(), SizedBox.shrink()]),
          ),
        ),
      );

      expect(find.byKey(const Key('pack-reward-impact')), findsNothing);
      expect(find.byKey(const Key('pack-reward-flight-card')), findsNothing);
    });

    testWidgets(
      'renders neutral bottom navigation with selected semantics and a persistent cue',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await pumpNeutralShell(tester);

        final navFinder = find.byKey(const Key('tab-shell-bottom-navigation'));
        final nav = tester.widget<Material>(navFinder);
        final colors = Theme.of(tester.element(navFinder)).colorScheme;
        final navBorder = nav.shape! as Border;

        expect(tester.getSize(navFinder).height, 76);
        expect(nav.color, colors.surface);
        expect(nav.elevation, 0);
        expect(navBorder.top.color, colors.outlineVariant);
        expect(find.byType(ShadButton), findsNWidgets(3));
        expect(
          find.byKey(const Key('tab-shell-nav-selected-map')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('tab-shell-nav-selected-pack')),
          findsNothing,
        );
        expect(
          tester
                  .getSemantics(find.byKey(const Key('tab-shell-nav-item-map')))
                  .flagsCollection
                  .isSelected ==
              Tristate.isTrue,
          isTrue,
        );

        await tester.tap(find.byKey(const Key('tab-shell-nav-item-pack')));
        await tester.pump();

        expect(
          find.byKey(const Key('tab-shell-nav-selected-map')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('tab-shell-nav-selected-pack')),
          findsOneWidget,
        );
        expect(
          tester
                  .getSemantics(
                    find.byKey(const Key('tab-shell-nav-item-pack')),
                  )
                  .flagsCollection
                  .isSelected ==
              Tristate.isTrue,
          isTrue,
        );
        semantics.dispose();
      },
    );

    testWidgets('activates the focused destination from the keyboard', (
      tester,
    ) async {
      await pumpNeutralShell(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(
        find.byKey(const Key('tab-shell-nav-selected-pack')),
        findsOneWidget,
      );
    });

    testWidgets(
      'completes discovery reward without drawing Pack nav overlays',
      (tester) async {
        final completions = <String>[];

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              wakeLockRepositoryProvider.overrideWithValue(
                _FakeWakeLockRepository(),
              ),
              wakeLockObservabilityProvider.overrideWithValue(
                _TestObservabilityService(),
              ),
              appObservabilityProvider.overrideWithValue(
                _TestObservabilityService(),
              ),
              encounterObservabilityProvider.overrideWithValue(
                _TestObservabilityService(),
              ),
              navigationScreenTransitionLoggerProvider.overrideWithValue(
                NavigationScreenTransitionLogger(logEvent: (_, __, {data}) {}),
              ),
              debugModeProvider.overrideWith(() => _FalseDebugMode()),
              encounterProvider.overrideWith(
                () => _FlyingRewardEncounterNotifier(completions),
              ),
            ],
            child: const ShadApp(
              home: TabShell(screens: [SizedBox.shrink(), SizedBox.shrink()]),
            ),
          ),
        );

        expect(find.byKey(const Key('pack-reward-flight-card')), findsNothing);
        expect(find.byKey(const Key('pack-reward-impact')), findsNothing);

        await tester.pump();

        expect(completions, ['reward-1']);
        expect(find.byKey(const Key('pack-reward-flight-card')), findsNothing);
        expect(find.byKey(const Key('pack-reward-impact')), findsNothing);
      },
    );

    testWidgets('tab switching works with IndexedStack', (tester) async {
      final transitions = <Map<String, dynamic>>[];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            wakeLockRepositoryProvider.overrideWithValue(
              _FakeWakeLockRepository(),
            ),
            wakeLockObservabilityProvider.overrideWithValue(
              _TestObservabilityService(),
            ),
            appObservabilityProvider.overrideWithValue(
              _TestObservabilityService(),
            ),
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
          child: const ShadApp(
            home: TabShell(screens: [SizedBox.shrink(), SizedBox.shrink()]),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify IndexedStack is present
      expect(find.byType(IndexedStack), findsOneWidget);

      // Tap Pack (index 1).
      await tester.tap(find.byKey(const Key('tab-shell-nav-button-pack')));
      await tester.pumpAndSettle();

      expect(transitions, hasLength(1));
      expect(transitions.last['from_screen'], 'map_root_screen');
      expect(transitions.last['to_screen'], 'pack_screen');

      // Tap back to Map (index 0).
      await tester.tap(find.byKey(const Key('tab-shell-nav-button-map')));
      await tester.pumpAndSettle();

      expect(transitions, hasLength(2));
      expect(transitions.last['from_screen'], 'pack_screen');
      expect(transitions.last['to_screen'], 'map_root_screen');
    });

    testWidgets('tapping same tab does not trigger transition', (tester) async {
      final transitions = <Map<String, dynamic>>[];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            wakeLockRepositoryProvider.overrideWithValue(
              _FakeWakeLockRepository(),
            ),
            wakeLockObservabilityProvider.overrideWithValue(
              _TestObservabilityService(),
            ),
            appObservabilityProvider.overrideWithValue(
              _TestObservabilityService(),
            ),
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
          child: const ShadApp(
            home: TabShell(screens: [SizedBox.shrink(), SizedBox.shrink()]),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap same tab multiple times
      await tester.tap(find.byKey(const Key('tab-shell-nav-button-map')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('tab-shell-nav-button-map')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('tab-shell-nav-button-map')));
      await tester.pump();

      // Should have no transitions (already on Map tab)
      expect(
        transitions.where((t) => t['from_screen'] == 'map_root_screen').length,
        0,
      );
    });

    testWidgets(
      'debug nav button appears when debug mode is on and toggles overlay',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              wakeLockRepositoryProvider.overrideWithValue(
                _FakeWakeLockRepository(),
              ),
              wakeLockObservabilityProvider.overrideWithValue(
                _TestObservabilityService(),
              ),
              appObservabilityProvider.overrideWithValue(
                _TestObservabilityService(),
              ),
              navigationScreenTransitionLoggerProvider.overrideWithValue(
                NavigationScreenTransitionLogger(logEvent: (_, __, {data}) {}),
              ),
              debugModeProvider.overrideWith(() => _TrueDebugMode()),
            ],
            child: const ShadApp(
              home: TabShell(screens: [SizedBox.shrink(), SizedBox.shrink()]),
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
      },
    );

    testWidgets('debug unvisited-cell control targets nearest unvisited cell', (
      tester,
    ) async {
      final locationCalls =
          <({double lat, double lng, String? targetCellId, String reason})>[];
      final obs = _TestObservabilityService();

      tester.view.physicalSize = const Size(1000, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            wakeLockRepositoryProvider.overrideWithValue(
              _FakeWakeLockRepository(),
            ),
            wakeLockObservabilityProvider.overrideWithValue(
              _TestObservabilityService(),
            ),
            appObservabilityProvider.overrideWithValue(obs),
            navigationScreenTransitionLoggerProvider.overrideWithValue(
              NavigationScreenTransitionLogger(logEvent: (_, __, {data}) {}),
            ),
            debugModeProvider.overrideWith(() => _TrueDebugMode()),
            mapProvider.overrideWith(() => _ReadyMapNotifier()),
            explorationProvider.overrideWith(() => _ReadyExplorationNotifier()),
            playerMarkerProvider.overrideWith(
              () => _ReadyPlayerMarkerNotifier(),
            ),
            locationProvider.overrideWith(
              () => _TrackingLocationNotifier(locationCalls),
            ),
          ],
          child: const ShadApp(
            home: TabShell(screens: [SizedBox.expand(), SizedBox.shrink()]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('debug_nav_button')));
      await tester.pump();
      await tester.tapAt(const Offset(970, 598));
      await tester.pump();

      expect(locationCalls, hasLength(1));
      expect(locationCalls.single.targetCellId, 'target');
      expect(locationCalls.single.reason, 'nearest_unvisited_cell');
      expect(
        obs.events.map((event) => event.event),
        contains('map.debug_unvisited_move_requested'),
      );
    });

    testWidgets('debug nav button is absent when debug mode is off', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            wakeLockRepositoryProvider.overrideWithValue(
              _FakeWakeLockRepository(),
            ),
            wakeLockObservabilityProvider.overrideWithValue(
              _TestObservabilityService(),
            ),
            appObservabilityProvider.overrideWithValue(
              _TestObservabilityService(),
            ),
            navigationScreenTransitionLoggerProvider.overrideWithValue(
              NavigationScreenTransitionLogger(logEvent: (_, __, {data}) {}),
            ),
            debugModeProvider.overrideWith(() => _FalseDebugMode()),
          ],
          child: const ShadApp(
            home: TabShell(screens: [SizedBox.shrink(), SizedBox.shrink()]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('debug_nav_button')), findsNothing);
      expect(find.byType(DebugGestureOverlay), findsNothing);
    });

    testWidgets('desktop builds expose Settings access', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            wakeLockRepositoryProvider.overrideWithValue(
              _FakeWakeLockRepository(),
            ),
            wakeLockObservabilityProvider.overrideWithValue(
              _TestObservabilityService(),
            ),
            appObservabilityProvider.overrideWithValue(
              _TestObservabilityService(),
            ),
            navigationScreenTransitionLoggerProvider.overrideWithValue(
              NavigationScreenTransitionLogger(logEvent: (_, __, {data}) {}),
            ),
            debugModeProvider.overrideWith(() => _FalseDebugMode()),
            desktopControlsAvailableProvider.overrideWithValue(true),
          ],
          child: const ShadApp(
            home: TabShell(screens: [SizedBox.shrink(), SizedBox.shrink()]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('desktop_settings_button')), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const Key('desktop_settings_button')),
            )
            .tooltip,
        'Settings',
      );
    });

    testWidgets('releases wake lock when app is paused', (tester) async {
      final wakeLockCalls = <String>[];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            wakeLockRepositoryProvider.overrideWithValue(
              _TrackingWakeLockRepository(wakeLockCalls),
            ),
            wakeLockObservabilityProvider.overrideWithValue(
              _TestObservabilityService(),
            ),
            appObservabilityProvider.overrideWithValue(
              _TestObservabilityService(),
            ),
            navigationScreenTransitionLoggerProvider.overrideWithValue(
              NavigationScreenTransitionLogger(logEvent: (_, __, {data}) {}),
            ),
            debugModeProvider.overrideWith(() => _FalseDebugMode()),
          ],
          child: const ShadApp(
            home: TabShell(screens: [SizedBox.shrink(), SizedBox.shrink()]),
          ),
        ),
      );
      await tester.pumpAndSettle();
      wakeLockCalls.clear(); // ignore the initial acquire on init

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      expect(wakeLockCalls, contains('release'));
    });

    testWidgets('re-acquires wake lock when app resumes on map tab', (
      tester,
    ) async {
      final wakeLockCalls = <String>[];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            wakeLockRepositoryProvider.overrideWithValue(
              _TrackingWakeLockRepository(wakeLockCalls),
            ),
            wakeLockObservabilityProvider.overrideWithValue(
              _TestObservabilityService(),
            ),
            appObservabilityProvider.overrideWithValue(
              _TestObservabilityService(),
            ),
            navigationScreenTransitionLoggerProvider.overrideWithValue(
              NavigationScreenTransitionLogger(logEvent: (_, __, {data}) {}),
            ),
            debugModeProvider.overrideWith(() => _FalseDebugMode()),
          ],
          child: const ShadApp(
            home: TabShell(screens: [SizedBox.shrink(), SizedBox.shrink()]),
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
      final source = File(
        'lib/ui/product_surfaces/app/tab_shell.dart',
      ).readAsStringSync();
      expect(source, contains('_packPageController'));
      expect(source, contains('PackScreen('));
      expect(source, contains('pageController:'));
      expect(source, contains('onEdgeSwipe:'));
      expect(source, contains("'edge_swipe_to_pack'"));
      expect(source, isNot(contains("actionType: 'edge_swipe_to_player'")));
    });

    test('source: TabShell completes Pack rewards without nav overlays', () {
      final source = File(
        'lib/ui/product_surfaces/app/tab_shell.dart',
      ).readAsStringSync();
      expect(source, contains('addPostFrameCallback'));
      expect(source, contains('completeRewardFlight'));
      expect(source, isNot(contains('_PackRewardImpactOverlay')));
      expect(source, isNot(contains("Key('pack-reward-impact')")));
      expect(source, isNot(contains('_PackRewardFlightOverlay')));
    });

    test('source: Pack left-edge overscroll returns to Map', () {
      final source = File(
        'lib/ui/product_surfaces/app/tab_shell.dart',
      ).readAsStringSync();
      final leftCase = source.substring(
        source.indexOf('case EdgeSwipeDirection.left:'),
        source.indexOf('case EdgeSwipeDirection.right:'),
      );

      expect(leftCase, contains('_onTabSelected(_mapTabIndex)'));
    });

    test('source: Pack right-edge overscroll remains Pack-owned', () {
      final source = File(
        'lib/ui/product_surfaces/app/tab_shell.dart',
      ).readAsStringSync();
      final rightCaseStart = source.indexOf('case EdgeSwipeDirection.right:');
      final rightCase = source.substring(
        rightCaseStart,
        source.indexOf('\n  @override', rightCaseStart),
      );

      expect(rightCase, isNot(contains('_onTabSelected(')));
      expect(rightCase, isNot(contains('_townTabIndex')));
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
            wakeLockRepositoryProvider.overrideWithValue(
              _FakeWakeLockRepository(),
            ),
            wakeLockObservabilityProvider.overrideWithValue(
              _TestObservabilityService(),
            ),
            appObservabilityProvider.overrideWithValue(
              _TestObservabilityService(),
            ),
            navigationScreenTransitionLoggerProvider.overrideWithValue(
              NavigationScreenTransitionLogger(
                logEvent: (event, category, {data}) {
                  if (event == 'navigation.screen_changed') {
                    transitions.add(
                      '${data?['from_screen']}→${data?['to_screen']}',
                    );
                  }
                },
              ),
            ),
            debugModeProvider.overrideWith(() => _FalseDebugMode()),
          ],
          child: ShadApp(
            home: TabShell(
              screens: [
                // Use SizedBox.expand so the gesture surface has a hit area.
                SizedBox.expand(), // map
                SizedBox.expand(), // pack
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('leftward drag in the Map interior remains Map-owned', (
      tester,
    ) async {
      final transitions = <String>[];
      await pumpShellWithFakeScreens(tester, transitions: transitions);

      await tester.flingFrom(
        const Offset(400, 400),
        const Offset(-300, 0),
        800,
      );
      await tester.pumpAndSettle();

      expect(transitions, isEmpty);
    });

    testWidgets(
      'leftward drag inside Map right 24px edge changes Map to Pack',
      (tester) async {
        final transitions = <String>[];
        await pumpShellWithFakeScreens(tester, transitions: transitions);

        await tester.flingFrom(
          const Offset(784, 400),
          const Offset(-300, 0),
          800,
        );
        await tester.pumpAndSettle();

        expect(transitions, ['map_root_screen→pack_screen']);
      },
    );
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
