import 'package:earth_nova/shared/mixins/observable_lifecycle.dart';
import 'package:flutter/material.dart' hide Durations;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/features/achievements/widgets/achievement_list_view.dart';
import 'package:earth_nova/features/auth/providers/auth_provider.dart';
import 'package:earth_nova/features/auth/screens/settings_screen.dart';
import 'package:earth_nova/features/caretaking/providers/caretaking_provider.dart';
import 'package:earth_nova/features/sanctuary/providers/sanctuary_provider.dart';
import 'package:earth_nova/features/sanctuary/widgets/sanctuary_stub_tab.dart';
import 'package:earth_nova/features/sanctuary/widgets/zoo_tab.dart';
import 'package:earth_nova/shared/design_tokens.dart';
import 'package:earth_nova/shared/widgets/identicon_avatar.dart';

/// Ambient gallery of collected species grouped by habitat.
///
/// Contains a scrollable [TabBar] with 5 tabs mirroring [SanctuaryTab]:
///   0 Zoo | 1 Feeding | 2 Breeding | 3 Museum | 4 Achievements
///
/// [ZooTab] shows the original sanctuary body (health header + habitat
/// sections). Feeding / Breeding / Museum show "coming soon" stubs.
/// Achievements embeds [AchievementListView].
class SanctuaryScreen extends ConsumerStatefulWidget {
  const SanctuaryScreen({super.key});

  @override
  ConsumerState<SanctuaryScreen> createState() => _SanctuaryScreenState();
}

class _SanctuaryScreenState extends ConsumerState<SanctuaryScreen>
    with SingleTickerProviderStateMixin, ObservableLifecycle<SanctuaryScreen> {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: SanctuaryTab.values.length,
      vsync: this,
    );
    _tabController.addListener(_onTabChanged);

    // Record sanctuary visit after the first frame to avoid modifying
    // provider state during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(caretakingProvider.notifier).recordVisit();
    });
  }

  void _onTabChanged() {
    // Sync sanctuaryProvider so other providers know which tab is active.
    ref
        .read(sanctuaryProvider.notifier)
        .setActiveTab(SanctuaryTab.values[_tabController.index]);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildIdenticonAction(BuildContext context) {
    final userId = ref.watch(authProvider.select((a) => a.user?.id));
    return IconButton(
      icon: IdenticonAvatar(seed: userId ?? 'anonymous', size: 28),
      tooltip: 'Settings',
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const SettingsScreen(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surfaceContainer,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        shadowColor: cs.shadow.withValues(alpha: 0.08),
        title: Text(
          'Sanctuary',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
            letterSpacing: -0.2,
          ),
        ),
        centerTitle: false,
        actions: [
          _buildIdenticonAction(context),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: cs.primary,
          labelColor: cs.primary,
          unselectedLabelColor: cs.onSurfaceVariant,
          labelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          indicatorWeight: 2.5,
          padding: EdgeInsets.zero,
          tabs: SanctuaryTab.values
              .map(
                (tab) => Tab(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Spacing.xs),
                    child: Text('${tab.icon} ${tab.displayName}'),
                  ),
                ),
              )
              .toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          ZooTab(), // 0 — species grouped by habitat
          SanctuaryStubTab(tab: SanctuaryTab.feeding), // 1
          SanctuaryStubTab(tab: SanctuaryTab.breeding), // 2
          SanctuaryStubTab(tab: SanctuaryTab.museum), // 3
          AchievementListView(), // 4 — shared with AchievementScreen
        ],
      ),
    );
  }
}
