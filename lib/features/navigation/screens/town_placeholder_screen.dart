import 'package:flutter/material.dart';
import 'package:earth_nova/shared/widgets/empty_state_widget.dart';

/// Placeholder for the Town tab until the NPC system is implemented.
///
/// No AppBar — the shell-level identicon overlay is visible on this tab.
class TownPlaceholderScreen extends StatelessWidget {
  const TownPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: EmptyStateWidget(
        icon: '🏘️',
        title: 'Town — Coming Soon',
        subtitle:
            'Discover NPCs while exploring the map.\nThey\'ll gather here.',
      ),
    );
  }
}
