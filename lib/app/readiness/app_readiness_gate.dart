import 'dart:async';

import 'package:earth_nova/shared/design.dart';
import 'package:earth_nova/shared/widgets/tab_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/core/observability/browser_diagnostics.dart';
import 'package:earth_nova/features/auth/presentation/providers/auth_provider.dart';
import 'package:earth_nova/features/identification/presentation/providers/items_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/map_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/map_readiness_provider.dart';

import 'app_readiness.dart';

class AppReadinessGate extends ConsumerStatefulWidget {
  const AppReadinessGate({
    required this.userId,
    this.child = const TabShell(),
    super.key,
  });

  final String userId;
  final Widget child;

  @override
  ConsumerState<AppReadinessGate> createState() => _AppReadinessGateState();
}

class _AppReadinessGateState extends ConsumerState<AppReadinessGate> {
  Timer? _detailTimer;
  bool _showDetails = false;
  String? _copyStatus;

  @override
  void initState() {
    super.initState();
    _scheduleStart();
  }

  @override
  void didUpdateWidget(covariant AppReadinessGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) _scheduleStart();
  }

  void _scheduleStart() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _start();
    });
  }

  void _start({bool retry = false}) {
    _detailTimer?.cancel();
    _showDetails = false;
    _copyStatus = null;
    _detailTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _showDetails = true);
    });
    final notifier = ref.read(appReadinessProvider.notifier);
    unawaited(retry ? notifier.retry() : notifier.start(widget.userId));
  }

  @override
  void dispose() {
    _detailTimer?.cancel();
    super.dispose();
  }

  Future<void> _signOut() async {
    final purged = await ref
        .read(appReadinessProvider.notifier)
        .purge(widget.userId);
    if (purged && mounted) await ref.read(authProvider.notifier).signOut();
  }

  Future<void> _copyDiagnostics() async {
    final observability = ref.read(appObservabilityProvider);
    final readiness = ref.read(appReadinessProvider);
    final mapReadiness = ref.read(mapReadinessProvider);
    final map = ref.read(mapProvider);
    final items = ref.read(itemsProvider);
    observability.log(
      'app.readiness.diagnostics_copy_requested',
      'app',
      data: {'readiness_phase': readiness.phase.name},
    );
    final payload = observability.exportDiagnostics(
      browserLogsJson: readBrowserDiagnosticLogsJson(),
      debugInfo: {
        'readiness_phase': readiness.phase.name,
        'readiness_error': readiness.errorMessage,
        'readiness_completed_checkpoints': readiness.completedCheckpoints
            .toList(growable: false),
        'readiness_required_checkpoints': AppReadinessState.requiredCheckpoints
            .toList(growable: false),
        'map_readiness': mapReadiness.toLogData(),
        'map_state': map.runtimeType.toString(),
        if (map case MapStateReady ready) ...{
          'map_cell_count': ready.cells.length,
          'map_visited_cell_count': ready.visitedCellIds.length,
          'map_location': {
            'lat': ready.location.lat,
            'lng': ready.location.lng,
            'accuracy': ready.location.accuracy,
            'is_confident': ready.location.isConfident,
            'timestamp': ready.location.timestamp.toUtc().toIso8601String(),
          },
        },
        'pack_item_count': items.items.length,
        'pack_has_loaded': items.hasLoaded,
        'pack_is_loading': items.isLoading,
        'pack_error': items.error,
      },
    );
    try {
      await Clipboard.setData(ClipboardData(text: payload));
      if (mounted) setState(() => _copyStatus = 'Diagnostics copied');
    } catch (error, stack) {
      observability.logError(
        error,
        stack,
        event: 'app.readiness.diagnostics_copy_failed',
      );
      if (mounted) setState(() => _copyStatus = 'Could not copy diagnostics');
    }
  }

  @override
  Widget build(BuildContext context) {
    final readiness = ref.watch(appReadinessProvider);
    return Stack(
      fit: StackFit.expand,
      children: [
        AbsorbPointer(
          key: const Key('readiness-input-gate'),
          absorbing: !readiness.permitsInput,
          child: widget.child,
        ),
        if (!readiness.permitsInput)
          ColoredBox(
            color: Theme.of(context).colorScheme.surface,
            child: SafeArea(
              child: Center(
                child: _ReadinessOverlay(
                  readiness: readiness,
                  showDetails: _showDetails,
                  onRetry: () => _start(retry: true),
                  onSignOut: _signOut,
                  onCopyDiagnostics: _copyDiagnostics,
                  copyStatus: _copyStatus,
                ),
              ),
            ),
          )
        else if (readiness.phase == AppReadinessPhase.syncing ||
            readiness.phase == AppReadinessPhase.degraded ||
            readiness.phase == AppReadinessPhase.conflict ||
            readiness.phase == AppReadinessPhase.recovery)
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: _SyncStatus(
                readiness: readiness,
                onUseDevice: () =>
                    ref.read(appReadinessProvider.notifier).selectLocalSave(),
                onUseCloud: () =>
                    ref.read(appReadinessProvider.notifier).selectCloudSave(),
              ),
            ),
          ),
      ],
    );
  }
}

