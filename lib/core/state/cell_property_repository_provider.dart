import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/core/persistence/cell_property_repository.dart';
import 'package:earth_nova/core/state/app_database_provider.dart';

/// Singleton [CellPropertyRepository] that wraps [AppDatabase].
final cellPropertyRepositoryProvider = Provider<CellPropertyRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return CellPropertyRepository(db);
});
