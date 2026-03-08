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
        '(offline / dev mode)', () async {
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
      await notifier.signUp(email: 'test@example.com', password: 'password123');
      // Sign out to reset to unauthenticated.
      await notifier.signOut();

      final states = <AuthStatus>[];
      container.listen(authProvider, (_, next) => states.add(next.status));

      await notifier.signIn(email: 'test@example.com', password: 'password123');

      expect(states, contains(AuthStatus.loading));
      expect(states.last, AuthStatus.authenticated);
    });

    test('signIn with wrong password sets error state', () async {
      final container = await makeContainer();
      addTearDown(container.dispose);

      final notifier = container.read(authProvider.notifier);
      await notifier.signUp(email: 'test@example.com', password: 'correctpass');
      await notifier.signOut();

      await notifier.signIn(email: 'test@example.com', password: 'wrongpass');

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

    // ── signInWithPhone ─────────────────────────────────────────────────────

    test('signInWithPhone transitions through loading to authenticated',
        () async {
      final container = await makeContainer();
      addTearDown(container.dispose);

      final notifier = container.read(authProvider.notifier);

      // Sign out first to start from a clean unauthenticated state.
      await notifier.signOut();

      final states = <AuthStatus>[];
      container.listen(authProvider, (_, next) => states.add(next.status));

      await notifier.signInWithPhone(phoneNumber: '+15551234567');

      expect(states, contains(AuthStatus.loading));
      expect(states.last, AuthStatus.authenticated);
    });

    test('signInWithPhone sets user with phone number', () async {
      final container = await makeContainer();
      addTearDown(container.dispose);

      await container
          .read(authProvider.notifier)
          .signInWithPhone(phoneNumber: '+15551234567');

      final state = container.read(authProvider);
      expect(state.status, AuthStatus.authenticated);
      expect(state.user, isNotNull);
      expect(state.user!.phoneNumber, '+15551234567');
    });

    test('signInWithPhone with invalid number sets error state', () async {
      final container = await makeContainer();
      addTearDown(container.dispose);

      await container
          .read(authProvider.notifier)
          .signInWithPhone(phoneNumber: 'not-a-phone');

      final state = container.read(authProvider);
      expect(state.status, AuthStatus.unauthenticated);
      expect(state.errorMessage, isNotNull);
      expect(state.errorMessage, contains('E.164'));
    });

    // ── signOut ──────────────────────────────────────────────────────────────

    test('signOut transitions authenticated → unauthenticated', () async {
      final container = await makeContainer();
      addTearDown(container.dispose);

      final notifier = container.read(authProvider.notifier);
      await notifier.signUp(email: 'test@example.com', password: 'password123');
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

      expect(container.read(authProvider).status, AuthStatus.authenticated);
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

    // ── upgradeWithEmail ─────────────────────────────────────────────────────

    test(
        'upgradeWithEmail transitions anonymous → authenticated with '
        'isAnonymous: false', () async {
      final container = await makeContainer();
      addTearDown(container.dispose);

      // makeContainer() auto-signs-in anonymously via MockAuthService.
      expect(container.read(authProvider).isAnonymous, isTrue);

      final states = <AuthState>[];
      container.listen(authProvider, (_, next) => states.add(next));

      await container.read(authProvider.notifier).upgradeWithEmail(
            email: 'upgraded@example.com',
            password: 'newpass123',
            displayName: 'Upgraded User',
          );

      expect(
          states,
          contains(
              predicate<AuthState>((s) => s.status == AuthStatus.loading)));
      final finalState = container.read(authProvider);
      expect(finalState.status, AuthStatus.authenticated);
      expect(finalState.user, isNotNull);
      expect(finalState.user!.isAnonymous, isFalse);
      expect(finalState.user!.email, 'upgraded@example.com');
    });

    test('upgradeWithEmail on non-anonymous user is a no-op', () async {
      final container = await makeContainer();
      addTearDown(container.dispose);

      final notifier = container.read(authProvider.notifier);

      // Sign up first (non-anonymous) — makeContainer() leaves us anonymous,
      // so upgrade to a real account first.
      await notifier.upgradeWithEmail(
        email: 'real@example.com',
        password: 'pass123',
      );
      final upgradedState = container.read(authProvider);
      expect(upgradedState.user!.isAnonymous, isFalse);

      // Capture state before second call.
      final stateBeforeSecondCall = container.read(authProvider);

      final states = <AuthState>[];
      container.listen(authProvider, (_, next) => states.add(next));

      // Try to upgrade again — should be a no-op.
      await notifier.upgradeWithEmail(
        email: 'another@example.com',
        password: 'pass456',
      );

      // No state transitions should have occurred.
      expect(states, isEmpty);
      expect(container.read(authProvider), equals(stateBeforeSecondCall));
    });

    test('upgradeWithEmail with bad email restores anonymous session for retry',
        () async {
      final container = await makeContainer();
      addTearDown(container.dispose);

      // User starts anonymous — capture pre-upgrade state.
      final preUpgrade = container.read(authProvider);
      expect(preUpgrade.isAnonymous, isTrue);

      await container.read(authProvider.notifier).upgradeWithEmail(
            email: 'not-an-email',
            password: 'pass123',
          );

      // On failure, the anonymous session is restored so the user can retry.
      final state = container.read(authProvider);
      expect(state.status, AuthStatus.authenticated);
      expect(state.isAnonymous, isTrue);
    });

    // ── linkOAuth ────────────────────────────────────────────────────────────

    test('linkOAuth on anonymous user calls service and emits auth change',
        () async {
      final container = await makeContainer();
      addTearDown(container.dispose);

      // makeContainer() auto-signs-in anonymously.
      expect(container.read(authProvider).isAnonymous, isTrue);

      await container.read(authProvider.notifier).linkOAuth(provider: 'google');

      // _listenToAuthChanges handles the state transition on success.
      // Allow the stream event to propagate.
      await Future<void>.delayed(const Duration(milliseconds: 200));

      final state = container.read(authProvider);
      expect(state.status, AuthStatus.authenticated);
      expect(state.user, isNotNull);
      expect(state.user!.isAnonymous, isFalse);
    });

    test('linkOAuth on non-anonymous user is a no-op', () async {
      final container = await makeContainer();
      addTearDown(container.dispose);

      final notifier = container.read(authProvider.notifier);

      // Upgrade to non-anonymous first.
      await notifier.upgradeWithEmail(
        email: 'upgraded@example.com',
        password: 'pass123',
      );
      expect(container.read(authProvider).user!.isAnonymous, isFalse);

      final stateBeforeCall = container.read(authProvider);
      final states = <AuthState>[];
      container.listen(authProvider, (_, next) => states.add(next));

      await notifier.linkOAuth(provider: 'apple');

      await Future<void>.delayed(const Duration(milliseconds: 200));

      // No state transitions — already upgraded.
      expect(states, isEmpty);
      expect(container.read(authProvider), equals(stateBeforeCall));
    });

    // ── signOutWithWarning ───────────────────────────────────────────────────

    test('signOutWithWarning sets error state for anonymous users', () async {
      final container = await makeContainer();
      addTearDown(container.dispose);

      // makeContainer() auto-signs-in anonymously.
      expect(container.read(authProvider).isAnonymous, isTrue);

      await container.read(authProvider.notifier).signOutWithWarning();

      final state = container.read(authProvider);
      expect(state.status, AuthStatus.unauthenticated);
      expect(state.errorMessage, isNotNull);
      expect(state.errorMessage, contains('Cannot sign out anonymous user'));
    });

    test('signOutWithWarning signs out non-anonymous users', () async {
      final container = await makeContainer();
      addTearDown(container.dispose);

      final notifier = container.read(authProvider.notifier);

      // Upgrade to non-anonymous first.
      await notifier.upgradeWithEmail(
        email: 'upgraded@example.com',
        password: 'pass123',
      );
      expect(container.read(authProvider).user!.isAnonymous, isFalse);

      final states = <AuthStatus>[];
      container.listen(authProvider, (_, next) => states.add(next.status));

      await notifier.signOutWithWarning();

      expect(states, contains(AuthStatus.unauthenticated));
      // No error message — clean sign out.
      expect(container.read(authProvider).errorMessage, isNull);
    });
  });
}
