import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/models/habitat.dart';
import 'package:earth_nova/models/item_instance.dart';
import 'package:earth_nova/providers/sanctuary_provider.dart';
import 'package:earth_nova/shared/widgets/rarity_badge.dart';
import 'package:earth_nova/shared/widgets/species_art_image.dart';
import 'package:earth_nova/widgets/item_detail_sheet.dart';

class SanctuaryScreen extends ConsumerWidget {
  const SanctuaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final placed = ref.watch(sanctuaryProvider);

    // Group by first habitat
    final byHabitat = <Habitat, List<ItemInstance>>{};
    for (final item in placed) {
      final h = item.habitats.isNotEmpty ? item.habitats.first : null;
      if (h != null) {
        byHabitat.putIfAbsent(h, () => []).add(item);
      } else {
        // Fallback: put under forest if no habitat
        byHabitat.putIfAbsent(Habitat.forest, () => []).add(item);
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        title: Row(
          children: [
            const Text('Sanctuary'),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${placed.length}',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
      body: placed.isEmpty
          ? const _EmptyState()
          : ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: byHabitat.entries.map((entry) {
                return _HabitatSection(
                  habitat: entry.key,
                  items: entry.value,
                );
              }).toList(),
            ),
    );
  }
}

// ---------------------------------------------------------------------------

class _HabitatSection extends StatelessWidget {
  final Habitat habitat;
  final List<ItemInstance> items;

  const _HabitatSection({required this.habitat, required this.items});

  Color _habitatColor() {
    final hex = habitat.colorHex.replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  String _habitatIcon() => switch (habitat) {
        Habitat.forest => '🌲',
        Habitat.plains => '🌾',
        Habitat.freshwater => '🏞️',
        Habitat.saltwater => '🌊',
        Habitat.swamp => '🐊',
        Habitat.mountain => '⛰️',
        Habitat.desert => '🏜️',
      };

  @override
  Widget build(BuildContext context) {
    final color = _habitatColor();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
          child: Row(
            children: [
              Text(_habitatIcon(), style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                habitat.displayName,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${items.length}',
                style: TextStyle(
                  color: color.withValues(alpha: 0.6),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),

        // Horizontal scroll of cards
        SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (ctx, i) => _SmallCard(
              item: items[i],
              accentColor: color,
              onTap: () => showItemDetailSheet(ctx, items[i]),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _SmallCard extends StatelessWidget {
  final ItemInstance item;
  final Color accentColor;
  final VoidCallback onTap;

  const _SmallCard({
    required this.item,
    required this.accentColor,
    required this.onTap,
  });

  String _emoji(ItemInstance item) => switch (item.category.name) {
        'fauna' => '🦊',
        'flora' => '🌿',
        'mineral' => '💎',
        _ => '❓',
      };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accentColor.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(10)),
              child: SpeciesArtImage(
                artUrl: item.artUrl,
                fallbackEmoji: _emoji(item),
                size: 80,
                borderRadius: BorderRadius.zero,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (item.rarity != null)
                      RarityBadge(
                          status: item.rarity!, size: RarityBadgeSize.small),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.park_outlined, size: 56, color: Colors.white24),
            SizedBox(height: 16),
            Text(
              'Place species from your Pack\nto build your sanctuary',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 14),
            ),
          ],
        ),
      );
}
