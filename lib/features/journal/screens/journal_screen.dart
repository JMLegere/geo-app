import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fog_of_world/features/journal/providers/journal_provider.dart';
import 'package:fog_of_world/features/journal/widgets/journal_filter_bar.dart';
import 'package:fog_of_world/features/journal/widgets/journal_progress_bar.dart';
import 'package:fog_of_world/features/journal/widgets/species_card.dart';
import 'package:fog_of_world/features/journal/widgets/species_detail_sheet.dart';

/// Main collection journal screen.
///
/// Assembles [JournalProgressBar], [JournalFilterBar], and a 2-column
/// [GridView] of [SpeciesCard] widgets. Tapping a card opens
/// [SpeciesDetailSheet] as a modal bottom sheet.
///
/// This is a standalone screen — it does not depend on MapScreen or any
/// map-specific providers.
class JournalScreen extends ConsumerWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(journalProvider);
    final notifier = ref.read(journalProvider.notifier);
    final filtered = state.filteredSpecies;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        title: const Text(
          'Journal',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A2E),
            letterSpacing: -0.2,
          ),
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          // Progress bar
          JournalProgressBar(
            collected: state.collectedCount,
            total: state.totalCount,
          ),

          // Filter bar
          JournalFilterBar(
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
                ? const _EmptyState()
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '🔍',
            style: TextStyle(fontSize: 36),
          ),
          SizedBox(height: 12),
          Text(
            'No species match filters',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Try adjusting your filters',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }
}
