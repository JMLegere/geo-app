import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fog_of_world/core/persistence/item_instance_repository.dart';
import 'package:fog_of_world/core/state/app_database_provider.dart';

/// Provides [ItemInstanceRepository] backed by the singleton [AppDatabase].
///
/// Used by [gameCoordinatorProvider] to persist discovered items and by
/// startup hydration to restore inventory from SQLite.
final itemInstanceRepositoryProvider = Provider<ItemInstanceRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return ItemInstanceRepository(db);
});
