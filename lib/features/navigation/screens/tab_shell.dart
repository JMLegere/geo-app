import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/features/map/map_screen.dart';
import 'package:earth_nova/features/map/utils/map_visibility.dart';
import 'package:earth_nova/features/sanctuary/screens/sanctuary_screen.dart';
import 'package:earth_nova/features/navigation/screens/town_placeholder_screen.dart';
import 'package:earth_nova/features/pack/screens/pack_screen.dart';
import 'package:earth_nova/features/navigation/providers/tab_index_provider.dart';
import 'package:earth_nova/shared/constants.dart';

/// Root navigation shell with 4-tab bottom bar.
///
/// Uses [IndexedStack] so all tab children remain mounted — MapScreen's
/// GPS, fog, and ticker state persist across tab switches.
///
/// On web, [MapVisibility] hides/reveals the MapLibre HTML container when
/// switching away from or back to the Map tab (index 0). On native platforms,
/// [MapVisibility] is a no-op.
///
/// Tab layout: Map (0) | Home (1) | Town (2) | Pack (3)
class TabShell extends ConsumerStatefulWidget {
  const TabShell({super.key});

  @override
  ConsumerState<TabShell> createState() => _TabShellState();
}

class _TabShellState extends ConsumerState<TabShell> {
  late final MapVisibility _mapVisibility;

  @override
  void initState() {
    super.initState();
    _mapVisibility = MapVisibility();
  }

  @override
  void dispose() {
    _mapVisibility.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(tabIndexProvider);

    // Listen for tab changes to control MapLibre visibility on web.
    // On native platforms, MapVisibility is a no-op.
    ref.listen<int>(tabIndexProvider, (previous, next) {
      if (next == 0) {
        _mapVisibility.revealMapContainer();
      } else if (previous == 0) {
        _mapVisibility.hideMapContainer();
      }
    });

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: currentIndex,
            children: const [
              MapScreen(),
              SanctuaryScreen(),
              TownPlaceholderScreen(),
              PackScreen(),
            ],
          ),
          // Build version stamp — bottom right, above nav bar.
          Positioned(
            right: 8,
            bottom: 4,
            child: IgnorePointer(
              child: Text(
                'v$kBuildTimestamp',
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.35),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) => ref.read(tabIndexProvider.notifier).setTab(index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.explore),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Town',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.backpack),
            label: 'Pack',
          ),
        ],
      ),
    );
  }
}
