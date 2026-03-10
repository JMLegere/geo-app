import 'package:flutter/material.dart' hide Durations;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/features/achievements/models/achievement.dart';
import 'package:earth_nova/features/achievements/models/achievement_state.dart';
import 'package:earth_nova/features/achievements/providers/achievement_provider.dart';
import 'package:earth_nova/shared/design_tokens.dart';
import 'package:earth_nova/shared/earth_nova_theme.dart';

/// Reusable achievement list content — no Scaffold/AppBar wrapper.
///
/// Used by both [AchievementScreen] (standalone page) and the Sanctuary
/// Achievements tab. Reads from [achievementProvider].
class AchievementListView extends ConsumerWidget {
  const AchievementListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final achievementsState = ref.watch(achievementProvider);
    final sortedItems = _sortedAchievements(achievementsState);

    return CustomScrollView(
      slivers: [
        // Summary header
        SliverToBoxAdapter(
          child: _UnlockedHeader(
            unlockedCount: achievementsState.unlockedCount,
            totalCount: achievementsState.totalCount,
          ),
        ),

        // Achievement list
        SliverList.separated(
          itemCount: sortedItems.length,
          separatorBuilder: (ctx, __) => Padding(
            padding: Spacing.paddingScreenH,
            child: Divider(
                color: Theme.of(ctx).colorScheme.outlineVariant, height: 1),
          ),
          itemBuilder: (_, index) {
            final progress = sortedItems[index];
            final def = kAchievementDefinitions[progress.id]!;
            return _AchievementTile(progress: progress, definition: def);
          },
        ),

        // Bottom padding
        const SliverToBoxAdapter(child: SizedBox(height: Spacing.xxxl)),
      ],
    );
  }

  /// Returns achievements sorted: unlocked first (newest first), then locked.
  List<AchievementProgress> _sortedAchievements(AchievementsState state) {
    final unlocked =
        state.achievements.values.where((p) => p.isUnlocked).toList()
          ..sort((a, b) {
            // Newest unlock first; fallback to registry order if dates equal.
            final aDate = a.unlockedAt;
            final bDate = b.unlockedAt;
            if (aDate != null && bDate != null) return bDate.compareTo(aDate);
            if (aDate != null) return -1;
            if (bDate != null) return 1;
            return 0;
          });

    final locked =
        state.achievements.values.where((p) => !p.isUnlocked).toList()
          ..sort(
            (a, b) => AchievementId.values
                .indexOf(a.id)
                .compareTo(AchievementId.values.indexOf(b.id)),
          );

    return [...unlocked, ...locked];
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _UnlockedHeader extends StatelessWidget {
  final int unlockedCount;
  final int totalCount;

  const _UnlockedHeader({
    required this.unlockedCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = totalCount == 0 ? 0.0 : unlockedCount / totalCount;
    final cs = Theme.of(context).colorScheme;
    final nova = context.earthNova;

    return Container(
      margin:
          EdgeInsets.fromLTRB(Spacing.lg, Spacing.xs, Spacing.lg, Spacing.xxl),
      padding: EdgeInsets.all(Spacing.xl),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: Radii.borderXxxl,
        boxShadow: Shadows.medium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '🏆',
                style: TextStyle(fontSize: 28),
              ),
              Spacing.gapHMd,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$unlockedCount / $totalCount Unlocked',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    unlockedCount == totalCount
                        ? 'All achievements complete!'
                        : '${totalCount - unlockedCount} remaining',
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Spacing.gapLg,
          // Overall progress bar
          ClipRRect(
            borderRadius: Radii.borderXs,
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 8,
              backgroundColor: cs.outlineVariant,
              valueColor: AlwaysStoppedAnimation<Color>(
                nova.successColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Achievement tile
// ---------------------------------------------------------------------------

class _AchievementTile extends StatelessWidget {
  final AchievementProgress progress;
  final AchievementDefinition definition;

  const _AchievementTile({
    required this.progress,
    required this.definition,
  });

  @override
  Widget build(BuildContext context) {
    final isUnlocked = progress.isUnlocked;
    final cs = Theme.of(context).colorScheme;
    final nova = context.earthNova;

    return Opacity(
      opacity: isUnlocked ? 1.0 : 0.6,
      child: Container(
        color: cs.surfaceContainer,
        padding: EdgeInsets.symmetric(
            horizontal: Spacing.lg, vertical: Spacing.md + 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Emoji icon
            Container(
              width: Spacing.massive,
              height: Spacing.massive,
              decoration: BoxDecoration(
                color: isUnlocked
                    ? nova.successColor
                        .withValues(alpha: Opacities.badgeBackgroundSubtle)
                    : cs.outline.withValues(alpha: 0.10),
                borderRadius: Radii.borderXl,
              ),
              child: Center(
                child: Text(
                  definition.icon,
                  style: const TextStyle(fontSize: 26),
                ),
              ),
            ),
            SizedBox(width: Spacing.md + 2),

            // Title + description + progress
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    definition.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isUnlocked ? cs.onSurface : cs.onSurfaceVariant,
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    definition.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  if (!isUnlocked) ...[
                    Spacing.gapSm,
                    _ProgressBar(progress: progress),
                  ],
                  if (isUnlocked && progress.unlockedAt != null) ...[
                    Spacing.gapXs,
                    Text(
                      _formatDate(progress.unlockedAt!),
                      style: TextStyle(
                        fontSize: 11,
                        color: nova.successColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            Spacing.gapHSm,

            // Right indicator
            if (isUnlocked)
              Icon(
                Icons.check_circle_rounded,
                color: nova.successColor,
                size: 24,
              )
            else
              Icon(
                Icons.lock_outline_rounded,
                color: cs.outline,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final months = [
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
    return 'Unlocked ${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}

// ---------------------------------------------------------------------------
// Progress bar widget for locked achievements
// ---------------------------------------------------------------------------

class _ProgressBar extends StatelessWidget {
  final AchievementProgress progress;

  const _ProgressBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    final fraction = progress.progressFraction;
    final label = '${progress.currentValue}/${progress.targetValue}';
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(Radii.xs),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 5,
            backgroundColor: cs.outlineVariant,
            valueColor: AlwaysStoppedAnimation<Color>(
              cs.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: cs.outline,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
