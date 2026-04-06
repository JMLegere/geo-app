import 'package:flutter/material.dart' hide Durations;
import 'package:earth_nova/core/domain/entities/game_region.dart';
import 'package:earth_nova/core/domain/entities/habitat.dart';
import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/core/domain/entities/iucn_status.dart';
import 'package:earth_nova/core/domain/entities/taxonomic_group.dart';
import 'package:earth_nova/shared/extensions/iconography.dart';
import 'package:earth_nova/shared/extensions/iucn_status_theme.dart';
import 'package:earth_nova/shared/theme/app_theme.dart';
import 'package:earth_nova/shared/theme/design_tokens.dart';

/// Shows a TCG-style species card as a centered modal overlay.
void showSpeciesCard(BuildContext context, Item item) {
  showGeneralDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.78),
    barrierDismissible: true,
    barrierLabel: 'Close species card',
    transitionDuration: const Duration(milliseconds: 400),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeIn,
      );
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.78, end: 1.0).animate(curved),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        ),
      );
    },
    pageBuilder: (context, _, __) => SpeciesCard(item: item),
  );
}

/// TCG card widget — can be used standalone or via [showSpeciesCard].
class SpeciesCard extends StatelessWidget {
  const SpeciesCard({super.key, required this.item});
  final Item item;

  @override
  Widget build(BuildContext context) {
    final status = IucnStatus.fromString(item.rarity);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final cardWidth = (screenWidth - 48).clamp(0.0, 320.0);
    final artHeight = cardWidth * 0.68;
    final borderColor = status?.color ?? AppTheme.outline;
    final isRare = status != null &&
        (status == IucnStatus.criticallyEndangered ||
            status == IucnStatus.endangered ||
            status == IucnStatus.vulnerable);
    final borderWidth = isRare ? 2.5 : 1.5;

    return Center(
      child: GestureDetector(
        onVerticalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0) > 300) {
            Navigator.of(context).pop();
          }
        },
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: cardWidth,
            decoration: BoxDecoration(
              color: _cardBgColor(status),
              borderRadius: BorderRadius.circular(Radii.xxxl),
              border: Border.all(color: borderColor, width: borderWidth),
              boxShadow: status != null && status.glowAlpha > 0
                  ? [
                      BoxShadow(
                        color: status.color
                            .withValues(alpha: status.glowAlpha + 0.10),
                        blurRadius: 24,
                        spreadRadius: -4,
                      ),
                    ]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Radii.xxxl - 1),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ArtZone(
                    item: item,
                    status: status,
                    width: cardWidth,
                    height: artHeight,
                  ),
                  Container(
                    height: 4,
                    color: status?.color ?? AppTheme.surfaceContainerHighest,
                  ),
                  _InfoZone(item: item, status: status),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Color _cardBgColor(IucnStatus? status) {
    if (status == null) return AppTheme.surfaceContainer;
    return switch (status) {
      IucnStatus.criticallyEndangered => const Color(0xFF150A24),
      IucnStatus.endangered => const Color(0xFF1A1200),
      IucnStatus.vulnerable => const Color(0xFF06142A),
      _ => AppTheme.surfaceContainer,
    };
  }
}

// ─── Art zone ─────────────────────────────────────────────────────────────────

class _ArtZone extends StatelessWidget {
  const _ArtZone({
    required this.item,
    required this.status,
    required this.width,
    required this.height,
  });

  final Item item;
  final IucnStatus? status;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildArt(),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    SpeciesCard._cardBgColor(status).withValues(alpha: 0.85),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Row(
              children: [
                if (status != null) _rarityPill(),
                const Spacer(),
                _overlayPill(
                  child: Text(item.category.emoji,
                      style: const TextStyle(fontSize: 16)),
                ),
                const SizedBox(width: Spacing.xs),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.80),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArt() {
    if (item.artUrl != null) {
      return Image.network(
        item.artUrl!,
        fit: BoxFit.cover,
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return _fallbackArt();
        },
        errorBuilder: (_, __, ___) => _fallbackArt(),
      );
    }
    if (item.iconUrl != null) {
      return Container(
        color: _artBgColor(),
        child: Center(
          child: Image.network(
            item.iconUrl!,
            width: 100,
            height: 100,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _fallbackEmoji(),
          ),
        ),
      );
    }
    return _fallbackArt();
  }

