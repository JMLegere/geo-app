import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/features/pack/presentation/screens/pack_screen.dart';
import 'package:earth_nova/features/map/presentation/providers/wake_lock_provider.dart';
import 'package:earth_nova/features/map/presentation/debug/debug_unvisited_cell_target.dart';
import 'package:earth_nova/features/map/presentation/providers/location_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/encounter_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/desktop_controls_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/exploration_provider.dart';
import 'package:earth_nova/features/map/presentation/screens/map_root_screen.dart';
import 'package:earth_nova/features/map/presentation/providers/map_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/player_marker_provider.dart';
import 'package:earth_nova/features/profile/presentation/screens/settings_screen.dart';

import 'package:earth_nova/shared/observability/navigation/app_navigation_observer.dart';
import 'package:earth_nova/shared/observability/widgets/observable_interaction.dart';
import 'package:earth_nova/shared/product/player_actions.dart';
import 'package:earth_nova/shared/product/product_action_surface.dart';
import 'package:earth_nova/shared/observability/widgets/observable_screen.dart';
import 'package:earth_nova/shared/debug/debug_gesture_overlay.dart';
import 'package:earth_nova/shared/debug/debug_mode_provider.dart';
import 'package:earth_nova/shared/design.dart';

const int _mapTabIndex = 0;
const int _packTabIndex = 1;
const _tabScreenNames = ['map', 'pack'];

PlayerActionId? _playerActionIdForTab(int index) => switch (index) {
      _mapTabIndex => PlayerActions.openMap,
      _packTabIndex => PlayerActions.openPack,
      _ => null,
    };

/// 2-tab bottom navigation for Map and Pack.
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
const Duration _navLabelMotionDuration = Duration(milliseconds: 180);

const Color _carbonGray100 = Color(0xFF161616);
const Color _carbonGray70 = Color(0xFF525252);
const Color _carbonGray20 = Color(0xFFE0E0E0);
const Color _carbonWhite = Color(0xFFFFFFFF);
const Color _carbonBlue60 = Color(0xFF0F62FE);
const Color _carbonFocus = Color(0xFFD0E2FF);

const double _mapSwipeEdgeWidth = 24;

class _BottomNavDestination {
  const _BottomNavDestination({
    required this.label,
    required this.actionId,
  });

  final String label;
  final PlayerActionId actionId;
}

const _bottomNavItems = [
  _BottomNavDestination(
    label: 'Map',
    actionId: PlayerActions.openMap,
  ),
  _BottomNavDestination(
    label: 'Pack',
    actionId: PlayerActions.openPack,
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
    final animationDuration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : _navMotionDuration;

    return Material(
      key: const Key('tab-shell-bottom-navigation'),
      color: _carbonWhite,
      elevation: 0,
      shape: const Border(
        top: BorderSide(color: _carbonGray20),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: _bottomNavHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final tabWidth = constraints.maxWidth / _bottomNavItems.length;
              final indicatorWidth = tabWidth / 2;
              final indicatorLeft = (tabWidth * selectedIndex) +
                  ((tabWidth - indicatorWidth) / 2);

              return Stack(
                children: [
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
                  AnimatedPositioned(
                    key: const Key('tab-shell-nav-indicator-position'),
                    duration: animationDuration,
                    curve: Curves.easeOutCubic,
                    left: indicatorLeft,
                    bottom: 0,
                    width: indicatorWidth,
                    height: 2,
                    child: const IgnorePointer(
                      child: ColoredBox(
                        key: Key('tab-shell-nav-indicator'),
                        color: _carbonBlue60,
                      ),
                    ),
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
    final foreground = selected ? _carbonGray100 : _carbonGray70;
    final animationDuration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : _navLabelMotionDuration;

    return ProductActionSurface(
      actionId: item.actionId,
      child: Semantics(
        button: true,
        selected: selected,
        label: item.label,
        child: Material(
          key: Key('tab-shell-nav-surface-${item.label.toLowerCase()}'),
          color: selected ? _carbonGray20 : _carbonWhite,
          // eac-clickable-owner-logs: _EarthNovaBottomNav receives an ObservableInteraction-wrapped callback from TabShell with per-tab product action IDs.
          child: InkWell(
            key: Key('tab-shell-nav-item-${item.label.toLowerCase()}'),
            focusColor: _carbonFocus,
            onTap: onTap,
            child: AnimatedDefaultTextStyle(
              key: Key('tab-shell-nav-label-${item.label.toLowerCase()}'),
              duration: animationDuration,
              curve: Curves.easeOutCubic,
              style: TextStyle(
                color: foreground,
                fontSize: 14,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                height: 1,
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
    assert(widget.screens == null || widget.screens!.length == 2);
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
        // Swiped right past page 0 → go to Map.
        _onTabSelected(_mapTabIndex);
      case EdgeSwipeDirection.right:
        // Pack owns its trailing edge.
        return;
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
    final desktopControlsAvailable =
        ref.watch(desktopControlsAvailableProvider);
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
            IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
            if (_currentIndex == _mapTabIndex)
              Positioned(
                top: 0,
                right: 0,
                bottom: 0,
                width: _mapSwipeEdgeWidth,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragEnd: (details) {
                    if (details.primaryVelocity != null &&
                        details.primaryVelocity! < 0) {
                      ObservableInteraction.log(
                        logger: logger,
                        screenName: 'tab_shell',
                        widgetName: 'map_edge_swipe',
                        actionType: 'edge_swipe_to_pack',
                        playerActionId: PlayerActions.openPack,
                        payload: const {
                          'from_tab_index': _mapTabIndex,
                          'to_tab_index': _packTabIndex,
                        },
                      );
                      _onTabSelected(_packTabIndex);
                    }
                  },
                ),
              ),
            if (desktopControlsAvailable)
              Positioned(
                top: 8,
                right: 8,
                child: SafeArea(
                  child: Material(
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    elevation: 2,
                    shape: const CircleBorder(),
                    child: IconButton(
                      key: const Key('desktop_settings_button'),
                      icon: const EarthIcon(glyph: EarthGlyph.settings),
                      tooltip: 'Settings',
                      onPressed: ObservableInteraction.wrapVoidCallback(
                        logger: logger,
                        screenName: 'tab_shell',
                        widgetName: 'desktop_settings_button',
                        actionType: 'open_settings',
                        telemetryOnlyReason:
                            'Settings navigation is account and input chrome outside the gameplay action catalog.',
                        callback: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            settings: const RouteSettings(name: 'settings'),
                            builder: (_) => const SettingsScreen(),
                          ),
                        ),
                      ),
                    ),
                  ),
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
