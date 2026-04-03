import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/data/sync/mock_auth_service.dart';
import 'package:earth_nova/models/auth_state.dart';
import 'package:earth_nova/models/user_profile.dart';
import 'package:earth_nova/providers/auth_provider.dart';

UserProfile _makeProfile({String id = 'u_1'}) => UserProfile(
      id: id,
      email: 'test@example.com',
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  group('AuthNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
      addTearDown(container.dispose);
    });

    test('initial state is loading', () {
      final state = container.read(authProvider);
      expect(state.status, AuthStatus.loading);
    });

    test('setState changes auth state', () {
      container
          .read(authProvider.notifier)
          .setState(const AuthState.unauthenticated());
      expect(container.read(authProvider).status, AuthStatus.unauthenticated);
    });

    test('setAuthenticated transitions to authenticated with userId', () {
      final profile = _makeProfile(id: 'player_99');
      container.read(authProvider.notifier).setAuthenticated(profile);

      final state = container.read(authProvider);
      expect(state.status, AuthStatus.authenticated);
      expect(state.user?.id, 'player_99');
    });

    test('setUnauthenticated clears user', () {
      container.read(authProvider.notifier).setAuthenticated(_makeProfile());
      container.read(authProvider.notifier).setUnauthenticated();

      final state = container.read(authProvider);
      expect(state.status, AuthStatus.unauthenticated);
      expect(state.user, isNull);
    });

    test('authenticated state carries userId', () {
      final profile = _makeProfile(id: 'abc_123');
      container.read(authProvider.notifier).setAuthenticated(profile);

      expect(container.read(authProvider).user?.id, 'abc_123');
    });

    test('state transitions: loading → authenticated → unauthenticated', () {
      // Initial: loading.
      expect(container.read(authProvider).status, AuthStatus.loading);

      // Authenticate.
      container
          .read(authProvider.notifier)
          .setAuthenticated(_makeProfile(id: 'user_1'));
      expect(container.read(authProvider).status, AuthStatus.authenticated);

      // Sign out.
      container.read(authProvider.notifier).setUnauthenticated();
      expect(container.read(authProvider).status, AuthStatus.unauthenticated);
    });

    test('setError transitions to unauthenticated with errorMessage', () {
      container.read(authProvider.notifier).setError('Network error');

      final state = container.read(authProvider);
      // AuthState.error uses unauthenticated status per implementation.
      expect(state.status, AuthStatus.unauthenticated);
      expect(state.errorMessage, 'Network error');
    });

    test('authStateChanges from MockAuthService triggers state update',
        () async {
      final mockService = MockAuthService();
      final scopedContainer = ProviderContainer(overrides: [
        authServiceProvider.overrideWith((ref) => mockService),
      ]);
      addTearDown(scopedContainer.dispose);

      // Initial state: loading (before MockAuthService emits null).
      expect(scopedContainer.read(authProvider).status, AuthStatus.loading);

      // Sign in via mock service.
      await mockService.signInWithPhone('+13334445555');

      // Wait for stream to propagate.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(
        scopedContainer.read(authProvider).status,
        AuthStatus.authenticated,
      );
      mockService.dispose();
    });

    // --- Stream-driven state transitions (authStateChanges) ---

    test('stream null while loading transitions to unauthenticated', () async {
      // Regression: the original bug — stream emits null (no session) while
      // the notifier is still in loading state, leaving the button disabled.
      final mockService = MockAuthService();
      final scopedContainer = ProviderContainer(overrides: [
        authServiceProvider.overrideWith((ref) => mockService),
      ]);
      addTearDown(scopedContainer.dispose);

      // Read provider to trigger build() and set up stream listener.
      expect(scopedContainer.read(authProvider).status, AuthStatus.loading);

      // MockAuthService emits null on first listen (no existing session).
      // Wait for stream to propagate.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(
        scopedContainer.read(authProvider).status,
        AuthStatus.unauthenticated,
      );
      mockService.dispose();
    });

    test(
        'stream null while error clears error and transitions to unauthenticated',
        () async {
      final mockService = MockAuthService();
      final scopedContainer = ProviderContainer(overrides: [
        authServiceProvider.overrideWith((ref) => mockService),
      ]);
      addTearDown(scopedContainer.dispose);

      // Read provider to trigger build() and set up stream listener.
      expect(scopedContainer.read(authProvider).status, AuthStatus.loading);

      // Wait for initial null → unauthenticated.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(scopedContainer.read(authProvider).status,
          AuthStatus.unauthenticated);

      // Force error state via notifier.
      scopedContainer.read(authProvider.notifier).setError('Network error');
      expect(scopedContainer.read(authProvider).errorMessage, 'Network error');

      // Sign out → stream emits null → should clear error and stay
      // unauthenticated.
      await mockService.signOut();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = scopedContainer.read(authProvider);
      expect(state.status, AuthStatus.unauthenticated);
      expect(state.errorMessage, isNull);
      mockService.dispose();
    });

    test('stream null while unauthenticated is a no-op', () async {
      final mockService = MockAuthService();
      final scopedContainer = ProviderContainer(overrides: [
        authServiceProvider.overrideWith((ref) => mockService),
      ]);
      addTearDown(scopedContainer.dispose);

      // Read provider to trigger build() and set up stream listener.
      expect(scopedContainer.read(authProvider).status, AuthStatus.loading);

      // Wait for initial null emission → unauthenticated.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(scopedContainer.read(authProvider).status,
          AuthStatus.unauthenticated);

      // Sign out again → stream emits null again.
      await mockService.signOut();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Should still be unauthenticated, no crash.
      expect(scopedContainer.read(authProvider).status,
          AuthStatus.unauthenticated);
      mockService.dispose();
    });

    test('stream null while authenticated transitions to unauthenticated',
        () async {
      // Session expiry: user was authenticated, stream emits null.
      final mockService = MockAuthService();
      final scopedContainer = ProviderContainer(overrides: [
        authServiceProvider.overrideWith((ref) => mockService),
      ]);
      addTearDown(scopedContainer.dispose);

      // Read provider to trigger build() and set up stream listener.
      expect(scopedContainer.read(authProvider).status, AuthStatus.loading);

      // Sign in.
      await mockService.signInWithPhone('+13334445555');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
        scopedContainer.read(authProvider).status,
        AuthStatus.authenticated,
      );

      // Sign out → stream emits null.
      await mockService.signOut();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(
        scopedContainer.read(authProvider).status,
        AuthStatus.unauthenticated,
      );
      mockService.dispose();
    });

    // --- signInWithPhone method ---

    test('signInWithPhone success: loading → authenticated', () async {
      final mockService = MockAuthService();
      final scopedContainer = ProviderContainer(overrides: [
        authServiceProvider.overrideWith((ref) => mockService),
      ]);
      addTearDown(scopedContainer.dispose);

      await scopedContainer
          .read(authProvider.notifier)
          .signInWithPhone('+13334445555');

      expect(
        scopedContainer.read(authProvider).status,
        AuthStatus.authenticated,
      );
      mockService.dispose();
    });

    test('signInWithPhone failure: loading → error', () async {
      final mockService = MockAuthService();
      final scopedContainer = ProviderContainer(overrides: [
        authServiceProvider.overrideWith((ref) => mockService),
      ]);
      addTearDown(scopedContainer.dispose);

      // Invalid phone number → AuthException.
      await scopedContainer.read(authProvider.notifier).signInWithPhone('bad');

      final state = scopedContainer.read(authProvider);
      expect(state.status, AuthStatus.unauthenticated);
      expect(state.errorMessage, isNotNull);
      mockService.dispose();
    });

    // --- signOut method ---

    test('signOut from authenticated transitions to unauthenticated', () async {
      final mockService = MockAuthService();
      final scopedContainer = ProviderContainer(overrides: [
        authServiceProvider.overrideWith((ref) => mockService),
      ]);
      addTearDown(scopedContainer.dispose);

      // Read provider to trigger build() and set up stream listener.
      expect(scopedContainer.read(authProvider).status, AuthStatus.loading);

      // Sign in via the notifier (which also emits to the stream).
      await scopedContainer
          .read(authProvider.notifier)
          .signInWithPhone('+13334445555');
      expect(
        scopedContainer.read(authProvider).status,
        AuthStatus.authenticated,
      );

      await scopedContainer.read(authProvider.notifier).signOut();

      expect(
        scopedContainer.read(authProvider).status,
        AuthStatus.unauthenticated,
      );
      mockService.dispose();
    });

    test('signOut from unauthenticated is a no-op', () async {
      final mockService = MockAuthService();
      final scopedContainer = ProviderContainer(overrides: [
        authServiceProvider.overrideWith((ref) => mockService),
      ]);
      addTearDown(scopedContainer.dispose);

      // Read provider to trigger build().
      expect(scopedContainer.read(authProvider).status, AuthStatus.loading);

      await scopedContainer.read(authProvider.notifier).signOut();

      expect(
        scopedContainer.read(authProvider).status,
        AuthStatus.unauthenticated,
      );
      mockService.dispose();
    });
  });
}
