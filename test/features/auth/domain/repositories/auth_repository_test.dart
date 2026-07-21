import 'package:earth_nova/core/domain/entities/user_profile.dart';
import 'package:earth_nova/features/auth/domain/repositories/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthException', () {
    test('uses stable safe messages for credential and availability failures',
        () {
      const invalidCredentials = AuthException.invalidCredentials();
      const unavailable = AuthException.unavailable();

      expect(invalidCredentials.message, 'Invalid login credentials.');
      expect(
        invalidCredentials.toString(),
        'AuthException: Invalid login credentials.',
      );
      expect(unavailable.message, 'Authentication service unavailable.');
      expect(
        unavailable.toString(),
        'AuthException: Authentication service unavailable.',
      );
    });
  });

  group('AuthEvent', () {
    test('state changes retain the exact optional authenticated identity', () {
      final profile = UserProfile(
        id: 'player-7',
        phone: '+15551234567',
        displayName: 'Riley',
        createdAt: DateTime.utc(2026, 7, 21),
      );
      final signedIn = AuthStateChanged(profile);
      const signedOut = AuthStateChanged(null);

      expect(signedIn.user, same(profile));
      expect(signedOut.user, isNull);
    });

    test('terminal auth events retain their distinct public kinds', () {
      const expired = AuthSessionExpired();
      const externalSignOut = AuthExternalSignOut();

      expect(expired, isA<AuthEvent>());
      expect(externalSignOut, isA<AuthEvent>());
      expect(expired.runtimeType, isNot(externalSignOut.runtimeType));
    });
  });
}
