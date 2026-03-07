import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fog_of_world/core/state/write_queue_repository_provider.dart';
import 'package:fog_of_world/features/sync/providers/sync_provider.dart';
import 'package:fog_of_world/features/sync/services/queue_processor.dart';

/// Singleton [QueueProcessor] that flushes the local write queue to Supabase.
///
/// Returns null-safe: even when Supabase is not configured, the processor
/// is created (it will no-op on flush).
final queueProcessorProvider = Provider<QueueProcessor>((ref) {
  final queueRepo = ref.watch(writeQueueRepositoryProvider);
  final persistence = ref.watch(supabasePersistenceProvider);

  return QueueProcessor(
    queueRepo: queueRepo,
    persistence: persistence,
  );
});
