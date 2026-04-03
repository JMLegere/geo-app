import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/providers/sync_provider.dart';

class SyncScreen extends ConsumerWidget {
  const SyncScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncProvider);
    final isSyncing = syncState.status == SyncStatus.syncing;
    final isError = syncState.status == SyncStatus.error;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: const Text('Sync'),
        backgroundColor: const Color(0xFF161B22),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Status card
          _StatusCard(syncState: syncState),
          const SizedBox(height: 16),

          // Pending count
          _InfoTile(
            icon: Icons.pending_actions,
            label: 'Pending writes',
            value: '${syncState.pendingCount}',
            valueColor:
                syncState.pendingCount > 0 ? Colors.amber : Colors.green,
          ),
          const SizedBox(height: 8),

          // Error banner
          if (isError && syncState.lastError != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: Colors.redAccent, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      syncState.lastError!,
                      style: const TextStyle(
                          color: Colors.redAccent, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Flush Now button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: isSyncing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.sync, size: 18),
              label: Text(isSyncing ? 'Syncing…' : 'Flush Now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF238636),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: isSyncing
                  ? null
                  : () => ref.read(syncProvider.notifier).refreshPendingCount(),
            ),
          ),

          const SizedBox(height: 24),

          // Info note
          const Text(
            'Sync flushes the local write queue to Supabase. '
            'Rejected entries are rolled back automatically.',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _StatusCard extends StatelessWidget {
  final SyncState syncState;

  const _StatusCard({required this.syncState});

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (syncState.status) {
      SyncStatus.idle => ('Idle', Colors.green, Icons.check_circle_outline),
      SyncStatus.syncing => ('Syncing', Colors.blue, Icons.sync),
      SyncStatus.error => ('Error', Colors.red, Icons.error_outline),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Connection Status',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white38, size: 18),
          const SizedBox(width: 12),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
