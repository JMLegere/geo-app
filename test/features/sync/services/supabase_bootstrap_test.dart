import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/config/supabase_bootstrap.dart';

void main() {
  group('SupabaseBootstrap', () {
    // ── initialize ───────────────────────────────────────────────────────────

    test('initialize() sets initialized = false when credentials missing', () {
      // When SUPABASE_URL is empty (the default in tests), initialize()
      // should set ready to an already-resolved future and leave
      // initialized = false.
      final bootstrap = SupabaseBootstrap();
      bootstrap.initialize();

      // ready should be immediately resolved (no async work).
      expect(bootstrap.ready, completes);
      // initialized should remain false.
      expect(bootstrap.initialized, isFalse);
    });

    test('ready completes immediately when no credentials', () async {
      final bootstrap = SupabaseBootstrap();
      bootstrap.initialize();

      // ready should resolve without delay.
      final stopwatch = Stopwatch()..start();
      await bootstrap.ready;
      stopwatch.stop();

      // Should complete in <100ms (no actual Supabase init).
      expect(stopwatch.elapsedMilliseconds, lessThan(100));
    });

    test('ready Future resolves after initialization attempt', () async {
      // Even though we can't actually initialize Supabase in tests (no valid
      // credentials), we can verify that ready is a Future that
      // eventually resolves (either to success or failure).
      final bootstrap = SupabaseBootstrap();
      bootstrap.initialize();

      // This should not hang or throw.
      await expectLater(bootstrap.ready, completes);
    });

    test('initialized defaults to false before initialize() is called', () {
      final bootstrap = SupabaseBootstrap();
      expect(bootstrap.initialized, isFalse);
    });

    test('ready defaults to resolved future before initialize() is called',
        () async {
      final bootstrap = SupabaseBootstrap();
      // Should complete immediately without calling initialize().
      await expectLater(bootstrap.ready, completes);
    });
  });
}
