import 'package:flutter_test/flutter_test.dart';
import 'package:fog_of_world/features/sync/services/supabase_bootstrap.dart';

void main() {
  group('SupabaseBootstrap', () {
    // Reset globals before each test to avoid state leakage.
    setUp(() {
      supabaseInitialized = false;
      supabaseReady = Future<void>.value();
    });

    // ── initializeSupabase ───────────────────────────────────────────────────

    test('initializeSupabase sets supabaseInitialized = false when credentials missing',
        () {
      // When SUPABASE_URL is empty (the default in tests), initializeSupabase()
      // should set supabaseReady to an already-resolved future and leave
      // supabaseInitialized = false.
      initializeSupabase();

      // supabaseReady should be immediately resolved (no async work).
      expect(supabaseReady, completes);
      // supabaseInitialized should remain false.
      expect(supabaseInitialized, isFalse);
    });

    test('supabaseReady completes immediately when no credentials', () async {
      initializeSupabase();

      // supabaseReady should resolve without delay.
      final stopwatch = Stopwatch()..start();
      await supabaseReady;
      stopwatch.stop();

      // Should complete in <100ms (no actual Supabase init).
      expect(stopwatch.elapsedMilliseconds, lessThan(100));
    });

    test('supabaseReady Future resolves after initialization attempt', () async {
      // Even though we can't actually initialize Supabase in tests (no valid
      // credentials), we can verify that supabaseReady is a Future that
      // eventually resolves (either to success or failure).
      initializeSupabase();

      // This should not hang or throw.
      await expectLater(supabaseReady, completes);
    });
  });
}
