import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/features/identification/presentation/screens/pack_screen.dart';
import 'package:earth_nova/features/living_world/presentation/screens/town_screen.dart';
import 'package:earth_nova/features/map/presentation/providers/wake_lock_provider.dart';
import 'package:earth_nova/features/map/presentation/debug/debug_unvisited_cell_target.dart';
import 'package:earth_nova/features/map/presentation/providers/location_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/encounter_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/exploration_provider.dart';
import 'package:earth_nova/features/map/presentation/screens/map_root_screen.dart';
import 'package:earth_nova/features/map/presentation/providers/map_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/player_marker_provider.dart';

import 'package:earth_nova/shared/observability/navigation/app_navigation_observer.dart';
import 'package:earth_nova/shared/observability/widgets/observable_interaction.dart';
import 'package:earth_nova/shared/product/player_actions.dart';
import 'package:earth_nova/shared/observability/widgets/observable_screen.dart';
import 'package:earth_nova/shared/debug/debug_gesture_overlay.dart';
import 'package:earth_nova/shared/debug/debug_mode_provider.dart';
import 'package:earth_nova/shared/design.dart';
import 'package:earth_nova/shared/theme/app_theme.dart';
import 'package:earth_nova/shared/widgets/stub_screen.dart';

const int _mapTabIndex = 0;
const int _playerTabIndex = 1;
const int _townTabIndex = 2;
const int _homeTabIndex = 3;
const _tabScreenNames = ['map', 'player', 'town', 'home'];

PlayerActionId? _playerActionIdForTab(int index) => switch (index) {
      _mapTabIndex => PlayerActions.openMap,
      _playerTabIndex => PlayerActions.openPack,
      _townTabIndex => PlayerActions.openTown,
      _homeTabIndex => PlayerActions.openSanctuary,
      _ => null,
    };

/// 4-tab bottom navigation. Player is backed by Pack; Town lists discovered NPC venues; Home is a stub.
class TabShell extends ConsumerStatefulWidget {
  const TabShell({
    super.key,
    this.screens,
  });

  final List<Widget>? screens;

  @override
  ConsumerState<TabShell> createState() => _TabShellState();
}

const double _bottomNavHeight = 76;
const Duration _navMotionDuration = Duration(milliseconds: 280);

class _BottomNavDestination {
  const _BottomNavDestination({
    required this.label,
  });

  final String label;
}

const _bottomNavItems = [
  _BottomNavDestination(
    label: 'Map',
  ),
  _BottomNavDestination(
    label: 'Player',
  ),
  _BottomNavDestination(
    label: 'Town',
  ),
  _BottomNavDestination(
    label: 'Home',
  ),
];

