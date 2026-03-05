import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fog_of_world/features/achievements/models/achievement.dart';
import 'package:fog_of_world/features/achievements/models/achievement_state.dart';
import 'package:fog_of_world/features/achievements/providers/achievement_provider.dart';

/// Full-screen achievement browser.
///
/// Layout:
/// 1. AppBar — "Achievements" title.
/// 2. Header card — "X / Y Unlocked" summary.
/// 3. ListView — unlocked achievements first (sorted by unlock date),
///    then locked achievements sorted by their registry order.
class AchievementScreen extends ConsumerWidget {
  const AchievementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final achievementsState = ref.watch(achievementProvider);
    final sortedItems = _sortedAchievements(achievementsState);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAF8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAFAF8),
        elevation: 0,
        scrolledUnderElevation: 1,
        title: const Text(
          'Achievements',
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
            separatorBuilder: (_, __) => const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Divider(color: Color(0xFFE5E7EB), height: 1),
            ),
            itemBuilder: (_, index) {
              final progress = sortedItems[index];
              final def = kAchievementDefinitions[progress.id]!;
              return _AchievementTile(progress: progress, definition: def);
            },
          ),

          // Bottom padding
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  /// Returns achievements sorted: unlocked first (newest first), then locked.
  List<AchievementProgress> _sortedAchievements(AchievementsState state) {
    final unlocked = state.achievements.values
        .where((p) => p.isUnlocked)
        .toList()
      ..sort((a, b) {
        // Newest unlock first; fallback to registry order if dates equal.
        final aDate = a.unlockedAt;
        final bDate = b.unlockedAt;
        if (aDate != null && bDate != null) return bDate.compareTo(aDate);
        if (aDate != null) return -1;
        if (bDate != null) return 1;
        return 0;
      });

    final locked = state.achievements.values
        .where((p) => !p.isUnlocked)
        .toList()
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

    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '🏆',
                style: TextStyle(fontSize: 28),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$unlockedCount / $totalCount Unlocked',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A2E1B),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    unlockedCount == totalCount
                        ? 'All achievements complete!'
                        : '${totalCount - unlockedCount} remaining',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Overall progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 8,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF10B981),
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

    return Opacity(
      opacity: isUnlocked ? 1.0 : 0.6,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Emoji icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isUnlocked
                    ? const Color(0xFF10B981).withValues(alpha: 0.12)
                    : const Color(0xFF9CA3AF).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  definition.emoji,
                  style: const TextStyle(fontSize: 26),
                ),
              ),
            ),
            const SizedBox(width: 14),

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
                      color: isUnlocked
                          ? const Color(0xFF1A2E1B)
                          : const Color(0xFF4B5563),
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    definition.description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  if (!isUnlocked) ...[
                    const SizedBox(height: 8),
                    _ProgressBar(progress: progress),
                  ],
                  if (isUnlocked && progress.unlockedAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(progress.unlockedAt!),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF10B981),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Right indicator
            if (isUnlocked)
              const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF10B981),
                size: 24,
              )
            else
              const Icon(
                Icons.lock_outline_rounded,
                color: Color(0xFF9CA3AF),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 5,
            backgroundColor: const Color(0xFFE5E7EB),
            valueColor: const AlwaysStoppedAnimation<Color>(
              Color(0xFF6B7280),
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF9CA3AF),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
