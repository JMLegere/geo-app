import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fog_of_world/core/database/app_database.dart';

/// Singleton [AppDatabase] instance for the entire app.
///
/// Uses the platform-aware [createDatabaseConnection] (file-backed on native,
/// in-memory on web). Disposed when the provider is invalidated (app shutdown).
///
/// Tests should override this with an in-memory database:
/// ```dart
/// appDatabaseProvider.overrideWithValue(AppDatabase(NativeDatabase.memory()))
/// ```
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});
