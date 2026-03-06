import 'package:flutter/material.dart' hide Durations;
import 'package:fog_of_world/core/models/iucn_status.dart';
import 'package:fog_of_world/features/pack/providers/pack_provider.dart';
import 'package:fog_of_world/shared/earth_nova_theme.dart';

/// Horizontal scrolling filter bar for the collection pack.
///
/// Renders three groups of [FilterChip]s:
/// - Collection status: All / Collected / Undiscovered
/// - Habitat: All / Forest / Plains / …
/// - Rarity: All / LC / NT / VU / EN / CR / EX
///
/// Each group is separated by a subtle [VerticalDivider].
class PackFilterBar extends StatelessWidget {
  final CollectionFilter collectionFilter;
  final HabitatFilter habitatFilter;
  final RarityFilter rarityFilter;

  final ValueChanged<CollectionFilter> onCollectionFilterChanged;
  final ValueChanged<HabitatFilter> onHabitatFilterChanged;
  final ValueChanged<RarityFilter> onRarityFilterChanged;

  const PackFilterBar({
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
        color: Theme.of(context).colorScheme.surfaceContainer,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
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

  /// Returns a rarity chip color from [EarthNovaTheme] (matches badge palette).
  Color? _rarityChipColor(RarityFilter filter) => switch (filter) {
    RarityFilter.all => null,
    RarityFilter.leastConcern => EarthNovaTheme.rarityColor(IucnStatus.leastConcern),
    RarityFilter.nearThreatened => EarthNovaTheme.rarityColor(IucnStatus.nearThreatened),
    RarityFilter.vulnerable => EarthNovaTheme.rarityColor(IucnStatus.vulnerable),
    RarityFilter.endangered => EarthNovaTheme.rarityColor(IucnStatus.endangered),
    RarityFilter.criticallyEndangered => EarthNovaTheme.rarityColor(IucnStatus.criticallyEndangered),
    RarityFilter.extinct => EarthNovaTheme.rarityColor(IucnStatus.extinct),
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
    final activeColor = selectedColor ?? Theme.of(context).colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected
                ? (selectedColor == EarthNovaTheme.rarityColor(IucnStatus.nearThreatened)
                    ? Theme.of(context).colorScheme.onSurface
                    : Colors.white)
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        selected: selected,
        onSelected: onSelected,
        showCheckmark: false,
        selectedColor: activeColor,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
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
        color: Theme.of(context).colorScheme.outlineVariant,
        indent: 4,
        endIndent: 4,
      ),
    );
  }
}
