import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/features/encounters/presentation/providers/pending_encounter_provider.dart';
import 'package:earth_nova/shared/design.dart';

class PendingEncounterLayer extends ConsumerWidget {
  const PendingEncounterLayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pendingEncounterProvider);
    if (state is! PendingEncounterReady) return const SizedBox.shrink();

    final pending = state.pendingEncounter;
    final option = pending.options.first;
    final theme = Theme.of(context);

    return IgnorePointer(
      child: SafeArea(
        minimum: const EdgeInsets.all(Spacing.lg),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Semantics(
            container: true,
            label: 'Pending encounter: ${pending.definitionDisplayName}. '
                'Option: ${option.displayName}.',
            child: ExcludeSemantics(
              child: Card(
                margin: EdgeInsets.zero,
                color: theme.colorScheme.surfaceContainerHigh,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Radii.xl),
                  side: BorderSide(color: theme.colorScheme.outline),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(Spacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const EarthMetaText(
                        'Pending encounter',
                        tone: EarthMetaTone.accent,
                      ),
                      const SizedBox(height: Spacing.xs),
                      Text(
                        pending.definitionDisplayName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: Spacing.md),
                      const EarthMetaText(
                        'Option',
                        tone: EarthMetaTone.muted,
                      ),
                      const SizedBox(height: Spacing.xs),
                      Text(
                        option.displayName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
