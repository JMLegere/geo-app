import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/database/app_database.dart';

void main() {
  group('Database Migration v18 - enrichment merged into LocalSpeciesTable',
      () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('schema version is 24', () {
      expect(db.schemaVersion, 24);
    });

    test('LocalPlayerProfileTable has totalSteps column', () async {
      const userId = 'user123';
      const displayName = 'TestPlayer';

      // Insert a profile with step values
      await db.into(db.localPlayerProfileTable).insert(
            LocalPlayerProfileTableCompanion(
              id: const Value(userId),
              displayName: const Value(displayName),
              totalSteps: const Value(1500),
              lastKnownStepCount: const Value(1200),
            ),
          );

      // Read back and verify
      final profile = await (db.select(db.localPlayerProfileTable)
            ..where((tbl) => tbl.id.equals(userId)))
          .getSingleOrNull();

      expect(profile, isNotNull);
      expect(profile!.totalSteps, 1500);
      expect(profile.lastKnownStepCount, 1200);
    });

    test('step columns default to 0', () async {
      const userId = 'user456';
      const displayName = 'AnotherPlayer';

      // Insert a profile without specifying step values
      await db.into(db.localPlayerProfileTable).insert(
            LocalPlayerProfileTableCompanion(
              id: const Value(userId),
              displayName: const Value(displayName),
            ),
          );

      // Read back and verify defaults
      final profile = await (db.select(db.localPlayerProfileTable)
            ..where((tbl) => tbl.id.equals(userId)))
          .getSingleOrNull();

      expect(profile, isNotNull);
      expect(profile!.totalSteps, 0);
      expect(profile.lastKnownStepCount, 0);
    });

    test('step columns can be updated', () async {
      const userId = 'user789';
      const displayName = 'UpdatePlayer';

      // Insert initial profile
      await db.into(db.localPlayerProfileTable).insert(
            LocalPlayerProfileTableCompanion(
              id: const Value(userId),
              displayName: const Value(displayName),
              totalSteps: const Value(100),
              lastKnownStepCount: const Value(50),
            ),
          );

      // Update step values
      await (db.update(db.localPlayerProfileTable)
            ..where((tbl) => tbl.id.equals(userId)))
          .write(
        const LocalPlayerProfileTableCompanion(
          totalSteps: const Value(2000),
          lastKnownStepCount: const Value(1800),
        ),
      );

      // Read back and verify updates
      final profile = await (db.select(db.localPlayerProfileTable)
            ..where((tbl) => tbl.id.equals(userId)))
          .getSingleOrNull();

      expect(profile, isNotNull);
      expect(profile!.totalSteps, 2000);
      expect(profile.lastKnownStepCount, 1800);
    });

    test('multiple profiles can have different step values', () async {
      // Insert first profile
      await db.into(db.localPlayerProfileTable).insert(
            LocalPlayerProfileTableCompanion(
              id: const Value('user_a'),
              displayName: const Value('PlayerA'),
              totalSteps: const Value(1000),
              lastKnownStepCount: const Value(900),
            ),
          );

      // Insert second profile
      await db.into(db.localPlayerProfileTable).insert(
            LocalPlayerProfileTableCompanion(
              id: const Value('user_b'),
              displayName: const Value('PlayerB'),
              totalSteps: const Value(5000),
              lastKnownStepCount: const Value(4500),
            ),
          );

      // Read both and verify
      final profileA = await (db.select(db.localPlayerProfileTable)
            ..where((tbl) => tbl.id.equals('user_a')))
          .getSingleOrNull();

      final profileB = await (db.select(db.localPlayerProfileTable)
            ..where((tbl) => tbl.id.equals('user_b')))
          .getSingleOrNull();

      expect(profileA!.totalSteps, 1000);
      expect(profileA.lastKnownStepCount, 900);
      expect(profileB!.totalSteps, 5000);
      expect(profileB.lastKnownStepCount, 4500);
    });
  });
}
