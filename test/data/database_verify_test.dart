import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/data/database.dart';

void main() {
  group('AppDatabase.verifyTables', () {
    late AppDatabase db;

    tearDown(() async {
      await db.close();
    });

    test('returns true when all expected tables exist', () async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      // Drift runs migration on open, creating all tables.
      // Force a query to ensure the DB is initialized.
      await db.customSelect('SELECT 1').get();

      expect(await db.verifyTables(), isTrue);
    });

    test('returns false when a required table is missing', () async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await db.customSelect('SELECT 1').get();

      // Drop a required table to simulate stale/partial schema.
      await db.customStatement('DROP TABLE IF EXISTS species_table');

      expect(await db.verifyTables(), isFalse);
    });

    test('reports which tables are missing', () async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await db.customSelect('SELECT 1').get();

      await db.customStatement('DROP TABLE IF EXISTS species_table');
      await db.customStatement('DROP TABLE IF EXISTS items_table');

      final missing = await db.missingTables();
      expect(missing, containsAll(['species_table', 'items_table']));
    });
  });
}
