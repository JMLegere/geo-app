import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fog_of_world/core/persistence/cell_progress_repository.dart';
import 'package:fog_of_world/core/state/app_database_provider.dart';

/// Singleton [CellProgressRepository] that wraps [AppDatabase].
final cellProgressRepositoryProvider = Provider<CellProgressRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return CellProgressRepository(db);
});
