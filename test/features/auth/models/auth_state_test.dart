import 'package:flutter_test/flutter_test.dart';

import 'package:earth_nova/features/auth/models/auth_state.dart';
import 'package:earth_nova/features/auth/models/user_profile.dart';

void main() {
  group('AuthState', () {
    test('isLoggedIn returns true for authenticated user', () {
      final profile = UserProfile(
        id: 'user-123',
        email: 'test@example.com',
        createdAt: DateTime(2024, 1, 1),
      );

      final state = AuthState.authenticated(profile);

      expect(state.isLoggedIn, isTrue);
    });

    test('isLoggedIn returns false when unauthenticated', () {
      final state = AuthState.unauthenticated();

      expect(state.isLoggedIn, isFalse);
    });

    test('otpSent stores phone number', () {
      final state = AuthState.otpSent(phone: '+15555550100');

      expect(state.status, AuthStatus.otpSent);
      expect(state.phone, '+15555550100');
      expect(state.isLoggedIn, isFalse);
    });

    test('otpVerifying stores phone number', () {
      final state = AuthState.otpVerifying(phone: '+15555550100');

      expect(state.status, AuthStatus.otpVerifying);
      expect(state.phone, '+15555550100');
      expect(state.isLoggedIn, isFalse);
    });

    test('error sets unauthenticated status with message', () {
      final state = AuthState.error('Something went wrong');

      expect(state.status, AuthStatus.unauthenticated);
      expect(state.errorMessage, 'Something went wrong');
      expect(state.isLoggedIn, isFalse);
    });

    test('loading has correct status', () {
      const state = AuthState.loading();

      expect(state.status, AuthStatus.loading);
      expect(state.isLoggedIn, isFalse);
    });

    test('copyWith preserves unchanged fields', () {
      final state = AuthState.otpSent(phone: '+15555550100');
      final copied = state.copyWith(status: AuthStatus.otpVerifying);

      expect(copied.status, AuthStatus.otpVerifying);
      expect(copied.phone, '+15555550100');
    });

    test('equality works correctly', () {
      final a = AuthState.otpSent(phone: '+15555550100');
      final b = AuthState.otpSent(phone: '+15555550100');
      final c = AuthState.otpSent(phone: '+15555550101');

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });
}
