import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/checkpoint_gateway.dart';
import '../domain/local_save_store.dart';
import 'checkpoint_sync_coordinator.dart';

final checkpointGatewayProvider = Provider<CheckpointGateway?>((ref) => null);

final checkpointSyncCoordinatorProvider = Provider<CheckpointSyncCoordinator?>((
  ref,
) {
  final gateway = ref.watch(checkpointGatewayProvider);
  if (gateway == null) return null;
  return CheckpointSyncCoordinator(
    store: ref.watch(checkpointLocalSaveStoreProvider),
    gateway: gateway,
  );
});

/// Overridden by the readiness save store so gameplay and synchronization share
/// one transactional database rather than competing persistence paths.
final checkpointLocalSaveStoreProvider = Provider<LocalSaveStore>(
  (ref) => throw StateError('Local save store is not configured.'),
);
