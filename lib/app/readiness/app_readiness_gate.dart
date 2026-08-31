import 'dart:async';

import 'package:earth_nova/shared/design.dart';
import 'package:earth_nova/shared/widgets/tab_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:earth_nova/features/auth/presentation/providers/auth_provider.dart';

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
                ),
              ),
            ),
          )
        else if (readiness.phase == AppReadinessPhase.syncing ||
            readiness.phase == AppReadinessPhase.degraded)
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: _SyncStatus(degraded: readiness.isDegraded),
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
  });

  final AppReadinessState readiness;
  final bool showDetails;
  final VoidCallback onRetry;
  final VoidCallback onSignOut;

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
  const _SyncStatus({required this.degraded});

  final bool degraded;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: AppNotice(
      title: degraded
          ? 'Using your latest saved expedition'
          : 'Syncing expedition',
      message: degraded
          ? 'Your saved Map and Pack are available while we reconnect.'
          : 'Your latest Map and Pack are updating in the background.',
      tone: degraded ? AppNoticeTone.warning : AppNoticeTone.info,
    ),
  );
}

String _playerPhase(AppReadinessPhase phase) => switch (phase) {
  AppReadinessPhase.hydrating => 'Gathering your map and Pack.',
  AppReadinessPhase.usable => 'Your expedition is ready.',
  AppReadinessPhase.syncing => 'Syncing your latest expedition.',
  AppReadinessPhase.degraded => 'Using your latest saved expedition.',
  AppReadinessPhase.failed => 'Your expedition could not be prepared.',
};

String _checkpointLabel(String checkpoint) => switch (checkpoint) {
  'working_set' => 'Saved expedition',
  'pack' => 'Pack',
  'map_surface' => 'Map surface',
  _ => checkpoint,
};
