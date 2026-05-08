import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/features/identification/presentation/screens/pack_screen.dart';
import 'package:earth_nova/features/map/presentation/providers/wake_lock_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/location_provider.dart';
import 'package:earth_nova/features/map/presentation/screens/map_root_screen.dart';
import 'package:earth_nova/features/profile/presentation/screens/settings_screen.dart';
import 'package:earth_nova/shared/observability/navigation/app_navigation_observer.dart';
import 'package:earth_nova/shared/observability/widgets/observable_interaction.dart';
import 'package:earth_nova/shared/observability/widgets/observable_screen.dart';
import 'package:earth_nova/shared/debug/debug_gesture_overlay.dart';
import 'package:earth_nova/shared/debug/debug_mode_provider.dart';
import 'package:earth_nova/shared/extensions/iconography.dart';
import 'package:earth_nova/shared/widgets/stub_screen.dart';

const int _mapTabIndex = 0;
const int _packTabIndex = 1;
const int _sanctuaryTabIndex = 2;
const _tabScreenNames = ['map', 'pack', 'sanctuary', 'settings'];

/// 4-tab bottom navigation. Pack is real, others are stubs.
class TabShell extends ConsumerStatefulWidget {
  const TabShell({
    super.key,
    this.screens,
  });

  final List<Widget>? screens;

  @override
  ConsumerState<TabShell> createState() => _TabShellState();
}

class _TabShellState extends ConsumerState<TabShell>
    with WidgetsBindingObserver {
  int _currentIndex = _mapTabIndex;
  bool _debugOverlayVisible = false;

  /// PageController owned by TabShell and injected into PackScreen so that
  /// cross-tab edge swipes can be detected and handled here.
  late final PageController _packPageController;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _packPageController = PageController();
    _screens = widget.screens ??
        [
          const MapRootScreen(),
          PackScreen(
            pageController: _packPageController,
            onEdgeSwipe: _onPackEdgeSwipe,
          ),
          const StubScreen(label: AppIcons.sanctuary),
          const SettingsScreen(),
        ];
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
        // Swiped right past page 0 → go to Map (tab to the left of Pack).
        _onTabSelected(_mapTabIndex);
      case EdgeSwipeDirection.right:
        // Swiped left past last page → go to Sanctuary (tab to the right).
        _onTabSelected(_sanctuaryTabIndex);
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

  void _onTabSelected(int index) {
    if (index == _currentIndex) return;

    final previousIndex = _currentIndex;
    if (index == _mapTabIndex) {
      ref.read(wakeLockProvider.notifier).acquire();
    } else if (_currentIndex == _mapTabIndex) {
      ref.read(wakeLockProvider.notifier).release();
    }
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

    return ObservableScreen(
      screenName: 'tab_shell',
      observability: obs,
      builder: (_) => Scaffold(
        body: Stack(
          children: [
            // Wrap in GestureDetector to catch horizontal swipes on the map
            // tab. Only the map tab triggers a cross-tab swipe (rightward →
            // Pack). Pack's own PageView handles its own edge overscroll via
            // onEdgeSwipe; other tabs have no swipe gesture.
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragEnd: _currentIndex == _mapTabIndex
                  ? (details) {
                      if (details.primaryVelocity != null &&
                          details.primaryVelocity! < 0) {
                        _onTabSelected(_packTabIndex);
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
                onResumeGps: _onDebugResumeGps,
              ),
          ],
        ),
        bottomNavigationBar: Stack(
          children: [
            NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected:
                  ObservableInteraction.wrapValueChanged<int>(
                logger: logger,
                screenName: 'tab_shell',
                widgetName: 'bottom_navigation_bar',
                actionType: 'tab_selected',
                payloadBuilder: (tabIndex) => {
                  'tab_index': tabIndex,
                },
                callback: _onTabSelected,
              ),
              destinations: const [
                NavigationDestination(
                    icon: Icon(Icons.map_outlined), label: 'Map'),
                NavigationDestination(
                    icon: Icon(Icons.backpack), label: 'Pack'),
                NavigationDestination(
                    icon: Icon(Icons.nature), label: 'Sanctuary'),
                NavigationDestination(
                    icon: Icon(Icons.settings), label: 'Settings'),
              ],
            ),
            if (debugMode)
              Positioned(
                right: 8,
                bottom: 8,
                child: IconButton(
                  key: const Key('debug_nav_button'),
                  icon: Icon(
                    Icons.bug_report,
                    size: 20,
                    color: _debugOverlayVisible
                        ? const Color(0xFF006D77)
                        : const Color(0xFFADB5BD),
                  ),
                  onPressed: () => setState(
                      () => _debugOverlayVisible = !_debugOverlayVisible),
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
