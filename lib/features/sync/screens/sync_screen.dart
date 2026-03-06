import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:fog_of_world/features/auth/models/auth_state.dart';
import 'package:fog_of_world/features/auth/providers/auth_provider.dart';
import 'package:fog_of_world/features/sync/models/sync_status.dart';
import 'package:fog_of_world/features/sync/providers/sync_provider.dart';

/// A settings-style screen for manual cloud sync.
///
/// Shows current sync status, last sync time, pending change count, and a
/// "Sync Now" button.  Unauthenticated users see a prompt to sign in instead.
class SyncScreen extends ConsumerWidget {
  const SyncScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncStatus = ref.watch(syncProvider);
    final authState = ref.watch(authProvider);
    final isUnauthenticated = authState.status == AuthStatus.unauthenticated;
    final isSyncing = syncStatus.type == SyncStatusType.syncing;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cloud Sync'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StatusCard(syncStatus: syncStatus, isUnauthenticated: isUnauthenticated),
              const SizedBox(height: 16),
              if (syncStatus.type == SyncStatusType.error &&
                  syncStatus.errorMessage != null)
                _ErrorBanner(
                  message: syncStatus.errorMessage!,
                  onRetry: isUnauthenticated
                      ? null
                      : () => ref.read(syncProvider.notifier).syncNow(),
                ),
              const SizedBox(height: 16),
              _SyncButton(
                isSyncing: isSyncing,
                isDisabled: isUnauthenticated,
                onPressed: () => ref.read(syncProvider.notifier).syncNow(),
              ),
              const SizedBox(height: 24),
              const _InfoText(),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Subwidgets ────────────────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.syncStatus, required this.isUnauthenticated});

  final SyncStatus syncStatus;
  final bool isUnauthenticated;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _statusIcon(syncStatus.type),
                const SizedBox(width: 8),
                Text(
                  _statusLabel(syncStatus.type, isUnauthenticated),
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (syncStatus.lastSyncedAt != null)
              Text(
                'Last synced: ${_formatDate(syncStatus.lastSyncedAt!)}',
                style: theme.textTheme.bodySmall,
                key: const Key('last_synced_text'),
              )
            else
              Text(
                'Never synced',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              '${syncStatus.pendingChanges} pending change'
              '${syncStatus.pendingChanges == 1 ? '' : 's'}',
              style: theme.textTheme.bodySmall,
              key: const Key('pending_changes_text'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusIcon(SyncStatusType type) {
    switch (type) {
      case SyncStatusType.idle:
        return const Icon(Icons.cloud_outlined, size: 20);
      case SyncStatusType.syncing:
        return const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case SyncStatusType.success:
        return const Icon(Icons.cloud_done_outlined, size: 20, color: Colors.green);
      case SyncStatusType.error:
        return const Icon(Icons.cloud_off_outlined, size: 20, color: Colors.red);
    }
  }

  String _statusLabel(SyncStatusType type, bool isUnauthenticated) {
    if (isUnauthenticated) return 'Sync unavailable';
    switch (type) {
      case SyncStatusType.idle:
        return 'Ready to sync';
      case SyncStatusType.syncing:
        return 'Syncing…';
      case SyncStatusType.success:
        return 'Up to date';
      case SyncStatusType.error:
        return 'Sync failed';
    }
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('MMM d, y HH:mm').format(dt);
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.onErrorContainer,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                  fontSize: 13,
                ),
                key: const Key('error_message_text'),
              ),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                child: const Text('Try Again'),
              ),
          ],
        ),
      ),
    );
  }
}

class _SyncButton extends StatelessWidget {
  const _SyncButton({
    required this.isSyncing,
    required this.isDisabled,
    required this.onPressed,
  });

  final bool isSyncing;
  final bool isDisabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (isDisabled) {
      return Column(
        children: [
          ElevatedButton(
            onPressed: null,
            child: const Text('Sync Now'),
          ),
          const SizedBox(height: 8),
          Text(
            'Sign in to enable cloud sync',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
            key: const Key('sign_in_prompt'),
          ),
        ],
      );
    }

    return ElevatedButton(
      onPressed: isSyncing ? null : onPressed,
      child: isSyncing
          ? const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    key: Key('sync_spinner'),
                  ),
                ),
                SizedBox(width: 8),
                Text('Syncing…'),
              ],
            )
          : const Text('Sync Now'),
    );
  }
}

class _InfoText extends StatelessWidget {
  const _InfoText();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Your progress is saved locally. Sync to back up to the cloud.',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
      textAlign: TextAlign.center,
    );
  }
}
