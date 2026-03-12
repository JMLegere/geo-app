import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/core/state/item_instance_repository_provider.dart';
import 'package:earth_nova/core/state/write_queue_repository_provider.dart';
import 'package:earth_nova/features/sync/providers/sync_provider.dart';
import 'package:earth_nova/features/sync/providers/sync_toast_provider.dart';
import 'package:earth_nova/features/sync/services/queue_processor.dart';

final queueProcessorProvider = Provider<QueueProcessor>((ref) {
  final queueRepo = ref.watch(writeQueueRepositoryProvider);
  final persistence = ref.watch(supabasePersistenceProvider);
  final itemRepo = ref.watch(itemInstanceRepositoryProvider);

  final processor = QueueProcessor(
    queueRepo: queueRepo,
    persistence: persistence,
    itemRepo: itemRepo,
  );

  processor.onAutoFlushComplete = (summary) {
    if (summary.confirmed > 0 && !summary.hasRejections) {
      ref.read(syncToastProvider.notifier).showSuccess();
    } else if (summary.hasRejections) {
      ref.read(syncToastProvider.notifier).showError();
    }
  };

  return processor;
});