class _ReadinessOverlay extends StatelessWidget {
  const _ReadinessOverlay({
    required this.readiness,
    required this.showDetails,
    required this.onRetry,
    required this.onSignOut,
    required this.onCopyDiagnostics,
    required this.copyStatus,
  });

  final AppReadinessState readiness;
  final bool showDetails;
  final VoidCallback onRetry;
  final VoidCallback onSignOut;
  final VoidCallback onCopyDiagnostics;
  final String? copyStatus;

  @override
  Widget build(BuildContext context) {
    final failed = readiness.phase == AppReadinessPhase.failed;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: AppCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              failed ? 'We need a moment' : 'Preparing your expedition',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              failed
                  ? readiness.errorMessage ??
                        'Your latest map and Pack could not load.'
                  : _playerPhase(readiness.phase),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (!failed) ...[
              const SizedBox(height: 16),
              Semantics(
                key: const Key('readiness-progress'),
                label: 'Readiness progress',
                value:
                    '${readiness.completedRequiredCheckpoints} of ${readiness.totalRequiredCheckpoints} checkpoints complete',
                liveRegion: true,
                child: ExcludeSemantics(
                  child: ShadProgress(
                    value:
                        readiness.completedRequiredCheckpoints /
                        readiness.totalRequiredCheckpoints,
                  ),
                ),
              ),
              if (showDetails) ...[
                const SizedBox(height: 16),
                for (final checkpoint in AppReadinessState.requiredCheckpoints)
                  _Checkpoint(
                    label: _checkpointLabel(checkpoint),
                    complete: readiness.completedCheckpoints.contains(
                      checkpoint,
                    ),
                  ),
              ],
            ],
            if (failed) ...[
              const SizedBox(height: 24),
              AppButton(label: 'Retry', expand: true, onPressed: onRetry),
              const SizedBox(height: 8),
              AppButton(
                label: 'Sign out',
                variant: AppButtonVariant.ghost,
                expand: true,
                onPressed: onSignOut,
              ),
              const SizedBox(height: 8),
              AppButton(
                key: const Key('copy-readiness-diagnostics'),
                label: 'Copy diagnostics',
                variant: AppButtonVariant.outline,
                expand: true,
                onPressed: onCopyDiagnostics,
              ),
              if (copyStatus != null) ...[
                const SizedBox(height: 8),
                Semantics(
                  liveRegion: true,
                  child: Text(copyStatus!, textAlign: TextAlign.center),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _Checkpoint extends StatelessWidget {
  const _Checkpoint({required this.label, required this.complete});

  final String label;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final state = complete ? 'Complete' : 'Pending';
    return Semantics(
      label: '$label, $state',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(
                complete ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 18,
                color: complete
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(width: 8),
              Text(state, style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _SyncStatus extends StatelessWidget {
  const _SyncStatus({
    required this.readiness,
    required this.onUseDevice,
    required this.onUseCloud,
  });

  final AppReadinessState readiness;
  final VoidCallback onUseDevice;
  final VoidCallback onUseCloud;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: AppCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppNotice(
            title: switch (readiness.phase) {
              AppReadinessPhase.conflict => 'Choose your expedition',
              AppReadinessPhase.recovery => 'Progress needs attention',
              AppReadinessPhase.degraded =>
                'Using your latest saved expedition',
              _ => 'Syncing expedition',
            },
            message:
                readiness.errorMessage ??
                (readiness.isDegraded
                    ? 'Your saved expedition is available while we reconnect.'
                    : 'Your latest expedition is updating in the background.'),
            tone: readiness.phase == AppReadinessPhase.syncing
                ? AppNoticeTone.info
                : AppNoticeTone.warning,
          ),
          if (readiness.phase == AppReadinessPhase.conflict) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Use this device',
                    onPressed: onUseDevice,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppButton(
                    label: 'Use cloud save',
                    variant: AppButtonVariant.secondary,
                    onPressed: onUseCloud,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    ),
  );
}

String _playerPhase(AppReadinessPhase phase) => switch (phase) {
  AppReadinessPhase.hydrating => 'Gathering your map and Pack.',
  AppReadinessPhase.usable => 'Your expedition is ready.',
  AppReadinessPhase.syncing => 'Syncing your latest expedition.',
  AppReadinessPhase.degraded => 'Using your latest saved expedition.',
  AppReadinessPhase.conflict => 'Choose which complete expedition to keep.',
  AppReadinessPhase.recovery => 'Your saved expedition needs attention.',
  AppReadinessPhase.failed => 'Your expedition could not be prepared.',
};

String _checkpointLabel(String checkpoint) => switch (checkpoint) {
  'working_set' => 'Saved expedition',
  'pack' => 'Pack',
  'pack_media' => 'Pack artwork',
  'map_surface' => 'Map surface',
  _ => checkpoint,
};
