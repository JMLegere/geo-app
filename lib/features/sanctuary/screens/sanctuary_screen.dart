import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fog_of_world/core/models/habitat.dart';
import 'package:fog_of_world/features/caretaking/providers/caretaking_provider.dart';
import 'package:fog_of_world/features/sanctuary/providers/sanctuary_provider.dart';
import 'package:fog_of_world/features/sanctuary/widgets/habitat_section.dart';
import 'package:fog_of_world/features/sanctuary/widgets/sanctuary_health_indicator.dart';
import 'package:fog_of_world/features/sanctuary/widgets/streak_badge.dart';
import 'package:fog_of_world/shared/widgets/empty_state_widget.dart';

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
    });
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
      backgroundColor: const Color(0xFFFAFAF8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAFAF8),
        elevation: 0,
        scrolledUnderElevation: 1,
        title: const Text(
          'Sanctuary',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A2E1B),
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: false,
      ),
      body: CustomScrollView(
        slivers: [
          // Summary header: health indicator + streak badge
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: SanctuaryHealthIndicator(
                      percentage: state.healthPercentage,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Vertical divider
                  Container(
                    width: 1,
                    height: 72,
                    color: const Color(0xFFE5E7EB),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Daily streak',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF9CA3AF),
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        StreakBadge(streak: state.currentStreak),
                        const SizedBox(height: 10),
                        Text(
                          '${state.totalCollected} / ${state.totalInPool} species',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
            separatorBuilder: (_, __) => const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Divider(color: Color(0xFFE5E7EB), height: 32),
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
