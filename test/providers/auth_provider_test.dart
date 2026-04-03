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
  });
}
