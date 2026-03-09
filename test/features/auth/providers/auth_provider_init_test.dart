import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:earth_nova/features/auth/models/auth_state.dart';
import 'package:earth_nova/features/auth/providers/auth_provider.dart';

import '../../../fixtures/auth_test_doubles.dart';

void main() {
  group('AuthNotifier initialization', () {
    // In the new architecture, AuthNotifier is a thin state holder.
    // Auth orchestration (session restore, anonymous fallback) lives in
    // gameCoordinatorProvider. These tests verify the notifier's behavior
    // when seeded by the coordinator.

    // ── Initial state ────────────────────────────────────────────────────────

    test('build() returns AuthState.initial() (loading) immediately', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Read synchronously before any external code calls setState().
      final state = container.read(authProvider);

      // AuthState.initial() returns loading status.
      expect(state.status, AuthStatus.loading);
      expect(state.user, isNull);
      expect(state.errorMessage, isNull);
    });

    // ── Simulated GC initialization flow ─────────────────────────────────────

    test('becomes authenticated when GC pushes state via setState()', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Read the provider to create the notifier.
      container.read(authProvider);

      // Simulate what gameCoordinatorProvider.initializeAuth() does:
      // 1. Create and seed the auth service.
      final fakeService = FakeAuthService();
      container.read(authServiceProvider.notifier).set(fakeService);

      // 2. Sign in anonymously.
      final user = await fakeService.signInAnonymously();

      // 3. Push authenticated state.
      container.read(authProvider.notifier).setState(
            AuthState.authenticated(user),
          );

      final state = container.read(authProvider);
      expect(state.status, AuthStatus.authenticated);
      expect(state.user, isNotNull);
      expect(state.user!.displayName, 'Explorer');
    });

    // ── State transitions ────────────────────────────────────────────────────

    test('transitions from loading to authenticated when GC pushes state',
        () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Set up listener BEFORE reading the provider to capture all changes.
      final states = <AuthStatus>[];
      container.listen(authProvider, (_, next) => states.add(next.status));

      // Read to trigger build() — initial state is loading.
      container.read(authProvider);

      // Simulate GC pushing auth state.
      final fakeService = FakeAuthService();
      container.read(authServiceProvider.notifier).set(fakeService);
      final user = await fakeService.signInAnonymously();
      container.read(authProvider.notifier).setState(
            AuthState.authenticated(user),
          );

      expect(states, contains(AuthStatus.authenticated));
    });

    test('provides a valid user after GC initialization', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(authProvider);

      // Simulate GC init.
      final fakeService = FakeAuthService();
      container.read(authServiceProvider.notifier).set(fakeService);
      final user = await fakeService.signInAnonymously();
      container.read(authProvider.notifier).setState(
            AuthState.authenticated(user),
          );

      final state = container.read(authProvider);
      expect(state.isLoggedIn, isTrue);
      expect(state.user, isNotNull);
      expect(state.user!.id, isNotEmpty);
      expect(state.user!.displayName, isNotEmpty);
    });
  });
}
