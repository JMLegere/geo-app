import 'package:flutter/material.dart';
import 'package:fog_of_world/features/journal/providers/journal_provider.dart';

/// Horizontal scrolling filter bar for the collection journal.
///
/// Renders three groups of [FilterChip]s:
/// - Collection status: All / Collected / Undiscovered
/// - Habitat: All / Forest / Plains / …
/// - Rarity: All / LC / NT / VU / EN / CR / EX
///
/// Each group is separated by a subtle [VerticalDivider].
class JournalFilterBar extends StatelessWidget {
  final CollectionFilter collectionFilter;
  final HabitatFilter habitatFilter;
  final RarityFilter rarityFilter;

  final ValueChanged<CollectionFilter> onCollectionFilterChanged;
  final ValueChanged<HabitatFilter> onHabitatFilterChanged;
  final ValueChanged<RarityFilter> onRarityFilterChanged;

  const JournalFilterBar({
    super.key,
    required this.collectionFilter,
    required this.habitatFilter,
    required this.rarityFilter,
    required this.onCollectionFilterChanged,
    required this.onHabitatFilterChanged,
    required this.onRarityFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Colors.black.withValues(alpha: 0.06),
            width: 0.5,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
          // --- Collection status group ---
          for (final filter in CollectionFilter.values)
            _FilterChip(
              label: filter.displayName,
              selected: collectionFilter == filter,
              onSelected: (_) => onCollectionFilterChanged(filter),
            ),

          _Separator(),

          // --- Habitat group ---
          for (final filter in HabitatFilter.values)
            _FilterChip(
              label: filter.displayName,
              selected: habitatFilter == filter,
              onSelected: (_) => onHabitatFilterChanged(filter),
            ),

          _Separator(),

          // --- Rarity group ---
          for (final filter in RarityFilter.values)
            _FilterChip(
              label: filter.displayName,
              selected: rarityFilter == filter,
              onSelected: (_) => onRarityFilterChanged(filter),
              selectedColor: _rarityChipColor(filter),
            ),
        ],
        ),
      ),
    );
  }

  /// Returns a muted chip color for rarity filters (matching badge palette).
  Color? _rarityChipColor(RarityFilter filter) => switch (filter) {
        RarityFilter.all => null,
        RarityFilter.leastConcern => const Color(0xFF4CAF50),
        RarityFilter.nearThreatened => const Color(0xFFFFEB3B),
        RarityFilter.vulnerable => const Color(0xFFFF9800),
        RarityFilter.endangered => const Color(0xFFF44336),
        RarityFilter.criticallyEndangered => const Color(0xFFB71C1C),
        RarityFilter.extinct => const Color(0xFF424242),
      };
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final Color? selectedColor;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.selectedColor,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = selectedColor ?? const Color(0xFF1A1A2E);

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected
                ? (selectedColor == const Color(0xFFFFEB3B)
                    ? const Color(0xFF1A1A2E)
                    : Colors.white)
                : const Color(0xFF374151),
          ),
        ),
        selected: selected,
        onSelected: onSelected,
        showCheckmark: false,
        selectedColor: activeColor,
        backgroundColor: const Color(0xFFF3F4F6),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _Separator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: VerticalDivider(
        width: 1,
        thickness: 1,
        color: Colors.black.withValues(alpha: 0.1),
        indent: 4,
        endIndent: 4,
      ),
    );
  }
}
