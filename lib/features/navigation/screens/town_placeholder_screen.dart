import 'package:flutter/material.dart';
import 'package:fog_of_world/shared/widgets/empty_state_widget.dart';

/// Placeholder for the Town tab until the NPC system is implemented.
class TownPlaceholderScreen extends StatelessWidget {
  const TownPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: EmptyStateWidget(
        icon: '🏘️',
        title: 'Town — Coming Soon',
        subtitle: 'Discover NPCs while exploring the map.\nThey\'ll gather here.',
      ),
    );
  }
}
