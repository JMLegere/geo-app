import 'package:flutter/material.dart' hide Durations;

import 'package:earth_nova/core/models/item_instance.dart';
import 'package:earth_nova/shared/design_tokens.dart';
import 'package:earth_nova/features/pack/widgets/species_card.dart';
import 'package:earth_nova/features/pack/widgets/species_card_rarity_frame.dart';

/// Shows the species card as a centered modal dialog.
///
/// Usage:
/// ```dart
/// showSpeciesCardModal(context, item: instance);
/// ```
void showSpeciesCardModal(
  BuildContext context, {
  required ItemInstance item,
}) {
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss species card',
    barrierColor: Colors.black.withValues(alpha: 0.6),
    transitionDuration: const Duration(milliseconds: 450),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return _SpeciesCardDialog(
        item: item,
        animation: animation,
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1.0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      );
    },
  );
}

/// The dialog wrapper — applies rarity frame and responsive sizing.
class _SpeciesCardDialog extends StatelessWidget {
  const _SpeciesCardDialog({
    required this.item,
    required this.animation,
  });

  final ItemInstance item;
  final Animation<double> animation;

  /// Responsive card width as fraction of screen.
  double _cardWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final shortestSide = MediaQuery.of(context).size.shortestSide;

    if (shortestSide >= 900) {
      // Tablet: 35% screen width, max 440px
      return (screenWidth * 0.35).clamp(0, 440);
    } else if (shortestSide >= 600) {
      // Tablet: 55% screen width, max 440px
      return (screenWidth * 0.55).clamp(0, 440);
    } else {
      // Phone: 85% screen width
      return screenWidth * 0.85;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rarity = item.rarity;
    final cardWidth = _cardWidth(context);
    // 2:3 aspect ratio (width : height)
    final cardHeight = cardWidth * 1.5;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: cardWidth,
          height:
              cardHeight.clamp(0, MediaQuery.of(context).size.height * 0.88),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E), // dark card surface
            borderRadius: Radii.borderLg,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 24,
                spreadRadius: 4,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: Radii.borderLg,
            child: SpeciesCardRarityFrame(
              rarity: rarity,
              borderRadius: Radii.lg,
              child: Padding(
                padding: EdgeInsets.all(Spacing.lg),
                child: SpeciesCard(
                  item: item,
                  animate: true,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
