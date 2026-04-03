import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/models/affix.dart';
import 'package:earth_nova/models/item_instance.dart';
import 'package:earth_nova/providers/inventory_provider.dart';
import 'package:earth_nova/shared/widgets/rarity_badge.dart';
import 'package:earth_nova/shared/widgets/species_art_image.dart';

/// Shows a full-detail bottom sheet for a given [ItemInstance].
void showItemDetailSheet(BuildContext context, ItemInstance item) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => ItemDetailSheet(item: item),
  );
}

class ItemDetailSheet extends ConsumerWidget {
  final ItemInstance item;

  const ItemDetailSheet({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPlaced = item.status == ItemInstanceStatus.placed;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF161B22),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Art image
            Center(
              child: SpeciesArtImage(
                artUrl: item.artUrl,
                fallbackEmoji: _categoryEmoji(item),
                size: 160,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            const SizedBox(height: 16),

            // Name + rarity
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (item.scientificName != null)
                        Text(
                          item.scientificName!,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),
                if (item.rarity != null)
                  RarityBadge(
                    status: item.rarity!,
                    size: RarityBadgeSize.large,
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // Stats row
            _StatsRow(item: item),
            const SizedBox(height: 16),

            // Location
            if (_hasLocation(item)) ...[
              _SectionLabel('Discovered At'),
              _locationText(item),
              const SizedBox(height: 4),
            ],

            // Discovery date + cell
            _SectionLabel('Discovery'),
            Text(
              _formatDate(item.acquiredAt),
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            if (item.acquiredInCellId != null)
              Text(
                'Cell: ${item.acquiredInCellId}',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            const SizedBox(height: 16),

            // Affixes
            if (item.affixes.isNotEmpty) ...[
              _SectionLabel('Affixes'),
              ...item.affixes
                  .where((a) => a.type != AffixType.intrinsic)
                  .map((a) => _AffixTile(affix: a)),
              const SizedBox(height: 16),
            ],

            // Sanctuary button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isPlaced ? Colors.red.shade900 : const Color(0xFF238636),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  final notifier = ref.read(inventoryProvider.notifier);
                  if (isPlaced) {
                    notifier.updateStatus(item.id, ItemInstanceStatus.active);
                  } else {
                    notifier.updateStatus(item.id, ItemInstanceStatus.placed);
                  }
                  Navigator.of(context).pop();
                },
                child: Text(
                  isPlaced ? 'Remove from Sanctuary' : 'Place in Sanctuary',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _hasLocation(ItemInstance item) =>
      item.locationDistrict != null ||
      item.locationCity != null ||
      item.locationState != null ||
      item.locationCountry != null;

  Widget _locationText(ItemInstance item) {
    final parts = [
      item.locationDistrict,
      item.locationCity,
      item.locationState,
      item.locationCountry,
    ].whereType<String>().toList();
    return Text(
      parts.join(', '),
      style: const TextStyle(color: Colors.white70, fontSize: 13),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  String _categoryEmoji(ItemInstance item) => switch (item.category.name) {
        'fauna' => '🦊',
        'flora' => '🌿',
        'mineral' => '💎',
        'fossil' => '🦴',
        'artifact' => '🏺',
        'food' => '🍎',
        'orb' => '🔮',
        _ => '❓',
      };
}

class _StatsRow extends StatelessWidget {
  final ItemInstance item;

  const _StatsRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final hasStats =
        item.brawn != null || item.wit != null || item.speed != null;

    if (!hasStats) {
      return const Text(
        'Stats not yet enriched',
        style: TextStyle(color: Colors.white38, fontSize: 13),
      );
    }

    return Row(
      children: [
        _StatChip(label: 'Brawn', value: item.brawn, color: Colors.redAccent),
        const SizedBox(width: 8),
        _StatChip(label: 'Wit', value: item.wit, color: Colors.blueAccent),
        const SizedBox(width: 8),
        _StatChip(label: 'Speed', value: item.speed, color: Colors.greenAccent),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int? value;
  final Color color;

  const _StatChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              value?.toString() ?? '-',
              style: TextStyle(
                  color: color, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(label,
                style: const TextStyle(color: Colors.white38, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      );
}

class _AffixTile extends StatelessWidget {
  final Affix affix;

  const _AffixTile({required this.affix});

  @override
  Widget build(BuildContext context) {
    final typeLabel = affix.type == AffixType.prefix ? 'PREFIX' : 'SUFFIX';
    final color = affix.type == AffixType.prefix
        ? Colors.amberAccent
        : Colors.purpleAccent;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              typeLabel,
              style: TextStyle(
                  color: color, fontSize: 9, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            affix.id,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
