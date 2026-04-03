import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/data/repos/cell_visit_repo.dart';
import 'package:earth_nova/data/repos/write_queue_repo.dart';
import 'package:earth_nova/data/sync/queue_processor.dart';
import 'package:earth_nova/data/sync/supabase_client.dart';
import 'package:earth_nova/data/sync/supabase_persistence.dart';
import 'package:earth_nova/providers/database_provider.dart';
import 'package:earth_nova/providers/engine_provider.dart';

export 'package:earth_nova/data/sync/queue_processor.dart' show QueueProcessor;

/// Provides the [QueueProcessor] singleton.
///
/// [SupabasePersistence] is null in offline/test mode — the processor handles
/// this gracefully (canSync = false, flush returns empty summary).
final queueProcessorProvider = Provider<QueueProcessor>((ref) {
  final db = ref.watch(databaseProvider);
  final itemRepo = ref.watch(itemRepoProvider);

  // Create SupabasePersistence if Supabase is available.
  SupabasePersistence? persistence;
  final supabaseClient = SupabaseBootstrap.client;
  if (supabaseClient != null) {
    persistence = SupabasePersistence(supabaseClient);
  }

  final processor = QueueProcessor(
    queueRepo: WriteQueueRepo(db),
    persistence: persistence,
    itemRepo: itemRepo,
    cellVisitRepo: CellVisitRepo(db),
  );
  ref.onDispose(processor.dispose);
  return processor;
});
