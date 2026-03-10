import 'package:flutter/material.dart' hide Durations;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/core/models/habitat.dart';
import 'package:earth_nova/features/auth/widgets/save_progress_banner.dart';
import 'package:earth_nova/shared/game_icons.dart';
import 'package:earth_nova/features/auth/widgets/upgrade_bottom_sheet.dart';
import 'package:earth_nova/features/sanctuary/providers/sanctuary_provider.dart';
import 'package:earth_nova/features/sanctuary/widgets/habitat_section.dart';
import 'package:earth_nova/features/sanctuary/widgets/sanctuary_health_indicator.dart';
import 'package:earth_nova/features/sanctuary/widgets/streak_badge.dart';
import 'package:earth_nova/shared/design_tokens.dart';
import 'package:earth_nova/shared/widgets/empty_state_widget.dart';

/// Zoo overview tab — species grouped by habitat with health summary.
///
/// Extracted from the former [SanctuaryScreen] body. Shows:
/// 1. Summary header (health indicator + streak badge).
/// 2. Save-progress banner (anonymous users).
/// 3. Vertically scrollable habitat sections.
class ZooTab extends ConsumerWidget {
  const ZooTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sanctuaryProvider);
    final cs = Theme.of(context).colorScheme;

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

    return CustomScrollView(
      slivers: [
        // Summary header: health indicator + streak badge
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.fromLTRB(
                Spacing.lg, Spacing.xs, Spacing.lg, Spacing.xxl),
            padding: const EdgeInsets.all(Spacing.xl),
            decoration: BoxDecoration(
              color: cs.surfaceContainer,
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
                  color: cs.outlineVariant,
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
                          color: cs.outline,
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
                          color: cs.onSurfaceVariant,
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
              icon: GameIcons.placed,
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
              child: Divider(color: cs.outlineVariant, height: 32),
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
    );
  }
}