  Widget _fallbackArt() => Container(
        color: _artBgColor(),
        child: Center(child: _fallbackEmoji()),
      );

  Widget _fallbackEmoji() =>
      Text(item.category.emoji, style: const TextStyle(fontSize: 56));

  Color _artBgColor() {
    if (status == null) return AppTheme.surfaceContainerHigh;
    return switch (status!) {
      IucnStatus.criticallyEndangered => const Color(0xFF12072A),
      IucnStatus.endangered => const Color(0xFF1A1000),
      IucnStatus.vulnerable => const Color(0xFF04101E),
      _ => AppTheme.surfaceContainerHigh,
    };
  }

  Widget _rarityPill() {
    final isRare = status == IucnStatus.criticallyEndangered ||
        status == IucnStatus.endangered;
    return _overlayPill(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isRare) ...[
            Text('◆', style: TextStyle(fontSize: 6, color: status!.color)),
            const SizedBox(width: 2),
          ],
          Text(
            status!.code,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: status!.color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _overlayPill({required Widget child}) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sm,
          vertical: Spacing.xs,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
        child: child,
      );
}

// ─── Info zone ────────────────────────────────────────────────────────────────

class _InfoZone extends StatelessWidget {
  const _InfoZone({required this.item, required this.status});
  final Item item;
  final IucnStatus? status;

  @override
  Widget build(BuildContext context) {
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            item.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.onSurface,
              letterSpacing: -0.3,
            ),
          ),
          if (item.scientificName != null) ...[
            const SizedBox(height: 3),
            Text(
              item.scientificName!,
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: AppTheme.onSurfaceVariant.withValues(alpha: 0.80),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.xs,
            children: [
              if (status != null)
                _BadgePill(
                  text: '${status!.code} · ${status!.displayName}',
                  color: status!.color,
                ),
              if (item.taxonomicClass != null && group != TaxonomicGroup.other)
                _InfoPill(icon: group.icon, label: group.label),
            ],
          ),
          if (habitatList.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                for (var i = 0; i < habitatList.length && i < 7; i++) ...[
                  if (i > 0) const SizedBox(width: Spacing.sm),
                  Text(habitatList[i].icon,
                      style: const TextStyle(fontSize: 18)),
                ],
              ],
            ),
          ],
          if (regionList.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                for (var i = 0; i < regionList.length && i < 6; i++) ...[
                  if (i > 0) const SizedBox(width: Spacing.sm),
                  Text(regionList[i].icon,
                      style: const TextStyle(fontSize: 18)),
                ],
              ],
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('📅', style: TextStyle(fontSize: 12)),
              Text(
                _formatDate(item.acquiredAt),
                style: TextStyle(
                  fontSize: 10,
                  color: AppTheme.onSurfaceVariant.withValues(alpha: 0.60),
                ),
              ),
              if (item.acquiredInCellId != null) ...[
                Text('·',
                    style: TextStyle(
                        color:
                            AppTheme.onSurfaceVariant.withValues(alpha: 0.30))),
                const Text('📍', style: TextStyle(fontSize: 12)),
                Text(
                  'Cell ${item.acquiredInCellId}',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.onSurfaceVariant.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

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

// ─── Badge pills ──────────────────────────────────────────────────────────────

class _BadgePill extends StatelessWidget {
  const _BadgePill({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(Radii.pill),
        border: Border.all(color: color.withValues(alpha: 0.50)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});
  final String icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(Radii.pill),
        border: Border.all(color: AppTheme.outline.withValues(alpha: 0.50)),
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
              color: AppTheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
