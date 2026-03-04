import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fog_of_world/features/auth/models/auth_state.dart';
import 'package:fog_of_world/features/auth/providers/auth_provider.dart';
import 'package:fog_of_world/core/config/supabase_bootstrap.dart';

void main() {
  group('AuthNotifier initialization', () {
    // Reset bootstrap globals before each test to avoid state leakage.
    setUp(() {
      supabaseInitialized = false;
      supabaseReady = Future<void>.value();
    });

    // ── Initial state ────────────────────────────────────────────────────────

    test('build() returns AuthState.initial() (loading) immediately', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Read synchronously before any async work completes.
      final state = container.read(authProvider);

      // AuthState.initial() returns loading status.
      expect(state.status, AuthStatus.loading);
      expect(state.user, isNull);
      expect(state.errorMessage, isNull);
    });

    // ── Fallback to MockAuthService ──────────────────────────────────────────

    test('falls back to MockAuthService when Supabase not configured', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Read the provider to trigger initialization.
      container.read(authProvider);

      // Wait for _initializeAuth() to complete (includes MockAuthService
      // anonymous sign-in, which has a 100ms simulated delay).
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // Without Supabase credentials, AuthNotifier should auto-sign-in
      // anonymously via MockAuthService.
      final state = container.read(authProvider);
      expect(state.status, AuthStatus.authenticated);
      expect(state.user, isNotNull);
      expect(state.user!.displayName, 'Explorer');
    });

    // ── State transitions ────────────────────────────────────────────────────

    test('transitions from loading to authenticated after init', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Set up listener BEFORE reading the provider to capture initial state.
      final states = <AuthStatus>[];
      container.listen(authProvider, (_, next) => states.add(next.status));

      // Now read the provider to trigger initialization.
      container.read(authProvider);

      // Wait for initialization to complete.
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // Should have transitioned: loading → authenticated.
      // Note: listener captures state changes, so we should see authenticated
      // (the initial read returns loading, but listener only fires on changes).
      expect(states, contains(AuthStatus.authenticated));
    });

    test('provides a valid user after initialization', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(authProvider);

      // Wait for initialization.
      await Future<void>.delayed(const Duration(milliseconds: 200));

      final state = container.read(authProvider);
      expect(state.isLoggedIn, isTrue);
      expect(state.user, isNotNull);
      expect(state.user!.id, isNotEmpty);
      expect(state.user!.displayName, isNotEmpty);
    });
  });
}
