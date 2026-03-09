import 'package:flutter/material.dart' hide Durations;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/core/models/item_category.dart';
import 'package:earth_nova/features/auth/providers/auth_provider.dart';
import 'package:earth_nova/features/auth/providers/upgrade_prompt_provider.dart';
import 'package:earth_nova/features/auth/screens/settings_screen.dart';

import 'package:earth_nova/features/auth/widgets/save_progress_banner.dart';
import 'package:earth_nova/features/auth/widgets/upgrade_bottom_sheet.dart';
import 'package:earth_nova/features/pack/providers/pack_provider.dart';
import 'package:earth_nova/features/pack/widgets/category_stub_tab.dart';
import 'package:earth_nova/features/pack/widgets/character_tab.dart';
import 'package:earth_nova/features/pack/widgets/fauna_grid_tab.dart';
import 'package:earth_nova/shared/design_tokens.dart';
import 'package:earth_nova/shared/widgets/identicon_avatar.dart';

/// Main Pack screen — a scrollable 8-tab inventory viewer.
///
/// Tabs mirror [PackTab] enum order:
///   0 Character | 1 Fauna | 2–7 category stubs (flora, minerals, …, orbs)
///
/// Tab content is lazy-loaded via [TabBarView]. The [packProvider] is synced
/// on every tab change so other features can observe the active tab.
class PackScreen extends ConsumerStatefulWidget {
  const PackScreen({super.key});

  @override
  ConsumerState<PackScreen> createState() => _PackScreenState();
}

class _PackScreenState extends ConsumerState<PackScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: PackTab.values.length,
      vsync: this,
    );
    _tabController.addListener(_onTabChanged);

    // Show upgrade bottom sheet once when the threshold is crossed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.listenManual<UpgradePromptState>(upgradePromptProvider, (_, next) {
        if (next.shouldShow) {
          ref.read(upgradePromptProvider.notifier).markShown();
          UpgradeBottomSheet.show(context);
        }
      });
    });
  }

  void _onTabChanged() {
    // Sync packProvider so other providers know which tab is active.
    ref
        .read(packProvider.notifier)
        .setActiveTab(PackTab.values[_tabController.index]);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildIdenticonAction(BuildContext context) {
    final userId = ref.watch(authProvider).user?.id;
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
          'Pack',
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
          tabs: PackTab.values
              .map(
                (tab) => Tab(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Spacing.xs),
                    child: Text('${tab.emoji} ${tab.displayName}'),
                  ),
                ),
              )
              .toList(),
        ),
      ),
      body: Column(
        children: [
          // Persistent upgrade banner — shown once threshold is crossed.
          SaveProgressBanner(
            onUpgradeTap: () => UpgradeBottomSheet.show(context),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                CharacterTab(), // 0 — character stats & inventory summary
                FaunaGridTab(), // 1 — fauna PC-box grid
                CategoryStubTab(category: ItemCategory.flora), // 2
                CategoryStubTab(category: ItemCategory.mineral), // 3
                CategoryStubTab(category: ItemCategory.fossil), // 4
                CategoryStubTab(category: ItemCategory.artifact), // 5
                CategoryStubTab(category: ItemCategory.food), // 6
                CategoryStubTab(category: ItemCategory.orb), // 7
              ],
            ),
          ),
        ],
      ),
    );
  }
}
