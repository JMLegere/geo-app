import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/data/sync/queue_processor.dart';
import 'package:earth_nova/providers/database_provider.dart';
import 'package:earth_nova/providers/engine_provider.dart';
import 'package:earth_nova/data/repos/write_queue_repo.dart';

export 'package:earth_nova/data/sync/queue_processor.dart' show QueueProcessor;

/// Provides the [QueueProcessor] singleton.
///
/// [SupabasePersistence] is null in offline/test mode — the processor handles
/// this gracefully (canSync = false, flush returns empty summary).
final queueProcessorProvider = Provider<QueueProcessor>((ref) {
  final db = ref.watch(databaseProvider);
  final itemRepo = ref.watch(itemRepoProvider);
  final processor = QueueProcessor(
    queueRepo: WriteQueueRepo(db),
    persistence:
        null, // SupabasePersistence injected by engine layer when available
    itemRepo: itemRepo,
  );
  ref.onDispose(processor.dispose);
  return processor;
});
