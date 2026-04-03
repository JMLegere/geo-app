import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/providers/sanctuary_provider.dart';

/// Placeholder sanctuary screen. Shows sanctuary item count.
class SanctuaryScreen extends ConsumerWidget {
  const SanctuaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sanctuaryItems = ref.watch(sanctuaryProvider);
    final count = sanctuaryItems.length;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: const Text('Sanctuary'),
        backgroundColor: const Color(0xFF161B22),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.park, size: 48, color: Colors.white38),
            const SizedBox(height: 12),
            Text(
              '$count species placed',
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}
