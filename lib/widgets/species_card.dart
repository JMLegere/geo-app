import 'package:flutter/material.dart' hide Durations;
import 'package:earth_nova/models/item.dart';
import 'package:earth_nova/models/iucn_status.dart';
import 'package:earth_nova/shared/app_theme.dart';
import 'package:earth_nova/shared/design_tokens.dart';
import 'package:earth_nova/shared/iconography.dart';

/// Full-screen bottom sheet showing species details.
///
/// Displays: art/icon, display name, scientific name, rarity badge,
/// category, taxonomic group, habitats, regions, and acquired date.
///
/// Usage:
/// ```dart
/// showSpeciesCard(context, item);
/// ```
void showSpeciesCard(BuildContext context, Item item) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => SpeciesCard(item: item),
  );
}

/// The species detail card content.
class SpeciesCard extends StatelessWidget {
  const SpeciesCard({super.key, required this.item});
  final Item item;

  @override
  Widget build(BuildContext context) {
    final status = IucnStatus.fromString(item.rarity);
    final group = item.taxonomicGroup;
    final habitatList = item.habitats
        .map(Habitat.fromString)
        .whereType<Habitat>()
        .where((h) => h != Habitat.unknown)
        .toList();
    final regionList = item.continents
        .map(GameRegion.fromString)
        .whereType<GameRegion>()
        .where((r) => r != GameRegion.unknown)
        .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.surfaceContainer,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(Radii.xxxl),
            ),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: Spacing.sm),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.outline,
                    borderRadius: BorderRadius.circular(Radii.pill),
                  ),
                ),
              ),
              const SizedBox(height: Spacing.lg),

              // Art / icon
              Center(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(Radii.xxl),
                    border: Border.all(
                      color: status != null
                          ? status.color.withValues(alpha: status.borderAlpha)
                          : AppTheme.outline.withValues(alpha: 0.3),
                      width: 2,
                    ),
                    boxShadow: status != null && status.glowAlpha > 0
                        ? [
                            BoxShadow(
                              color: status.color
                                  .withValues(alpha: status.glowAlpha),
                              blurRadius: 20,
                              spreadRadius: -4,
                            ),
                          ]
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(Radii.xl),
                    child: _buildArt(),
                  ),
                ),
              ),
              const SizedBox(height: Spacing.lg),

              // Display name
              Text(
                item.displayName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onSurface,
                  letterSpacing: -0.3,
                ),
              ),

              // Scientific name
              if (item.scientificName != null) ...[
                const SizedBox(height: Spacing.xxs),
                Text(
                  item.scientificName!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: AppTheme.onSurfaceVariant.withValues(alpha: 0.8),
                  ),
                ),
              ],
              const SizedBox(height: Spacing.md),

              // Rarity badge row
              if (status != null)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.md,
                      vertical: Spacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: status.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(Radii.pill),
                      border: Border.all(
                        color: status.color.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      '${status.code} · ${status.displayName}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: status.color,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: Spacing.xxl),

              // Info chips
              Wrap(
                spacing: Spacing.sm,
                runSpacing: Spacing.sm,
                alignment: WrapAlignment.center,
                children: [
                  _InfoChip(
                    icon: item.category.emoji,
                    label: item.category.label,
                  ),
                  if (item.taxonomicClass != null &&
                      group != TaxonomicGroup.other)
                    _InfoChip(icon: group.icon, label: group.label),
                ],
              ),

              // Habitats
              if (habitatList.isNotEmpty) ...[
                const SizedBox(height: Spacing.xl),
                _SectionLabel(label: 'HABITAT'),
                const SizedBox(height: Spacing.xs),
                Wrap(
                  spacing: Spacing.sm,
                  runSpacing: Spacing.sm,
                  children: habitatList
                      .map((h) => _InfoChip(icon: h.icon, label: h.label))
                      .toList(),
                ),
              ],

              // Regions
              if (regionList.isNotEmpty) ...[
                const SizedBox(height: Spacing.xl),
                _SectionLabel(label: 'REGION'),
                const SizedBox(height: Spacing.xs),
                Wrap(
                  spacing: Spacing.sm,
                  runSpacing: Spacing.sm,
                  children: regionList
                      .map((r) => _InfoChip(icon: r.icon, label: r.label))
                      .toList(),
                ),
              ],

              // Acquired info
              const SizedBox(height: Spacing.xxl),
              _SectionLabel(label: 'DISCOVERED'),
              const SizedBox(height: Spacing.xs),
              Text(
                _formatDate(item.acquiredAt),
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
              if (item.acquiredInCellId != null) ...[
                const SizedBox(height: Spacing.xxs),
                Text(
                  'Cell ${item.acquiredInCellId}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),
              ],

              const SizedBox(height: Spacing.giant),
            ],
          ),
        );
      },
    );
  }

  Widget _buildArt() {
    if (item.artUrl != null) {
      return Image.network(
        item.artUrl!,
        fit: BoxFit.cover,
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return Center(
            child:
                Text(item.category.emoji, style: const TextStyle(fontSize: 48)),
          );
        },
        errorBuilder: (_, __, ___) => _fallbackIcon(),
      );
    }
    if (item.iconUrl != null) {
      return Center(
        child: Image.network(
          item.iconUrl!,
          width: 64,
          height: 64,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _fallbackIcon(),
        ),
      );
    }
    return _fallbackIcon();
  }

  Widget _fallbackIcon() => Center(
        child: Text(item.category.emoji, style: const TextStyle(fontSize: 48)),
      );

  static String _formatDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});
  final String icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.md,
        vertical: Spacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(Radii.pill),
        border: Border.all(color: AppTheme.outline.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: Spacing.xs),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: AppTheme.onSurfaceVariant.withValues(alpha: 0.7),
        letterSpacing: 0.8,
      ),
    );
  }
}
