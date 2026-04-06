import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/domain/entities/auth_state.dart';
import 'package:earth_nova/core/domain/entities/user_profile.dart';
import 'package:earth_nova/features/auth/domain/repositories/auth_repository.dart';

void main() {
  group('AuthException', () {
    test('toString includes message', () {
      const e = AuthException('bad credentials');
      expect(e.toString(), 'AuthException: bad credentials');
    });

    test('message is accessible', () {
      const e = AuthException('test');
      expect(e.message, 'test');
    });
  });
  final profile =
      UserProfile(id: 'u1', phone: '555', createdAt: DateTime(2026));

  group('AuthState constructors', () {
    test('loading', () {
      const state = AuthState.loading();
      expect(state.status, AuthStatus.loading);
      expect(state.user, isNull);
      expect(state.errorMessage, isNull);
    });

    test('unauthenticated', () {
      const state = AuthState.unauthenticated();
      expect(state.status, AuthStatus.unauthenticated);
      expect(state.user, isNull);
    });

    test('authenticated', () {
      final state = AuthState.authenticated(profile);
      expect(state.status, AuthStatus.authenticated);
      expect(state.user, profile);
    });

    test('error', () {
      const state = AuthState.error('oops');
      expect(state.status, AuthStatus.error);
      expect(state.errorMessage, 'oops');
    });
  });

  group('AuthState.when', () {
    test('routes loading', () {
      const state = AuthState.loading();
      final result = state.when(
        loading: () => 'loading',
        unauthenticated: () => 'unauth',
        authenticated: (_) => 'auth',
        error: (_) => 'error',
      );
      expect(result, 'loading');
    });

    test('routes unauthenticated', () {
      const state = AuthState.unauthenticated();
      final result = state.when(
        loading: () => 'loading',
        unauthenticated: () => 'unauth',
        authenticated: (_) => 'auth',
        error: (_) => 'error',
      );
      expect(result, 'unauth');
    });

    test('routes authenticated with user', () {
      final state = AuthState.authenticated(profile);
      final result = state.when(
        loading: () => 'loading',
        unauthenticated: () => 'unauth',
        authenticated: (u) => u.id,
        error: (_) => 'error',
      );
      expect(result, 'u1');
    });

    test('routes error with message', () {
      const state = AuthState.error('fail');
      final result = state.when(
        loading: () => 'loading',
        unauthenticated: () => 'unauth',
        authenticated: (_) => 'auth',
        error: (msg) => msg,
      );
      expect(result, 'fail');
    });
  });

  group('AuthState value equality', () {
    test('loading equals loading', () {
      expect(const AuthState.loading(), equals(const AuthState.loading()));
    });

    test('authenticated equals authenticated with same user', () {
      final a = AuthState.authenticated(profile);
      final b = AuthState.authenticated(profile);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('error equals error with same message', () {
      expect(const AuthState.error('x'), equals(const AuthState.error('x')));
    });

    test('different statuses not equal', () {
      expect(const AuthState.loading(),
          isNot(equals(const AuthState.unauthenticated())));
    });
  });
}
