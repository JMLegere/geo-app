import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fog_of_world/core/state/item_instance_repository_provider.dart';
import 'package:fog_of_world/core/state/write_queue_repository_provider.dart';
import 'package:fog_of_world/features/sync/providers/sync_provider.dart';
import 'package:fog_of_world/features/sync/services/queue_processor.dart';

final queueProcessorProvider = Provider<QueueProcessor>((ref) {
  final queueRepo = ref.watch(writeQueueRepositoryProvider);
  final persistence = ref.watch(supabasePersistenceProvider);
  final itemRepo = ref.watch(itemInstanceRepositoryProvider);

  return QueueProcessor(
    queueRepo: queueRepo,
    persistence: persistence,
    itemRepo: itemRepo,
  );
});
