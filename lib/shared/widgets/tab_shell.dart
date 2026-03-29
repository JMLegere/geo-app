import 'package:earth_nova/core/services/observability_buffer.dart';
import 'package:earth_nova/shared/mixins/observable_lifecycle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/features/auth/models/auth_state.dart';
import 'package:earth_nova/features/auth/providers/auth_provider.dart';
import 'package:earth_nova/features/auth/screens/settings_screen.dart';
import 'package:earth_nova/features/map/map_screen.dart';
import 'package:earth_nova/features/map/utils/map_visibility.dart';
import 'package:earth_nova/core/state/tab_index_provider.dart';
import 'package:earth_nova/shared/widgets/town_placeholder_screen.dart';
import 'package:earth_nova/features/pack/screens/pack_screen.dart';
import 'package:earth_nova/features/sanctuary/screens/sanctuary_screen.dart';
import 'package:earth_nova/features/sync/providers/queue_processor_provider.dart';
import 'package:earth_nova/features/sync/services/lifecycle_flush.dart';
import 'package:earth_nova/shared/constants.dart';
import 'package:earth_nova/shared/design_tokens.dart';
import 'package:earth_nova/shared/widgets/error_boundary.dart';
import 'package:earth_nova/shared/widgets/identicon_avatar.dart';

/// Root navigation shell with 4-tab bottom bar.
///
/// MapScreen (tab 0) is kept alive via [Offstage] — MapLibre's GPS, fog, and
/// ticker state is expensive to recreate. All other tabs (Sanctuary, Town,
/// Pack) are built on demand and disposed when not selected, eliminating
/// their widget trees and animation controllers while they're invisible.
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

class _TabShellState extends ConsumerState<TabShell>
    with WidgetsBindingObserver, ObservableLifecycle<TabShell> {
  @override
  String get observabilityName => 'TabShell';

  late final MapVisibility _mapVisibility;
  late final LifecycleFlush _lifecycleFlush;

  @override
  void initState() {
    super.initState();
    _mapVisibility = MapVisibility();

    // Mobile lifecycle: flush write queue when app is backgrounded.
    WidgetsBinding.instance.addObserver(this);

    // Web lifecycle: flush write queue on visibilitychange → hidden.
    _lifecycleFlush = LifecycleFlush();
    _lifecycleFlush.onFlush = _flushWriteQueue;
    _lifecycleFlush.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _lifecycleFlush.dispose();
    _mapVisibility.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Flush immediately when the app is paused (mobile) or hidden (desktop).
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

    // Pop pushed routes (Settings, Achievements) when the user signs out so
    // the AnimatedSwitcher-driven LoginScreen becomes fully visible.
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (previous?.status == AuthStatus.authenticated &&
          next.status == AuthStatus.unauthenticated) {
        if (context.mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
    });

    // Listen for tab changes to control MapLibre visibility on web.
    // On native platforms, MapVisibility is a no-op.
    const tabNames = ['Map', 'Home', 'Town', 'Pack'];
    ref.listen<int>(tabIndexProvider, (previous, next) {
      debugPrint('[NAV] tab switch: ${tabNames[previous ?? 0]} → '
          '${tabNames[next]}');
      ObservabilityBuffer.instance?.event('tab_switched', {
        'from_tab': previous ?? 0,
        'to_tab': next,
      });
      if (next == 0) {
        _mapVisibility.revealMapContainer();
      } else if (previous == 0) {
        _mapVisibility.hideMapContainer();
      }
    });

    final authState = ref.watch(authProvider);
    final userId = authState.user?.id;

    return Scaffold(
      body: Stack(
        children: [
          // Single ErrorBoundary wraps the tab content. Per-tab boundaries
          // caused a cascade bug: FlutterError.onError is global, so all
          // boundaries catch the same error simultaneously, blanking every
          // tab. One boundary avoids the cascade while still protecting the
          // bottom nav bar (which lives outside in the Scaffold).
          //
          // MapScreen stays alive via Offstage — MapLibre state (GPS, fog,
          // tickers) is expensive to recreate. The other tabs build on demand
          // and dispose when deselected, eliminating their widget trees and
          // animation controllers while invisible.
          ErrorBoundary(
            onError: (details, reset) => DefaultErrorFallback(
              onRetry: reset,
            ),
            child: Stack(
              children: [
                // MapScreen always mounted; hidden when not on tab 0.
                // Offstage preserves MapLibre state across tab switches.
                Offstage(
                  offstage: currentIndex != 0,
                  child: const MapScreen(),
                ),
                if (currentIndex == 1) const SanctuaryScreen(),
                if (currentIndex == 2) const TownPlaceholderScreen(),
                if (currentIndex == 3) const PackScreen(),
              ],
            ),
          ),
          // ── Player identicon — persistent settings trigger ─────────────
          // Shown on tabs without their own AppBar (Map, Town).
          // Tabs with AppBars include the identicon in their actions instead.
          if (userId != null && (currentIndex == 0 || currentIndex == 2))
            Positioned(
              top: MediaQuery.of(context).padding.top + Spacing.sm,
              right: Spacing.md,
              child: _PlayerIdenticonButton(
                userId: userId,
                onTap: () {
                  debugPrint('[ACTION] open settings');
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SettingsScreen(),
                    ),
                  );
                },
              ),
            ),
          // ── Sync indicator + build version stamp ─────────────────────
          Positioned(
            right: 8,
            bottom: 4,
            child: IgnorePointer(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const _SyncIndicator(),
                  Text(
                    kBuildTimestamp,
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.35),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) {
          debugPrint('[ACTION] tap tab: ${tabNames[index]}');
          ref.read(tabIndexProvider.notifier).setTab(index);
        },
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

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

/// Tappable identicon avatar with subtle backdrop for map-tab legibility.
///
/// Uses a frosted container so the identicon remains visible against bright
/// map tiles and dark AppBar backgrounds alike.
class _PlayerIdenticonButton extends StatelessWidget {
  const _PlayerIdenticonButton({
    required this.userId,
    required this.onTap,
  });

  final String userId;
  final VoidCallback onTap;

  static const double _size = 36;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Semantics(
        label: 'Player profile and settings',
        button: true,
        child: Container(
          width: _size,
          height: _size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.surfaceContainer.withValues(alpha: 0.85),
            border: Border.all(
              color: colors.outline.withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: Shadows.soft,
          ),
          child: IdenticonAvatar(seed: userId, size: _size),
        ),
      ),
    );
  }
}

/// Animated sync icon that appears when the write queue is flushing.
///
/// Watches [QueueProcessor.isFlushing] via a polling timer (500ms).
/// Shows a spinning sync arrow that fades in/out with the flush state.
class _SyncIndicator extends ConsumerStatefulWidget {
  const _SyncIndicator();

  @override
  ConsumerState<_SyncIndicator> createState() => _SyncIndicatorState();
}

class _SyncIndicatorState extends ConsumerState<_SyncIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spinController;
  bool _isFlushing = false;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Check flush state on every rebuild (triggered by parent's ref.watch
    // on providers that change during gameplay). This is lightweight — just
    // a bool getter, no stream subscription or polling needed.
    final processor = ref.watch(queueProcessorProvider);
    final flushing = processor.isFlushing;

    if (flushing != _isFlushing) {
      _isFlushing = flushing;
      if (flushing) {
        _spinController.repeat();
      } else {
        _spinController.stop();
      }
    }

    return AnimatedOpacity(
      opacity: _isFlushing ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: RotationTransition(
          turns: _spinController,
          child: Icon(
            Icons.sync,
            size: 12,
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
          ),
        ),
      ),
    );
  }
}
