import 'package:flutter/material.dart' hide Durations;
import 'package:fog_of_world/shared/design_tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fog_of_world/features/auth/providers/upgrade_prompt_provider.dart';
import 'package:fog_of_world/features/auth/screens/settings_screen.dart';
import 'package:fog_of_world/features/auth/widgets/save_progress_banner.dart';
import 'package:fog_of_world/features/auth/widgets/upgrade_bottom_sheet.dart';
import 'package:fog_of_world/features/pack/providers/pack_provider.dart';
import 'package:fog_of_world/features/pack/widgets/pack_filter_bar.dart';
import 'package:fog_of_world/features/pack/widgets/pack_progress_bar.dart';
import 'package:fog_of_world/features/pack/widgets/species_card.dart';
import 'package:fog_of_world/features/pack/widgets/species_detail_sheet.dart';
import 'package:fog_of_world/shared/widgets/empty_state_widget.dart';

/// Main collection pack screen.
///
/// Assembles [PackProgressBar], [PackFilterBar], and a 2-column
/// [GridView] of [SpeciesCard] widgets. Tapping a card opens
/// [SpeciesDetailSheet] as a modal bottom sheet.
///
/// This is a standalone screen — it does not depend on MapScreen or any
/// map-specific providers.
class PackScreen extends ConsumerStatefulWidget {
  const PackScreen({super.key});

  @override
  ConsumerState<PackScreen> createState() => _PackScreenState();
}

class _PackScreenState extends ConsumerState<PackScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.listenManual<UpgradePromptState>(upgradePromptProvider, (prev, next) {
        if (next.shouldShow) {
          ref.read(upgradePromptProvider.notifier).markShown();
          UpgradeBottomSheet.show(context);
        }
      });
    });
  }

  Widget _buildEmptyState(PackState state) {
    // Nothing collected yet — show exploration prompt.
    final hasActiveCollectionFilter =
        state.collectionFilter == CollectionFilter.collected;
    final nothingCollected = state.collectedCount == 0;

    if (nothingCollected && !hasActiveCollectionFilter) {
      return const EmptyStateWidget(
        icon: '🔬',
        title: 'No species discovered yet',
        subtitle: 'Start exploring to find wildlife!',
      );
    }

    if (nothingCollected && hasActiveCollectionFilter) {
      return const EmptyStateWidget(
        icon: '🎒',
        title: 'Nothing collected yet',
        subtitle: 'Explore cells on the map to discover and collect species.',
      );
    }

    // Has collections but active filters yield no results.
    return const EmptyStateWidget(
      icon: '🔍',
      title: 'No species match filters',
      subtitle: 'Try adjusting your filters to see more species.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(packProvider);
    final notifier = ref.read(packProvider.notifier);
    final filtered = state.filteredSpecies;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        shadowColor: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.08),
        title: Text(
           'Pack',
           style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
            letterSpacing: -0.2,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(
              Icons.settings,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Save progress banner — shown when user is anonymous and has
          // crossed the upgrade threshold.
          SaveProgressBanner(
            onUpgradeTap: () => UpgradeBottomSheet.show(context),
          ),

           // Progress bar
           PackProgressBar(
             collected: state.collectedCount,
             total: state.totalCount,
           ),

           // Filter bar
           PackFilterBar(
            collectionFilter: state.collectionFilter,
            habitatFilter: state.habitatFilter,
            rarityFilter: state.rarityFilter,
            onCollectionFilterChanged: notifier.setCollectionFilter,
            onHabitatFilterChanged: notifier.setHabitatFilter,
            onRarityFilterChanged: notifier.setRarityFilter,
          ),

          // Grid
          Expanded(
            child: filtered.isEmpty
                ? _buildEmptyState(state)
                : GridView.builder(
                    padding: const EdgeInsets.all(Spacing.lg),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 0.82,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final species = filtered[index];
                      final isCollected = state.collectedIds.contains(species.id);

                      return SpeciesCard(
                        species: species,
                        isCollected: isCollected,
                        onTap: () => showSpeciesDetailSheet(
                          context,
                          species: species,
                          isCollected: isCollected,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
