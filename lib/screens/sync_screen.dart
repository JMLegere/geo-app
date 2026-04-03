import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/providers/sync_provider.dart';

/// Placeholder sync screen. Shows write queue count.
class SyncScreen extends ConsumerWidget {
  const SyncScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: const Text('Sync'),
        backgroundColor: const Color(0xFF161B22),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sync, size: 48, color: Colors.white38),
            const SizedBox(height: 12),
            Text(
              '${syncState.pendingCount} pending',
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 4),
            Text(
              syncState.status.name,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
