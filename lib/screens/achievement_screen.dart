import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/providers/achievement_provider.dart';

class AchievementScreen extends ConsumerWidget {
  const AchievementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(achievementProvider);
    final all = state.achievements.values.toList();

    // Sort: unlocked first, then by progress fraction desc
    all.sort((a, b) {
      if (a.isUnlocked != b.isUnlocked) {
        return a.isUnlocked ? -1 : 1;
      }
      return b.progressFraction.compareTo(a.progressFraction);
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        title: Row(
          children: [
            const Text('Achievements'),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${state.unlockedIds.length}/${all.length}',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: all.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _AchievementCard(progress: all[i]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _AchievementCard extends StatelessWidget {
  final AchievementProgress progress;

  const _AchievementCard({required this.progress});

  static const _kMeta =
      <AchievementId, ({String title, String desc, IconData icon})>{
    AchievementId.firstSteps: (
      title: 'First Steps',
      desc: 'Observe your first cell',
      icon: Icons.directions_walk,
    ),
    AchievementId.explorer: (
      title: 'Explorer',
      desc: 'Observe 10 cells',
      icon: Icons.explore,
    ),
    AchievementId.cartographer: (
      title: 'Cartographer',
      desc: 'Observe 50 cells',
      icon: Icons.map,
    ),
    AchievementId.naturalist: (
      title: 'Naturalist',
      desc: 'Discover 5 species',
      icon: Icons.eco,
    ),
    AchievementId.biologist: (
      title: 'Biologist',
      desc: 'Discover 15 species',
      icon: Icons.biotech,
    ),
    AchievementId.taxonomist: (
      title: 'Taxonomist',
      desc: 'Discover 50 species',
      icon: Icons.library_books,
    ),
    AchievementId.forestFriend: (
      title: 'Forest Friend',
      desc: 'Discover a forest species',
      icon: Icons.park,
    ),
    AchievementId.oceanExplorer: (
      title: 'Ocean Explorer',
      desc: 'Discover a saltwater species',
      icon: Icons.waves,
    ),
    AchievementId.mountaineer: (
      title: 'Mountaineer',
      desc: 'Discover a mountain species',
      icon: Icons.terrain,
    ),
    AchievementId.dedicated: (
      title: 'Dedicated',
      desc: 'Maintain a 7-day streak',
      icon: Icons.local_fire_department,
    ),
    AchievementId.devoted: (
      title: 'Devoted',
      desc: 'Maintain a 30-day streak',
      icon: Icons.favorite,
    ),
    AchievementId.marathon: (
      title: 'Marathon',
      desc: 'Walk 10 km total',
      icon: Icons.directions_run,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final meta = _kMeta[progress.id]!;
    final unlocked = progress.isUnlocked;
    final fraction = progress.progressFraction;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: unlocked
              ? Colors.amber.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: unlocked
                  ? Colors.amber.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              meta.icon,
              size: 22,
              color: unlocked ? Colors.amber : Colors.white38,
            ),
          ),
          const SizedBox(width: 14),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      meta.title,
                      style: TextStyle(
                        color: unlocked ? Colors.white : Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (unlocked) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.check_circle,
                          size: 14, color: Colors.amber),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  meta.desc,
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
                const SizedBox(height: 6),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 4,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      unlocked ? Colors.amber : Colors.blueAccent,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${progress.currentValue} / ${progress.targetValue}',
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
