import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/config/supabase_bootstrap.dart';

void main() {
  group('SupabaseBootstrap', () {
    // ── Static API ───────────────────────────────────────────────────────────

    test('initialized defaults to false before initialize() is called', () {
      // Static field — reflects the current state of the class.
      // In tests (no credentials), this should be false.
      expect(SupabaseBootstrap.initialized, isFalse);
    });

    test('initialize() returns false when credentials missing', () async {
      // When SUPABASE_URL is empty (the default in tests), initialize()
      // should return false and leave initialized = false.
      final result = await SupabaseBootstrap.initialize();

      expect(result, isFalse);
      expect(SupabaseBootstrap.initialized, isFalse);
    });

    test('initialize() completes without throwing when no credentials',
        () async {
      // Should not throw even with missing credentials.
      await expectLater(SupabaseBootstrap.initialize(), completes);
    });

    test('initialize() is idempotent — calling twice is safe', () async {
      // Multiple calls should not throw or corrupt state.
      await SupabaseBootstrap.initialize();
      await SupabaseBootstrap.initialize();

      expect(SupabaseBootstrap.initialized, isFalse);
    });
  });
}
