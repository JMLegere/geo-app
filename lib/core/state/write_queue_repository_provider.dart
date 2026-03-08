import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/core/persistence/write_queue_repository.dart';
import 'package:earth_nova/core/state/app_database_provider.dart';

/// Singleton [WriteQueueRepository] that wraps [AppDatabase].
final writeQueueRepositoryProvider = Provider<WriteQueueRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return WriteQueueRepository(db);
});
