import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/features/identification/presentation/screens/pack_screen.dart';
import 'package:earth_nova/features/map/presentation/providers/wake_lock_provider.dart';
import 'package:earth_nova/features/map/presentation/screens/map_screen.dart';
import 'package:earth_nova/features/profile/presentation/screens/settings_screen.dart';
import 'package:earth_nova/shared/extensions/iconography.dart';
import 'package:earth_nova/shared/widgets/stub_screen.dart';

const int _mapTabIndex = 0;

/// 4-tab bottom navigation. Pack is real, others are stubs.
class TabShell extends ConsumerStatefulWidget {
  const TabShell({super.key});

  @override
  ConsumerState<TabShell> createState() => _TabShellState();
}

class _TabShellState extends ConsumerState<TabShell>
    with WidgetsBindingObserver {
  int _currentIndex = _mapTabIndex;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _screens = [
      const MapScreen(),
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
    if (index == _mapTabIndex) {
      ref.read(wakeLockProvider.notifier).acquire();
    } else if (_currentIndex == _mapTabIndex) {
      ref.read(wakeLockProvider.notifier).release();
    }
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onTabSelected,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.map_outlined), label: 'Map'),
          NavigationDestination(icon: Icon(Icons.backpack), label: 'Pack'),
          NavigationDestination(icon: Icon(Icons.nature), label: 'Sanctuary'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
