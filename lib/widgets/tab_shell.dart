import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/data/observability.dart';
import 'package:earth_nova/models/auth_state.dart';
import 'package:earth_nova/providers/auth_provider.dart';
import 'package:earth_nova/providers/queue_processor_provider.dart';
import 'package:earth_nova/providers/tab_provider.dart';
import 'package:earth_nova/screens/map_screen.dart';
import 'package:earth_nova/screens/pack_screen.dart';
import 'package:earth_nova/screens/sanctuary_screen.dart';
import 'package:earth_nova/screens/settings_screen.dart';

/// Root navigation shell — 3 tabs: Map | Sanctuary | Pack.
///
/// All tabs kept alive via [Offstage] to preserve widget state across tab
/// switches without image/animation churn.
class TabShell extends ConsumerStatefulWidget {
  const TabShell({super.key});

  @override
  ConsumerState<TabShell> createState() => _TabShellState();
}

class _TabShellState extends ConsumerState<TabShell>
    with WidgetsBindingObserver {
  // Tracks which tabs have been built at least once.
  // Map tab (index 0) is always built immediately.
  final Set<int> _builtTabs = {0};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _flushWriteQueue();
    } else if (state == AppLifecycleState.resumed) {
      // Flush write queue when returning to foreground to pick up any
      // queued writes that may have accumulated while backgrounded.
      _flushWriteQueue();
    }
  }

  Widget _buildTab(int index, int currentIndex, Widget child) {
    if (!_builtTabs.contains(index)) {
      return const SizedBox.shrink();
    }
    return Offstage(
      offstage: currentIndex != index,
      child: child,
    );
  }

  Future<void> _flushWriteQueue() async {
    final userId = ref.read(authProvider).user?.id;
    await ref.read(queueProcessorProvider).flushNow(userId: userId);
    await AppObservability.instance.flush();
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(tabIndexProvider);

    // Pop settings/etc when user signs out.
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (previous?.status == AuthStatus.authenticated &&
          next.status == AuthStatus.unauthenticated) {
        if (context.mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
    });

    const tabNames = ['Map', 'Sanctuary', 'Pack'];

    return Scaffold(
      body: Stack(
        children: [
          // Lazy + Offstage: tabs are only built when first selected, then
          // kept alive via Offstage to avoid GPS/animation teardown.
          _buildTab(0, currentIndex, const MapScreen()),
          _buildTab(1, currentIndex, const SanctuaryScreen()),
          _buildTab(2, currentIndex, const PackScreen()),

          // Settings button — top-right on Map tab
          if (currentIndex == 0)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 16,
              child: _SettingsButton(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SettingsScreen(),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) {
          debugPrint('[NAV] tab switch: ${tabNames[index]}');
          setState(() => _builtTabs.add(index));
          ref.read(tabIndexProvider.notifier).setTab(index);
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.explore),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.park),
            label: 'Sanctuary',
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

class _SettingsButton extends StatelessWidget {
  const _SettingsButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.surfaceContainer.withValues(alpha: 0.85),
          border: Border.all(
            color: colors.outline.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Icon(Icons.person, size: 20, color: colors.onSurface),
      ),
    );
  }
}
