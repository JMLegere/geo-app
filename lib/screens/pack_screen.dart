import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/providers/inventory_provider.dart';

/// Placeholder pack screen. Shows inventory count.
class PackScreen extends ConsumerWidget {
  const PackScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventory = ref.watch(inventoryProvider);
    final count = inventory.items.length;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: const Text('Pack'),
        backgroundColor: const Color(0xFF161B22),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.backpack, size: 48, color: Colors.white38),
            const SizedBox(height: 12),
            Text(
              '$count items',
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}
