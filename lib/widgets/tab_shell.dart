import 'package:flutter/material.dart';
import 'package:earth_nova/screens/pack_screen.dart';
import 'package:earth_nova/screens/settings_screen.dart';
import 'package:earth_nova/screens/stub_screen.dart';
import 'package:earth_nova/shared/iconography.dart';

/// 4-tab bottom navigation. Pack is real, others are stubs.
class TabShell extends StatefulWidget {
  const TabShell({super.key});

  @override
  State<TabShell> createState() => _TabShellState();
}

class _TabShellState extends State<TabShell> {
  int _currentIndex = 1; // Default to Pack

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const StubScreen(label: AppIcons.map),
      const PackScreen(),
      const StubScreen(label: AppIcons.sanctuary),
      const SettingsScreen(),
    ];
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
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
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
