import 'package:flutter/material.dart' hide Durations;

import 'package:earth_nova/core/models/item_category.dart';
import 'package:earth_nova/shared/game_icons.dart';
import 'package:earth_nova/shared/widgets/empty_state_widget.dart';

/// Placeholder tab for item categories not yet implemented.
///
/// Shows an [EmptyStateWidget] with the category icon and a "coming soon"
/// message. Used for Flora, Minerals, Fossils, Artifacts, Food, and Orbs
/// until those categories have real UI.
class CategoryStubTab extends StatelessWidget {
  const CategoryStubTab({required this.category, super.key});

  /// The item category this stub represents.
  final ItemCategory category;

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      icon: GameIcons.category(category),
      title: '${_capitalize(category.displayName)} coming soon',
      subtitle: 'This category will be available in a future update.',
    );
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}
