import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/core/fog/fog_state_resolver.dart';
import 'package:earth_nova/core/state/daily_seed_provider.dart';
import 'package:earth_nova/core/state/fog_resolver_provider.dart';
import 'package:earth_nova/core/state/player_provider.dart';
import 'package:earth_nova/shared/constants.dart';
import 'package:earth_nova/shared/design_tokens.dart';

/// Bottom sheet that shows cell information and lets the player spend steps to
/// explore a frontier cell remotely.
///
/// ## Exploration logic (in order):
/// 1. Web platform → info only, no explore button.
/// 2. Player is physically in this cell → shows "You're here!" instead.
/// 3. Cell already visited → shows "Already explored".
/// 4. Cell not on frontier → shows "Not adjacent to explored area".
/// 5. Insufficient steps → disabled button with reason text.
/// 6. All checks pass → enabled "Explore (500 steps)" button.
///
/// Tapping the button:
///   - Disables button immediately (rapid-tap guard).
///   - Calls [PlayerNotifier.spendSteps] → reduces [PlayerState.totalSteps].
///   - Calls [FogStateResolver.visitCellRemotely] → emits [onVisitedCellAdded]
///     which triggers [DiscoveryService] automatically (no extra wiring needed).
///   - Closes the sheet.
///
/// Stale seed: exploration is allowed but a warning is shown that species
/// discoveries are paused until the seed refreshes.
class CellInfoSheet extends ConsumerStatefulWidget {
  const CellInfoSheet({
    required this.cellId,
    this.isWebPlatformOverride,
    super.key,
  });

  /// The tapped cell ID to display information for.
  final String cellId;

  /// Override the web platform check. Defaults to [kIsWeb].
  ///
  /// Inject `true` in tests to simulate web platform behavior (hides explore
  /// button). In production code, leave null so [kIsWeb] is used.
  @visibleForTesting
  final bool? isWebPlatformOverride;

  @override
  ConsumerState<CellInfoSheet> createState() => _CellInfoSheetState();
}

class _CellInfoSheetState extends ConsumerState<CellInfoSheet> {
  /// Rapid-tap guard: disabled while an exploration action is in flight.
  bool _isExploring = false;

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final fogResolver = ref.read(fogResolverProvider);
    final seedService = ref.read(dailySeedServiceProvider);

    final isWeb = widget.isWebPlatformOverride ?? kIsWeb;
    final totalSteps = playerState.totalSteps;
    final isVisited = fogResolver.visitedCellIds.contains(widget.cellId);
    final isCurrentCell = fogResolver.currentCellId == widget.cellId;
    final isFrontier = fogResolver.explorationFrontier.contains(widget.cellId);
    final isDiscoveryPaused = seedService.isDiscoveryPaused;

