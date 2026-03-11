import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/core/persistence/location_node_repository.dart';
import 'package:earth_nova/core/state/app_database_provider.dart';

/// Singleton [LocationNodeRepository] that wraps [AppDatabase].
final locationNodeRepositoryProvider = Provider<LocationNodeRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return LocationNodeRepository(db);
});
