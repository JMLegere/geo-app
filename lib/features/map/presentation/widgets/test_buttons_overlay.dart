import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/features/map/domain/entities/map_level.dart';
import 'package:earth_nova/features/map/presentation/providers/location_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/map_level_provider.dart';

class TestButtonsOverlay extends ConsumerWidget {
  const TestButtonsOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(mapLevelProvider.notifier);

    return Container(
      color: Colors.black54,
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusRow('GPS', _getGpsStatus(ref)),
          _buildStatusRow('Level', ref.watch(mapLevelProvider).name),
          const Divider(color: Colors.white24),
          _buildTestButton(
            key: const Key('debug_level_up'),
            label: Semantics(
              label: 'Go to parent level',
              child: const Text('↑ Level Up'),
            ),
            onPressed: notifier.pinchClose,
          ),
          _buildTestButton(
            key: const Key('debug_level_down'),
            label: Semantics(
              label: 'Go to child level',
              child: const Text('↓ Level Down'),
            ),
            onPressed: notifier.pinchSpread,
          ),
          _buildTestButton(
            key: const Key('debug_level_root'),
            label: Semantics(
              label: 'Go to root',
              child: const Text('⌂ Root'),
            ),
            onPressed: () => notifier.jumpTo(MapLevel.cell),
          ),
        ],
      ),
    );
  }

  String _getGpsStatus(WidgetRef ref) {
    final locationState = ref.watch(locationProvider);
    return switch (locationState) {
      LocationProviderLoading() => 'loading',
      LocationProviderActive() => 'active',
      LocationProviderPermissionDenied() => 'denied',
      LocationProviderPaused() => 'paused',
      LocationProviderError() => 'error',
    };
  }

  Widget _buildStatusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          Text(
            ': $value',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildTestButton({
    required Key key,
    required Widget label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 32,
      child: TextButton(
        key: key,
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        child: label,
      ),
    );
  }
}
