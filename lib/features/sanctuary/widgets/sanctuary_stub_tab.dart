import 'package:flutter/material.dart' hide Durations;

import 'package:earth_nova/features/sanctuary/providers/sanctuary_provider.dart';
import 'package:earth_nova/shared/widgets/empty_state_widget.dart';

/// Placeholder tab for sanctuary features not yet implemented.
///
/// Shows an [EmptyStateWidget] with the tab emoji and a "coming soon"
/// message. Used for Feeding, Breeding, and Museum until those features
/// have real UI.
class SanctuaryStubTab extends StatelessWidget {
  const SanctuaryStubTab({required this.tab, super.key});

  /// The sanctuary tab this stub represents.
  final SanctuaryTab tab;

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      icon: tab.emoji,
      title: '${tab.displayName} coming soon',
      subtitle: 'This feature will be available in a future update.',
    );
  }
}
