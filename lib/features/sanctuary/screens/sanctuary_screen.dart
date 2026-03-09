import 'package:flutter/material.dart' hide Durations;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/core/models/habitat.dart';
import 'package:earth_nova/features/achievements/screens/achievement_screen.dart';

import 'package:earth_nova/features/auth/providers/auth_provider.dart';
import 'package:earth_nova/features/auth/screens/settings_screen.dart';
import 'package:earth_nova/features/auth/widgets/save_progress_banner.dart';
import 'package:earth_nova/features/auth/widgets/upgrade_bottom_sheet.dart';
import 'package:earth_nova/features/caretaking/providers/caretaking_provider.dart';
import 'package:earth_nova/features/sanctuary/providers/sanctuary_provider.dart';
import 'package:earth_nova/features/sanctuary/widgets/habitat_section.dart';
import 'package:earth_nova/features/sanctuary/widgets/sanctuary_health_indicator.dart';
import 'package:earth_nova/features/sanctuary/widgets/streak_badge.dart';
import 'package:earth_nova/shared/design_tokens.dart';
import 'package:earth_nova/shared/widgets/empty_state_widget.dart';
import 'package:earth_nova/shared/widgets/identicon_avatar.dart';

/// Ambient gallery of collected species grouped by habitat.
///
/// Laid out top-to-bottom:
/// 1. AppBar with "Sanctuary" title.
/// 2. Summary row: [SanctuaryHealthIndicator] + [StreakBadge].
/// 3. Vertically scrollable list of [HabitatSection] widgets, one per habitat
///    that either has collected species or is in the full habitat enum.
class SanctuaryScreen extends ConsumerStatefulWidget {
  const SanctuaryScreen({super.key});

  @override
  ConsumerState<SanctuaryScreen> createState() => _SanctuaryScreenState();
}

class _SanctuaryScreenState extends ConsumerState<SanctuaryScreen> {
  @override
  void initState() {
    super.initState();
    // Record sanctuary visit after the first frame to avoid modifying
    // provider state during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(caretakingProvider.notifier).recordVisit();
      // Upgrade prompt listener lives in PackScreen only (both screens are
      // in an IndexedStack, so duplicate listeners caused double-triggering).
    });
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
    final state = ref.watch(sanctuaryProvider);

    // Build an ordered list of all habitats; show habitats that have at
    // least one collected species first, then remaining habitats appended.
    final populatedHabitats = Habitat.values
        .where((h) =>
            state.speciesByHabitat.containsKey(h) &&
            (state.speciesByHabitat[h]?.isNotEmpty ?? false))
        .toList();
    final emptyHabitats =
        Habitat.values.where((h) => !populatedHabitats.contains(h)).toList();
    final orderedHabitats = [...populatedHabitats, ...emptyHabitats];

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Text(
          'Sanctuary',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(
              Icons.emoji_events,
              color: Theme.of(context).colorScheme.primary,
            ),
            tooltip: 'Achievements',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AchievementScreen(),
                ),
              );
            },
          ),
          _buildIdenticonAction(context),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Summary header: health indicator + streak badge
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(
                  Spacing.lg, Spacing.xs, Spacing.lg, Spacing.xxl),
              padding: const EdgeInsets.all(Spacing.xl),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: Radii.borderXxxl,
                boxShadow: Shadows.medium,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: SanctuaryHealthIndicator(
                      percentage: state.healthPercentage,
                    ),
                  ),
                  Spacing.gapHLg,
                  // Vertical divider
                  Container(
                    width: 1,
                    height: 72,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  Spacing.gapHLg,
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Daily streak',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.outline,
                            letterSpacing: 0.3,
                          ),
                        ),
                        Spacing.gapSm,
                        StreakBadge(streak: state.currentStreak),
                        Spacing.gapMd,
                        Text(
                          '${state.totalCollected} / ${state.totalInPool} species',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Save progress banner — shown when user is anonymous and has
          // crossed the upgrade threshold.
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
              child: SaveProgressBanner(
                onUpgradeTap: () => UpgradeBottomSheet.show(context),
              ),
            ),
          ),

          // Empty state when nothing collected yet — replaces habitat sections.
          if (state.totalCollected == 0)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyStateWidget(
                icon: '🏡',
                title: 'Your sanctuary is empty',
                subtitle:
                    'Discover species to populate it!\nExplore the map to find wildlife.',
              ),
            ),

          // Habitat sections — only shown once at least one species is collected.
          if (state.totalCollected > 0)
            SliverList.separated(
              itemCount: orderedHabitats.length,
              separatorBuilder: (_, __) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Divider(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    height: 32),
              ),
              itemBuilder: (_, index) {
                final habitat = orderedHabitats[index];
                final habitatSpecies =
                    state.speciesByHabitat[habitat] ?? const [];
                return Padding(
                  padding: EdgeInsets.only(
                    top: index == 0 ? 0 : 4,
                    bottom: index == orderedHabitats.length - 1 ? 32 : 4,
                  ),
                  child: HabitatSection(
                    habitat: habitat,
                    species: habitatSpecies,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
