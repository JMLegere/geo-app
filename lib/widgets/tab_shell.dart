import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    }
  }

  Future<void> _flushWriteQueue() async {
    final userId = ref.read(authProvider).user?.id;
    await ref.read(queueProcessorProvider).flushNow(userId: userId);
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
          // Offstage keeps all tab trees alive — prevents GPS/animation teardown
          // on Map and avoids image churn on Pack/Sanctuary.
          Offstage(
            offstage: currentIndex != 0,
            child: const MapScreen(),
          ),
          Offstage(
            offstage: currentIndex != 1,
            child: const SanctuaryScreen(),
          ),
          Offstage(
            offstage: currentIndex != 2,
            child: const PackScreen(),
          ),

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
