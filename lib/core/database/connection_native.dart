import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

/// Creates a file-backed SQLite database for native platforms.
QueryExecutor createDatabaseConnection() {
  return LazyDatabase(() async {
    final file = File('fog_of_world.db');
    return NativeDatabase(file);
  });
}
