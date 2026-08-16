import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/features/encounters/presentation/providers/pending_encounter_provider.dart';
import 'package:earth_nova/shared/design.dart';
import 'package:earth_nova/shared/product/player_actions.dart';
import 'package:earth_nova/shared/product/product_action_surface.dart';

class PendingEncounterLayer extends ConsumerWidget {
  const PendingEncounterLayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pendingEncounterProvider);
    PendingEncounterReady? ready;
    PendingEncounterResolving? resolving;
    PendingEncounterFailure? failure;

    if (state is PendingEncounterReady) {
      ready = state;
    } else if (state is PendingEncounterResolving) {
      resolving = state;
    } else if (state is PendingEncounterFailure &&
        state.pendingEncounter != null) {
      failure = state;
    } else {
      return const SizedBox.shrink();
    }

    final pending = ready?.pendingEncounter ??
        resolving?.pendingEncounter ??
        failure!.pendingEncounter!;
    final option = pending.options.first;
    final isResolving = resolving != null;
    final isRetry = failure != null;
    final onPressed = isResolving
        ? null
        : isRetry
            ? () =>
                ref.read(pendingEncounterProvider.notifier).retryResolution()
            : () =>
                ref.read(pendingEncounterProvider.notifier).resolve(option.id);

    return SafeArea(
      minimum: const EdgeInsets.all(Spacing.lg),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: EarthPanel(
          title: pending.definitionDisplayName,
          eyebrow: 'Pending encounter',
          tone: EarthPanelTone.accent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              EarthFieldRow(
                label: 'Option',
                value: option.displayName,
              ),
              const SizedBox(height: Spacing.md),
              ProductActionSurface(
                actionId: PlayerActions.resolvePresentEncounter,
                child: Semantics(
                  key: const Key('resolve-present-encounter'),
                  label: 'Pending encounter: ${pending.definitionDisplayName}. '
                      'Option: ${option.displayName}.',
                  button: true,
                  enabled: onPressed != null,
                  onTap: onPressed,
                  excludeSemantics: true,
                  child: isResolving
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox.square(
                              dimension: Spacing.xl,
                              child: CircularProgressIndicator(
                                strokeWidth: Spacing.xxs,
                              ),
                            ),
                            const SizedBox(width: Spacing.sm),
                            Text(
                              'Resolving…',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                          ],
                        )
                      : EarthActionButton(
                          label: isRetry ? 'Retry' : 'Resolve',
                          onPressed: onPressed,
                          actionId: PlayerActions.resolvePresentEncounter,
                          tone: EarthActionTone.secondary,
                          expand: true,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
