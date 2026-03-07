import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fog_of_world/core/persistence/profile_repository.dart';
import 'package:fog_of_world/core/state/app_database_provider.dart';

/// Singleton [ProfileRepository] that wraps [AppDatabase].
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return ProfileRepository(db);
});
