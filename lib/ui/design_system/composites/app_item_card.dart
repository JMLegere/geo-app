import 'package:flutter/material.dart';
import '../foundations/app_design_theme.dart';
import '../foundations/spacing.dart';
import 'app_card.dart';

/// Only Player-permitted, category-specific information belongs in a card.
class AppCardProperty {
  const AppCardProperty({required this.label, required this.value});
  final String label;
  final String value;
}

/// Shared non-interactive portrait used by collection and inspection adapters.
/// The feature owns the exact Item action and supplies knowledge-safe artwork.
class AppItemCard extends StatelessWidget {
  const AppItemCard({
    required this.artwork,
    this.unknown = false,
    this.busy = false,
    this.property,
    super.key,
  });
  final Widget artwork;
  final bool unknown;
  final bool busy;
  final AppCardProperty? property;

  @override
  Widget build(BuildContext context) => AppCard(
    tone: AppSurfaceTone.card,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (unknown)
          DecoratedBox(
            decoration: const BoxDecoration(color: DesignPalette.emphasis),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.xxs),
              child: Text(
                'Unknown',
                textAlign: TextAlign.center,
                style: DesignTypography.compact.copyWith(
                  color: DesignPalette.outline,
                ),
              ),
            ),
          ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(Spacing.xs),
            child: Center(
              child: busy
                  ? const Icon(
                      Icons.hourglass_top,
                      key: Key('pack-examining-icon'),
                    )
                  : artwork,
            ),
          ),
        ),
        if (!unknown && property != null)
          Semantics(
            label: '${property!.label}: ${property!.value}',
            child: ExcludeSemantics(
              child: DecoratedBox(
                decoration: const BoxDecoration(color: DesignPalette.inset),
                child: Padding(
                  padding: const EdgeInsets.all(Spacing.xxs),
                  child: Text(
                    property!.value,
                    textAlign: TextAlign.center,
                    style: DesignTypography.compact,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
