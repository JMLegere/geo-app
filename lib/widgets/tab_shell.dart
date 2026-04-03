import 'package:flutter/material.dart';
import 'package:earth_nova/models/auth_state.dart';
import 'package:earth_nova/screens/loading_screen.dart';
import 'package:earth_nova/screens/login_screen.dart';
import 'package:earth_nova/screens/settings_screen.dart';
import 'package:earth_nova/screens/stub_screen.dart';
import 'package:earth_nova/shared/app_theme.dart';

/// Root app widget — switches between login, loading, and tab shell.
class EarthNovaApp extends StatelessWidget {
  const EarthNovaApp({required this.authState, super.key});
  final AuthState authState;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EarthNova',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: authState.when(
        loading: () => const LoadingScreen(),
        unauthenticated: () => const LoginScreen(),
        authenticated: (_) => const TabShell(),
        error: (_) => const LoginScreen(),
      ),
    );
  }
}

/// 4-tab bottom navigation. Pack is real, others are stubs.
class TabShell extends StatefulWidget {
  const TabShell({super.key});

  @override
  State<TabShell> createState() => _TabShellState();
}

class _TabShellState extends State<TabShell> {
  int _currentIndex = 1; // Default to Pack

  static const _screens = [
    StubScreen(label: '🗺️'), // Map
    LoadingScreen(), // Pack (stub until Slice 2)
    StubScreen(label: '🌿'), // Sanctuary
    SettingsScreen(), // Settings
  ];

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
