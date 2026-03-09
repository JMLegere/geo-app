import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:earth_nova/features/auth/models/auth_state.dart';
import 'package:earth_nova/features/auth/providers/auth_provider.dart';

import '../../../fixtures/auth_test_doubles.dart';

void main() {
  group('AuthNotifier', () {
    // Helper: create container with FakeAuthService pre-seeded.
    ProviderContainer makeContainer() {
      final container = ProviderContainer();
      container.read(authServiceProvider.notifier).set(FakeAuthService());
      addTearDown(container.dispose);
      return container;
    }

    // ── Initial state ────────────────────────────────────────────────────────

    test('Initial build state is unauthenticated', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(authProvider);
      expect(state.status, AuthStatus.unauthenticated);
    });

    test('setState() directly updates state', () {
      final container = makeContainer();

      container.read(authProvider.notifier).setState(
            AuthState.authenticated(kTestUser),
          );

      expect(container.read(authProvider).status, AuthStatus.authenticated);
      expect(container.read(authProvider).user, kTestUser);
    });

    // ── sendOtp ──────────────────────────────────────────────────────────────

    test('sendOtp transitions to otpSent with phone stored', () async {
      final container = makeContainer();
      final notifier = container.read(authProvider.notifier);

      await notifier.sendOtp('+15551234567');

      final state = container.read(authProvider);
      expect(state.status, AuthStatus.otpSent);
      expect(state.phone, '+15551234567');
    });

    test('sendOtp with invalid phone sets error state', () async {
      final container = makeContainer();

      await container.read(authProvider.notifier).sendOtp('not-a-phone');

      final state = container.read(authProvider);
      expect(state.status, AuthStatus.unauthenticated);
      expect(state.errorMessage, isNotNull);
      expect(state.errorMessage, contains('E.164'));
    });

    test('sendOtp when service throws sets error state', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final fakeService = FakeAuthService()..shouldThrow = true;
      container.read(authServiceProvider.notifier).set(fakeService);

      await container.read(authProvider.notifier).sendOtp('+15551234567');

      final state = container.read(authProvider);
      expect(state.status, AuthStatus.unauthenticated);
      expect(state.errorMessage, isNotNull);
    });

    test('sendOtp when no service is a no-op', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      // No service set — authServiceProvider returns null.

      await container.read(authProvider.notifier).sendOtp('+15551234567');

      // State unchanged — still unauthenticated.
      expect(container.read(authProvider).status, AuthStatus.unauthenticated);
    });

    // ── verifyOtp ────────────────────────────────────────────────────────────

    test('verifyOtp transitions otpSent → otpVerifying → authenticated',
        () async {
      final container = makeContainer();
      final notifier = container.read(authProvider.notifier);

      await notifier.sendOtp('+15551234567');
      expect(container.read(authProvider).status, AuthStatus.otpSent);

      final states = <AuthStatus>[];
      container.listen(authProvider, (_, next) => states.add(next.status));

      await notifier.verifyOtp(phone: '+15551234567', code: '123456');

      expect(states, contains(AuthStatus.otpVerifying));
      expect(states.last, AuthStatus.authenticated);
    });

    test('verifyOtp sets user profile on success', () async {
      final container = makeContainer();
      final notifier = container.read(authProvider.notifier);

      await notifier.sendOtp('+15551234567');
      await notifier.verifyOtp(phone: '+15551234567', code: '123456');

      final state = container.read(authProvider);
      expect(state.status, AuthStatus.authenticated);
      expect(state.user, isNotNull);
      expect(state.user!.phoneNumber, '+15551234567');
    });

    test('verifyOtp with wrong code sets error state', () async {
      final container = makeContainer();
      final notifier = container.read(authProvider.notifier);

      await notifier.sendOtp('+15551234567');
      await notifier.verifyOtp(phone: '+15551234567', code: 'wrong');

      final state = container.read(authProvider);
      expect(state.status, AuthStatus.unauthenticated);
      expect(state.errorMessage, isNotNull);
    });

    test('verifyOtp without prior sendOtp sets error state', () async {
      final container = makeContainer();

      await container
          .read(authProvider.notifier)
          .verifyOtp(phone: '+15551234567', code: '123456');

      final state = container.read(authProvider);
      expect(state.status, AuthStatus.unauthenticated);
      expect(state.errorMessage, isNotNull);
    });

    // ── signOut ──────────────────────────────────────────────────────────────

    test('signOut transitions authenticated → unauthenticated', () async {
      final container = makeContainer();
      final notifier = container.read(authProvider.notifier);

      // Authenticate first.
      await notifier.sendOtp('+15551234567');
      await notifier.verifyOtp(phone: '+15551234567', code: '123456');
      expect(container.read(authProvider).status, AuthStatus.authenticated);

      final states = <AuthStatus>[];
      container.listen(authProvider, (_, next) => states.add(next.status));

      await notifier.signOut();

      expect(states, contains(AuthStatus.unauthenticated));
    });

    test('signOut when no service is a no-op', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      // No service set.

      // Set state to authenticated manually.
      container.read(authProvider.notifier).setState(
            AuthState.authenticated(kTestUser),
          );

      await container.read(authProvider.notifier).signOut();

      // State unchanged — still authenticated (no service to call).
      expect(container.read(authProvider).status, AuthStatus.authenticated);
    });

    // ── isLoggedIn ───────────────────────────────────────────────────────────

    test('isLoggedIn is true after successful verifyOtp', () async {
      final container = makeContainer();
      final notifier = container.read(authProvider.notifier);

      await notifier.sendOtp('+15551234567');
      await notifier.verifyOtp(phone: '+15551234567', code: '123456');

      expect(container.read(authProvider).isLoggedIn, isTrue);
    });

    test('isLoggedIn is false when unauthenticated', () {
      final container = makeContainer();

      expect(container.read(authProvider).isLoggedIn, isFalse);
    });
  });
}