    // Determine the cell status label for display.
    final String statusLabel;
    if (isCurrentCell) {
      statusLabel = 'You are here';
    } else if (isVisited) {
      statusLabel = 'Explored';
    } else if (isFrontier) {
      statusLabel = 'Frontier';
    } else {
      statusLabel = 'Undiscovered';
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Spacing.lg,
          Spacing.md,
          Spacing.lg,
          Spacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Drag handle ────────────────────────────────────────────────
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: Spacing.md),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withAlpha(77),
                  borderRadius: Radii.borderPill,
                ),
              ),
            ),

            // ── Cell ID ────────────────────────────────────────────────────
            Text(
              'Cell',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    letterSpacing: 1.2,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              widget.cellId,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontFamily: 'monospace',
                fontFamilyFallback: const ['Courier New'],
              ),
            ),

            Spacing.gapMd,

            // ── Status row ────────────────────────────────────────────────
            Row(
              children: [
                _StatusChip(label: statusLabel, isCurrentCell: isCurrentCell),
                if (!isWeb) ...[
                  const Spacer(),
                  Text(
                    '$totalSteps steps',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                    semanticsLabel: 'Current step balance: $totalSteps steps',
                  ),
                ],
              ],
            ),

            Spacing.gapMd,

            // ── Stale seed warning ─────────────────────────────────────────
            if (isDiscoveryPaused)
              Padding(
                padding: const EdgeInsets.only(bottom: Spacing.md),
                child: Row(
                  children: [
                    Icon(
                      Icons.cloud_off_rounded,
                      size: 14,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    Spacing.gapXs,
                    Text(
                      'Species discoveries paused — seed refreshing…',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.error,
                          ),
                    ),
                  ],
                ),
              ),

            // ── Action area ───────────────────────────────────────────────
            // Web: no step spending UI.
            if (!isWeb) _buildExploreAction(context, playerState, fogResolver),
          ],
        ),
      ),
    );
  }

  Widget _buildExploreAction(
    BuildContext context,
    PlayerState playerState,
    FogStateResolver fogResolver,
  ) {
    final isVisited = fogResolver.visitedCellIds.contains(widget.cellId);
    final isCurrentCell = fogResolver.currentCellId == widget.cellId;
    final isFrontier = fogResolver.explorationFrontier.contains(widget.cellId);
    final hasEnoughSteps = playerState.totalSteps >= kStepCostPerCell;

    // Conditions where we show a disabled/non-explore button:
    if (isCurrentCell) {
      return _buildInfoRow(context, Icons.location_on_rounded, "You're here!");
    }

    if (isVisited) {
      return _buildInfoRow(
          context, Icons.check_circle_rounded, 'Already explored');
    }

    if (!isFrontier) {
      return _buildInfoRow(
        context,
        Icons.explore_off_rounded,
        'Not adjacent to explored area',
      );
    }

    // Frontier cell — show explore button (enabled or disabled by steps).
    final String buttonLabel = 'Explore (${kStepCostPerCell} steps)';
    final String? disabledReason =
        hasEnoughSteps ? null : 'Not enough steps (need $kStepCostPerCell)';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (disabledReason != null)
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.sm),
            child: Text(
              disabledReason,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
              textAlign: TextAlign.center,
            ),
          ),
        SizedBox(
          height: ComponentSizes.buttonHeight,
          child: ElevatedButton.icon(
            key: const Key('explore_button'),
            onPressed: (hasEnoughSteps && !_isExploring) ? _onExplore : null,
            icon: const Icon(Icons.explore_rounded),
            label: Text(buttonLabel),
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: Radii.borderXxxl,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String message) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        Spacing.gapXs,
        Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  Future<void> _onExplore() async {
    // Rapid-tap guard: disable immediately so double-taps cannot double-spend.
    setState(() => _isExploring = true);

    final playerNotifier = ref.read(playerProvider.notifier);
    final fogResolver = ref.read(fogResolverProvider);

    // Spend steps first — returns false if overdraft would occur.
    final spent = playerNotifier.spendSteps(kStepCostPerCell);
    if (!spent) {
      // State race: steps changed between render and tap (e.g. rapid taps).
      setState(() => _isExploring = false);
      return;
    }

    // Visit the cell remotely — triggers DiscoveryService via onVisitedCellAdded.
    try {
      fogResolver.visitCellRemotely(widget.cellId);
    } catch (_) {
      // Cell left frontier between render and tap (e.g. GPS moved player into it).
      // Refund the steps to keep the balance consistent.
      playerNotifier.addSteps(kStepCostPerCell);
      setState(() => _isExploring = false);
      return;
    }

    // Close the sheet — exploration is complete.
    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.isCurrentCell});

  final String label;
  final bool isCurrentCell;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final Color chipColor =
        isCurrentCell ? colorScheme.primary : colorScheme.secondaryContainer;
    final Color labelColor = isCurrentCell
        ? colorScheme.onPrimary
        : colorScheme.onSecondaryContainer;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.sm,
        vertical: Spacing.xxs,
      ),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: Radii.borderXxxl,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: labelColor,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
