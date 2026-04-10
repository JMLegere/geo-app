import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/features/identification/presentation/screens/pack_screen.dart';
import 'package:earth_nova/features/map/presentation/providers/wake_lock_provider.dart';
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

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _screens = widget.screens ??
        [
          const MapRootScreen(),
          const PackScreen(),
          const StubScreen(label: AppIcons.sanctuary),
          const SettingsScreen(),
        ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(wakeLockProvider.notifier).acquire();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
            IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
            if (debugMode && _debugOverlayVisible) const DebugGestureOverlay(),
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
