import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/core/persistence/hierarchy_repository.dart';
import 'package:earth_nova/core/state/app_database_provider.dart';

/// Singleton [HierarchyRepository] that wraps [AppDatabase].
final hierarchyRepositoryProvider = Provider<HierarchyRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return HierarchyRepository(db);
});
