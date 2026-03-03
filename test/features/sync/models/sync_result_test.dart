import 'package:flutter_test/flutter_test.dart';
import 'package:fog_of_world/features/sync/models/sync_result.dart';

void main() {
  group('SyncResult', () {
    // ── isSuccess ─────────────────────────────────────────────────────────────

    test('isSuccess is true when errorCount is 0 and errorMessage is null', () {
      const result = SyncResult(
        uploadedCount: 5,
        downloadedCount: 3,
        errorCount: 0,
      );

      expect(result.isSuccess, isTrue);
    });

    test('isSuccess is false when errorCount > 0', () {
      const result = SyncResult(
        uploadedCount: 5,
        downloadedCount: 3,
        errorCount: 1,
        errorMessage: 'Upload failed',
      );

      expect(result.isSuccess, isFalse);
    });

    test('isSuccess is false when errorMessage is set even if errorCount is 0',
        () {
      const result = SyncResult(
        uploadedCount: 0,
        downloadedCount: 0,
        errorCount: 0,
        errorMessage: 'Something went wrong',
      );

      expect(result.isSuccess, isFalse);
    });

    test('isSuccess is false when both errorCount > 0 and errorMessage set',
        () {
      const result = SyncResult(
        uploadedCount: 0,
        downloadedCount: 0,
        errorCount: 2,
        errorMessage: 'Multiple errors',
      );

      expect(result.isSuccess, isFalse);
    });

    // ── field access ──────────────────────────────────────────────────────────

    test('stores uploadedCount, downloadedCount, errorCount', () {
      const result = SyncResult(
        uploadedCount: 10,
        downloadedCount: 7,
        errorCount: 0,
      );

      expect(result.uploadedCount, 10);
      expect(result.downloadedCount, 7);
      expect(result.errorCount, 0);
      expect(result.errorMessage, isNull);
    });

    test('stores errorMessage when provided', () {
      const result = SyncResult(
        uploadedCount: 0,
        downloadedCount: 0,
        errorCount: 1,
        errorMessage: 'Network timeout',
      );

      expect(result.errorMessage, 'Network timeout');
    });

    test('zero counts result in isSuccess true', () {
      const result = SyncResult(
        uploadedCount: 0,
        downloadedCount: 0,
        errorCount: 0,
      );

      expect(result.isSuccess, isTrue);
      expect(result.uploadedCount, 0);
      expect(result.downloadedCount, 0);
    });
  });
}