class _EarthNovaBottomNav extends StatelessWidget {
  const _EarthNovaBottomNav({
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        border: Border(
          top: BorderSide(color: AppTheme.outline.withValues(alpha: 0.44)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.30),
            blurRadius: 22,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: _bottomNavHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final tabWidth = constraints.maxWidth / _bottomNavItems.length;
              final indicatorWidth = math.min(
                48.0,
                math.max(30.0, tabWidth * 0.34),
              );
              final indicatorLeft = (tabWidth * selectedIndex) +
                  ((tabWidth - indicatorWidth) / 2);

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedPositioned(
                    key: const Key('tab-shell-nav-indicator-position'),
                    duration: _navMotionDuration,
                    curve: Curves.easeOutCubic,
                    left: indicatorLeft,
                    top: 64,
                    width: indicatorWidth,
                    height: 3,
                    child: DecoratedBox(
                      key: const Key('tab-shell-nav-indicator'),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: AppTheme.tertiary.withValues(alpha: 0.92),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.tertiary.withValues(alpha: 0.32),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var index = 0;
                          index < _bottomNavItems.length;
                          index++)
                        Expanded(
                          child: _EarthNovaNavItem(
                            item: _bottomNavItems[index],
                            selected: index == selectedIndex,
                            onTap: () => onDestinationSelected(index),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _EarthNovaNavItem extends StatelessWidget {
  const _EarthNovaNavItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _BottomNavDestination item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppTheme.tertiary : AppTheme.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: InkWell(
        key: Key('tab-shell-nav-item-${item.label.toLowerCase()}'),
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          style: TextStyle(
            color: foreground,
            fontSize: 11,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            height: 1,
            letterSpacing: selected ? 0.15 : 0,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabShellState extends ConsumerState<TabShell>
    with WidgetsBindingObserver {
  int _currentIndex = _mapTabIndex;
  bool _debugOverlayVisible = false;

  /// PageController owned by TabShell and injected into PackScreen so that
  /// cross-tab edge swipes can be detected and handled here.
  late final PageController _packPageController;

  late final List<Widget Function()> _screenFactories;
  late final List<Widget> _screens;
  String? _autoCompletingRewardKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _packPageController = PageController();
    _screenFactories = widget.screens != null
        ? widget.screens!.map((screen) => () => screen).toList(growable: false)
        : [
            () => const MapRootScreen(),
            () => PackScreen(
                  pageController: _packPageController,
                  onEdgeSwipe: _onPackEdgeSwipe,
                ),
            () => const TownScreen(),
            () => const StubScreen(label: 'Home'),
          ];
    _screens = List<Widget>.filled(
      _screenFactories.length,
      const SizedBox.shrink(),
      growable: false,
    );
    _materializeScreen(_mapTabIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(wakeLockProvider.notifier).acquire();
    });
  }

  @override
  void dispose() {
    _packPageController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Called by [PackScreen] when the user overscrolls past a category edge.
  void _onPackEdgeSwipe(EdgeSwipeDirection direction) {
    switch (direction) {
      case EdgeSwipeDirection.left:
        // Swiped right past page 0 → go to Map (tab to the left of Player).
        _onTabSelected(_mapTabIndex);
      case EdgeSwipeDirection.right:
        // Swiped left past last page → go to Town (tab to the right).
        _onTabSelected(_townTabIndex);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      ref.read(wakeLockProvider.notifier).release();
    } else if (state == AppLifecycleState.resumed &&
        _currentIndex == _mapTabIndex) {
      ref.read(wakeLockProvider.notifier).acquire();
    }
  }

  void _materializeScreen(int index) {
    if (index < 0 || index >= _screens.length) return;
    if (_screens[index] is! SizedBox) return;
    _screens[index] = _screenFactories[index]();
  }

  void _onTabSelected(int index) {
    if (index == _currentIndex) return;

    final previousIndex = _currentIndex;
    if (index == _mapTabIndex) {
      ref.read(wakeLockProvider.notifier).acquire();
    } else if (_currentIndex == _mapTabIndex) {
      ref.read(wakeLockProvider.notifier).release();
    }
    _materializeScreen(index);
    ref.read(navigationScreenTransitionLoggerProvider).logScreenChanged(
          source: 'tab_shell',
          fromScreen: _tabScreenNames[previousIndex],
          toScreen: _tabScreenNames[index],
        );
    setState(() => _currentIndex = index);
  }

  void _onDebugMovePlayer(DebugPlayerMoveDirection direction) {
    final mappedDirection = switch (direction) {
      DebugPlayerMoveDirection.north => DebugLocationMoveDirection.north,
      DebugPlayerMoveDirection.south => DebugLocationMoveDirection.south,
      DebugPlayerMoveDirection.west => DebugLocationMoveDirection.west,
      DebugPlayerMoveDirection.east => DebugLocationMoveDirection.east,
    };
    ref.read(locationProvider.notifier).moveDebugLocation(mappedDirection);
  }

  void _onDebugMovePlayerToUnvisited() {
    final readyMapState = _debugReadyMapState();
    if (readyMapState == null) {
      _logDebugUnvisitedMoveUnavailable('map_not_ready');
      return;
    }

    final markerState = ref.read(playerMarkerProvider);
    final currentPosition = markerState.lat != 0.0 || markerState.lng != 0.0
        ? (lat: markerState.lat, lng: markerState.lng)
        : (lat: readyMapState.location.lat, lng: readyMapState.location.lng);
    final explorationState = ref.read(explorationProvider);
    final target = selectDebugUnvisitedCellTarget(
      cells: readyMapState.cells,
      backendVisitedCellIds: readyMapState.visitedCellIds,
      sessionVisitedCellIds: explorationState.visitedCellIds,
      currentCellId: explorationState.currentCellId,
      currentPosition: currentPosition,
    );

    if (target == null) {
      _logDebugUnvisitedMoveUnavailable(
        'no_unvisited_target',
        data: {
          'backend_visited_count': readyMapState.visitedCellIds.length,
          'session_visited_count': explorationState.visitedCellIds.length,
          'loaded_cell_count': readyMapState.cells.length,
        },
      );
      return;
    }

    ref.read(appObservabilityProvider).log(
      'map.debug_unvisited_move_requested',
      'map',
      data: {
        'source': 'debug_controls',
        'target_cell_id': target.cellId,
        'lat': target.coord.lat,
        'lng': target.coord.lng,
      },
    );
    ref.read(locationProvider.notifier).moveDebugLocationTo(
          lat: target.coord.lat,
          lng: target.coord.lng,
          targetCellId: target.cellId,
          reason: 'nearest_unvisited_cell',
        );
  }

  MapStateReady? _debugReadyMapState() {
    return switch (ref.read(mapProvider)) {
      MapStateReady ready => ready,
      MapStateRefreshing(previous: final previous) => previous,
      _ => null,
    };
  }

  void _logDebugUnvisitedMoveUnavailable(
    String reason, {
    Map<String, dynamic> data = const {},
  }) {
    ref.read(appObservabilityProvider).log(
      'map.debug_unvisited_move_unavailable',
      'map',
      data: {
        'source': 'debug_controls',
        'reason': reason,
        ...data,
      },
    );
  }

  void _onDebugResumeGps() {
    ref.read(locationProvider.notifier).resumeGps();
  }

  @override
  Widget build(BuildContext context) {
    final obs = ref.watch(appObservabilityProvider);

    void logger({
      required String event,
      required String category,
      Map<String, dynamic>? data,
    }) {
      ref.read(wakeLockProvider.notifier).obs.log(event, category, data: data);
    }

    final debugMode = ref.watch(debugModeProvider);
    final flyingReward = ref.watch(
      encounterProvider.select((state) => state.flyingReward),
    );
    if (flyingReward == null) {
      _autoCompletingRewardKey = null;
    } else {
      final rewardKey = '${flyingReward.speciesId}:${flyingReward.cellId}';
      if (_autoCompletingRewardKey != rewardKey) {
        _autoCompletingRewardKey = rewardKey;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final activeReward = ref.read(encounterProvider).flyingReward;
          final activeRewardKey = activeReward == null
              ? null
              : '${activeReward.speciesId}:${activeReward.cellId}';
          if (activeRewardKey == rewardKey) {
            ref.read(encounterProvider.notifier).completeRewardFlight();
          }
        });
      }
    }

    return ObservableScreen(
      screenName: 'tab_shell',
      observability: obs,
      builder: (_) => Scaffold(
        body: Stack(
          children: [
            // Wrap in GestureDetector to catch horizontal swipes on the map
            // tab. Only the map tab triggers a cross-tab swipe (rightward →
            // Player). Player's own PageView handles its own edge overscroll
            // via onEdgeSwipe; other tabs have no swipe gesture.
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragEnd: _currentIndex == _mapTabIndex
                  ? (details) {
                      if (details.primaryVelocity != null &&
                          details.primaryVelocity! < 0) {
                        ObservableInteraction.log(
                          logger: logger,
                          screenName: 'tab_shell',
                          widgetName: 'map_edge_swipe',
                          actionType: 'edge_swipe_to_player',
                          playerActionId: PlayerActions.openPack,
                          payload: const {
                            'from_tab_index': _mapTabIndex,
                            'to_tab_index': _playerTabIndex,
                          },
                        );
                        _onTabSelected(_playerTabIndex);
                      }
                    }
                  : null,
              child: IndexedStack(
                index: _currentIndex,
                children: _screens,
              ),
            ),
            if (debugMode && _debugOverlayVisible)
              DebugGestureOverlay(
                onMovePlayer: _onDebugMovePlayer,
                onMovePlayerToUnvisited: _onDebugMovePlayerToUnvisited,
                onResumeGps: _onDebugResumeGps,
              ),
          ],
        ),
        bottomNavigationBar: Stack(
          clipBehavior: Clip.none,
          children: [
            _EarthNovaBottomNav(
              selectedIndex: _currentIndex,
              onDestinationSelected:
                  ObservableInteraction.wrapValueChanged<int>(
                logger: logger,
                screenName: 'tab_shell',
                widgetName: 'bottom_navigation_bar',
                actionType: 'tab_selected',
                playerActionIdBuilder: _playerActionIdForTab,
                payloadBuilder: (tabIndex) => {
                  'tab_index': tabIndex,
                },
                callback: _onTabSelected,
              ),
            ),
            if (debugMode)
              Positioned(
                right: 8,
                bottom: 8,
                child: IconButton(
                  key: const Key('debug_nav_button'),
                  icon: EarthIcon(
                    glyph: EarthGlyph.debug,
                    size: 20,
                    tone: _debugOverlayVisible
                        ? EarthIconTone.primary
                        : EarthIconTone.neutral,
                  ),
                  onPressed: ObservableInteraction.wrapVoidCallback(
                    logger: logger,
                    screenName: 'tab_shell',
                    widgetName: 'debug_nav_button',
                    actionType: 'toggle_debug_overlay',
                    telemetryOnlyReason:
                        'Debug overlay toggle is developer-only test chrome.',
                    callback: () => setState(
                        () => _debugOverlayVisible = !_debugOverlayVisible),
                  ),
                  tooltip: 'Debug overlay',
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
