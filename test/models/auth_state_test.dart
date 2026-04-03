import 'package:flutter_test/flutter_test.dart';

import 'package:earth_nova/models/auth_state.dart';
import 'package:earth_nova/models/user_profile.dart';

UserProfile _makeProfile({String id = 'u_1'}) => UserProfile(
      id: id,
      email: 'test@example.com',
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  group('AuthState', () {
    test('loading factory has correct status', () {
      const state = AuthState.loading();
      expect(state.status, AuthStatus.loading);
      expect(state.user, isNull);
      expect(state.phone, isNull);
      expect(state.errorMessage, isNull);
    });

    test('unauthenticated factory has correct status', () {
      const state = AuthState.unauthenticated();
      expect(state.status, AuthStatus.unauthenticated);
      expect(state.user, isNull);
    });

    test('authenticated factory carries user', () {
      final profile = _makeProfile();
      final state = AuthState.authenticated(profile);
      expect(state.status, AuthStatus.authenticated);
      expect(state.user, profile);
    });

    test('otpSent factory carries phone', () {
      final state = AuthState.otpSent(phone: '+13334445555');
      expect(state.status, AuthStatus.otpSent);
      expect(state.phone, '+13334445555');
    });

    test('otpVerifying factory carries phone', () {
      final state = AuthState.otpVerifying(phone: '+13334445555');
      expect(state.status, AuthStatus.otpVerifying);
      expect(state.phone, '+13334445555');
    });

    test('error factory has unauthenticated status and message', () {
      final state = AuthState.error('Network error');
      expect(state.status, AuthStatus.unauthenticated);
      expect(state.errorMessage, 'Network error');
    });

    test('isLoggedIn returns true only when authenticated', () {
      expect(AuthState.authenticated(_makeProfile()).isLoggedIn, true);
      expect(const AuthState.loading().isLoggedIn, false);
      expect(const AuthState.unauthenticated().isLoggedIn, false);
      expect(AuthState.error('err').isLoggedIn, false);
    });

    test('equality by status, user, phone, errorMessage', () {
      final a = AuthState.authenticated(_makeProfile());
      final b = AuthState.authenticated(_makeProfile());
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('not equal when status differs', () {
      expect(const AuthState.loading() == const AuthState.unauthenticated(),
          false);
    });

    test('copyWith overrides fields', () {
      final state = AuthState.authenticated(_makeProfile());
      final updated = state.copyWith(errorMessage: 'err');
      expect(updated.user, state.user);
      expect(updated.errorMessage, 'err');
    });

    test('when() dispatches to correct callback', () {
      final result = AuthState.authenticated(_makeProfile()).when(
        loading: () => 'loading',
        unauthenticated: () => 'unauth',
        authenticated: (user) => 'auth:${user.id}',
        otpSent: (phone) => 'otp',
      );
      expect(result, 'auth:u_1');
    });

    test('when() maps otpVerifying to loading', () {
      final result = AuthState.otpVerifying(phone: '+1').when(
        loading: () => 'loading',
        unauthenticated: () => 'unauth',
        authenticated: (user) => 'auth',
        otpSent: (phone) => 'otp',
      );
      expect(result, 'loading');
    });

    test('toString contains status', () {
      expect(const AuthState.loading().toString(), contains('loading'));
    });
  });
}
