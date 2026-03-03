import 'package:flutter_test/flutter_test.dart';
import 'package:fog_of_world/features/sync/models/sync_status.dart';

void main() {
  group('SyncStatus', () {
    // ── Default state ─────────────────────────────────────────────────────────

    test('default state is idle with 0 pending changes', () {
      const status = SyncStatus(type: SyncStatusType.idle);

      expect(status.type, SyncStatusType.idle);
      expect(status.pendingChanges, 0);
      expect(status.lastSyncedAt, isNull);
      expect(status.errorMessage, isNull);
    });

    // ── SyncStatusType values ─────────────────────────────────────────────────

    test('SyncStatusType has idle, syncing, success, error values', () {
      expect(SyncStatusType.values, contains(SyncStatusType.idle));
      expect(SyncStatusType.values, contains(SyncStatusType.syncing));
      expect(SyncStatusType.values, contains(SyncStatusType.success));
      expect(SyncStatusType.values, contains(SyncStatusType.error));
      expect(SyncStatusType.values.length, 4);
    });

    // ── copyWith ──────────────────────────────────────────────────────────────

    test('copyWith replaces type', () {
      const original = SyncStatus(type: SyncStatusType.idle);
      final updated = original.copyWith(type: SyncStatusType.syncing);

      expect(updated.type, SyncStatusType.syncing);
      expect(updated.pendingChanges, original.pendingChanges);
    });

    test('copyWith replaces lastSyncedAt', () {
      const original = SyncStatus(type: SyncStatusType.idle);
      final dt = DateTime(2026, 1, 15, 12, 0);
      final updated = original.copyWith(lastSyncedAt: dt);

      expect(updated.lastSyncedAt, dt);
      expect(updated.type, SyncStatusType.idle);
    });

    test('copyWith replaces errorMessage', () {
      const original = SyncStatus(type: SyncStatusType.idle);
      final updated = original.copyWith(errorMessage: 'Network error');

      expect(updated.errorMessage, 'Network error');
    });

    test('copyWith replaces pendingChanges', () {
      const original = SyncStatus(type: SyncStatusType.idle);
      final updated = original.copyWith(pendingChanges: 5);

      expect(updated.pendingChanges, 5);
    });

    test('copyWith preserves unchanged fields', () {
      final dt = DateTime(2026, 1, 15);
      final original = SyncStatus(
        type: SyncStatusType.success,
        lastSyncedAt: dt,
        pendingChanges: 3,
      );
      final updated = original.copyWith(type: SyncStatusType.error);

      expect(updated.type, SyncStatusType.error);
      expect(updated.lastSyncedAt, dt);
      expect(updated.pendingChanges, 3);
    });

    // ── equality ──────────────────────────────────────────────────────────────

    test('two identical SyncStatus instances are equal', () {
      final dt = DateTime(2026, 1, 1);
      final a = SyncStatus(
        type: SyncStatusType.success,
        lastSyncedAt: dt,
        pendingChanges: 2,
      );
      final b = SyncStatus(
        type: SyncStatusType.success,
        lastSyncedAt: dt,
        pendingChanges: 2,
      );

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('different types are not equal', () {
      const a = SyncStatus(type: SyncStatusType.idle);
      const b = SyncStatus(type: SyncStatusType.syncing);

      expect(a, isNot(equals(b)));
    });
  });
}
