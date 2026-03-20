import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/core/database/app_database.dart';

/// Singleton [AppDatabase] instance for the entire app.
///
/// Uses the platform-aware [createDatabaseConnection] (file-backed on native,
/// in-memory on web). Seeds [LocalSpeciesTable] from `assets/species_data.json`
/// on first run (when the table is empty). Disposed when the provider is
/// invalidated (app shutdown).
///
/// Tests should override this with an in-memory database:
/// ```dart
/// appDatabaseProvider.overrideWithValue(AppDatabase(NativeDatabase.memory()))
/// ```
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase(
    null,
    () => rootBundle.loadString('assets/species_data.json'),
  );
  ref.onDispose(() => db.close());
  return db;
});
