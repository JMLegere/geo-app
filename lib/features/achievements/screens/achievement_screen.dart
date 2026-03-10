import 'package:flutter/material.dart' hide Durations;

import 'package:earth_nova/features/achievements/widgets/achievement_list_view.dart';

/// Full-screen achievement browser.
///
/// Wraps [AchievementListView] in a Scaffold with an AppBar. The list
/// content is shared with the Sanctuary Achievements tab.
class AchievementScreen extends StatelessWidget {
  const AchievementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Text(
          'Achievements',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: false,
      ),
      body: const AchievementListView(),
    );
  }
}
