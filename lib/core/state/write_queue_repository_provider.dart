import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fog_of_world/core/persistence/write_queue_repository.dart';
import 'package:fog_of_world/core/state/app_database_provider.dart';

/// Singleton [WriteQueueRepository] that wraps [AppDatabase].
final writeQueueRepositoryProvider = Provider<WriteQueueRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return WriteQueueRepository(db);
});
