import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fog_of_world/features/auth/models/auth_state.dart';
import 'package:fog_of_world/features/auth/providers/auth_provider.dart';

void main() {
  group('AuthNotifier', () {
    // Helper: create container, wait for session check to settle.
    // When Supabase is not configured (the test default), AuthNotifier
    // auto-signs-in anonymously via MockAuthService.signInAnonymously()
    // which has a 100 ms simulated delay.
    Future<ProviderContainer> makeContainer() async {
      final container = ProviderContainer();
      // Initialize provider.
      container.read(authProvider);
      // Let _initializeAuth() + signInAnonymously() complete.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      return container;
    }

    // ── Initial state ────────────────────────────────────────────────────────

    test('Initial build state is loading before session check', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Read synchronously before any async work can complete.
      final state = container.read(authProvider);

      // AuthNotifier.build() returns AuthState.initial() == loading.
      expect(state.status, AuthStatus.loading);
      // NOTE: do NOT call container.dispose() here — addTearDown handles it.
      // Calling dispose() explicitly here leaves _initializeAuth() async
      // work pending, which would try to set state on a disposed provider.
    });

    test(
        'Auto-signs in anonymously when Supabase is not configured '
        '(offline / dev mode)',
        () async {
      final container = await makeContainer();
      addTearDown(container.dispose);

      // Without Supabase, AuthNotifier auto-creates an anonymous session
      // so the user goes straight to the map — no login screen.
      expect(container.read(authProvider).status, AuthStatus.authenticated);
      expect(container.read(authProvider).user, isNotNull);
      expect(container.read(authProvider).user!.displayName, 'Explorer');
    });

    // ── signUp ───────────────────────────────────────────────────────────────

    test('signUp transitions through loading to authenticated', () async {
      final container = await makeContainer();
      addTearDown(container.dispose);

      final notifier = container.read(authProvider.notifier);

      // Sign out first to start from a clean unauthenticated state
      // (makeContainer auto-signs-in when Supabase is not configured).
      await notifier.signOut();

      final states = <AuthStatus>[];
      container.listen(authProvider, (_, next) => states.add(next.status));

      await notifier.signUp(
        email: 'test@example.com',
        password: 'password123',
      );

      expect(states, contains(AuthStatus.loading));
      expect(states.last, AuthStatus.authenticated);
    });

    test('signUp sets authenticated user profile', () async {
      final container = await makeContainer();
      addTearDown(container.dispose);

      await container.read(authProvider.notifier).signUp(
            email: 'test@example.com',
            password: 'password123',
          );

      final state = container.read(authProvider);
      expect(state.status, AuthStatus.authenticated);
      expect(state.user, isNotNull);
      expect(state.user!.email, 'test@example.com');
    });

    test('signUp with bad email sets error state', () async {
      final container = await makeContainer();
      addTearDown(container.dispose);

      await container.read(authProvider.notifier).signUp(
            email: 'not-an-email',
            password: 'password123',
          );

      final state = container.read(authProvider);
      expect(state.status, AuthStatus.unauthenticated);
      expect(state.errorMessage, isNotNull);
      expect(state.errorMessage, contains('Invalid email format'));
    });

    // ── signIn ───────────────────────────────────────────────────────────────

    test('signIn transitions through loading to authenticated', () async {
      final container = await makeContainer();
      addTearDown(container.dispose);

      final notifier = container.read(authProvider.notifier);

      // Create account first.
      await notifier.signUp(
          email: 'test@example.com', password: 'password123');
      // Sign out to reset to unauthenticated.
      await notifier.signOut();

      final states = <AuthStatus>[];
      container.listen(authProvider, (_, next) => states.add(next.status));

      await notifier.signIn(
          email: 'test@example.com', password: 'password123');

      expect(states, contains(AuthStatus.loading));
      expect(states.last, AuthStatus.authenticated);
    });

    test('signIn with wrong password sets error state', () async {
      final container = await makeContainer();
      addTearDown(container.dispose);

      final notifier = container.read(authProvider.notifier);
      await notifier.signUp(
          email: 'test@example.com', password: 'correctpass');
      await notifier.signOut();

      await notifier.signIn(
          email: 'test@example.com', password: 'wrongpass');

      final state = container.read(authProvider);
      expect(state.status, AuthStatus.unauthenticated);
      expect(state.errorMessage, isNotNull);
      expect(state.errorMessage, contains('Wrong password'));
    });

    test('signIn with unknown email sets error state', () async {
      final container = await makeContainer();
      addTearDown(container.dispose);

      await container.read(authProvider.notifier).signIn(
            email: 'nobody@example.com',
            password: 'pass',
          );

      final state = container.read(authProvider);
      expect(state.status, AuthStatus.unauthenticated);
      expect(state.errorMessage, contains('User not found'));
    });

    // ── signOut ──────────────────────────────────────────────────────────────

    test('signOut transitions authenticated → unauthenticated', () async {
      final container = await makeContainer();
      addTearDown(container.dispose);

      final notifier = container.read(authProvider.notifier);
      await notifier.signUp(
          email: 'test@example.com', password: 'password123');
      expect(container.read(authProvider).status, AuthStatus.authenticated);

      final states = <AuthStatus>[];
      container.listen(authProvider, (_, next) => states.add(next.status));

      await notifier.signOut();

      expect(states, contains(AuthStatus.unauthenticated));
    });

    // ── continueAsGuest ──────────────────────────────────────────────────────

    test('continueAsGuest transitions to authenticated via anonymous sign-in',
        () async {
      final container = await makeContainer();
      addTearDown(container.dispose);

      await container.read(authProvider.notifier).continueAsGuest();

      expect(
          container.read(authProvider).status, AuthStatus.authenticated);
    });

    test('continueAsGuest sets isLoggedIn and provides a user', () async {
      final container = await makeContainer();
      addTearDown(container.dispose);

      await container.read(authProvider.notifier).continueAsGuest();

      final state = container.read(authProvider);
      expect(state.isLoggedIn, isTrue);
      expect(state.user, isNotNull);
      expect(state.user!.displayName, 'Explorer');
    });
  });
}
